FactoryBot.define do
  factory :account_user do
    account
    user
    role { "member" }

    trait(:owner)  { role { "owner" } }
    trait(:admin)  { role { "admin" } }
    trait(:member) { role { "member" } }
  end
end
