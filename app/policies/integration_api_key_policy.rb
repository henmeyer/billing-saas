# frozen_string_literal: true

class IntegrationApiKeyPolicy < ApplicationPolicy
  def index?   = admin?
  def create?  = admin?
  def destroy? = admin?
end
