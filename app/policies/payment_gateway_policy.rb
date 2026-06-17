# frozen_string_literal: true

class PaymentGatewayPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
