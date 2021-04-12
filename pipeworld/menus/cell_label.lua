return
function(ctx, row, cell)
	local res = {}

-- sort based on the label itself
	local labels = {}
	for k, v in pairs(cell.input_labels) do
		table.insert(labels, v)
	end
	table.sort(labels, function(a, b) return a.labelhint <= b.labelhint; end)

-- then show short description with vsym and keysym, long with help
	for _, v in ipairs(labels) do
		local shortcut = ""
		local symname = row.cfg.keyboard[v.initial]
		if symname then
			shortcut = decode_modifiers(v.modifiers, " ") .. symname
		end

		table.insert(res, {
			label = v.labelhint,
			hint = v.description,
			shortcut = shortcut,
			prefix = v.vsym,
			handler = function()
				if not valid_vid(cell.vid) then
					return
				end

				target_input(cell.vid, {
					kind = v.datatype,
					translated = true,
					label = v.labelhint,
					active = true,
					subid = 0,
					devid = 0
				})
			end,
-- shortcut?
		})
	end

	return res
end
