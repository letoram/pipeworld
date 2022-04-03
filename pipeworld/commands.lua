--
-- It returns a factory function that takes a wm context where it will
-- add a commands string keyed table. The factory function in turn
-- returns a lookup funciton that will perform the actual command
-- dispatch.
--
-- This should probably be refactored to match a durden-like menu structure
-- instead (but maybe stick with verb-object order as that is established in
-- bindings and menus now).
--
local ctx

-- wrappers for selected row and selected cell as those are so common
local function ensure_row(ctx, ...)
	local row = ctx.last_focus
	if not row then
		return
	end
	return row
end

local function run_row(ctx, fptr)
	local row = ctx.last_focus
	if not row then
		return
	end
	return fptr(row)
end

local function ensure_row_cell(ctx, scope, ...)
	local row = ctx.last_focus
	if not row then
		return
	end
	return row, row.cells[row.selected_index]
end

local function run_row_cell(ctx, method, ...)
	local row, cell = ensure_row_cell(ctx)
	if not row then
		return
	end
	return cell[method](cell, ...)
end

local menus = {}
local function build_menu(group)
	if not menus[group] then
		local fun = system_load("menus/" .. group .. ".lua", false)
		if fun then
			menus[group] = fun()
		else
			warning("couldn't load menu: " .. group)
			return
		end
	end

-- this is dynamically generated so that we can have menus for dynamic content
	local row, cell = ensure_row_cell(ctx)
	return menus[group](ctx, row, cell)
end

local cmdtree = {}

cmdtree["/reset/system"] =
function()
	system_collapse()
end

cmdtree["/shutdown/system"] =
function()
	shutdown(EXIT_SUCCESS)
end

cmdtree["/maximize/cell"] =
function(ctx, pan)
	local row, cell = ensure_row_cell(ctx)
	if not row then
		return
	end
	cell:maximize({pan = pan})
end

cmdtree["/scale/row/increment"] =
function(ctx, val)
	local row = ensure_row(ctx)
	if not row then
		return
	end

	val = math.clamp(val and val or 0.1, 0.01, 0.5)
	local inc_w = row.scale_factor[1] + val
	local inc_h = row.scale_factor[2] + val
	row:scale(inc_w, inc_h)
end

cmdtree["/scale/row/set"] =
function(ctx, val)
	local row = ensure_row(ctx)
	if not row then
		return
	end
	row:scale(val, val)
end

cmdtree["/scale/row/decrement"] =
function(ctx, val)
	local row = ensure_row(ctx)
	if not row then
		return
	end

	val = math.clamp(val and val or 0.1, 0.01, 0.5)
	local inc_w = row.scale_factor[1] - val
	local inc_h = row.scale_factor[2] - val
	row:scale(inc_w, inc_h)
end

cmdtree["/scale/cell/increment"] =
function(ctx, fdx, fdy)
	local row, cell = ensure_row_cell(ctx)
	if not row then
		return
	end

	fdx = fdx and fdx or 0
	fdy = fdy and fdy or 0
	fdx = math.clamp(fdx and fdx or 0.0, 0.01, 0.5)
	fdy = math.clamp(fdy and fdy or 0.0, 0.01, 0.5)

	cell.scale_factor[1] = math.clamp(cell.scale_factor[1] + fdx, 0.01, 100)
	cell.scale_factor[2] = math.clamp(cell.scale_factor[2] + fdy, 0.01, 100)
	cell.row:invalidate()
end

cmdtree["/scale/cell/decrement"] =
function(ctx, fdx, fdy)
	local row, cell = ensure_row_cell(ctx)
	if not row then
		return
	end

	fdx = fdx and fdx or 0
	fdy = fdy and fdy or 0
	fdx = math.clamp(fdx and fdx or 0.0, 0.01, 0.5)
	fdy = math.clamp(fdy and fdy or 0.0, 0.01, 0.5)

	cell.scale_factor[1] = math.clamp(cell.scale_factor[1] - fdx, 0.01, 100)
	cell.scale_factor[2] = math.clamp(cell.scale_factor[2] - fdy, 0.01, 100)

	cell.row:invalidate()
end

cmdtree["/invalidate/all"] =
function(ctx)
	for _, row in ipairs(ctx.rows) do
		row:invalidate(0, true, true)
	end
end

