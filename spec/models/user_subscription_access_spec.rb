require "rails_helper"
RSpec.describe User do
  it "creates a trial for a new registration" do
    user = create(:user)

    expect(user.on_trial?).to be(true)
    expect(user.subscription.trial_ends_at).to be_within(1.second).of(user.created_at + 7.days)
  end

  it "grants superadmin access independently of a paid plan" do
    user = create(:user, :superadmin)
    user.subscription.update!(plan: "none", trial_ends_at: nil)

    expect(user.has_write_access?).to be(true)
  end

  it "uses Subscription after migration instead of old User fields" do
    user = create(:user)
    user.update!(subscription_expires_at: 1.year.from_now.to_date)

    expect(user.has_active_subscription?).to be(false)
  end
end
