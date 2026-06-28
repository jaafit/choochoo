class Log < ApplicationRecord
  belongs_to :host

  ACTIONS = %w[nominate send_off add subtract delete gift promote demote add_player].freeze

  validates :action, inclusion: { in: ACTIONS }

  # Names of the other players involved (present at a nomination, or sent off
  # alongside the nominee). Stored denormalized so the log survives deletions.
  def other_names
    Array(data["others"] || data["members"])
  end

  # Who performed the action: the player's name, or "Admin" when the host did it.
  def actor_label
    actor_name.presence || "Admin"
  end

  # Net ticket change applied to the chosen player on a send-off. New logs store
  # the exact applied delta as "chosen_delta"; older logs derive it from the
  # legacy "delta" (deduction) plus the +1 the nominee earned for being present.
  def net_ticket_delta
    return data["chosen_delta"] if data.key?("chosen_delta")
    d = data["delta"]
    d && d + 1
  end

  # Short label for the nominee's net ticket change on a send-off, e.g. "-3 tix".
  def net_ticket_label
    return nil unless net_ticket_delta
    "#{net_ticket_delta.zero? ? '-0' : net_ticket_delta} tix"
  end
end
