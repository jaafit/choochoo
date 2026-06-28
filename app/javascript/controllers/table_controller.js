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
    "card", "idleArea", "selectArea", "pickArea", "undoSendArea", "undoSendButton",
    "editArea", "giftArea", "shareArea", "editLink", "giftLink", "nomineeName"
  ]
  static values = {
    nominateUrl: String, sendUrl: String, undoUrl: String,
    myId: Number, admin: Boolean, lastSendLog: Number, lastSendName: String, base: String
  }

  accent = ["bg-accent", "text-accent-content", "ring-2", "ring-accent", "shadow-lg"]
  primary = ["bg-primary", "text-primary-content", "shadow-md"]
  baseLook = ["bg-base-100", "shadow-md"]

  connect() {
    this.present = new Set()
    this.playing = new Set()
    this.phase = "idle"            // idle | spinning | selecting
    this.winnerId = null
    this.sendLogId = this.lastSendLogValue || null
    this.sendName = this.lastSendNameValue || ""
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
    this.sendLogId = null
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
    const data = await this.post(this.sendUrlValue,
      { chosen_id: this.winnerId, member_ids: [...this.playing] })
    if (!data) return
    this.applyRoster(data.roster)
    this.sendLogId = data.log_id || null
    this.sendName = this.nameFor(this.winnerId)
    // The picker and the players who played leave the room; anyone else who was
    // present stays selected, ready for the next round.
    this.playing.forEach((id) => this.present.delete(id))
    this.present.delete(this.winnerId)
    this.phase = "idle"
    this.winnerId = null
    this.playing = new Set()
    this.render()
  }

  async undoSend() {
    if (!this.sendLogId) return
    const data = await this.post(this.undoUrlValue, { log_id: this.sendLogId })
    if (!data) return
    this.applyRoster(data.roster)
    // The server tells us whether the now-latest action is the player's own
    // send-off, so we keep offering to undo that one too. The label carries the
    // picker's name, and we pulse the button so a back-to-back undo of two games
    // with the same picker still reads as "something happened".
    this.sendLogId = data.undo_log_id || null
    this.sendName = data.undo_log_name || ""
    this.render()
    this.pulseUndo()
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
    this.toggle(this.undoSendAreaTarget, !!this.sendLogId)
    if (this.sendLogId && this.hasUndoSendButtonTarget) {
      this.undoSendButtonTarget.textContent =
        this.sendName ? `Undo ${this.sendName}'s game` : "Undo send"
    }

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

  // Brief fade so an undo that leaves the button in place (next action is also an
  // undoable send) still gives visible feedback.
  pulseUndo() {
    if (!this.sendLogId || !this.hasUndoSendButtonTarget) return
    const btn = this.undoSendButtonTarget
    btn.classList.add("opacity-40")
    setTimeout(() => btn.classList.remove("opacity-40"), 150)
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
      look = this.accent; label = "picker"; display = Math.max(0, base - this.playing.size)
    } else if (this.present.has(id)) {
      const playing = this.phase === "selecting" && this.playing.has(id)
      look = playing ? this.accent : this.primary
      label = playing ? "playing" : "present"
      display = base + 1
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
