# frozen_string_literal: true

class CustomerPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = seller?
  def update?  = seller?
  def destroy? = manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
