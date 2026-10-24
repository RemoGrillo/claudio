<div align="center">

<img src="share/icons/hicolor/scalable/apps/io.github.remogrillo.claudio.svg" width="96" alt="Claudio icon">

# Claudio

**Claude Code in a sidebar for KDE Plasma.**
One key and it glitches into view at the right edge of your screen, over whatever you are doing, on every virtual desktop.

[![AUR](https://img.shields.io/aur/version/claudio?logo=archlinux&label=AUR)](https://aur.archlinux.org/packages/claudio)
![KDE Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-1d99f3?logo=kde)
![Wayland](https://img.shields.io/badge/Wayland-only-ffbc00)
![Ghostty](https://img.shields.io/badge/terminal-Ghostty-3551f3)
![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)

<!-- screenshot to add: <img src="docs/screenshots/hero.png" alt="Claudio open on the right edge of a KDE Plasma desktop, with its coloured glow" width="100%"> -->

</div>

## What it is

Claudio is a [Ghostty](https://ghostty.org) quick terminal running [Claude Code](https://code.claude.com/docs),
dressed up to feel like part of the desktop:

- **Always one key away.** <kbd>Meta</kbd>+<kbd>C</kbd>, the **Copilot key** on new laptops, or a click on the tray icon.
  It stays running in the background, so your chats are still there when you bring it back.
- **Reveal effects.** A KWin effect draws how it appears and disappears: **glitch**, **decrypt**, **scan**, a plain **slide**, or nothing.
- **Animated glow.** A soft halo flows around the sidebar in 2 to 4 colours of your choice.
- **Several chats at once.** One Claude Code chat per tab; each tab is titled after its conversation.
- **Usage at a glance.** A tray icon shows how much of your 5-hour Claude window you have used and the minutes until it resets.
  It pulses while a chat is working, and you get a notification when a long job is done.
- **Frosted glass.** Rounded corners and a translucent background, blurred by KWin.

No network calls of its own, no API keys: usage figures come from the data Claude Code already passes to its status line.

## Reveal effects

| Effect | |
|---|---|
| **glitch** | the window arrives in horizontal bands that jerk into place, with RGB split, flicker and scanlines |
| **decrypt** | a grid of green glyphs keeps changing, then resolves into the terminal from top to bottom |
| **scan** | a cyan line sweeps across a blurred hologram, leaving the sharp window behind it |
| **slide** | a clean slide in from the edge of the screen |
| **none** | just appears |

<!-- screenshots to add: docs/screenshots/{glitch,decrypt,scan}.png and docs/screenshots/reveal.gif -->

Pick one from the tray menu, with `claudio-effect glitch|decrypt|scan|slide|none`,
or in *System Settings → Window Management → Desktop Effects → Claudio reveal*.
Speed, intensity and the number of glitch bands are adjustable too.

## Tray icon

<div align="center"><img src="docs/screenshots/tray-states.png" width="100%" alt="Tray icon states: no data, 42% used with 87 minutes to reset, 76%, 93%, and the glow while a chat is working"></div>

<!-- screenshot to add: docs/screenshots/tray-menu.png (right-click menu) -->

| Action | What happens |
|---|---|
| Left click | show/hide Claudio |
| Middle click | notification with session and weekly usage, and which chats are working |
| Right click | settings: reveal effect, speed, intensity, glitch bands, glow colours |
| Hover | the same details as a tooltip |

The ring is green, then amber from 70% and red from 90%; the small number below is the minutes until the 5-hour window resets.

## Requirements

- **KDE Plasma 6 on Wayland** (KWin effects and scripts, global shortcuts through the desktop portal)
- **Ghostty** 1.3 or newer
- **Claude Code** — from the [native installer](https://code.claude.com/docs/en/setup) or the `claude-code` AUR package
- Python 3 with PyGObject, `qdbus6`, `kioclient`, `kwriteconfig6` (all part of a normal Plasma install)
- Optional: [Better Blur DX](https://github.com/xarblu/kwin-effects-better-blur-dx) for a stronger frosted-glass look

The tray icon on its own also works in other StatusNotifierItem trays (it just cannot open the sidebar there).

## Install

### Arch Linux (AUR)

```bash
yay -S claudio          # or paru, or: git clone https://aur.archlinux.org/claudio.git && cd claudio && makepkg -si
claudio-setup           # once, as your own user
```

### From source

```bash
git clone https://github.com/RemoGrillo/claudio.git
cd claudio
make                            # builds noslide.so and the shaders (needs qt6-shadertools and wayland headers)
sudo make install PREFIX=/usr   # or skip this and run everything straight from the checkout
claudio-setup                   # or ./bin/claudio-setup from the checkout
```

`claudio-setup` is per user and safe to run again. It:

1. copies the default colours to `~/.config/claudio/colors.conf`;
2. enables the KWin effect `claudio_reveal` and the KWin script `claudio-glow`;
3. adds autostart entries for Claudio, the tray icon and (if your user can read the keyboards) the Copilot key;
4. adds Claudio's hooks and status line to `~/.claude/settings.json` (a backup is saved next to it).
   If you already have a status line it is left alone: `claudio-setup --statusline` replaces it.

Then press <kbd>Meta</kbd>+<kbd>C</kbd> (or run `claudio-toggle`). The first time, KDE asks you to allow Claudio's global shortcut.

## Usage

| Keys | |
|---|---|
| <kbd>Meta</kbd>+<kbd>C</kbd> / Copilot key | show/hide Claudio |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd> | new chat in a new tab |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>W</kbd> | close the tab |
| <kbd>Ctrl</kbd>+<kbd>Tab</kbd>, <kbd>Alt</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | switch chat |

Change the global shortcut in *System Settings → Keyboard → Shortcuts → Claudio*.

**Copilot key.** It sends <kbd>Meta</kbd>+<kbd>Shift</kbd>+<kbd>F23</kbd>, which KDE's shortcut system cannot bind.
`claudio-copilot-key` reads the keyboards directly to catch it, so your user needs to be in the `input` group
(`sudo usermod -aG input $USER`, then log in again and rerun `claudio-setup`). It only listens for that one key.
Keep in mind that membership of `input` lets any program you run read keyboard input.

## Configuration

| File | What |
|---|---|
| `~/.config/claudio/colors.conf` | glow, tray and active-tab colours (2–4 colours plus an optional highlight); picked up live |
| `~/.config/claudio/ghostty.conf` | your Ghostty overrides for Claudio only: size, opacity, font… |
| `kwinrc` → `[Effect-claudio_reveal]` | reveal effect settings (use `claudio-effect` or the tray menu) |

For example, a wider and more opaque sidebar:

```ini
# ~/.config/claudio/ghostty.conf
quick-terminal-size = 40%,90%
background-opacity = 0.85
```

`claudio-effect` without arguments prints the current reveal settings:

```text
$ claudio-effect
effect=glitch speed=1.0 duration=0/0 ms (0 = auto) bands=14 intensity=1.0
$ claudio-effect decrypt && claudio-effect speed 1.5
```

## How it works

| Piece | Role |
|---|---|
| `claudio` | starts a dedicated Ghostty instance (`io.github.remogrillo.claudio`) as a quick terminal docked to the right |
| `noslide.so` | `LD_PRELOAD`ed into that Ghostty only: hides KWin's slide protocol so the reveal effect can draw instead |
| `claudio_reveal` | KWin effect (JavaScript + GLSL) animating the sidebar in and out |
| `claudio-glow` | KWin script (QML + a Qt shader) drawing the halo around the sidebar, with a hole for KRunner |
| `claudio-tab` | runs `claude` in each tab |
| `claudio-statusline` | Claude Code status line; saves the usage limits to `~/.cache/claudio/usage.json` |
| `claudio-hook` | Claude Code hook; tracks which Claudio chats are working, notifies when long jobs finish |
| `claudio-tray` | StatusNotifierItem tray icon with a dbusmenu settings menu |
| `claudio-toggle` | shows/hides Claudio through KDE's global shortcut, starting it if needed |
| `claudio-copilot-key` | turns Copilot key presses into `claudio-toggle` |

## Uninstall

```bash
claudio-setup --remove   # as each user; keeps ~/.config/claudio
sudo pacman -R claudio   # or: sudo make uninstall PREFIX=/usr
```

## Troubleshooting

- **Nothing happens on <kbd>Meta</kbd>+<kbd>C</kbd>:** check that Claudio is running (`pgrep -f claudio.conf`) and that the
  shortcut is listed under *Shortcuts → Claudio*. Running `claudio-toggle` from a terminal starts it if needed.
- **No animation, or KWin's own slide:** `qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded claudio_reveal`
  should print `true`; `journalctl --user -b | grep claudio_reveal` shows shader errors.
- **The tray icon shows "–":** Claude Code has not sent usage data yet (send a message), or another status line is configured
  (`claudio-setup --statusline`).
- **No glow:** the glow script needs `glow.frag.qsb`, built by `make`; after a big Qt update rebuild it.

## Credits

Made by [Remo Grillo](https://github.com/RemoGrillo). Claudio is an unofficial project, not affiliated with or endorsed by
Anthropic; Claude and Claude Code are trademarks of Anthropic.

Licensed under the [GNU GPL v3 or later](LICENSE).
