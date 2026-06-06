class IntegrationFieldConfig < ApplicationRecord
  belongs_to :integration
  belongs_to :license_type, optional: true
  belongs_to :credit_type,  optional: true

  FIELD_TYPES = %w[license credit].freeze
  validates :field_type, inclusion: { in: FIELD_TYPES }

  validate :exactly_one_type_present

  private

  def exactly_one_type_present
    if license_type_id.blank? && credit_type_id.blank?
      errors.add(:base, "Deve ter license_type ou credit_type")
    end
    if license_type_id.present? && credit_type_id.present?
      errors.add(:base, "Deve ter apenas um tipo")
    end
  end
end
