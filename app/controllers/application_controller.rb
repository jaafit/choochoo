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

  # Only the host may edit tickets, delete players, or share player links.
  def host_only!
    redirect_to app_root_path, alert: "Not allowed." unless host_view?
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
end
