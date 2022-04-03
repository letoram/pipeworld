local function pxhint(cell, w, h)
	cell.hint_factor[1] = 1
	cell.hint_factor[2] = 1

-- fake swap in and re-run hinting
	local ow = cell.fsrv_size[1]
	local oh = cell.fsrv_size[2]
	cell.fsrv_size[1] = w
	cell.fsrv_size[2] = h

	cell:rehint()

-- need to reset and wait so that input scaling and so on still applies
	cell.fsrv_size[1] = ow
	cell.fsrv_size[2] = oh
end

return
function(ctx, row, cell)
	local res = {}
	local media = false
	local graphical = false
	local list = table.linearize(suppl_size_lut(graphical, media))
	local mod_w = 1
	local mod_h = 1

	if cell.name == "terminal" or cell.name == "tui" or cell.name == "cli" then
		mod_w = cell.fonthint_wh[1]
		mod_h = cell.fonthint_wh[2]
	end

	table.sort(
		list,
		function(a, b)
			return a[2][1] * a[2][2] <= b[2][1] * b[2][2]
		end
	)

	for _,v in ipairs(list) do
		v.label = v[1]
		v.handler = function()
			pxhint(cell, v[2][1] * mod_w, v[2][2] * mod_h)
		end
	end

	return list
end
