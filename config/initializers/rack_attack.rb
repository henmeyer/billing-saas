class Rack::Attack
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("api/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  self.throttled_responder = lambda do |req|
    [429, { "Content-Type" => "application/json" },
     [{ error: "Muitas requisições. Tente novamente em breve." }.to_json]]
  end
end

Rails.application.config.middleware.use Rack::Attack
