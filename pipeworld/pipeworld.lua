-- state table for built-in keyboard layout handling
local keyboard
local bindings
local cfg
local anchor
local actions
local input_underlay
local run_script_set
local wm
local shader_rescan
local tool_hooks = {}
local spawn_popup

-- used for hooking non-keybound inputs
local input_grab
local input_grab_ref

local function run_action(action, ...)
	if type(action) == "string" then
		actions(action, ...)
		return true

-- handle argument expansion or table of tables to have a macro- action
	elseif type(action) == "table" then
		if action.group then
			for _, v in ipairs(action.group) do
				run_action(v)
			end
		else
			run_action(action[1], unpack(action, 2))
		end
		return true
	end
end

-- this ignores the normal pipeworld grab input chain
function pipeworld_popup_capture(anchor, cancel)
-- custom cursor for the current selection add a mouse grab surface
	local grab = null_surface(wm.w, wm.h)
	link_image(grab, anchor)
	image_mask_clear(grab, MASK_POSITION)

	local mh = {}

	mh.name = "popup_grab"

-- remember the old input grab
	local ogrb = input_grab
	local oref = input_grab_ref

	local restore =
	function()
		if valid_vid(grab) then
			mouse_droplistener(mh)
			delete_image(grab)
			input_grab = ogrb
			input_grab_ref = oref
		end
	end

-- click on the grab surface will trigger
	mh.click = function()
		cancel()
		restore()
	end

	mh.rclick = mh.click
	mh.own = function(ctx, vid)
		return vid == grab
	end
	mouse_addlistener(mh)
	order_image(grab, 65529)
	show_image(grab)

-- closure to call on completion
	return restore
end

function pipeworld_grab_input(ref, new_grab)
-- tries to modify grab someone else has
	if input_grab_ref and input_grab_ref ~= ref then
--		print("grab violation", debug.traceback())
		return input_grab_ref, input_grab
	end

-- mark that we are switching grab
	if input_grab and new_grab ~= input_grab then
		input_grab()
	end

	if not new_grab then
		input_grab_ref = nil
		input_grab = nil
	else
		input_grab_ref = ref
		input_grab = new_grab
	end
end

local recovery_row
function pipeworld_adopt(vid, kind, title, parent, last)
	if kind == "unknown" then
		return false
	end

-- Adopt is complex as always since we want to retain row order and cell
-- position in the hierarcy, as well as reconstruct rows that has an internal
-- type, e.g. expressions. The proper tactic for that is to have a function
-- that can sweep the rows and store them as temp_row_num_type and let the
-- different cell types expose a factory string for reconstructing them.
--
-- For the time being, just take the allowed primary types and assign them
-- to a recovery row and wrap the adopt objects through a factory
	if not recovery_row then
-- register our meta factory
	end
end

local function setup_mouse_support()

-- add a cursor image to one of the overlay planes, fallback to a single
-- colored box if the cursor image gets broken in some way
	local cursor = load_image("cursor/default.png")
	if not valid_vid(cursor) then
		cursor = fill_surface(8, 8, 0, 255, 0)
		image_tracetag(cursor, "cursor")
	end
	mouse_setup(cursor, 65535, 1, true, false)
	input_underlay = null_surface(VRESW, VRESH)
	show_image(input_underlay)
	image_tracetag(input_underlay, "input_underlay")

	local ms = mouse_state()
	if cfg.mouse_autohide > 0 then
		ms.autohide = true
		ms.hide_base = cfg.mouse_autohide
	end

	local rclick_consume
	mouse_addlistener({
		name = "underlay",
		own = function(ctx, vid)
			return vid == input_underlay
		end,

		motion = function(ctx, vid, dx, dy, x, y)
		end,

		drop = function(ctx)
			wm.pan_block = false
			wm.pan_deadline = CLOCK + 50
		end,

		dblclick = function(ctx)
			run_action(bindings["bg_mouse_dblclick"])
		end,

		rclick = function(ctx)
			if rclick_consume then
				rclick_consume = false
				return
			end

			run_action(bindings["bg_mouse_rclick"])
		end,

		drag = function(ctx, vid, dx, dy)
-- block the anchor from being dragged around when there is nothing visible
-- as that would displayce the 'click to spawn' anchor
			if #wm.rows == 0 then
				return
			end

-- disable autopanning so it is possible to "look around" without repanning
			wm.pan_block = true

			local mstate = mouse_state()
			local zoom = mstate.btns[MOUSE_RBUTTON]
			if zoom then
				rclick_consume = true
				local sum = dx + dy
				if sum > 0 then
					run_action("/scale/row/increment", 0.01)
				elseif sum < 0 then
					run_action("/scale/row/decrement", 0.01)
				end
				wm:invalidate(true, true)

-- nudge-anchor is a tool hookable state as it might affect other on-screen items
			else
				wm:nudge_anchor(dx, dy)
			end
		end,

		button =
		function(ctx, vid, index, active, x, y)
			if not active then
				return
			end
			wm:drop_popup()
			if index == MOUSE_WHEELPY then
				run_action(bindings["bg_mouse_wheel_up"])
			elseif index == MOUSE_WHEELNY then
				run_action(bindings["bg_mouse_wheel_down"])
			end
		end,
		})
