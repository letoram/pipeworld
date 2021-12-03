return
function()
	return
	{
		{
			label = "Expression", command = "/insert/row/expression"
		},
		{
			label = "Terminal", command = "/insert/row/terminal"
		},
		{
			label = "Command-Line", command = "/insert/row/cli"
		},
		{
			label = "Target...", command = "/popup/row_target_menu",
			eval =
			function()
				return #list_targets() > 0
			end
		}
	}
end
