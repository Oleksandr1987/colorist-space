module Wayforpay
  class Signature
    require 'digest'

    def self.generate(data_array, secret_key)
      signature_base_string = data_array.join(';')
      Digest::SHA1.hexdigest(secret_key + signature_base_string)
    end
  end
end
