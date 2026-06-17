# frozen_string_literal: true

class ProductPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
