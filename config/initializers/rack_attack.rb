# Rate limiting via rack-attack. Weekly throttles guard the two things a bad
# actor can spam: minting hosts and writing log rows.
#
#   * By IP   — 5 new hosts per week
#   * By IP   — 300 new log entries per week
#   * By Host — 60 new log entries per week (shared across all that host's people)
#   * By non-admin Player — 20 new log entries per week
#
# Undo/ungift DELETE log rows rather than create them, so they're deliberately
# left unthrottled: undoing then redoing nets a free action, which is fine — the
# point is to bound how fast the logs table grows, and a delete shrinks it.
#
# rack-attack sits after Rack::MethodOverride in the stack, so request_method is
# the real verb (PATCH/DELETE), letting us tell players#update (rename, no log)
# apart from players#destroy (logs) on the shared /players/:id path.

class Rack::Attack
  # In development/test the 5-hosts-per-week IP cap would block routine local
  # clicking (every GET / mints a host), so limit throttling to production.
  self.enabled = Rails.env.production?

  # Single-process Puma (threads only, no workers) means an in-process store is
  # both shared across all request threads and free of any extra service —
  # important on the 512 MB box. Counts reset on deploy/restart; acceptable for
  # abuse limiting (these are weekly caps, not accounting).
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  class Request < ::Rack::Request
    # Paths that create a Log row, by HTTP verb. Both the host URL
    # (/hosts/:uuid/...) and the player URL (/player/:player_uuid/...) reach the
    # same actions, hence the shared prefix.
    SEND_OFF   = %r{\A/(?:hosts|player)/[^/]+/send_off\z}
    PLAYERS    = %r{\A/(?:hosts|player)/[^/]+/players\z}
    DESTROY    = %r{\A/(?:hosts|player)/[^/]+/players/\d+\z}
    MEMBER_LOG = %r{\A/(?:hosts|player)/[^/]+/players/\d+/(?:adjust_tickets|gift|promote|demote)\z}

    # The real client IP, not the proxy's. We deploy behind Kamal's proxy (+
    # Thruster), so the connecting peer is a Docker-internal address and the
    # client lives in X-Forwarded-For. ActionDispatch::RemoteIp runs earlier in
    # the stack and has already resolved this with trusted-proxy handling (it
    # trusts the private ranges the Docker network uses), so we reuse its result
    # rather than Rack's own req.ip, which would key throttles on the proxy.
    def remote_ip
      @remote_ip ||= (env["action_dispatch.remote_ip"] || ip).to_s
    end

    # GET / always mints a fresh host (HostsController#bootstrap), so every hit
    # here is one new host.
    def bootstrap?
      get? && path == "/"
    end

    # True for the endpoints that write a log entry. nominate/state/show, host
    # rename, claim, ungift and undo all write no log, so they're absent.
    def log_write?
      case request_method
      when "POST"   then path.match?(SEND_OFF) || path.match?(PLAYERS)
      when "DELETE" then path.match?(DESTROY)
      when "PATCH"  then path.match?(MEMBER_LOG)
      else false
      end
    end

    def host_uuid
      path[%r{\A/hosts/([^/]+)}, 1]
    end

    def player_uuid
      path[%r{\A/player/([^/]+)}, 1]
    end

    # The player acting via their own URL (nil for host-URL requests). Memoized so
    # the two log throttles share a single lookup per request.
    def acting_player
      return @acting_player if defined?(@acting_player)
      @acting_player = player_uuid && Player.find_by(uuid: player_uuid)
    end

    # The host this request acts on, reached by either URL form. One indexed
    # lookup, memoized; only ever called for log-writing requests.
    def throttle_host_id
      return @throttle_host_id if defined?(@throttle_host_id)
      @throttle_host_id =
        if host_uuid
          Host.where(uuid: host_uuid).pick(:id)
        else
          acting_player&.host_id
        end
    end

    # A non-admin player acting via their own URL. Admins skip the tighter
    # per-player cap (they still count against the per-host cap).
    def non_admin_player_id
      p = acting_player
      p.id if p && !p.admin?
    end
  end
end

# 1) New hosts per IP.
Rack::Attack.throttle("hosts/ip", limit: 10, period: 1.week) do |req|
  req.remote_ip if req.bootstrap?
end

# 2) New log entries per host (shared budget across the host's admins + players).
Rack::Attack.throttle("logs/host", limit: 60, period: 1.week) do |req|
  "host:#{req.throttle_host_id}" if req.log_write? && req.throttle_host_id
end

# 3) New log entries per non-admin player.
Rack::Attack.throttle("logs/player", limit: 20, period: 1.week) do |req|
  "player:#{req.non_admin_player_id}" if req.log_write? && req.non_admin_player_id
end

# 4) New log entries per IP (a coarse cap across whatever hosts/players an IP drives).
Rack::Attack.throttle("logs/ip", limit: 300, period: 1.week) do |req|
  req.remote_ip if req.log_write?
end
