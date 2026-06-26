class Webhooks::BaseController < ActionController::API
  private

  def verify_hmac_signature(secret, header_name: "X-Webhook-Signature")
    signature = request.headers[header_name]
    body      = request.body.read
    request.body.rewind

    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"

    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      render json: { error: "Assinatura inválida" }, status: :unauthorized
      return false
    end
    true
  end

  def verify_static_token(secret, header_name:)
    token = request.headers[header_name]

    unless ActiveSupport::SecurityUtils.secure_compare(secret.to_s, token.to_s)
      render json: { error: "Token inválido" }, status: :unauthorized
      return false
    end
    true
  end
end
