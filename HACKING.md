Interested in adding, extending, modifying or fixing features? great.

This short document tries to help you navigate where to go and what to do,
along with various pitfalls discovered as things are still being 'figured out'.

Out of ideas? Check the TODO.md for smaller one-shot projects.

Check the IDEAS.md for larger and more experimental ones. If you want to
discuss details before taking them on, find an issue that match the project, or
create one (tag it with 'enhancement' and make sure the name match the matter
in IDEAS.md).

In most cases you will need to use the scripting API of arcan itself. The set
of functions and documentation/examples thereof can be found in doc/\*.lua part
of the arcan source repository.

Generic
=======

Worthwhile to know is that certain high-level functions, extensions to the
_math_ _string_ and _table_ tables normally go into suppl.lua and eventually
merged into upstream arcan builtin/ (the system script path, e.g.
/usr/share/arcan/scripts/builtin) if they are sufficiently generic and usable.

Similarly, certain common functions; UI components like buttons and popups
along with special handlers like clipboard should be generalised and moved
into builtin/ and uiprim/ respectively to eventually get merged into Arcan.

From Inputs to Commands
=======================

commands.lua act as factories for interactive actions, e.g. what should happen
on a keypress or mouse gesture. They should implement little to no logic by
themselves, only sanity checks, validation and routing to the right subsystem.

Naming scheme is verb/(object or group)/(action or property) or type/property
for custom cell specific actions.

The function pipeworld_input(tbl) is the event entry-point for whenever arcan
receives an input event from any supported device, as well as when devices are
added or removed.

The 'builtin/mouse.lua' (arcan system script) gets first shot at processing
the events.

Thereafter it routes to special device string identifier hooks (intended for
tools that implement more complex input handling, e.g. game controllers and
touchscreens/trackpads). These come from

    pipeworld_input_hook_device(label, callback)

Finally, if nobody else wants the input - and it is from a translated
(keyboard) source, the current keylayout 'builtin/keyboard.lua (part of arcan)
is applied, the bindings table from bindings.lua applied - then onward to
whatever cell that holds the current input grab.

# Add a new built-in function

Adding functions to the expression cell API is probably the 'easiest'
modifications to make. This section describes how to do that.

## Pick a Scope

Determine the 'scope' based on what the function should effect.
Normal calculations, string operations and so on? then it is 'expression' scope.

If it modifies the properties of the current cell, such as size, sampling
filters, or response to an event? then it is 'cell' scope.

If it has a global effect, such as changing selection, destroying cells or even
shutting down, you are looking for 'system' scope.

If it outputs a complex result, e.g. rendering images, video, composites - then
it is 'factory'. Factory will apply to both 'expression' and to 'system'
(as the result can be added either as a new row/cell or be part of a longer
chain of expressions).

## Copy / Modify the template

Inside cells/api there is a template.lua file. Copy and rename this into the
cells/api/(scope) folder. The name (sans extension) will be the same name as
the function itself will have.

**Make sure to avoid name collisions in cell and system scope to the ones in
factory**

The template should cover and document all required fields, the more confusing
one is possibly 'type\_helper' as it intended as an input completion feature
where more advanced input might be needed, e.g. a color picker when a function
expects a color value.

# Modify the expression language

The expression language isn't set in stone, and it might be 'safer' to add a
cell type of your own for a different language you might want rather than
modifying the default one.

In any case, re-using some stages, like lexical analysis and the expression
API itself. Therefore, these are split out into cells/shared/parser.lua,
cells/shared/lexer.lua and cells/shared/api.

Shaders
=======

