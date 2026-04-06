module PhotosHelper
  def optimized(photo)
    PhotoDecorator.decorate(photo).optimized
  end

  def thumb(photo)
    PhotoDecorator.decorate(photo).thumb
  end
end
