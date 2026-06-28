class PlayersController < ApplicationController
  before_action :set_host
  before_action :host_only!, only: [ :destroy, :update, :adjust_tickets ]
  before_action :set_player, only: [ :destroy, :update, :toggle_room, :adjust_tickets, :gift, :ungift ]

  # POST players — anyone with access (host or player) may add a player.
  def create
    player = @host.players.create(player_params)
    if player.persisted?
      # `added` lets the view autofocus the input only right after an add.
      redirect_to app_root_path(added: 1)
    else
      redirect_to app_root_path, alert: player.errors.full_messages.to_sentence
    end
  end

  # PATCH — host only. Saves the edited name and, like "done", leaves the room
  # (giving back the present ticket). A bad name keeps us in the editing view.
  def update
    if @player.update(player_params)
      @player.toggle_room!
      redirect_to app_root_path
    else
      redirect_to host_path(@host, editing: 1), alert: @player.errors.full_messages.to_sentence
    end
  end

  # DELETE — host only.
  def destroy
    @host.update!(nominated_player: nil) if @host.nominated_player_id == @player.id
    @host.log_delete!(@player)
    @player.destroy
    redirect_to app_root_path
  end

  # PATCH toggle_room — in/out of the room (host or player).
  def toggle_room
    @player.toggle_room!
    redirect_to app_root_path
  end

  # PATCH adjust_tickets — host only.
  def adjust_tickets
    @host.adjust_ticket!(@player, params[:amount].to_i)
    redirect_to host_path(@host, editing: 1)
  end

  # PATCH gift — the acting player gives one of their tickets to @player.
  def gift
    @host.gift!(giver: current_player, recipient: @player)
    redirect_to app_root_path(gifting: 1)
  end

  # PATCH ungift — undo the acting player's most recent gift (latest log only).
  def ungift
    @host.undo_gift!(by: current_player)
    redirect_to app_root_path(gifting: 1)
  end

  private

  def set_player
    @player = @host.players.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name)
  end
end
