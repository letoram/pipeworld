local function debugfn(cp, builtin)
	return {"debug", cp, builtin}
end

return function(types)
	return {
		handler = debugfn,
		args = {types.FACTORY, types.VIDEO, types.BOOLEAN},
		names = {"target", "builtin"},
		type_helper = {},
		argc = 0,
		help = "Create a debug cell from a reference."
		}
end
