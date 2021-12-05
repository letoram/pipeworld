-- This unit contains all the logic for window management
local insert_row = system_load("row.lua")()

local function run_pan(ctx)
	if ctx.pan_deadline > CLOCK or ctx.pan_block then
		return
	end

	local x1, y1, x2, y2
	local pt = ctx.pan_queue

	ctx.pan_queue = nil
	ctx.pan_queue_forced = nil
	if pt.dead then
		ctx.last_pan_target = nil
		return
	end

	ctx.last_pan_target = pt

-- this will resolve the world-space coordinate for the pan target, so the
-- anchor position is included in the deal and we can just nudge the anchor
	local props = image_surface_resolve(pt.bg)
	local margin = pt.cfg.pan_fit_margin

	x1 = props.x - margin[1]
	y1 = props.y - margin[2]
	x2 = props.x + margin[3] + pt.last_w
	y2 = props.y + margin[4] + pt.last_h

-- don't try and pan if it fits
	if x1 >= 0 and y1 >= 0 and x2 <= ctx.w and y2 <= ctx.h then
		return
	end

-- or if it is impossible
	if x2 - x1 > ctx.w or y2 - y1 > ctx.h then
		return
	end

	local dx = 0
	local dy = 0

-- bias towards upper left corner
	if x1 < 0 then
		dx = -1 * x1
	elseif x2 > ctx.w then
		dx = ctx.w - x2
	end

	if y1 < 0 then
		dy = -1 * y1
	elseif y2 > VRESH then
		dy = ctx.h - y2
	end

-- scale the animation speed based on the maximum relative pixel distance
	local adx = math.abs(dx)
	local ady = math.abs(dy)
	local fact

	if adx > ady then
		fact = adx / ctx.w
	else
		fact = ady / ctx.h
	end
	fact = math.clamp(fact, 0.1, 1.0)
	local speed = math.ceil(fact * ctx.cfg.pan_speed)

	ctx:nudge_anchor(dx, dy, speed, ctx.cfg.animation_tween)
	ctx.pan_deadline = CLOCK + speed
end

local function label_to_index(lbl)
	local ofs = 0

	for i=#lbl,1,-1 do
		local ch = string.sub(lbl, i, i)
		local val = string.byte(string.upper(ch)) - string.byte('A') + (i-1) * 27
		ofs = ofs + val
	end
	return ofs
end

local function relayout_rows(ctx, dt)
	local cfg = ctx.cfg
	dt = dt and dt or cfg.animation_speed

