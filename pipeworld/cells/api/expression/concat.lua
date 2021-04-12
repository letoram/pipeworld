local function concat_function(...)
	local arg = {...}
	return table.concat(arg)
end

return function(types)
	return {
		handler = concat_function,
		args = {types.STRING, types.STRING, types.VARARG},
		argc = 2,
		help = "Concatenate strings",
		type_helper = {}
	}
end
