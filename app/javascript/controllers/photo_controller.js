import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "modalImage"]

  connect() {
    this.photos = Array.from(document.querySelectorAll("[data-photo-url]"))
    this.index = 0
    this.listenForArrows()
    this.listenForSwipe()
  }

  show(event) {
    const wrapper = event.currentTarget
    if (wrapper.classList.contains("long-press")) return // don't open modal if long press active

    const image = wrapper.querySelector("img")
    const url = image.dataset.photoUrl
    this.index = this.photos.findIndex(p => p.dataset.photoUrl === url)
    this.openModal(url)
  }

  openModal(url) {
    this.modalImageTarget.src = url
    this.modalTarget.classList.remove("hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalImageTarget.src = ""
  }

  prev() {
    this.index = (this.index - 1 + this.photos.length) % this.photos.length
    this.modalImageTarget.src = this.photos[this.index].dataset.photoUrl
  }

  next() {
    this.index = (this.index + 1) % this.photos.length
    this.modalImageTarget.src = this.photos[this.index].dataset.photoUrl
  }

  listenForArrows() {
    window.addEventListener("keydown", e => {
      if (this.modalTarget.classList.contains("hidden")) return
      if (e.key === "ArrowLeft") this.prev()
      if (e.key === "ArrowRight") this.next()
      if (e.key === "Escape") this.close()
    })
  }

  listenForSwipe() {
    let touchStartX = 0

    this.modalTarget.addEventListener("touchstart", e => {
      touchStartX = e.changedTouches[0].screenX
    })

    this.modalTarget.addEventListener("touchend", e => {
      const diffX = e.changedTouches[0].screenX - touchStartX
      if (Math.abs(diffX) > 50) {
        diffX > 0 ? this.prev() : this.next()
      }
    })
  }

  // === New: long press for delete ===
  touchStart(event) {
    const wrapper = event.currentTarget
    wrapper.longPressTimer = setTimeout(() => {
      wrapper.classList.add("long-press")
    }, 600) // 600ms for long press
  }

  touchEnd(event) {
    clearTimeout(event.currentTarget.longPressTimer)
  }
}
