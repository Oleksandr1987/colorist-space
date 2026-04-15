// app/javascript/controllers/wizard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "title", "progress", "step", "nextButton", "nextLabel", "nextIcon", "prevButton"]

  connect() {
    console.log("Wizard controller connected")

    this.current = 0
    this.steps = this.stepTargets
    this.nav = this.element.querySelectorAll(".wiz-item")

    this.update()
    this.updateNextButton()
    this.updateButtons()
    this.initSwipe()
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
    const titles = ["Formula", "Services", "Photos", "Notes"]
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
    this.element.remove()
  }
}
