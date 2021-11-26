--
-- 'Middle-weight' border shader based on a discard stage
--
-- The distinction between state color and obj_color is to have a per-object
-- coloring with state overrides without resorting to another dimension of
-- ugroups.
--
-- The weight is used as color blend weight against the object color
--
return {
	label = "Row",
	version = 1,
	frag =
[[
	uniform float border;
	uniform float obj_opacity;
	uniform bool inactive;
	uniform sampler2D map_tu0;
	uniform sampler2D map_tu1;
	uniform float width;
	uniform float height;
	uniform vec4 remap;
	varying vec2 texco;

	void main()
	{
		vec3 col = texture2D(map_tu1, vec2(
			remap.z + remap.x * gl_FragCoord.x / width,
			remap.w + remap.y * (1.0 - (gl_FragCoord.y / height))
		)).rgb;

/* and greyscale on inactive */
		if (inactive){
			float avg = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b;
			gl_FragColor = vec4(avg, avg, avg, 1.0);
		}
		else
			gl_FragColor = vec4(col, obj_opacity);
	}
]],
	uniforms = {
		inactive = {
			label = 'Inactive',
			utype = 'b',
			default = false,
		},
		width = {
			label = 'Background Width',
			utype = 'f',
			ignore = true,
			default =
			function(shader)
				shader.uniforms.width.high = VRESW
				return VRESW
			end,
			low = 0,
			high = VRESW
		},
		height = {
			label = 'Background Height',
			utype = 'f',
			ignore = true,
			default =
			function(shader)
				shader.uniforms.height.high = VRESH
				return VRESH
			end,
			low = 0,
			high = VRESH
		},
		remap = {
			label = 'Remap',
			utype = 'ffff',
			ignore = true,
			default = {1.0, 1.0, 0.0, 0.0},
			low = 0,
			high = 1.0
		}
	},
	states = {
		active = {uniforms = { inactive = false } },
		passive = {uniforms = { inactive = true } },
	}
};
