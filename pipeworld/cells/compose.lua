-- naive basic recursive binpacker,
local function simple_solver(nodes, w, h)
	table.sort(nodes, function(a, b) return a.h > b.h end)

	local get_node;
	get_node = function(n, w, h)
		if (n.used) then
			local r = get_node(n.r, w, h)
			if (r) then
				return r;
			else
				return get_node(n.d, w, h)
			end
		elseif (w <= n.w and h <= n.h) then
			n.used = true
			n.d = {x = n.x,     y = n.y + h, w = n.w,     h = n.h - h}
			n.r = {x = n.x + w, y = n.y,     w = n.w - w, h = h      }
			return n
		end
	end

	local root = {x = 0, y = 0, w = w, h = h}
	for _, v in ipairs(nodes) do
		local n = get_node(root, v.w, v.h)
		if (n) then
			v.x = n.x; v.y = n.y
			v.used = true
		end
	end

-- did we get a solution or not?
	local rest = {}

	for _, v in ipairs(nodes) do
-- option here would also be to split the work-set based on the not-used ones,
-- add that to a second plane and offset- / re-order that
		if not v.used then
			table.insert(rest, v)
		end
	end

	if #rest > 0 then
		return false, rest
	end

-- some post- processing here to make sure we add space when possible would be nice,
	return true
end

local ro_controls =
{
	["LEFT"] =
	function()

	end,
	["TAB"] =
	function()

	end
}

local function simple_ro_input(cell, iotbl, sym, lutsym)
-- input is only used to relayout, and since mouse.lua still does not handle/
-- expose a context based state machine we are stuck with manual controls for
-- adjusting the composition.
	if iotbl.digital and not iotbl.active then
		return
	end

	if sym and ro_controls[sym] then
		ro_controls[sym](cell)
	end
end

local function simple_rw_input(iotbl)
-- allow some kind of typing, the likely path from this isn't in-pipeworld
-- itself as you can just type into the source cell, but from an encoder
-- attached that is connected to an external source where you get 'input'
-- events.
end

local function apply_pad(set)
	for _,v in ipairs(set) do
		v.x = v.x + v.pad_w
		v.y = v.y + v.pad_h
		v.w = v.w - v.pad_w - v.pad_w
		v.h = v.h - v.pad_h - v.pad_h
	end
end

local function expose_bin(set, max_w, max_h)

-- add some padding, a better post processing here would be some kind of
-- graph drawing algorithm e.g. spring or something to space things out after
-- we have a solution
	for _,v in ipairs(set) do
		v.pad_w = 20
		v.pad_h = 20
		v.w = v.w + v.pad_w + v.pad_w
		v.h = v.h + v.pad_h + v.pad_h
	end

	if simple_solver(set, max_w, max_h) then
		apply_pad(set)
		return
	end

-- remove down to 1 px border
	for _,v in ipairs(set) do
		v.w = v.w - v.pad_w - v.pad_w
		v.h = v.h - v.pad_h - v.pad_h
		v.pad_w = 1
		v.pad_h = 1
	end

-- and expose-like shrink until we have a solution
	while not simple_solver(set, max_w, max_h) do
		for _,v in ipairs(set) do
			v.w = v.w * 0.9
			v.h = v.h * 0.9
		end
	end

	apply_pad(set)
end

local policies = {
	ro_bin = {expose_bin, simple_ro_input},
	rw_bin = {expose_bin, simple_rw_input},
}

local function apply_solver(cell)
	local w = cell.rendertarget_wh[1]
	local h = cell.rendertarget_wh[2]

	local boxes = {}

-- translate into current set, add some padding
	for _,v in ipairs(cell.compose_set) do
		local props = image_surface_resolve(v)
		table.insert(boxes, {
			vid = v,
			x = 0,
			y = 0,
			w = props.width,
			h = props.height,
			z = 1
		})
	end

-- policy will reposition/resize/tag
	cell.policy[1](boxes, w, h)

	for _,v in ipairs(boxes) do
		move_image(v.vid, v.x, v.y)
		resize_image(v.vid, v.w, v.h)
		order_image(v.vid, v.z)
	end
end

return
function(row, cfg, opts, ...)
-- arguments are treated as full cells (table), vids that we inherit
-- (caller expected to null_surface+share_storage) or factory functions
-- in order to provide input and react on changes
	local cells = {...}

	opts = type(opts) == "table" and opts or {}

	if not opts.policy then
		opts.policy = cfg.compose_policy
	end

	if not policies[opts.policy] then
		warning("unknown composition packing policy")
		return
	end

-- setup the buffer and quality / format
	local w, h = unpack(cfg.compose_default_wh)
	if opts.width then
		w = opts.width
	end

	if opts.height then
		h = opts.height
	end

	local fmt = ALLOC_QUALITY_NORMAL
	if opts.format and type(opts.format) == "number" then
		fmt = opts.format
	end

	local vid = alloc_surface(w, h, true, fmt)
	if not valid_vid(vid) then
		warning("could not allocate composition surface")
		return
	end
	image_mask_set(vid, MASK_UNPICKABLE)

-- Create the composition intermediates and bind as rendertarget,
--
-- This is not (yet) clocked off the set of producers but rather updates
-- every frame which is wasteful.
--
-- What should be done is to enable verbose reporting (part of fsrv.lua)
--
	local set = {}
	local input_map = {}

	local clean_set =
	function()
		for _, v in ipairs(set) do
			delete_image(v)
		end
	end

	for _, v in ipairs(cells) do
		if type(v) == "table" then
			v = v:export_content("video_buffer_handle")
		end

		if type(v) == "number" and valid_vid(v) then
-- In order to not break the source cell, we need to make a copy, the problem
-- is to pick a suitable scale and trigger on storage modifications. Just go with
-- the native storage size and let the layouting scheme deal with per-surface resizes.
--
-- Arcan does not do this yet, but be able to tag_transform a surface to react on
-- backing store changes is probably the way forward rather than adding more appl-
-- level logic on_resize.
			local props = image_storage_properties(v)
			local surf = null_surface(props.width, props.height)

-- vid limit might be reached
			if not valid_vid(surf) then
				warning("couldn't allocate composition-intermediate")
				clean_set(set)
				return
			end

			image_sharestorage(v, surf)
			table.insert(set, surf)
			image_tracetag(surf, "composite_intermediate_" .. tostring(v))
			show_image(surf)

-- if we need to retain the input mapping for external clients, track that
-- though we might need to do something more fancy to survive across multiple
-- compose(compose()) (which is kindof insane)
			if valid_vid(v, TYPE_FRAMESERVER) then
				input_map[surf] = v
			end

			table.insert(set, surf)
		else
			warning("bad member in compose-cell source set")
		end
	end

	if #set == 0 then
		clean_set(cells)
		warning("refusing empty composition-cell source set")
		return
	end

	define_rendertarget(vid,
		set, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1)

-- finally tie to the cell itself
	local res = pipeworld_cell_template("compose", row, cfg)
	res.input_map = input_map
	res.compose_set = set
	res.policy = policies[opts.policy]
	res.rendertarget_wh = {w, h}
	res:set_content(vid)
	res.types = {
		{},
		{"video_buffer_handle"}
	}

	local focus = res.focus
	res.focus =
	function(cell, ...)
		focus(cell, ...)
		cell.cfg.input_grab(cell,
			function(iotbl, sym, lutsym)
				if not iotbl then -- grab release
					return
				end
				cell.policy[2](cell, iotbl, sym, lutsym)
			end
		)
	end

	apply_solver(res)
	return res
end,
{
-- resize
-- auto_relayout
--
}
