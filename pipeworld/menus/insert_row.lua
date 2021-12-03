return
function()
	return
	{
		{
			label = "Expression", command = "/append/row/expression"
		},
		{
			label = "Terminal", command = "/append/row/terminal"
		},
		{
			label = "Command-Line", command = "/append/row/cli"
		},
		{
			label = "Target...", command = "/popup/target_menu",
			eval =
			function()
				return #list_targets() > 0
			end
		}
	}
end
