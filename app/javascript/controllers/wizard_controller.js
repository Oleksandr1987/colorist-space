// app/javascript/controllers/wizard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "container",
    "title",
    "progress",
    "step",
    "nextButton",
    "nextLabel",
    "nextIcon",
    "prevButton",
    "unsavedModal",
    "unsavedTitle",
    "unsavedMessage"
  ]

  static values = {
    unsavedTitle: String,
    unsavedMessage: String,
    saveLabel: String,
    discardLabel: String,
    cancelLabel: String
  }

  connect() {
    console.log("Wizard controller connected")

    this.current = 0
    this.steps = this.stepTargets
    this.nav = this.element.querySelectorAll(".wiz-item")
    this.isDirty = false

    this.markDirty = this.markDirty.bind(this)

    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("change", this.markDirty)

    window.addEventListener("formula:changed", this.markDirty)
    window.addEventListener("services:changed", this.markDirty)
    window.addEventListener("wizard:changed", this.markDirty)

    this.element.querySelector("form")?.addEventListener("submit", () => {
      this.isDirty = false
    })

    this.update()
    this.updateNextButton()
    this.updateButtons()
    this.initSwipe()
  }

  disconnect() {
    this.element.removeEventListener("input", this.markDirty)
    this.element.removeEventListener("change", this.markDirty)

    window.removeEventListener("formula:changed", this.markDirty)
    window.removeEventListener("services:changed", this.markDirty)
    window.removeEventListener("wizard:changed", this.markDirty)
  }

  // ---------------- NAV CLICK ----------------
  go(event) {
    this.current = parseInt(event.currentTarget.dataset.step)

    this.update()
    this.updateNextButton()
    this.updateButtons()
  }

  // ---------------- NEXT ----------------
  next() {
    if (this.current < this.steps.length - 1) {
      this.current++

      this.update()
      this.updateNextButton()
      this.updateButtons()
    }
  }

  // ---------------- PREV ----------------
  prev() {
    if (this.current > 0) {
      this.current--

      this.update()
      this.updateNextButton()
      this.updateButtons()
    }
  }

  // ---------------- UPDATE UI ----------------
  update() {
    // steps
    this.steps.forEach((el, i) => {
      el.classList.toggle("active", i === this.current)
    })

    // nav icons
    this.nav.forEach((el, i) => {
      el.classList.toggle("active", i === this.current)
    })

    // title
    const titles = ["Services", "Formula", "Photos", "Notes"]
    this.titleTarget.textContent = titles[this.current]

    this.updateProgress()
  }

  // ---------------- PROGRESS ----------------
  updateProgress() {
    const total = this.steps.length - 1

    if (total <= 0) {
      this.progressTarget.style.width = "0%"
      return
    }

    const percent = ((this.current + 1) / (total + 1)) * 100
    this.progressTarget.style.width = `${percent}%`
  }

  // ---------------- SWIPE ----------------
  initSwipe() {
    let startX = 0

    this.containerTarget.addEventListener("touchstart", e => {
      startX = e.changedTouches[0].screenX
    })

    this.containerTarget.addEventListener("touchend", e => {
      const diff = e.changedTouches[0].screenX - startX

      if (Math.abs(diff) > 50) {
        diff > 0 ? this.prev() : this.next()
      }
    })
  }

  // ---------------- NEXT BUTTON ----------------
  updateNextButton() {
    const isLast = this.current === this.steps.length - 1

    if (isLast) {
      this.nextLabelTarget.textContent = "SAVE"
      this.nextButtonTarget.type = "submit"
      this.nextIconTarget.style.display = "none"
    } else {
      this.nextLabelTarget.textContent = "NEXT"
      this.nextButtonTarget.type = "button"
      this.nextIconTarget.style.display = "inline-block"
    }
  }

  // ---------------- BACK BUTTON ----------------
  updateButtons() {
    if (!this.hasPrevButtonTarget) return

    if (this.current === 0) {
      this.prevButtonTarget.style.visibility = "hidden"
    } else {
      this.prevButtonTarget.style.visibility = "visible"
    }
  }

  close() {
    if (!this.isDirty) {
      history.back()
      return
    }

    this.openUnsavedModal()
  }

  openUnsavedModal() {
    if (this.hasUnsavedTitleTarget) {
      this.unsavedTitleTarget.textContent = this.unsavedTitleValue
    }

    if (this.hasUnsavedMessageTarget) {
      this.unsavedMessageTarget.textContent = this.unsavedMessageValue
    }

    this.unsavedModalTarget.classList.remove("hidden")
  }

  cancelClose() {
    this.unsavedModalTarget.classList.add("hidden")
  }

  discardChanges() {
    this.isDirty = false
    history.back()
  }

  saveAndClose() {
    this.isDirty = false
    this.element.querySelector("form")?.requestSubmit()
  }

  markDirty() {
    this.isDirty = true
  }
}
