class Api::V1::PortalSessionsController < Api::V1::BaseController
  def create
    customer = find_customer_by_external_id!(params[:external_id])
    return unless customer

    session, token = PortalSession.generate!(
      customer:    customer,
      integration: current_integration
    )

    portal_url = "#{request.base_url}/portal/#{token}"

    render json: {
      url:        portal_url,
      expires_in: PortalSession::TOKEN_TTL.to_i,
      expires_at: session.expires_at.iso8601
    }
  end
end
