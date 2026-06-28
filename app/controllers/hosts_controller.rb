class HostsController < ApplicationController
  before_action :set_host, only: [ :show, :nominate, :undo, :send_off ]

  # GET / — no host in the URL, so create one and put its UUID in the URL.
  def bootstrap
    host = Host.create!
    redirect_to host_path(host)
  end

  # GET /hosts/:uuid  or  /player/:player_uuid
  #
  # Once the host has an owner, the host URL is no longer a control surface — it
  # redirects to the owner's player URL. Before that it bootstraps the first admin
  # (add-yourself, or "Which player are you?"); see the view.
  def show
    redirect_to player_path(@host.owner.uuid) if host_view? && @host.owner
  end

  # POST nominate — host or any player may nominate (no need to be present).
  def nominate
    @host.nominate!(actor: current_player)
    redirect_to app_root_path
  end

  # POST undo — host can undo the latest action; a player only their own latest.
  def undo
    if @host.can_undo_latest?(current_player)
      if @host.selecting?
        @host.cancel_nomination!
      elsif @host.undoable_send_off?
        @host.restore_send_off!
      end
    end
    redirect_to app_root_path
  end

  # POST send_off — commit the round; selection (member_ids) comes from the client.
  def send_off
    @host.send_off!(params[:member_ids] || [], actor: current_player)
    redirect_to app_root_path
  end
end
