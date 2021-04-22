local function on_unfocus(cell)
	if not valid_vid(cell.vid, TYPE_FRAMESERVER) then
		return
	end

	if (cell.cfg.cell_alpha_hint ~= cell.cfg.cell_alpha_hint_unfocus) then
		target_graphmode(cell.vid, 1, cell.cfg.cell_alpha_hint_unfocus)
		target_graphmode(cell.vid, 0)
	end

	target_displayhint(cell.vid, 0, 0, TD_HINT_UNFOCUSED)
end

local function on_focus(cell)
	if not valid_vid(cell.vid, TYPE_FRAMESERVER) then
		return
	end

	cell.cfg.input_grab(cell,
	function(iotbl, sym, lutsym)
		if not iotbl then
			return
		end

-- if sym + modifiers == known label, then tag the input with that
		if iotbl.translated and cell.input_syms[lutsym] then
			iotbl.label = cell.input_syms[lutsym]
		end

		target_input(cell.vid, iotbl)
	end)

	if (cell.cfg.cell_alpha_hint ~= cell.cfg.cell_alpha_hint_unfocus) then
		target_graphmode(cell.vid, 1, cell.cfg.cell_alpha_hint)
		target_graphmode(cell.vid, 0)
	end

	target_displayhint(cell.vid, 0, 0, 0)
end

local function on_rehint(cell)
	if not valid_vid(cell.vid, TYPE_FRAMESERVER) or not cell.fsrv_size then
		return
	end

	local hfx = cell.hint_factor[1]
	local hfy = cell.hint_factor[2]

	if cell.maximized then
		hfx = 1
		hfy = 1
	end

-- note, this would cause a resized coming from the client, modifying
-- the fsrv_size and so on - thus consume on use the hint factor
	local w = math.ceil(cell.fsrv_size[1] * hfx)
	local h = math.ceil(cell.fsrv_size[2] * hfy)
	cell.hint_factor = {1, 1}

	target_displayhint(cell.vid, w, h, TD_HINT_UNCHANGED)
end

local function on_reset(cell)
	if not valid_vid(cell.vid, TYPE_FRAMESERVER) or cell.state == "dead" then
		return
	end

	local fs = cell.cfg.ext_reset_flash
	if fs and fs > 0 then
		fs = math.ceil(fs * 0.5)
		local col = color_surface(1, 1, unpack(cell.cfg.colors[cell.row.state].cell_alert))
		link_image(col, cell.vid, ANCHOR_UL, ANCHOR_SCALE_WH)
		image_inherit_order(col, true)
		order_image(col, 1)
		blend_image(col, 1.0, fs)
		blend_image(col, 0.0, fs)
		expire_image(col, fs + fs)
	end

	reset_target(cell.vid, true)
end

local function on_button(ctx, vid, index, active, x, y)
	target_input(ctx.cell.vid, {
		kind = "digital",
		mouse = true,
		devid = 0,
		subid = index,
		active = active
	})
end

local function on_motion(ctx, vid, x, y)
-- just ignore and use the data hidden in cell
	local cell = ctx.cell
	target_input(cell.vid, {
		kind = "analog", mouse = true,
		devid = 0, subid = 0,
		samples = {cell.last_mx, cell.delta_mx}
	})

	target_input(cell.vid, {
		kind = "analog", mouse = true,
		devid = 0, subid = 1,
		samples = {cell.last_my, cell.delta_my}
	})
end

return function(cell, vid)
	resize_image(vid, 1, 1)
	cell:set_content(vid)
	cell.mouse_proxy = {
		cell = cell,
		button = on_button,
		motion = on_motion
	}

	cell.input_labels = {}
	cell.input_syms = {}

	local base_focus = cell.focus

	cell.rehint = on_rehint
	cell.focus =
	function(...)
		base_focus(...)
		return on_focus(...)
	end

	local base_unfocus = cell.unfocus
	cell.unfocus =
	function(...)
		base_unfocus(...)
		return on_unfocus(...)
	end
	cell.reset = on_reset
end
