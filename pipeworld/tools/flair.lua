--
-- missing to make things nicer:
--
-- raindrop mode:
--  set wallpaper itself to a blurred version (though can still add more for acrylic)
--  create downsampled unfiltered 'sharp' version
--  particle system that runs and renders into alpha map sampled with background
--  raindrop particle system that samples sharp version inverted using a lookup texture
--  for refraction
--
-- to go over the top:
--  ray-trace from light source into 1d texture (mouse cursor?)
--  build shadow map based on 1d texture as 'shadowed or not'
--

-- resolution vs. cost tradeoff
local blur_factor_w = 0.4
local blur_factor_h = 0.4
local offset_x = -0.01
local offset_y = -0.01

-- desired blur strength (wallpaper)
local n_blur_passes = 16

-- separability doesn't do much here
local blur_shader
local blur_frag = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
uniform vec2 obj_output_sz;
uniform vec4 weight;
varying vec2 texco;
uniform vec3 shadow_color;

void main()
{
	vec4 sum = vec4(0.0);
	float blurh = 1.0 / obj_output_sz.x;
	sum += texture2D(map_tu0, vec2(texco.x - 4.0 * blurh, texco.y)) * 0.05;
	sum += texture2D(map_tu0, vec2(texco.x - 3.0 * blurh, texco.y)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x - 2.0 * blurh, texco.y)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x - 1.0 * blurh, texco.y)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x - 0.0 * blurh, texco.y)) * 0.18;
	sum += texture2D(map_tu0, vec2(texco.x + 1.0 * blurh, texco.y)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x + 2.0 * blurh, texco.y)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x + 3.0 * blurh, texco.y)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x + 4.0 * blurh, texco.y)) * 0.05;

	float blurv = 1.0 / obj_output_sz.y;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 4.0 * blurv)) * 0.05;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 3.0 * blurv)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 2.0 * blurv)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 1.0 * blurv)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 0.0 * blurv)) * 0.18;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 1.0 * blurv)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 2.0 * blurv)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 3.0 * blurv)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 4.0 * blurv)) * 0.05;
	sum *= weight;
	gl_FragColor = vec4(sum.rgb, sum.a);
}
]]

local blur_mix = [[
	uniform sampler2D map_tu0; /* high resolution wallpaper */
	uniform sampler2D map_tu1; /* shadow map                */
	varying vec2 texco;
	uniform vec2 offset;
	uniform vec2 obj_output_sz;

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float smoothstep(float e0, float e1, float e)
{
	float t = clamp((e - e0) / (e1 - e0), 0.0, 1.0);
	return t * t * (1.0 - 2.0 * t);
}

void main()
	{
		vec3 col = texture2D(map_tu0, texco).rgb;
		vec2 uv = gl_FragCoord.xy / obj_output_sz;
		uv.y = 1.0 - uv.y;

		vec4 shadow = texture2D(map_tu1, uv).rgba;
		float fact = 1.0 - shadow.a;

		vec3 pc = rgb2hsv(col);
		float sv = -smoothstep(0.2, 0.5, pc.b) * 2.0 - 1.0;

		col = col.rgb - (shadow.a * fact * sv);
		gl_FragColor = vec4(col.rgb, 1.0);
	}
]]

-- use this to make the source image slightly larger
local boxblur_vert = [[
uniform mat4 modelview;
uniform mat4 projection;
uniform vec4 shadow_offset;

attribute vec2 texcoord;
varying vec2 texco;
attribute vec4 vertex;
void main(){
	vec2 sv = vec2(vertex.x, vertex.y);

/* the blur only applies to the object fragments, which will match
   1:1 with the original shape, so need to enlargen it a little bit */
	if (sv.x < 0.0){
		sv.x = sv.x - shadow_offset.x;
	}
	else {
		sv.x = sv.x + shadow_offset.y;
	}

	if (sv.y < 0.0){
		sv.y = sv.y - shadow_offset.z;
	}
	else {
		sv.y = sv.y + shadow_offset.w;
	}

/* vertex will be object-space [-halfw..halfw, -halfh..halfh] */

	gl_Position = (projection * modelview) * vec4(sv.xy, 1.0, 1.0);
  texco = texcoord;
}
]]

