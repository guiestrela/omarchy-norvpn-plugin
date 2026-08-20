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
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service { id: nord; settings: root.settings }

  onOpenedChanged: if (opened) {
    nord.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
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
    tooltipText: "NordVPN — " + nord.statusText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) nord.refresh()
      else if (buttonCode === Qt.MiddleButton) nord.toggle()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(320))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: countryPicker.popupOpen
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
          color: nord.lastError !== "" && nord.actionStatus === "" ? root.urgent : root.dim
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
      }
    }
  }
}
