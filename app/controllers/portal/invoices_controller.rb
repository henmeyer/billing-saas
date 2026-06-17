class Portal::InvoicesController < Portal::BaseController
  before_action :require_invoice_history!

  def index
    set_tenant!
    charges = current_customer.charges
                              .where(subscription: current_subscription)
                              .order(created_at: :desc)
                              .limit(20)

    render inertia: "Portal/Invoices/Index", props: {
      charges:       charges.map { |c| serialize(c) },
      portal_config: portal_config,
      branding:      branding
    }
  end

  private

  def require_invoice_history!
    return if portal_config["show_invoice_history"]

    redirect_to portal_dashboard_path(token: portal_token),
                alert: "Histórico não disponível."
  end

  def serialize(c)
    {
      id:         c.id,
      amount:     c.amount_cents / 100.0,
      status:     c.status,
      gateway:    c.gateway,
      paid_at:    c.paid_at&.strftime("%d/%m/%Y"),
      due_date:   c.due_date&.strftime("%d/%m/%Y"),
      created_at: c.created_at.strftime("%d/%m/%Y")
    }
  end
end
