import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "modalImage", "photo", "photoContainer", "dot"]
  static values = {
    photos: Array,
    index: Number,
    mode: String // "fullscreen" or "inline"
  }

  connect() {
    // Якщо photosValue є — inline viewer (service_notes/show)
    if (this.hasPhotosValue) {
      this.modeValue = "inline"
      this.indexValue = 0
      this.showInlinePhoto(0)
      this.setupSwipeInline()
      return
    }

    // Інакше fullscreen режим (clients/show)
    this.modeValue = "fullscreen"
    this.photos = Array.from(document.querySelectorAll("[data-photo-url]"))
    this.index = 0

    this.setupKeyboard()
    this.setupSwipeMobileFullscreen()
    this.setupSwipeDesktopFullscreen()
  }

  /* -----------------------------------
     FULLSCREEN MODE (clients/show)
  ------------------------------------*/

  show(event) {
    if (this.modeValue !== "fullscreen") return

    const wrapper = event.currentTarget
    if (wrapper.classList.contains("long-press")) return

    const img = wrapper.querySelector("img")
    const url = img.dataset.photoUrl

    this.index = this.photos.findIndex(p => p.dataset.photoUrl === url)
    this.openFullscreen(url)
  }

  openFullscreen(url) {
    this.modalImageTarget.src = url
    this.modalTarget.classList.remove("hidden")
  }

  close() {
    if (this.modeValue !== "fullscreen") return
    this.modalTarget.classList.add("hidden")
    this.modalImageTarget.src = ""
  }

  next() {
    if (this.modeValue === "fullscreen") {
      this.index = (this.index + 1) % this.photos.length
      this.modalImageTarget.src = this.photos[this.index].dataset.photoUrl
    } else {
      this.nextInline()
    }
  }

  prev() {
    if (this.modeValue === "fullscreen") {
      this.index = (this.index - 1 + this.photos.length) % this.photos.length
      this.modalImageTarget.src = this.photos[this.index].dataset.photoUrl
    } else {
      this.prevInline()
    }
  }

  setupKeyboard() {
    window.addEventListener("keydown", e => {
      if (this.modalTarget.classList.contains("hidden")) return
      if (e.key === "Escape") this.close()
      if (e.key === "ArrowRight") this.next()
      if (e.key === "ArrowLeft") this.prev()
    })
  }

  setupSwipeMobileFullscreen() {
    let startX = 0

    this.modalTarget.addEventListener("touchstart", e => {
      startX = e.changedTouches[0].screenX
    })

    this.modalTarget.addEventListener("touchend", e => {
      const diff = e.changedTouches[0].screenX - startX
      if (Math.abs(diff) > 50) diff > 0 ? this.prev() : this.next()
    })
  }

  setupSwipeDesktopFullscreen() {
    let isDown = false
    let startX = 0

    this.modalTarget.addEventListener("mousedown", e => {
      isDown = true
      startX = e.clientX
    })

    this.modalTarget.addEventListener("mouseup", e => {
      if (!isDown) return
      isDown = false

      const diff = e.clientX - startX
      if (Math.abs(diff) > 60) diff > 0 ? this.prev() : this.next()
    })
  }

  /* -----------------------------------
     INLINE MODE (service_notes/show)
  ------------------------------------*/

  showInlinePhoto(index) {
    const url = this.photosValue[index]
    this.photoTarget.src = url

    this.dotTargets.forEach((dot, i) =>
      dot.classList.toggle("active", i === index)
    )
  }

  nextInline() {
    if (this.indexValue < this.photosValue.length - 1) {
      this.indexValue++
      this.showInlinePhoto(this.indexValue)
    }
  }

  prevInline() {
    if (this.indexValue > 0) {
      this.indexValue--
      this.showInlinePhoto(this.indexValue)
    }
  }

  clickNext() {
    if (this.modeValue !== "inline") return
    this.nextInline()
  }

  setupSwipeInline() {
    let startX = 0

    this.photoContainerTarget.addEventListener("touchstart", e => {
      startX = e.changedTouches[0].screenX
    })

    this.photoContainerTarget.addEventListener("touchend", e => {
      const diff = e.changedTouches[0].screenX - startX
      if (Math.abs(diff) > 40) diff > 0 ? this.prevInline() : this.nextInline()
    })
  }

  /* -----------------------------------
     Long Press (delete)
  ------------------------------------*/

  touchStart(event) {
    const wrapper = event.currentTarget
    wrapper.longPressTimer = setTimeout(() => {
      wrapper.classList.add("long-press")
    }, 600)
  }

  touchEnd(event) {
    clearTimeout(event.currentTarget.longPressTimer)
  }
}