end

local function nudge_anchor(wm, dx, dy)
	for _, v in ipairs(tool_hooks) do
		v(wm, "pan", dx, dy)
	end
end

function pipeworld(args)
	system_load("builtin/string.lua")()
	system_load("builtin/table.lua")()

	keyboard, bindings = system_load("bindings.lua")()
	mouse    = system_load("builtin/mouse.lua")()
	suppl    = system_load("suppl.lua")()         -- string/table helpers
	cfg      = system_load("config.lua")()        -- visual/wm preferences
	system_load("timer.lua")()                    -- hooks for adding _clock_pulse timers
	system_load("fsrv.lua")()                     -- default dispatch handler used by cells
	spawn_popup = system_load("ui/popup.lua")()

	setup_mouse_support()

-- expose possible handlers for wm invalidation
	cfg.on_wm_dirty = {}
	cfg.input_grab = pipeworld_grab_input
	cfg.popup_grab = pipeworld_popup_capture
	cfg.keyboard = keyboard

-- wallpaper / flair tools need this information
	anchor = null_surface(1, 1)
	cfg.world_anchor = anchor

	pipeworld_shader_setup, shader_rescan = system_load("shaders/shader.lua")()

-- separate anchor and background so we can have a wallpaper that doesn't pan
-- or use different inputs to control its panning
	show_image(anchor)
	order_image(anchor, 2)
	image_tracetag(anchor, "grid_anchor")
	image_mask_set(anchor, MASK_UNPICKABLE)

-- tie the anchor to a new window manager, load it and populate with
-- cell types, registering  them as part of the wm
	wm = system_load("cellmgmt.lua")()(anchor, cfg)
	wm.run_action =
	function(...)
		run_action(wm, ...)
	end
	wm.action_bindings =
	function(wm, path)
		run_action(bindings[path])
	end

-- always run with a color, config can allow something more refined
	image_color(WORLDID, unpack(cfg.colors.background))
	cfg.wallpaper = system_load("wallpaper.lua")()(wm, cfg)
	show_image(cfg.wallpaper)

-- and a set of preset paths into the wm that the keybindings attach to
	cfg.actions = system_load("commands.lua")()(wm)
	actions = cfg.actions

-- extensions that don't fit well with the cell api model
	for i,v in ipairs(glob_resource("tools/*.lua")) do
		local name = string.sub(v, 1, -5)
		if not table.find_i(cfg.blocked_tools, name) then
			local fact = system_load("tools/" .. v, false)
			if not fact then
				warning("parsing error loading " .. v)
			else
				local ok, msg = pcall(fact(), wm, cfg)
				if not ok then
					warning("error loading tool " .. v .. ":" .. msg)
				elseif type(msg) == "function" then
					table.insert(tool_hooks, msg)
				end
			end
		end
	end

