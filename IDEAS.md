# Ideas

This document covers some experiments that are up for grabs but might take
serious efforts and maybe not even possible.

## I1 - Decoupled 'Workspaces'

The wm code is thankfully mostly written in a way that it can run multiple
sets of rows indepedently. This is not being leveraged to full effect and
a way of having multiple workspaces and group/move them would be useful.

This could be useful to map to multiple spaces as well of course, along
with controls for importing / exporting between spaces.

## I2 - Minimap

This is a tool with a lot of potential utility. Create a zoomed out view
as a minimap for quick navigation without modifying zoom would be helpful.
This should also be exposable as an external connection point in order to
use other devices like a streamdeck or tablet.

## I3 - Waypoints

This should be quick and easy to implement, perhaps more difficult to find a UI
language for (popup dialog?), but being able to save the current position /
zoom levels in order to have a set of favorites and jump between them (with
preview, but that is a more difficult thing).

## I4 - OSD Keyboard

To allow for mouse/touch/pen only navigation, a tool for using the builtin/
osdkbd.lua helper script would be useful. The complex part is probably to
figure out which 'extra' buttons should be added for context/controls, and how
to attach to expression-cell completion helpers. It should also be treated as
its own overlay that is not anchored to the wm.

## I5 - Save / Restore

There is currently no persistance at all, it should be possible to save the
current layout and reload it. This should re-use the scripts/ facility that
testing and autorun can do.

## I6 - Scene to Shell Export

This is a big one. It should 'for most' cases be possible to translate the
rows/cells into a shell script. While there are things that will certainly be
off-limits and heuristics needed to control - some pipelines would surely be
possible.

## I7 - Dependency Overlay

It's easy to get confused by which cells are dependent on what content, Rows
are supposed to help that somewhat but when other expressions are set it isn't
as easy. Even for rows it should be visually indicated where there is a pipe
and not.

## I8 - Type Helpers

The table that each cell expression function uses to register and integrate
prepared for type- helpers, but no such helpers have been written yet. The idea
was that constrained arguments, say cell addresses and so on, could have
extended visual helpers that popup and expand into function arguments.

## I9 - Multidisplay

Currently a single large surface is only considered - while there are multiple
paths for how hotplugging displays could work, but the more interesting is
probably to combine link-target from I2 and run that through a separate rtgt
that is mapped to the new displays.

Others is to mimic the durden tactic and combine I1 with some way of moving
input focus between displays and have them be isolated.

## I10 - HUD-tool

Normal components, e.g. statusbar, lockscreen, ... could be added as a plugin
tool that exposes a set of connection pointers per screen (bonus points if made
generic enough to work as a builtin/ to upstream arcan).

## I11 - Internationalization

Add a LANGID as a reference to possible LUTs and lookup when picking labels in
popup menu or intercept set\_error. Should handle more OSD Keyboard layouts as
well. Arcan clients that doesn't respect GEOHINT should be updated (terminal
user messages, encode- OCR and encode- T2S), and the wayland-bridge needs an
xkb- table swap message.

## I12 - Desktop-Zoom-dependent Icons

This is in the mind-map post-it category. Having persistent notes that set
visibility and scale relative to the current global anchor zoom would allow
'traditional' ZUI note taking style data organization to work. Have that
handle both normal 'icons', 'post-its' and some visual partition (would
probably make sense). Bonus for working at < 1fps style eInk.

## I13 - Slouch-tool

A good project that spans both external processing creation and custom cell
development would be something that takes a camera feed, blur/sobel and runs it
through some off-the-shelf face, defines reference and exposes deviation from
this reference as a trigger.
