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
  readonly property bool busy: statusProcess.running || countriesProcess.running || controlProcess.running || setCountryProcess.running
  readonly property string statusText: Model.statusText(connectionState)
  property string actionStatus: ""
  property string lastError: ""
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 5, 2, 60)
  property string _statusOutput: ""
  property string _countriesOutput: ""
  property var vpnSettings: ({})
  property string settingsError: ""
  readonly property bool settingsBusy: settingsProcess.running || setSettingProcess.running

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
    if (!settingsProcess.running) settingsProcess.running = true
  }
  function toggle() {
    if (controlProcess.running) return
    _desired = (connected || transitioning) ? 0 : 1
    controlProcess.command = _desired === 1 ? ["nordvpn", "connect"] : ["nordvpn", "disconnect"]
    controlProcess.running = true
  }
  function setCountry(value) {
    if (!value || setCountryProcess.running) return
    setCountryProcess.command = ["nordvpn", "connect", value]
    setCountryProcess.running = true
  }
  function setSetting(name, value) {
    if (!name || setSettingProcess.running) return
    var argument = String(value || "")
    if (name === "lan-discovery") argument = argument === "on" ? "enable" : "disable"
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
    id: actionStatusTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionStatus = ""
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
        root.connectionState = parsed.state
        root.country = parsed.country
        root.server = parsed.server
        if (root._desired !== -1 && root.connected === (root._desired === 1)) root._desired = -1
      } else root.connectionState = "Unavailable"
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
    id: settingsProcess
    command: ["nordvpn", "settings"]
    stdout: StdioCollector { id: settingsStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.vpnSettings = Model.parseSettings(settingsStdout.text || "")
        root.settingsError = ""
      } else {
        root.settingsError = "NordVPN settings unavailable"
      }
    }
  }
  Process {
    id: setSettingProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: setSettingStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.settingsError = Model.elide(setSettingStderr.text || "Could not change NordVPN setting")
        root.actionStatus = root.settingsError
        actionStatusTimer.restart()
      }
      root.refresh()
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
        root.lastError = Model.elide(setCountryStderr.text || "Could not change NordVPN country")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      }
      settleTimer.ticks = 0
      settleTimer.restart()
    }
  }
}
