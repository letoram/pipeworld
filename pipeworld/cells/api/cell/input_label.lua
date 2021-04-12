local function input_label(label)
	label = string.upper(label)
	local cell = eval_scope.cell

	if not valid_vid(cell.vid, TYPE_FRAMESERVER) then
		cell:set_error("Cell source does not refer to a valid external client.")
		return
	end

	if not (cell.input_labels[label]) then
		cell:set_error("Cell has not announced label '" .. label .. "'")
		return
	end

	target_input(cell.vid, {
		kind = cell.input_labels[label].datatype,
		translated = true,
		label = label,
		active = true,
		subid = 0,
		devid = 0
	})
end

local function get_label_set(cell)
	local res = {}
	for k,_ in pairs(cell.input_labels) do
		table.insert(res, k)
	end
	table.sort(res)
	return res
end

return function(types)
	return {
		handler = input_label,
		args = {types.NIL, types.STRING},
		names = {},
		argc = 1,
		help = "Trigger a client announced digital input.",
		type_helper = {get_label_set},
	}
end
