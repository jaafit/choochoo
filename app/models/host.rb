class Host < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :logs, dependent: :destroy
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

  # Player rows for the client grid: name + authoritative ticket count + flags.
  # Presence and the in-progress round live only in the browser now, so the
  # server never knows (or broadcasts) who is in the room or being picked.
  def roster_json
    roster.map do |p|
      { id: p.id, name: p.name, tickets: p.tickets, admin: p.admin, owner: p.id == owner_id }
    end
  end

  # Most recent log entry (reverse chronological by id).
  def latest_log
    logs.order(id: :desc).first
  end

  # Weighted random pick among the present players (client-supplied ids). Stateless:
  # spends no tickets and writes no log — the round lives in the browser until
  # send-off, which is what lets several players run a raffle at once. Weighting
  # uses tickets + 1 so a just-arrived 0-ticket player stays pickable, matching
  # the old post-entry pool. Reads ticket counts from the DB, never the client.
  def pick_winner(present_ids)
    pool = players.where(id: Array(present_ids))
                  .flat_map { |p| Array.new([ p.tickets, 0 ].max + 1, p) }
    pool.sample
  end

  # Can the given actor undo the latest action from the home page? Only the
  # player who performed it — even admins get no override here; their override
  # lives in the logs view (see HostsController#undo with `admin`). Always
  # limited to the single latest log entry.
  def can_undo_latest?(actor)
    log = latest_log
    return false unless log
    log.actor_player_id == actor&.id
  end

  # True once the host has at least one admin (the owner is always the first).
  def has_admin?
    owner_id.present?
  end

  # Make the player the host's owner: its first admin. Used when the first player
  # adds themselves, or when someone claims a player on an admin-less host.
  #
  # Clearing the UUID retires the host URL: once there's an owner, that URL is no
  # longer a control surface, so we drop it entirely. Everyone now acts through
  # their own player URL. (Existing hosts created before this aren't backfilled.)
  def make_owner!(player)
    transaction do
      player.update!(admin: true)
      update!(owner: player, uuid: nil)
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

  # Commit a round from client-supplied ids — we never trust client ticket
  # numbers, only the id lists. Each player sent to the chosen one's game earns
  # +1; the chosen pays 1 per other player sent, floored at 0. Players who were
  # merely present (not sent) are untouched. The log stores a prior-ticket
  # snapshot of everyone changed so the round can be undone while it is still the
  # latest log. Returns the created log, or nil if the chosen id is invalid.
  def send_off!(chosen_id, member_ids, actor: nil)
    log = nil
    transaction do
      chosen = players.find_by(id: chosen_id)
      if chosen
        ids = (Array(member_ids).map(&:to_i) - [ chosen.id ]).uniq
        members = players.where(id: ids).order(Arel.sql("name COLLATE NOCASE ASC")).to_a
        new_chosen = [ chosen.tickets - members.size, 0 ].max
        snapshot = ([ chosen ] + members).to_h { |p| [ p.id.to_s, p.tickets ] }

        log = logs.create!(action: "send_off", player_name: chosen.name, player_id: chosen.id,
                     actor_player_id: actor&.id, actor_name: actor&.name, data: {
          "chosen_id" => chosen.id,
          "members" => members.map(&:name),
          "member_ids" => members.map(&:id),
          "chosen_delta" => new_chosen - chosen.tickets,
          "prior_tickets" => snapshot
        })
        # Atomic increments so concurrent send-offs over overlapping sets can't
        # lose updates; the chosen's floored value is computed above.
        players.where(id: members.map(&:id)).update_all("tickets = tickets + 1") if members.any?
        players.where(id: chosen.id).update_all(tickets: new_chosen)
      end
    end
    log
  end

  # True when the most recent action was a send-off (so it can be undone).
  def undoable_send_off?
    latest_log&.action == "send_off"
  end

  # Reverse the latest log entry, whatever its action — the admins-only override
  # offered from the logs page. Only runs while `log` is still the latest entry,
  # so every reverser's stored state (ticket snapshots, the deleted player's
  # attributes) is still current. The owner's own actions are off-limits; the
  # caller enforces that. Returns true when something was reversed.
  def undo_latest!(log)
    return false unless log && log == latest_log

    case log.action
    when "send_off"   then restore_send_off!(log)
    when "gift"       then !!undo_gift!   # admin override: no `by`
    when "add"        then revert_ticket!(log, -1)
    when "subtract"   then revert_ticket!(log, +1)
    when "promote"    then revert_role!(log, admin: false)
    when "demote"     then revert_role!(log, admin: true)
    when "add_player" then revert_add_player!(log)
    when "delete"     then revert_delete!(log)
    else false
    end
  end

  # Reverse a send-off: restore every affected player's ticket count from the
  # log's snapshot and delete the log. Callers verify `log` is the latest entry
  # first, so the snapshot is still current — any later change would have created
  # a newer log, which is exactly why undo refuses to run when it isn't latest.
  def restore_send_off!(log)
    return false unless log&.action == "send_off"
    transaction do
      Hash(log.data["prior_tickets"]).each do |pid, tix|
        players.where(id: pid).update_all(tickets: tix)
      end
      log.destroy
    end
    true
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
  # admin who deleted them. We snapshot the player's attributes so an admin can undo
  # the deletion from the logs page while it's still the latest entry — recreating
  # them with the same uuid keeps any bookmarked player URL working.
  def log_delete!(player, actor: nil)
    logs.create!(action: "delete", player_name: player.name, player_id: player.id,
                 actor_player_id: actor&.id, actor_name: actor&.name,
                 data: { "tickets" => player.tickets, "admin" => player.admin, "uuid" => player.uuid })
  end

  private

  # Reverse a single edit-mode ticket change (+1 / -1), floored at 0, then drop
  # the log. `delta` is the inverse of what the log applied.
  def revert_ticket!(log, delta)
    player = players.find_by(id: log.player_id)
    transaction do
      player&.update!(tickets: [ player.tickets + delta, 0 ].max)
      log.destroy
    end
    true
  end

  # Reverse a promote/demote by restoring the prior admin flag, then drop the log.
  def revert_role!(log, admin:)
    player = players.find_by(id: log.player_id)
    transaction do
      player&.update!(admin: admin)
      log.destroy
    end
    true
  end

  # Undo an add: remove the just-added player. Safe because undo only runs while
  # this is the latest log, so nothing has happened to them since.
  def revert_add_player!(log)
    transaction do
      players.where(id: log.player_id).destroy_all
      log.destroy
    end
    true
  end

  # Undo a delete: recreate the player from the snapshot taken at deletion. Old
  # delete logs without a snapshot bring the player back by name with defaults.
  def revert_delete!(log)
    snap = log.data || {}
    transaction do
      players.create!(name: log.player_name,
                      tickets: snap["tickets"].to_i,
                      admin: !!snap["admin"],
                      uuid: snap["uuid"].presence || SecureRandom.uuid)
      log.destroy
    end
    true
  end

  def normalize_name
    name&.strip!
  end

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
