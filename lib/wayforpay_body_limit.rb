# frozen_string_literal: true

require "stringio"
require "rack/utils"

class WayforpayBodyLimit
  MAX_BYTES = 64 * 1024
  BODY_KEY = "colorist.wayforpay_body"

  def initialize(app)
    @app = app
  end

  def call(env)
    path = Rack::Utils.unescape_path(env["PATH_INFO"].to_s).squeeze("/").delete_suffix("/")
    return @app.call(env) unless path == "/subscription/payment_callback"
    return too_large if env["CONTENT_LENGTH"].to_i > MAX_BYTES

    body = +"".b
    input = env["rack.input"]
    if input
      loop do
        chunk = input.read(MAX_BYTES + 1 - body.bytesize)
        break if chunk.nil? || chunk.empty?
        body << chunk
        return too_large if body.bytesize > MAX_BYTES
      end
    end

    # Subsequent middleware and Rails see only the already bounded body.
    env[BODY_KEY] = body
    env["rack.input"] = StringIO.new(body)
    env["CONTENT_LENGTH"] = body.bytesize.to_s
    @app.call(env)
  end

  private

  def too_large
    body = "Payload too large\n"
    [ 413, { "content-type" => "text/plain; charset=utf-8",
      "content-length" => body.bytesize.to_s }, [ body ] ]
  end
end
