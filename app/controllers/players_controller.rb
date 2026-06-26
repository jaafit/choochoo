class PlayersController < ApplicationController
  before_action :set_host
  before_action :host_only!, only: [ :destroy, :adjust_tickets ]
  before_action :set_player, only: [ :destroy, :toggle_room, :adjust_tickets ]

  # POST players — anyone with access (host or player) may add a player.
  def create
    @host.players.create(player_params)
    # `added` lets the view autofocus the input only right after an add.
    redirect_to app_root_path(added: 1)
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

  private

  def set_player
    @player = @host.players.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name)
  end
end
