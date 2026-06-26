class Host < ApplicationRecord
  has_many :players, dependent: :destroy
  belongs_to :nominated_player, class_name: "Player", optional: true

  before_create :assign_uuid

  # Use the UUID (not the numeric id) in URLs.
  def to_param
    uuid
  end

  # Players "at the table" for this round, highest ticket count first.
  def present_players
    players.where(present: true).order(tickets: :desc, name: :asc)
  end

  def absent_players
    players.where(present: false).order(tickets: :desc, name: :asc)
  end

  # Weighted random pick among present players: each player gets one entry per
  # ticket. Winning costs `present_players.size` tickets (floored at 0).
  # Returns the chosen player, or nil if no one has any tickets.
  def nominate!
    present = present_players.to_a
    pool = present.flat_map { |p| Array.new(p.tickets, p) }
    return nil if pool.empty?

    winner = pool.sample
    transaction do
      winner.update!(tickets: [ 0, winner.tickets - present.size ].max)
      update!(nominated_player: winner)
    end
    winner
  end

  def reset_nomination!
    update!(nominated_player: nil)
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
