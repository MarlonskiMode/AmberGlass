# Amber Glass

Draw a rectangle on your Mac and everything inside it turns into a live amber display. The app reads the screen under the rectangle, converts it to greyscale, then paints the tones from black to amber. Brightness, contrast, and the amber hue can all be dialed in, and the pane keeps updating as you work underneath it.

[Box Tint](#box-tint), a companion that lays stained-glass color over the screen without recording it, lives in the same project.

## Amber Glass

- **Draw panes.** Click Draw Amber Pane, then drag on the desktop. Hold Shift for a square. Option-click a pane to remove it, Command-Z undoes, and Esc finishes. Panes cover every display and every Space, including full-screen apps.
- **Live recolor.** Pixels under a pane are captured, desaturated, and mapped from black in the shadows to your chosen amber in the highlights. Video and scrolling update in place. Clicks pass through, so you keep using the apps underneath.
- **Tone.** A dial moves the highlight color from amber (`#FFB000`) to a deep burnt orange (`#8C2F00`). The readout shows the exact hex.
- **Brightness and contrast.** Brightness runs from −100 to +100. Contrast runs from 0% to 200%, so it can go both below and above the original. Double-click a dial to reset it. Changes apply immediately to every pane.
- **Stays put.** Panes and dial settings are saved and come back the next time you open the app. Closing the window leaves the panes up; quit from the menu bar icon.

### Shortcuts

These work while other apps are focused.

| Shortcut | Action |
| --- | --- |
| ⌃⌥⌘A | Start or finish drawing |
| ⌃⌥⇧⌘Z | Undo the last pane |
| ⌃⌥⇧⌘⌫ | Clear every pane |

### Screen Recording

Amber Glass has to read the pixels it recolors, so macOS requires Screen Recording permission. Allow it when prompted, then quit and reopen the app. macOS only applies the permission to a freshly launched copy. While panes are visible, the system shows its recording indicator in the menu bar.

The build script signs the app with a stable local certificate named Box Tint Local. Permission survives later rebuilds. If a pane ever stays a flat tint and the window says permission is needed even though the switch is on, click Reset and Relaunch in the app, allow the prompt, and open it once more.

## Box Tint

Box Tint lays translucent color over the screen instead of recoloring the pixels, so it needs no special permission. It cannot increase contrast. Brightness below zero darkens toward black, brightness above zero lightens toward white, and contrast only washes toward gray.

- Pick a color from the stained-glass palette, type a hex code (`#RGB`, `#RRGGBB`, or `#RRGGBBAA`), or use the color well. An 8-digit hex also sets the density.
- Density, brightness, contrast, and an optional glass sheen are stored with each pane. Apply to All Panes copies the current settings onto panes already on screen.
- Drawing works the same way as Amber Glass.

| Shortcut | Action |
| --- | --- |
| ⌃⌥⌘T | Start or finish drawing |
| ⌃⌥⌘Z | Undo the last pane |
| ⌃⌥⌘⌫ | Clear every pane |

The undo and clear shortcuts differ from Amber Glass so both apps can run at the same time.

## Requirements

macOS 14 or later. Xcode or the Swift command-line tools.

## Build

From the project folder:

```bash
./build.sh            # creates build/Amber Glass.app and build/Box Tint.app
./build.sh --install  # also copies both apps into /Applications
```

The first build creates the Box Tint Local code-signing certificate in your login keychain and trusts it for signing. Later builds reuse it.

Open either app from `/Applications`, Spotlight, or Launchpad. Neither app starts at login on its own.
