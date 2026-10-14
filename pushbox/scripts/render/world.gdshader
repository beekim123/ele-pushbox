shader_type canvas_item;
render_mode unshaded;
uniform sampler2D palette : filter_nearest;
uniform bool local_pixel_coordinates = false;
uniform int biome_style_id = 0;
uniform int iron_crate_id = -1;
uniform int acid_id = -1;
uniform int lava_id = -1;
uniform int pumice_id = -1;
uniform int ice_id = -1;
uniform int levitated_sand_id = -1;
uniform int levitated_pumice_id = -1;
uniform int fume_id = -1;
uniform vec4 bedrock_base = vec4(0.227451,0.266667,0.4,1.0);
uniform vec4 bedrock_seam = vec4(0.149020,0.168627,0.266667,1.0);
uniform vec4 bedrock_edge = vec4(0.545098,0.607843,0.705882,1.0);
uniform vec4 bedrock_trim = vec4(0.352941,0.411765,0.533333,1.0);
uniform vec4 cracked_base = vec4(0.760784,0.521569,0.411765,1.0);
uniform vec4 cracked_edge = vec4(0.894118,0.650980,0.447059,1.0);
uniform vec4 cracked_vein = vec4(0.243137,0.152941,0.192157,1.0);
uniform vec4 sand_base = vec4(0.760784,0.521569,0.411765,1.0);
uniform vec4 sand_mid = vec4(0.894118,0.650980,0.447059,1.0);
uniform vec4 sand_light = vec4(0.917647,0.831373,0.666667,1.0);
uniform vec4 water_base = vec4(0.0,0.6,0.858824,0.78);
uniform vec4 water_deep = vec4(0.070588,0.305882,0.537255,0.88);
uniform vec4 water_edge = vec4(0.172549,0.909804,0.960784,0.95);
uniform int bedrock_id = 1;
uniform int cracked_id = 2;
uniform int sand_id = 5;
uniform int water_id = 6;
uniform int crate_id = 3;
uniform int gate_id = 4;
uniform vec4 room_rect = vec4(0.0, 0.0, 320.0, 192.0);
uniform vec2 world_origin = vec2(0.0);
uniform ivec2 cell_texture_size = ivec2(256,256);
varying vec2 world_position;
const vec4 INK = vec4(0.094118, 0.078431, 0.145098, 1.0);
const vec4 SLATE = vec4(0.352941, 0.411765, 0.533333, 1.0);
const vec4 ROCK_EDGE = vec4(0.545098, 0.607843, 0.705882, 1.0);

float hash_tile(vec2 tile) {
	return fract(sin(dot(tile, vec2(127.1, 311.7))) * 43758.5453);
}
float stroke(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}
vec4 bedrock(vec2 p, vec2 tile) {
	vec4 c = bedrock_base;
	vec4 seam = bedrock_seam;
	if (p.x == 0.0 || p.y == 0.0) { c = seam; }
	else if (p.x == 1.0 || p.y == 1.0) { c = bedrock_trim; }
	float start = 3.0 + 4.0 * step(0.5, hash_tile(tile));
	if (p.y == 9.0 && p.x >= start && p.x <= start + 4.0) { c = seam; }
	if (biome_style_id == 1) {
		float root = mod(p.x + floor(p.y / 3.0), 12.0);
		if (root < 2.0) { c = bedrock_seam; }
		else if (root == 2.0) { c = bedrock_trim; }
	} else if (biome_style_id == 2) {
		if (p.x >= 4.0 && p.x <= 11.0 && p.y >= 4.0 && p.y <= 11.0 &&
			(p.x == 4.0 || p.y == 4.0 || (p.x == 11.0 && p.y < 9.0) || (p.y == 11.0 && p.x < 9.0))) { c = bedrock_seam; }
		if (p.x == 7.0 && p.y >= 7.0 && p.y <= 10.0) { c = bedrock_trim; }
	} else if (biome_style_id == 3) {
		float stratum = mod(p.x + 2.0*p.y, 16.0);
		c = stratum < 2.0 ? bedrock_seam : bedrock_base;
		if (stratum == 2.0) { c = bedrock_trim; }
		if (p.x == 12.0 && p.y == 5.0 && hash_tile(tile) > 0.75) { c = vec4(0.172549,0.909804,0.960784,1.0); }
	} else if (biome_style_id == 4) {
		if (mod(p.x-p.y+32.0,16.0) == 4.0) { c = bedrock_trim; }
		if (p.x == 1.0 || p.y == 1.0) { c = vec4(0.996078,0.682353,0.203922,1.0); }
	} else if (biome_style_id == 5) {
		if (p.x == 0.0 || p.y == 0.0 || p.x == 15.0 || p.y == 15.0) { c = bedrock_seam; }
		if ((p.x == 2.0 || p.x == 13.0) && (p.y == 2.0 || p.y == 13.0)) { c = bedrock_edge; }
		if (p.y == 10.0 && p.x >= 5.0 && p.x <= 10.0) { c = bedrock_seam; }
	}
	return c;
}
vec4 cracked_rock(vec2 p) {
	vec4 c = cracked_base;
	if (p.x == 0.0 || p.y == 0.0) { c = cracked_edge; }
	float crack = min(min(stroke(p, vec2(9,0), vec2(7,4)), stroke(p, vec2(7,4), vec2(10,7))),
		min(stroke(p, vec2(10,7), vec2(6,10)), stroke(p, vec2(6,10), vec2(8,15))));
	float branch = min(min(stroke(p, vec2(8,5), vec2(3,6)), stroke(p, vec2(3,6), vec2(0,4))),
		min(stroke(p, vec2(7,10), vec2(12,11)), stroke(p, vec2(12,11), vec2(15,14))));
	if (crack <= 0.9 || branch <= 0.5) { c = cracked_vein; }
	return c;
}

