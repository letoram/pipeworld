local function build_color(r, g, b)
	if not r then
		r = 0
	end

	if not g then
		g = 0
	end

	if not b then
		b = 0
	end

	local res = fill_surface(32, 32, r, g, b)
	if not res then
		return BADID
	end
	return {"image", res}
end

return function(types)
	return {
		handler = build_color,
		args = {types.FACTORY, types.NUMBER, types.NUMBER, types.NUMBER},
		names = {"red", "green", "blue"},
		argc = 3,
		help = "Returns a single color cell.",
		type_helper = {},
	}
end
