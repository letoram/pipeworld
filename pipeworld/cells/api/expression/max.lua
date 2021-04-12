local function calc_max(...)
	local arg = {...}
	local max = arg[1]

	for i=2,#arg do
		if arg[i] > max then
			max = arg[i]
		end
	end

	return max
end

return function(types)
	return {
		handler = calc_max,
		args = {types.NUMBER, types.NUMBER, types.VARARG},
		argc = 1,
		help = "Returns the highest value among the supplied arguments",
		type_helper = {}
	}
end
