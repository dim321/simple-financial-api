require "rails_helper"

RSpec.describe "financial database constraints" do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:now) { Time.current }

  it "rejects negative account balances at the database level" do
    expect {
      Account.insert_all!(
        [
          {
            user_id: user.id,
            account_number: "99999999999999999999",
            currency: "USD",
            status: "active",
            balance_cents: -1,
            created_at: now,
            updated_at: now
          }
        ]
      )
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "rejects non-positive transaction amounts at the database level" do
    expect {
      Transaction.insert_all!(
        [
          {
            target_account_id: account.id,
            amount_cents: 0,
            currency: "USD",
            transaction_type: Transaction.transaction_types.fetch("deposit"),
            status: Transaction.statuses.fetch("completed"),
            created_at: now,
            updated_at: now
          }
        ]
      )
    }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
