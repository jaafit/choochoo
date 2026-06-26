class LogsController < ApplicationController
  before_action :set_host

  PER_PAGE = 20

  # GET /hosts/:host_uuid/logs?page=N — 20 changes per page, newest first.
  def index
    @page  = [ params[:page].to_i, 1 ].max
    @total = @host.logs.count
    @logs  = @host.logs.order(id: :desc)
                  .offset((@page - 1) * PER_PAGE)
                  .limit(PER_PAGE)
    @has_next = @total > @page * PER_PAGE
  end
end
