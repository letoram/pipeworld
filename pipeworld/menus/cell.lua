return
function(ctx, row, cell)
	local lst = {
		{
			label = "Reset Cell", command = "/reset/cell"
		},
		{
			label = "Destroy Cell", command = "/delete/cell"
		},
		{
			label = "Revert to Expression", command = "/revert/cell"
		},
		{
			label = "Modify Cell", command = "/cursor/cellexpr"
		},
		{
			label = "Scale...", command = "/popup/cell_scale_menu"
		},
	}

	if cell.name == "cli" then
		if not cell.insert_vertical then
		table.insert(lst, {
			label = "Children as new Row",
			command = "/cli/child_vertical"
		})
		else
			table.insert(lst, {
				label = "Children as new Column",
				command = "/cli/child_horizontal"
			})
		end
	end

	if valid_vid(cell.vid, TYPE_FRAMESERVER) then
		table.insert(lst, {
			label = "Size Hint...",
			command = "/popup/cell_hint_menu"
		})

		for _,v in pairs(cell.input_labels) do
			table.insert(lst, {
				label = "Input Labels...",
				command = "/popup/cell_label_menu"
			})

			break
		end
	end

	return lst
end
