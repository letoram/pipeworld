local function reverse(str)
	local lst = {}
	local pos = 1
	local len = #str

	while true do
		local step = string.utf8forward(str, pos)
		table.insert(lst, 1, string.sub(str, pos, step-1))
		if step == pos then
			break
		end
		pos = step
	end

	return table.concat(lst, "")
end

return function(types)
	return {
		handler = reverse,
		args = {types.STRING, types.STRING},
		names = {},
		argc = 1,
		help = "Reverse the input string.",
		type_helper = {nil}
	}
end
