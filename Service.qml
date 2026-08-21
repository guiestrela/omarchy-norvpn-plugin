import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root
  property var settings: ({})
  property string connectionState: "Unknown"
  property string country: ""
  property string server: ""
  property var countries: []
  property bool countriesLoaded: false
  property int _desired: -1
  readonly property bool connected: connectionState === "Connected"
  readonly property bool transitioning: connectionState === "Connecting" || connectionState === "Reconnecting" || connectionState === "Disconnecting"
  readonly property bool unavailable: connectionState === "Unavailable"
  readonly property bool active: _desired === -1 ? connected : (_desired === 1)
  readonly property bool busy: statusProcess.running || countriesProcess.running || controlProcess.running || setCountryProcess.running || pauseProcess.running
  readonly property string statusText: Model.statusText(connectionState)
  property string actionStatus: ""
  property string lastError: ""
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 5, 2, 60)
  property string _statusOutput: ""
  property string _countriesOutput: ""
  property bool _statusInitialized: false
  property bool _suppressNextStatusAnnouncement: false
  property bool _settingsInitialized: false
  property string _lastAnnouncedState: ""
  property string _lastAnnouncedCountry: ""
  property string _lastAnnouncedServer: ""
  property var vpnSettings: ({})
  property string settingsError: ""
  property int pauseRemainingSec: 0
  property string _pauseDuration: ""
  readonly property string pauseCountdownText: pauseRemainingSec > 0 ? formatPauseTime(pauseRemainingSec) : "Ready"
  readonly property bool settingsBusy: settingsProcess.running || setSettingProcess.running

  function explainError(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    if (/routing is currently used by meshnet/i.test(value))
      return "Routing cannot be changed while Meshnet is enabled. Disable Meshnet first."
    return Model.elide(value || "NordVPN setting could not be changed")
  }
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }
  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }
  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
    if (!countriesLoaded && !countriesProcess.running) countriesProcess.running = true
  }
  function refreshSettings() {
    if (!settingsProcess.running) settingsProcess.running = true
  }
  function announce(headline, description) {
    if (!headline || !root._settingsInitialized || Model.settingEnabled(root.vpnSettings["tray"])) return
    var args = ["omarchy-notification-send", "-g", "󰦝", headline]
    if (description) args.push(description)
    Quickshell.execDetached(args)
  }
  function announceStatusChange(parsed) {
    var state = String(parsed.state || "")
    var country = String(parsed.country || "")
    var server = String(parsed.server || "")
    if (!root._statusInitialized) {
      root._statusInitialized = true
      root._lastAnnouncedState = state
      root._lastAnnouncedCountry = country
      root._lastAnnouncedServer = server
      return
    }
    if (state !== root._lastAnnouncedState) {
      var suppress = root._suppressNextStatusAnnouncement && (state === "Connected" || state === "Disconnected")
      if (suppress) {
        root._suppressNextStatusAnnouncement = false
      } else if (state === "Connected") {
        var target = country || server
        root.announce("NordVPN connected", target ? "Connected to " + target : "VPN connection is active")
      } else if (state === "Disconnected") {
        root.announce("NordVPN disconnected", "VPN connection is inactive")
      } else if (state === "Unavailable") {
        root.announce("NordVPN unavailable", "The NordVPN daemon could not be reached")
      }
    } else if (state === "Connected" && (country !== root._lastAnnouncedCountry || server !== root._lastAnnouncedServer)) {
      var changedTarget = country || server
      if (root._suppressNextStatusAnnouncement) {
        root._suppressNextStatusAnnouncement = false
      } else {
        root.announce("NordVPN server changed", changedTarget ? "Connected to " + changedTarget : "Connected server updated")
      }
    }
    root._lastAnnouncedState = state
    root._lastAnnouncedCountry = country
    root._lastAnnouncedServer = server
  }
  function toggle() {
    if (controlProcess.running) return
    _desired = (connected || transitioning) ? 0 : 1
    _suppressNextStatusAnnouncement = true
    controlProcess.command = _desired === 1 ? ["nordvpn", "connect"] : ["nordvpn", "disconnect"]
    controlProcess.running = true
  }
  function formatPauseTime(seconds) {
    var total = Math.max(0, parseInt(seconds, 10) || 0)
    var minutes = Math.floor(total / 60)
    var secs = total % 60
    return minutes + ":" + (secs < 10 ? "0" : "") + secs
  }
  function durationSeconds(duration) {
    var values = { "5m": 300, "15m": 900, "30m": 1800, "1h": 3600, "24h": 86400 }
    return values[String(duration || "")] || 0
  }
  function clearPauseCountdown() {
    pauseRemainingSec = 0
    _pauseDuration = ""
  }
  function pause(duration) {
    if (!duration || pauseProcess.running) return
    _pauseDuration = duration
    pauseProcess.command = ["nordvpn", "pause", duration]
    pauseProcess.running = true
  }
  function setCountry(value) {
    if (!value || setCountryProcess.running) return
    _suppressNextStatusAnnouncement = true
    setCountryProcess.command = ["nordvpn", "connect", value]
    setCountryProcess.running = true
  }
  function setSetting(name, value) {
    if (!name || setSettingProcess.running) return
    var argument = String(value || "")
    if (name === "pq") name = "post-quantum"
    if (name === "lan-discovery") argument = argument === "on" ? "enable" : "disable"
    else if (argument === "on") argument = "enabled"
    else if (argument === "off") argument = "disabled"
    setSettingProcess.command = ["nordvpn", "set", name, argument]
    setSettingProcess.running = true
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refreshSettings()
  Timer {
    id: settleTimer
    property int ticks: 0
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      ticks += 1
      root.refresh()
      if (ticks >= 6) { ticks = 0; running = false; root._desired = -1 }
    }
  }
  Timer {
    id: pauseTimer
    interval: 1000
    repeat: true
    running: root.pauseRemainingSec > 0
    onTriggered: {
      if (root.pauseRemainingSec > 0) root.pauseRemainingSec -= 1
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 3000
    repeat: false
    onTriggered: {
      root.actionStatus = ""
      root.settingsError = ""
      root.lastError = ""
    }
  }

  Process {
    id: statusProcess
    command: ["nordvpn", "status"]
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
      onStreamFinished: root._statusOutput = text
    }
    onExited: function(exitCode) {
      var output = String(statusStdout.text || root._statusOutput || "").trim()
      if (exitCode === 0 && output !== "") {
        var parsed = Model.parseStatus(output)
        root.announceStatusChange(parsed)
        root.connectionState = parsed.state
        root.country = parsed.country
        root.server = parsed.server
        if (root._desired !== -1 && root.connected === (root._desired === 1)) root._desired = -1
      } else {
        root.announceStatusChange({ state: "Unavailable", country: "", server: "" })
        root.connectionState = "Unavailable"
      }
    }
  }
  Process {
    id: countriesProcess
    command: ["nordvpn", "countries"]
    stdout: StdioCollector {
      id: countriesStdout
      waitForEnd: true
      onStreamFinished: root._countriesOutput = text
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.countries = Model.parseCountries(countriesStdout.text || root._countriesOutput || "")
        root.countriesLoaded = root.countries.length > 0
      }
    }
  }
  Process {
    id: pauseProcess
    command: []
    stdout: StdioCollector { id: pauseStdout; waitForEnd: true }
    stderr: StdioCollector { id: pauseStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var output = String(pauseStderr.text || pauseStdout.text || "")
        root.lastError = Model.elide(output || "Could not pause NordVPN")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.pauseRemainingSec = root.durationSeconds(root._pauseDuration)
        root.actionStatus = "NordVPN paused"
        root.announce("NordVPN paused", "The VPN will resume when the pause expires")
        actionStatusTimer.restart()
      }
    }
  }
  Process {
    id: settingsProcess
    command: ["nordvpn", "settings"]
    stdout: StdioCollector { id: settingsStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.vpnSettings = Model.parseSettings(settingsStdout.text || "")
        root.settingsError = ""
        root._settingsInitialized = true
      } else {
        root.settingsError = "NordVPN settings unavailable"
        root._settingsInitialized = false
        root.actionStatus = root.settingsError
        actionStatusTimer.restart()
      }
    }
  }
  Process {
    id: setSettingProcess
    command: []
    stdout: StdioCollector { id: setSettingStdout; waitForEnd: true }
    stderr: StdioCollector { id: setSettingStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var output = String(setSettingStderr.text || setSettingStdout.text || "")
        root.settingsError = root.explainError(output || ("NordVPN setting command failed (" + exitCode + ")"))
        root.actionStatus = root.settingsError
        actionStatusTimer.restart()
      } else {
        var settingCommand = setSettingProcess.command || []
        root.announce("NordVPN setting changed", settingCommand.length >= 4 ? settingCommand[2] + " → " + settingCommand[3] : "The setting was updated")
      }
      root.refreshSettings()
    }
  }
  Process {
    id: controlProcess
    command: []
    stdout: StdioCollector { id: controlStdout; waitForEnd: true }
    stderr: StdioCollector { id: controlStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var stdout = String(controlStdout.text || "")
      var stderr = String(controlStderr.text || "")
      if (exitCode !== 0) {
        root._suppressNextStatusAnnouncement = false
        root._desired = -1
        root.lastError = Model.elide(stderr || stdout || "NordVPN command failed")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else { root.lastError = ""; root.actionStatus = "" }
      settleTimer.ticks = 0
      settleTimer.restart()
    }
  }
  Process {
    id: setCountryProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: setCountryStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root._suppressNextStatusAnnouncement = false
        root.lastError = Model.elide(setCountryStderr.text || "Could not change NordVPN country")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      }
      settleTimer.ticks = 0
      settleTimer.restart()
    }
  }
}
