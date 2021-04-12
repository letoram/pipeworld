local function capture(id, opts)

-- numbers will coalesce to strings, so we can try and convert back
	if id ~= nil and tonumber(id) ~= nil then
		id = tonumber(id)
	end

	return {"capture", id, opts}
end

return function(types)
	return {
		handler = capture,
		args = {types.FACTORY, types.STRING, types.STRING},
		names = {"id", "options"},
		type_helper = {},
		argc = 0,
		help = "Open a video capture device."
	}
end