-- we hook this to let tools react when auto-panning modifies the anchor
	local old_nudge = wm.nudge_anchor
	wm.nudge_anchor =
	function(wm, dx, dy, ...)
		nudge_anchor(wm, dx, dy)
		old_nudge(wm, dx, dy, ...)
	end

	if #args > 0 then
		run_script_set(args, "scripts/")
	else
		run_script_set({"autorun.lua"}, "scripts/")
	end

-- now activate tools as we have the wm
	for _, v in ipairs(tool_hooks) do
		v(wm, "create")
	end

	wm:nudge_anchor(10, 10)
end

function pipeworld_get_symtable()
	return keyboard
end

local function process_keybind(iotbl)
	local sym = keyboard.tolabel(iotbl.keysym)
	if not sym then
		return false
	end

-- first check if any of our designated modifier meta keys are being held
-- this is the spot to also add other possible tactics like 'chords' and
-- resolve those to m1/m2 or some other prefix and then 'drop on consume'
	local m1 = false
	local m2 = false
	for _,v in ipairs(decode_modifiers(iotbl.modifiers)) do
		if v == bindings["meta_1"] then
			m1 = true
		elseif v == bindings["meta_2"] then
			m2 = true
		end
	end

	if not m1 and not m2 then
		return false
	end

	local modstr
	if m1 and m2 then
		modstr = "m1_m2_"
	elseif m2 then
		modstr = "m2_"
	else
		modstr = "m1_"
	end

-- might want to trigger on both rising and falling edge
	if iotbl.active then
		modstr = modstr .. sym
	else
		modstr = modstr .. "release_" .. sym
	end

	if not bindings[modstr] then
		return false
	end

-- regardless of the action, consume the keypress
	run_action(bindings[modstr])
	return true
end

local label_hooks = {
	analog = {},
	digital = {},
}

function pipeworld_input_hook_label(label, datatype, handler)
	label_hooks[datatype][label] = handler
end

local device_hooks = {}
local devhandlers = {}
function pipeworld_input_hook_device(devlbl, handler, soft)
	if soft and devhandlers[devlbl] then
		return
	end
	devhandlers[devlbl] = handler
end

function pipeworld_input(iotbl)
	if mouse_iotbl_input(iotbl) then
		return
	end

-- device added / removed?
	if iotbl.kind == "status" then
		if iotbl.action == "added" then
			local lh = devhandlers[iotbl.extlabel]
			if lh then
				devhandlers[iotbl.devid] = lh
			end
		end
		return
	end

-- check label hooks
	if iotbl.label then
		local hook
		if iotbl.analog then
			hook = label_hooks.analog[iotbl.label]
		elseif iotbl.digital then
			hook = label_hooks.digital[iotbl.label]
		end
		if hook then
			hook(wm, cfg, iotbl)
			return
		end
	end

-- check registered devices
	local dh = devhandlers[iotbl.devid]
	if not dh and iotbl.analog then
		dh = devhandlers["analog"]
	end

	if dh then
		if dh(wm, cfg, iotbl) then
			return
		end
	end

-- only keyboard input from now on, still allow a 'default analog'
	if not iotbl.translated then
		return
	end

-- translate / resolve and forward to active cell
	local sym, lutsym = keyboard:patch(iotbl)

	if process_keybind(iotbl) then
		return
	end

	if input_grab then
		input_grab(iotbl, sym, lutsym)
	end
end

function pipeworld_clock_pulse()
	mouse_tick(1)

-- enact repeat-rate
	local tbl = keyboard:tick()
	if tbl then
		for _, v in ipairs(tbl) do
			pipeworld_input(v)
		end
	end

	run_action("/tick")
end

function pipeworld_postframe_pulse()
end

function pipeworld_force_size(w, h, vppcm, hppcm)
	VRESW = w
	VRESH = h
	VPPCM = vppcm
	HPPCM = hppcm

	run_action("/resize/canvas", w, h, vppcm, hppcm)
	resize_video_canvas(w, h)
	resize_image(input_underlay, w, h)

-- also specify that the world density has changed
	rendertarget_reconfigure(WORLDID, vppcm, hppcm)

