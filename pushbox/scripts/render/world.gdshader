shader_type canvas_item;
render_mode unshaded;
uniform sampler2D palette : filter_nearest;
uniform sampler2D bedrock_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D cracked_tex : source_color, filter_nearest, repeat_enable;
uniform int bedrock_id = 1;
uniform int cracked_id = 2;
uniform int sand_id = 5;
uniform int water_id = 6;
uniform int crate_id = 3;
uniform int gate_id = 4;
uniform vec4 room_rect = vec4(0.0, 0.0, 320.0, 192.0);
varying vec2 world_position;
const vec4 INK = vec4(0.094118, 0.078431, 0.145098, 1.0);
const vec4 SLATE = vec4(0.352941, 0.411765, 0.533333, 1.0);
const vec4 ROCK_EDGE = vec4(0.545098, 0.607843, 0.705882, 1.0);

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
int material_at(sampler2D cell_texture, ivec2 at) {
	if (at.x < 0 || at.y < 0 || at.x >= 256 || at.y >= 256) { return bedrock_id; }
	uvec4 t = uvec4(round(texelFetch(cell_texture, at, 0) * 255.0));
	return int(t.r | ((t.g & 15u) << 8u));
}
void fragment() {
	ivec2 px = min(ivec2(UV * vec2(textureSize(TEXTURE, 0))), ivec2(255));
	uvec4 t = uvec4(round(texelFetch(TEXTURE, px, 0) * 255.0));
	int mat = int(t.r | ((t.g & 15u) << 8u));
	int variant = int((t.g >> 4u) & 3u);
	vec2 wp = floor(world_position);
	vec2 tile_uv = (wp + 0.5) / 16.0;
	vec4 c = vec4(0.0);
	bool in_room = wp.x >= room_rect.x && wp.y >= room_rect.y && wp.x < room_rect.x + room_rect.z && wp.y < room_rect.y + room_rect.w;
	if (in_room && mat != 0 && mat != crate_id && mat != gate_id) {
		int up = material_at(TEXTURE, px - ivec2(0, 1));
		bool exposed = up == 0 || up == crate_id || up == gate_id || up == water_id;
		if (mat == bedrock_id) {
			c = texture(bedrock_tex, tile_uv);
			if (exposed) { c = ROCK_EDGE; }
			else if (material_at(TEXTURE, px - ivec2(0,2)) == 0) { c = SLATE; }
			if (material_at(TEXTURE, px - ivec2(1,0)) == sand_id || material_at(TEXTURE, px + ivec2(1,0)) == sand_id) { c = INK; }
		} else if (mat == cracked_id) {
			c = texture(cracked_tex, tile_uv);
		} else if (mat == sand_id) {
			c = variant == 0 ? vec4(0.760784, 0.521569, 0.411765, 1.0) : (variant == 1 ? vec4(0.894118, 0.650980, 0.447059, 1.0) : vec4(0.917647, 0.831373, 0.666667, 1.0));
			if (exposed) { c = vec4(0.917647, 0.831373, 0.666667, 1.0); }
		} else if (mat == water_id) {
			int depth = 0;
			for (int i = 1; i <= 129; i++) {
				if (material_at(TEXTURE, px - ivec2(0,i)) != water_id) { break; }
				depth += 1;
			}
			c = depth > 128 ? vec4(0.070588, 0.305882, 0.537255, 0.88) : vec4(0.0, 0.6, 0.858824, 0.78);
			if (up == 0) { c = vec4(0.172549, 0.909804, 0.960784, 0.95); }
		} else {
			c = texelFetch(palette, ivec2(mat, variant), 0);
		}
	}
	COLOR = c;
}
