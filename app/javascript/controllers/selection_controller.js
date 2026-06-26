import { Controller } from "@hotwired/stimulus"

// Client-side "who's playing" selection. No network calls while selecting — the
// chosen ids live in memory and are only submitted with the Send selected form.
// State is intentionally not persisted: each nominate is a fresh page load and
// should start with nobody selected.
export default class extends Controller {
  static targets = ["player", "nomineeTickets", "memberInputs"]
  static values = { baseTickets: Number }

  // Playing-state look (accent), vs the plain in-room look (primary).
  playingClasses = ["bg-accent", "text-accent-content", "ring-2", "ring-accent", "shadow-lg"]
  roomClasses = ["bg-primary", "text-primary-content"]

  connect() {
    this.selected = new Set()
    this.render()
  }

  toggle(event) {
    const id = Number(event.currentTarget.dataset.playerId)
    this.selected.has(id) ? this.selected.delete(id) : this.selected.add(id)
    this.render()
  }

  // Select every present player (the player targets are the in-room, non-nominee
  // cards). Purely client-side.
  selectAll() {
    this.playerTargets.forEach((el) => this.selected.add(Number(el.dataset.playerId)))
    this.render()
  }

  render() {
    this.playerTargets.forEach((el) => {
      const on = this.selected.has(Number(el.dataset.playerId))
      this.playingClasses.forEach((c) => el.classList.toggle(c, on))
      this.roomClasses.forEach((c) => el.classList.toggle(c, !on))
      const badge = el.querySelector(".badge")
      if (badge) badge.textContent = on ? "playing" : "present"
    })

    if (this.hasNomineeTicketsTarget) {
      const remaining = Math.max(0, this.baseTicketsValue - 1 - this.selected.size)
      this.nomineeTicketsTarget.textContent = `${remaining} tix`
    }

    if (this.hasMemberInputsTarget) {
      this.memberInputsTarget.replaceChildren()
      this.selected.forEach((id) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "member_ids[]"
        input.value = id
        this.memberInputsTarget.appendChild(input)
      })
    }
  }
}
