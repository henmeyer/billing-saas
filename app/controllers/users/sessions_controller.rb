class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_tenant, raise: false

  def new
    render inertia: 'Auth/Login', props: {}
  end
end
