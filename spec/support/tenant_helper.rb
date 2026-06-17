module TenantHelper
  def with_tenant(account, &)
    ActsAsTenant.with_tenant(account, &)
  end

  def set_tenant(account)
    ActsAsTenant.current_tenant = account
  end
end

RSpec.configure do |config|
  config.include TenantHelper
end
