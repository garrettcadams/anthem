class Submission < ApplicationRecord
  belongs_to :artist, class_name: 'User', foreign_key: 'artist_id'
  belongs_to :dj, class_name: 'User', foreign_key: 'dj_id'
  belongs_to :asset
  belongs_to :playlist # Target mixtape

  enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected' }

  validates :artist_id, presence: true
  validates :dj_id, presence: true
  validates :asset_id, presence: true
  validates :playlist_id, presence: true # This is the target mixtape
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Optional future validations (can be added later if needed):
  # validate :playlist_is_a_mix
  # validate :dj_owns_playlist
  # validate :artist_owns_asset

  # def playlist_is_a_mix
  #   errors.add(:playlist, "must be a mix or mixtape.") unless playlist&.is_mix?
  # end

  # def dj_owns_playlist
  #   errors.add(:dj, "must be the owner of the mixtape.") unless playlist&.user_id == dj_id
  # end

  # def artist_owns_asset
  #   errors.add(:artist, "must be the owner of the asset.") unless asset&.user_id == artist_id
  # end
end
