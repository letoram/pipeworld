local function set_scheme(scheme)
	local cell = eval_scope.cell
	if not valid_vid(cell.vid, TYPE_FRAMESERVER) then
		cell:set_error("cell has no external client")
		return
	end

	local ok, msg = pipeworld_send_colors(cell, scheme)
	if not ok then
		cell:set_error(msg)
	end
end

return function(types)
	return {
		handler = set_scheme,
		args = {types.NIL, types.STRING},
		argc = 1,
		names = {"scheme"},
		help = "Change the client-active color scheme.",
		type_helper = {},
	}
end
