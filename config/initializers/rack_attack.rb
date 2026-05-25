# frozen_string_literal: true

class Rack::Attack
  throttle("auth/sign_in/ip", limit: 10, period: 60) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/sign_in"
  end

  throttle("accounts/transfer/ip", limit: 30, period: 60) do |req|
    req.ip if req.post? && req.path == "/api/v1/accounts/transfer"
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    headers = {
      "Content-Type" => "application/json",
      "RateLimit-Limit" => match_data[:limit].to_s,
      "RateLimit-Remaining" => "0",
      "RateLimit-Reset" => (now + match_data[:period]).to_s
    }

    body = {
      status: {
        code: 429,
        message: "Too many requests. Retry later."
      }
    }.to_json

    [ 429, headers, [ body ] ]
  end
end
