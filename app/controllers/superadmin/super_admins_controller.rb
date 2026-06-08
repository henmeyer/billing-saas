class Superadmin::SuperAdminsController < Superadmin::BaseController
  def index
    super_admins = SuperAdmin.order(created_at: :desc)

    render inertia: "Superadmin/SuperAdmins/Index", props: {
      super_admins: super_admins.map { |sa| serialize(sa) },
      current_id:   current_user.id
    }
  end

  def new
    render inertia: "Superadmin/SuperAdmins/New", props: {
      errors: {}
    }
  end

  def create
    sa = SuperAdmin.new(
      name:                  params[:name],
      email:                 params[:email],
      password:              params[:password],
      password_confirmation: params[:password_confirmation]
    )

    if sa.save
      redirect_to superadmin_super_admins_path,
                  notice: "SuperAdmin criado com sucesso."
    else
      render inertia: "Superadmin/SuperAdmins/New", props: {
        errors: sa.errors.as_json
      }
    end
  end

  def destroy
    sa = SuperAdmin.find(params[:id])

    if sa.id == current_user.id
      redirect_to superadmin_super_admins_path,
                  alert: "Você não pode remover a si mesmo."
      return
    end

    if SuperAdmin.count <= 1
      redirect_to superadmin_super_admins_path,
                  alert: "Deve existir ao menos um SuperAdmin."
      return
    end

    sa.destroy!
    redirect_to superadmin_super_admins_path, notice: "SuperAdmin removido."
  end

  private

  def serialize(sa)
    {
      id:         sa.id,
      name:       sa.name,
      email:      sa.email,
      created_at: sa.created_at.strftime("%d/%m/%Y"),
    }
  end
end
