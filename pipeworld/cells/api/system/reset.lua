return function(types)
	return {
		handler = system_collapse,
		args = {types.NIL, types.STRING, types.BOOLEAN},
		argc = 0,
		names = {"appl", "skip_adopt"},
		help = "Reload Pipeworld or switch Arcan application.",
		type_helper = {
			function()
				return glob_resource("*", SYS_APPL_RESOURCE)
			end
		}
	}
end
