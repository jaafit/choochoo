import { Controller } from "@hotwired/stimulus"

// Two-step confirm for a destructive action (the admin "undo" on the logs page).
// Tapping the trigger swaps it for confirm/cancel; confirm submits the form,
// cancel (or 3s of inaction) reverts, so a stray tap never leaves a live
// "confirm" sitting around waiting to be hit by accident.
export default class extends Controller {
  static targets = ["trigger", "prompt"]
  static values = { timeout: { type: Number, default: 3000 } }

  open() {
    this.triggerTarget.classList.add("hidden")
    this.promptTarget.classList.remove("hidden")
    this.timer = setTimeout(() => this.cancel(), this.timeoutValue)
  }

  cancel() {
    clearTimeout(this.timer)
    this.promptTarget.classList.add("hidden")
    this.triggerTarget.classList.remove("hidden")
  }

  disconnect() { clearTimeout(this.timer) }
}
