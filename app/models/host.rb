class Host < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :logs, dependent: :destroy
  belongs_to :nominated_player, class_name: "Player", optional: true

  before_create :assign_uuid

  # Use the UUID (not the numeric id) in URLs.
  def to_param
    uuid
  end

  # Everyone, always alphabetical (case-insensitive) regardless of room status or
  # ticket count, so a player's grid position never moves as state changes.
  def roster
    players.order(Arel.sql("name COLLATE NOCASE ASC"))
  end

  # Players currently in the room.
  def present_players
    players.where(present: true)
  end

  # True once a player has been nominated: we're choosing who plays their game.
  def selecting?
    nominated_player_id.present?
  end

  # In-room players eligible to be marked as playing the nominee's game.
  def selectable_players
    present_players.where.not(id: nominated_player_id)
  end

  # Tickets the nominee will end up with: they pay 1 to be nominated plus 1 per
  # selected player, floored at 0. `selected_count` comes from the session.
  def nominee_remaining_tickets(selected_count)
    return nil unless nominated_player
    [ 0, nominated_player.tickets - 1 - selected_count ].max
  end

  # Most recent log entry (reverse chronological by id).
  def latest_log
    logs.order(id: :desc).first
  end

  # Weighted random pick among the players in the room (one entry per ticket).
  # No tickets are spent yet — that happens on send-off. Logs who was present.
  def nominate!(actor: nil)
    pool = present_players.flat_map { |p| Array.new(p.tickets, p) }
    return nil if pool.empty?

    winner = pool.sample
    others = present_players.where.not(id: winner.id)
                            .order(Arel.sql("name COLLATE NOCASE ASC")).pluck(:name)
    transaction do
      update!(nominated_player: winner)
      logs.create!(action: "nominate", player_name: winner.name, player_id: winner.id,
                   actor_player_id: actor&.id, data: { "others" => others })
    end
    winner
  end

  # Can the given actor (a Player, or nil for the host) undo the latest action?
  # The host can undo anything; a player only their own most-recent action.
  def can_undo_latest?(actor)
    log = latest_log
    return false unless log
    actor.nil? || log.actor_player_id == actor.id
  end

  # Cancel the current nomination (undo of a nominate): drop its log entry too.
  def cancel_nomination!
    transaction do
      log = latest_log
      log.destroy if log&.action == "nominate"
      update!(nominated_player: nil)
    end
  end

  # Commit the round: the nominee pays their tickets, then the nominee and the
  # selected players leave the room. The send_off log entry doubles as the undo
  # snapshot. `member_ids` is the ephemeral selection from the session.
  def send_off!(member_ids, actor: nil)
    return unless selecting?

    nominee = nominated_player
    members = selectable_players.where(id: member_ids).order(Arel.sql("name COLLATE NOCASE ASC")).to_a
    new_tickets = [ 0, nominee.tickets - 1 - members.size ].max
    transaction do
      logs.create!(action: "send_off", player_name: nominee.name, player_id: nominee.id,
                   actor_player_id: actor&.id, data: {
        "members" => members.map(&:name),
        "member_ids" => members.map(&:id),
        "delta" => new_tickets - nominee.tickets,
        "nominee_tickets" => nominee.tickets
      })
      nominee.update!(tickets: new_tickets)
      ([ nominee ] + members).each { |p| p.update!(present: false) }
      update!(nominated_player: nil)
    end
  end

  # True when the most recent action was a send-off (so it can be undone).
  def undoable_send_off?
    latest_log&.action == "send_off"
  end

  # Reverse the last send-off: restore the nominee's tickets, put the nominee and
  # everyone sent off back in the room (re-nominated), and delete the log entry.
  def restore_send_off!
    log = latest_log
    return unless log&.action == "send_off"

    data = log.data
    nominee = players.find_by(id: log.player_id)
    transaction do
      nominee&.update!(tickets: data["nominee_tickets"], present: true)
      players.where(id: data["member_ids"]).update_all(present: true)
      update!(nominated_player_id: log.player_id)
      log.destroy
    end
  end

  # Edit-mode +/- a ticket (floored at 0). Logging collapses inverse pairs: a
  # subtract right after an add (same player) just deletes the add, and vice versa.
  def adjust_ticket!(player, amount)
    new_tickets = [ 0, player.tickets + amount ].max
    return if new_tickets == player.tickets

    this_action = amount.positive? ? "add" : "subtract"
    inverse = amount.positive? ? "subtract" : "add"
    transaction do
      player.update!(tickets: new_tickets)
      last = latest_log
      if last && last.action == inverse && last.player_id == player.id
        last.destroy
      else
        logs.create!(action: this_action, player_name: player.name, player_id: player.id)
      end
    end
  end

  # Record a player deletion (call before the player is destroyed).
  def log_delete!(player)
    logs.create!(action: "delete", player_name: player.name, player_id: player.id)
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
