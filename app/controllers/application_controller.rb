class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Loads the host named in the URL. Works for both the host's own routes
  # (params[:uuid]) and nested player routes (params[:host_uuid]).
  def set_host
    uuid = params[:host_uuid] || params[:uuid]
    @host = Host.find_by(uuid: uuid)
    redirect_to root_path, alert: "That host no longer exists." unless @host
  end

  # Authorization is possession-based: anyone holding the host's UUID controls
  # it. A richer role model can hook in here later (e.g. a spectator token).
  def current_role
    @host ? :admin : :visitor
  end
  helper_method :current_role

  def admin?
    current_role == :admin
  end
  helper_method :admin?
end
