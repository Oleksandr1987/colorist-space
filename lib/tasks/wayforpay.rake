namespace :wayforpay do
  desc "Reconcile initial payments and regular agreements; no card charges are initiated"
  task reconcile: :environment do
    Subscription.where.not(checkout_payment_id: nil).find_each do |subscription|
      begin
        Subscriptions::Reconcile.call(subscription)
      rescue Wayforpay::Error => e
        warn "Subscription #{subscription.id}: #{e.message}"
      end
    end
    puts "Unmatched callbacks: #{WayforpayEvent.where(state: 'unmatched').count}"
  end
end
