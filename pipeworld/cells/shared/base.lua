local decorator = system_load("builtin/decorator.lua")()

-- expand as needed
pipeworld_exchange_types = {
	"external_blob_pipe",
	"video_buffer_handle"
}

local function cell_anchor(
	cell, anchor, point, dx, dy, w, h, dt, interp)

	link_image(cell.bg, anchor, point)
	image_inherit_order(cell.bg, true)
	order_image(cell.bg, 1)

-- and set the new one
	reset_image_transform(cell.bg, bit.bor(MASK_POSITION, MASK_SCALE))
	move_image(cell.bg, dx, dy, dt, interp)
	resize_image(cell.bg, w, h, dt, interp)
	if valid_vid(cell.vid) then
		resize_image(cell.vid, w, h, dt, interp)
	end
end

local function drop_cell(cell, dt, interp)
-- revert state
	if cell.maximized then
		cell:maximize()
	end

-- de-register tag
	if cell.tag and cell.row.wm.tags[cell.tag] == cell then
		cell.row.wm.tags[cell.tag] = nil
	end

-- fade out
	dt = (dt and dt > 0) and dt or 1

	cell:drop_encoder()

	blend_image(cell.bg, 0, dt, interp)
	resize_image(cell.bg, 1, 1, dt, interp)
	expire_image(cell.bg, dt)

	if cell.decor then
		cell.decor:destroy()
	end

	for _,v in ipairs(cell.timers) do
		timer_delete(v)
	end

	if valid_vid(cell.vid) then
		resize_image(cell.vid, 1, 1, dt, interp)
	end

-- release input
	cell.cfg.input_grab(cell)

-- schedule a row relayout, though the cell might have been detached
	if cell.row then
		cell.row:invalidate(dt)
	end

-- release handlers and add uaf detection
	mouse_droplistener(cell.mouse_handler)
	table.wipe(cell)
	cell.dead = true
end

local function set_content(cell, vid, aid, mouse_proxy)
	if not valid_vid(vid) then
		return
	end

	if valid_vid(cell.vid) and vid ~= cell.vid then
		delete_image(cell.vid)
		cell.vid = nil
	end

	image_mask_clear(vid, MASK_OPACITY)
	image_tracetag(vid, "cell_content")
	image_clip_on(vid, CLIP_SHALLOW, cell.row.bg)
	show_image(vid)
	link_image(vid, cell.bg) -- ANCHOR_UL, ANCHOR_SCALE_WH)
	image_inherit_order(vid, true)
	order_image(vid, 1)
	pipeworld_shader_setup(vid, "ui", cell.cfg.cell_shader)

-- update any encoders, open question (so configurable) if we should also resize
-- to fit aspect to crop, 1:1 or rebuild/send new encoder to replace the old. It
-- is the resize on recordtarget ghost that is back to haunt us.
	for _,v in pairs(cell.encoders) do
		image_sharestorage(vid, v.ref)
	end

	cell.vid = vid
	cell.aid = aid
	cell.mouse_proxy = mouse_proxy
end

local function on_resize(cell, dt, interp)
	local w, h = cell:content_size()
	cell.ratio = {1, 1}

	if cell.last_w == w and cell.last_h == h then
		return
	end

	if not cell.initial_w then
		cell.initial_w = w
		cell.initial_h = h
	end

	cell.last_w = w
	cell.last_h = h

	resize_image(cell.bg, w, h, dt, interp)

	if valid_vid(cell.vid) then
		reset_image_transform(cell.vid, MASK_SCALE)
		local store = image_storage_properties(cell.vid)
		cell.ratio = {w / store.width, h / store.height}
		resize_image(cell.vid, w, h, dt, interp)
	end

	local focused, _, in_cell = cell.row:focused()

-- re-focus as a precaution, and re-pan if we used to be the pan target
	if focused and in_cell == cell then
		cell:focus()
	end
end

