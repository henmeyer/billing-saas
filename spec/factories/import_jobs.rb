FactoryBot.define do
  factory :import_job do
    association :account
    association :user
    gateway { "asaas" }
    status  { "pending" }
    preview   { {} }
    decisions { {} }
    result    { {} }
  end
end
