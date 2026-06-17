# frozen_string_literal: true

class PlanPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