void vertex() {
	world_position = local_pixel_coordinates ? VERTEX : (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin;
}
int material_at(sampler2D cell_texture, ivec2 at) {
	if (at.x < 0 || at.y < 0 || at.x >= cell_texture_size.x || at.y >= cell_texture_size.y) { return bedrock_id; }
	uvec4 t = uvec4(round(texelFetch(cell_texture, at, 0) * 255.0));
	return int(t.r | ((t.g & 15u) << 8u));
}
void fragment() {
	ivec2 px = min(ivec2(UV * vec2(textureSize(TEXTURE, 0))), textureSize(TEXTURE,0)-ivec2(1));
	uvec4 t = uvec4(round(texelFetch(TEXTURE, px, 0) * 255.0));
	int mat = int(t.r | ((t.g & 15u) << 8u));
	int variant = int((t.g >> 4u) & 3u);
	vec2 wp = floor(world_position);
	vec2 tile_pixel = mod(wp, 16.0);
	vec4 c = vec4(0.0);
	bool in_room = wp.x >= room_rect.x && wp.y >= room_rect.y && wp.x < room_rect.x + room_rect.z && wp.y < room_rect.y + room_rect.w;
	if (in_room && mat != 0 && mat != crate_id && mat != iron_crate_id && mat != gate_id) {
		int up = material_at(TEXTURE, px - ivec2(0, 1));
		bool exposed = up == 0 || up == crate_id || up == iron_crate_id || up == gate_id || up == water_id || up == acid_id;
		if (mat == bedrock_id) {
			c = bedrock(tile_pixel, floor(wp / 16.0));
			if (exposed) { c = bedrock_edge; }
			else if (material_at(TEXTURE, px - ivec2(0,2)) == 0) { c = bedrock_trim; }
			int top = material_at(TEXTURE, px - ivec2(0,int(tile_pixel.y)+1));
			int bottom = material_at(TEXTURE, px + ivec2(0,16-int(tile_pixel.y)));
			bool tile_top = top == 0 || top == crate_id || top == iron_crate_id || top == gate_id || top == water_id || top == acid_id;
			if (biome_style_id == 1 && tile_top && tile_pixel.y < 3.0) { c = vec4(0.388235,0.780392,0.301961,1.0); }
			if (biome_style_id == 4 && bottom == 0 && tile_pixel.y >= 13.0 && wp.y < room_rect.y+room_rect.w-3.0) { c = vec4(1.0); }
			if (biome_style_id == 5 && tile_top && tile_pixel.y < 2.0) {
				c = mod(tile_pixel.x+tile_pixel.y,8.0) < 4.0 ? vec4(0.996078,0.905882,0.380392,1.0) : INK;
			}
			if (material_at(TEXTURE, px - ivec2(1,0)) == sand_id || material_at(TEXTURE, px + ivec2(1,0)) == sand_id) { c = INK; }
		} else if (mat == cracked_id) {
			c = cracked_rock(tile_pixel);
		} else if (mat == sand_id || mat == levitated_sand_id) {
			c = variant == 0 ? sand_base : (variant == 1 ? sand_mid : sand_light);
			if (exposed) { c = sand_light; }
		} else if (mat == water_id) {
			int depth = 0;
			for (int i = 1; i <= 129; i++) {
				if (material_at(TEXTURE, px - ivec2(0,i)) != water_id) { break; }
				depth += 1;
			}
			c = depth > 128 ? water_deep : water_base;
			if (up == 0) { c = water_edge; }
		} else if (mat == acid_id) {
			c = vec4(0.243137,0.537255,0.282353,0.9);
			if (mod(wp.x+wp.y*3.0,19.0) < 2.0) { c = vec4(0.388235,0.780392,0.301961,1.0); }
			if (up != acid_id) { c = vec4(0.996078,0.905882,0.380392,1.0); }
		} else if (mat == lava_id) {
			c = biome_style_id == 5 ? vec4(0.709804,0.313725,0.533333,1.0) : vec4(0.894118,0.231373,0.266667,1.0);
			if (mod(wp.x-floor(wp.y/3.0),11.0) < 2.0 || up != lava_id) {
				c = biome_style_id == 5 ? vec4(1.0,0.0,0.266667,1.0) : vec4(0.996078,0.682353,0.203922,1.0);
			}
		} else if (mat == pumice_id || mat == levitated_pumice_id) {
			c = variant % 2 == 0 ? vec4(0.545098,0.607843,0.705882,1.0) : vec4(0.352941,0.411765,0.533333,1.0);
			if (mod(wp.x+wp.y*5.0,7.0) == 0.0) { c = INK; }
		} else if (mat == fume_id) {
			c = vec4(0.72,0.86,0.45,0.45);
		} else if (mat == ice_id) {
			c = vec4(0.172549,0.909804,0.960784,1.0);
			if (mod(tile_pixel.x+tile_pixel.y,9.0) < 2.0 || up != ice_id) { c = vec4(1.0); }
			else if (tile_pixel.y > 12.0) { c = vec4(0.0,0.6,0.858824,1.0); }
		} else {
			c = texelFetch(palette, ivec2(mat, variant), 0);
		}
	}
	COLOR = c;
}
