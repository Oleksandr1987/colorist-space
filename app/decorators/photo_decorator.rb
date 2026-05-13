class PhotoDecorator < Draper::Decorator
  delegate_all
  # :nocov:
  def optimized
    object.variant(
      resize_to_limit: [ 1280, 1280 ],
      saver: { quality: 80 }
    )
  end

  def thumb
    object.variant(
      resize_to_fill: [ 400, 400 ],
      saver: { quality: 75 }
    )
  end
  # :nocov:
end
