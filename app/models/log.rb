class Log < ApplicationRecord
  belongs_to :host

  ACTIONS = %w[nominate send_off add subtract delete].freeze

  validates :action, inclusion: { in: ACTIONS }

  # Names of the other players involved (present at a nomination, or sent off
  # alongside the nominee). Stored denormalized so the log survives deletions.
  def other_names
    Array(data["others"] || data["members"])
  end

  def ticket_delta
    data["delta"]
  end

  # Net ticket change over the whole transaction: the send-off deduction plus the
  # +1 the nominee earned by being present. Holds whether or not the deduction was
  # clamped at 0 (see derivation: net == delta + 1 in both cases).
  def net_ticket_delta
    d = data["delta"]
    d && d + 1
  end
end