local function set_mouse(cell)
	cell.mouse_handler = {
		name = "cell",
		own =
		function(ctx, vid)
			return vid == cell.bg or vid == cell.vid
		end,
		motion =
-- if we are scaled below some ratio just ignore any action forwarding
		function(ctx, vid, x, y)
			local props = image_surface_resolve(vid)
			local l_mx = cell.last_mx and cell.last_mx or x
			local l_my = cell.last_my and cell.last_my or y
			cell.last_mx = (x - props.x) / cell.scale_cache[1]
			cell.last_my = (y - props.y) / cell.scale_cache[2]

			cell.delta_mx = cell.last_mx - l_mx
			cell.delta_my = cell.last_my - l_my

			if cell.mouse_proxy and cell.mouse_proxy.motion then
				cell.mouse_proxy.motion(cell.mouse_proxy, vid, x, y)
			end
		end,
		button =
		function(ctx, vid, index, active, x, y)
			if vid == cell.vid then
				cell:ensure_focus()

				if cell.mouse_proxy and cell.mouse_proxy.button then
					cell.mouse_proxy.button(cell.mouse_proxy, vid, index, active, x, y)
					return
				end
			end

			if not active then
				return
			end

			cell:ensure_focus()

			if index == MOUSE_WHEELPY then
				local dtbl = cell.scale_factor
				dtbl[1] = dtbl[1] + cell.cfg.scale_step[1]
				dtbl[2] = dtbl[2] + cell.cfg.scale_step[1]
				cell.row:invalidate()

			elseif index == MOUSE_WHEELNY then
				local dtbl = cell.scale_factor
				dtbl[1] = dtbl[1] - cell.cfg.scale_step[1]
				dtbl[2] = dtbl[2] - cell.cfg.scale_step[1]
				cell.row:invalidate()
			end
		end,
		over =
		function(ctx, vid)
		end,
		click =
		function(ctx, vid)
		end,

-- only use double-click to toggle scale-ignore if we are not already in that state
-- or maximized or holding the meta key state, otherwise we'd break double-click
-- passthrough
		dblclick =
		function(ctx, vid, x, y)
			if cell.cfg.keyboard.meta_1 or not (cell.maximized or cell.scale_ignore) then
				cell.row:scale_ignore_cell(cell)
			end
		end,
-- re-order?
		drag =
		function(ctx, vid)
		end
	}

	mouse_addlistener(cell.mouse_handler,
		{"motion", "button", "click", "over", "dblclick"})
end

local function content_size(cell, ignore_scale)
-- start with row/cell default suggestion
	local sw, sh, hw, hh = cell.row:cell_size()

-- grab the scale factors
	local sfx = 1
	local sfy = 1

	ignore_scale = cell.maximized or cell.scale_ignore or ignore_scale

	if not ignore_scale then
		sfx = cell.row.scale_factor[1] * cell.scale_factor[1]
		sfy = cell.row.scale_factor[2] * cell.scale_factor[2]
	end

-- if we already have contents, use that
	if valid_vid(cell.vid) then
		local props = image_storage_properties(cell.vid)
		sw = props.width * sfx
		sh = props.height * sfy
		hw = props.width * cell.row.hint_factor[1] * cell.hint_factor[1]
		hw = props.height * cell.row.hint_factor[2] * cell.hint_factor[2]
	else
		sw = sw * sfx
		sh = sh * sfy
		hw = hw * cell.hint_factor[1]
		hh = hh * cell.hint_factor[2]
	end

	local hfx = cell.hint_factor[1]
	local hfy = cell.hint_factor[2]

-- and cache the scale check (for mouse actions)
	cell.scale_cache[1] = sfx
	cell.scale_cache[2] = sfy

	return sw, sh, hw, hh
end

local function ensure_focus(cell)
	local focused, _, in_cell = cell.row:focused()
	if not focused then
		cell.row:focus()
	end

	cell.row:select_cell(cell)
-- we run the pan operation here as it comes from an interactive source (click)
	cell.row.wm:pan_fit(cell)
	return true
end

local function maximize_state(cell, args)
	if cell.maximized then
		cell.scale_factor = cell.old_scale_factor
		cell.fsrv_size = cell.old_fsrv_size
		cell.old_scale_factor = nil
		cell.maximized = false

-- and apply the new scale factors
		cell.row:invalidate()
	else
-- option here is if we should also attempt to override hint and
-- explicitly set an unfactored hint?
		cell.old_scale_factor = cell.scale_factor
		cell.scale_factor = {1, 1}
		cell.old_fsrv_size = cell.fsrv_size

		w = cell.row.wm.w
		h = cell.row.wm.h

-- overide this so we try to fit the screen
		cell.fsrv_size = {w, h}
		cell.maximized = true
		cell.row:invalidate()
	end

-- and send new hinting factors to match 1x1 or previous normal
	cell:rehint()
end

local function find_ch_ofs(instr, pos)
	local ofs = 1

	for i = 1,pos do
		ofs = string.utf8forward(instr, ofs)
	end

	return string.sub(instr, 1, ofs)
end

local function show_error(cell, ch_offset)
	if cell.error_popup then
		cell.error_popup:cancel()
	end

-- wait until we actually gets selected as we will clear the error state
	if not cell.focused or not cell.row:focused() or not cell.last_error then
		return
	end

-- non-grab popup attached with the message
	cell.error_popup = pipeworld_popup_spawn(
	{
		{
			label = cell.last_error,
			handler = function()
			end
		}
	}, true, cell.bg, ANCHOR_LL)

