local function build_target(tgt, cfg)
	return {"target", tgt, cfg}
end

local function tgt_helper(state, intgt)
	return list_targets()
end

local function cfg_helper(state, incfg)
-- interesting, need to populate eval_scope with tgt_helper
-- in order for this one to list_configurations
	return {}
end

return function(types)
	return {
		handler = build_target,
		args = {types.FACTORY, types.STRING, types.STRING},
		argc = 1,
		names = {"target", "config"},
		help = "Launch a named external target.",
		type_helper = {tgt_helper, cfg_helper}
	}
end
