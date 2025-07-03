FactoryBot.define do
  factory :transaction do
    amount { 50.0 }
    currency { 'USD' }
    status { 'completed' }
    description { 'Test transaction' }
    transaction_type { 'deposit' }

    trait :deposit do
      transaction_type { 'deposit' }
      association :target_account, factory: :account
    end

    trait :withdrawal do
      transaction_type { 'withdrawal' }
      association :source_account, factory: :account
    end

    trait :transfer do
      transaction_type { 'transfer' }
      association :source_account, factory: :account
      association :target_account, factory: :account
    end

    trait :with_large_amount do
      amount { 500.0 }
    end

    trait :with_small_amount do
      amount { 5.0 }
    end

    trait :without_description do
      description { nil }
    end

    trait :with_custom_description do
      sequence(:description) { |n| "Custom transaction #{n}" }
    end

    trait :pending do
      status { 'pending' }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :reversed do
      status { 'reversed' }
    end
  end
end
