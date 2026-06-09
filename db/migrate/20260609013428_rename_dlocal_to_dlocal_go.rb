class RenameDlocalToDlocalGo < ActiveRecord::Migration[7.1]
  def change
    execute "UPDATE payment_gateways SET provider = 'dlocal_go' WHERE provider = 'dlocal'"
    execute "UPDATE subscriptions SET gateway = 'dlocal_go' WHERE gateway = 'dlocal'"
    execute "UPDATE charges SET gateway = 'dlocal_go' WHERE gateway = 'dlocal'"
  end
end
