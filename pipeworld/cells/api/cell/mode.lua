local function tag_cell(tag)
	if tag == "mutate" or tag == "new_cell" or tag == "new_row" then
		eval_scope.cell.expression_factory = tag
	else
		eval_scope.cell:set_error("mode: unknown mode '" ..tag .. "'")
		return
	end
end

return function(types)
	return {
		handler = tag_cell,
		args = {types.NIL, types.STRING},
		argc = 1,
		help = "Change cell spawn mode.",
		names = {"tag"},
		type_helper = {"strset"},
		strset = {"mutate", "new_cell", "new_row"}
	}
end
