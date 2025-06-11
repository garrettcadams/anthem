require 'rails_helper'

RSpec.describe "Submissions", type: :request do
  let(:artist_user) do
    User.create!(
      login: "artist_#{SecureRandom.hex(4)}",
      email: "artist_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :artist,
      display_name: "Artist User"
    )
  end
  let(:dj_user) do
    User.create!(
      login: "dj_#{SecureRandom.hex(4)}",
      email: "dj_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :dj,
      display_name: "DJ User"
    )
  end
  let(:other_artist_user) do # For testing access control
    User.create!(
      login: "other_artist_#{SecureRandom.hex(4)}",
      email: "other_artist_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :artist,
      display_name: "Other Artist"
    )
  end
  let(:listener_user) do # For testing role restrictions
    User.create!(
      login: "listener_#{SecureRandom.hex(4)}",
      email: "listener_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :listener,
      display_name: "Listener User"
    )
  end
  let!(:mixtape) do # make it available immediately
    Playlist.create!(
      user: dj_user,
      title: "DJ #{dj_user.login}'s Mixtape",
      is_mix: true,
      permalink: "dj_#{dj_user.login}_s_mixtape_#{SecureRandom.hex(4)}"
    )
  end
  let!(:artist_asset) do # make it available immediately
    Asset.create!(
      user: artist_user,
      title: "Test Track by #{artist_user.login}",
      mp3_file_name: "test.mp3",
      mp3_content_type: "audio/mpeg",
      mp3_file_size: 12345,
      length: 123,
      audio_file: Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'files', 'muppets.mp3'), 'audio/mpeg')
    )
  end
   let!(:other_artist_asset) do # make it available immediately
    Asset.create!(
      user: other_artist_user,
      title: "Other Artist's Track",
      audio_file: Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'files', 'muppets.mp3'), 'audio/mpeg')
    )
  end


  before do
    # Ensure a dummy file exists for Asset creation
    dummy_file_path = Rails.root.join('spec', 'fixtures', 'files', 'muppets.mp3')
    FileUtils.mkdir_p(File.dirname(dummy_file_path))
    FileUtils.touch(dummy_file_path) unless File.exist?(dummy_file_path)
  end

  describe "GET /playlists/:playlist_id/submissions/new" do
    context "when logged in as an artist" do
      before { UserSession.create(artist_user) }
      it "succeeds for submitting to a DJ's mixtape" do
        get new_playlist_submission_path(mixtape)
        expect(response).to have_http_status(:ok)
      end

      it "populates @artist_assets with only current artist's tracks" do
        get new_playlist_submission_path(mixtape)
        expect(assigns(:artist_assets).map(&:id)).to match_array([artist_asset.id])
        expect(assigns(:artist_assets).map(&:id)).not_to include(other_artist_asset.id)
      end

      it "redirects if playlist is not a mix" do
        album = Playlist.create!(user: dj_user, title: "DJ's Album", is_mix: false, permalink: "djs_album_#{SecureRandom.hex(4)}")
        get new_playlist_submission_path(album)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Target mixtape not found, is not a mixtape, or the owner is not a DJ.')
      end

      it "redirects if playlist owner is not a DJ" do
        non_dj_playlist_owner = User.create!(login: "nondj_#{SecureRandom.hex(4)}", email: "nondj@example.com", password: 'password', role: :listener)
        non_dj_mixtape = Playlist.create!(user: non_dj_playlist_owner, title: "Listener's Mix", is_mix: true, permalink: "listener_mix_#{SecureRandom.hex(4)}")
        get new_playlist_submission_path(non_dj_mixtape)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Target mixtape not found, is not a mixtape, or the owner is not a DJ.')
      end
    end

    context "when logged in as a non-artist (e.g., listener)" do
      before { UserSession.create(listener_user) }
      it "redirects with an alert" do
        get new_playlist_submission_path(mixtape)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Only artists can submit tracks.')
      end
    end

    context "when not logged in" do
      it "redirects to login page (or handles as per require_login)" do
        get new_playlist_submission_path(mixtape)
        # Behavior of require_login might vary (e.g., redirect to login, root, or raise error)
        # Assuming it redirects to login or shows an access denied message.
        # For this app, it seems to redirect to login_path or root_path with an alert if not setup for specific redirect.
        expect(response).to redirect_to(login_path) # Or other path as per app's require_login
      end
    end
  end

  describe "POST /playlists/:playlist_id/submissions" do
    context "when logged in as an artist" do
      before { UserSession.create(artist_user) }

      it "creates a submission with valid parameters" do
        expect {
          post playlist_submissions_path(mixtape), params: {
            submission: { asset_id: artist_asset.id, message: "Check it out!" }
          }
        }.to change(Submission, :count).by(1)

        expect(response).to redirect_to(playlist_path(mixtape))
        expect(flash[:notice]).to eq('Track submitted successfully.')

        last_submission = Submission.last
        expect(last_submission.artist).to eq(artist_user)
        expect(last_submission.dj).to eq(dj_user)
        expect(last_submission.asset).to eq(artist_asset)
        expect(last_submission.playlist).to eq(mixtape)
        expect(last_submission.status).to eq('pending')
        expect(last_submission.message).to eq("Check it out!")
      end

      it "does not create a submission with invalid asset_id" do
         expect {
          post playlist_submissions_path(mixtape), params: {
            submission: { asset_id: nil, message: "No track" } # asset_id is nil
          }
        }.not_to change(Submission, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Could not submit track.") # Or specific error
      end

      it "does not create a submission if asset_id belongs to another user" do
        expect {
          post playlist_submissions_path(mixtape), params: {
            submission: { asset_id: other_artist_asset.id, message: "Wrong asset" }
          }
        }.not_to change(Submission, :count)
        # This scenario might be caught by controller logic that scopes assets,
        # or a validation in the model. If not explicitly handled, it might save,
        # which would be a flaw. The current controller builds via `current_user.sent_submissions`
        # which should prevent this if `asset_id` is the only way to link an asset.
        # Let's assume the controller build method correctly scopes or there's a validation.
        # If it saves, the test would fail, revealing the issue.
        # A more robust test would be to check if an error is raised or specific flash.
        # For now, just checking count.
      end
    end
    # Add tests for non-artists, non-logged-in users, etc.
  end

  describe "GET /my_submissions" do
    context "when logged in as an artist" do
      before { UserSession.create(artist_user) }
      let!(:submission_by_artist) { Submission.create!(artist: artist_user, dj: dj_user, asset: artist_asset, playlist: mixtape) }

      it "shows the artist's sent submissions" do
        get my_submissions_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(artist_asset.title)
        expect(response.body).to include(mixtape.title)
      end
    end

    context "when logged in as a non-artist" do
      before { UserSession.create(listener_user) }
      it "redirects with an alert" do
        get my_submissions_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Only artists can view their submissions.')
      end
    end
  end
end
