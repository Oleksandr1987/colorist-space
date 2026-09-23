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

  it "gets paid access from the subscription" do
    user = create(:user)
    user.subscription.update!(plan: "monthly", current_period_start: Time.current,
      current_period_end: 1.month.from_now)

    expect(user.has_active_subscription?).to be(true)
  end
end