Shaders are split into base (effects that can be applied to cell contents as
part of an expression) and ui. The UI shaders follow the same patterns as in
[durden](https://github.com/letoram/durden), so look there for inspiration.

Decorations
===========

Cell decorations are a bit special, they use the builtin/decorator.lua script
that is part of the arcan respository. To overload that, copy it from there
(arcan system-script path, e.g. /usr/share/arcan/scripts/builtin) to the
builtin folder in pipeworld and modify in place.

Input / System 'Features'
========================

The 'tools' folder is scanned on startup. Each script there (that is not
in the user config.lua blocklist) will be executed after everything else
is initialized.

The included 'flair' tool is for desktop effects, such as the acrylic row
background blur and parallax scrolling. There is also an input example
(3dnav.lua) for use with 3d-mice.

Cells
=====

To add a new cell type:

* create a new .lua file with an appropriate name in the cells directory
* modify cellmgmt.lua to reference it
* add any relevant factory API (see add a new builtin function)

Each cell script has one or two possible returns: the factory function
and a table of command paths and handlers to add for custom actions that
should be bindable to inputs or popups:

    return
		function(row, cfg, myarg_1, myarg_2)
		    local res = pipeworld_cell_template("myname", row, cfg)
				-- do things to set res up
				res.plugin_state.something = 12 -- state you want to track
				return res
		end,
		{["/mycell/do/the/thing"] = some_function}

Window Management
=================

This part is the one with the most nuances too it - the scaling, zooming,
re-ordering etc. has a lot of subtle edge cases with animations while there
are ongoing animations.

If you want to dip into this, the main three scripts are 'wm.lua', 'row.lua'
and 'cells/shared/base.lua' - with all of them returning a table of function
that chain together.

Per 'WM' there can be many 'rows' and for each 'row' there can be many 'cells'.
The 'cells' have a set of known 'base' functions.

Timers
======

There is a shared system for having low-accuracy, low-precision timers. These
are clocked off a base of 25Hz (engine configuration thing). To use:

    timer_add_periodic(str:name, int:delay_ticks, bool:remove_after_use, func:on_enter, bool:hide)

The 'remove_after_use' means that the timer will be removed after firing (one-shot).

The 'name' is any unique string identifier, a collision here will replace/update any
existing timer with that name.

After registering, you can also manually manage its lifecycle:

    timer_delete(name)
		timer_resume(name)
		timer_suspend(name)

There are also 'on-idle' timers that activate after a certain idle-period:

    timer_add_idle(str:name, int:delay_ticks, bool:remove_after_use, func:on_enter, func:on_leave, bool:hide)

External Processor
==================

There are three APIs for writing clients that can be invoked through the CLI or
through the Lua Arcan API (see launch\_target in the Lua documentation).

1. ALT - (high-level, easy) the same interface as Pipeworld itself is written
in, i.e. Lua scripts with some restrictions on folder and file structure. Tools
written in this are 'started' through arcan (or arcan_lwa) itself:

    mkdir test
		echo "function test() end" > test/test.lua
		arcan ./test

2. TUI - (mid-level, C) is similar to a better 'ncurses'. It is intended for
test-dominant UIs with a vtable like dispatch structure. See doc/exttool/tui
for a template.

3. SHMIF (low-level) with a traditional 'event-loop' like workflow and mainly
works 'per pixel'. See doc/exttool/shmif for a template.

The common denominator for these is how they hook up to Pipeworld. There are
currently two paths:

    listen-cell: {/row/add/listen, "hi"}
    ARCAN_CONNPATH=hi my_thing

The second is by manually registering it as a launchable 'target':

    arcan_db add_target mything BIN /path/to/the/thing (for TUI/SHMIF)
    target-cell: {/row/add/target, "mything"}

There is a lot of nuance to the second form, multiple sets of command line
options can be set as 'configurations' - custom metadata tags can be used for
writing more advanced tools, and they have access to per-target/per/config
key-value stores.

A third will be through the cli-cell (requires changes in upstream Arcan):

    mode arcan
		./app
		cli-cell: {/row/add/cli, "mode=arcan:cli=/path/to/the/thing"}

The added value with the second and third form is that the chain of trust is
retained, connections are inherited from the display server launching rather
than subject to something that could be a man-in-the-middle.
