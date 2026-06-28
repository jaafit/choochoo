import { Controller } from "@hotwired/stimulus"

// Fetches the cross-host stats fragment using the token kept in localStorage and
// renders it. The token is never put in the URL — it rides in a request header.
// No token (or a wrong one) yields an empty response and the page stays blank.
export default class extends Controller {
  static targets = ["content"]
  static values = { url: String }

  connect() {
    this.page = 1
    this.load()
  }

  // Pager buttons inside the fragment carry data-page.
  go(event) {
    this.page = Number(event.currentTarget.dataset.page) || 1
    this.load()
    window.scrollTo({ top: 0 })
  }

  async load() {
    const token = (window.localStorage.getItem("someonepicktoken") || "").trim()
    try {
      // no-store: a token-less first load returns a bodyless 204 that the browser
      // would otherwise cache against this URL and replay even after a token is set.
      const res = await fetch(`${this.urlValue}?page=${this.page}`, {
        cache: "no-store",
        headers: { "X-Someonepick-Token": token, "Accept": "text/html" }
      })
      const html = res.ok ? (await res.text()).trim() : ""
      if (html) this.contentTarget.innerHTML = html
    } catch (_) {
      // Network error: leave the placeholder in place.
    }
  }
}
