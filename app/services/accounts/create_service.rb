class Accounts::CreateService
  Result = Struct.new(:success?, :account, :user, :errors)

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      account = Account.create!(
        name: @params[:company_name]
      )

      user = account.users.create!(
        name:                  @params[:name],
        email:                 @params[:email],
        password:              @params[:password],
        password_confirmation: @params[:password_confirmation],
        role:                  "owner"
      )

      Seeds::DefaultTypesService.call(account)

      Result.new(true, account, user, [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(false, nil, nil, e.record.errors.full_messages)
  end
end
