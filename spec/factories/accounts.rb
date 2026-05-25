FactoryBot.define do
  factory :account do
    association :user
    balance { 100.0 }
    status { 'active' }

    trait :with_zero_balance do
      balance { 0.0 }
    end

    trait :with_high_balance do
      balance { 1000.0 }
    end

    trait :active do
      status { 'active' }
    end

    trait :on_hold do
      status { 'on_hold' }
    end

    trait :closed do
      status { 'closed' }
    end

    trait :with_transactions do
      after(:create) do |account|
        create_list(:transaction, 3, source_account: account, transaction_type: 'withdraw')
        create_list(:transaction, 2, target_account: account, transaction_type: 'deposit')
      end
    end
  end
end
