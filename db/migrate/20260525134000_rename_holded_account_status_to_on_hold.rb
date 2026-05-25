class RenameHoldedAccountStatusToOnHold < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :accounts, name: "accounts_status_supported"

    execute "UPDATE accounts SET status = 'on_hold' WHERE status = 'holded'"

    add_check_constraint :accounts,
                         "status IN ('active', 'on_hold', 'closed')",
                         name: "accounts_status_supported",
                         validate: false
  end

  def down
    remove_check_constraint :accounts, name: "accounts_status_supported"

    execute "UPDATE accounts SET status = 'holded' WHERE status = 'on_hold'"

    add_check_constraint :accounts,
                         "status IN ('active', 'holded', 'closed')",
                         name: "accounts_status_supported",
                         validate: false
  end
end
