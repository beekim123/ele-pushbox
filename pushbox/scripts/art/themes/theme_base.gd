extends RefCounted
## ThemeSpec contract: semantic terrain colors, sprite remaps and gate protocol.
const DEFAULT_COLORS := {
	"bedrock_base": Color("3a4466"), "bedrock_seam": Color("262b44"),
	"bedrock_edge": Color("8b9bb4"), "bedrock_trim": Color("5a6988"),
	"cracked_base": Color("c28569"), "cracked_edge": Color("e4a672"), "cracked_vein": Color("3e2731"),
	"sand_base": Color("c28569"), "sand_mid": Color("e4a672"), "sand_light": Color("ead4aa"),
	"water_base": Color("0099db",0.78), "water_deep": Color("124e89",0.88), "water_edge": Color("2ce8f5",0.95),
	"accent": Color("fee761"), "particle_rock": Color("c28569"), "particle_sand": Color("e4a672")
}

static func make(index: int, id: String, colors: Dictionary, remap: Dictionary) -> Dictionary:
	var uniforms: Dictionary = DEFAULT_COLORS.duplicate()
	uniforms.merge(colors,true)
	return {"index": index, "id": id, "colors": uniforms, "remap": remap, "gate_mode": "energy" if index >= 4 else "mechanical"}