-- disable the cursor and make sure that when we are done, the cell returns
-- to whatever its proper recolor state is
	if cell.error_popup then
		cell.error_popup.clock = CLOCK
		delete_image(cell.error_popup.cursor)
		cell.error_popup.on_finish = function()
			cell.error_popup:cancel()
			cell:recolor()
		end

-- sweep ch_offset codepoints from start, re-use the fmtstr and get the
-- pixel- offset and move popup there
		if ch_offset then
			local trunc = find_ch_ofs(cell.last_error, ch_offset)
			local fmt = cell.cfg.popup_text_valid
			local w = text_dimensions({fmt, trunc})
			move_image(cell.error_popup.anchor, w, 0)
		end

		local os = cell.state
		cell.state = "alert"
		cell:recolor()
		cell.state = os
	end

	cell.last_error = nil
end

local function focus_cell(cell)
	if not cell.custom_state then
		cell.state = "selected"
	end

	cell.focused = true
	show_error(cell)
	cell:recolor()

	local dt = 1000

-- figure out if we fit on the screen currently or not
	local bg_p = image_surface_properties(cell.bg, dt)
	local r_p = image_surface_properties(cell.row.bg, dt)
	local disp_p = image_surface_resolve(cell.row.wm.anchor)
	disp_p.width = disp_p.width - disp_p.x
	disp_p.height = disp_p.height - disp_p.y

-- translate to screen space
	local x1 = bg_p.x + r_p.x + disp_p.x
	local x2 = x1 + bg_p.width
	local y1 = bg_p.y + r_p.y + disp_p.y
	local y2 = y1 + bg_p.height
end

local function cell_error(cell, message, offset)
	cell.last_error = message

	if cell.last_error then
		cell.error_timestamp = CLOCK
		show_error(cell, offset)
	end

	cell:recolor()
end

local function unfocus_cell(cell)
	if cell.maximized then
		cell:maximize()
	end

	if cell.error_popup then
		cell.error_popup:cancel()
		cell.error_popup = nil
	end

	if not cell.custom_state then
		cell.state = "passive"
	end

	cell.focused = false
	cell:recolor()
	cell.cfg.input_grab(cell)
end

local function cell_reset(cell)
	cell.reset_clock = cell.row.wm.clock
end

local function scale_ignore(cell)
	cell.scale_ignore = not cell.scale_ignore
	cell.row:invalidate()
end

local function cell_cp(cell)
	return 0, 0
end

local function cell_recolor(cell)
	local col = cell.cfg.colors[cell.row.state]
	local lbl = "cell_" .. (cell.custom_state and cell.custom_state or cell.state)
	assert(col[lbl], "missing color for cell state: " .. cell.state)

	if cell.decor then
		cell.decor:border_color(unpack(col[lbl]))
	end

-- opacity is used to indicate selection state
	instant_image_transform(cell.vid, MASK_OPACITY)
	blend_image(cell.vid, cell.focused and 1.0 or 0.5)
end

-- default naive implementation, exports the contents itself - this has
-- the problem what we don't 're-export' unless asked so might need yet another
-- callback / listening system for this
local function export_content(cell, outtype, suffix)
	if outtype == "video_buffer_handle" and valid_vid(cell.vid) then
		return cell.vid, "video_buffer_handle"
	end

	if cell.suffix_handler.export[suffix] then
		return cell.suffix_handler.export[suffix](cell, outtype)
	end
end

