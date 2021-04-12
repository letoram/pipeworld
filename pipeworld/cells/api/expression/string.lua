local function string(instr)
	return instr
end

return function(types)
	return {
		handler = string,
		args = {types.STRING, types.STRING},
		argc = 1,
		help = "Copy or convert a reference or literal to a string",
		type_helper = {},
	}
end