local function enum_group(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
			function()
			end
	end

	local i = 1
	local group_parent = row.group_parent

	if group_parent then
		i = row.group_parent.index
	end

	return function()
		if not ctx.rows[i] or (ctx.rows[i].detached and ctx.rows[i] ~= group_parent) then
			return nil
		else
			local res = ctx.rows[i]
			i = i + 1
			return res
		end
	end
end

cmdtree["/scale/group/toggle"] =
function(ctx)
	for row in enum_group(ctx) do
		if row.scale_copy then
			row:scale(row.scale_copy[1], row.scale_copy[1])
			row.scale_copy = nil
		else
			row.scale_copy = {row.scale_factor[1], row.scale_factor[2]}
			row:scale(1, 1)
		end
	end
end

cmdtree["/scale/group/set"] =
function(ctx, sx, y)
	for row in enum_group(ctx) do
		row:scale(sx, sy)
	end
end

cmdtree["/scale/group/decrement"] =
function(ctx, val)
	val = math.clamp(val and val or 0.1, 0.001, 0.5);
	for row in enum_group(ctx) do
		row:scale(row.scale_factor[1] - val, row.scale_factor[2] - val)
	end
end

cmdtree["/scale/group/increment"] =
function(ctx, val)
	val = math.clamp(val and val or 0.1, 0.001, 0.5);
	for row in enum_group(ctx) do
		row:scale(row.scale_factor[1] + val, row.scale_factor[2] + val)
	end
end

cmdtree["/scale/all/toggle"] =
function(ctx)
	for _, row in ipairs(ctx.rows) do
		if row.scale_copy then
			row:scale(row.scale_copy[1], row.scale_copy[1])
			row.scale_copy = nil
		else
			row.scale_copy = {row.scale_factor[1], row.scale_factor[2]}
			row:scale(1, 1)
		end
	end
end

cmdtree["/scale/all/set"] =
function(ctx, sx, sy)
	for _, row in ipairs(ctx.rows) do
		row:scale(sx, sy)
	end
end

cmdtree["/scale/all/decrement"] =
function(ctx, val)
	val = math.clamp(val and val or 0.1, 0.001, 0.5);
	for _, row in ipairs(ctx.rows) do
		row:scale(row.scale_factor[1] - val, row.scale_factor[2] - val)
	end
end

cmdtree["/scale/all/increment"] =
function(ctx, val)
	val = math.clamp(val and val or 0.1, 0.001, 0.5);
	for _, row in ipairs(ctx.rows) do
		row:scale(row.scale_factor[1] + val, row.scale_factor[2] + val)
	end
end

local function all_inactive(ctx, cb)
	local cr = ensure_row(ctx)
	if not cr then
		return
	end

	for _, row in ipairs(ctx.rows) do
		if row ~= cr then
			cb(row)
		end
	end
end

cmdtree["/scale/all_but_current/increment"] =
function(ctx, step)
	all_inactive(ctx,
	function(row)
		row:scale(row.scale_factor[1] + val, row.scale_factor[2] + val)
	end)
end

cmdtree["/scale/all_but_current/set"] =
function(ctx, sx, sy)
	all_inactive(ctx,
	function(row)
		row:scale(sx, sy)
	end)
end

cmdtree["/scale/all_but_current/decrement"] =
function(ctx, step)
	all_inactive(ctx,
	function(row)
		row:scale(row.scale_factor[1] - val, row.scale_factor[2] - val)
	end)
end

cmdtree["/revert/cell"] =
function(ctx)
	local row, cell = ensure_row_cell(ctx)

	if not cell then
		return
	end

	if cell.revert then
		cell:revert()
	else
		row.wm:replace_cell(cell, "expression")
	end
end

cmdtree["/revert/row"] =
function(ctx)
	local row, cell = ensure_row_cell(ctx)

	if not row then
		return
	end

	local list = {}
	for i,v in ipairs(row.cells) do
		if v.revert then
			table.insert(list, v)
		end
	end

	for _,v in ipairs(list) do
		v:revert()
	end
end

cmdtree["/popup/cursor/sysexpr"] =
function(ctx)
-- we fake 'build' a row, then remove it from the ctx and attach it to our cursor
	local cell = ctx:popup_cell("System", "expression", nil, false, ":")
	if cell then
		cell.destroy_on_escape = true
	end
end

local lst = glob_resource("menus/*.lua")
for _, v in ipairs(lst) do
	local k = string.sub(v, 1, -5)
	cmdtree["/popup/" .. k .. "_menu"] =
	function()
		pipeworld_popup_spawn(build_menu(k))
	end
end

cmdtree["/popup/cursor/rowexpr"] =
function(ctx)
	local pr, pc = ensure_row_cell(ctx)
	if not pr or not pc then
		return
	end

	local cell = ctx:popup_cell("Row", "expression", nil, false, "_")
	if cell then
		cell.eval_proxy = pc
		cell.destroy_on_escape = true
	end
end

cmdtree["/popup/cursor/cellexpr"] =
function(ctx)
	local pr, pc = ensure_row_cell(ctx)
	if not pr or not pc then
		return
	end

	local cell = ctx:popup_cell("Cell", "expression", nil, false, ".")
	if cell then
		cell.eval_proxy = pc
		cell.destroy_on_escape = true
	end
end

cmdtree["/pan/cursor"] =
function(ctx)
	local rx, ry = mouse_xy()
	local props = image_surface_resolve(ctx.anchor, 1000)
	reset_image_transform(ctx.anchor, MASK_POSITION)
	local dx = rx - props.x
	local dy = ry - props.y
	nudge_image(ctx.anchor, dx, dy, ctx.cfg.animation_speed, ctx.cfg.animation_tween)
end

cmdtree["/pan/focus"] =
function(ctx, row, ind)
	local cell
	if not ofs or not ctx.rows[row] or ctx.rows[row].cells[ind] then
		_, cell = ensure_row_cell(ctx)
	else
		cell = ctx.rows[row].cells[ind]
	end

	if not cell then
		return
	end

	cell.row.wm:pan_fit(cell)
end

cmdtree["/select/up"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row or #ctx.rows == 0 then
		return
	end

	local index = row.index - 1
	if index == 0 then
		index = #ctx.rows
	end

	ctx.rows[index]:focus()
end

cmdtree["/select/next"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
	end

-- action on overflow is configurable,
-- either wrap around
-- or step row
-- or insert cell
	local wrap = ctx.cfg.cell_wrap
	local at_end = row.selected_index == #row.cells
	if at_end and wrap and ctx.cmdtree[wrap] and wrap ~= "/select/next" then
		ctx.cmdtree[wrap](ctx)
		return
	end

	row:select_index(row.selected_index + 1)
end

cmdtree["/select/previous"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
	end

	row:select_index(row.selected_index - 1)
end

cmdtree["/select/last"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
	end
	row:select_index(#row.cells)
end

cmdtree["/swap/cell/left"] =
function(ctx)
	local row, cell = ensure_row_cell(ctx)
	if not row then
		return
	end

	local i = table.force_find_i(row.cells, cell)

	if i == 1 then
		return
	end

	local old = row.cells[i-1]
	row.cells[i-1] = cell
	row.cells[i] = old

	row:invalidate(0, true, true)
	row:select_index(i-1)
end

cmdtree["/swap/cell/right"] =
function(ctx)
	local row, cell = ensure_row_cell(ctx)
	if not row then
		return
	end

	local i = table.force_find_i(row.cells, cell)

	if i == #row.cells then
		return
	end

	local old = row.cells[i+1]
	row.cells[i+1] = cell
	row.cells[i] = old

	row:invalidate(0, true, true)
	row:select_index(i+1)
end

cmdtree["/swap/row/up"] =
function(ctx)
	local row = ensure_row(ctx)
	if row.index > 1 then
		row.wm:swap(row.index, row.index - 1)
	end
end

cmdtree["/swap/row/down"] =
function(ctx)
	local row = ensure_row(ctx)
	if row.index < #row.wm.rows then
		row.wm:swap(row.index, row.index + 1)
	end
end

cmdtree["/select/first"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
	end
	row:select_index(1)
end

cmdtree["/link/row"] =
function(ctx, state)
	run_row(ctx, function(row) row:toggle_linked(state) end)
end

cmdtree["/select/down"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
	end

	local wrap = ctx.cfg.row_wrap
	local at_end = row.index == #ctx.rows
	if at_end and wrap and ctx.cmdtree[wrap] and wrap ~= "/select/down" then
		ctx.cmdtree[wrap](ctx)
		return
	end

	local index = row.index
	index = index + 1
	if index > #ctx.rows then
		index = 1
	end

	ctx.rows[index]:focus()
end

cmdtree["/tick"] =
function(ctx, no_cd, no_anim)
	ctx:tick(no_cd, no_anim)
end

cmdtree["/reset/cell"] =
function(ctx)
	run_row_cell(ctx, "reset")
end

cmdtree["/reset/row"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
	end
	for i,v in ipairs(row.cells) do
		v:reset()
	end
end

cmdtree["/input/type_string"] =
function(ctx, str)
	if not str or #str == 0 then
		return
	end

	for _, v in ipairs(suppl_string_to_keyboard(str, pipeworld_get_keyboard())) do
		pipeworld_input(v)
	end
end

cmdtree["/delete/cell"] =
function(ctx)
	local row, cell = ensure_row_cell(ctx)
	if not row then
		return
	end
	row:delete_cell(cell)
end

cmdtree["/delete/row"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row then
		return
	end

	row:destroy()
end

cmdtree["/toggle/anchor/row"] =
function(ctx)
	ctx:toggle_linked(row)
end

-- this should be automatically invoked from pipeworld_display_state
cmdtree["/resize/canvas"] =
function(ctx, neww, newh, vppcm, hppcm)
	local cfg = ctx.cfg
	if cfg.wallpaper_update then
		cfg.wallpaper_update(cfg.wallpaper, cfg, neww, newh)
	end
	ctx:resize(neww, newh)
end

cmdtree["/clipboard/paste_preview"] =
function(ctx)
	local pr, pc = ensure_row_cell(ctx)
	if not pr or not pc then
		return
	end

	local msg = pipeworld_clipboard().globals[1]
	if not msg or #msg == 0 then
		return
	end

	msg = string.gsub(msg, "\"", "\\\"")

	local cell = ctx:popup_cell("Cell", "expression", "paste(\"" .. msg .. "\")", false, ".")
	if cell then
		cell.eval_proxy = pc
		cell.destroy_on_escape = true
	end
end

cmdtree["/clipboard/copy"] =
function(ctx, msg, outtype)
	local cb = pipeworld_clipboard()

	if not msg then
		local _, cell = ensure_row_cell(ctx)
		if not cell then
			return
		end

		if cell.last_str then
			msg = cell.last_str
		elseif cell.clipboard then
			msg = cb:list_local(cell.clipboard)[1]
		end
	end

	if msg then
		pipeworld_clipboard():set_global(msg,
			"/clipboard/copy", outtype and outtype or "text/plain")
	end
end

cmdtree["/clipboard/paste"] =
function(ctx, msg)
	local _, cell = ensure_row_cell(ctx)
	if cell and cell.paste then
		cell:paste(pipeworld_clipboard().globals[1])
	end
end

cmdtree["/resynch"] =
function(ctx)
	local row = ensure_row(ctx)
	if not row or #row.cells < 2 then
		return
	end

	local function match_type(tin, tout)
		for _, stype in ipairs(tin) do
			for _, dtype in ipairs(tout) do
				if dtype == stype then
					return stype
				end
			end
		end
	end

-- sweep chain, match preferred type transfers, cancel at first fail
	for i=1,#row.cells-1 do
		local acell = row.cells[i+0]
		local bcell = row.cells[i+1]
		local tin = bcell:types()
		local tout = acell:types()

-- pick first match from both sets
		local match = match_type(tin, tout)
		if not match then
			return
		end

-- and the sending cell will forward to receive on the other
		acell:send(bcell, match)
	end
end

function pipeworld_command_register(path, command)
	cmdtree[path] = command
end

-- take a row/cell wm context and return a command-tree for binding inputs
return
function(wm)
	ctx = wm
	local cmdtree = table.copy_shallow(cmdtree)
	ctx.cmdtree = cmdtree

	for k,v in pairs(wm.types) do
		cmdtree["/insert/row/" .. k] =
		function(ctx, ...)
			ctx:add_row(k, ...)
		end
	end

-- append the permitted cell types
	for ctype, _ in pairs(wm.types) do
		cmdtree["/append/row/" .. ctype] =
		function(ctx, ...)
			local row, cell = ensure_row_cell(ctx)
			if row then
				local cell = row:add_cell(wm.types[ctype], ...)
				if cell then
					row:select_cell(cell)
				end
			end
		end

-- and any dynamic paths it might have provided
		if wm.type_handlers[ctype] then
			for k, fn in pairs(wm.type_handlers[ctype]) do
				cmdtree[k] = function(ctx, ...)
					local row, cell = ensure_row_cell(ctx)
					if cell then
						fn(cell, ...)
					end
				end
			end
		end
	end

-- and default to expression
	cmdtree["/insert/row"] =
	function(ctx, ...)
		return ctx:add_row("expression", ...)
	end

	return
	function(path, ...)
		if cmdtree[path] then
			return cmdtree[path](ctx, ...)
		end
	end
end
