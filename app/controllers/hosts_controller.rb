class HostsController < ApplicationController
  before_action :set_host, only: [ :show, :nominate, :undo, :send_off ]

  # GET / — no host in the URL, so create one and put its UUID in the URL.
  def bootstrap
    host = Host.create!
    redirect_to host_path(host)
  end

  # GET /hosts/:uuid
  def show
  end

  # POST /hosts/:uuid/nominate
  def nominate
    @host.nominate!
    redirect_to host_path(@host)
  end

  # POST /hosts/:uuid/undo — undo the nominate, or restore the last send-off.
  def undo
    if @host.selecting?
      @host.cancel_nomination!
    elsif @host.undoable_send_off?
      @host.restore_send_off!
    end
    redirect_to host_path(@host)
  end

  # POST /hosts/:uuid/send_off — commit the round; nominee + selected leave.
  # The selection (member_ids) comes from the client, not the server.
  def send_off
    @host.send_off!(params[:member_ids] || [])
    redirect_to host_path(@host)
  end
end
