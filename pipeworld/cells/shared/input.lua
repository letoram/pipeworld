-- primitive for building command-line input, lifted from durden/suppl.lua
local readline = system_load("ui/text_input.lua")()

local function resolve_scale(cell)
	local row_scale = cell.row.scale_factor
	local cell_scale = cell.scale_factor
	local sfx = row_scale[1] * cell_scale[1]
	local sfy = row_scale[2] * cell_scale[2]
	return sfx, sfy
end

local function get_format_string(cfg, sfy)
	local pt_sz = math.clamp(math.floor(cfg.font_sz * sfy), 1)
	return string.format(cfg.input_format, cfg.font, pt_sz)
end

local function input_lock(cell)
	cell.input_locked = true
	hide_image(cell.caret)
end

local function update_str(cell, msg)
-- figure out where to draw the caret
	local sfx, sfy = resolve_scale(cell)
	local fmt_str = get_format_string(cell.cfg, sfy)
	local cstr = cell.readline:caret_str()
	local w, h = text_dimensions({fmt_str, cstr})

	cell.caret_ofs = w
	move_image(cell.caret, w, 0)

-- scaling won't be as accurate for the line here as we stick strictly to the
-- pt_size, when having MSDFs as an option that can be reconsidered
	local msg_changed = msg ~= cell.last_str
	local fmt_changed = fmt_str ~= cell.last_fmt

	if msg_changed and cell.text_changed then
		cell:text_changed(msg, cell.last_str, cstr)
	end

	if msg_changed or fmt_changed then
		cell.last_str = msg
		cell.last_fmt = fmt_str

		_, _, cell.label_w, h = render_text(cell.line, {fmt_str, msg})
	end

-- if an empty string gets set, the returned height will also be empty in spite
-- of our previous calibration of pt size, causing box/clipping/anchor to be wrong
-- so re-do the dimensions against a placebo-string to get the height
	if h == 0 then
		_, h = text_dimensions({fmt_str, "Aj!_^"})
		cell.label_h = h
	end

	cell.last_box_w = cell.box_w

-- set the actual box_w to the content width
	if cell.cfg.min_w == 0 then
		cell.box_w = cell.label_w + 4
	else
		cell.box_w = math.floor(
			(math.floor(cell.label_w / cell.cfg.min_w) + 1) * cell.cfg.min_w)
	end

-- don't relayout every input, but grow/shrink the box with a decent margin,
-- interestingly enough the HEIGHT can oscillate from rounding / scaling issues
-- that seem to be tied to render_text
	if cell.last_box_w ~= cell.box_w or fmt_changed then
		if h > 0 then
			cell.label_h = h
		end

-- default is off, popup cell forces it
		cell.row:invalidate(cell.input_animation_speed)
	end
end

local function focus(cell)
	cell:recolor()
	cell.cfg.input_grab(cell,
	function(io, sym, lutsym)
		local msg
		if not io or not io.active or not cell.readline then
			return
		end

		if cell.symbol_input and cell:symbol_input(sym, lutsym, io.utf8) then
			return
		end

		if sym == "ESCAPE" then
			if cell.error_popup then
				cell.error_popup:cancel()
				cell.error_popup = nil
			end

			if not cell.read_only then
				cell.input_locked = false
				show_image(cell.caret)
			end

			cell:recolor()
			update_str(cell, cell.readline:view_str())

-- cell destroy goes through the row it is in
			if cell.destroy_on_escape then
				cell.row:delete_cell(cell)
			end
			return
		end

		if cell.input_locked then
			return
		end

-- first check our own symbols
		if sym == "RETURN" or sym == "KP_ENTER" then
			msg = cell.readline:view_str()
			if #msg > 0 and cell.ok then
				cell:commit(msg)
			end
			return
		end

-- then process the input, this will modify msg and possibly caret
		cell.readline:input(io, sym, lutsym)
		msg = cell.readline:view_str()
		local fmt, ok = cell:eval(msg)
		cell.ok = ok

		update_str(cell, msg)
	end)
	cell.old_handlers.focus(cell)
end

local function force_str(cell, msg)
	cell.readline:set_str(msg)
	update_str(cell, cell.readline:view_str())
end

