local function autodel(state)
	eval_scope.cell.row.autodelete = state
end

return function(types)
	return {
		handler = autodel,
		args = {types.NIL, types.BOOLEAN},
		argc = 1,
		names = {},
		help = "Automatically destroy any cell on the row where its external client terminates.",
		type_helper = {},
	}
end
