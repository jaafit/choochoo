class Host < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :logs, dependent: :destroy
  belongs_to :nominated_player, class_name: "Player", optional: true
  # The owner is the host's first admin. One per host; can never be demoted.
  belongs_to :owner, class_name: "Player", optional: true

  before_create :assign_uuid
  before_validation :normalize_name

  validates :name, length: { maximum: 20 }

  # Use the UUID (not the numeric id) in URLs.
  def to_param
    uuid
  end

  # The header/title text: the host's chosen name, or the default.
  def display_name
    name.presence || "Someone Pick"
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
                   actor_player_id: actor&.id, actor_name: actor&.name,
                   data: { "others" => others })
    end
    winner
  end

  # Can the given actor (a Player) undo the latest action? An admin can undo
  # anything; a non-admin player only their own most-recent action.
  def can_undo_latest?(actor)
    log = latest_log
    return false unless log
    actor&.admin? || log.actor_player_id == actor&.id
  end

  # True once the host has at least one admin (the owner is always the first).
  def has_admin?
    owner_id.present?
  end

  # Make the player the host's owner: its first admin. Used when the first player
  # adds themselves, or when someone claims a player on an admin-less host.
  def make_owner!(player)
    transaction do
      player.update!(admin: true)
      update!(owner: player)
    end
  end

  # Promote a player to admin. `by` is the acting admin (recorded in the log).
  def promote!(player, by:)
    return if player.admin?

    transaction do
      player.update!(admin: true)
      logs.create!(action: "promote", player_name: player.name, player_id: player.id,
                   actor_player_id: by&.id, actor_name: by&.name)
    end
  end

  # Demote a non-owner admin back to a regular player. The owner can never be
  # demoted. `by` is the acting admin (recorded in the log).
  def demote!(player, by:)
    return unless player.admin?
    return if player.id == owner_id

    transaction do
      player.update!(admin: false)
      logs.create!(action: "demote", player_name: player.name, player_id: player.id,
                   actor_player_id: by&.id, actor_name: by&.name)
    end
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
                   actor_player_id: actor&.id, actor_name: actor&.name, data: {
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
  def adjust_ticket!(player, amount, actor: nil)
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
        logs.create!(action: this_action, player_name: player.name, player_id: player.id,
                     actor_player_id: actor&.id, actor_name: actor&.name)
      end
    end
  end

  # A player gives one of their own tickets to another player. The log records the
  # giver as the actor and the recipient as the player, so it can be undone (by the
  # giver) while it's still the latest entry.
  def gift!(giver:, recipient:)
    return unless giver && recipient && giver.id != recipient.id
    return unless giver.tickets.positive?

    transaction do
      giver.update!(tickets: giver.tickets - 1)
      recipient.update!(tickets: recipient.tickets + 1)
      logs.create!(action: "gift", player_name: recipient.name, player_id: recipient.id,
                   actor_player_id: giver.id, actor_name: giver.name,
                   data: { "giver_id" => giver.id, "giver_name" => giver.name })
    end
  end

  # Reverse the most recent gift — only while it's the latest log entry. The ticket
  # returns from recipient to giver and the entry is removed. `by`, when given, must
  # be the giver who made it (a player can only undo their own gift).
  def undo_gift!(by: nil)
    log = latest_log
    return unless log&.action == "gift"
    return unless by.nil? || log.actor_player_id == by.id

    recipient = players.find_by(id: log.player_id)
    giver = players.find_by(id: log.data["giver_id"])
    transaction do
      recipient&.update!(tickets: [ recipient.tickets - 1, 0 ].max)
      giver&.update!(tickets: giver.tickets + 1)
      log.destroy
    end
  end

  # Record that `actor` added `player` to the roster. (The first player — the
  # owner, added during bootstrap — isn't logged; see PlayersController#create.)
  def log_add!(player, actor: nil)
    logs.create!(action: "add_player", player_name: player.name, player_id: player.id,
                 actor_player_id: actor&.id, actor_name: actor&.name)
  end

  # Record a player deletion (call before the player is destroyed). `actor` is the
  # admin who deleted them.
  def log_delete!(player, actor: nil)
    logs.create!(action: "delete", player_name: player.name, player_id: player.id,
                 actor_player_id: actor&.id, actor_name: actor&.name)
  end

  private

  def normalize_name
    name&.strip!
  end

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
