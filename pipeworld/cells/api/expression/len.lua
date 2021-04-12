local function calc_len(a)
	return #a
end

return function(types)
	return {
		handler = calc_len,
		args = {types.NUMBER, types.STRING},
		argc = 1,
		help = "Returns the length of the supplied string",
		type_helper = {},
	}
end