local boxblur_frag = [[
/*
 * shadow solution courtesy of Evan Wallace,
 * 'Fast Rounded Rectangle Shadows'
 * madebyevan.com/shaders/fast-rounded-rectangle-shadows
 * (MIT license), see github.com/evanw/glfx.js
 */
	uniform float obj_opacity;
	uniform float radius;
	uniform float sigma;
	uniform vec2 obj_output_sz;
	uniform float weight;
	uniform vec3 shadow_color;
	varying vec2 texco;

vec2 error_function(vec2 x)
{
	vec2 s = sign(x), a = abs(x);
	x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
	x *= x;
	return s - s / (x * x);
}

float gaussian(float x, float sigma)
{
	const float pi =  3.141592653589793;
	return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * pi) * sigma);
}

float rounded_shadow_x(float x, float y, float sigma, float corner, vec2 halfv)
{
	float delta = min(halfv.y - corner - abs(y), 0.0);
	float curved = halfv.x - corner + sqrt(max(0.0, corner * corner - delta * delta));
	vec2 integral = 0.5 + 0.5 * error_function((x + vec2(-curved, curved)) * (sqrt(0.5)/sigma));
	return integral.y - integral.x;
}

float rounded_box_shadow(vec2 lower, vec2 upper, vec2 point, float sigma, float corner)
{
	vec2 center = (lower + upper) * 0.5;
	vec2 halfv = (upper - lower) * 0.5;
	point -= center;
	float low = point.y - halfv.y;
	float high = point.y + halfv.y;
	float start = clamp(-3.0 * sigma, low, high);
	float end = clamp(3.0 * sigma, low, high);

	float step = (end - start) / 4.0;
	float y = start + step * 0.5;
	float value = 0.0;
	for (int i = 0; i < 4; i++){
		value += rounded_shadow_x(point.x, point.y - y, sigma, corner, halfv) * gaussian(y, sigma) * step;
		y += step;
	}
	return value;
}

void main()
{
	float padding = 3.0 * sigma;
	vec2 vert = mix(vec2(0.0, 0.0) - padding, obj_output_sz + padding, texco);

	vec2 rvec = vec2(radius, radius);
	vec2 high = obj_output_sz;

	float a = rounded_box_shadow(vec2(0.0, 0.0), high, vert, sigma, radius);
	gl_FragColor = vec4(shadow_color, max(obj_opacity * weight * a, 0.0));
}
]]

--[[
vec3 rgb2hsv(vec3 c)
	{
		vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
		vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
		vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

		float d = q.x - min(q.w, q.y);
		float e = 1.0e-10;

		return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x / e), q.x);
	}

  vec3 hsv2rgb(vec3 c)
	{
		vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
		vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
		return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
	}
}
]]--

local mouse_shid = build_shader(nil,
[[
	uniform sampler2D map_tu0;
	uniform sampler2D map_tu1;
	varying vec2 texco;
	uniform vec3 outline_bright;
	uniform vec3 outline_dark;
	uniform float width;
	uniform float height;
	uniform vec4 remap;

	void main()
	{
		vec4 shape = texture2D(map_tu0, texco);

    // copied from row.lua
		float txco_s = remap.z + remap.x * gl_FragCoord.x / width;
		float txco_t = remap.w + remap.y * (1.0 - (gl_FragCoord.y / height));

		vec4 col = texture2D(map_tu1, vec2(txco_s, txco_t));

		float luma = (shape.r + shape.g + shape.b) / 3.0;
		float intens = (col.r + col.g + col.b) / 3.0;
		float pct = smoothstep(0.3, 0.4, intens);
		vec3 outline = mix(outline_dark, outline_bright, pct);

		gl_FragColor = vec4(mix(outline, col.rgb, luma), shape.a);
	}
]], "CURSOR")

