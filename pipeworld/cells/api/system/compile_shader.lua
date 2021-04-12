local function compile(name, frag, vert)
	if not frag or #frag == 0 then
		frag = nil
	end

	if not vertex or #vertex == 0 then
		vertex = nil
	end

-- the shader compiler interface  is asynch, right now we can't get any
-- decent error message back - a shader_status arcan-lua function is missing.
	build_shader(vert, frag, name)
end

return
function(types)
	return {
		handler = compile,
		args = {types.NIL, types.STRING, types.STRING, types.STRING},
		argc = 2,
		names = {"name", "fragment", "vertex"},
		help = "Compile a new GPU processing program (shader) and bind to a name.",
		type_helper = {}
	}
end
