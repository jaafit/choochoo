class HostsController < ApplicationController
  before_action :set_host, only: [ :show, :state, :update, :nominate, :undo, :send_off ]
  before_action :admin_only!, only: [ :update ]

  # GET / — no host in the URL, so create one and put its UUID in the URL.
  def bootstrap
    host = Host.create!
    redirect_to host_path(host)
  end

  # GET /hosts/:uuid  or  /player/:player_uuid
  #
  # Before the host has an owner, the host URL bootstraps the first admin
  # (add-yourself, or "Which player are you?"); see the view. Becoming an owner
  # clears the host UUID (see Host#make_owner!), so for hosts created since then
  # the host URL stops resolving entirely. The redirect below only fires for
  # legacy hosts that still carry a UUID alongside an owner.
  def show
    redirect_to player_path(@host.owner.uuid) if host_view? && @host.owner
  end

  # PATCH — admin only. Rename the host. Strong params + Active Record keep the
  # value parameterized, so there's no SQL-injection surface.
  def update
    @host.update(host_params)
    redirect_to app_root_path, alert: @host.errors.full_messages.to_sentence.presence
  end

  # GET state.json — the authoritative roster (names + ticket totals) for the
  # client to reconcile against after a change. No round state: presence and the
  # in-progress pick live only in the browser.
  def state
    render json: { roster: @host.roster_json }
  end

  # POST nominate — pick a winner among the client's present ids. Stateless: no
  # tickets spent, no log written. Returns the winner and the fresh roster.
  def nominate
    winner = @host.pick_winner(params[:present_ids] || [])
    render json: { winner_id: winner&.id, roster: @host.roster_json }
  end

  # POST send_off — commit the round from client ids: chosen + who was sent to
  # their game. Returns the roster and the new log id (so the client can offer an
  # immediate "undo send"). Trusts only the ids, never client ticket numbers.
  def send_off
    log = @host.send_off!(params[:chosen_id], params[:member_ids] || [], actor: current_player)
    render json: { roster: @host.roster_json, log_id: log&.id }
  end

  # POST undo — reverse the latest send-off, but only if it's still the latest
  # log (`log_id` must match). From the home page a player may undo only their
  # own; from the logs view an admin may undo anyone's (params[:admin]).
  def undo
    log = @host.latest_log
    if log && log.id == params[:log_id].to_i && log.action == "send_off"
      authorized = params[:admin].present? ? current_admin? : log.actor_player_id == current_player&.id
      @host.restore_send_off!(log) if authorized
    end

    # After undoing, the now-latest action may itself be the player's own
    # send-off — report it (with the picker's name) so the home page can offer to
    # undo that one too, labelled so each successive undo visibly changes.
    latest = @host.latest_log
    undo_log = (latest&.action == "send_off" && @host.can_undo_latest?(current_player)) ? latest : nil

    respond_to do |format|
      format.json { render json: { roster: @host.roster_json, undo_log_id: undo_log&.id, undo_log_name: undo_log&.player_name } }
      # 303 so Turbo follows the redirect and re-renders the logs page, where the
      # new latest action then shows its own undo button.
      format.html { redirect_to(params[:admin].present? ? app_logs_path : app_root_path, status: :see_other) }
    end
  end

  private

  def host_params
    params.require(:host).permit(:name)
  end
end
