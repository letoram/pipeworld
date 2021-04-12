-- get the set of video encoder friendly output sizes from suppl.lua

local keys = {
	size = function(cell, val, opts)
		local lut = suppl_size_lut(true, true)
		if lut[val] then
			opts.width = lut[val][1]
			opts.height = lut[val][2]
			return true
		end
		cell:set_error(string.format(
			"No matching preset to %s for option key 'size'", val))
	end,
-- the different quality modes are not stable in the engine yet
	quality = function(cell, val, opts)
		return true
	end
-- other options are the layouting formula, clocking (fixed-rate, ...)
}

local function compose(fmt, ...)

-- use some kind of format string rather than trying to lock down this interface
	local list = string.split(fmt, ":")
	local cell = eval_scope.cell

	local opts =
	{
		width = 720,
		height = 480
	}

	for _, v in ipairs(list) do
		local key, val = string.split_first(v, "=")
		if keys[key] then
			if not keys[key](cell, val, opts) then
				return
			end
		else
			cell:set_error("Uknown key '" .. key .. "'")
			return
		end
	end

	return {"compose", opts, ...}
end

local function fmt_helper(instr)
-- split into opts, remove the helpers that have a matching key already
	return {
		"quality={default,fp16,565}",
		"size={480p,720p,1080p,4k}",
		"policy={ro_bin,rw_bin}"
	}
end

return function(types)
	return {
		handler = compose,
		args = {types.FACTORY, types.STRING, types.VIDEO, types.VARARG},
		type_helper = {fmt_helper},
		name = {"options", "source"},
		argc = 2,
		help = "Create a composition cell out of one or many video inputs.",
	}
end
