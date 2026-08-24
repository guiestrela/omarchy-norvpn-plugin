# NordVPN — Omarchy bar widget

A widget for [Omarchy](https://omarchy.org/) that controls the official
NordVPN Linux client from the top bar, with quick connect, disconnect, and a
searchable country selector.

![NordVPN widget popup](preview.png)

## Requirements

- Omarchy with the Quickshell-based plugin system.
- The official NordVPN Linux client installed, with `nordvpn` available on
  `PATH`.
- The client authenticated and its daemon running. Test it with:

  ```bash
  nordvpn status
  ```

The plugin uses the official NordVPN CLI commands `status`, `settings`,
`countries`, `connect`, `disconnect`, and the supported `set` options. It does
not access NordVPN credentials or modify NordVPN configuration files directly.

## Installation

```bash
omarchy plugin add https://github.com/guiestrela/omarchy-norvpn-plugin.git --enable
```

## Enable or disable

Enable the plugin in the right bar section:

```bash
omarchy plugin enable io.github.guiestrela.nordvpn right
```

Disable it without removing the installed files:

```bash
omarchy plugin disable io.github.guiestrela.nordvpn
```

## Usage

- Left-click: open or close the popup.
- Right-click: refresh the connection status.
- Middle-click: connect or disconnect.
- In the popup, the switch performs a quick connect or disconnect.
- The country selector searches countries and runs `nordvpn connect <country>`.
- Auto-connect can target a specific country by choosing it in the country list
  shown below Auto-connect, or by setting `autoConnectCountry` to its two-letter
  NordVPN country code (for example, `br` or `fr`). When the
  field is empty, NordVPN chooses the fastest available server. The plugin
  applies this as `nordvpn set autoconnect on <country_code>` when Auto-connect
  is enabled.
- The Pause selector pauses the VPN immediately when you choose 5m, 15m, 30m, 1h, or 24h using `nordvpn pause`. A countdown is shown beside the selector, which then returns to its placeholder.

The icon is bright when connected, dimmed when disconnected, and shown in the
alert color when the NordVPN daemon is unavailable.

## Settings

The popup reads `nordvpn settings` and presents supported options in a
two-column layout. The following settings can be changed through the official
`nordvpn set` command:

- Technology
- Firewall
- Kill Switch
- Auto-connect
- Threat Protection Lite
- Notify and Tray
- Meshnet and DNS
- LAN Discovery
- Routing
- Virtual Location
- ARP Ignore
- Post-quantum VPN

`Firewall Mark` and `User Consent` are displayed as read-only daemon status
values. They must be checked or managed through the NordVPN terminal/CLI when
supported by the installed client version.

- `refreshIntervalSec` (2–60, default 5): connection status refresh interval.
- `autoConnectCountry` (default empty): optional two-letter country code used
  by Auto-connect, such as `br` or `fr`.

## Uninstall

To remove the plugin completely, run:

```bash
omarchy plugin remove io.github.guiestrela.nordvpn --yes
```

This disables the plugin and removes its installed files.

## License

MIT — see [LICENSE](LICENSE).
