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
    "card", "idleArea", "selectArea", "shareSelectArea", "pickArea",
    "editArea", "giftArea", "shareArea", "shareStartArea", "editLink", "giftLink", "nomineeName"
  ]
  static values = {
    nominateUrl: String, sendUrl: String,
    myId: Number, admin: Boolean, base: String
  }

  // Tile looks, by state. All are light fills (the role-coloured name stays
  // legible on every one); the state is signalled by the border, ring and the
  // pill badge rather than a flooded background. Kept in sync with _card.html.erb
  // and the static tile markup in hosts/show.html.erb.
  baseLook    = ["bg-[#FAF5EA]", "border-[#E7DBC2]", "shadow-[0_3px_8px_rgba(20,12,4,.3)]"]
  presentLook = ["bg-[#DCE6FA]", "border-[1.5px]", "border-[#2E6BD6]", "shadow-[0_0_0_3px_rgba(46,107,214,.22),0_3px_8px_rgba(20,12,4,.3)]"]
  playingLook = ["bg-[#DCEFEA]", "border-[1.5px]", "border-[#159B82]", "shadow-[0_0_0_3px_rgba(21,155,130,.22),0_3px_8px_rgba(20,12,4,.3)]"]
  pickerLook  = ["bg-[#FBE2DC]", "border-[1.5px]", "border-[#EE5A43]", "shadow-[0_0_0_3px_rgba(238,90,67,.25),0_3px_8px_rgba(20,12,4,.3)]"]
  badgeColors = ["bg-[#2E6BD6]", "bg-[#159B82]", "bg-[#EE5A43]"]

  connect() {
    this.present = new Set()
    this.playing = new Set()
    this.phase = "idle"            // idle | spinning | selecting | sharing
    this.winnerId = null
    this.render()
  }

  disconnect() { clearTimeout(this.timer); this.clearRails() }

  // --- interactions ---------------------------------------------------------

  tapCard(event) {
    const id = Number(event.currentTarget.dataset.playerId)
    if (this.phase === "spinning") return
    if (this.phase === "sharing") {
      // Tapping a card shares that player. The owner has no popup, so nothing
      // happens for them — stay in sharing.
      this.openShare(id)
      return
    }
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
    const data = await this.post(this.sendUrlValue,
      { chosen_id: this.winnerId, member_ids: [...this.playing] })
    if (!data) return
    this.applyRoster(data.roster)

    // The picker and the players who played leave the room; anyone else who was
    // present stays selected, ready for the next round.
    this.playing.forEach((id) => this.present.delete(id))
    this.present.delete(this.winnerId)
    this.phase = "idle"
    this.winnerId = null
    this.playing = new Set()
    this.render()
  }

  // --- pick animation -------------------------------------------------------

  // Lay every present player's tickets out as little dashed cells, then flick a
  // highlight among all the cells for ~2s — each ticket equally likely, so a
  // player's odds scale with how many they hold. Never the same cell twice in a
  // row, though the same player can light up again on a different ticket. When it
  // settles we tear the cells down and light the server-chosen winner's card.
  animatePick(winnerId) {
    const cells = this.buildRails()
    const settle = () => {
      this.clearRails()
      this.winnerId = winnerId
      this.phase = "selecting"
      this.render()
    }
    if (cells.length < 2) { settle(); return }

    this.phase = "spinning"
    this.render()
    let delay = 90, elapsed = 0, current = null
    const hop = () => {
      current = this.nextCell(cells, current)
      // The flicking highlight uses the picker colour (coral), the same fill the
      // winner's tile and "picker" badge get when the wheel settles.
      cells.forEach((c) => c.classList.toggle("bg-[#EE5A43]", c === current))
      if (elapsed >= 2500) { settle(); return }
      this.timer = setTimeout(hop, delay)
      elapsed += delay
      delay = Math.min(320, delay * 1.12)
    }
    hop()
  }

  // A random cell with equal weight per ticket, never the one currently lit.
  nextCell(cells, current) {
    const pool = cells.filter((c) => c !== current)
    return pool[Math.floor(Math.random() * pool.length)]
  }

  // Fill each present player's rail with one dashed cell per ticket, side by
  // side. We use their present count (tickets + 1) to match the server's pick
  // weighting, so everyone present has at least one cell. Returns the flat list
  // of cells so the animation can flick a highlight across them.
  buildRails() {
    const cells = []
    this.cardTargets.forEach((el) => {
      const rail = el.querySelector(".js-rail")
      if (!rail) return
      rail.innerHTML = ""
      if (!this.present.has(Number(el.dataset.playerId))) return
      const tickets = Math.max(0, Number(el.dataset.tickets) || 0)
      const n = tickets + 1
      // 4 columns, at least 2 rows so anyone with 8 or fewer tickets gets the same
      // cell size; beyond 8 we add rows, shrinking the cells to fit.
      rail.style.gridTemplateColumns = "repeat(4, 1fr)"
      rail.style.gridTemplateRows = `repeat(${Math.max(2, Math.ceil(n / 4))}, 1fr)`
      // Past 8 tickets the cells are getting cramped, so tighten the gap to
      // gap-0.5 (2px) from the rail's default gap-1 (4px); otherwise keep default.
      rail.style.gap = tickets > 8 ? "2px" : ""
      for (let i = 0; i < n; i++) {
        const cell = document.createElement("div")
        cell.className = "ticket-cell rounded-md text-primary"
        rail.appendChild(cell)
        cells.push(cell)
      }
      rail.classList.remove("hidden")
      rail.classList.add("grid")
    })
    return cells
  }

  clearRails() {
    this.cardTargets.forEach((el) => {
      const rail = el.querySelector(".js-rail")
      if (rail) { rail.innerHTML = ""; rail.classList.add("hidden"); rail.classList.remove("grid") }
    })
  }

  // --- rendering ------------------------------------------------------------

  render() {
    this.cardTargets.forEach((el) => this.renderCard(el))

    const idle = this.phase === "idle"
    const selecting = this.phase === "selecting"
    const sharing = this.phase === "sharing"
    this.toggle(this.idleAreaTarget, idle)
    this.toggle(this.selectAreaTarget, selecting)
    this.toggle(this.shareSelectAreaTarget, sharing)

    if (selecting && this.hasNomineeNameTarget) {
      this.nomineeNameTarget.textContent = this.nameFor(this.winnerId)
    }
    if (!idle) return

    const one = this.present.size === 1 ? [...this.present][0] : null
    this.toggle(this.pickAreaTarget, this.present.size >= 2)
    // With nobody selected, an admin gets a share button that opens sharing mode.
    this.toggle(this.shareStartAreaTarget, this.adminValue && this.present.size === 0)

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

  // With nobody selected, an admin can share any player: enter sharing mode,
  // where the "Share with whom?" prompt shows and tapping a card opens that
  // player's popup. Cancel returns to idle.
  startShare() {
    if (this.phase !== "idle" || this.present.size !== 0) return
    this.phase = "sharing"
    this.render()
  }

  cancelShare() {
    if (this.phase !== "sharing") return
    this.phase = "idle"
    this.render()
  }

  // Open the pre-rendered popup for the single present player.
  share() {
    const one = this.present.size === 1 ? [...this.present][0] : null
    if (one == null) return
    this.openShare(one)
  }

  // Open a player's share popup; closing it deselects everyone and returns the
  // table to a clean idle state.
  openShare(id) {
    const modal = document.getElementById(`share-modal-${id}`)
    if (!modal) return
    modal.addEventListener("close", () => {
      this.present.clear()
      this.phase = "idle"
      this.render()
    }, { once: true })
    modal.showModal()
  }

  isOwner(id) { return this.cardFor(id)?.dataset.owner === "true" }

  renderCard(el) {
    const id = Number(el.dataset.playerId)
    const baseTix = Math.max(0, Number(el.dataset.tickets) || 0)
    const tile = el.querySelector(".js-tile")
    const badge = el.querySelector(".js-badge")
    const tix = el.querySelector(".js-tickets")
    const plus = el.querySelector(".js-plus")

    // state: null (idle/absent) | "present" | "playing" | "picker". A non-null
    // state means a highlighted tile: dark ticket number, coloured pill badge.
    let look, state, display, showPlus
    if (this.phase !== "idle" && id === this.winnerId) {
      // Picker mid-round: the present credit (+1) minus one per player in the
      // game (the picker plus each player added). P is capped at N+1 so the
      // result never drops below 0.
      look = this.pickerLook; state = "picker"; showPlus = false
      display = `${baseTix}+1-${Math.min(this.playing.size + 1, baseTix + 1)}`
    } else if (this.present.has(id)) {
      const isPlaying = this.phase === "selecting" && this.playing.has(id)
      // Present tiles keep their blue "present" look throughout the spin (the
      // tag and ticket math still hide — see `animating` below); the dashed
      // ticket cells overlay them and the coral highlight rides the cells.
      look = isPlaying ? this.playingLook : this.presentLook
      state = isPlaying ? "playing" : "present"
      display = `${baseTix}`; showPlus = true
    } else {
      look = this.baseLook; state = null; display = `${baseTix}`; showPlus = false
    }

    // While a tile is animating (present, mid-spin) only its name shows over the
    // ticket cells — the badge and the ticket math hide (kept in flow via
    // visibility so nothing shifts when the spin starts or stops).
    const animating = this.phase === "spinning" && this.present.has(id)
    this.setLook(tile, look)

    badge.textContent = state || ""
    this.setBadgeColor(badge, state)
    badge.classList.toggle("hidden", animating || !state)

    tix.textContent = display
    // Highlighted tiles get the dark ink number; quiet ones the muted brown.
    tix.classList.toggle("text-[#33271A]", state != null)
    tix.classList.toggle("text-[#8A7A5E]", state == null)
    tix.classList.toggle("invisible", animating)

    plus.classList.toggle("hidden", !showPlus)
    plus.classList.toggle("invisible", animating)
  }

  // --- helpers --------------------------------------------------------------

  cardFor(id) { return this.cardTargets.find((c) => Number(c.dataset.playerId) === id) }
  nameFor(id) { return this.cardFor(id)?.dataset.name || "" }
  toggle(el, on) { if (el) el.classList.toggle("hidden", !on) }

  setLook(tile, look) {
    if (!tile) return
    const all = [...this.baseLook, ...this.presentLook, ...this.playingLook, ...this.pickerLook]
    tile.classList.remove(...all)
    tile.classList.add(...look)
  }

  // Pill badge colour follows the tile state (blue present, teal playing, coral
  // picker); the default keeps blue so an empty badge has a sane colour.
  setBadgeColor(badge, state) {
    if (!badge) return
    badge.classList.remove(...this.badgeColors)
    badge.classList.add(state === "playing" ? "bg-[#159B82]" : state === "picker" ? "bg-[#EE5A43]" : "bg-[#2E6BD6]")
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
