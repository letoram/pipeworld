local function index_to_label(ind)
	local lut =
	{
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
		'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
		'U', 'V', 'W', 'X', 'Y', 'Z'
	}

	local conv
	conv = function(num, base)
		if num <= base then
			return lut[num]
		else
			return conv(math.floor((num - 1) / base), base) .. lut[1 + (num - 1) % base]
		end
	end

	return conv(ind, #lut)
end

local function decor_scale_y(row)
	return math.clamp(row.scale_factor[2], 0.0, 1.0);
end

local function decor_scale_x(row)
	return math.clamp(row.scale_factor[1], 0.0, 1.0);
end

local drag_state = {}
local function drop_preview()
	if drag_state.preview and valid_vid(drag_state.preview) then
		expire_image(drag_state.preview, cell.cfg.animation_speed)
		blend_image(drag_state.preview, 0.0, cell.cfg.animation_speed)
		drag_state.preview = nil
	end
end

local function label_drag(cell, done)
	local mx, my = mouse_xy()
	local res = pick_items(mx, my, 1, true)

	if #res > 0 then
		if last_item ~= drag_state.over then
			drop_preview()
			drag_state.over = last_item
		end
	else
		drop_preview()
-- look for item in all known rows and cells
	end
	return drag_state
end

local function update_label_position(row)
	local dst_vid = row.bg
	if not valid_vid(row.label) then
		return
	end

-- resolve the row scale factors, assume we are not in a maximized state
	local sfx = decor_scale_x(row)
	local sfy = decor_scale_y(row)
	local normal_label = true

	local cell = row.cells[row.selected_index]

-- no point in showing the minimized version, just hide and exclude the row from layout
-- unless the cell being targeted is maximized
	if (sfx < 1.0 or sfy < 1.0) and not (cell and cell.scale_ignore) then
		blend_image(row.label, 0.0, row.cfg.animation_speed, INTERP_EXPOUT)
		if row.label_h > 0 then
			row.label_h_copy = row.label_h
		end
		row.label_h = 0
		return
	end

-- and when we go back from minimized scale to >= 1.0 (or other threshold) re-enable
-- the height so the row-layouting will add the correct padding
	show_image(row.label)
	if row.label_h_copy and row.label_h == 0 then
		row.label_h = row.label_h_copy
		row.label_h_copy = nil
	end

	if cell then
		dst_vid = cell.bg

		if cell.scale_ignore then
			sfx = 1
			sfy = 1
			normal_label = false
		end
	end

-- this is not animated, which can look weird if we are in other animation still
	local end_w = row.label_w
	local end_h = row.label_h

	if normal_label then
-- going larger than 1.0 just looks ugly until we have SDFs
		end_w = end_w * sfx;
		end_h = end_h * sfy;
		resize_image(row.label, end_w, end_h, row.cfg.animation_speed)
		image_shader(row.label, "DEFAULT")
		image_clip_on(row.label, CLIP_SHALLOW, row.bg)
	else
		image_clip_off(row.label)
		pipeworld_shader_setup(row.label, "ui", "popup", "active")
		local props = image_storage_properties(row.label)
		resize_image(row.label, props.width + 8, props.height + 8)
		end_h = props.height + 8
	end

	link_image(row.label, dst_vid)
	image_inherit_order(row.label, true)
	order_image(row.label, 5)
	move_image(row.label, 0, -end_h)
end

local function set_label(row, message)
-- build final string and repackage as format table
	local fmt = row:focused() and row.cfg.label_format or row.cfg.label_unfocus_format
	local cell = row.cells[row.selected_index]

-- ignore cell-less row, can happen during cleanup with asynch update
	if not cell then
		return
	end

-- might need different color / contrast in maximized state - ideally this should
-- also be controlled by the background through sampling the row-bg to figure out
-- if we should be bright on dark or dark on bright
	if cell.maximized or cell.scale_ignore then
		fmt = row.cfg.label_maximized_format
	end

	lbl = {fmt, message}

	if row.force_message then
		lbl[2] = row.force_message
	end

	if not lbl[2] then
		lbl[2] = table.concat(
			suppl_gsub_cb(row.cfg.label_ptn,
				"%%%a",
				function(match)
					if match == "%a" then
						return index_to_label(row.index) .. tostring(row.selected_index)
					elseif match == "%T" then
						return cell.title
					elseif match == "%t" then
						return cell.tag
					end
				end
			)
		)
	end

-- rendering is always expensive, so don't do it unless necessary
	if row.last_message and row.last_message == lbl[2] and row.last_format == lbl[1] then
		update_label_position(row)
		return
	end

	row.last_message = lbl[2]
	row.last_format = lbl[1]

-- create on first use
	if not valid_vid(row.label) then
		row.label, _, row.label_w, row.label_h = render_text(lbl)
		image_tracetag(row.label, "row_label")
		show_image(row.label)
		image_inherit_order(row.label, true)
		move_image(row.label, 0, -row.label_h)
		order_image(row.label, 1)

		row.label_mh = {
			name = "row_label",
			own = function(ctx, vid)
				return vid == row.label
			end,
			click = function()
				row:focus()
				row.wm:action_bindings("row_label_click")
			end,
			rclick = function()
				row:focus()
				row.wm:action_bindings("row_label_rclick")
			end,
			dblclick = function()
				row.cells[row.selected_index]:ignore_scale()
			end,
			over = function()
				if not row.cells[row.selected_index].scale_ignore then
					local cover = color_surface(1, 1, unpack(row.cfg.colors.rowlbl_hl))
					link_image(cover, row.label, ANCHOR_UL, ANCHOR_SCALE_WH)
					blend_image(cover, row.cfg.colors.rowlbl_hl[4])
					image_inherit_order(cover, true)
					order_image(cover, 1)
					row.highlight_bg = cover
					image_mask_set(cover, MASK_UNPICKABLE)
				end
			end,
			out = function()
				if valid_vid(row.highlight_bg) then
					delete_image(row.highlight_bg)
					row.highlight_bg = nil
				end
			end,
-- careful to not rely on cached cell here as the label mouse-handler will live longer
			drag = function(_, vid, dx, dy)
				drag_state = label_drag(row.cells[row.selected_index], false)
			end,
			drop = function()
				if type(drag_state) == "function" then
					drag_state()
				end
			end,
		}
		mouse_addlistener(row.label_mh)
	else
		-- re-render into the store, track the dimensions as we scale elsewhere
		_, _, row.label_w, row.label_h = render_text(row.label, lbl)
	end

	update_label_position(row)
end

-- suggest the start size of a cell that has dynamic user size
local function cell_size(row)
	local cfg = row.cfg

	return
		cfg.min_w,
		cfg.row_height,
		cfg.min_w * row.hint_factor[1],
		cfg.row_height * row.hint_factor[2]
end

local function get_focused(row)
	local ctx = row.wm

	return
		ctx.last_focus == row,
		ctx.last_focus,
		row.selected_index and row.cells[row.selected_index] or nil
end

local function row_recolor(row, state)
	local ctbl = row.cfg.colors[state]

	reset_image_transform(row.bg, MASK_OPACITY)
	blend_image(row.bg, ctbl.opacity, row.cfg.animation_speed)
	row.decor:border_color(unpack(ctbl.row_border))

	if row.cfg.row_shader then
		row.bgshid = pipeworld_shader_setup(row.bg, "ui", row.cfg.row_shader, state)
	end

	row.state = state

	for i=1,#row.cells do
		row.cells[i]:recolor()
	end
end

local function set_focused(row)
-- first remove focus from the previously active row on the context
	local ctx = row.wm
	local cfg = row.cfg
	row_recolor(row, "active")

	if ctx.last_focus == row then
		return
	end

	if ctx.last_focus then
		ctx.last_focus:unfocus()
	end

	ctx.last_focus = row
	row:set_label()
	order_image(row.bg, row.wm.group_count * 10)
	row.cells[row.selected_index]:focus()
end

local function set_unfocused(row)
	local ctx = row.wm
	local cfg = row.cfg

	row_recolor(row, "passive")

	if ctx.last_focus == row then
		ctx.last_focus = nil
	end

	if not row.cells[row.selected_index] then
		return
	end

	order_image(row.bg, 10)
	row.cells[row.selected_index]:unfocus()
	row:set_label()
end

local function scale_row(row, fx, fy, dt, no_cd, no_anim)
-- change the scale for drawing, the clients will not be made aware of this.
	row.scale_factor[1] = math.clamp(fx, 0.01, 100)
	row.scale_factor[2] = math.clamp(fy, 0.01, 100)

-- queue for relayout
	row:invalidate(dt, no_cd, no_anim)
end

local function rehint_row(row, fx, fy)
	row.hint_factor[1] = math.clamp(fx, fy, 0.01, 100)
	row.hint_factor[2] = math.clamp(fx, fy, 0.01, 100)

	for _,v in ipairs(row.cells) do
		cell.hint_factor[1] = cell.hint_factor[1] + row.hint_factor[1]
		cell.hint_factor[2] = cell.hint_factor[2] + row.hint_factor[2]
		v:rehint()
	end

	row.hint_factor = {1, 1}
end

local function invalidate_row(row, dt, no_cd, no_anim)
	dt = dt and dt or row.cfg.row_animation_delay

-- animation is broken if a new (without dt) animation comes on with no_anim_queue
	if no_cd then
		row.cooldown = 0
	end

	if no_anim then
		dt = 0
	end

-- [dt] is optional, and don't increase the deadline if we already have one
	if not row.pending_relayout or dt < row.pending_relayout then
		row.pending_relayout = dt
	end

-- but go immediately if asked
	if dt == 0 then
		row:relayout(0, 0)
		return

	elseif row.no_anim_queue then
		row:relayout(dt, row.cfg.animation_tween)
		return
	end

-- also make sure to update the label state while we are at it
	row:set_label()
end

local function relayout(row, dt, interp)
	local cfg = row.cfg
	local ctx = row.wm

-- scaling the label text isnt' very nice but the engine is still really slow
-- if sweeping through a lot of pt-sizes so do it like that for now and wait
-- for MSDFs through a text specific surface type
	local pad_y = row.label_h * decor_scale_y(row)
	local orig = image_surface_properties(row.bg)

	local x = (cfg.row_border + cfg.row_pad[2]) * decor_scale_x(row) + cfg.cell_border
	local y = (cfg.row_border + cfg.row_pad[1]) * decor_scale_y(row) + pad_y + cfg.cell_border
	local sb_x = 2 * cfg.cell_border
	local sb_y = 2 * cfg.cell_border

	local spacing = cfg.cell_spacing * row.scale_factor[1]
	local max_cell_h = 0

	reset_image_transform(row.bg, MASK_SCALE)

	if valid_vid(row.label) then
		reset_image_transform(row.label)
		update_label_position(row)
	end

	for i, v in ipairs(row.cells) do
-- then the content
		v:resize(dt, interp)
-- the decoration border isn't actually scaled in order to show client state
-- colors clearly, and content size takes both cells scale factor and row scale
-- factor into account
		local w, h = v:content_size()

		if h + sb_y > max_cell_h then
			max_cell_h = h + sb_y
		end

-- anchor deals with bg resizing
		v:set_anchor(row.bg, ANCHOR_UL, x, y, w, h, dt, interp)

		x = x + w + sb_x + (i == #row.cells and 0 or 1) * spacing
	end

-- dt needs to be calculated based on pixel-difference from current or we will never get ok
-- synch between animations of cells and decorations (without dipping into deep hierarchies)
-- the current 'bind to scale' edge and hierarchy seems to work well enough but has a perf
-- penalty that scales with the number of rows, the engine also only caches discrete ticks.
	local dw = math.ceil((cfg.row_border * 2 + cfg.row_pad[4]) * decor_scale_x(row) + x)
	local dh = math.ceil((cfg.row_border * 2 + cfg.row_pad[3] + y) * decor_scale_y(row) + max_cell_h)

	resize_image(row.bg, dw, dh, dt, interp)
	row.bg_height = dh

	row.wm:relayout(dt)
end

local function select_index(row, ind)
	if ind <= 0 then
		ind = #row.cells - ind
	end

	if ind == row.selected_index then
		return
	end

-- this can trigger a delete in the edge case of dirty expression cell
	row.cells[row.selected_index]:unfocus()
	if row.dead then
		return
	end

	row.selected_index = math.clamp(ind, 1, #row.cells)
	local base = row.cells[row.selected_index]
	base:focus()
	row:set_label()
end

-- should really be moved into base.lua as cell-destroy and have row be a listener
local function delete_cell(row, cell)
	if #row.cells == 1 then
		row:destroy(cell.cfg.animation_speed, cell.cfg.animation_tween)
		return
	end

-- shift selection
	local i = table.force_find_i(row.cells, cell)
	if row.selected_index == i then
		if i == #row.cells then
			row:select_index(i-1)
		end
	end

-- forget any existing tag
	if cell.tag then
		row.wm.tags[cell.tag] = nil
	end

	table.remove(row.cells, i)
	cell:destroy(row.cfg.animation_speed, row.cfg.animation_tween)
	row:invalidate()
end

local function fade_anchor(row)
	if row.dead then
		return
	end
	expire_image(row.bg, row.cfg.animation_speed)
	resize_image(row.bg, 1, 1, row.cfg.animation_speed, row.cfg.animation_tween)
	blend_image(row.bg, 0.0, row.cfg.animation_speed)
end

local function drop_mh(row)
-- all the possible mouse handler sets
	if row.mouse_handler then
		mouse_droplistener(row.mouse_handler)
	end

	if row.label_mh then
		mouse_droplistener(row.label_mh)
	end

	if row.sa_mh then
		mouse_droplistener(row.sa_mh)
	end
end

local function destroy_row(row)
	assert(not row.dead, "dangling row reference")

-- remove popup state first, this cleanup forcibly kills everything but may in
-- some cases (popup expression input cancellation) recurse into destroying the
-- row in case of event handlers in the cells themselves.
	if row.popup then
		row.popup = false
		row.wm:drop_popup()
		if row.dead then
			return
		end
	end

	local ctx = row.wm
	local row_i = table.find_i(ctx.rows, row)
	local props = image_surface_properties(row.bg)

-- row can be destroyed on focus drop here
	if row_i then
		ctx:detach_row(row_i)
	end

	if row.dead then
		return
	end

-- cascade-clean any cells, make sure any cell->row calls are ignored
	row.invalidate =
	function()
	end

	for i, v in ipairs(row.cells) do
		v:destroy(row.cfg.animation_speed, row.cfg.animation_tween)
	end

-- make sure that the spawn helper anchor doesn't die with the row
	if image_parent(ctx.spawn_anchor) == row.bg then
		link_image(ctx.spawn_anchor, ctx.anchor)
	end

	fade_anchor(row)
	drop_mh(row)

-- clean and mark to make uaf easier to find
	table.wipe(row)
	row.dead = true

	if ctx.last_focus == row then
		ctx.last_focus = nil
	end

	ctx:relayout()
end

local function add_cell(row, factory, ...)
	local cell, index = factory(row, row.cfg, ...)
	if not cell then
		return
	end

-- sneak 'move' of cell to estimated position so it doesn't appear from the
-- last anchor, tacitly assume that the focused cell spawned the new one
-- (though that might not actually be true)
	if #row.cells > 0 then
		local p = image_surface_properties(row.cells[#row.cells].bg)
		move_image(cell.bg, p.x + p.width, p.y)
	end

	if not index then
		table.insert(row.cells, cell)
	else
		table.insert(row.cells, index, cell)
	end

	row:invalidate()
	return cell
end

local function row_index_at_xy(row, x, y)
	local props = image_surface_resolve(row.bg)
	local rx = x - props.x
	local ry = y - props.y

-- sweep the cells and get x-ofs + width
	for i, v in ipairs(row.cells) do
		local dp = image_surface_properties(v.bg)
		if rx >= dp.x and rx <= dp.x + dp.width then
			return i
		end
	end
end

-- Two animation properties of note here :
--
--  * relayout_invalidation - indicates that we should relayout
--  * cooldown - blocks us from relayouting too often
--
-- These both protect against storms of animation requests - the cooldown
-- against animations being queued while others are still in flight (which can
-- happen at different rates)
--
-- The other when activity on the same row cascades into eachother and should
-- give clients ample time to react.
--
local function tick(ctx, no_cd)

-- update both cooldown counter and relayout counter so that they do not
-- chain of eachother
	if ctx.cooldown and ctx.cooldown > 0 then
		ctx.cooldown = ctx.cooldown < 1
	end

	if not ctx.pending_relayout then
		return
	else
		ctx.pending_relayout = ctx.pending_relayout - 1
		if ctx.pending_relayout > 0 then
			return
		end
	end

	if ctx.cooldown and ctx.cooldown > 0 then
		if not no_cd then
			return
		end
	else
		ctx.cooldown = ctx.cfg.row_animation_cooldown
	end

	ctx:relayout(ctx.cfg.animation_speed, ctx.cfg.animation_tween)
	ctx.pending_relayout = false
end

local function spawn_anchor(ctx, row, sa)
	show_image(row.spawn_anchor)
	order_image(row.spawn_anchor, 5)
	local sa = row.spawn_anchor
	local cfg = row.cfg

	row.sa_mh = {
		name = "spawn_anchor_row",
		own = function(ctx, vid)
			return vid == sa
		end,
		over = function(ctx, vid)
			ctx.overlay = color_surface(1, 1, unpack(cfg.colors.active.selection_bg))
			blend_image(ctx.overlay, 1.0, cfg.animation_speed * 0.5)
			blend_image(ctx.overlay, 0.5, cfg.animation_speed * 0.5)

			resize_image(ctx.overlay, cfg.row_height, row.bg_height, cfg.animation, cfg.animation_tween)
			link_image(ctx.overlay, sa)
			image_mask_set(ctx.overlay, MASK_UNPICKABLE)
		end,
		out = function(ctx, vid)
			if valid_vid(ctx.overlay) then
				delete_image(ctx.overlay)
				ctx.overlay = nil
			end
		end,
		click = function()
			row:focus()
			row.wm:action_bindings("row_spawn_anchor_click")
		end,
		rclick = function()
			row:focus()
			row.wm:action_bindings("row_spawn_anchor_rclick")
		end
	}
	mouse_addlistener(row.sa_mh)
end

local function row_mouse(ctx, row)
	local cfg = row.cfg

	row.mouse_handler =
	{
		name = "row_mh",
		own_vid = row.bg,
		dblclick =
		function()
			if not row.stored_scale then
				row.stored_scale = {row.scale_factor[1], row.scale_factor[2]}
				row:scale(1, 1)
			else
				row:scale(row.stored_scale[1], row.stored_scale[2])
				row.stored_scale = nil
			end
		end,
		button =
		function(ctx, vid, index, active, x, y)
			if not active then
				return
			end

			row:focus()
			local fp = row_index_at_xy(row, x, y)

-- ideally these should probably accumulate and release on tick instead so the
-- animation goes smoother on non-analog mice
			if index == MOUSE_WHEELPY then
				row:scale(
					row.scale_factor[1] + cfg.scale_step[1],
					row.scale_factor[2] + cfg.scale_step[2]
				)
			elseif index == MOUSE_WHEELNY then
				row:scale(
					row.scale_factor[1] - cfg.scale_step[1],
					row.scale_factor[2] - cfg.scale_step[2]
				)
			elseif fp then
				row:select_index(fp)
				row.wm:pan_fit(row.cells[fp])
			end
		end,
		rclick =
		function()
			row:focus()
			row.wm:action_bindings("row_bg_rclick")
		end,
		drag =
		function(_, vid, dx, dy)
			nudge_image(ctx.anchor, dx, dy)
		end,
	}
	mouse_addlistener(row.mouse_handler)
end

-- sweep backwards and find the first index that is not detached
local function find_group_parent(row)
	row.group_parent = row
	local ind = row.index

	while ind > 1 do
		if row.wm.rows[ind].detached then
			return row.wm.rows[ind]
		end
		ind = ind - 1
	end

	return row.wm.rows[ind]
end

local function toggle_linked(row, state, dt, interp)
	if row.index == 1 then
		return
	end

	local detached = row.detached
	state = state and state or not row.detached
	row.detached = state

	local bg = image_surface_resolve(row.bg)
	local anch = image_surface_resolve(row.wm.anchor)

-- only move / reposition if the actual anchor state changes
	if row.detached ~= detached and row.detached then
		relink_image(row.bg, row.wm.anchor)
		row.group_parent = find_group_parent(row)
		row.wm.group_count = row.wm.group_count + 1
		row.wm:relayout(dt, interp)

	elseif not row.detached and detached then
		row.wm.group_count = row.wm.group_count - 1
		relink_image(row.bg, row.wm.rows[row.index-1].bg, ANCHOR_LL)
		row.group_parent = find_group_parent(row)
		row.wm:relayout(dt, interp)
	end
end

local function select_cell(row, cell)
	cell.row:select_index(table.force_find_i(row.cells, cell))
end

local function scale_ignore_cell(row, cell)
	for i,v in ipairs(row.cells) do
		if v.scale_ignore and i ~= row.selected_index then
			v:ignore_scale()
			break
		end
	end

	cell:ignore_scale()
	row.wm:pan_fit(cell, true)
end

-- instantiate a new cell from the factory function [cell(row, cfg)]
-- and attach to the set of rows defined inside [ctx] which comes
-- from the returned factory of this translation unit
local decorator = system_load("builtin/decorator.lua")()
return function(ctx, ind, cell, ...)
	local cfg = ctx.cfg
	local ot = type(cell)
	local popup = ind == -1 and ctx.last_focus

	if ot == "string" then
		cell = ctx.types[cell]
	end
	if not cell then
		warning(string.format(
			"insert_row: unknown cell type (%s):", ot, tostring(cell)))
		return
	end

-- provide the colors as texture units so that the entire object has a textured store
	local bg = fill_surface(32, 32, unpack(cfg.colors.active.row_bg))
	local bg_passive = fill_surface(32, 32, unpack(cfg.colors.passive.row_bg))
	image_framesetsize(bg, 3, FRAMESET_MULTITEXTURE)
	set_image_as_frame(bg, ctx.row_bg, 2)
	set_image_as_frame(bg, bg_passive, 1)
	delete_image(bg_passive)

	image_tracetag(bg, "row_bg")
	force_image_blend(bg, BLEND_FORCE)
	image_mask_clear(bg, MASK_OPACITY)
	order_image(bg, 10)

	local b = cfg.row_border
	local row = {
		wm = ctx,
		bg = bg,
		bg_height = 1,
		cfg = cfg,
		state = "passive",

		cells = {},
		decor = decorator({
			border = {b, b, b, b},
			pad = {0, 0, 0, 0},
--			force_order = 1 : removed as popup_cell conflicts
		})(bg),
		index = math.abs(ind),
		selected_index = 1,
		label_w = 0,
		label_h = 0,
		cooldown = 0,
		popup = popup,

-- vtable
		set_label = set_label,
		cell_size = cell_size,
		focused = get_focused,
		focus = set_focused,
		unfocus = set_unfocused,
		scale = scale_row,
		scale_ignore_cell = scale_ignore_cell,
		hint = rehint_row,
		invalidate = invalidate_row,
		relayout = relayout,
		tick = tick,
		select_index = select_index,
		select_cell = select_cell,
		delete_cell = delete_cell,
		add_cell = add_cell,
		destroy = destroy_row,
		toggle_linked = toggle_linked,
		index_to_label = function(row)
			return index_to_label(row.index)
		end,

-- scale is forced presentation size, hint is external content size
		scale_factor = {cfg.scale_factor[1], cfg.scale_factor[2]},
		hint_factor = {1, 1},

-- might not be used if popup
		spawn_anchor = null_surface(cfg.row_height, 10, 1)
	}
	link_image(row.spawn_anchor, row.bg, ANCHOR_UR, ANCHOR_SCALE_H)

-- takes all the fancy (rounded, flow, color) and selection state
	if cfg.row_shader then
		row.bgshid = pipeworld_shader_setup(bg, "ui", cfg.row_shader, "active")
	end

	if not popup then
		spawn_anchor(ctx, row)
		row_mouse(ctx, row)
	end

	row:set_label()
	show_image(row.bg)

-- spawn the new reference cell, guard against it being destroyed on creation or
-- not possible to create due to some dynamic condition as well as the cell killing
-- the row itself..
	cell = cell(row, cfg, ...)

	if not cell or row.dead then
		row:destroy()
		return
	end

	cell:set_anchor(row.bg, ANCHOR_UL, 1, 1, cfg.row_border, cfg.row_border, 1, 1)
	table.insert(row.cells, cell)

-- ind -1 is special for 'popup row'
	if popup then
	else
		table.insert(ctx.rows, ind, row)
		ctx:reindex()
	end
	row:focus()

	return row
end
