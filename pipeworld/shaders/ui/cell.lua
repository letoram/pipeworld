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
		vec2 sf = obj_output_sz / obj_storage_sz;

/* blur below a set scale */
		if (sf.x < 0.7 || sf.y < 0.7){
			sf = vec2(1.0, 1.0) / obj_storage_sz;
			vec3 ack = vec3(0.0);

			ack += texture2D(map_tu0, vec2(texco.s - sf.x, texco.t - sf.y)).rgb;
			ack += texture2D(map_tu0, vec2(texco.s       , texco.t - sf.y)).rgb;
			ack += texture2D(map_tu0, vec2(texco.s + sf.x, texco.t - sf.y)).rgb;

			ack += texture2D(map_tu0, vec2(texco.s - sf.x, texco.t)).rgb;
			ack += col.rgb;
			ack += texture2D(map_tu0, vec2(texco.s + sf.x, texco.t)).rgb;

			ack += texture2D(map_tu0, vec2(texco.s - sf.x, texco.t + sf.y)).rgb;
			ack += texture2D(map_tu0, vec2(texco.s       , texco.t + sf.y)).rgb;
			ack += texture2D(map_tu0, vec2(texco.s + sf.x, texco.t + sf.y)).rgb;

			col.r = ack.r / 9.0;
			col.g = ack.g / 9.0;
			col.b = ack.b / 9.0;
		}

/* opacity is used to indicate selection state */
		if (obj_opacity < 1.0){
			float avg = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b;
			gl_FragColor = vec4(avg, avg, avg, obj_opacity);
		}
		else
			gl_FragColor = col;
	}
]],
	uniforms = {
	},
};
