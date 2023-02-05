local parse, types, type_strtbl = system_load("cells/shared/parser.lua")()()

-- history is kept per default namespace
local history =
{
 ["="] = {},
 [":"] = {},
 ["."] = {},
 ["_"] = {}
}

-- namespace to function mapping
local vtables = {}

-- prefix character to symbol table mapping
local namespaces = {}

-- loading with some minor validation
local valid_table_req = {
	handler = "function",
	args = "table",
	help = "string",
	type_helper = "table",
}

local function load_action(dst, fn, sym)

	local fun, msg = system_load(fn, false)
	if not fun then
		warning(string.format("expression.lua: error loading: %s", fn))
		return
	end

-- so we have a function that represents the loaded script, time to eval it
	local ok, fact = pcall(fun)
	if not ok then
		warning(string.format(
			"expression.lua: parsing error on %s, reason: %s", fn, fact))
		return
	end

-- now we have the function that should expand into the actual function
	if type(fact) ~= "function" then
		warning(string.format(
			"expression.lua: %s not returning a valid factory", fn))
		return
	end

-- run and validate the result before adding as a valid function
	local restbl = fact(types)
	if not type(restbl) == "table" then
		warning(string.format(
			"expression.lua: %s did not return a table", fn))
			return
	end

	for k,v in pairs(valid_table_req) do
		if type(restbl[k]) ~= v then
			warning(string.format(
				"expression.lua: %s key %s type mismatched (expected %s, got %s)", fn, k, v, type(restbl[k])))
			return
		end
	end

	if not restbl.argc then
		warning(string.format("expression.lua: %s did not provide an argument count", fn))
		return
	end

-- special optional command for registering in the commands- binding space
-- note the this only applies to WMs created after this has been loaded, so
-- dynamic reloading functions without resetting won't be reflected
	if type(restbl.command) == "string" then
		pipeworld_command_register(restbl.command, restbl.handler)
	end

-- finally build the vtable entry
	dst[sym] = restbl
end

