class Imports::PreviewService
  def self.call(import_job)
    new(import_job).call
  end

  def initialize(import_job)
    @import_job = import_job
    @account    = import_job.account
  end

  def call
    @import_job.update!(status: "fetching")

    gateway  = @account.payment_gateways.find_by!(provider: @import_job.gateway)
    fetcher  = fetcher_for(@import_job.gateway, gateway)
    customers = fetcher.call

    existing_emails = Customer.pluck(:email).to_set

    new_customers       = []
    duplicate_customers = []

    customers.each do |c|
      email = c[:email] || c["email"]
      next if email.blank?

      if existing_emails.include?(email)
        existing = Customer.find_by(email: email)
        duplicate_customers << c.merge(existing_id: existing.id)
      else
        new_customers << c
      end
    end

    @import_job.update!(
      status:  "preview_ready",
      preview: {
        "new"        => new_customers,
        "duplicates" => duplicate_customers,
        "total"      => customers.length,
        "fetched_at" => Time.current.iso8601
      }
    )

  rescue StandardError => e
    @import_job.update!(
      status:        "failed",
      error_message: e.message
    )
    raise
  end

  private

  def fetcher_for(gateway, gateway_record)
    case gateway
    when "asaas"  then Imports::FetchAsaasService.new(gateway_record)
    when "stripe" then Imports::FetchStripeService.new(gateway_record)
    else raise "Gateway #{gateway} não suportado para importação"
    end
  end
end
