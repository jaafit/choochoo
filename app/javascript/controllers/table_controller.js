import { Controller } from "@hotwired/stimulus"

// The whole raffle lives here, in the browser. Marking players present and
// choosing who plays never touch the server (responsive + private), and the
// server holds no round state, so several players can run a raffle at once.
//
// Only two requests hit the server, and they trust ids, never client ticket
// numbers: Pick (server chooses the winner, weighted) and Send (server credits
// the players sent to the game and debits the chosen). Each returns the fresh
// roster, which we reconcile into the grid; there is no background polling.
export default class extends Controller {
  static targets = [
    "card", "idleArea", "selectArea", "pickArea",
    "editArea", "giftArea", "shareArea", "editLink", "giftLink", "nomineeName"
  ]
  static values = {
    nominateUrl: String, sendUrl: String,
    myId: Number, admin: Boolean, base: String
  }

  accent = ["bg-accent", "text-accent-content", "ring-2", "ring-accent", "shadow-lg"]
  primary = ["bg-primary", "text-primary-content", "shadow-md"]
  baseLook = ["bg-base-100", "shadow-md"]

  connect() {
    this.present = new Set()
    this.playing = new Set()
    this.phase = "idle"            // idle | spinning | selecting
    this.winnerId = null
    // "Show the math" overlay for the last committed round: a Map of player id ->
    // the expression to display (e.g. "5-2", "3+1"). It lingers after a send-off
    // until a newer round is sent (a fresh log supersedes it) or the page reloads.
    // Purely client-side; the server never knows about it.
    this.lastRound = new Map()
    this.render()
  }

  disconnect() { clearTimeout(this.timer) }

  // --- interactions ---------------------------------------------------------

  tapCard(event) {
    const id = Number(event.currentTarget.dataset.playerId)
    if (this.phase === "spinning") return
    if (this.phase === "selecting") {
      if (id === this.winnerId || !this.present.has(id)) return
      this.playing.has(id) ? this.playing.delete(id) : this.playing.add(id)
    } else {
      this.present.has(id) ? this.present.delete(id) : this.present.add(id)
    }
    this.render()
  }

  selectAll() {
    this.present.forEach((id) => { if (id !== this.winnerId) this.playing.add(id) })
    this.render()
  }

  async pick() {
    const ids = [...this.present]
    if (this.phase !== "idle" || ids.length < 2) return
    const data = await this.post(this.nominateUrlValue, { present_ids: ids })
    if (!data || data.winner_id == null) return
    this.applyRoster(data.roster)
    this.playing = new Set()
    this.animatePick(data.winner_id)
  }

  // Undo of a pick is purely local — the pick wrote nothing to the server.
  undoPick() {
    if (this.phase !== "selecting") return
    this.phase = "idle"
    this.winnerId = null
    this.playing = new Set()
    this.render()
  }

  async send() {
    if (this.phase !== "selecting") return
    const chosenId = this.winnerId
    const memberIds = [...this.playing]
    // Snapshot each affected player's pre-send count ("N") now, while the cards
    // still hold the old numbers, so the lingering math can show "N-P" / "N+1".
    const priorOf = (id) => Math.max(0, Number(this.cardFor(id)?.dataset.tickets) || 0)
    const chosenN = priorOf(chosenId)
    const memberN = new Map(memberIds.map((id) => [id, priorOf(id)]))

    const data = await this.post(this.sendUrlValue,
      { chosen_id: chosenId, member_ids: memberIds })
    if (!data) return
    this.applyRoster(data.roster)

    // Rebuild the "show the math" overlay for this just-committed round. It
    // replaces any prior round's math: the chosen pays one per player sent (P,
    // floored at 0 -> capped at N), and each player sent earns +1.
    this.lastRound = new Map()
    this.lastRound.set(chosenId, `${chosenN}-${Math.min(memberIds.length, chosenN)}`)
    memberN.forEach((n, id) => this.lastRound.set(id, `${n}+1`))

    // The picker and the players who played leave the room; anyone else who was
    // present stays selected, ready for the next round.
    this.playing.forEach((id) => this.present.delete(id))
    this.present.delete(chosenId)
    this.phase = "idle"
    this.winnerId = null
    this.playing = new Set()
    this.render()
  }

  // --- pick animation -------------------------------------------------------

  // Hop a ticket-weighted highlight among the present cards for ~2s, then settle
  // into the selecting view with the real (server-chosen) winner lit.
  animatePick(winnerId) {
    const cards = [...this.present].map((id) => this.cardFor(id)).filter(Boolean)
    if (cards.length < 2) { this.winnerId = winnerId; this.phase = "selecting"; this.render(); return }

    this.phase = "spinning"
    this.render()
    let delay = 90, elapsed = 0, current = null
    const hop = () => {
      current = this.weightedNext(cards, current)
      cards.forEach((c) => this.setLook(c.querySelector(".card"), c === current ? this.accent : this.primary))
      if (elapsed >= 2200) {
        this.winnerId = winnerId
        this.phase = "selecting"
        this.render()
        return
      }
      this.timer = setTimeout(hop, delay)
      elapsed += delay
      delay = Math.min(320, delay * 1.12)
    }
    hop()
  }

