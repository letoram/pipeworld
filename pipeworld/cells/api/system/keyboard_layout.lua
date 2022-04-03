local function run_action(verb, ...)
	local ok
	local id = -1
	repeat
		ok = input_remap_translation(id, verb, ...)
		id = id - 1
	until not ok
end

local function layout(layout, variant, options, model)
	if not layout then
		run_action(TRANSLATION_CLEAR)
		return
	end

	variant = variant and variant or ""
	model = model and model or ""
	options = options and options or ""

	run_action(TRANSLATION_SET, layout, model, variant, options)
end

return function(types)
	return {
		handler = layout,
		args = {types.NIL, types.STRING, types.STRING, types.STRING, types.STRING},
		names = {"layout", "variant", "model", "options"},
		type_helper = {},
		argc = 1,
		help = "Create a debug cell from a reference."
		}
end
