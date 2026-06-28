class PlayersController < ApplicationController
  before_action :set_host
  before_action :admin_only!, only: [ :destroy, :update, :adjust_tickets, :promote, :demote ]
  before_action :set_player, only: [ :destroy, :update, :adjust_tickets,
                                     :gift, :ungift, :promote, :demote, :claim ]

  # POST players — anyone with access (host or player) may add a player. Adding the
  # very first player (only reachable from the host URL) makes them the owner — the
  # first admin — and drops them into their own player URL.
  def create
    first = @host.players.empty?
    player = @host.players.create(player_params)
    if player.persisted?
      if first
        # The owner bootstraps themselves — no "added" log entry for that.
        @host.make_owner!(player)
        redirect_to player_path(player.uuid)
      else
        @host.log_add!(player, actor: current_player)
        # `added` lets the view autofocus the input only right after an add.
        redirect_to app_root_path(added: 1)
      end
    else
      redirect_to app_root_path, alert: player.errors.full_messages.to_sentence
    end
  end

  # PATCH claim — host URL only. Someone on an admin-less host says which player
  # they are; that player becomes the owner (first admin) and gets their own URL.
  def claim
    if @host.owner
      redirect_to player_path(@host.owner.uuid)
    else
      @host.make_owner!(@player)
      redirect_to player_path(@player.uuid)
    end
  end

  # PATCH — admin only. Saves the edited name. A bad name keeps us in editing.
  def update
    if @player.update(player_params)
      redirect_to app_root_path
    else
      redirect_to app_root_path(editing: @player.id), alert: @player.errors.full_messages.to_sentence
    end
  end

  # DELETE — admin only. Admins can't delete other admins (demote first).
  def destroy
    if @player.admin?
      redirect_to app_root_path(editing: @player.id), alert: "Demote #{@player.name} before deleting."
      return
    end
    @host.log_delete!(@player, actor: current_player)
    @player.destroy
    redirect_to app_root_path
  end

  # PATCH adjust_tickets — admin only.
  def adjust_tickets
    @host.adjust_ticket!(@player, params[:amount].to_i, actor: current_player)
    redirect_to app_root_path(editing: @player.id)
  end

  # PATCH promote — admin only. Flag a non-admin player as an admin.
  def promote
    @host.promote!(@player, by: current_player)
    redirect_to app_root_path(editing: @player.id)
  end

  # PATCH demote — admin only. Strip a non-owner admin's flag.
  def demote
    if @player.id == @host.owner_id
      redirect_to app_root_path(editing: @player.id), alert: "The owner can't be demoted."
    else
      @host.demote!(@player, by: current_player)
      redirect_to app_root_path(editing: @player.id)
    end
  end

  # PATCH gift — the acting player gives one of their tickets to @player.
  def gift
    @host.gift!(giver: current_player, recipient: @player)
    redirect_to app_root_path(gifting: @player.id)
  end

  # PATCH ungift — undo the acting player's most recent gift (latest log only).
  def ungift
    @host.undo_gift!(by: current_player)
    redirect_to app_root_path(gifting: @player.id)
  end

  private

  def set_player
    @player = @host.players.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name)
  end
end
