class DashboardController < ApplicationController
  # Cross-host, read-only stats. The shell page (#index) is public so the browser
  # can boot the Stimulus controller; the actual data (#data) is gated by a token
  # the browser holds in localStorage and sends in a header. No token / wrong
  # token => no data. There is no write action here — it's purely for stats.
  PER_PAGE = 200

  before_action :require_token, only: :data

  # GET /dashboard — static shell. JS fetches #data with the token.
  def index
  end

  # GET /dashboard/data?page=N — paginated logs across every host, plus counts.
  # Rendered as an HTML fragment (no layout) injected by the dashboard controller.
  def data
    @page  = [ params[:page].to_i, 1 ].max
    @total = Log.count
    @logs  = Log.includes(:host).order(id: :desc)
                .offset((@page - 1) * PER_PAGE)
                .limit(PER_PAGE)
    @has_next = @total > @page * PER_PAGE

    @stats = {
      hosts:           Host.count,
      players:         Player.count,
      log_entries:     @total,
      games:           Log.where(action: "send_off").count,
      tickets:         Player.sum(:tickets),
      new_hosts_30d:   Host.where("created_at > ?", 30.days.ago).count,
      new_players_30d: Player.where("created_at > ?", 30.days.ago).count,
      new_games_30d:   Log.where(action: "send_off").where("created_at > ?", 30.days.ago).count
    }

    render layout: false
  end

  private

  # Constant-time compare of the browser-supplied token against the one in
  # encrypted credentials (decryptable only with config/master.key, which is not
  # in git). Missing/blank/mismatched => 204 No Content, so the page shows nothing.
  def require_token
    expected = Rails.application.credentials.someonepicktoken.to_s
    given    = request.headers["X-Someonepick-Token"].to_s
    return if expected.present? &&
              ActiveSupport::SecurityUtils.secure_compare(given, expected)

    head :no_content
  end
end
