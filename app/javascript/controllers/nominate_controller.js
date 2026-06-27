import { Controller } from "@hotwired/stimulus"

// Suspense animation for the Pick button. When Pick is submitted we hold the
// request, cycle the orange "picker" highlight across all present players for
// ~2 seconds (starting at 150ms per player, each step 10% faster), then let the
// nominate request go through and the real result render. The animation is pure
// showmanship — which card lands last is not tied to who actually gets picked.
export default class extends Controller {
  static targets = ["candidate"]

  // Mirror the picker/in-room looks used in the grid (see _card.html.erb).
  accentClasses = ["bg-accent", "text-accent-content", "ring-2", "ring-accent", "shadow-lg"]
  roomClasses = ["bg-primary", "text-primary-content"]

  run(event) {
    // Nothing to animate, or already spinning: let the submit proceed normally.
    if (this.spinning || this.candidateTargets.length < 2) return
    event.preventDefault()
    this.spinning = true
    this.spin(event.target)
  }

  spin(form) {
    const cards = this.candidateTargets
    let i = 0
    let delay = 250
    let elapsed = 0
    // 10% faster each step quickly converges, so floor the delay to keep the
    // highlight visibly cycling for the full two seconds before it stops.
    const minDelay = 30

    const tick = () => {
      this.highlight(cards[i % cards.length])
      i += 1
      if (elapsed >= 2000) {
        form.requestSubmit()
        return
      }
      this.timer = setTimeout(tick, delay)
      elapsed += delay
      delay = Math.max(minDelay, delay * 0.90)
    }
    tick()
  }

  // Cancel the loop on any teardown (Turbo navigation when Pick is skipped or a
  // player is clicked), so a stale timer can never fire a second submit.
  disconnect() {
    clearTimeout(this.timer)
  }

  highlight(card) {
    this.candidateTargets.forEach((el) => {
      const on = el === card
      this.accentClasses.forEach((c) => el.classList.toggle(c, on))
      this.roomClasses.forEach((c) => el.classList.toggle(c, !on))
    })
  }
}
