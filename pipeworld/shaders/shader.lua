--
-- simplified version of the one in durden
--
-- still rather old and murky and well within the rights of a redesign
-- when it comes to ugroups, uniform invalidations, settings persistance
-- and the likes
--

local names = {}

if (SHADER_LANGUAGE == "GLSL120") then
local old_build = build_shader;
function build_shader(vertex, fragment, label, internal)
	vertex = vertex and ("#define VERTEX\n" .. vertex) or nil;
	fragment = fragment and ([[
		#ifdef GL_ES
			#ifdef GL_FRAGMENT_PRECISION_HIGH
				precision highp float;
			#else
				precision mediump float;
			#endif
		#else
			#define lowp
			#define mediump
			#define highp
		#endif
	]] .. fragment) or nil;

-- track ones being built outside of the normal shader management
	if not internal then
		names[label] = old_build(vertex, fragment, label)
		return names[label]
	else
		return old_build(vertex, fragment, label);
	end
end
end

local shdrtbl = {
	effect = {},
	ui = {},
	simple = {}
};

local groups = {"effect", "ui", "simple"};
local set_uniform;

-- currently just return the simple ones as the effect/ui may be multipass
-- and stateful, thus requiring specifics on context of use
function shader_list()
	local res = {}

	for k,_ in pairs(names) do
		table.insert(res, k)
	end

	for _,v in pairs(shdrtbl.simple) do
		table.insert(res, v.name)
	end

	table.sort(res)
	return res
end

local function load_defaults(shader, lookup)
-- this is not very robust, bad written shaders will yield fatal()
	for k,v in pairs(shader.uniforms) do
		local val = v.default

		if type(v.default) == "function" then
			val = v.default(shader)
		end

		if val == nil then
			warning("shader " .. shader.name .. " did not set a default value for " .. k)
			shader.broken = true
			return
		end

-- on-load and on-apply might both trigger this
		if lookup then
			val = lookup(shader.name, k, val, shader)
			if val then
				v.default = val
			end
		end

-- update basic shader and states (uniform groups) as well
		if shader.states then
			for l,state in pairs(shader.states) do
				local vl = val

				if state.uniforms[k] then
					vl = state.uniforms[k]
				end
				if state.shid then
					set_uniform(state.shid, k, v.utype, val, "loader" .. "-state-" .. k);
				end
			end
		end

		if shader.shid then
			set_uniform(shader.shid, k, v.utype, val, "loader" .. "-" .. k);
		end
	end
end

local function shdrmgmt_scan(lookup_fn)
 	for a,b in ipairs(groups) do
 		local path = string.format("shaders/%s/", b);

		for i,j in ipairs(glob_resource(path .. "*.lua", APPL_RESOURCE)) do
			local res = system_load(path .. j, false);
			if (res) then
				res = res();
				if (not res or type(res) ~= "table" or res.version ~= 1) then
					warning("shader " .. j .. " failed validation");
				else
					local key = string.sub(j, 1, string.find(j, '.', 1, true)-1);
					shdrtbl[b][key] = res;
				end
		else
				warning("error parsing " .. path .. j);
 			end
		end
	end

-- and rebuild default uniform values, this will reset any user customization
	for gname, group in pairs(shdrtbl) do
		for name, shader in pairs(group) do
			shader.name = gname .. "_" .. name;
			load_defaults(shader, lookup_fn)
		end
	end
end

shdrmgmt_scan();

