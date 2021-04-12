local function open_cp(cp, limit)
	return {"listen", cp, limit}
end

return function(types)
	return {
		handler = open_cp,
		args = {types.FACTORY, types.STRING, types.NUMBER},
		type_helper = {}, -- cp-helper (not-in use, valid string), number- (min-max range?)
		argc = 1,
		help = "Setup a named listening connection"
		}
end
