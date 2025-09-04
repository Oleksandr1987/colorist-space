import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["colorsList", "container", "template"]

  // відкриває форму для вибраної секції (Roots, Midshaft…)
  showSection(event) {
    event.preventDefault()
    const section = event.currentTarget.dataset.section

    const template = this.templateTarget.innerHTML
    const html = template.replace(/__SECTION__/g, section)

    this.containerTarget.innerHTML = html
  }

  addColor(event) {
    event.preventDefault()
    const list = this.colorsListTarget
    const prototype = list.dataset.prototype
    const newId = new Date().getTime()

    const parser = new DOMParser()
    const decoded = parser.parseFromString(prototype, "text/html").body.innerHTML

    const newFields = decoded.replace(/NEW_RECORD/g, newId)
    list.insertAdjacentHTML("beforeend", newFields)
  }

  removeColor(event) {
    event.preventDefault()
    event.currentTarget.closest(".color-row").remove()
  }
}
