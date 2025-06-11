require 'rails_helper'

RSpec.describe Submission, type: :model do
  let(:artist) do
    User.create!(
      login: "artist_#{SecureRandom.hex(4)}",
      email: "artist_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :artist
    )
  end
  let(:dj) do
    User.create!(
      login: "dj_#{SecureRandom.hex(4)}",
      email: "dj_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :dj
    )
  end
  let(:asset) do
    # Asset creation might require an audio file or other specific attributes.
    # This is a simplified version. Tests might fail if more is needed.
    # Also, Asset belongs_to user, so that needs to be the artist.
    Asset.create!(
      user: artist,
      title: "Test Track by #{artist.login}",
      mp3_file_name: "test.mp3", # Assuming this is a required field or handled by paperclip/activestorage
      mp3_content_type: "audio/mpeg",
      mp3_file_size: 12345,
      length: 123,
      audio_file: Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'files', 'muppets.mp3'), 'audio/mpeg')
    )
  end
  let(:playlist) do
    # Playlist belongs_to user, which should be the DJ.
    Playlist.create!(
      user: dj,
      title: "DJ #{dj.login}'s Mixtape",
      is_mix: true,
      permalink: "dj_#{dj.login}_s_mixtape_#{SecureRandom.hex(4)}" # permalink needs to be unique per user
    )
  end

  before do
    # Ensure a dummy file exists for Asset creation if ActiveStorage/Paperclip needs it
    # This is a common requirement.
    dummy_file_path = Rails.root.join('spec', 'fixtures', 'files', 'muppets.mp3')
    FileUtils.mkdir_p(File.dirname(dummy_file_path))
    FileUtils.touch(dummy_file_path) unless File.exist?(dummy_file_path)

    # Activate authlogic for model tests that might trigger callbacks involving current_user
    # (though less common for direct model tests, good practice if userstamps or similar are used)
    # activate_authlogic
  end

  it { should belong_to(:artist).class_name('User') }
  it { should belong_to(:dj).class_name('User') }
  it { should belong_to(:asset) }
  it { should belong_to(:playlist) }

  it { should validate_presence_of(:artist_id) }
  it { should validate_presence_of(:dj_id) }
  it { should validate_presence_of(:asset_id) }
  it { should validate_presence_of(:playlist_id) }
  it { should validate_presence_of(:status) }

  it { should define_enum_for(:status).with_values(pending: 'pending', approved: 'approved', rejected: 'rejected').backed_by_column_of_type(:string) }

  it 'defaults status to pending' do
    submission = Submission.new
    expect(submission.status).to eq('pending')
  end

  it 'is valid with valid attributes' do
    submission = Submission.new(artist: artist, dj: dj, asset: asset, playlist: playlist)
    expect(submission).to be_valid
  end

  # Test for invalid status
  it 'is not valid with an invalid status' do
    submission = Submission.new(artist: artist, dj: dj, asset: asset, playlist: playlist, status: 'invalid_status')
    expect(submission).not_to be_valid
    expect(submission.errors[:status]).to include("is not included in the list")
  end
end
