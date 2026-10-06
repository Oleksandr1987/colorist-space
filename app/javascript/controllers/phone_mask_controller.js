import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.maxDigits = 9
    this.digits = this.extractNationalDigits(this.element.value)

    this.element.inputMode = "numeric"
    this.element.autocomplete = "tel"

    this.handleBeforeInput = this.handleBeforeInput.bind(this)
    this.handlePaste = this.handlePaste.bind(this)
    this.handleFocus = this.handleFocus.bind(this)
    this.handleClick = this.handleClick.bind(this)
    this.handleExternalChange = this.handleExternalChange.bind(this)
    this.handleBlur = this.handleBlur.bind(this)

    this.element.addEventListener("beforeinput", this.handleBeforeInput)
    this.element.addEventListener("paste", this.handlePaste)
    this.element.addEventListener("focus", this.handleFocus)
    this.element.addEventListener("click", this.handleClick)
    this.element.addEventListener("phone-mask:change", this.handleExternalChange)
    this.element.addEventListener("blur", this.handleBlur)

    this.createDisplay()
    this.render()
  }

  disconnect() {
    this.element.removeEventListener("beforeinput", this.handleBeforeInput)
    this.element.removeEventListener("paste", this.handlePaste)
    this.element.removeEventListener("focus", this.handleFocus)
    this.element.removeEventListener("click", this.handleClick)
    this.element.removeEventListener("phone-mask:change", this.handleExternalChange)
    this.element.removeEventListener("blur", this.handleBlur)

    this.displayElement?.remove()
  }

  handleFocus() {
    this.render()
    this.moveCursorToEnd()
  }

  handleClick() {
    this.moveCursorToEnd()
  }

  handleBeforeInput(event) {
    if (
      event.inputType === "deleteContentBackward" ||
      event.inputType === "deleteContentForward"
    ) {
      event.preventDefault()
      this.deleteLastDigit()
      return
    }

    if (event.inputType === "insertFromPaste") {
      return
    }

    if (event.inputType !== "insertText") {
      return
    }

    event.preventDefault()

    const value = event.data || ""

    if (!/^\d+$/.test(value)) {
      return
    }

    this.insertDigits(value)
  }

  handlePaste(event) {
    event.preventDefault()

    const pastedValue = event.clipboardData?.getData("text") || ""
    const digits = this.extractNationalDigits(pastedValue)

    if (digits.length !== this.maxDigits) {
      return
    }

    this.digits = digits
    this.render()
  }

  handleExternalChange() {
    this.digits = this.extractNationalDigits(this.element.value)
    this.render()
  }

  handleBlur() {
    this.render()
  }

  insertDigits(value) {
    if (this.digits.length >= this.maxDigits) {
      return
    }

    const available = this.maxDigits - this.digits.length
    const digits = value.replace(/\D/g, "").slice(0, available)

    if (!digits) {
      return
    }

    this.digits += digits
    this.render()
  }

  deleteLastDigit() {
    if (this.digits.length === 0) {
      return
    }

    this.digits = this.digits.slice(0, -1)
    this.render()
  }

  createDisplay() {
    const wrapper = this.element.closest(".phone-input-wrapper")

    if (!wrapper) {
      return
    }

    wrapper.querySelector(".phone-mask-display")?.remove()

    this.displayElement = document.createElement("div")
    this.displayElement.className = "phone-mask-display"
    this.displayElement.setAttribute("aria-hidden", "true")

    wrapper.appendChild(this.displayElement)
  }

  render() {
    this.element.value = this.normalizedValue()

    if (this.displayElement) {
      this.displayElement.innerHTML = this.displayValue()
    }

    this.moveCursorToEnd()
  }

  normalizedValue() {
    if (this.digits.length === 0) {
      return "+380"
    }

    return `+380${this.digits}`
  }

  displayValue() {
    const digits = this.digits.padEnd(this.maxDigits, "_").split("")
    const focused = document.activeElement === this.element
    const cursorPosition = this.digits.length

    const parts = [
      '<span class="phone-mask-entered">+380 (</span>'
    ]

    for (let index = 0; index < this.maxDigits; index++) {
      if (focused && index === cursorPosition) {
        parts.push('<span class="phone-mask-caret">|</span>')
      }

      parts.push(this.maskCharacter(digits[index]))

      if (index === 1) {
        parts.push('<span class="phone-mask-entered">) </span>')
      } else if (index === 4 || index === 6) {
        parts.push('<span class="phone-mask-entered"> </span>')
      }
    }

    if (focused && cursorPosition === this.maxDigits) {
      parts.push('<span class="phone-mask-caret">|</span>')
    }

    return parts.join("")
  }

  maskCharacter(character) {
    if (character === "_") {
      return '<span class="phone-mask-empty">_</span>'
    }

    return `<span class="phone-mask-entered">${character}</span>`
  }

  extractNationalDigits(value) {
    let digits = value.toString().replace(/\D/g, "")

    if (digits.startsWith("380")) {
      digits = digits.slice(3)
    } else if (digits.startsWith("0") && digits.length >= 10) {
      digits = digits.slice(1)
    }

    return digits.slice(0, this.maxDigits)
  }

  moveCursorToEnd() {
    requestAnimationFrame(() => {
      if (document.activeElement !== this.element) {
        return
      }

      const position = this.element.value.length

      this.element.setSelectionRange(position, position)
    })
  }
}
