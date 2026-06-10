class Portal::CheckoutsController < Portal::BaseController
  def show
    set_tenant!
    charge = current_customer.charges.find(params[:charge_id])

    render inertia: "Portal/Checkout", props: {
      charge: {
        id:             charge.id,
        amount_cents:   charge.amount_cents,
        status:         charge.status,
        gateway:        charge.gateway,
        redirect_url:   charge.redirect_url,
        pix_qr_code:   charge.charge_data["pix_qr_code"],
        pix_code:       charge.charge_data["pix_copy_paste"],
        boleto_url:     charge.charge_data["boleto_url"],
        boleto_barcode: charge.charge_data["boleto_barcode"],
        due_date:       charge.due_date&.strftime("%d/%m/%Y")
      },
      portal_config: portal_config,
      branding:      branding
    }
  end

  def status
    set_tenant!
    charge = current_customer.charges.find(params[:charge_id])
    render json: { status: charge.status, paid: charge.status == "paid" }
  end
end
