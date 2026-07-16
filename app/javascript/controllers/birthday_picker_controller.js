import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "display",
    "hidden",
    "modal",
    "days",
    "months"
  ]

  connect() {
    this.selectedDay = "01"
    this.selectedMonth = "01"

    this.dayTimer = null
    this.monthTimer = null

    if (this.hiddenTarget.value) {
      const [month, day] = this.hiddenTarget.value.split("-")

      this.selectedMonth = month
      this.selectedDay = day

      this.updateDisplay()
    }
  }

  open() {
    this.modalTarget.classList.remove("hidden")

    requestAnimationFrame(() => {
      this.scrollToSelected()

      this.snap(this.daysTarget, "day")
      this.snap(this.monthsTarget, "month")
    })
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  stop(event) {
    event.stopPropagation()
  }

  save() {
    this.hiddenTarget.value =
      `${this.selectedMonth}-${this.selectedDay}`

    this.updateDisplay()

    this.close()
  }

  snap(container, attribute) {
    const items = [...container.children]

    const center =
      container.scrollTop + container.clientHeight / 2

    let nearest = null
    let distance = Infinity

    items.forEach(item => {
      const itemCenter =
        item.offsetTop + item.offsetHeight / 2

      const diff =
        Math.abs(center - itemCenter)

      if (diff < distance) {
        distance = diff
        nearest = item
      }
    })

    if (!nearest) return

    container.scrollTo({
      top:
        nearest.offsetTop -
        container.clientHeight / 2 +
        nearest.offsetHeight / 2,
      behavior: "smooth"
    })

    if (attribute === "day") {
      this.selectedDay = nearest.dataset.day
    } else {
      this.selectedMonth = nearest.dataset.month
    }

    this.highlight(container, nearest)
  }

  highlight(container, active) {
    container
      .querySelectorAll(".birthday-wheel-item")
      .forEach(item => {
        item.classList.remove("active")
      })

    active.classList.add("active")
  }

  scrollToSelected() {
    const day = this.daysTarget.querySelector(
      `[data-day="${this.selectedDay}"]`
    )

    if (day) {
      this.daysTarget.scrollTop =
        day.offsetTop -
        this.daysTarget.clientHeight / 2 +
        day.offsetHeight / 2
    }

    const month = this.monthsTarget.querySelector(
      `[data-month="${this.selectedMonth}"]`
    )

    if (month) {
      this.monthsTarget.scrollTop =
        month.offsetTop -
        this.monthsTarget.clientHeight / 2 +
        month.offsetHeight / 2
    }
  }

  updateDisplay() {
    const month = this.monthsTarget.querySelector(
      `[data-month="${this.selectedMonth}"]`
    )

    if (!month) return

    this.displayTarget.value =
      `${parseInt(this.selectedDay, 10)} ${month.textContent.trim()}`
  }

  scrollDay() {
    clearTimeout(this.dayTimer)

    this.dayTimer = setTimeout(() => {
      this.snap(this.daysTarget, "day")
    }, 80)
  }

  scrollMonth() {
    clearTimeout(this.monthTimer)

    this.monthTimer = setTimeout(() => {
      this.snap(this.monthsTarget, "month")
    }, 80)
  }
}
