FactoryBot.define do
  factory :user do
    name                  { Faker::Name.name }
    email                 { Faker::Internet.unique.email }
    password              { "password123" }
    password_confirmation { "password123" }

    factory :super_admin, class: "SuperAdmin"
  end
end