  weightedNext(cards, current) {
    const pool = cards.filter((c) => c !== current)
    const choices = pool.length ? pool : cards
    const weight = (c) => Math.max(0, Number(c.dataset.tickets) || 0) + 1
    let roll = Math.random() * choices.reduce((s, c) => s + weight(c), 0)
    for (const c of choices) { roll -= weight(c); if (roll < 0) return c }
    return choices[choices.length - 1]
  }

  // --- rendering ------------------------------------------------------------

  render() {
    this.cardTargets.forEach((el) => this.renderCard(el))

    const idle = this.phase === "idle"
    const selecting = this.phase === "selecting"
    this.toggle(this.idleAreaTarget, idle)
    this.toggle(this.selectAreaTarget, selecting)

    if (selecting && this.hasNomineeNameTarget) {
      this.nomineeNameTarget.textContent = this.nameFor(this.winnerId)
    }
    if (!idle) return

    const one = this.present.size === 1 ? [...this.present][0] : null
    this.toggle(this.pickAreaTarget, this.present.size >= 2)

    // Other admins can edit anyone except the owner; only the owner edits the owner.
    const showEdit = this.adminValue && one != null && !(this.isOwner(one) && !this.isOwner(this.myIdValue))
    const showGift = !this.adminValue && one != null && one !== this.myIdValue
    // Admins can share any present player except the owner — unless it's their own.
    const showShare = this.adminValue && one != null && !(this.isOwner(one) && one !== this.myIdValue)
    this.toggle(this.editAreaTarget, showEdit)
    this.toggle(this.giftAreaTarget, showGift)
    this.toggle(this.shareAreaTarget, showShare)
    if (showEdit) this.editLinkTarget.href = `${this.baseValue}?editing=${one}`
    if (showGift) this.giftLinkTarget.href = `${this.baseValue}?gifting=${one}`
  }

  // Open the pre-rendered popup for the single present player.
  share() {
    const one = this.present.size === 1 ? [...this.present][0] : null
    if (one == null) return
    document.getElementById(`share-modal-${one}`)?.showModal()
  }

  isOwner(id) { return this.cardFor(id)?.dataset.owner === "true" }

  renderCard(el) {
    const id = Number(el.dataset.playerId)
    const base = Math.max(0, Number(el.dataset.tickets) || 0)
    const card = el.querySelector(".card")
    const badge = el.querySelector(".badge")
    const tix = el.querySelector(".js-tickets")

    let look, label, display
    if (this.phase !== "idle" && id === this.winnerId) {
      // Picker mid-round: the present credit (+1) minus one per player in the
      // game (the picker plus each player added). P is capped at N+1 so the
      // result never drops below 0.
      look = this.accent; label = "picker"
      display = `${base}+1-${Math.min(this.playing.size + 1, base + 1)}`
    } else if (this.present.has(id)) {
      const playing = this.phase === "selecting" && this.playing.has(id)
      look = playing ? this.accent : this.primary
      label = playing ? "playing" : "present"
      display = `${base}+1`
    } else if (this.lastRound.has(id)) {
      // A finished round still showing its math until a newer round supersedes it.
      look = this.baseLook; label = ""; display = this.lastRound.get(id)
    } else {
      look = this.baseLook; label = ""; display = base
    }

    this.setLook(card, look)
    badge.textContent = label || "·"
    badge.classList.toggle("invisible", !label)
    badge.classList.toggle("badge-neutral", !!label)
    tix.textContent = display
  }

  // --- helpers --------------------------------------------------------------

  cardFor(id) { return this.cardTargets.find((c) => Number(c.dataset.playerId) === id) }
  nameFor(id) { return this.cardFor(id)?.dataset.name || "" }
  toggle(el, on) { if (el) el.classList.toggle("hidden", !on) }

  setLook(card, look) {
    if (!card) return
    const all = [...this.accent, ...this.primary, ...this.baseLook]
    card.classList.remove(...all)
    card.classList.add(...look)
  }

  // Update ticket counts in place from the authoritative roster. If the set of
  // players changed (added/deleted elsewhere), fall back to a full reload.
  applyRoster(roster) {
    const ids = new Set(this.cardTargets.map((c) => Number(c.dataset.playerId)))
    if (roster.length !== ids.size || roster.some((p) => !ids.has(p.id))) {
      window.location.reload()
      return
    }
    const byId = new Map(roster.map((p) => [p.id, p]))
    this.cardTargets.forEach((c) => {
      const p = byId.get(Number(c.dataset.playerId))
      if (p) { c.dataset.tickets = p.tickets; c.dataset.name = p.name }
    })
  }

  async post(url, body) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify(body)
      })
      return res.ok ? await res.json() : null
    } catch {
      return null
    }
  }
}