local function reload_commands()
	namespaces = {}
	namespaces[":"] = "system"
	namespaces["."] = "cell"
	namespaces["_"] = "row"
	namespaces["="] = "expression" -- also the default

	local base = "cells/api/"

	for _, k in pairs(namespaces) do
		local pref = base .. k .. "/"
		vtables[k] = {}
		for _, v in ipairs(glob_resource(pref .. "*.lua")) do
			load_action(vtables[k], pref .. v, string.lower(string.sub(v, 1, #v-4)))
		end
	end

-- expression namespace is also merged into system/cell/row, but not the ones
-- that are factories, having cell expressions that create new cells would open
-- up for ugly side effects
	for k,v in pairs(vtables.expression) do
		if not vtables.cell[k] then
			vtables.cell[k] = v
		end
		if not vtables.system[k] then
			vtables.system[k] = v
		end
	end

-- the factory functions can be applied in both expression context and in system
-- scope as a means of adding new cells or new rows
	local pref = base .. "factory/"
	for _, v in ipairs(glob_resource(pref .. "*.lua")) do
		local basename = string.lower(string.sub(v, 1, #v-4))
		load_action(vtables["system"], pref .. v, basename)
		load_action(vtables["expression"], pref .. v, basename)
	end

-- add ourself to the system namespace for reloading
	vtables["system"]["reload"] = {
		handler = reload_commands,
		args = {types.NIL},
		argc = 0,
		help = "Reload expression API",
		type_helper = {}
	}
end

reload_commands()

local function set_error(cell, err, ofs, msg)
-- hover / toggle for error message, cell doesn't have a good way to visualize
-- the error message yet so here we are
	if type(err) == "string" then
		cell:set_error(err, ofs)
	end

	cell:lock_input()
end

-- we also need a way to covert types, e.g. image_buffer_handle can be
-- retained the way it is, but a video_buffer_handle would need to be
-- sample-copied when applied
local typemap = {
	["image_buffer_handle"] = types.IMAGE,
	[types.IMAGE] = "image_buffer_handle",
	["video_buffer_handle"] = types.VIDEO,
	[types.VIDEO] = "video_buffer_handle",
	[types.STRING] = "text/plain",
	["text/plain"] = types.STRING,
}

-- symbol lookup:
--  $name   tagged cell alias name
--
local function cell_symbol(cell, name, dtype, alt)
	local ch = string.sub(name, 1, 1)
	local row = cell.row
	local	cell_ref

-- relative-or-absolute
	if ch == "$" then
-- grab cell and row index, step n and resolve
		if #name == 1 then
			return nil
		end
		local rest = string.sub(name, 2)
		cell_ref = cell.row.wm:find_cell_tag(rest)
		if not cell_ref then
			return nil, "No cell tagged (" .. rest .. ")"
		end
-- or absolute row reference by name and (possibly) number
	else
		cell_ref = cell.row.wm:find_cell_name(name)
		if not cell_ref then
			return nil, "No cell with name (" .. name .. ")"
		end
	end

	if cell_ref == cell then
		return nil, "Self-recursive cell reference (" .. name .. ")"
	end

-- register us as a possible trigger if the referenced cell changes,
-- but only once (A1 + A1 should only reset us once if A1 changes(
	if cell_ref.update_listeners then
		if not table.find_i(cell_ref.update_listeners, cell) then
			table.insert(cell_ref.update_listeners, cell)
		end
	end

-- remember this symbol as one of our references, so that we can unreg
-- on our next reset (which would case a new insert)
	if not table.find_i(cell.lookup_cache, cell_ref) then
		table.insert(cell.lookup_cache, cell_ref)
	end

-- use a typemap between our set of types and the ones used by the lexer and
-- expression cells, as the content import/export mechanism can be used for
-- negotiating/pairing mime-type sets and that kind of jazz as well.
	local content, ctype = cell_ref:export_content(
		dtype ~= types.VARTYPE and typemap[dtype] or nil, alt)
	if content then
		if not typemap[ctype] then
			return nil, "Referenced cell provided content of unknown type: '" .. ctype .. "'"
		end
		return content, typemap[ctype]
	end

	if dtype == types.CELL then
		return cell_ref, types.CELL
	end

-- special handling for the types we know of, being STRING and NUMBER
	if dtype == types.VARTYPE or dtype == types.STRING or dtype == types.NUMBER then
		if cell_ref.content then
			if dtype == types.STRING then
				return tostring(cell_ref.content[1]), types.STRING
			end
			return tostring(cell_ref.content[1]), types.NUMBER
		end

-- image with a video source we can just instantiate with a null-surface
-- or re-blit through a rendertarget BUT lifecycle becomes weird, to avoid
-- that we need to copy every time
	elseif dtype == types.IMAGE then
	end

	return nil, "Referenced cell cannot provide content for type '" .. type_strtbl[dtype] .. "'"
end

-- return a function that returns val, typetble
local function expose_func(cell, vtable, name)
	local fn = vtable[name]
	if not fn then
		return
	end

	return fn.handler, fn.args, fn.argc
end

local function set_number(cell, val, expr)
	cell.content = {val}
	cell.types[2] = {types.NUMBER}
	cell:set_state("completed")
	local nf = cell.number_formats[cell.format_index]
	cell:update_label(cell.number_formats[cell.format_index].process(val))

-- track these so that we can switch representation with TAB
	cell.title = nf.label .. expr
	cell.expression = expr
	cell.row:invalidate()

	cell:add_result(val)
	cell:lock_input()
end

local function set_string(cell, val, expr)
	cell.content = {val}
	cell.types[2] = {types.STRING}
	cell:set_state("completed")
	cell:update_label(val)

	local ns = cell.force_ns and cell.force_ns or "="
	cell:lock_input()
end

local function revert_expression(cell, expr)
	return function()
		local cell = cell.row.wm:replace_cell(cell, "expression", expr)
	end
end

local function notify_handlers(cell)
	for i,v in ipairs(cell.update_listeners) do
		if v.dirty_update then
			v:dirty_update()
		end
	end
end

local function flush_lookup_cache(cell)
	for _, v in ipairs(cell.lookup_cache) do
		if v.update_listeners then
			table.remove_match(v.update_handlers, cell)
		end
	end

	cell.lookup_cache = {}
end

local function drop_popup(cell)
	if cell.popup then
		cell.popup:cancel()
		cell.popup = nil
	end
	if cell.show_help then
		cell.show_help:cancel()
		cell.show_help = nil
	end
end

local function dispatch_expr(cell, expr, vtable, slookup)
-- set the 'reset' handler for the cell to be the function that
-- evaluates the expression and then explicitly invoke rest
	local in_reset = false

	cell.reset =
	function()
-- recursion safeguard
		if in_reset then
			return
		end
		in_reset = true

		flush_lookup_cache(cell)

		local res =
		parse(
			expr,
			function(...)
				return slookup(cell, ...)
			end,
			function(...)
				return expose_func(cell, vtable, ...)
			end,
			function(...)
				return set_error(cell, ...)
			end
		)

		if type(res) ~= "function" then
-- got error during parsing
			return
		end

		local old_scope = eval_scope
		eval_scope = {
			cell = cell.eval_proxy and cell.eval_proxy or cell,
			row = cell.row,
			wm = cell.row.wm
		}

-- eval expression
		local act, kind, val = res()
		cell.content_ts = CLOCK

-- edge-case, the call might have modified the row/cell so that it no longer exists
		if cell.dead or cell.row.dead then
			return
		end

		if kind == types.NUMBER then
			set_number(cell, val, expr)
			notify_handlers(cell)
			rv = true

		elseif kind == types.STRING then
			set_string(cell, val, expr)
			notify_handlers(cell)
			rv = true

-- more state might need to be transfered in these cases where we mutate to
-- a different type in order for cells dependent on us to remain consistent
		elseif kind == types.FACTORY then

-- if we run as a popup, apply the factory to the row where the cell is
			local new_cell
			if val and cell.row.popup and cell.row.popup.add_cell then
				local th = cell.row.wm.types[val[1]]
				new_cell = cell.row.popup:add_cell(th, unpack(val, 2))
			elseif val then
				new_cell = cell.row.wm:replace_cell(cell, unpack(val))
			end

			if new_cell then
				new_cell.revert = revert_expression(new_cell, expr)
			else
-- we expect the factory itself to :set_error so do nothing on failure
			end

		elseif kind == types.IMAGE then
-- either spawn new or mutate with eval type
			local new_cell = cell.row.wm:replace_cell(cell, image_tracetag(val))
			new_cell:set_content(val)
			new_cell.revert = revert_expression(new_cell, expr)
			rv = true

-- just clear
		elseif kind == types.NIL then
			cell:force_str("")
		end

-- use clock granularity for the time being
		eval_scope = old_scope
		in_reset = false
	end

	cell:reset()
-- the reset might have destroyed the cell
	if cell.row and cell.row.popup then
		cell.row.wm:drop_popup()
	end

	return rv
end

local function mode_check(cell, msg)
-- commit guaranteed > 0
	cell.last_expression = msg
	cell.last_mode = nil

-- mutate cell type based on contents
	local mode = string.sub(msg, 1, 1)
	local rest = string.sub(msg, 2)
	cell.types = {
		{},
		{}
	}

-- pick expression namespace by default (no selector for symbol space)
	local vtable = vtables.expression
	local stable = cell_symbol

	if mode == "!" and not cell.force_ns then
		if (rest == "lash") then
			cell.row.wm:replace_cell(cell, "cli",
				cell.cfg.terminal_size[1], cell.cfg.terminal_size[2], "cli=lua")
		else
			cell.row.wm:replace_cell(cell, "cli", rest)
		end
		return

	elseif mode == "#" and not cell.force_ns then
		cell.terminal_size = cell.cfg.cli_size
		cell.row.wm:replace_cell(cell, "terminal", rest)
		return

	elseif namespaces[mode] then
		vtable = vtables[namespaces[mode]]
		msg = rest
		cell.last_mode = mode
	end

-- allow the #.: etc. parsing to work, but then swap the namespace
	if cell.force_ns and namespaces[cell.force_ns] then
		vtable = vtables[namespaces[cell.force_ns]]
	end

	drop_popup(cell)

-- full expression, parse returns a function that will execute the expression
	cell:set_state("processing")
	cell.title = msg
	cell.row:invalidate()

-- remember in history both expression and result at the time
	local hdst = history[cell.force_ns and cell.force_ns or "="]

	if (dispatch_expr(cell, msg, vtable, stable) and cell.cfg) then
-- add to history
		local found = false
		for i,v in ipairs(hdst) do
			if v == msg then
				found = true
				break
			end
		end

		if not found then
			table.insert(hdst, msg)
			if #hdst > cell.cfg.expression_history then
				table.remove(hdst, 1)
			end
		end

		table.insert(hdst, msg)
	end

-- nothing changed? (dead / nil expression)
	if cell.state == "processing" then
		cell:set_state("passive")
	end
end

-- whenever a cell we have a dependency on has been updated, we should
-- try and reset ourselves, but if done multiple times the same clock,
-- schedule a one-off timer
local function cell_dirty(cell)
	if cell.content_ts == CLOCK then
		if not cell.got_timer then
			cell.got_timer = true
			timer_add_periodic(tostring(cell), 1, true,
				function()
					cell.got_timer = false
					cell_dirty(cell)
				end
			)
		end
-- might want to block this if we have a dependency on external processes
	elseif cell.reset then
		cell:reset()
	end
end

local factory = system_load("cells/shared/input.lua")()

local function build_table(cell, vtable, symbol, prefix, rest, lfun, arg)
-- in most contexts both a symbol and a function is a possible candidate,
-- but it is not until we get the F( that the symbol actually becomes a
-- function and then we are in a different evaluation scope
	local syms = cell.row.wm:all_cells_id()
	local st = table.linearize(vtable, false, symbol)
	for _, v in ipairs(syms) do
		table.insert(st, v)
	end
	table.sort(st, function(a, b) return a[1] <= b[1]; end)

	local list = {}

-- There is a problem with these when there is a dependency to previous arguments,
-- as those might only be resolved through execution, at most we can have part of
-- the handler in the returned popup that, if triggered, this state is committed
-- until help reset or something.
	if lfun and lfun.type_helper and lfun.type_helper[arg] then
		local th = lfun.type_helper[arg]
		if type(th) == "function" then
			th = th()
		end
		if type(th) == "table" then
			for _,v in ipairs(th) do
				table.insert(list, {
					label = v, active = true,
					handler = function()
						cell:force_str(string.format("%s\"%s\"%s", prefix, v, rest))
					end
				})
			end
		end
	end

-- last iteration, actually build the updated menu based on prefix, could/should
-- probably filter the results based on type (if known) as well
	for _,v in ipairs(st) do
		if string.starts_with(string.upper(v[1]), string.upper(symbol)) then
			table.insert(list, {
				label = v[1], active = true,
				handler = function()
					cell:force_str(prefix .. v[1] .. rest)
				end
			})
-- clamp the number of results until the popup ui component can do scrolling
			if #list > 20 then
				table.insert(list, {label = "...", active = false, handler = function() end})
				break
			end
		end
	end

	return list
end

local function build_help(fcall, arg_ind)
	local raw =
	{
		"\\#ffffff\\i", fcall.help,
		"\\!i\\!b\\n\\r", "(",
	}

-- recall fcall.args[1] is return type
	for i=2, #fcall.args do
		local fmt = "\\!b"
		local col = "\\#ffffff"
		local arg_n = i - 1

-- non-required arguments get a darker color
		if arg_n > fcall.argc then
			col = "\\#aaaaaa"
		end

-- the current argument gets a highlight color
		if arg_n == arg_ind then
			fmt = "\\b"
			col = "\\#00ff00"
		end

-- convert type to args
		local lbl
		if fcall.args[i] == types.VARARG then
			lbl = "..."

			if arg_ind >= arg_n then
				fmt = "\\b"
				col = "\\#00ff00"
			end

-- default to a type to string mapping
		else
			lbl = type_strtbl[fcall.args[i]]
		end

		local name = ""

-- add names if we can
		if fcall.names and fcall.names[i - 1] then
			name = fcall.names[i - 1].."="
		end

		table.insert(raw, fmt .. col)
		table.insert(raw, string.format("%s%s%s", name, lbl, i<#fcall.args and ", " or ""))
	end

	table.insert(raw, "\\#ffffff")
	table.insert(raw, ")")

	return {raw = raw}
end

local function update_completion(cell, new, last, caret)
-- pick expression namespace by default (no selector for symbol space)
	if not cell.popup and not cell.show_help then
		return
	end

	local old_scope = eval_scope
	eval_scope = {
		cell = cell.eval_proxy and cell.eval_proxy or cell,
		row = cell.row,
		wm = cell.row.wm
	}

	local vtable = vtables.expression
	local mode = string.sub(caret, 1, 1)

	if namespaces[mode] then
		vtable = vtables[namespaces[mode]]
		caret = string.sub(caret, 2)
	else
		mode = ""
	end

	if cell.force_ns and namespaces[cell.force_ns] then
		vtable = vtables[namespaces[cell.force_ns]]
	end

-- we run parsing and mostly assume it will fail and by doing so we will
-- get the failing token and possible the last symbol-lookup and function
-- lookup after that to filter and show argument helpers
	local last_ent, last_fun
	local fail, fail_ind, fail_fun
	local tokens = {}

	parse(
		caret,
		function(name, dtype, alt)
			last_fun = nil
			last_ent = name
			return cell_symbol(cell, name, dtype, alt)
		end,
		function(name)
			last_ent = name
			last_fun = name
			return expose_func(cell, vtable, name)
		end,
		function(err, ofs, msg, nargs, sfun)
-- might want to give some error feedback immediately as highlight?
-- otherwise this helps to figure out how many arguments we have passed
			fail = ofs
			fail_ind = nargs
			fail_fun = sfun
		end,
		tokens
	)

-- the last two symbols should be the completion target and end marker
	local lt = tokens[#tokens]
	local ind = fail_fun or (lt and (lt[1] == types.FCALL or lt[1] == types.SYMBOL) and lt[2])

	if not ind and cell.last_help_ind then
		ind = cell.last_help_ind[1]
		fail_ind = cell.last_help_ind[2]
	end
	fail_ind = fail_ind and fail_ind or 0

-- if we get lexer error after a function scope error, assume that the
-- last set of error states still apply (my_function("now <-- that one will fit this
	if (cell.show_help) then
		local menu = {}

		if vtable[ind] then
			menu[1] = build_help(vtable[ind], fail_ind + 1)
			cell.last_help_ind = {ind, fail_ind}
		end

		if #menu > 0 then
			if cell.show_help.replace then
				cell.show_help:replace(menu)
				hide_image(cell.show_help.cursor)
			else
				cell.show_help = pipeworld_popup_spawn(menu,
					true, cell.caret, ANCHOR_UL, {
						animation_in = 1, animation_out = 1,
						inv_y = -4, mouse_block = true
				})
				hide_image(cell.show_help.cursor)
			end
		elseif cell.show_help.replace then
			cell.show_help:replace({})
		end
	end

	if not cell.popup then
		eval_scope = old_scope
		return
	end

-- figure out the string up until the lexeme we build the helper for, this
-- is different if we are partially through a symbol or completing into a
-- fresh argument as part of function calls
	local prefix = mode .. caret
	local suffix = ""
	local sym = ""

	if lt then
		if lt[1] == types.SYMBOL then
			prefix = mode .. string.sub(caret, 1, lt[3] - #lt[2] - 1)
			suffix = string.sub(new, #caret + 1 + #mode)
			sym = lt[2]
		end
	end

	local list = build_table(cell, vtable, sym, prefix, suffix, vtable[ind], fail_ind+1)
	eval_scope = old_scope
	cell.popup:replace(list)
end

local function popup_select(popup, item)
	if not item then
		return
	end
	item:handler()
end

-- Override some controls so that we can step through history, this is
-- different based on if input is locked or not. This symbol interception
-- is provided by the input cell code, not by the text_input state machine
-- which only provides ctrl+ / metra+
local function input_symbol(cell, sym, lutsym, ch)
	if cell.popup then
		if (ch == " " or sym == "RETURN" or sym == "ENTER" or sym == "RIGHT") then
-- arrow is step selected entry, step back string length, and search until
-- the sequences align and swap in
			cell.popup:trigger()
			cell.popup = nil
			return true
		end

		if sym == "UP" then
			cell.popup:step_up()
			return true
		elseif sym == "DOWN" then
			cell.popup:step_down()
			return true
		end
	end

	if sym == "F1" then
		if cell.show_help then
			cell.show_help:cancel()
			cell.show_help = nil
		else
			cell.show_help = { cancel = function() end }
			local self = cell.last_str
			cell.last_str = nil
			cell:force_str(self)
		end
		return true

	elseif sym == "TAB" then
		if cell.input_locked then
			if not cell.content or type(cell.content[1]) ~= "number" then
				return
			end

			cell.format_index = cell.format_index + 1
			if cell.format_index > #cell.number_formats then
				cell.format_index = 1
			end

			local nf = cell.number_formats[cell.format_index]
			cell:update_label(nf.process(cell.content[1]))
			cell.title = nf.label .. (cell.expression and cell.expression or "")
			cell.row:invalidate()

-- popup positioning does not respect screen boundaries, it just anchors to
-- the cursor itself - might need an option for that
		elseif not cell.popup then
			cell.popup = pipeworld_popup_spawn(
				{{label = "Temp"}}, true, cell.caret, ANCHOR_LL,
				{animation_in = 1, animation_out = 1}
			)

-- force 'text_changed' invocation by setting us to ourselves, the fastest
-- way to get all the arguments out of the input state machine
			local self = cell.last_str
			cell.last_str = nil
			local pos = cell.readline.caretpos
			cell:force_str(self)
			local pos = cell.readline:caret_set(pos)
		else
			drop_popup(cell)
		end

		return true
	elseif sym == "ESCAPE" then
		drop_popup(cell)

		if cell.input_locked then
			cell:set_state("inactive")
			cell.title = "(edit) " .. (cell.expression and cell.expression or "")
			cell.row:invalidate()
		end
		return false
	end
end

-- retain a result history as well so that we can eventually graph
-- the contents (or show as list 'below' as they accumulate due to
-- other cells updating or user manually changing.
local function add_result(cell, val)
	if not val or (type(val) == "string" and #val == 0) then
		return
	end

	table.insert(cell.results, val)
	if #cell.results > cell.results_cap then
		table.remove(cell.results, 1)
	end
end

local function pnumf(val, div)
	if val == 0 then
		return "0"
	end
	val = val / div
	local a, b = math.modf(val)
	if b == 0.0 then
		return tostring(a)
	else
		return string.format("%.4f", val)
	end
end

return
function(row, cfg, preset, commit, ns)

-- derive from the 'input' cell template and add hooks to manage evaulation,
-- completion, history and state
	local cell = factory("expression", row, cfg)

	cell.lookup_cache = {}
	cell.update_listeners = {}
	cell.commit = mode_check
	cell.force_ns = ns
	cell.title = "(edit) "
	cell.symbol_input = input_symbol

-- this should probably be better controlled
	cell.add_result = add_result
	cell.results_cap = 100
	cell.results = {}

	cell:set_state("inactive")

-- use TAB to step through formatting, these should really be exposed
-- as a menu as well so that a larger set or the stepping order can be
-- controlled as this grows
	cell.number_formats = {
		{
			label = "(.4f) ",
			name = "float_lim",
			process = function(v)
				return string.format("%.4f", v)
			end,
		},
		{
			label = "(f) ",
			name = "float",
			process = function(v)
				return string.format("%f", v)
			end,
		},
		{
			label = "(0x) ",
			name = "hex",
			process = function(v)
				local i, _ = math.modf(v)
				return string.format("%x", i)
			end
		},
		{
			label = "(dec) ",
			name = "decimal",
			process = function(v)
				return string.format("%d", v)
			end
		},
		{
			label = "(KiB) ",
			name = "kilobytes",
			process = function(v)
				return pnumf(v, 1024)
			end,
		},
		{
			label = "(MiB) ",
			name = "megabytes",
			process = function(v)
				return pnumf(v, 1024 * 1024)
			end,
		},
		{
			label = "(GiB) ",
			name = "gigabytes",
			process = function(v)
				return pnumf(v, 1024 * 1024 * 1024)
			end,
		}
	}
	cell.format_index = 1

-- called when a cell we depend on in an expression has changed
	cell.dirty_update = cell_dirty
	cell.text_changed = update_completion

-- used for UI elements, when the string has changed
	cell.dirty = function(cell)
		return cell.last_str and #cell.last_str > 0
	end

-- we don't support maximize toggle / scaling for input boxes (they'd be useless)
	cell.maximize =
	function()
		cell.maximized = cell.maximized
	end

-- override the destroy so that we stop listening to other cells being updated
	local old_dest = cell.destroy
	cell.destroy =
	function(...)
		flush_lookup_cache(cell)
		return old_dest(...)
	end

	local old_uf = cell.unfocus

-- unfocus- refresh only when we don't have system/cell namespace
	cell.unfocus =
	function(...)
		old_uf(...)
		local safe_reset = cell.last_mode == nil and cell.force_ns == nil
		if safe_reset and cell.cfg.expression_unfocus_reset then
			cell:reset()
		end
	end

	if preset then
		cell:force_str(preset)
		if commit then
			mode_check(cell, preset)
		else
		end
	end

	return cell
end
