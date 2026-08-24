import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.guiestrela.nordvpn"
  ipcTarget: "io.github.guiestrela.nordvpn"
  manageIpc: false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: nord.unavailable ? urgent : (nord.active ? foreground : dim)
  readonly property color barIconColor: nord.unavailable ? Qt.darker(barForeground, 1.2) : (nord.active ? barForeground : Qt.darker(barForeground, 1.55))
  readonly property string toggleHint: nord.active ? "Disconnect" : "Connect"
  readonly property bool paused: nord.pauseRemainingSec > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service { id: nord; settings: root.settings }

  onOpenedChanged: if (opened) {
    nord.refresh()
    nord.refreshSettings()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Connections {
    target: nord
    function onConnectionStateChanged() {
      if (nord.connected) {
        pausePicker.value = ""
        nord.clearPauseCountdown()
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { nord.toggle() }
    function refresh(): string { nord.refresh(); return "ok" }
    function status(): string { return nord.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰦝"
    foreground: root.barIconColor
    tooltipText: root.paused
      ? "NordVPN " + String.fromCodePoint(0x2014) + " Paused (" + nord.pauseCountdownText + ")"
      : "NordVPN " + String.fromCodePoint(0x2014) + " " + nord.statusText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) nord.refresh()
      else if (buttonCode === Qt.MiddleButton) nord.toggle()
      else root.toggle()
    }
  }

  Timer {
    id: pauseTooltipTimer
    interval: 1000
    repeat: true
    running: root.paused && button.tooltipHovered
    onTriggered: {
      if (root.bar && button.tooltipHovered)
        root.bar.tooltipText = button.tooltipText
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
    blocked: countryPicker.popupOpen || pausePicker.popupOpen || technologyPicker.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") nord.refresh()
        else if (t === "c" || t === "C") nord.toggle()
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: "NordVPN"
          meta: nord.statusText
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: nord.unavailable ? 0.5 : (nord.active ? 1.0 : 0.6)
          iconComponent: Component {
            Text { text: "󰦝"; color: root.iconColor; font.family: root.fontFamily; font.pixelSize: Style.font.display }
          }
          trailingControl: Component {
            ToggleSwitch {
              id: powerSwitch
              checked: nord.active
              busy: nord.busy || nord.unavailable
              interactive: !nord.unavailable
              foreground: hero.foreground
              onToggled: nord.toggle()
              PanelToolTip {
                visible: powerSwitch.containsMouse
                text: root.toggleHint
                fontFamily: hero.fontFamily
              }
            }
          }
        }

        Text {
          visible: nord.actionStatus !== "" || nord.lastError !== ""
          width: parent.width
          text: nord.actionStatus !== "" ? nord.actionStatus : nord.lastError
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { foreground: root.foreground }
        Column {
          width: parent.width
          spacing: Style.space(8)
          PanelSectionHeader { text: "COUNTRY"; foreground: root.foreground; fontFamily: root.fontFamily }
          SearchableDropdown {
            id: countryPicker
            width: parent.width
            showLabel: false
            placeholderText: "Search countries..."
            fontFamily: root.fontFamily
            options: nord.countries
            value: nord.country
            onChanged: function(v) { nord.setCountry(v) }
          }
        }

        PanelSeparator { foreground: root.foreground }
        Column {
          width: parent.width
          spacing: Style.space(8)
          PanelSectionHeader { text: "PAUSE"; foreground: root.foreground; fontFamily: root.fontFamily }
          Row {
            width: parent.width
            spacing: Style.space(10)
            SearchableDropdown {
              id: pausePicker
              width: Style.space(220)
            showLabel: false
            placeholderText: "Choose pause duration..."
            fontFamily: root.fontFamily
            options: [
              { value: "5m", label: "5 minutes" },
              { value: "15m", label: "15 minutes" },
              { value: "30m", label: "30 minutes" },
              { value: "1h", label: "1 hour" },
              { value: "24h", label: "24 hours" }
            ]
              onChanged: function(v) {
                nord.pause(v)
                pausePicker.value = ""
              }
            }
            Text {
              width: parent.width - pausePicker.width - Style.space(10)
              height: pausePicker.implicitHeight
              text: nord.pauseCountdownText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        PanelSeparator { foreground: root.foreground }
        Column {
          width: parent.width
          spacing: Style.space(8)
          PanelSectionHeader { text: "SETTINGS"; foreground: root.foreground; fontFamily: root.fontFamily }
          SearchableDropdown {
            id: technologyPicker
            width: parent.width
            showLabel: true
            label: "Technology"
            placeholderText: "Select technology..."
            fontFamily: root.fontFamily
            options: [
              { value: "NORDLYNX", label: "NordLynx" },
              { value: "OPENVPN", label: "OpenVPN" }
            ]
            value: nord.vpnSettings["technology"] || ""
            onChanged: function(v) { nord.setSetting("technology", v) }
          }

          Item {
            width: parent.width
            implicitHeight: settingsFlow.implicitHeight

            Flow {
              id: settingsFlow
              width: parent.width
            spacing: Style.space(8)
            Repeater {
              model: [
              { key: "firewall", label: "Firewall", command: "firewall" },
              { key: "kill-switch", label: "Kill Switch", command: "killswitch" },
              { key: "auto-connect", label: "Auto-connect", command: "autoconnect" },
              { key: "threat-protection-lite", label: "Threat Protection Lite", command: "threatprotectionlite" },
              { key: "notify", label: "Notify", command: "notify" },
              { key: "tray", label: "Tray", command: "tray" },
              { key: "meshnet", label: "Meshnet", command: "meshnet" },
              { key: "dns", label: "DNS", command: "dns" },
              { key: "lan-discovery", label: "LAN Discovery", command: "lan-discovery" },
              { key: "routing", label: "Routing", command: "routing" },
              { key: "virtual-location", label: "Virtual Location", command: "virtual-location" },
              { key: "arp-ignore", label: "ARP Ignore", command: "arp-ignore" },
              { key: "post-quantum-vpn", label: "Post-quantum VPN", command: "pq" }
            ]
            delegate: Column {
              width: (settingsFlow.width - Style.space(8)) / 2
              spacing: Style.space(8)
              Row {
                width: parent.width
                spacing: Style.space(8)
                Text {
                  width: parent.width - settingSwitch.width - Style.space(8)
                  text: modelData.label + ": " + (nord.vpnSettings[modelData.key] || "Checking…")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                  maximumLineCount: 2
                  verticalAlignment: Text.AlignVCenter
                }
                ToggleSwitch {
                  id: settingSwitch
                  checked: Model.settingEnabled(nord.vpnSettings[modelData.key])
                  busy: nord.settingsBusy
                  interactive: !nord.unavailable
                  foreground: root.foreground
                  onToggled: nord.setSetting(modelData.command, checked ? "off" : "on")
                }
              }
              SearchableDropdown {
                id: autoConnectCountryPicker
                visible: modelData.key === "auto-connect"
                width: parent.width
                showLabel: false
                placeholderText: "Auto-connect country (optional)..."
                fontFamily: root.fontFamily
                options: nord.countries
                value: nord.autoConnectCountry
                onChanged: function(v) {
                  nord.autoConnectCountry = v
                  if (Model.settingEnabled(nord.vpnSettings["auto-connect"]))
                    nord.setSetting("autoconnect", "on")
                }
              }
            }
            }

            Rectangle {
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              width: 1
              color: root.dim
              opacity: 0.55
            }
          }

          PanelSeparator { foreground: root.foreground }
          Text {
            width: parent.width
            text: "Editable options use NordVPN set commands. Firewall Mark and User Consent are daemon status values and are read-only here. Manage them through the NordVPN terminal/CLI when supported."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
          Text {
            width: parent.width
            text: "- Firewall Mark: " + (nord.vpnSettings["firewall-mark"] || "Checking…")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
          Text {
            width: parent.width
            text: "- User Consent: " + (nord.vpnSettings["user-consent"] || "Checking…")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
