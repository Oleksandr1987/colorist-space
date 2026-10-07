// app/javascript/controllers/birthday_picker_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "hidden", "modal", "days", "months"]

  connect() {
    this.selectedDay = "01"
    this.selectedMonth = "01"

    this.dayTimer = null
    this.monthTimer = null
    this.itemHeight = 44

    if (this.hiddenTarget.value) {
      const [month, day] = this.hiddenTarget.value.split("-")

      this.selectedMonth = month
      this.selectedDay = day
    }

    this.renderDays()
    this.updateDisplay()
  }

  disconnect() {
    clearTimeout(this.dayTimer)
    clearTimeout(this.monthTimer)
  }

  open() {
    this.modalTarget.classList.remove("hidden")

    this.renderDays()

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.scrollToSelected()
        this.highlightSelected()
      })
    })
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  stop(event) {
    event.stopPropagation()
  }

  save() {
    this.hiddenTarget.value = `${this.selectedMonth}-${this.selectedDay}`

    this.updateDisplay()
    this.close()
  }

  scrollDay() {
    clearTimeout(this.dayTimer)

    this.dayTimer = setTimeout(() => {
      const item = this.nearestItem(this.daysTarget)

      if (!item) return

      this.selectedDay = item.dataset.day

      this.snapToItem(this.daysTarget, item)
      this.highlightSelected()
    }, 100)
  }

  scrollMonth() {
    clearTimeout(this.monthTimer)

    this.monthTimer = setTimeout(() => {
      const item = this.nearestItem(this.monthsTarget)

      if (!item) return

      const previousMonth = this.selectedMonth
      this.selectedMonth = item.dataset.month

      this.snapToItem(this.monthsTarget, item)

      if (previousMonth !== this.selectedMonth) {
        this.adjustDayForMonth()
        this.renderDays()

        requestAnimationFrame(() => {
          const day = this.daysTarget.querySelector(`[data-day="${this.selectedDay}"]`)
          if (day) {
            this.scrollToItem(this.daysTarget, day)
          }

          this.highlightSelected()
        })
      } else {
        this.highlightSelected()
      }
    }, 100)
  }

  renderDays() {
    const numberOfDays = this.daysInSelectedMonth()

    this.daysTarget.replaceChildren(
      this.createSpacer(),
      ...Array.from({ length: numberOfDays }, (_, index) => {
        const day = String(index + 1).padStart(2, "0")
        const item = document.createElement("div")

        item.className = "birthday-wheel-item"
        item.dataset.day = day
        item.textContent = day

        return item
      }),
      this.createSpacer()
    )
  }

  createSpacer() {
    const spacer = document.createElement("div")
    spacer.className = "birthday-wheel-spacer"

    return spacer
  }

  daysInSelectedMonth() {
    const month = Number(this.selectedMonth)
    if (month === 2) return 28

    if ([4, 6, 9, 11].includes(month)) return 30

    return 31
  }

  adjustDayForMonth() {
    const maxDay = this.daysInSelectedMonth()
    const currentDay = Number(this.selectedDay)

    if (currentDay > maxDay) {
      this.selectedDay = String(maxDay).padStart(2, "0")
    }
  }

  nearestItem(container) {
    const items = container.querySelectorAll(".birthday-wheel-item")

    if (!items.length) return null

    const center = container.scrollTop + container.clientHeight / 2

    let nearest = null
    let distance = Infinity

    items.forEach((item) => {
      const itemCenter = item.offsetTop + item.offsetHeight / 2
      const currentDistance = Math.abs(center - itemCenter)

      if (currentDistance < distance) {
        distance = currentDistance
        nearest = item
      }
    })

    return nearest
  }

  snapToItem(container, item) {
    container.scrollTo({
      top: item.offsetTop - (container.clientHeight - item.offsetHeight) / 2,
      behavior: "smooth"
    })
  }

  scrollToSelected() {
    const month = this.monthsTarget.querySelector(`[data-month="${this.selectedMonth}"]`)
    const day = this.daysTarget.querySelector(`[data-day="${this.selectedDay}"]`)

    if (month) {
      this.scrollToItem(this.monthsTarget, month)
    }

    if (day) {
      this.scrollToItem(this.daysTarget, day)
    }
  }

  scrollToItem(container, item) {
    container.scrollTop = item.offsetTop - (container.clientHeight - item.offsetHeight) / 2
  }

  highlightSelected() {
    this.monthsTarget
      .querySelectorAll(".birthday-wheel-item")
      .forEach((item) => {
        item.classList.toggle("active", item.dataset.month === this.selectedMonth)
      })

    this.daysTarget
      .querySelectorAll(".birthday-wheel-item")
      .forEach((item) => {
        item.classList.toggle("active", item.dataset.day === this.selectedDay)
      })
  }

  updateDisplay() {
    const month = this.monthsTarget.querySelector(`[data-month="${this.selectedMonth}"]`)
    if (!month) return

    this.displayTarget.value =
      `${Number(this.selectedDay)} ${month.textContent.trim()}`
  }
}
