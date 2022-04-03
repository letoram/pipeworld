local function paste_cell(str)
	local cell = eval_scope.cell

	if not cell.paste then
		cell:set_error("Cell source does not refer to a valid external client.")
		return
	end

	cell:paste(str)
end

return function(types)
	return {
		handler = paste_cell,
		args = {types.NIL, types.STRING},
		argc = 1,
		names = {"text"},
		help = "send text/plain message to cell clipboard",
		type_helper = {nil}
	}
end
