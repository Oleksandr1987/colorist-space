require "rails_helper"
require_relative "../../../lib/wayforpay/signature"
RSpec.describe Wayforpay::Signature do
  it "matches the standard HMAC-MD5 test vector" do
    expect(described_class.generate([ "Hi There" ], [ 11 ].pack("C") * 16)).to eq("9294727a3638bb1c13f48ef8158bfc9d")
  end

  it "matches an independent UTF-8 HMAC-MD5 fixture, including merchantDomainName" do
    fields = [ "test_merchant", "www.market.ua", "DH783023", 1415379863, "1547.36", "UAH",
      "Процесор Intel Core i5-4670 3.4GHz", "Пам'ять Kingston DDR3-1600 4096MB PC3-12800", 1, 1, 1000, "547.36" ]

    expect(described_class.generate(fields, "dhkq3vUi94{Z!5frxs(02ML")).to eq("4941ea0c7f5b4833c2bd06b1fefcdc0b")
  end
end
