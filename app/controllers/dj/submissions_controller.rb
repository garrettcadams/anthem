# frozen_string_literal: true

module Dj
  class SubmissionsController < ApplicationController
    before_action :require_login
    before_action :require_dj_role
    before_action :find_submission, only: [:update]

    def index
      @pending_submissions = current_user.received_submissions.pending
                                .includes(:artist, :asset, :playlist)
                                .order(created_at: :desc)
      # Optionally, you might want to include other statuses as well,
      # e.g., @approved_submissions = current_user.received_submissions.approved...
      # For now, just pending as per the plan.
    end

    def update
      new_status = params.require(:submission).permit(:status)[:status]

      if @submission.update(status: new_status)
        if @submission.approved?
          # Add asset to playlist
          # Ensure asset is not already in the playlist to avoid duplicates
          unless @submission.playlist.assets.exists?(@submission.asset_id)
            track = @submission.playlist.tracks.build(asset: @submission.asset, user_id: @submission.playlist.user_id)
            if track.save
              flash[:notice] = 'Submission approved and track added to mixtape.'
            else
              # Rollback status or handle error more gracefully
              @submission.pending! # Revert status if track adding fails for some reason
              flash[:alert] = "Submission approved, but failed to add track to mixtape: #{track.errors.full_messages.join(', ')}."
            end
          else
            flash[:notice] = 'Submission approved. Track was already in the mixtape.'
          end
        else # Rejected or other status
          flash[:notice] = "Submission status updated to #{@submission.status}."
        end
        redirect_to dj_submissions_path
      else
        flash[:alert] = "Failed to update submission status: #{@submission.errors.full_messages.join(', ')}"
        redirect_to dj_submissions_path, status: :unprocessable_entity
      end
    end

    private

    def require_dj_role
      # Assuming User model has a method like `dj?` or an enum for roles
      redirect_to root_path, alert: 'Only DJs can manage submissions.' unless current_user.dj?
    end

    def find_submission
      @submission = current_user.received_submissions.find(params[:id])
    end

    # No separate submission_params for update is strictly needed if only updating status via specific params
    # def submission_update_params
    #   params.require(:submission).permit(:status)
    # end
  end
end
