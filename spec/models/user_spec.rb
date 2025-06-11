require "rails_helper"

RSpec.describe User, type: :model do
  context '.destroy_deleted_accounts_older_than_30_days' do
    it 'should really destroy users deleted more than 30 days ago' do
      expect { User.destroy_deleted_accounts_older_than_30_days }
        .to change { User.with_deleted.count }.by(-1)
    end

    it 'should not destroy a user deleted within last 30 days' do
      expect(users(:deleted_yesterday)).to be_valid
      User.destroy_deleted_accounts_older_than_30_days
      expect(User.with_deleted.where(login: 'deleted_yesterday').first).to be_present
    end
  end

  describe 'record selection method' do
    it 'finds a user by login' do
      user = users(:henri_willig)
      expect(User.find_by_login_or_email(user.login)).to eq(user)
    end

    it 'finds a user by email' do
      user = users(:henri_willig)
      expect(User.find_by_login_or_email(user.email)).to eq(user)
    end
  end

  describe 'scopes' do
    it 'include profile and avatar image to prevent n+1 queries' do
      expect do
        User.with_preloads.each do |user|
          user.avatar_image
          user.profile.bio
        end
      end.to perform_queries(count: 4)
    end
  end

  describe "associations" do
    it { should have_many(:sent_submissions).class_name('Submission').with_foreign_key('artist_id').dependent(:destroy) }
    it { should have_many(:received_submissions).class_name('Submission').with_foreign_key('dj_id').dependent(:destroy) }
  end

  describe "enums" do
    it { should define_enum_for(:role).with_values(listener: 'listener', artist: 'artist', dj: 'dj').backed_by_column_of_type(:string) }
  end

  describe "defaults" do
    it 'defaults role to listener' do
      user = User.new
      expect(user.role).to eq('listener')
    end
  end

  context "validation" do
    it "should be valid with email, login and password" do
      expect(new_user).to be_valid
      expect(users(:sudara)).to be_valid
    end

    it "should validate logins" do
      expect(new_user(login: "bobbyf")).to be_valid
      expect(new_user(login: "BobbyF")).to be_valid
      expect(new_user(login: "r00ter")).to be_valid
      expect(new_user(login: "with spaces")).not_to be_valid
      expect(new_user(login: "with_underscore")).to be_valid
      expect(new_user(login: "!7384.")).not_to be_valid
      expect(new_user(login: "aa")).not_to be_valid
    end

    # https://www.wikiwand.com/en/Email_address#/Examples
    it "should validate email" do
      expect(new_user(email: "userEmail1&@gmail.com")).to be_valid
      expect(new_user(email: "userEmail1&@gmail.")).not_to be_valid
      expect(new_user(email: "Abc.example.com")).not_to be_valid
      expect(new_user(email: "A@b@c@example.com")).not_to be_valid
      expect(new_user(email: "a\"b(c)d,e:f;g<h>i[j\k]l@example.com")).not_to be_valid
      expect(new_user(email: 'just"not"right@example.com')).not_to be_valid
      expect(new_user(email: 'this is"not\allowed@example.com')).not_to be_valid
      expect(new_user(email: 'this\ still\"not\\allowed@example.com ')).not_to be_valid
      expect(new_user(email: 'expect(new_user(email: "Abc.example.com")).not_to be_valid')).not_to be_valid
    end

    it "can be an admin" do
      expect(users(:sudara)).to be_admin
    end

    it "can be a mod" do
      expect(users(:sandbags)).to be_moderator
    end

    it "should treat an admin as a mod too" do
      expect(users(:sudara)).to be_moderator
    end

    it "should not require a profile on update" do
      @user = new_user
      @user.save
      @user.save
      expect(@user).to be_valid
    end
  end

  context "activation" do
    it "is considered active when persishble token doesn't exist" do
      expect(users(:arthur)).to be_active
    end

    it "is not active when perishable token exists" do
      expect(users(:not_activated).perishable_token).to be_present
      expect(users(:not_activated)).not_to be_active
    end

    it "can be activated and deactivated" do
      users(:not_activated).activate!
      expect(users(:not_activated)).to be_active
      users(:not_activated).reset_perishable_token!
      expect(users(:not_activated)).not_to be_active
    end
  end

  context "relations" do
    it 'has tracks called assets' do
      expect(users(:arthur).assets).to be_present
    end

    it 'has a favorites playlist and tracks' do
      # users(:arthur).favorites.should be_present
    end
  end

  context "deletion" do
    let(:user) { users(:sudara) }
    let!(:asset) { assets(:valid_mp3) }
    let!(:playlist) { playlists(:owp) }
    let!(:comment) { comments(:valid_comment_on_asset_by_user) }
    let!(:listen) { listens(:valid_listen) }

    describe "soft delete" do
      it "should soft delete associated recored" do
        UserCommand.new(user).soft_delete_with_relations
        user.reload

        expect(user.assets).not_to be_present
        expect(user.listens).not_to be_present
        expect(user.tracks).not_to be_present
        expect(user.playlists).not_to be_present
        expect(user.comments_received).not_to be_present
      end
    end
  end

  describe "assigning a new avatar image" do
    context "without an avatar" do
      let(:user) { users(:william_shatner) }

      it "creates the avatar" do
        user.update!(avatar_image: file_fixture_uploaded_file('marie.jpg'))
        expect(user.avatar_image).to be_attached
      end
    end

    context "with an avatar" do
      let(:user) { users(:henri_willig) }

      it "replaces the avatar" do
        user.update!(avatar_image: file_fixture_uploaded_file('marie.jpg'))
        expect(user.avatar_image).to be_attached
      end
    end
  end

  describe "generating URLs to an avatar" do
    context "with an avatar" do
      let(:user) { users(:henri_willig) }

      it "knows the user has an avatar" do
        expect(user.avatar_image_present?).to eq(true)
      end

      it "returns a storage location to a variant" do
        location = user.avatar_image_location(variant: :large_avatar)
        expect(location).to be_kind_of(Storage::Location)
        expect(location.attachment).to be_kind_of(ActiveStorage::VariantWithRecord)
        expect(location).to_not be_signed
      end
    end

    context "without an avatar" do
      let(:user) { users(:william_shatner) }

      it "knows the user does not have an avatar" do
        expect(user.avatar_image_present?).to eq(false)
      end

      it "does not return a URL to a variant" do
        expect(user.avatar_image_location(variant: :large_avatar)).to be_nil
      end
    end
  end

  protected

  def new_user(options = {})
    User.new({ email: 'new@user.com', login: 'newuser', password: 'quire451', password_confirmation: 'quire451' }.merge(options))
  end
end
