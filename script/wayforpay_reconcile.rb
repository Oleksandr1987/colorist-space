# Run with: bin/rails runner script/wayforpay_reconcile.rb
# Stop with Ctrl-C. Needed in development to reconcile recurring charges.
loop do
  Subscription.where.not(checkout_payment_id: nil).find_each do |subscription|
    begin
      Subscriptions::Reconcile.call(subscription)
    rescue Wayforpay::Error, ActiveRecord::StatementInvalid => e
      Rails.logger.warn("Reconciliation subscription=#{subscription.id}: #{e.class.name}")
    end
  end
  sleep 60
end
