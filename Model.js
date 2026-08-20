function countryLabel(name) {
  return String(name || "").trim().replace(/\s+/g, " ")
}

function parseCountries(raw) {
  var lines = String(raw || "").split("\n")
  var seen = {}
  var out = []
  for (var i = 0; i < lines.length; i++) {
    var country = lines[i].trim()
    if (country === "" || /^countries:?$/i.test(country) || seen[country]) continue
    seen[country] = true
    out.push({ value: country, label: countryLabel(country) })
  }
  out.sort(function(a, b) {
    return a.label < b.label ? -1 : (a.label > b.label ? 1 : 0)
  })
  return out
}

function parseStatus(raw) {
  var text = String(raw || "")
  function field(name) {
    var match = text.match(new RegExp("^" + name + "\\s*:\\s*(.+)$", "im"))
    return match ? match[1].trim() : ""
  }
  var status = field("Status")
  var normalized = status.toLowerCase()
  var state = normalized.indexOf("connected") === 0 ? "Connected"
    : normalized.indexOf("connecting") === 0 ? "Connecting"
    : normalized.indexOf("disconnecting") === 0 ? "Disconnecting"
    : normalized.indexOf("reconnecting") === 0 ? "Reconnecting"
    : normalized.indexOf("disconnected") === 0 ? "Disconnected"
    : status || "Unknown"
  return { state: state, country: field("Country"), server: field("Server") }
}

function statusText(state) {
  switch (String(state || "")) {
    case "Connected": return "Connected"
    case "Connecting": return "Connecting…"
    case "Reconnecting": return "Reconnecting…"
    case "DisconnectingToReconnect": return "Reconnecting…"
    case "Disconnecting": return "Disconnecting…"
    case "Interrupted": return "Interrupted"
    case "Disconnected": return "Disconnected"
    case "Unavailable": return "Unavailable"
    default: return "Checking…"
  }
}

function elide(text) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  return value.length > 140 ? value.substring(0, 137) + "…" : value
}
