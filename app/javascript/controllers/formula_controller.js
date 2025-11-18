import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  // ---------------- SECTIONS ----------------
  showSection(event) {
    event.preventDefault()
    const section = event.currentTarget.dataset.section
    const template = this.templateTarget.innerHTML
    const html = template.replace(/__SECTION__/g, section)
    this.containerTarget.innerHTML = html
  }

  // ---------------- COLORS ----------------
  addColor(event) {
    event.preventDefault()
    const block = event.currentTarget.closest(".colors-block")
    const list = block.querySelector("[data-formula-target='colorsList']")
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

  // ---------------- OXIDANT ----------------
  addOxidant(event) {
    event.preventDefault()
    const block = event.currentTarget.closest(".oxidant-block")
    const container = block.querySelector("[data-formula-target='oxidant']")

    if (container.querySelector("select")) return

    const html = `
      <div class="oxidant-row">
        <span class="label">Oxidant</span>
        <select name="formula_step[oxidant]" class="input">
          <option value="">Select %</option>
          <option value="3%">3%</option>
          <option value="6%">6%</option>
          <option value="9%">9%</option>
          <option value="12%">12%</option>
        </select>
      </div>
    `
    container.innerHTML = html
  }

  // ---------------- TIME ----------------
  addTime(event) {
    event.preventDefault()
    const block = event.currentTarget.closest(".time-block")
    const container = block.querySelector("[data-formula-target='time']")

    if (container.querySelector("input")) return

    const html = `
      <div class="time-row">
        <span class="label">TIME</span>
        <input type="number" name="formula_step[time]" min="1" max="120"
               placeholder="Minutes"
               class="input" style="width: 100px;" />
        <span>min</span>
      </div>
    `
    container.innerHTML = html
  }
}
