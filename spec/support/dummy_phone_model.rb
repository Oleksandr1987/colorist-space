class DummyPhoneModel
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Callbacks

  define_model_callbacks :validation

  attr_accessor :phone

  include PhoneValidator

  def valid?
    run_callbacks :validation do
      super
    end
  end
end
