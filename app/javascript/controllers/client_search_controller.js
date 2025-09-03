import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "group"]

  connect() {
    console.log("ClientSearchController connected");
    this.inputTarget.addEventListener("input", () => this.search());
  }

  search() {
    const query = this.inputTarget.value.toLowerCase();
    console.log("Search query:", query);

    this.groupTargets.forEach((group) => {
      let hasVisibleItems = false;

      group.querySelectorAll("[data-client-search-target='item']").forEach((item) => {
        const name = item.querySelector(".client-link").textContent.toLowerCase();
        const isVisible = name.includes(query);
        item.style.display = isVisible ? "block" : "none";
        if (isVisible) hasVisibleItems = true;
      });

      group.style.display = hasVisibleItems ? "block" : "none";
    });
  }
}
