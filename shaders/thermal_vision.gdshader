shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D zezlan_texture  : filter_linear_mipmap;

vec3 thermal_palette(float t) {
	vec3 c0 = vec3(0.0,  0.0,  0.0);
	vec3 c1 = vec3(0.25, 0.0,  0.4);
	vec3 c2 = vec3(0.85, 0.05, 0.05);
	vec3 c3 = vec3(1.0,  0.45, 0.0);
	vec3 c4 = vec3(1.0,  1.0,  0.9);

	vec3 col;
	if (t < 0.25)      col = mix(c0, c1, t / 0.25);
	else if (t < 0.5)  col = mix(c1, c2, (t - 0.25) / 0.25);
	else if (t < 0.75) col = mix(c2, c3, (t - 0.5)  / 0.25);
	else               col = mix(c3, c4, (t - 0.75)  / 0.25);
	return col;
}

void fragment() {
	vec4 zezlan = texture(zezlan_texture, SCREEN_UV);
	if (zezlan.a > 0.05) {
		float lum  = dot(zezlan.rgb, vec3(0.299, 0.587, 0.114));
		float heat = clamp(0.75 + lum * 0.5, 0.0, 1.0);
		COLOR = vec4(mix(vec3(1.0, 0.35, 0.0), vec3(1.0, 1.0, 0.85), heat), 1.0);
	} else {
		vec4 src = texture(screen_texture, SCREEN_UV);
		float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(thermal_palette(lum), src.a);
	}
}
