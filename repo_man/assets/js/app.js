// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/repo_man"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Refresh interval hook: localStorage persistence + countdown badge
const RefreshInterval = {
  mounted() {
    this.countdownTimer = null
    this.remaining = 0

    // Restore from localStorage
    const stored = parseInt(localStorage.getItem("refresh_interval"), 10)
    if ([0, 2000, 10000, 30000].includes(stored)) {
      this.pushEvent("restore_refresh", {interval: stored})
      this.startCountdown(stored)
    } else {
      this.startCountdown(2000)
    }

    // Listen for server-pushed interval changes
    this.handleEvent("refresh-interval-changed", ({interval}) => {
      localStorage.setItem("refresh_interval", interval)
      this.startCountdown(interval)
    })
  },

  updated() {
    const interval = parseInt(this.el.dataset.interval, 10)
    this.startCountdown(interval)
  },

  startCountdown(interval) {
    clearInterval(this.countdownTimer)
    this.countdownTimer = null
    const badge = document.getElementById("refresh-badge")
    if (!badge) return

    if (interval === 0) {
      badge.textContent = "off"
      return
    }

    if (interval < 10000) {
      // 2s: static badge, no countdown
      badge.textContent = (interval / 1000) + "s"
      return
    }

    // 10s, 30s: live countdown
    this.remaining = Math.round(interval / 1000)
    badge.textContent = this.remaining
    this.countdownTimer = setInterval(() => {
      this.remaining--
      if (this.remaining <= 0) this.remaining = Math.round(interval / 1000)
      badge.textContent = this.remaining
    }, 1000)
  },

  destroyed() {
    clearInterval(this.countdownTimer)
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, RefreshInterval},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Open Terminal: calls the host-side terminal-opener companion (localhost:4001)
// to launch Ghostty at the given path
window.addEventListener("phx:open-terminal", (event) => {
  const path = event.detail.path
  if (!path) return
  fetch(`http://127.0.0.1:4001/open?path=${encodeURIComponent(path)}`)
    .catch(() => {
      // Companion not running — fall back to clipboard copy
      if (navigator.clipboard) {
        navigator.clipboard.writeText(path)
        const btn = event.target
        if (btn) {
          const orig = btn.textContent
          btn.textContent = "📋"
          setTimeout(() => { btn.textContent = orig }, 1000)
        }
      }
    })
})

// Theme toggle: swap data-theme on <html> and persist to localStorage
window.toggleTheme = function() {
  let current = document.documentElement.getAttribute("data-theme")
  let next = current === "dark" ? "light" : "dark"
  document.documentElement.setAttribute("data-theme", next)
  localStorage.setItem("theme", next)
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