local events = {}
events.create =
function(wm)
	local glow = alloc_surface(wm.w, wm.h)
	if not valid_vid(glow) then
		return
	end

	local blurw = wm.w * blur_factor_w
	local blurh = wm.h * blur_factor_h
	local blur = alloc_surface(blurw, blurh)
	if not valid_vid(blur) then
		delete_image(glow)
		return
	end

	local b = wm.cfg.colors.cursor_outline_bright;
	local d = wm.cfg.colors.cursor_outline_dark;
	local f = 1.0 / 255.0;

	shader_uniform(mouse_shid, "remap", "ffff", 1.0, 1.0, 0.0, 0.0);
	shader_uniform(mouse_shid, "width", "f", wm.w);
	shader_uniform(mouse_shid, "height", "f", wm.h);
	shader_uniform(mouse_shid, "outline_dark", "fff", d[1] * f, d[2] * f, d[3] * f);
	shader_uniform(mouse_shid, "outline_bright", "fff", b[1] * f, b[2] * f, b[3] * f);

	wm.tool_flair = {
		glow = glow,
		blur = blur
	}

	glow_shader = shader_ugroup(blur_shader)
	shader_uniform(glow_shader, "weight", "ffff", 1.0, 1.0, 1.0, 1.0)

	local mix_shader = build_shader(nil, blur_mix, "flair_mix")
	shader_uniform(mix_shader, "width", "f", wm.w)
	shader_uniform(mix_shader, "height", "f", wm.h)

	local boxblur = build_shader(boxblur_vert, boxblur_frag, "box_blur")
	shader_uniform(boxblur, "radius", "f", 0.5)
	shader_uniform(boxblur, "sigma", "f", 4)
	shader_uniform(boxblur, "weight", "f", 1.0)
	shader_uniform(boxblur, "mix_factor", "f", 0.4)
	shader_uniform(boxblur, "shadow_color", "fff", 0.0, 0.0, 0.0)

-- adjust for non-uniform shadow/glow
	shader_uniform(boxblur, "shadow_offset", "ffff", 12.0, 12.0, 12.0, 12.0)

-- so for the basic glow texture we need a 1:1 size match between the two
-- linktargets or there will not be enough resolution to 'fit' the others
	define_linktarget(glow, wm.rtgt,
		RENDERTARGET_NOSCALE, -1, bit.bor(RENDERTARGET_COLOR, RENDERTARGET_ALPHA))

	image_shader(glow, boxblur, SHADER_DOMAIN_RENDERTARGET_HARD)

-- we just want to slice out the rows themselves, ignoring contents and decor
	local anchor_order = image_surface_resolve(wm.anchor).order
	rendertarget_range(glow, anchor_order, anchor_order + 10)

	_G[APPLID .. "_preframe_pulse"] =
	function()
-- this is 'a bit' ugly as it forces interpolated animations to resolve
-- to their current position indepedent of rendertarget processing order
-- then, we draw with the actual 'blurred rectangle shader' on the second
-- pass
		local vids = rendertarget_vids(wm.rtgt)
		for k,v in ipairs(vids) do
			image_surface_resolve(v)
		end
	end

-- debugging:
--	rendertarget_range(WORLDID, 1, anchor_order)

	image_framesetsize(wm.cfg.wallpaper, 2, FRAMESET_MULTITEXTURE)
	set_image_as_frame(wm.cfg.wallpaper, glow, 1)

	image_shader(wm.cfg.wallpaper, mix_shader)
	shader_uniform(mix_shader, "offset", "ff", offset_x, offset_y)

-- turned out so-so, need raytracing
--	local max_bias = 20
--	timer_add_periodic("cursor_shadow", 1, false,
--		function()
--			local mx, my = mouse_xy()
--			local t = max_bias
--			local l = t
--			local d = t
--			local r = t
--			local hw = VRESW * 0.5
--			local hh = VRESH * 0.5
--			local dx = (mx - hw) / hw * max_bias
--			local dy = (my - hh) / hh * max_bias
--			t = dy > 0 and 3 or math.abs(dy)
--			l = dx > 0 and 2 or math.abs(dx)
--			d = dy < 0 and 3 or math.abs(dy)
--			r = dx < 0 and 3 or math.abs(dx)
--			shader_uniform(boxblur, "shadow_offset", "ffff", l, r, t, d)
--		end
--	)
	return true
end

events.wallpaper_switch =
function(wm, new_vid)

end

events.resize =
function(wm, width, height)
	if not wm.tool_flair then
		return
	end

	local fw = width * blur_factor_w
	local fh = height * blur_factor_h

	image_resize_storage(wm.tool_flair.glow, width, height)
	image_resize_storage(wm.tool_flair.blur, fw, fh)

	resize_image(wm.tool_flair.glow, fw, fh)
	resize_image(wm.tool_flair.blur, width, height)
end

events.pan =
function(wm, dx, dy)
	local txcos = image_get_txcos(wm.cfg.wallpaper)
	if not txcos then
		return
	end

	local fx = txcos[3] - txcos[1]
	local fy = txcos[6] - txcos[2]
	local ox = txcos[1]
	local oy = txcos[2]

