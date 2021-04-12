local function wallpaper(fn)
	local wm = eval_scope.wm
	if type(fn) == "string" then
		local func = wm.cmdtree["/wallpaper/set"]
		if func then
			func(wm, fn)
		end
	end
end

return
function(types)
	return {
		handler = wallpaper,
		args = {types.NIL, types.VARTYPE},
		names = {},
		argc = 1,
		help = "Change wallpaper.",
		type_helper = {}
	}
end
