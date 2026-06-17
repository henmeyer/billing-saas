# frozen_string_literal: true

class ImportJobPolicy < ApplicationPolicy
  def index?   = manager?
  def show?    = manager?
  def create?  = manager?
  def decide?  = manager?
  def execute? = manager?
end
