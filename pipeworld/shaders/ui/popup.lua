--
-- basic shader for cells where there is no other specific type to the contents
--
return {
	label = "Popup",
	version = 1,
vert = [[
uniform mat4 modelview;
uniform mat4 projection;

uniform vec2 obj_output_sz;

uniform float thickness;
uniform float border;

attribute vec2 texcoord;
varying vec2 texco;
varying vec2 real_texco;

attribute vec4 vertex;
void main(){
	gl_Position = (projection * modelview) * vertex;
	vec2 real_sz = obj_output_sz / (obj_output_sz - 2.0 * thickness);
	vec2 step_st = 1.0 / obj_output_sz * real_sz;

	texco = texcoord;
	real_texco = (texcoord * real_sz) - (step_st * thickness);
}
]],

frag =
[[
	uniform float border;
	uniform float thickness;
	uniform float obj_opacity;

	uniform vec3 bg_color;
	uniform vec3 border_color;

	uniform sampler2D map_tu0;

	uniform vec2 obj_output_sz;
	uniform float weight;

	varying vec2 texco;
	varying vec2 real_texco;

	void main()
	{
		float margin_s = (border / obj_output_sz.x);
		float margin_t = (border / obj_output_sz.y);
		float margin_w = (thickness / obj_output_sz.x);
		float margin_h = (thickness / obj_output_sz.y);

/* discard both inner and outer border in order to support 'gaps' */
		if (
			texco.s < margin_w || texco.t < margin_h ||
			texco.s > 1.0 - margin_w || texco.t > 1.0 - margin_h)
		{
			if (
				texco.s < margin_s || texco.t < margin_t ||
				texco.s > 1.0 - margin_s || texco.t > 1.0 - margin_t)
				gl_FragColor = vec4(border_color, obj_opacity);
			else
				gl_FragColor = vec4(bg_color, obj_opacity);
		}
		else{
			vec4 col = texture2D(map_tu0, real_texco);
			gl_FragColor = vec4((1.0 - col.a) * bg_color + col.a * col.rgb, obj_opacity);
		}
	}
]],
	uniforms = {
		bg_color = {
			label = "Background Color",
			utype = 'fff',
			ignore = false,
			default = {0, 0, 0},
			low = 0,
			high = 1
		},
-- the surface itself needs to be oversized with 2* this amount for the
-- text itself to fit and come out right
		thickness = {
			label = "Thickness",
			utype = 'f',
			ignore = false,
			default = 4,
			low = 1,
			high = 10,
		},
-- needs to be < thickness
		border = {
			label = "Border",
			utype = 'f',
			ignore = false,
			default = 1,
			low = 1,
			high = 10
		},
		border_color = {
			label = "Border Color",
			utype = 'fff',
			ignore = false,
			default = {1, 1, 1},
			low = 0,
			high = 1
		},
	},
};
