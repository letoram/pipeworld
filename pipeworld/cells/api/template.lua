local function template_function(...)
	local arg = {...}
	local max = arg[1]

	if arg[1] == 10 then
		eval_scope.cell:set_error("10 is not a proper number")
		return
	end

	for i=2,#arg do
		if arg[i] > max then
			max = arg[i]
		end
	end

	return max
end

function arg1_helper()
	return {"1", "3", "5"}
end

return function(types)
	return {
		handler = template_function,
-- this defines a function that returns a number (first entry) and takes a
-- variable count of number arguments
		args = {types.NUMBER, types.NUMBER, types.VARARG},

-- the number of 'minimum' arguments when variable argument counts are permitted
		argc = 1,

-- these will be used a prefix to the type in the help string
		names = {"argument_1", "argument_2", "extras"},

-- the help string is used for tab-completion/hover description
		help = "Returns the highest value among the supplied arguments",

-- type-helper is for finding possible completion sources, e.g. colour pickers,
-- dictionaries and so on.
		type_helper = {arg1_helper}
	}
end
