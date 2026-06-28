class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Resolves the request's credentials. A host UUID (params[:uuid]/[:host_uuid])
  # gives full control; a player UUID (params[:player_uuid]) gives a limited view
  # of that player's host — the host UUID never appears in player URLs.
  def set_host
    if params[:player_uuid]
      @current_player = Player.find_by(uuid: params[:player_uuid])
      @host = @current_player&.host
    else
      uuid = params[:host_uuid] || params[:uuid]
      @host = Host.find_by(uuid: uuid)
    end
    redirect_to root_path, alert: "That link is no longer valid." unless @host
  end

  # The player acting (nil when the host is acting).
  def current_player
    @current_player
  end
  helper_method :current_player

  def host_view?
    @current_player.nil?
  end
  helper_method :host_view?

  # An admin is a player flagged as such. The host view is never an admin — the
  # host URL only bootstraps the first admin, then redirects to the owner.
  def current_admin?
    !!@current_player&.admin?
  end
  helper_method :current_admin?

  # Only admins may edit tickets/names, delete players, promote/demote, or share
  # player links.
  def admin_only!
    redirect_to app_root_path, alert: "Not allowed." unless current_admin?
  end

  # --- Context-aware paths (host vs. player) used throughout the views --------

  def app_root_path(opts = {})
    host_view? ? host_path(@host, opts) : player_path(@current_player.uuid, opts)
  end
  helper_method :app_root_path

  def app_nominate_path
    host_view? ? nominate_host_path(@host) : player_nominate_path(@current_player.uuid)
  end
  helper_method :app_nominate_path

  def app_undo_path
    host_view? ? undo_host_path(@host) : player_undo_path(@current_player.uuid)
  end
  helper_method :app_undo_path

  def app_send_off_path
    host_view? ? send_off_host_path(@host) : player_send_off_path(@current_player.uuid)
  end
  helper_method :app_send_off_path

  def app_players_path
    host_view? ? host_players_path(@host) : player_players_path(@current_player.uuid)
  end
  helper_method :app_players_path

  def app_toggle_room_path(player)
    host_view? ? toggle_room_host_player_path(@host, player) : player_toggle_room_path(@current_player.uuid, player)
  end
  helper_method :app_toggle_room_path

  def app_gift_path(player)
    host_view? ? gift_host_player_path(@host, player) : player_gift_path(@current_player.uuid, player)
  end
  helper_method :app_gift_path

  def app_ungift_path(player)
    host_view? ? ungift_host_player_path(@host, player) : player_ungift_path(@current_player.uuid, player)
  end
  helper_method :app_ungift_path

  def app_logs_path(opts = {})
    host_view? ? host_logs_path(@host, opts) : player_logs_path(@current_player.uuid, opts)
  end
  helper_method :app_logs_path

  # The host itself (used to rename it). Renders only in the admin/player view.
  def app_host_path
    host_view? ? host_path(@host) : player_path(@current_player.uuid)
  end
  helper_method :app_host_path

  # Admin actions on a player. These render only in the player (admin) view, but
  # the host branch is kept for symmetry with the helpers above.
  def app_player_path(player)
    host_view? ? host_player_path(@host, player) : player_update_path(@current_player.uuid, player)
  end
  helper_method :app_player_path

  def app_adjust_tickets_path(player)
    host_view? ? adjust_tickets_host_player_path(@host, player) : player_adjust_tickets_path(@current_player.uuid, player)
  end
  helper_method :app_adjust_tickets_path

  def app_promote_path(player)
    host_view? ? promote_host_player_path(@host, player) : player_promote_path(@current_player.uuid, player)
  end
  helper_method :app_promote_path

  def app_demote_path(player)
    host_view? ? demote_host_player_path(@host, player) : player_demote_path(@current_player.uuid, player)
  end
  helper_method :app_demote_path
end