-- some shaders need to reload defaults as well
	mouse_querytarget(WORLDID)

	shader_rescan(
	function(name, key, value, shtbl)
		local shdr = cfg.shader_overrides[name]
		if shdr and shdr[key] then
			return shdr[key]
		end
		return value
	end)

-- and some tools might need to rebuild
	for _, v in ipairs(tool_hooks) do
		v(wm, "resize", VRESW, VRESH)
	end
end

-- this might get hijacked by a multidisplay tool
function pipeworld_display_state(status)
	if not cfg.lock_size then
		pipeworld_force_size(VRESW, VRESH, VPPCM, HPPCM)
	end
end

function pipeworld_popup_spawn(menu, nograb, spawn_anchor, anchor_p, opts)
	if not menu or #menu == 0 then
		return
	end

	local popup_config =
	{
		animation_in = 15,
		animation_out = 10,
		interp = cfg.animation_tween,
		text_valid = cfg.popup_text_valid,
		text_invalid = cfg.popup_text_invalid,

		border_attach =
		function(tbl, anchor)
			local mx, my = mouse_xy()
			order_image(anchor, 65530)

			if valid_vid(spawn_anchor) then
				link_image(anchor, spawn_anchor, anchor_p)
			else
				move_image(anchor, mx, my)
			end

-- all colors are set in the shader
			if valid_vid(tbl.outline) then
				delete_image(tbl.outline)
			end

			local surf = color_surface(8, 8, 0, 0, 0)
			link_image(surf, anchor)
			link_image(surf, anchor, ANCHOR_UL, ANCHOR_SCALE_WH)
			image_inherit_order(surf, true)
			resize_image(surf, 6, 6)
			move_image(surf, -3, -3)
			show_image(surf)
			tbl.outline = surf

			if tbl.options.inv_y then
				move_image(anchor, 0, -tbl.max_h + tbl.options.inv_y)
			end

			pipeworld_shader_setup(surf, "ui", "popup", "active")
			image_mask_set(surf, MASK_UNPICKABLE)
		end
	}

	opts = opts and opts or {}
	table.ensure_defaults(opts, popup_config)
	local pop = spawn_popup(menu, opts)

-- we want to use this code for some other things as well, mainly
-- autocompletion hints and then it makes sense to not have a universal grab
	if nograb then
		return pop
	end

	local grab_closure =
		pipeworld_popup_capture(
			pop.anchor,
			function()
				pop:cancel()
			end
		)

-- set a handler that both triggers the closure and dispatches the command
	pop.options.on_finish =
		function(ctx, item)
			grab_closure()

			if not item then
				return
			end

		if item.handler then
			item.handler()
		elseif item.command then
			run_action(item.command)
		end
	end

-- input grab is saved, so just replace it with this one that forwards to
-- our popup handler so that navigation works with keyboard as well
	input_grab =
	function(iotbl, sym, lutsym)
		if not iotbl or not iotbl.active then
			return
		end

		if sym == "UP" then
			pop:step_up()
		elseif sym == "DOWN" then
			pop:step_down()
		elseif sym == "ESCAPE" then
			pop:cancel()
		elseif sym == "RIGHT" or sym == "ENTER" or sym == "RETURN" or sym == "SPACE" then
			pop:trigger()
		end
	end

	return pop
end

run_script_set =
function(set, prefix)
	local okset = {}

	for _, v in ipairs(set) do
		if not resource(prefix .. v) then
			warning(string.format("missing script (%s%s)", prefix, v))
		else
			table.insert(okset, v)
		end
	end

	for _, v in ipairs(okset) do
		local script = system_load(prefix .. v, true)
		if script then
			local okstate, msg = pcall(script)
			if not okstate then
				warning(string.format(
					"failed to load/parse (%s) : %s", okstate, msg))
			elseif type(msg) ~= "table" then
				warning(string.format(
					"(%s) : returned wrong type (table of commands expected)", okstate, msg))
			else
				for _, line in ipairs(msg) do
					run_action(line)
				end
			end
		end
	end
end
