local function snapshot(fn)
	if resource(fn, APPL_RESOURCE) then
		zap_resource(fn, APPL_RESOURCE)
	end

	system_snapshot(fn)
end

return
function(types)
	return {
		handler = snapshot,
		args = {types.NIL, types.STRING},
		argc = 1,
		names = {"filename"},
		help = "Create a system state dump for debugging",
		type_helper = {}
	}
end
