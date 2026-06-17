# frozen_string_literal: true

class WebhookLogPolicy < ApplicationPolicy
  def index? = manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:integration).merge(Integration.all)
    end
  end
end
