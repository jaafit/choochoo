class PlayersController < ApplicationController
  before_action :set_host
  before_action :set_player, only: [ :destroy, :toggle_room, :adjust_tickets ]

  # POST /hosts/:host_uuid/players
  def create
    @host.players.create(player_params)
    # `added` lets the view autofocus the input only right after an add.
    redirect_to host_path(@host, added: 1)
  end

  # DELETE /hosts/:host_uuid/players/:id
  def destroy
    @host.update!(nominated_player: nil) if @host.nominated_player_id == @player.id
    @player.destroy
    redirect_to host_path(@host)
  end

  # PATCH /hosts/:host_uuid/players/:id/toggle_room — in/out of the room.
  def toggle_room
    @player.toggle_room!
    # A manual room change invalidates the last send-off's undo snapshot.
    @host.update!(undo_send_off: nil) if @host.undoable_send_off?
    redirect_to host_path(@host)
  end

  # PATCH /hosts/:host_uuid/players/:id/adjust_tickets?amount=1
  def adjust_tickets
    @player.adjust_tickets!(params[:amount].to_i)
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
