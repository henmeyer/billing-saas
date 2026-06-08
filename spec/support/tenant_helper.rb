module TenantHelper
  def with_tenant(account, &block)
    ActsAsTenant.with_tenant(account, &block)
  end

  def set_tenant(account)
    ActsAsTenant.current_tenant = account
  end
end

RSpec.configure do |config|
  config.include TenantHelper
end
