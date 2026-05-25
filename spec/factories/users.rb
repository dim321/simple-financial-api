FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }
    name { Faker::Name.last_name }

    trait :with_account do
      after(:create) do |user|
        create(:account, user: user)
      end
    end

    trait :with_active_account do
      after(:create) do |user|
        create(:account, user: user, status: 'active')
      end
    end

    trait :with_on_hold_account do
      after(:create) do |user|
        create(:account, user: user, status: 'on_hold')
      end
    end

    trait :with_closed_account do
      after(:create) do |user|
        create(:account, user: user, status: 'closed')
      end
    end
  end
end
