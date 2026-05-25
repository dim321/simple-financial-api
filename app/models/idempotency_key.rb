class IdempotencyKey < ApplicationRecord
  belongs_to :user

  validates :key, presence: true
  validates :request_method, presence: true
  validates :request_path, presence: true
  validates :request_fingerprint, presence: true

  def completed?
    response_status.present? && response_body.present?
  end
end
