shader_type canvas_item;
uniform sampler2D palette : filter_nearest;
uniform int overlay_mode = 0;
uniform vec4 fire_color = vec4(1.0, 0.55, 0.1, 1.0);

void fragment() {
  ivec2 size = textureSize(TEXTURE, 0);
  ivec2 px = min(ivec2(UV * vec2(size)), size - 1);
  uvec4 t = uvec4(round(texelFetch(TEXTURE, px, 0) * 255.0));
  int mat = int(t.r | ((t.g & 15u) << 8u));
  int variant = int((t.g >> 4u) & 3u);
  vec4 c = texelFetch(palette, ivec2(mat, variant), 0);
  if (((t.g >> 6u) & 1u) == 1u) {                 // 燃烧：只在显示上闪烁，不影响模拟
    float f = 0.5 + 0.5 * sin(TIME * 20.0 + float(px.x * 7 + px.y * 13));
    c = mix(c, fire_color, 0.35 + 0.35 * f);
  }
  if (overlay_mode == 1) {                        // 温度：蓝 → 红 → 白，50% 混合
    float v = float(t.b) / 255.0;
    vec3 ramp = v < 0.5 ? mix(vec3(0.0, 0.2, 1.0), vec3(1.0, 0.1, 0.0), v * 2.0)
                        : mix(vec3(1.0, 0.1, 0.0), vec3(1.0, 1.0, 1.0), (v - 0.5) * 2.0);
    c = vec4(mix(c.rgb, ramp, 0.5), max(c.a, 0.5));
  } else if (overlay_mode != 0) {
    float v = float(t.b) / 255.0;
    vec3 tint = overlay_mode == 2 ? vec3(0.1, 0.4, 1.0) : vec3(0.3, 1.0, 0.3);
    c = vec4(mix(c.rgb, tint, v * 0.7), max(c.a, v * 0.8));
  }
  COLOR = c;
}
