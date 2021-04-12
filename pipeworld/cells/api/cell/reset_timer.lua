local counter = 0

local function set_timer(val)
	local cell = eval_scope.cell

	if val < 0 then
		cell:set_error("reset timer must be >= 0")
		return
	end

	local drop_timer = function()
		if not cell.timers then
			return
		end

		local tn = cell.plugin_store.reset_timer_name
		if tn then
			cell.plugin_store.reset_timer_name = nil
			timer_delete(tn)
			table.remove_match(cell.timers, tn)
		end
	end

-- always remove current timer
	drop_timer()

	if not cell.reset then
		cell:set_error("cell type does not implement 'reset'")
		return
	end

-- nop
	if val == 0 then
	end

-- the resolution is quite poor here, but our logic clock is only ~25Hz
	local ntick = math.ceil(val / CLOCKRATE)
	counter = counter + 1


	local name = cell.name .. "_expr_" .. counter
	timer_add_periodic(name, ntick, false, function()
		if cell.reset then
			cell:reset()
		else
			drop_timer()
		end
	end, false)
	table.insert(cell.timers, name)
	cell.plugin_store.reset_timer_name = name
end

return function(types)
	return {
		handler = set_timer,
		args = {types.NIL, types.NUMBER},
		argc = 1,
		names = {"delay_ms"},
		help = "Set the cell to reset periodically.",
		type_helper = {"0 = disable"},
	}
end
