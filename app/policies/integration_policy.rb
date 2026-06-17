# frozen_string_literal: true

class IntegrationPolicy < ApplicationPolicy
  def index?   = manager?
  def show?    = manager?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
