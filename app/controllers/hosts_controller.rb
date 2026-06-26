class HostsController < ApplicationController
  before_action :set_host, only: [ :show, :nominate, :reset ]

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

  # POST /hosts/:uuid/reset
  def reset
    @host.reset_nomination!
    redirect_to host_path(@host)
  end
end
