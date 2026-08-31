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

function parseSettings(raw) {
  var values = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([^:]+):\s*(.*?)\s*$/)
    if (!match) continue
    var key = match[1].trim().toLowerCase().replace(/\s+/g, "-")
    values[key] = match[2].trim()
  }
  return values
}

function settingEnabled(value) {
  return /^(enabled|on|yes|true)$/i.test(String(value || "").trim())
}

function autoConnectTarget(value) {
  var target = String(value || "").trim()
  if (/^[a-z]{2}(?:[0-9]+)?$/i.test(target)) return target.toLowerCase()
  var codes = {
    "argentina": "ar", "australia": "au", "austria": "at", "belgium": "be",
    "botswana": "bw",
    "brazil": "br", "bulgaria": "bg", "canada": "ca", "chile": "cl",
    "colombia": "co", "costa rica": "cr", "croatia": "hr", "cyprus": "cy",
    "czech republic": "cz", "denmark": "dk", "estonia": "ee", "finland": "fi",
    "france": "fr", "georgia": "ge", "germany": "de", "greece": "gr",
    "hong kong": "hk", "hungary": "hu", "iceland": "is", "india": "in",
    "indonesia": "id", "ireland": "ie", "israel": "il", "italy": "it",
    "japan": "jp", "latvia": "lv", "luxembourg": "lu", "malaysia": "my",
    "mexico": "mx", "moldova": "md", "netherlands": "nl", "new zealand": "nz",
    "nigeria": "ng", "norway": "no", "poland": "pl", "portugal": "pt",
    "romania": "ro", "serbia": "rs", "singapore": "sg", "slovakia": "sk",
    "slovenia": "si", "south africa": "za", "south korea": "kr", "spain": "es",
    "sweden": "se", "switzerland": "ch", "taiwan": "tw", "thailand": "th",
    "turkey": "tr", "ukraine": "ua", "united arab emirates": "ae",
    "united kingdom": "uk", "united states": "us", "vietnam": "vn"
  }
  // Configuration can be edited outside the picker. Never pass an arbitrary
  // value as a country target; Process receives argv safely, but rejecting
  // unknown values also prevents accidental invalid NordVPN commands.
  if (codes[target.toLowerCase()]) return codes[target.toLowerCase()]
  if (/^[a-z]{2}(?:[0-9]+)?$/i.test(target)) return target.toLowerCase()
  // Country names returned by `nordvpn countries` may vary by client version.
  // Permit only plain human-readable names as a safe argv value.
  return /^[a-z][a-z .'-]{1,63}$/i.test(target) ? target : ""
}

function validPauseDuration(value) {
  return /^(5m|15m|30m|1h|24h)$/.test(String(value || ""))
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
