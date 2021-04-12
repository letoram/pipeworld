return
function(types)
	return {
		handler = shutdown,
		args = {types.NIL},
		argc = 0,
		help = "Shutdown Pipeworld immediately.",
		type_helper = {}
	}
end
