return
function()
	local res = {}
	for _,v in ipairs(list_targets()) do
		local cfg = target_configurations(v)
		if #cfg > 1 then
			for _, cfg in ipairs(cfg) do
				table.insert(res, {
					label = v .. "(" .. cfg .. ")",
					command = {"/insert/row/target", v, cfg}
				})
			end
		else
			table.insert(res, {
				label = v,
				command = {"/insert/row/target", v}
			});
		end
	end

	return res
end
