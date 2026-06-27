class Player < ApplicationRecord
  belongs_to :host

  validates :name, presence: true, length: { maximum: 12 },
                   uniqueness: { scope: :host_id, case_sensitive: false }

  # Runs before validations, so the trimmed value is what both the uniqueness
  # check and the saved record see.
  before_validation :normalize_name

  before_create :assign_uuid

  # Toggle in/out of the room. Arriving earns a ticket, leaving gives it back.
  def toggle_room!
    delta = present? ? -1 : 1
    update!(present: !present?, tickets: tickets + delta)
  end

  private

  def normalize_name
    name&.strip!
  end

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
