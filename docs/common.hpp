// Shared helpers for the measurement programs (not part of any deliverable).
#pragma once
#include <ele/core/content.hpp>
#include <ele/core/world.hpp>
#include <ele/core/queries.hpp>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <memory>
#include <string>
#include <vector>
inline std::string read_file(const std::string& path) {
    std::ifstream f(path); if (!f) return {};
    return {std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>()};
}
inline std::shared_ptr<const ele::Content> load(const std::string& dir, const std::string& profile = "profile.json") {
    std::vector<ele::Diagnostic> diags;
    auto c = ele::load_content({read_file(dir + "/materials.json"), read_file(dir + "/" + profile), read_file(dir + "/reactions.json")}, diags);
    for (auto& d : diags) std::fprintf(stderr, "%s %s: %s\n", d.error ? "ERROR" : "warning", d.path.c_str(), d.message.c_str());
    if (!c.value) { std::fprintf(stderr, "load failed\n"); std::exit(1); }
    return *c.value;
}
inline std::unique_ptr<ele::World> make_world(std::shared_ptr<const ele::Content> c, int w, int h, std::uint64_t seed = 1, std::uint32_t threads = 4) {
    ele::WorldConfig cfg; cfg.width = w; cfg.height = h; cfg.seed = seed; cfg.threads = threads;
    auto r = ele::World::create(cfg, c);
    if (!r.value) { std::fprintf(stderr, "create failed %d\n", int(r.error)); std::exit(1); }
    return std::move(*r.value);
}
inline void rect(ele::World& w, int x, int y, int ww, int hh, const char* mat, std::uint32_t mode = 0) {
    w.submit({ele::CommandType::PaintRect, x, y, ww, hh, w.material_id(mat), mode});
}
inline void clear(ele::World& w, int x, int y, int ww, int hh, std::uint32_t mode = 0) {
    w.submit({ele::CommandType::ClearRect, x, y, ww, hh, 0, mode});
}
inline int count_in(const ele::World& w, int x, int y, int ww, int hh, const char* mat) {
    auto id = w.material_id(mat); int n = 0;
    for (int yy = y; yy < y + hh; ++yy) for (int xx = x; xx < x + ww; ++xx) n += w.cell_at(xx, yy).material == id;
    return n;
}
inline int count_tag(const ele::World& w, int x, int y, int ww, int hh, const char* tag) {
    const auto& m = w.materials(); int bit = -1;
    for (size_t i = 0; i < m.tags.size(); ++i) if (m.tags[i] == tag) bit = int(i);
    if (bit < 0) return 0; int n = 0;
    for (int yy = y; yy < y + hh; ++yy) for (int xx = x; xx < x + ww; ++xx) {
        auto id = w.cell_at(xx, yy).material;
        if (id < m.n && (m.cold[id].tag_mask >> bit) & 1) ++n;
    }
    return n;
}
