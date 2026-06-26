class Player < ApplicationRecord
  belongs_to :host

  validates :name, presence: true, length: { maximum: 12 }

  before_create :assign_uuid

  # Toggle in/out of the room. Arriving earns a ticket, leaving gives it back.
  def toggle_room!
    delta = present? ? -1 : 1
    update!(present: !present?, tickets: tickets + delta)
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
