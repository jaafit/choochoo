import { Controller } from "@hotwired/stimulus"

// Suspense animation for the Pick button. When Pick is submitted we hold the
// request, hop the orange "picker" highlight from card to card for ~2 seconds,
// then let the nominate request go through and the real result render. Each hop
// lands on a ticket-weighted random player, never the one currently lit (so the
// highlight always visibly moves). The animation is pure showmanship — which
// card lands last is not tied to who actually gets picked.
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
    let current = null
    let delay = 200
    let elapsed = 0
    // 10% faster each step quickly converges, so floor the delay to keep the
    // highlight visibly hopping for the full two seconds before it stops.
    const minDelay = 30

    const tick = () => {
      current = this.pickNext(cards, current)
      this.highlight(current)
      if (elapsed >= 2500) {
        form.requestSubmit()
        return
      }
      this.timer = setTimeout(tick, delay)
      elapsed += delay
      delay = Math.max(minDelay, delay * 0.95)
    }
    tick()
  }

  // A ticket-weighted random card, excluding the one currently highlighted so the
  // highlight always moves. Falls back to the full set if exclusion empties it.
  pickNext(cards, current) {
    const pool = cards.filter((c) => c !== current)
    const choices = pool.length ? pool : cards
    const weight = (c) => Math.max(1, Number(c.dataset.weight) || 1)
    const total = choices.reduce((sum, c) => sum + weight(c), 0)

    let roll = Math.random() * total
    for (const c of choices) {
      roll -= weight(c)
      if (roll < 0) return c
    }
    return choices[choices.length - 1]
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
