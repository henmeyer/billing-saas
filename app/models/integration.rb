class Integration < ApplicationRecord
  acts_as_tenant :account

  AVAILABLE_EVENTS = %w[
    subscription.activated subscription.cancelled subscription.past_due
    subscription.renewed subscription.trial_ending plan.changed
    payment.received payment.failed credits.threshold_reached
    credits.depleted credits.recharged license.updated
  ].freeze

  validates :name,   presence: true
  validates :url,    presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :secret, presence: true

  scope :active, -> { where(active: true) }

  before_create :generate_secret

  def events_for(event_name)
    events.include?(event_name)
  end

  private

  def generate_secret
    self.secret ||= SecureRandom.hex(32)
  end
end
