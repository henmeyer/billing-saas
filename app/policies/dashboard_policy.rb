# frozen_string_literal: true

# Policy especial para o dashboard (não é um model)
class DashboardPolicy < ApplicationPolicy
  def full_stats?  = manager?
  def basic_stats? = true
end