set_uniform =
function(dstid, name, typestr, vals, source)
	local len = string.len(typestr);
	if (type(vals) == "table" and len ~= #vals) or
		(type(vals) ~= "table" and len > 1) then
		warning("set_uniform called from broken source: " .. source);
 		return false;
	end
	if (type(vals) == "table") then
		shader_uniform(dstid, name, typestr, unpack(vals));
 	else
		shader_uniform(dstid, name, typestr, vals);
	end
	return true;
end

local function load_from_file(relp, lim, defs)
	local res = {};
	if (open_rawresource(relp)) then
		if defs then
			for k,v in ipairs(defs) do
				table.insert(res, "#define " .. v);
			end
		end

		local line = read_rawresource();
		while (line ~= nil and lim -1 ~= 0) do
			table.insert(res, line);
			line = read_rawresource();
			lim = lim - 1;
		end
		close_rawresource();
	else
		warning(string.format("shader, load from file: %s failed, EEXIST", relp));
	end

	return table.concat(res, "\n");
end

-- load the actual shader contents based on the definition,
-- this includes vertex/fragment stage from sources
-- as well as possible lookup- tables and generator functions
local function setup_shader(shader, name, group)
	if (shader.shid) then
		return true;
	end

-- ugly non-blocking read (note, this does not cover variants)
	if (not shader.vert and shader.vert_source) then
		shader.vert = load_from_file(string.format(
			"shaders/base/%s", shader.vert_source), 1000, shader.vert_defs);
	end

	if (not shader.frag and shader.frag_source) then
		shader.frag = load_from_file(string.format(
			"shaders/base/%s", shader.frag_source), 1000, shader.vert_defs);
	end

	local dvf = (shader.vert and
		type(shader.vert == "table") and shader.vert[SHADER_LANGUAGE])
		and shader.vert[SHADER_LANGUAGE] or shader.vert;

	local dff = (shader.frag and
		type(shader.frag == "table") and shader.frag[SHADER_LANGUAGE])
		and shader.frag[SHADER_LANGUAGE] or shader.frag;

	shader.shid = build_shader(dvf, dff, shader.name, true);
	if (not shader.shid) then
		shader.broken = true;
		warning("building shader failed for " .. group.."_"..name);
		return false;
	end

	load_defaults(shader)
	return true;
end

local function filter_strnum(fltstr)
	if (fltstr == "bilinear") then
		return FILTER_BILINEAR;
	elseif (fltstr == "linear") then
		return FILTER_LINEAR;
	else
		return FILTER_NONE;
	end
end

local function ssetup(shader, dst, group, name, state)
	if (not shader.shid) then
		setup_shader(shader, name, group);

-- states inherit shaders, define different uniform values
		if (shader.states) then
			for k,v in pairs(shader.states) do
				v.shid = shader_ugroup(shader.shid);

				for i,j in pairs(v.uniforms) do
					set_uniform(v.shid, i, shader.uniforms[i].utype, j,
						string.format("%s-%s-%s", name, k, i));
				end
			end
		end
	end

-- now the shader exists, apply
	local shid = ((state and shader.states and shader.states[state]) and
		shader.states[state].shid) or shader.shid;

	if (valid_vid(dst)) then
		image_shader(dst, shid);
	end

	return shid;
end

local function esetup(shader, dst, name)
	if (not shader.passes or #shader.passes == 0) then
		return;
	end

	if (#shader.passes == 1 and shader.no_rendertarget) then
		return ssetup(shader.passes[1], dst, name);
	end

-- Track the order in which the rendertargets are created. This is needed as
-- each rendertarget is setup with manual update controls as a means of synching
-- with the frame delivery rate of the source.
	local rtgt_list = {};

-- the process of taking a pass description, creating an intermediate FBO
-- applying the pass shader and returning the outcome. Subtle edge conditions
-- to look out for here.
	local build_pass =
	function(invid, pass)
		local props = image_storage_properties(invid);
		local fmt = ALLOC_QUALITY_NORMAL;

		if (pass.float) then
			fmt = ALLOC_QUALITY_FLOAT16;
		elseif (pass.float32) then
			fmt = ALLOC_QUALITY_FLOAT32;
		end
		if (pass.filter) then
			image_texfilter(invid, filter_strnum(pass.filter));
		end

-- min-clamp as there's a limit for the rendertarget backend store,
-- note that scaling doesn't work with all modes (e.g. autocrop) or client types
		local outw = math.clamp(props.width * pass.scale[1], 32);
		local outh = math.clamp(props.height * pass.scale[2], 32);

		local outvid = alloc_surface(outw, outh, true, fmt);
		if (not valid_vid(outvid)) then
			return invid;
		end

-- for the passes that require lookup textures, asynch- preloaded or through
-- a function, switch the invid to a multitextured frameset and assign the slots
-- accordingly.
		local tmp_vid = null_surface(1, 1);
		if valid_vid(tmp_vid) then
			if (#pass.maps > 0) then
				image_framesetsize(invid, #pass.maps + 1, FRAMESET_MULTITEXTURE);
				for i,v in ipairs(pass.maps) do
					if type(v) == "function" then
						v(dst, tmp_vid);
					elseif valid_vid(v) then
						image_sharestorage(v, tmp_vid);
-- fallback to source store if the maps were setup wrong
					else
						image_sharestorage(dst, tmp_vid);
					end
					set_image_as_frame(pass.maps, tmp_vid, i);
				end
			end
			delete_image(tmp_vid);
		end

-- sanity checks and resource loading/preloading
		define_rendertarget(outvid, {invid},
			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);
		image_shader(invid, pass.shid);
		resize_image(invid, outw, outh);
		move_image(invid, 0, 0);
		show_image({invid, outvid});
		table.insert(rtgt_list, outvid);
		rendertarget_forceupdate(outvid);
		return outvid;
	end

-- the effect shader type is rather complex as it supports multiple
-- passes that feed into eachother, with different scaling, lookups and
-- so on between passes - that need to handle being resized and so on
local function preload_effect_shader(shdr, name)
	local ok = true

	for _,v in ipairs(shdr.passes) do
		if (not v.shid) then
			if not setup_shader(v, name) then
				v.broken = true
				ok = false
			end
		end

		if (not shdr.scale) then
			shdr.scale = {1, 1};
		end

		if (not shdr.filter) then
			shdr.filter = "bilinear";
		end

		if (not shdr.maps) then
			shdr.maps = {};
		else

-- asynch- shader lookup maps
			for i,v in ipairs(shdr.maps) do
				if (type(v) == "string") then
					if (v == ":source") then
						shdr.maps[i] = function(src)
							local surf = null_surface(1, 1);
							image_sharestorage(src, surf);
							return surf;
						end
					else
						shdr.maps[i] = load_image_asynch(
							string.format("shaders/lut/%s", v),
-- defer shader application if the LUT can't be loaded?
							function() end
						);
					end
				end
			end
		end
	end

	return ok
end

-- this is currently quite wasteful, there is a blit-out copy stage in order
-- to get an output buffer that can simply be sharestorage()d into the canvas
-- slot rather than all the complications with swap-in-out. That was necessary
-- for durden but probably not here as separate composite- cells can do that
-- job.
	local function build_passes()
		local props = image_storage_properties(dst);
		local invid = null_surface(props.width, props.height);
		image_sharestorage(dst, invid);

		for i=1,#shader.passes do
			invid = build_pass(invid, shader.passes[i]);
		end

-- chain finished and stored in invid, final blitout pass so we have a
-- shareable storage format
		local outprops = image_storage_properties(invid);
		local outvid = alloc_surface(outprops.width, outprops.height);
		define_rendertarget(outvid, {invid},
			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);
		table.insert(rtgt_list, outvid);
--		show_image(outvid);
		if (shader.filter) then
			image_texfilter(outvid, filter_strnum(shader.filter));
		end
		return outvid;
	end

	preload_effect_shader(shader, name);
	local outvid = build_passes();
	rendertarget_forceupdate(outvid);
	hide_image(outvid);

-- return a reference to the video object, a refresh function and a
-- rebuild-or-destroy function.
	return outvid,
	function()
		for i,v in ipairs(rtgt_list) do
			rendertarget_forceupdate(v);
		end
	end,
	function(vid, destroy)
		for i,v in ipairs(rtgt_list) do
			delete_image(v);
		end
		rtgt_list = {};
-- this is unnecessarily expensive, better approach would be to re-enumerate
-- the passes and just resize rendertarget and inputs / outputs
		if (not destroy and valid_vid(vid)) then
			dst = vid;
			return build_passes();
		end
	end;
end

local fmtgroups = {
	ui = ssetup,
	effect = esetup,
	simple = ssetup
}

-- load/build a shader matching shaders/[group]/[name].lua
--
-- a function that builds a shader chain for working on [srv_vid]
-- and returns the vid, an update function, a destruction function and a
-- table of uniform variable accessors
return
function(dst, group, name, state)
	if not fmtgroups[group] or not shdrtbl[group][name] then
		return
	end
	return fmtgroups[group](shdrtbl[group][name], dst, group, name, state);
end,
shdrmgmt_scan
