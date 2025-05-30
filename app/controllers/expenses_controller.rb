class ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_expense, only: %i[edit update destroy]

  auto_authorize :expense, only: %i[new create edit update destroy]
  after_action :verify_authorized, only: %i[new create edit update destroy]

  def index
    @expenses_by_month = current_user.expenses
      .order(spent_on: :desc)
      .group_by { |e| e.spent_on.strftime("%B %Y") }
  end

  def new
    @expense = current_user.expenses.build
  end

  def create
    @expense = current_user.expenses.build(expense_params)

    if @expense.save
      redirect_to expenses_path, notice: "Витрату успішно додано"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @expense.update(expense_params)
      redirect_to expenses_path, notice: "Витрату оновлено"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to expenses_path, notice: "Витрату видалено"
  end

  private

  def set_expense
    @expense = current_user.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:category, :note, :amount, :spent_on)
  end
end
