class Player < ApplicationRecord
  belongs_to :host

  validates :name, presence: true

  # Mark/unmark "at the table". Matches the original behaviour: arriving adds a
  # ticket, leaving removes one. No-op while a nomination is in progress.
  def toggle_present!
    delta = present? ? -1 : 1
    update!(present: !present?, tickets: tickets + delta)
  end

  # Edit-mode +/- a ticket, floored at 0.
  def adjust_tickets!(amount)
    update!(tickets: [ 0, tickets + amount ].max)
  end
end
