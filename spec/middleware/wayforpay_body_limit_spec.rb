require "spec_helper"
require_relative "../../lib/wayforpay_body_limit"

RSpec.describe WayforpayBodyLimit do
  let(:app) { ->(env) { [ 200, {}, [ env["rack.input"].read ] ] } }
  let(:middleware) { described_class.new(app) }

  def env_for(body, length = nil)
    { "PATH_INFO" => "/subscription/payment_callback", "rack.input" => StringIO.new(body),
      "CONTENT_LENGTH" => length }
  end

  it "rejects a declared oversized body without reading it" do
    env = env_for("", "65537")
    input = env["rack.input"]
    allow(input).to receive(:read).and_call_original

    response = middleware.call(env)

    expect(response.first).to eq(413)
    expect(input).not_to have_received(:read)
  end

  it "rejects oversized input without Content-Length after a bounded read" do
    env = env_for("x" * 100_000)
    input = env["rack.input"]

    expect(middleware.call(env).first).to eq(413)
    expect(input.pos).to eq(65537)
  end

  it "does not trust an understated Content-Length" do
    expect(middleware.call(env_for("x" * 65537, "2")).first).to eq(413)
  end

  it "preserves a valid body for downstream middleware and the controller" do
    env = env_for("{\"ok\":true}")
    response = middleware.call(env)

    expect(response.first).to eq(200)
    expect(response.last).to eq([ "{\"ok\":true}" ])
    expect(env[described_class::BODY_KEY]).to eq("{\"ok\":true}")
  end

  it "allows a body at the exact limit" do
    expect(middleware.call(env_for("x" * 65536)).first).to eq(200)
  end

  it "also guards the trailing-slash route" do
    env = env_for("x" * 65537)
    env["PATH_INFO"] += "/"

    expect(middleware.call(env).first).to eq(413)
  end

  it "does not restrict another endpoint" do
    env = env_for("x" * 65537)
    env["PATH_INFO"] = "/clients"

    expect(middleware.call(env).first).to eq(200)
  end
end
