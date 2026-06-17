# frozen_string_literal: true

class AccountUserPolicy < ApplicationPolicy
  def index?   = manager?
  def show?    = manager?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  # Não pode alterar role de alguém para um nível igual ou superior ao próprio
  def change_role?
    return false unless admin?

    my_level = user.account_user_for(ActsAsTenant.current_tenant)&.level || 0
    record.level < my_level
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(account: ActsAsTenant.current_tenant)
    end
  end
end
