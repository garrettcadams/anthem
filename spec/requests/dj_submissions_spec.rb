require 'rails_helper'

RSpec.describe "Dj::Submissions", type: :request do
  let(:artist_user) do
    User.create!(
      login: "artist_#{SecureRandom.hex(4)}",
      email: "artist_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :artist,
      display_name: "Artist User" # Added for clarity in views if needed
    )
  end
  let(:dj_user) do
    User.create!(
      login: "dj_#{SecureRandom.hex(4)}",
      email: "dj_#{SecureRandom.hex(4)}@example.com",
      password: 'password',
      password_confirmation: 'password',
      role: :dj,
      display_name: "DJ User" # Added for clarity
    )
  end
  let(:mixtape) do
    Playlist.create!(
      user: dj_user,
      title: "DJ #{dj_user.login}'s Mixtape",
      is_mix: true,
      permalink: "dj_#{dj_user.login}_s_mixtape_#{SecureRandom.hex(4)}"
    )
  end
  let(:artist_asset) do
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
  let!(:submission) do
    Submission.create!(
      artist: artist_user,
      dj: dj_user,
      asset: artist_asset,
      playlist: mixtape,
      message: "A test submission message"
      # status will default to 'pending'
    )
  end

  before do
    # Ensure a dummy file exists for Asset creation
    dummy_file_path = Rails.root.join('spec', 'fixtures', 'files', 'muppets.mp3')
    FileUtils.mkdir_p(File.dirname(dummy_file_path))
    FileUtils.touch(dummy_file_path) unless File.exist?(dummy_file_path)

    # Simulate login for dj_user using Authlogic test helpers
    # For request specs, direct session manipulation or stubbing current_user is common
    # Since Authlogic::TestCase is included for type: :request, UserSession.create should work if activated.
    # activate_authlogic # Usually called in rails_helper or a support file
    UserSession.create(dj_user) # This logs in dj_user

    # Fallback if UserSession.create doesn't work as expected in request spec context
    # without further setup, or if you prefer explicit stubbing for clarity:
    # allow_any_instance_of(Dj::SubmissionsController).to receive(:current_user).and_return(dj_user)
    # allow_any_instance_of(Dj::SubmissionsController).to receive(:logged_in?).and_return(true)
  end

  describe "GET /dj/submissions" do
    it "shows pending submissions for the DJ" do
      get dj_submissions_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(submission.asset.title)
      expect(response.body).to include(submission.artist.display_name) # or .name
    end
  end

  describe "PATCH /dj/submissions/:id" do
    it "approves a submission and adds track to playlist" do
      expect {
        patch dj_submission_path(submission), params: { submission: { status: 'approved' } }
      }.to change { mixtape.tracks.count }.by(1)
      expect(submission.reload.status).to eq('approved')
      expect(response).to redirect_to(dj_submissions_path)
      expect(flash[:notice]).to eq('Submission approved and track added to mixtape.')
    end

    it "rejects a submission" do
      initial_track_count = mixtape.tracks.count
      patch dj_submission_path(submission), params: { submission: { status: 'rejected' } }
      expect(submission.reload.status).to eq('rejected')
      expect(mixtape.tracks.count).to eq(initial_track_count)
      expect(response).to redirect_to(dj_submissions_path)
      expect(flash[:notice]).to eq("Submission status updated to rejected.")
    end

    it "handles approval if track is already in playlist" do
      # First, add the track to the playlist
      mixtape.tracks.create!(asset: artist_asset, user_id: dj_user.id)
      initial_track_count = mixtape.tracks.count

      expect {
        patch dj_submission_path(submission), params: { submission: { status: 'approved' } }
      }.not_to change { mixtape.tracks.count } # Count should not change

      expect(submission.reload.status).to eq('approved')
      expect(response).to redirect_to(dj_submissions_path)
      expect(flash[:notice]).to eq('Submission approved. Track was already in the mixtape.')
    end
  end
end
