# frozen_string_literal: true

class SubmissionsController < ApplicationController
  before_action :require_login
  before_action :require_artist_role_for_new_create, only: [:new, :create]
  before_action :require_artist_role_for_index, only: [:index]
  before_action :find_playlist_for_submission, only: [:new, :create]

  def index
    @sent_submissions = current_user.sent_submissions
                              .includes(:dj, :asset, :playlist)
                              .order(created_at: :desc)
  end

  def new
    @submission = Submission.new(playlist_id: @playlist.id, dj_id: @playlist.user_id)
    # Artists can only submit their own tracks
    @artist_assets = current_user.assets.published.order(:title)
  end

  def create
    @submission = current_user.sent_submissions.build(submission_params)
    # Ensure dj_id is set from playlist owner, not from potentially manipulated params
    @submission.dj_id = @playlist.user_id
    # also ensure playlist_id is correct and not manipulated
    @submission.playlist_id = @playlist.id


    if @submission.save
      redirect_to playlist_path(@playlist), notice: 'Track submitted successfully.' # Or artist dashboard
    else
      @artist_assets = current_user.assets.published.order(:title) #
      flash.now[:error] = "Could not submit track. #{@submission.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_artist_role_for_new_create
    redirect_to root_path, alert: 'Only artists can submit tracks.' unless current_user.artist?
  end

  def require_artist_role_for_index
    redirect_to root_path, alert: 'Only artists can view their submissions.' unless current_user.artist?
  end

  def find_playlist_for_submission
    # Ensure the playlist is a mix and owned by a DJ
    @playlist = Playlist.find_by(id: params[:playlist_id]) # Use find_by to avoid RecordNotFound if routing is lax
    if !@playlist || !@playlist.is_mix? || !@playlist.user&.dj?
      redirect_to root_path, alert: 'Target mixtape not found, is not a mixtape, or the owner is not a DJ.'
    end
  end

  def submission_params
    params.require(:submission).permit(:asset_id, :message) # playlist_id is set from context
  end
end
