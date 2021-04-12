local function calc_min(...)
	local arg = {...}
	local min = arg[1]

	for i=2,#arg do
		if arg[i] < min then
			min = arg[i]
		end
	end

	return min
end

return function(types)
	return {
		handler = calc_min,
		args = {types.NUMBER, types.NUMBER, types.VARARG},
		argc = 1,
		help = "Returns the lowest value among the supplied arguments",
		type_helper = {"number"}
	}
end
