local function gen_rnd(a, b)
	if a >= b then
		eval_scope.cell:set_error("(1:low) should be less than (2:high)")
		return
	end

	return math.random(a, b)
end

return function(types)
	return {
		handler = gen_rnd,
		args = {types.NUMBER, types.NUMBER, types.NUMBER},
		argc = 2,
		names = {
			low = 1,
			high = 2
		},
		help = "Return a random number between (low, high)",
		type_helper = {}
	}
end
