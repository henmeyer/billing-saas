class Webhooks::SyncLicensesJob < ApplicationJob
  queue_as :webhooks

  def perform(payload)
    customer = Customer.find_by(external_id: payload["customer_id"])
    return unless customer

    ActsAsTenant.current_tenant = customer.account

    payload["licenses"].each do |license_key, used_count|
      license_type = LicenseType.find_by(key: license_key)
      next unless license_type

      customer.metadata["license_usage"] ||= {}
      customer.metadata["license_usage"][license_key] = used_count.to_i
    end

    customer.save!
  end
end
