Rails.application.config.filter_parameters += [
  :merchantSignature, :merchantPassword, :secret_key, :recToken, :recTocken,
  :cardPan, :cardNumber, :cardCvv, :checkout_data
]
