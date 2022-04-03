local function strrep(str, times)
	return string.rep(str, times)
end

return function(types)
	return {
		handler = strrep,
		args = {types.STRING, types.STRING, types.NUMBER},
		names = {"input", "count"},
		argc = 2,
		help = "Repeat text input a fixed number of times",
		type_helper = {}
	}
end
