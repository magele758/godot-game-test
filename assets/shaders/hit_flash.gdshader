shader_type canvas_item;

uniform float flash_amount : hint_range(0, 1) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = mix(tex_color, vec4(flash_color.rgb, tex_color.a), flash_amount);
}