-- this is used in reset for pipelines (a [export] -> b [import] [export] -> ..
-- and currently just a placeholder
local function import_content(cell, intype, suffix)
	if cell.suffix_handler.import[suffix] then
		return cell.suffix_handler.import[intype](cell, intype)
	end
end

local function cell_state(cell, state)
	cell.custom_state = state
	cell:recolor()
end

local encoder_counter = 0
local function cell_encoder(cell, dest, opts)
	local cw, ch = cell:content_size(true)
	encoder_counter = encoder_counter + 1

	local defopt =
	{
		clock = -1,
		encoder = "",
		width = cw,
		height = ch,
		ref = encoder_counter
	}

	opts = opts and table.ensure_defaults(opts, defopt) or defopt

	if type(dest) == "table" then
		if not valid_vid(dest.vid, TYPE_FRAMESERVER) then
			return false, "Cell does not reference a frameserver"
		end
		dest = dest.vid
	end

-- It would be >very< nice to actually output YUV content, but that requires
-- more negotiation so that frame handles can be streamed to encoder (arcan
-- limitation, takes quite some work to get around). Depends on getting fences
-- plumbed.
	local buffer = alloc_surface(opts.width, opts.height, true, ALLOC_QUALITY_NORMAL)
	if not valid_vid(buffer) then
		return false, "Could not allocate composition buffer"
	end

	local aids = {}
	if not cell.aid or opts.no_audio then
		opts.encoder = "noaudio" .. (#(opts.encoder) > 0 and ":" or "") .. opts.encoder
	else
		aids = {cell.aid}
	end

-- The most pressing advance is to have a robust frame-update propagation system
-- and only clock when necessary rather than at a specific framerate (clock as a
-- function rather than number, then manually stepframe). The other is that we need
-- some audio mixing controls (as a pre-stage?) as well as a pad-to-constraints to
-- let some video encoders work (formats with fixed sizes or divisibility reqs.)
	local props = image_storage_properties(cell.vid)

	local ref = null_surface(props.width, props.height)
	show_image(ref)
	image_sharestorage(cell.vid, ref)

	define_recordtarget(buffer, dest, opts.encoder, {ref}, aids,
		RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, opts.clock,
		function(source, status, input)
			if status.kind == "terminated" then
				delete_image(source)
				table.remove_match(cell.encoders, opts.ref)
				if #status.last_words > 0 then
					cell:set_error(string.format("encoder (%s) died: %s", opts.ref, status.last_words))
				end
-- forward any input events if this is tied to a sharing session
			elseif status.kind == "input" and opts.input then
				opts.input(source, input)
			end
-- a12 from encoder might need more controls here in order to show authentication
-- fingerprint and query if the public key should be added to the keystore or not
		end
	)

	if cell.encoders[opts.ref] then
		delete_image(cell.encoders[opts.ref])
	end

	cell.encoders[opts.ref] = {buffer = buffer, ref = ref}
end

local function cell_drop_encoder(cell, ref)
	if not ref then
		for _,v in pairs(cell.encoders) do
			delete_image(v.buffer)
		end
		cell.encoders = {}
		return
	end

	if cell.encoders[ref] then
		delete_image(cell.encoders[ref].buffer)
		cell.encoders[ref] = nil
	else
		warning("cell:drop_encoder(" .. ref .. ") unknown ref")
	end
end

local function clip_copy(cell)
-- default doesn't do anything, input.lua and fsrv adds more
end

local function clip_paste(cell, src)
-- same as with copy
end

function pipeworld_cell_template(name, row, cfg)
	local bg = null_surface(1, 1)
	image_clip_on(bg, CLIP_SHALLOW, row.bg)

	show_image(bg)
	image_tracetag(bg, "cell_bg")

	local res = {
		bg = bg,
		cfg = table.copy(cfg),
		row = row,
		name = name,
		last_w = 0,
		last_h = 0,
		vid = null_surface(1, 1),
		scale_ignore = false,
		ignore_scale = scale_ignore,
		reset_clock = row.wm.clock,
		scale_factor = {1, 1},
		hint_factor = {1, 1},
		scale_cache = {1, 1},
		encoders = {},
		set_anchor = cell_anchor,
		add_encoder = cell_encoder,
		drop_encoder = cell_drop_encoder,
		popup_anchor_xy = cell_cp,
		state = "passive",
		set_state = cell_state,
		set_error = cell_error,
		recolor = cell_recolor,
-- reset to whatever initial state we had
		reset = cell_reset,
		ensure_focus = ensure_focus,
		content_size = content_size,
	-- called by row
		destroy = drop_cell,
		focus = focus_cell,
		unfocus = unfocus_cell,
-- placeholder
		input = function(cell, tbl)
		end,
		context_menu = function()
-- return a menu of cell specific actions, none defined atm.
			return {}
		end,
		rehint = function(cell)
-- if there are external factors, we should send a hint that the
-- size might have changed
		end,
-- return list of accepted input and output types, in preferred order
		types = {
			import = {},
			export = {}
		},
-- tools and other extensions might want to support their own import
-- and export types
		suffix_handler = {
			import = {},
			export = {}
		},
-- list of names of registered timers that gets unregistered on destroy
		timers = {},

-- generic k/v table used for cell-api/command-expression state etc.
		plugin_store = {},
		set_content = set_content,
		export_content = export_content,
		import_content = import_content,

		maximize = maximize_state,
		resize = on_resize,
	}

	local b = res.cfg.cell_border
	if b > 0 then
		res.decor = decorator(
		{
			border = {b, b, b, b},
			pad = {0, 0, 0, 0},
		})(bg)

-- clip decor against row background
		for k,v in pairs(res.decor.vids) do
			image_clip_on(v, CLIP_SHALLOW, row.bg)
		end
	end

	set_mouse(res)
	return res
end
