import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "collapsed",
    "expanded"
  ]

  open() {
    this.collapsedTarget.classList.add("hidden")
    this.expandedTarget.classList.remove("hidden")
  }

  close() {
    this.expandedTarget.classList.add("hidden")
    this.collapsedTarget.classList.remove("hidden")
  }
}
