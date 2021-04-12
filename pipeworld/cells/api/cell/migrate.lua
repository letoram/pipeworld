local function handler(main, fallback)
	local cell = eval_scope.cell
	if not valid_vid(cell.vid, TYPE_FRAMESERVER) then
		cell:set_error("Cell source does not refer to a valid external client.")
		return
	end

-- fallback first as setting a main will migrate immediately
	if fallback and #fallback > 0 then
		target_devicehint(cell.vid, fallback)
	end

	if #main > 0 then
		target_devicehint(cell.vid, main, true)
	end
end

return function(types)
	return {
		handler = handler,
		args = {types.NIL, types.STRING, types.STRING},
		names = {"main", "fallback"},
		argc = 1,
		help = "Ask the backing client to migrate somewhere else",
		type_helper = {"connection_point", "connection_point"}
	}
end
