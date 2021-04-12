local function sample_image(ref, w, h, shname)
	local v = ref:export_content("video_buffer_handle")

	if not v or not valid_vid(v) then
		eval_scope.cell:set_error("Referenced cell failed to export a valid image source.")
		return
	end

-- ok, need to resample into our snapshot, calculate size based on aspect ratio
	local props = image_storage_properties(v)

	if not w or w <= 0 then
		if h and h > 0 then
			w = h * (props.width / props.height)
		else
			w = props.width
		end
	end

	if not h or h <= 0 then
		h = w * (props.height / props.width)
	end

	w = math.clamp(w, 32, MAX_SURFACEW)
	h = math.clamp(h, 32, MAX_SURFACEH)

-- alloc intermediate and apply shader
	res = alloc_surface(w, h)
	if not valid_vid(res) then
		eval_scope.cell:set_error("Couldn't allocate/build new image buffer.")
		return
	end
	resample_image(v, shname and shname or "DEFAULT", w, h, res)

-- forward to image cell factory
	return {"image", res}
end

local function list_shaders()
	return shader_list()
end

return function(types)
	return {
		handler = sample_image,
		args = {types.FACTORY, types.CELL, types.NUMBER, types.NUMBER, types.STRING},
		argc = 1,
		names = {"source", "width", "height", "shader"},
		help = "",
		type_helper = {nil, nil, nil, list_shaders},
	}
end
