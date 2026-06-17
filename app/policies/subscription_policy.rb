# frozen_string_literal: true

class SubscriptionPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = seller?
  def update?  = seller?
  def destroy? = manager?
  def cancel?  = manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:customer).merge(Customer.all)
    end
  end
end
