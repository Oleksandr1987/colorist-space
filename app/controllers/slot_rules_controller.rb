class SlotRulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_slot_rule, only: %i[edit update destroy]

  def index
    @slot_rules = current_user.slot_rules.order(:start_time)
    @slot_rule = SlotRule.new
  end

  def create
    @slot_rule = current_user.slot_rules.build(slot_rule_params)
    build_schedule(@slot_rule)

    if @slot_rule.save
      redirect_to slot_rules_path, notice: "Rule created."
    else
      @slot_rules = current_user.slot_rules.order(:start_time)
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @slot_rule.update(slot_rule_params)
      build_schedule(@slot_rule)
      @slot_rule.save
      redirect_to slot_rules_path, notice: "Rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @slot_rule.destroy
    redirect_to slot_rules_path, notice: "Rule deleted."
  end

  private

  def set_slot_rule
    @slot_rule = current_user.slot_rules.find(params[:id])
  end

  def slot_rule_params
    params.require(:slot_rule).permit(:start_time, :end_time, weekdays: [])
  end

  def build_schedule(rule)
    return if rule.start_time.blank? || rule.weekdays.blank?

    base_time = Time.zone.now.change(hour: rule.start_time.hour, min: rule.start_time.min)
    weekdays = rule.weekdays.map(&:to_sym)

    schedule = IceCube::Schedule.new(base_time)
    schedule.add_recurrence_rule IceCube::Rule.weekly.day(*weekdays)
    rule.ice_cube_schedule = schedule
  end
end
