## Core
 - adopt handler
 - save / restore layout

## Misc / Assets
 - Proper static website with documentation
 - Separate API documentation (re-use arcan doc/\*.lua format and add generator)
 - Logo + related icons

## afsrv\_terminal (cli.c)
 - improve prompt
 - hooks / dlopen interface for custom shell
 - list -> list window browse -> decode handover
 - forward information about executed window in handover request
 - expand / collapse between command and title
 - autodetect launch mode? (i.e. arcan, terminal-emulator, wayland or xwayland)

## WM
 - move/swap mode (pick cell or part of cell)
 - icon if provided on small scale
 - repeat- rate controls (builtin/keyboard.lua)
 - touch/trackpad support (import from- share with- durden)
 - row 'decorations' (selected row only, shown on leftmost edge or attach to current label if not visible)
 - global clipboard with meta+c/v and middle-click
 - maximize toggle and wheel-scale down seem to include label in row-bg size
 - binding/indicator to show if child should replace parent or remain (:debug(,true) -> pick)
 - cell contents pan/zoom (without changing global / row scale)
 - work logging / IPC to behave like in durden/safespaces
 - draw to resize or slice

## Video
 - downsample shader (content preserving)
 - hand-convert retroarch shaders
 - slice (custom texture coordinate set)

## Bugs
 - input-scale factor wrong for mice in xwayland/wayland clients
 - xwayland/wayland clients create initial empty cells before the 'main one'
 - wayland cell needs a composited mode for dealing with x window management and subsurfaces (rt in builtin/wayland)
 - sometimes input grab remains on the wrong cell (often on creation/deletion)
   reproduce: popup cell, cancel with background click, popup again -> input dead
 - system popup fails on rclick

## Composition cell
 - more binpacking policies (tiling, stacking)
 - tunables: density, dimensions, colour space and format
 - input controls
 - dynamic add/remove
 - react on source resizes
 - transform (rotate, blend)
 - individual shaders
 - set audio source
 - updates clocked based on source updates

## Audio mixer cell
 - visualization
 - delay injection
 - filters
 - add / remove sources

## Audio synthesis cell
 - sample or function expression

## Graph Cell
 - for taking set of [number, string, ...]

## CLI/TUI cell
 - support completion / integration

## External Cell
 - bond\_target across row (see pipe system command)
 - progress indicator (for content state hints) / scroll bar
 - store/restore state controls
 - suspend/resume
 - proper 'paste'
 - file-open/save controls
 - allow some child windows (popup, icon)

## 'Special'
 - chain-loader for plugging in as HUD-tool in durden
 - chain-loader for plugging in as layer in safespaces

## Flair Tool
 - theme switching
 - transitions between themes (e.g. day/night), interpolate in perceptual space
 - animated background (reflection plane, rain on glass)
 - external LED controller mapping

## Wheel Input tool
 - combine with 3Dnav tool? (press-spin for stepping scale, ...)

## Touch Input Tool
 - import / borrow classifiers from durden
 - calibration mode
 - allow to pair with secondary screen (think Asus ScreenPad)

## Media Cell
 - build from capture cell with other arguments to afsrv\_decode
 - type helper that deals with both file picking and external url/media source enum

## Icon Cell
 - Reference icon that mutates back and forth between another factory (e.g. target-cell) and itself
 - Can also spawn multiple instances of the referenced target as new cells/rows
 - Persistance from config file? (or just rely on autorun?)

## Expression cell
 - BUG: single symbol resolving to function call without () says missing function/sym
 - dynamic command loading / reloading
 - generate API reference from cells/api/...
 - document grammar..
 - 'destroy' on expression mutated cell reverting to prefilled expression
 - mouse picking (meta + click cell -> lookup and add)
 - auto-parent when ) is unbalanced, e.g. 1+2*4 ) -> 1+2*(4) -> 1+2*(4)) -> 1+2(*4))
 - highlight error / token
 - ranges
 - history
   - save/load between sessions
   - pattern search (ctrl+r)
   - prefix completion
   - 'keyed' by key={expression}
 - result-history below expression (property toggle)
   - visualize history (similar to how output representation can be cycled)
 - timer / delay / yield (more asynch processing)
 - api for other cells / tools to register expression functions
 - ... in parser to expand arguments as interpolation from previous symbol to next symbol

## Tools/T2s
 - Bringup (speak cell path, type, name, expression, ...)

## Notifications
 - Bringup (hook fsrv.lua, alert messages)
