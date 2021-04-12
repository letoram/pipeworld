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

	eval_scope.cell.force_color = {r, g, b}
	return res
end

return function(types)
	return {
		handler = build_color,
		args = {types.NIL, types.NUMBER, types.NUMBER, types.NUMBER},
		argc = 3,
		names = {"red", "green", "blue"},
		help = "Change the active border color.",
		type_helper = {},
	}
end
