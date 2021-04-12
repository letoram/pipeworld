local function autodel(state)
	eval_scope.cell.autodelete = state
end

return function(types)
	return {
		handler = autodel,
		args = {types.NIL, types.BOOLEAN},
		argc = 1,
		names = {},
		help = "Automatically destroy cell if external client terminates.",
		type_helper = {},
	}
end
