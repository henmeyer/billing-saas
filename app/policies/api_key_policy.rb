# frozen_string_literal: true

class ApiKeyPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def destroy? = admin?
end
