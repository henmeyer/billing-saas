class Webhooks::BaseController < ActionController::API
  skip_before_action :verify_authenticity_token

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
end
