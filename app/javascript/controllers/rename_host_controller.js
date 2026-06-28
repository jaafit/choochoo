import { Controller } from "@hotwired/stimulus"

// Click-to-rename the host header. The display heading and an edit form sit in
// the same spot; clicking the heading (admins only — the form is only rendered
// for them) swaps to the input, and Escape restores the heading without saving.
export default class extends Controller {
  static targets = ["display", "form", "input"]

  edit() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }
}
