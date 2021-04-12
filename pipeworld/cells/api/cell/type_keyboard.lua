local timer_count = 1

local function delay_for_model(model)
	if model == "fast" then
		return 2
	elseif model == "medium" then
		return 8
	else
		return 16
	end
end

local function type_cell(str, model)
	local cell = eval_scope.cell

	if not model then
		model = "medium"
	end

	if not valid_vid(cell.vid, TYPE_FRAMESERVER) then
		cell:set_error("Cell source does not refer to a valid external client.")
		return
	end

-- These will fight eachother and lack cancellation - we could expose it as
-- different keyboards, but few clients care about that. The other is to have
-- one 'type timer' and queue the typing table.
--
-- Another problem is that the synthesis currently does not take a client keymap
-- into account, we just assume the client uses the utf8 field, and not all of
-- them do.
	local tbl = suppl_string_to_keyboard(str, cell.cfg.keyboard)
	assert(#tbl % 2 == 0)

	local name = "cell_api_timer_" .. tostring(timer_count)
	timer_count = timer_count + 1

-- plan is for model to also support typos and more randomized delays and a
-- learning mode, but first the keymap translation issues need to be smoothed
-- over
	timer_add_periodic(name, delay_for_model(model), false,
		function()
			if valid_vid(cell.vid, TYPE_FRAMESERVER) and #tbl > 0 then
				local input = table.remove(tbl, 1)
				target_input(cell.vid, input)
				input = table.remove(tbl, 1)
				target_input(cell.vid, input)
			else
				timer_delete(name)
			end
		end,
		true
	)
end

return function(types)
	return {
		handler = type_cell,
		args = {types.NIL, types.STRING, types.STRING},
		argc = 1,
		names = {"text", "speed"},
		help = "Type a string into the cell through simulated keypresses.",
		type_helper = {nil, {"slow", "medium", "fast"}},
	}
end
