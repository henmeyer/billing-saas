class Portal::SessionsController < Portal::BaseController
  skip_before_action :authenticate_portal!, only: [:expired]

  def expired
    render inertia: "Portal/Expired", props: {}
  end

  def destroy
    current_portal_session&.destroy
    redirect_to portal_expired_path
  end
end
