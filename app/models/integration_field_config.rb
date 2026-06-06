class IntegrationFieldConfig < ApplicationRecord
  belongs_to :integration
  belongs_to :license_type, optional: true
  belongs_to :credit_type,  optional: true
  belongs_to :feature_type, optional: true

  FIELD_TYPES = %w[license credit feature].freeze
  validates :field_type, inclusion: { in: FIELD_TYPES }

  validate :exactly_one_type_present

  private

  def exactly_one_type_present
    present = [license_type_id, credit_type_id, feature_type_id].compact.count
    errors.add(:base, "Deve ter exatamente um tipo") unless present == 1
  end
end
