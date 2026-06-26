class PlayersController < ApplicationController
  before_action :set_host
  before_action :set_player, only: [ :destroy, :toggle_present, :adjust_tickets ]

  # POST /hosts/:host_uuid/players
  def create
    @host.players.create(player_params)
    redirect_to host_path(@host)
  end

  # DELETE /hosts/:host_uuid/players/:id
  def destroy
    @host.reset_nomination! if @host.nominated_player_id == @player.id
    @player.destroy
    redirect_to host_path(@host)
  end

  # PATCH /hosts/:host_uuid/players/:id/toggle_present
  def toggle_present
    # Locked while a nomination is on the table, matching the original app.
    @player.toggle_present! unless @host.nominated_player_id
    redirect_to host_path(@host)
  end

  # PATCH /hosts/:host_uuid/players/:id/adjust_tickets?amount=1
  def adjust_tickets
    @player.adjust_tickets!(params[:amount].to_i)
    redirect_to host_path(@host)
  end

  private

  def set_player
    @player = @host.players.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name)
  end
end
