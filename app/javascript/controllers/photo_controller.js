// app/javascript/controllers/photo_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "modalImage", "photo", "photoContainer", "dot", "mainButton", "heart"]
  static values = {
    photos: Array,
    index: Number,
    mode: String,
    mainPhotoUrl: String
  }

  connect() {
    if (this.hasPhotosValue) {
      this.modeValue = "inline"
      this.indexValue = 0
      this.showInlinePhoto(0)

      if (this.hasPhotoContainerTarget) {
        this.setupSwipeInline()
      }

      return
    }

    // fullscreen mode
    this.modeValue = "fullscreen"

    if (!this.hasModalTarget) return

    this.photos = Array.from(document.querySelectorAll("[data-photo-url]"))
    this.index = 0
    this.setupKeyboard()
    this.setupSwipeMobileFullscreen()
    this.setupSwipeDesktopFullscreen()

    if (!this.hasPhotoTarget) return
  }

  /* FULLSCREEN MODE (clients/show) */
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
    if (!this.hasModalTarget || !this.hasModalImageTarget) return

    this.modalImageTarget.src = url
    this.modalTarget.classList.remove("hidden")
  }

  close() {
    if (!this.hasModalTarget || !this.hasModalImageTarget) return

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
    if (!this.hasModalTarget) return

    window.addEventListener("keydown", e => {
      if (this.modalTarget.classList.contains("hidden")) return
      if (e.key === "Escape") this.close()
      if (e.key === "ArrowRight") this.next()
      if (e.key === "ArrowLeft") this.prev()
    })
  }

  setupSwipeMobileFullscreen() {
    if (!this.hasModalTarget) return

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

  /* INLINE MODE (service_notes/show) */
  showInlinePhoto(index) {
    if (!this.hasPhotoTarget) return

    const photo = this.photosValue[index]
    if (!photo) return

    this.photoTarget.src = photo.url

    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("active", i === index)
    })

    this.updateMainPhotoButton()
  }

  updateMainPhotoButton() {
    if (!this.hasHeartTarget || !this.hasMainButtonTarget) return

    const photo = this.photosValue[this.indexValue]
    if (!photo) return

    const isMain = photo.main === true

    this.mainButtonTarget.classList.toggle("active", isMain)
  }

  async setMainPhoto(event) {
    event.preventDefault()
    event.stopPropagation()

    const photo = this.photosValue[this.indexValue]

    if (!photo || !this.hasMainPhotoUrlValue) return

    const response = await fetch(this.mainPhotoUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector(
          'meta[name="csrf-token"]'
        ).content,
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({photo_id: photo.id})
    })

    if (!response.ok) return

    const data = await response.json()
    const photos = this.photosValue.map(item => ({...item, main: item.id === data.main_photo_id}))

    const mainPhoto = photos.find(item => item.main)
    const otherPhotos = photos.filter(item => !item.main)

    this.photosValue = [mainPhoto, ...otherPhotos].filter(Boolean)
    this.indexValue = 0
    this.showInlinePhoto(0)
  }

  nextInline() {
    this.indexValue = (this.indexValue + 1) % this.photosValue.length
    this.showInlinePhoto(this.indexValue)
  }

  prevInline() {
    this.indexValue = (this.indexValue - 1 + this.photosValue.length) % this.photosValue.length
    this.showInlinePhoto(this.indexValue)
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

  /* Long Press (delete) */
  touchStart(event) {
    const wrapper = event.currentTarget
    wrapper.longPressTimer = setTimeout(() => {
      wrapper.classList.add("long-press")
    }, 600)
  }

  touchEnd(event) {
    clearTimeout(event.currentTarget.longPressTimer)
  }

  remove(event) {
    event.preventDefault()
    event.stopPropagation()

    const photoItem = event.currentTarget.closest(".photo-item")
    const url = photoItem.dataset.deleteUrl

    if (!confirm("Delete photo?")) return

    fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json"
      }
    })
      .then(response => {
        if (response.ok) {
          photoItem.remove()
        } else {
          alert("Failed to delete photo")
        }
      })

    window.dispatchEvent(new CustomEvent("wizard:changed"))
  }
}
