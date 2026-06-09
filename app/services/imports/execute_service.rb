class Imports::ExecuteService
  def self.call(import_job)
    new(import_job).call
  end

  def initialize(import_job)
    @import_job = import_job
    @account    = import_job.account
    @decisions  = import_job.decisions
    @result     = { imported: 0, updated: 0, skipped: 0, errors: [] }
  end

  def call
    @import_job.update!(status: "importing")

    preview = @import_job.preview

    (preview["new"] || []).each { |c| import_new(c) }

    (preview["duplicates"] || []).each do |c|
      email    = c["email"] || c[:email].to_s
      decision = @decisions[email] || "skip"
      process_duplicate(c, decision)
    end

    @import_job.update!(status: "done", result: @result)

  rescue StandardError => e
    @import_job.update!(
      status:        "failed",
      error_message: e.message,
      result:        @result
    )
    raise
  end

  private

  def import_new(data)
    ActiveRecord::Base.transaction do
      customer = Customer.create!(
        name:        data["name"]         || data[:name],
        email:       data["email"]        || data[:email],
        document:    data["document"]     || data[:document],
        phone:       data["phone"]        || data[:phone],
        external_id: data["external_ref"] || data[:external_ref],
        status:      "active",
        gateway_data: {
          @import_job.gateway => { "customer_id" => data["gateway_id"] || data[:gateway_id] }
        }
      )

      import_subscription(customer, data["subscription"] || data[:subscription])
      @result[:imported] += 1
    end
  rescue ActiveRecord::RecordInvalid => e
    @result[:errors] << { email: data["email"] || data[:email], message: e.message }
  end

  def process_duplicate(data, decision)
    case decision
    when "skip"
      @result[:skipped] += 1

    when "update"
      customer = Customer.find(data["existing_id"] || data[:existing_id])
      customer.update!(
        document: data["document"] || data[:document] || customer.document,
        phone:    data["phone"]    || data[:phone]    || customer.phone,
        gateway_data: customer.gateway_data.deep_merge({
          @import_job.gateway => { "customer_id" => data["gateway_id"] || data[:gateway_id] }
        })
      )
      import_subscription(customer, data["subscription"] || data[:subscription], update_existing: true)
      @result[:updated] += 1

    when "create"
      import_new(data)
    end
  rescue StandardError => e
    @result[:errors] << { email: data["email"] || data[:email], message: e.message }
  end

  def import_subscription(customer, sub_data, update_existing: false)
    return unless sub_data.present?

    sub_hash = sub_data.is_a?(Hash) ? sub_data.transform_keys(&:to_s) : {}
    return if sub_hash["gateway_subscription_id"].blank?

    existing = customer.subscriptions.find_by(
      gateway:                 @import_job.gateway,
      gateway_subscription_id: sub_hash["gateway_subscription_id"]
    )

    return if existing && !update_existing

    plan = find_matching_plan(sub_hash)

    customer.subscriptions.find_or_create_by!(
      gateway:                 @import_job.gateway,
      gateway_subscription_id: sub_hash["gateway_subscription_id"]
    ) do |s|
      s.plan                 = plan || Plan.active.first
      s.status               = "active"
      s.started_at           = Time.current
      s.current_period_start = Time.current.beginning_of_month
      s.current_period_end   = 1.month.from_now.beginning_of_month
    end
  end

  def find_matching_plan(sub_hash)
    if sub_hash["price_id"].present?
      plan = Plan.find_by(
        "gateway_data -> 'stripe' ->> 'price_id' = ?",
        sub_hash["price_id"]
      )
      return plan if plan
    end

    nil
  end
end