-- edge case, don't want pan-animation on spawn after deleting last row,
-- but delay it so any 'death' animation doesn't just appear in the corner
	if #ctx.rows == 0 then
		local pos = image_surface_properties(ctx.anchor)
		move_image(ctx.anchor, pos.x, pos.y)
		nudge_image(ctx.anchor, -pos.x, -pos.y, dt, cfg.animation_tween)
		return
	end

	for _, v in ipairs(ctx.rows) do
		reset_image_transform(v.bg, MASK_POSITION)
		if not v.detached then
			move_image(v.bg, 0, cfg.row_spacing, dt, cfg.animation_tween)
		end
	end

	local row = ctx.last_focus
	if not row then
		return
	end

	if ctx.last_pan_target then
		ctx:pan_fit(ctx.last_pan_target)
	end

	link_image(ctx.spawn_anchor, ctx.rows[#ctx.rows].bg, ANCHOR_LL, ANCHOR_SCALE_W)
	resize_image(ctx.spawn_anchor, 0, ctx.cfg.row_height)
end

local function ensure_cfg(cfg)
-- sanity-check cfg here and swap in defaults if something is missing
	assert(cfg.input_grab, "config lacks an input grab handler")
	assert(cfg.popup_grab, "config lacks a popup grab handler")
	return cfg
end

local function ctx_tick(ctx)
	for _, v in ipairs(ctx.rows) do
		v:tick()
	end

-- do this often enough
	if ctx.last_pan_target and CLOCK % ctx.cfg.repan_period == 0 then
		ctx:pan_fit(ctx.last_pan_target)
	end

-- this will repeat until the deadline from the last pan request has expired
	if ctx.pan_queue then
		run_pan(ctx)
	end
end

local function replace_cell(ctx, cell, ctype, ...)
	local _, _, focus_cell = cell.row:focused()
	local focused = cell == focus_cell
	local ot = cell.tag

	if focused then
		cell:unfocus()
	end

-- so emulate row destroy but not with destroying the row, but someone might
-- try to call this just after destroying the cell or on a detached cell
	if not cell.row then
		return
	end

	local props = image_surface_properties(cell.bg)
	local row = cell.row
	local ind = table.find_i(row.cells, cell)

	local op = image_parent(cell.bg)

-- and insert the new one in the same logical slot
	if not ctx.types[ctype] then
		warning("replace_cell() unknown type: " .. tostring(ctype))
		return
	end

	local new_cell = ctx.types[ctype](row, ctx.cfg, ...)
	if not new_cell then
		return
	end

-- This can happen if the construction of a cell causes it to replace into
-- aother, then we are at the end of insert_row just as the factory has been
-- called. This might leave us with an empty row
	if not ind then
		ind = 1
	else
		table.remove(row.cells, ind)
	end

	cell:destroy(0)

-- retain 'tag' so references might still work and update
	table.insert(row.cells, ind, new_cell)
	new_cell.name = ctype
	new_cell.tag = otag

-- reposition is to where the old cell was so the travel animation is shorter,
-- and retain the old 'link' as the invalidate schedule time might be in the future
	link_image(new_cell.bg, op)
	move_image(new_cell.bg, props.x, props.y)
	resize_image(new_cell.bg, props.width, props.height)

-- resend focus so input routing works
	if focused then
		new_cell:focus()
	end

-- any spawn animation triggered through the cell creation?
	if valid_vid(new_cell.vid) then
		instant_image_transform(new_cell.vid)
	end

-- missing is that we should also sweep all cells looking for any that references
-- the old cell and replace any links in processing / sampling there.
	new_cell.row:invalidate()
	return new_cell
end

local function register_type(ctx, name, factory, commands)
	ctx.types[name] = factory
	ctx.type_handlers[name] = commands
end

local function lookup_cell_tag(wm, tag)
-- if the user tags them, it is likely important enough to track
	return wm.tags[tag]
end

local function all_cells_id(wm)
	local lst = table.linearize(wm.tags, true)
	for i,v in ipairs(lst) do
		lst[i][1] = "$" .. v[1]
	end

	for _, v in ipairs(wm.rows) do
		local base = v:index_to_label()
		for n, c in ipairs(v.cells) do
			table.insert(lst, {base .. tostring(n), c})
		end
	end
	return lst
end

local function lookup_cell_name(wm, name)
-- strip out asci-index part
	local base = name
	local ofs = 1

	for i=1,#name do
		local ch = string.sub(name, i, i)
		if (string.byte(ch) >= 0x30 and string.byte(ch) <= 0x39) then
			base = string.sub(name, 1, i-1)
			ofs = tonumber(string.sub(name, i))
			if not ofs then
				return
			end
			break
		end
	end

	local row = wm.rows[label_to_index(base) + 1]
	if not row then
		return
	end

	return row.cells[ofs]
end

-- popup cell acts as just any normal row, but with different linking and a
-- destroy on onfocus action property
local function popup_cell(ctx, msg, cell, ...)
	local cfg = ctx.cfg
	ctx:drop_popup()

	local lf = ctx.last_focus
	if not lf then
		return
	end

-- build the popup cell and move it to the new anchor position, since it is a
-- popup we also grab input and return / revert on dismiss - but when restoring
-- we need to check so the cell didn't implode by itself
	local row = insert_row(ctx, -1, cell, ...)
	if not row then
		return
	end

	row:set_label(msg)

-- allow a different row background source for the popup
	set_image_as_frame(row.bg, ctx.row_popup_bg, 2)

	local grab_closure
	grab_closure = cfg.popup_grab(row.bg,
	function()
		grab_closure =
		function()
		end
		row.popup = false
		ctx:drop_popup()
	end)

-- self-modify / drop
	local old_uf = row.unfocus
	ctx.drop_popup =
	function()
		ctx.drop_popup = function()
		end
		grab_closure()

		if row.dead then
			return

-- special edge case here, if the currently focused cell has an error message
-- that is fresh, we want to detach that and kill on a timer
		else
			local last_cell = row.cells[row.selected_index]
			if last_cell.error_popup and CLOCK - last_cell.error_popup.clock < ctx.cfg.error_timeout then
				local ep = last_cell.error_popup
				last_cell.error_popup = nil
				relink_image(ep.anchor, WORLDID)
				timer_add_periodic("_popup_death", ctx.cfg.error_timeout, true, function()
					if valid_vid(ep.anchor) then
						ep:cancel()
					end
				end, true)
			end

			old_uf(row)
			row:destroy()
		end

-- focus will be lost otherwise?
		if not lf.dead then
			lf:focus()
		elseif #ctx.cells > 0 then
			ctx.cells[#ctx.cells]:focus()
		end
	end

	local ci = lf.cells[lf.selected_index]
	local lt = lf.bg

	if ci then
		lt = ci.bg
	end

-- this could really use the cursor
	link_image(row.bg, lt, ANCHOR_C)
	image_inherit_order(row.bg, true)
	order_image(row.bg, 10)
	row.index = lf.index

-- the 'row' doesn't exist in the normal set so invalidate won't be queued
	row:focus()
	row.cells[1].input_animation_speed = row.cfg.animation_speed
	row.no_anim_queue = true
	row:invalidate(row.cfg.animation_speed, true)

	row.unfocus =
	function()
		ctx:drop_popup()
	end

	return row.cells[1], ci
end

-- just boolean setter to mark if actions come from an interactive source or
-- not, as that might affect focus and panning
local function set_interactive(wm, state)
	if state then
		wm.interactive = true
	else
		wm.interactive = false
	end
end

local function ctx_invalidate(ctx, no_cd, no_anim)
	for i,v in ipairs(ctx.rows) do
		v:invalidate(nil, no_cd, no_anim)
	end
end

local function ctx_resize(ctx, neww, newh)
	ctx.w = neww
	ctx.h = newh
	ctx:drop_popup()
end

local function add_row_at(ctx, ind, ...)
-- absolute or relative to last?
	if ind == 0 then
		ind = 1

	elseif ind < 0 then
		ind = math.clamp(#ctx.rows + ind, 1, #ctx.rows + 1)

	elseif ind > #ctx.rows + 1 then
		ind = ctx.rows + 1
	end

	local row = insert_row(ctx, ind, ...)
	if not row or row.dead then
		return
	end

	row:focus()
	row:invalidate()

	return row
end

local function add_row(ctx, ...)
	return add_row_at(ctx, #ctx.rows + 1, ...)
end

-- ensure that the address fields and labels are correct after reordering
-- and allow groups to be split off into independetly anchored groups
local function reindex_rows(ctx)
	local group_parent = ctx.rows[1]

	for i,v in ipairs(ctx.rows) do

-- first group can't be detached from the global anchor, this might happen
-- if we swap across groups
		if i == 1 then
			link_image(v.bg, ctx.anchor)
			v.detached = nil
		elseif v.detached then
			group_parent = v
			link_image(v.bg, ctx.anchor)
		else
			link_image(v.bg, ctx.rows[i-1].bg, ANCHOR_LL)
		end

		v.group_parent = group_parent
		v.index = i
		v:set_label()
	end
end

local function detach_row(ctx, row_i)
	if not row_i then
		return
	end

	local dh = ctx.rows[row_i].bg_height

-- shift focus
	table.remove(ctx.rows, row_i)
	ctx:reindex()

-- make sure to retain position so animations stick
	local new_row = ctx.rows[row_i]
	if new_row then
		move_image(new_row.bg, 0, 2 * ctx.cfg.row_spacing + dh)
		new_row:focus()

	elseif #ctx.rows > 0 then
		ctx.rows[#ctx.rows]:focus()
	end
end

-- this is queued so a storm of pan-requests won't have (much) jank
local function pan_to(wm, tgt, force)
	if not tgt then
		if not wm.pan_queue_forced then
			wm.pan_queue = nil
		end
		return
	end

-- some cells that spawn storms of others and want to regain pan focus
-- might need to do so through more extreme means
	if wm.pan_queue and wm.pan_queue_forced then
		return
	end

	wm.pan_queue = tgt
	wm.pan_queue_forced = force
end

local function nudge_anchor(wm, dx, dy, dt, interp)
	local anchor = wm.anchor

-- if the currently selected row is detached, we move that row's anchor instead
	if wm.last_focus and wm.last_focus.group_parent ~= wm.rows[1] then
		anchor = wm.last_focus.group_parent.bg
	end

	reset_image_transform(anchor)
	nudge_image(anchor, dx, dy, dt, interp)
end

local function swap_rows(wm, r1_i, r2_i, dt, interp)
	local old = wm.rows[r2_i]
	wm.rows[r2_i] = wm.rows[r1_i]
	wm.rows[r1_i] = old
	wm:reindex()
	wm:relayout(dt, interp)
end

local function set_rendertarget(wm, rtgt)
	local set = {}
	local oldrt = wm.rtgt

	local set = rendertarget_vids(oldrt)
	wm.rtgt = rtgt

	for _, v in ipairs(set) do
		rendertarget_attach(wm.rtgt, v, RENDERTARGET_DETACH)
	end
end

local function set_active(wm)
	set_context_attachment(wm.rtgt)
	mouse_querytarget(wm.rtgt)
end

return
function(anchor, cfg)
	assert(valid_vid(anchor))

	if not cfg.row_bg then
		cfg.row_bg = fill_surface(32, 32, unpack(cfg.colors.active.row_bg))
		link_image(cfg.row_bg, anchor)
	end

	if not cfg.row_popup_bg then
		cfg.row_popup_bg = fill_surface(32, 32, unpack(cfg.colors.popup_bg))
		link_image(cfg.row_bg, anchor)
	end

	local res =
	{
	types    = {},
	type_handlers = {},
	rows     = {},
	tags     = {},
	w = VRESW,
	h = VRESH,
	rtgt = WORLDID,
	group_count = 1,
	resize   = ctx_resize,
	set_active = set_active,
	set_rendertarget = set_rendertarget,
	set_interactive = set_interactive,
-- counter used for reset() state/content tracking
	clock    = 0,
-- clipping / posiition orientation
	anchor   = anchor,
	cfg      = ensure_cfg(cfg),
-- hook up to CLK
	tick     = ctx_tick,
	invalidate = ctx_invalidate,
	relayout = relayout_rows,
	add_row  = add_row,
	add_row_at = add_row_at,
	popup_cell = popup_cell,
	row_bg   = cfg.row_bg,
	row_popup_bg = cfg.row_popup_bg,
	detach_row = detach_row,
	swap = swap_rows,
	reindex = reindex_rows,

-- swap the contents of one cell with another one
	replace_cell  = replace_cell,
	add_cell_type = register_type,
	find_cell_tag = lookup_cell_tag,
	find_cell_name = lookup_cell_name,

-- get a table of all rows and all their cells as tables of tables where
-- the first entry is the tag or cell address (tagged cells will occur twice)
	all_cells_id = all_cells_id,

-- take a set of cell references, find the screen-space positions and try to
-- offset the anchor so that shared bounding volume fit on the screen
	pan_fit = pan_to,
	pan_deadline = CLOCK,

-- the 'spawn' anchor attaches at the end of the last row
	spawn_anchor = null_surface(cfg.min_w, cfg.row_height),
	nudge_anchor = nudge_anchor,

-- when a popup_cell is active, this is changed to the destructor
	drop_popup = function()
	end,

-- for pairing with input bindings for certain actions
	action_bindings = function(wm, path)
	end
	}

	local sa = res.spawn_anchor

	local sa_mh = {
		name = "spawn_anchor",
		own = function(ctx, vid)
			return vid == sa
		end,
		over = function(ctx, vid)
			ctx.overlay = color_surface(1, 1, unpack(cfg.colors.active.selection_bg))
			blend_image(ctx.overlay, 1.0, cfg.animation_speed * 0.5)
			blend_image(ctx.overlay, 0.5, cfg.animation_speed * 0.5)

			resize_image(ctx.overlay, cfg.min_w, cfg.row_height)
			link_image(ctx.overlay, sa, ANCHOR_UL)
			image_mask_set(ctx.overlay, MASK_UNPICKABLE)
		end,
		out = function(ctx, vid)
			if valid_vid(ctx.overlay) then
				delete_image(ctx.overlay)
				ctx.overlay = nil
			end
		end,
		click = function()
			res:action_bindings("spawn_anchor_click")
		end,
		rclick = function()
			res:action_bindings("spawn_anchor_rclick")
		end
	}

	link_image(sa, anchor, ANCHOR_LL, ANCHOR_SCALE_W)
	image_mask_clear(sa, MASK_LIVING)
	image_inherit_order(sa, true)
	show_image(sa)
	mouse_addlistener(sa_mh)

	return res
end
