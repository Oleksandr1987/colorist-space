import { Controller } from "@hotwired/stimulus"
import Inputmask from "inputmask"

export default class extends Controller {
  connect() {
    Inputmask({
      mask: "+380(99)999-99-99",
      placeholder: "_",
      showMaskOnHover: false,
      showMaskOnFocus: true
    }).mask(this.element)
  }
}
