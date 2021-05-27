local function linktoggle(state)
	eval_scope.cell.row:toggle_linked(state)
end

return function(types)
	return {
		handler = linktoggle,
		args = {types.NIL, types.BOOLEAN},
		argc = 0,
		names = {
			state = 1,
		},
		help = "Set/toggle the row anchor link status flag for this row and its children.",
		type_helper = {},
	}
end
