--
-- basic shader for cells where there is no other specific type to the contents
--
return {
	label = "Cell",
	version = 1,
	frag =
[[
	uniform float border;
	uniform float obj_opacity;
	uniform vec2 obj_output_sz;
	uniform vec2 obj_storage_sz;

	uniform sampler2D map_tu0;
	uniform float width;
	uniform float height;

	varying vec2 texco;

	void main()
	{
		vec4 col = texture2D(map_tu0, texco).rgba;

/* up or downsampling? */

/* opacity is used to indicate selection state */
		if (obj_opacity < 1.0){
			float avg = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b;
			gl_FragColor = vec4(avg, avg, avg, obj_opacity);
			gl_FragColor = vec4(avg, avg, avg, col.a);
		}
		else
			gl_FragColor = col;
	}
]],
	uniforms = {
	},
};
