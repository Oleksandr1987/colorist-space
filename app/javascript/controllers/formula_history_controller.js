// app/javascript/controllers/formula_history_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "action",
    "search",
    "list",
    "count",
    "empty",
    "loading",
    "more",
    "history",
    "details",
    "steps",
    "selectedCount",
    "selectAll",
    "copy",
    "title",
    "back"
  ]

  static values = {
    url: String,
    appointmentId: String,
    targetServiceNoteId: String,
    translations: Object
  }

  connect() {
    this.page = 1
    this.searchTerm = ""
    this.requestController = null
    this.searchTimer = null
    this.opened = false

    this.selectedFormula = null
    this.selectedSteps = new Set()
    this.detailsController = null
  }

  disconnect() {
    this.requestController?.abort()
    clearTimeout(this.searchTimer)
    if (this.opened) {
      document.body.style.overflow = this.previousOverflow
    }

    this.detailsController?.abort()
  }

  async open(event) {
    event.preventDefault()

    if (this.opened) return

    this.opened = true
    this.previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"

    this.selectedFormula = null
    this.selectedSteps.clear()
    this.loadingTarget.textContent = this.translate("loading")

    this.modalTarget.classList.remove("hidden")
    this.searchTarget.value = ""
    this.searchTerm = ""
    this.page = 1
    this.historyTarget.classList.remove("hidden")
    this.detailsTarget.classList.add("hidden")
    this.titleTarget.textContent = this.translate("title")
    this.backTarget.classList.add("hidden")

    await this.load()
  }

  close(event) {
    event?.preventDefault()

    this.requestController?.abort()
    clearTimeout(this.searchTimer)

    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = this.previousOverflow || ""
    this.opened = false

    this.detailsController?.abort()
    this.selectedFormula = null
    this.selectedSteps.clear()
    this.detailsTarget.classList.add("hidden")
    this.historyTarget.classList.remove("hidden")
  }

  search() {
    clearTimeout(this.searchTimer)

    this.searchTimer = setTimeout(() => {
      this.searchTerm = this.searchTarget.value.trim()
      this.page = 1
      this.load()
    }, 300)
  }

  async loadMore(event) {
    event.preventDefault()
    if (this.loading) return

    this.page += 1
    await this.load(true)
  }

  async load(append = false) {
    this.requestController?.abort()

    const controller = new AbortController()
    this.requestController = controller
    this.loading = true

    this.loadingTarget.classList.remove("hidden")
    this.moreTarget.classList.add("hidden")
    this.emptyTarget.classList.add("hidden")

    if (!append) {
      this.listTarget.replaceChildren()
    }

    const url = this.historyUrl()

    url.searchParams.set("page", this.page)

    if (this.searchTerm) {
      url.searchParams.set("search", this.searchTerm)
    }

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: controller.signal
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()

      if (controller.signal.aborted) return

      this.renderList(data.formulas, append)
      this.countTarget.textContent = this.translate("formulasFound", { count: data.total })
      this.emptyTarget.classList.toggle("hidden", data.total !== 0)
      this.moreTarget.classList.toggle("hidden", !data.has_more)
    } catch (error) {
      if (error.name === "AbortError") return

      console.error("Formula history:", error)

      this.countTarget.textContent = this.translate("loadError")

      this.moreTarget.classList.add("hidden")
    } finally {
      if (this.requestController === controller) {
        this.loading = false
        this.loadingTarget.classList.add("hidden")
      }
    }
  }

  renderList(formulas, append = false) {
    if (!append) {
      this.listTarget.replaceChildren()
    }

    formulas.forEach(formula => {
      this.listTarget.appendChild(this.buildCard(formula))
    })
  }

  buildCard(formula) {
    const card = document.createElement("button")
    card.type = "button"
    card.className = "formula-history-card"
    card.dataset.formulaId = formula.id

    const header = document.createElement("div")
    header.className = "formula-history-card-header"

    const date = document.createElement("strong")
    date.textContent = this.formatDate(formula.date)

    const arrow = document.createElement("span")
    arrow.textContent = "›"

    header.append(date, arrow)

    const sections = document.createElement("div")
    sections.className = "formula-history-card-sections"

    const translations = this.application.getControllerForElementAndIdentifier(this.element, "formula")?.sectionsValue || {}

    sections.textContent = formula.sections.map(section => translations[section] || section).join(" · ")

    const count = document.createElement("small")
    count.textContent = this.translate("stepsCount", { count: formula.steps_count })

    card.append(header, sections, count)

    card.addEventListener("click", () => { this.selectFormula(formula.id) })

    return card
  }

  async selectFormula(id) {
    this.detailsController?.abort()

    const controller = new AbortController()
    this.detailsController = controller

    this.loadingTarget.classList.remove("hidden")
    this.loadingTarget.textContent = this.translate("loading")

    try {
      const url = this.historyUrl(id)

      const response = await fetch(url, {
        headers: { Accept: "application/json" }, credentials: "same-origin", signal: controller.signal
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const formula = await response.json()

      if (controller.signal.aborted || !this.opened) return

      this.selectedFormula = formula
      this.selectedSteps = new Set(formula.steps.map((_, index) => index))
      this.historyTarget.classList.add("hidden")
      this.detailsTarget.classList.remove("hidden")
      this.backTarget.classList.remove("hidden")
      this.titleTarget.textContent = this.translate("formulaDate", { date: this.formatDate(formula.date) })
      this.renderSteps()
    } catch (error) {
      if (error.name === "AbortError") return

      console.error("Formula details:", error)
      this.countTarget.textContent = this.translate("detailsError")
    } finally {
      if (this.detailsController === controller) {
        this.loadingTarget.classList.add("hidden")
      }
    }
  }

  renderSteps() {
    this.stepsTarget.replaceChildren()

    const steps = this.selectedFormula?.steps || []

    steps.forEach((step, index) => {
      const card = document.createElement("div")
      card.className = "formula-history-step"

      const header = document.createElement("label")
      header.className = "formula-history-step-header"

      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.checked = this.selectedSteps.has(index)

      checkbox.addEventListener("change", () => {
        if (checkbox.checked) {
          this.selectedSteps.add(index)
        } else {
          this.selectedSteps.delete(index)
        }

        this.updateSelection()
      })

      const title = document.createElement("strong")
      title.textContent = this.translate("stepTitle", {number: index + 1, section: this.sectionLabel(step.section)})

      header.append(checkbox, title)
      card.appendChild(header)

      const ingredients = step.ingredients || []
      const colors = ingredients.filter(item => item.kind === "color")
      const additives = ingredients.filter(item => item.kind === "additive")

      this.appendIngredientGroup(card, this.translate("colors"), colors)
      this.appendIngredientGroup(card, this.translate("additives"), additives)

      const oxidants = Array.isArray(step.oxidant) ? step.oxidant : step.oxidant ? [step.oxidant] : []

      if (oxidants.length > 0) {
        const block = document.createElement("div")
        block.className = "formula-history-step-group"

        const heading = document.createElement("strong")
        heading.textContent = this.translate("oxidants")
        block.appendChild(heading)

        oxidants.forEach(item => {
          const row = document.createElement("div")

          row.textContent = [
            item.brand,
            item.name || item.product_name,
            item.concentration,
            this.formatAmount(item)
          ].filter(Boolean).join(" · ")

          block.appendChild(row)
        })

        card.appendChild(block)
      }

      const time = document.createElement("div")
      time.className = "formula-history-step-time"
      time.textContent = this.translate("processingTime", {time: step.time || 0})

      card.appendChild(time)
      this.stepsTarget.appendChild(card)
    })

    this.updateSelection()
  }

  appendIngredientGroup(card, title, ingredients) {
    if (!ingredients.length) return

    const group = document.createElement("div")
    group.className = "formula-history-step-group"

    const heading = document.createElement("strong")
    heading.textContent = title
    group.appendChild(heading)

    ingredients.forEach(item => {
      const row = document.createElement("div")

      row.textContent = [
        item.brand,
        item.shade,
        this.formatAmount(item)
      ].filter(Boolean).join(" · ")

      group.appendChild(row)
    })

    card.appendChild(group)
  }

  sectionLabel(section) {
    const formulaController =
      this.application.getControllerForElementAndIdentifier(this.element, "formula")

    return formulaController?.sectionsValue?.[section] || section
  }

  updateSelection() {
    const total = this.selectedFormula?.steps?.length || 0
    const selected = this.selectedSteps.size

    this.selectedCountTarget.textContent = this.translate("selectedCount", {selected, total})

    this.selectAllTarget.textContent = selected === total ? this.translate("deselectAll") : this.translate("selectAll")

    this.copyTarget.disabled = selected === 0
    this.copyTarget.textContent = this.translate("copySelected", {count: selected})
  }

  toggleAll(event) {
    event.preventDefault()

    const steps = this.selectedFormula?.steps || []

    if (this.selectedSteps.size === steps.length) {
      this.selectedSteps.clear()
    } else {
      this.selectedSteps = new Set(steps.map((_, index) => index))
    }

    this.renderSteps()
  }

  back(event) {
    event.preventDefault()

    this.detailsController?.abort()

    this.selectedFormula = null
    this.selectedSteps.clear()

    this.detailsTarget.classList.add("hidden")
    this.historyTarget.classList.remove("hidden")

    this.titleTarget.textContent = this.translate("title")
    this.backTarget.classList.add("hidden")
  }

  copySelected(event) {
    event.preventDefault()

    if (!this.selectedFormula || this.selectedSteps.size === 0) {
      return
    }

    const formulaController = this.application.getControllerForElementAndIdentifier(this.element, "formula")

    if (!formulaController) {
      console.error("Formula controller not found")
      return
    }

    const steps = this.selectedFormula.steps.filter(
      (_, index) => this.selectedSteps.has(index)
    )

    const imported = formulaController.importSteps(steps)

    if (!imported) {
      console.warn("Formula import was rejected")
      return
    }

    this.close()
  }

  formatDate(value) {
    if (!value) return this.translate("noDate")

    const parts = value.split("-")
    if (parts.length !== 3) return value

    return `${parts[2]}.${parts[1]}.${parts[0]}`
  }

  historyUrl(id = null) {
    const url = new URL(this.urlValue, window.location.origin)

    if (id !== null) {
      url.pathname = `${url.pathname.replace(/\/$/, "")}/${encodeURIComponent(id)}`
    }

    if (this.targetServiceNoteIdValue) {
      url.searchParams.set("target_service_note_id", this.targetServiceNoteIdValue)
    } else {
      url.searchParams.set("appointment_id", this.appointmentIdValue)
    }

    return url
  }


  formatAmount(item) {
    if (item.amount == null) return null

    const unit = item.unit || "g"
    const translatedUnit = this.translationsValue.units?.[unit] || unit

    return `${item.amount} ${translatedUnit}`
  }

  translate(key, replacements = {}) {
    let text = this.translationsValue[key] || key

    Object.entries(replacements).forEach(([name, value]) => {
      text = text.replaceAll(`__${name.toUpperCase()}__`, String(value))
    })

    return text
  }
}
