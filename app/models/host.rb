class Host < ApplicationRecord
  has_many :players, dependent: :destroy
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

  # Weighted random pick among the players in the room (one entry per ticket).
  # No tickets are spent yet — that happens on send-off.
  def nominate!
    pool = present_players.flat_map { |p| Array.new(p.tickets, p) }
    return nil if pool.empty?

    winner = pool.sample
    update!(nominated_player: winner)
    winner
  end

  # Cancel the current nomination (undo of a nominate).
  def cancel_nomination!
    update!(nominated_player: nil)
  end

  # Commit the round: the nominee pays their tickets, then the nominee and the
  # selected players leave the room. A snapshot is saved so this is undoable.
  # `member_ids` is the ephemeral selection from the session.
  def send_off!(member_ids)
    return unless selecting?

    nominee = nominated_player
    members = selectable_players.where(id: member_ids).to_a
    snapshot = {
      "nominee_id" => nominee.id,
      "nominee_tickets" => nominee.tickets,
      "member_ids" => members.map(&:id)
    }
    transaction do
      nominee.update!(tickets: [ 0, nominee.tickets - 1 - members.size ].max)
      ([ nominee ] + members).each { |p| p.update!(present: false) }
      update!(nominated_player: nil, undo_send_off: snapshot)
    end
  end

  # True when the most recent send-off can still be undone.
  def undoable_send_off?
    undo_send_off.present?
  end

  # Reverse the last send-off: restore the nominee's tickets and put the nominee
  # and everyone who was sent off back in the room, re-nominated. The selection
  # itself is ephemeral, so it isn't restored.
  def restore_send_off!
    data = undo_send_off
    return unless data

    nominee = players.find_by(id: data["nominee_id"])
    transaction do
      nominee&.update!(tickets: data["nominee_tickets"], present: true)
      players.where(id: data["member_ids"]).update_all(present: true)
      update!(nominated_player_id: data["nominee_id"], undo_send_off: nil)
    end
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