local function resize(cell, dt, interp)
	update_str(cell, cell.last_str)
	local w, h = cell:content_size()

	reset_image_transform(cell.box, MASK_SCALE)
	reset_image_transform(cell.caret, MASK_SCALE)

	if cell.last_w == w and cell.last_h == h then
		return
	end

-- skip the animations, couldn't get them to look decent
	resize_image(cell.caret, 1, h) -- dt, interp)
	resize_image(cell.box, w, h)
end

local function unfocus(cell)
	cell.old_handlers.unfocus(cell)
	hide_image(cell.caret)
end

-- we rescale pt size and reraster on height change,
-- then crop the text if it doesn't fit the box while animating
local function content_size(cell)
	local cw = cell.box_w
	local ch = cell.label_h
	return cw, ch, cw, ch
end

local function release_readline(cell)
	delete_image(cell.box)
	cell.box = nil
	cell.caret = nil
	cell.readline = nil

	for k,v in pairs(cell.old_handlers) do
		cell[k] = v
	end

	cell.old_handlers = nil
end

local function recolor(cell)
	local col = cell.cfg.colors[cell.row.state]
	local lbl = "cell_" .. cell.state

	assert(col[lbl], "missing color for cell state: " .. cell.state)
	if cell.decor then
		cell.decor:border_color(unpack(col[lbl]))
	end

	image_color(cell.box, unpack(col.input_background))
	blend_image(cell.box, col.input_background[4])
end

local function append_str(cell, msg)
	if type(msg) == "string" then
		local rl = cell.readline
		if rl then
			local nch
			rl.msg, nch = string.insert(rl.msg, msg, rl.caretpos)
			rl.caretpos = rl.caretpos + nch
			update_str(cell, rl:view_str())
		else
			cell:force_str(msg)
		end
	end
end

return
function(id, row, cfg)
	local cell = pipeworld_cell_template(id, row, cfg)

-- bounding-box for background/contrast and order/clipping anchor
	local vid, _, w, h = render_text({get_format_string(cfg, 1), "temp"})
	render_text(vid, "")
	cell.name = id
	cell.box_w = cfg.min_w
	cell.label_h = h
	cell.label_w = w
	cell.recolor = recolor
	cell.caret_ofs = 0
	cell.line = vid
	cell.box = color_surface(1, 1, 0, 64, 0)
	cell.caret = color_surface(1, 1, unpack(cfg.colors.active.caret))
	cell.content_size = content_size
	cell.update_label = update_str
	cell.lock_input = input_lock
	cell.force_str = force_str
	cell.paste = append_str

	link_image(cell.line, cell.bg)
	link_image(cell.box, cell.line, ANCHOR_UL)
	link_image(cell.caret, cell.bg)
	show_image({cell.caret, cell.line})--, cell.box})

	image_inherit_order({cell.box, cell.caret, cell.line}, true)

-- resolve through new anchor chain
	order_image(cell.caret, 3)
	order_image(cell.line, 2)
	order_image(cell.box, -1)

-- we want to be able to click the text as a way of moving the caret
-- (binary search with text_dimensions) but until that is implemented,
-- just block all of those actions
	image_mask_set(cell.box, MASK_UNPICKABLE)
	image_mask_set(cell.line, MASK_UNPICKABLE)
	image_mask_set(cell.caret, MASK_UNPICKABLE)

-- this will make the text not clip cleanly to the box, the thing is that
-- non-shallow clipping can be really expensive (stencil buffer) it is best
-- to accept the slightly worse visuals.
	image_clip_on(cell.caret, CLIP_SHALLOW, row.bg)
	image_clip_on(cell.line, CLIP_SHALLOW, row.bg)
	image_clip_on(cell.box, CLIP_SHALLOW, row.bg)

	cell.readline = readline(nil, {}, nil, {})

-- for release if we mutate the cell to something else
	cell.old_handlers = {
		focus = cell.focus,
		unfocus = cell.unfocus,
		resize = cell.resize,
	}

	cell.focus = focus
	cell.unfocus = unfocus
	cell.resize = resize
	cell.release = release_readline

-- hooks for input handling, completion, ...
	cell.commit = function()
		warning("missing, cell does not implement commit")
	end

	cell.eval = function(cell, msg)
		return "", true
	end

	return cell
end
