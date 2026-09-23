require "rails_helper"
RSpec.describe "Account deletion guard" do
  include Devise::Test::IntegrationHelpers

  it "preserves active paid access even without provider history" do
    user = create(:user)
    user.subscription.update!(source: "wayforpay", plan: "monthly", status: "active",
      current_period_end: 5.months.from_now, auto_renew: false)

    expect(user.subscription.subscription_payments.exists?).to be(false)
    expect(user.subscription.wayforpay_order_reference).to be_nil
    sign_in user

    expect { delete user_registration_path }.not_to change(User, :count)
    expect(response).to redirect_to(settings_subscription_path(locale: I18n.locale))
    expect(user.reload.subscription.paid_access?).to be(true)
  end

  it "allows deletion of a trial without payments or a provider agreement" do
    user = create(:user)
    sign_in user

    expect { delete user_registration_path }.to change(User, :count).by(-1)
  end
end
