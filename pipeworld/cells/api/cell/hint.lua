local function handler(w, h)
	local cell = eval_scope.cell
	cell.hint_factor[1] = w
	cell.hint_factor[2] = h
	cell:rehint()
end

return function(types)
	return {
		handler = handler,
		args = {types.NIL, types.NUMBER, types.NUMBER},
		argc = 2,
		names = {"fact_w", "fact_h"},
		help = "Change the cell content size hint multiplier.",
		type_helper = {"identifier"}
	}
end
