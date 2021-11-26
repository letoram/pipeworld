About
=====

Pipeworld is a zooming dataflow tool and desktop heavily inspired by
[userland](https://www.userland.org). It is built using the [arcan desktop
engine](https://arcan-fe.com) [git](https://github.com/letoram/arcan).

It combines the programmable processing of shell scripts and pipes, the
interactive visual addressing/programming model of spread sheets, the
scenegraph- and interactive controls-, IPC- and client processing- of display
servers into one model with zoomable tiling window management.

It can be used as a standalone desktop of its own, or as a normal application
within another desktop as a 'substitute' for your normal terminal emulator.

It is described further in the article here:
[introducing pipeworld](https://arcan-fe.com/2021/04/12/introducing-pipeworld)

A longer video clip showcasing some features can be found here:
[Youtube - UI Demo](https://www.youtube.com/watch?v=zZqKD-p4GpE)

Contact
=======
Only use github issues for real bugs, not for support or wishful thinking
about features you dream of someone developing for you.

Oldschool chatter at #arcan on irc.freenode.net.

Discord invite at http://chat.divergent-desktop.org.

See the 'HACKING.md' for ways to contribute, 'TODO.md' for smaller things in
the near future and 'IDEAS.md' for bigger projects.

Use
===

*This project is used to drive the development of Arcan further, and requires a
very recent build of Arcan to work properly or even at all. Relying on packages
from your distribution can have weird and unexpected behaviour. Don't report
issues unless you are running with the current master branch of Arcan first.*

Assuming a working arcan installation, entering pipeworld should be no more
difficult than:

    arcan /path/to/pipeworld/pipeworld

Or just:

    arcan pipeworld

If it is added into your arcan applpath (.arcan/appl or /usr/share/arcan/appl).

You might want to look at the bindings.lua and config.lua lua files to modify
input controls and look/feel first, particularly the meta keys as those tend to
be different if you are running standalone or as part of another desktop.

The model is fairly simple:

You have _rows_ and _cells_. A _row_ act as a container (visual partition and
logical address) of a chain of 1..n cells, and each cell represents a data
consumer, producer or producer-consumer.

The first cell in a row defines how the row behaves, it is 'typed', see the
'Cell Model' section further below for more details.

By default, the first cell you will see is of the expression type, and it is
the cell type that will be created by default when a new row is built.

This cell acts as a namespaced command-line interface, see 'Expression Cell'
further below. Worthwhile to know:

    :shutdown()

Will cause the system function 'shutdown' to be called.

The window management style is 'zooming-tiling' - each logical group (cell,
row, world) has a magnification level and a density level. The easiest way to
get a feel for how this works is to use a mouse, and then add the patterns you
establish as keybindings.

Actions to try out:

 * mouse wheel on background (zoom in/out all)
 * mouse l-drag on background (pan)
 * mouse l-drag+rbutton on background (zoom in/out selected row)
 * double-click on background (toggle 1:1 or last zoom)
 * double-click on row (toggle 1:1 or last zoom for row)
 * mouse wheel on row background (zoom row in / out)
 * double-click on cell (toggle 1:1)
 * right-click on background, row-background and cell label

These actions all change the magnification or 'scale' the contents of the cell,
thus the clients do not receive any notifications to try and resize which is a
much more expensive option.

Configuration
=============

Check 'pipeworld/keybindings.lua' for default input bindings and for adding
your own. These map to one or many commands from the 'pipeworld/commands.lua'
file.

To see most of the currently available commands:

    grep cmdtree commands.lua

The commands and tools will be documented when the project is a bit more mature
and the set has stabilized.

Sets of commands can also be at startup. These are defined in the
'pipeworld/scripts/autorun.lua' file. Other scripts in this folder can also be
run at startup like this:

    arcan pipeworld tests/listen.lua

Which would run the test script 'listen.lua' in pipeworld/scripts/tests.

The 'devmaps' folder contains configuration files for tool (optional plugins),
advanced input and client colorschemes.

To change visuals, window management behaviour, animation speed and so on,
see the 'pipeworld/config.lua' file. To avoid modifying it directly and risking
merge collisions when we update and extend the set of options, you can
create sets of configuration overrides in the pipeworld/devmaps/themes folder.

These can be switched to at runtime by running the system expression:

    :theme("mytheme")

See further below for an explanation on running expressions.

The pipeworld/devmaps/themes/default.lua will be set automatically on startup,
and will remain empty in the git for the purpose of easy modification.

Popups
======

In the menus/ folder you will find bindings that control the various popups
that can be triggered on mouse or command bindings. These map to commands in
command.lua, so it is trivial to extend with your own.

These are:

 * system.lua (right-click wallpaper for system context menu)
 * label.lua (right-click on text label)
 * insert.lua (rclick on-over surface below last row)
 * row.lua (rclick on row background)

Automation / Testing
====================

Any arguments passed after 'pipeworld' on the command line will be treated as a
references to entries in the scripts/ subdirectory. These are simply tables of
commands matching the same set of actions available to keybindings, and will be
executed in the same order as provided on the command line.

This can be used to setup your default workspace as well as for testing changes.

Cell Model
==========

Cells are typed, and the type of the cell itself defines how it and other cells
in the row will behave, the inputs it will accept and the outputs it can
provide.

Cells has an evolving set of properties and parameters, some experimental and
undocumented for the time being.

The short list of existing cell types and their arguments is as follows:

* expression([preset], [commit], [namespace])
* capture([identifier]) - arcan-decode (afsrv\_decode) capture support (e.g. webcam)
* cli([w], [h], [arg], [detach]) - arcan builtin command-line
* compose(cell1, cell2, ...) - merge together contents from other cells
* debug(cell, [builtin]) - inject a debug window into a client
* image(resource) - single image loading
* listen(name) - opens a connection point for redirecting clients to (ARCAN\_CONNPATH=name)
* term([cmd]) - terminal emulator
* target([name]) - launching a specific application (see below)
* adopt([vid]) - special case, used internally

## Expression Cell

The main cell type that you will deal with is the 'Expression' cell, and it is
the default when you click to add a new cell, as shown in the clip here:

Some things to note about the expression cell:

1. `#` switches to CLI mode
2. `!` switches to Terminal mode (bash) or terminal-exec e.g. ! /bin/ls
3. `:` evaluates in 'system' scope
4. `.` evaluates in 'cell' scope
5. all other expressions are in normal ('expression') scope.

A cell that has changed or derived from cell-action can be reverted to its
initial state through the /revert/cell command path, discarding any previous
contents.

The 'expression' scope is the default scope for builtin functions. It should
be the one most commonly use and support basic arithmetic and other kinds of
expressions:

     1 + 2 * A1 + max(A2, B2)

An expression cell can also be used as a popup with a certain scope. The two
commands for that are '/cursor/cellexpr' and 'cursor/sysexpr' respectively.
(Default binding to m1+s for system and m1+d for cell).

In those cases the scope prefix (. or :) is implied and forced.

Some functions support completion and argument type helpers, use 'TAB' to
bring up the completion, and F1 for the helper text.

The rule of thumb is that functions that have a global effect, such as
creating new cells, modifying inputs and so on are added to the system scope.
Functions that change cell properties, such as assigning an alias tag:

    .tag("hi")

Belong to the cell scope. Each function exists as a single file in
cells/api/[system,cell,expression] and are scanned on startup.

Just like with the bindable 'commands.lua', the set of functions is evolving
and is currently undocumented. See the following folders:

    pipeworld/cells/api/expression
    pipeworld/cells/api/system
    pipeworld/cells/api/cell
    pipeworld/cells/api/factory

For the current commands (one file per command). The 'factory' folder is
a bit special and will result in commands in both cell and system scope.

## Terminal Cell

The terminal cell is simply a Vt100 compatible terminal emulator. It can
be switched to from the expression cell by entering '#' or run a single command
with:

    ! ls /usr

That can also be bound as a menu entry, keybinding or similar :

    {"/insert/row/term", "find /usr"}

## Target Cell

Arcan has a facility for defining external programs that can be launched, and
how those are setup. See the 'arcan\_db' tool manpage for more details, but the
short version is:

    arcan_db add_target BIN mytool /usr/bin/mytool arg1 arg2
    arcan_db add_config mytool test arg3 arg4

    {"/insert/row/target", "mytool", "test"}

Which would spawn a new process with an inherited connection through
'/usr/bin/mytool arg1 arg2 arg3 arg4'. This is only for applications that use
Arcans native client APIs (SHMIF and TUI). This includes other protocol
bridging tools, such as arcan-wayland (again using arcan\_db):

    add_target BIN weston-terminal /usr/bin/arcan-wayland -exec weston-terminal
    add_target BIN chromium-x11wl /usr/bin/arcan-wayland -exec-x11 chromium
    add_target BIN chromium-x11 /usr/bin/arcan_xwm -Xarcan chromium

## CLI mode

The external CLI is part of Arcan, and while it looks like a normal 'terminal'
prompt, it is not. The set of built-in commands it provides is limited, and it
is mainly useful for launching other programs.

The 'cd' command changes the current directory, while 'mode' changes execution
mode.  This is important as different clients have different needs from its
environment in order to connect properly.

The different modes are:

    x11
    wayland
    vt100 (will wrap through a terminal emulator)
    arcan

e.g.

    mode x11
    chromium

Would start chromium under X11.

The 'open' command will treat its argument as a media file, and the supported
formats are limited by what 'afsrv_decode' in arcan is compiled to handle.
