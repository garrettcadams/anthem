require 'rails_helper'

RSpec.feature "SubmissionProcess", type: :feature do
  let(:artist) do
    User.create!(
      login: 'testartist',
      email: 'testartist@example.com',
      password: 'password',
      password_confirmation: 'password',
      role: :artist,
      display_name: "Test Artist"
    )
  end
  let(:dj) do
    User.create!(
      login: 'testdj',
      email: 'testdj@example.com',
      password: 'password',
      password_confirmation: 'password',
      role: :dj,
      display_name: "Test DJ"
    )
  end
  let!(:asset_by_artist) do
    # Ensure dummy file exists
    dummy_file_path = Rails.root.join('spec', 'fixtures', 'files', 'muppets.mp3')
    FileUtils.mkdir_p(File.dirname(dummy_file_path))
    FileUtils.touch(dummy_file_path) unless File.exist?(dummy_file_path)

    Asset.create!(
      user: artist,
      title: "Artist's Cool Track",
      audio_file: Rack::Test::UploadedFile.new(dummy_file_path, 'audio/mpeg')
    )
  end
  let!(:dj_mixtape) do
    Playlist.create!(
      user: dj,
      title: "DJ's Hot Mixtape",
      is_mix: true,
      permalink: "djs_hot_mixtape_#{SecureRandom.hex(4)}" # Ensure unique permalink
    )
  end

  # Basic login helper for feature specs (adapt to your app's form structure)
  def login_user_feature(user_login, password)
    visit login_path
    fill_in 'user_session_login', with: user_login # Check actual ID/name of field
    fill_in 'user_session_password', with: password # Check actual ID/name of field
    click_button 'Come on in...' # Check actual button text/ID
  end

  scenario "Artist submits a track to a DJ's mixtape, DJ approves it", js: false do # js: true if dynamic elements
    # Artist part
    login_user_feature(artist.login, 'password')
    # Awaiting proper flash message or content check for successful login
    # expect(page).to have_content("Logged in successfully") # Or similar

    visit playlist_path(dj_mixtape) # Assumes playlist_path helper takes the object
    expect(page).to have_content(dj_mixtape.title)
    expect(page).to have_link("Submit your track to this mixtape") # Verify link is present
    click_link "Submit your track to this mixtape"

    expect(page).to have_current_path(new_playlist_submission_path(dj_mixtape))
    select asset_by_artist.title, from: 'submission_asset_id' # Check actual ID of select
    fill_in 'submission_message', with: 'Hope you like my track!' # Check actual ID of textarea
    click_button "Submit Track"

    expect(page).to have_content 'Track submitted successfully.'
    expect(Submission.count).to eq(1)
    submission = Submission.first
    expect(submission.artist).to eq(artist)
    expect(submission.dj).to eq(dj)
    expect(submission.asset).to eq(asset_by_artist)
    expect(submission.playlist).to eq(dj_mixtape)
    expect(submission.status).to eq('pending')

    # Logout artist (assuming a logout link/button exists)
    # For example: click_link "Logout" or find a more specific selector
    # This step is important for a clean state before DJ logs in.
    # If no direct logout link, may need to visit logout_path directly or manage session.
    # For now, we'll proceed assuming logout happens or session is reset for next login.
    # If using Capybara.reset_sessions!, ensure it's configured.
    # UserSession.find&.destroy # Direct Authlogic session destruction

    # DJ part
    login_user_feature(dj.login, 'password')
    # expect(page).to have_content("Logged in successfully")

    # Navigate to DJ submissions page
    # Assuming a link "Manage Submissions" exists in the header for DJs
    expect(page).to have_link("Manage Submissions")
    click_link "Manage Submissions"

    expect(page).to have_current_path(dj_submissions_path)
    expect(page).to have_content("Pending Submissions for Your Mixtapes")
    expect(page).to have_content(asset_by_artist.title)
    expect(page).to have_content(artist.display_name) # or .name

    # Approve the submission
    # This part can be tricky with Capybara if there are multiple identical buttons.
    # Using a more specific selector or scoping within a table row is better.
    # For simplicity, if it's the only "Approve" button for that submission:
    # find('tr', text: asset_by_artist.title).click_button('Approve')
    # Or give elements unique IDs in the view: e.g., id: "approve_submission_#{submission.id}"
    # For now, assuming a simple case or that the first "Approve" button is the correct one.

    # To make it more robust, let's assume the form is specific enough
    # or we can scope it. For now, we'll click the first one.
    # A better way would be to ensure the view has unique IDs for forms/buttons.
    within('table tbody tr', text: asset_by_artist.title) do
      click_button "Approve"
    end

    expect(page).to have_content 'Submission approved and track added to mixtape.'
    expect(submission.reload.status).to eq('approved')
    expect(dj_mixtape.tracks.count).to eq(1)
    expect(dj_mixtape.assets).to include(asset_by_artist)
  end
end