-- shift the range and base offset to match parallax panning, need to do
-- this both on the selected row and on the non-selected one as they have
-- different 'states'
	local active = wm.last_focus
	local passive = active == wm.rows[1] and wm.rows[2] or wm.rows[1]

	if active and active.bgshid then
		shader_uniform(active.bgshid, "remap", "ffff", fx, fy, ox, oy)
	end

	if passive and passive.bgshid then
		shader_uniform(passive.bgshid, "remap", "ffff", fx, fy, ox, oy)
	end

	shader_uniform(mouse_shid, "remap", "ffff", fx, fy, ox, oy)
	shader_uniform(mouse_shid, "width", "f", wm.w)
	shader_uniform(mouse_shid, "height", "f", wm.h)
end

local function event_handler(wm, event, ...)
	if events[event] then
		events[event](wm, ...)
	end
end

local function update_wallpaper(wm, vid)
	local cfg = wm.cfg

	if not image_matchstorage(vid, cfg.wallpaper) then
		set_image_as_frame(cfg.wallpaper, vid, 0)
	end

	local props = image_storage_properties(cfg.wallpaper)

	local wp = null_surface(32, 32)
	local blurw = props.width * 0.25
	local blurh = props.height * 0.25
	image_sharestorage(vid, wp)

-- statically apply the blur
	for i=1,n_blur_passes do
		resample_image(wp, blur_shader, blurw, blurh, true)
	end

	if valid_vid(cfg.row_bg) then
		delete_image(cfg.row_bg)
		link_image(cfg.row_bg, wm.anchor)
	end

-- swap into background for all rows as the 'acrylic'
	wm.row_bg = wp

	for _,row in ipairs(wm.rows) do
		set_image_as_frame(row.bg, wp, 2)
	end

-- setting cursor flair
	local mstate = mouse_state()

	image_framesetsize(mstate.cursor, 3, FRAMESET_MULTITEXTURE)
	set_image_as_frame(mstate.cursor, wp, 2)
	image_shader(mstate.cursor, "CURSOR")
	events.pan(wm, 0, 0)
	local props = image_storage_properties(mstate.cursor)
--	resize_image(mstate.cursor, props.width * 0.25, props.height * 0.25)
end

local function wallpaper_set(wm, ref)
	if type(ref) == "number" and valid_vid(ref) then
		update_wallpaper(wm, vid)

	elseif type(ref) == "string" then
		if not resource(ref) then
			ref = "backgrounds/" .. ref
		end

		load_image_asynch(ref,
			function(source, status)
				if status.kind == "loaded" then
					update_wallpaper(wm, source)
					local cfg = wm.cfg
					cfg.wallpaper_update(cfg.wallpaper, cfg, VRESW, VRESH)
				end
				delete_image(source)
			end
		)
	else
		warning("tools/flair: invalid wallpaper argument")
	end
end

local function load_theme(wm, theme)
	local theme, res = suppl_load_script_tbl("devmaps/themes/", theme)
	if not theme then
		return false, res
	end

	if theme.wallpaper then
		wallpaper_set(wm, theme.wallpaper)
	end

-- build a list of the targets where the cfg should be replaced with the
-- set of colors and font values needed
	local lst = {}
	for _, row in ipairs(wm.rows) do
		if row.cfg then
			table.insert(lst, row.cfg)
		end

		for _, cell in row.cells do
			if cell.cfg then
				table.insert(lst, row.cfg)
			end
		end
	end

-- we are still missing a feature or two to make this reasonably painless,
-- but we should cross-fade between current and old, so saving a screenshot
-- before wallpaper_set, add a transition trigger (asynch-load or timeout)
-- switch WORLDID (or whatever attachment we have) to temporary RT and draw
-- that with a shader that interpolates HSL from screenshot to current, then
-- switch RT back.

-- then if there are any wallpaper effect triggers and particle systems,
-- enable those..

-- open bits: led control schemes (if we have any controllers there)
end

-- only pre-compile shaders at load-time etc. rest is done dynamically
return
function(wm)
	blur_shader = build_shader(nil, blur_frag, "naive_gaussian")
	if not blur_shader then
		warning("tools/flair - error compiling gaussian")
		return
	end
	shader_uniform(blur_shader, "weight", "ffff", 0.5, 0.5, 0.5, 1.0)
	update_wallpaper(wm, wm.cfg.wallpaper)

-- intercept any wallpaper set
	wm.cmdtree["/wallpaper/set"] = wallpaper_set

-- intercept rendertarget redirection and use to rebuild ourselves

-- command for loading theme goes here
	return event_handler
end
