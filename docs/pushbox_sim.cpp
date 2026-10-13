// Pushbox turn engine on top of the real SDK, used to replay D1-D5 and measure the values the
// template estimates on paper. Implements the rules of pushbox/demo-template.md chapter 2 as revised
// in the 2026-10-13 review (side-contact floating, cumulative SAND class, quiet-tick settling, gate crush).
//
// Usage: pushbox_sim [level|all] [--profile profile.json] [--quiet N] [--t T] [--sup S] [--verbose]
#include "common.hpp"
#include <algorithm>
#include <cstring>
#include <functional>
#include <map>
#include <set>
#include <sstream>

namespace {
constexpr int TW = 20, TH = 12, TC = 16;  // tiles across, down, cells per tile edge
long g_bag = 0; int g_threads = 4, g_threshold = 128, g_support = 64, g_quiet = 8, g_max_ticks = 1200, g_max_rounds = 16, g_crush = 16;
bool g_verbose = false, g_wake = true;

enum Cls { OPEN, WATER, SAND, SOLID, BOX };
const char* cls_char = ".~sS#";

struct Box { std::string id; int x, y; bool floats; };
struct Lever { std::string id; int x, y; bool on; };
struct Gate { std::string id; std::vector<std::pair<int,int>> tiles; std::function<bool()> cond; bool open = false; };

struct Level {
    std::string name;
    std::vector<std::string> map;
    int px, py;
    std::vector<Box> boxes;
    std::vector<std::pair<int,int>> targets, ladders;
    std::vector<Lever> levers;
    int bombs = 0;
    std::vector<std::string> solution;
};

struct Game {
    ele::World* w = nullptr;
    int ox = 0, oy = 0;  // level origin in world tiles
    int px, py;          // player tile (world tiles)
    std::vector<Box> boxes;
    std::set<std::pair<int,int>> targets, ladders;
    std::vector<Lever> levers;
    std::vector<Gate> gates;
    long bag = 0; int bombs = 0;
    std::vector<ele::MaterialId> ids;  // local copy of the whole world, updated by our own swaps
    std::vector<ele::Command> pending;
    bool crumble_pending = false; int blast_cx = 0, blast_cy = 0;
    long ticks_total = 0; int rounds_last = 0; long ticks_last = 0;
    std::string log;
    // material classes by tag
    std::vector<int> is_solid, is_loose, is_fluid, is_box, is_breakable;
    ele::MaterialId m_empty = 0, m_crate, m_gate, m_sand;

    int tagbit(const char* t) { auto& tags = w->materials().tags; for (size_t i = 0; i < tags.size(); ++i) if (tags[i] == t) return int(i); return -1; }
    void init_tags() {
        auto n = w->materials().n; is_solid.assign(n, 0); is_loose.assign(n, 0); is_fluid.assign(n, 0); is_box.assign(n, 0); is_breakable.assign(n, 0);
        int bs = tagbit("solid"), bl = tagbit("loose"), bf = tagbit("fluid"), bb = tagbit("box"), bk = tagbit("breakable");
        for (unsigned i = 0; i < n; ++i) { auto m = w->materials().cold[i].tag_mask;
            is_solid[i] = (m >> bs) & 1; is_loose[i] = (m >> bl) & 1; is_fluid[i] = (m >> bf) & 1; is_box[i] = (m >> bb) & 1; is_breakable[i] = (m >> bk) & 1; }
        m_crate = w->material_id("crate"); m_gate = w->material_id("gate"); m_sand = w->material_id("sand");
    }
    void read_world() { ids.resize(320 * 192); for (int y = 0; y < 192; ++y) for (int x = 0; x < 320; ++x) ids[y * 320 + x] = w->cell_at(x, y).material; }
    ele::MaterialId at(int x, int y) const { return ids[y * 320 + x]; }
    struct Counts { int s = 0, l = 0, f = 0, b = 0, empty = 0, brk = 0; };
    Counts counts(int tx, int ty) const {
        Counts c; for (int y = ty * TC; y < ty * TC + TC; ++y) for (int x = tx * TC; x < tx * TC + TC; ++x) {
            auto m = at(x, y); if (m == 0) { ++c.empty; continue; }
            c.s += is_solid[m]; c.l += is_loose[m]; c.f += is_fluid[m]; c.b += is_box[m]; c.brk += is_breakable[m]; }
        return c;
    }
    bool box_at(int x, int y) const { for (auto& b : boxes) if (b.x == x && b.y == y) return true; return false; }
    Cls cls(int x, int y) const {
        if (x < 0 || y < 0 || x >= TW || y >= TH) return SOLID;
        if (box_at(x, y)) return BOX;
        auto c = counts(x, y);
        if (c.s >= g_threshold) return SOLID;
        if (c.s + c.l >= g_threshold) return SAND;
        if (c.f >= g_threshold) return WATER;
        return OPEN;
    }
    bool enterable(int x, int y) const { auto k = cls(x, y); return k == OPEN || k == WATER; }
    bool ladder(int x, int y) const { return ladders.count({x, y}) > 0; }

    void submit(ele::Command c) { pending.push_back(c); }
    void flush() {
        size_t i = 0;
        while (i < pending.size()) {
            size_t n = 0;
            for (; i < pending.size() && n < 4000; ++i, ++n) if (w->submit(pending[i]) != ele::Error::Ok) std::fprintf(stderr, "submit rejected\n");
            if (i < pending.size()) { w->step(); ++ticks_last; }
        }
        pending.clear();
    }
    void set_cell(int x, int y, ele::MaterialId m) { submit({ele::CommandType::SetCell, x, y, 0, 0, m, 0}); ids[y * 320 + x] = m; }
    void paint_tile(int tx, int ty, ele::MaterialId m) {
        submit({ele::CommandType::PaintRect, tx * TC, ty * TC, TC, TC, m, 0});
        for (int y = ty * TC; y < ty * TC + TC; ++y) for (int x = tx * TC; x < tx * TC + TC; ++x) ids[y * 320 + x] = m;
    }
    // Move box tile contents P -> Q (swap): Q gets crate, P gets Q's old cells.
    void swap_box(int px_, int py_, int qx, int qy) {
        std::vector<ele::MaterialId> old(TC * TC);
        for (int y = 0; y < TC; ++y) for (int x = 0; x < TC; ++x) old[y * TC + x] = at(qx * TC + x, qy * TC + y);
        paint_tile(qx, qy, m_crate);
        submit({ele::CommandType::ClearRect, px_ * TC, py_ * TC, TC, TC, 0, 0});
        for (int y = 0; y < TC; ++y) for (int x = 0; x < TC; ++x) ids[(py_ * TC + y) * 320 + px_ * TC + x] = 0;
        for (int y = 0; y < TC; ++y) for (int x = 0; x < TC; ++x) if (old[y * TC + x]) set_cell(px_ * TC + x, py_ * TC + y, old[y * TC + x]);
        if (g_wake) wake_neighbours(px_, py_);
    }
    // SDK known behaviour: sleeping liquid does not see a newly opened hole. Rewrite one fluid cell in each
    // neighbouring tile (below, left, right) so its chunk wakes and cells/liquid_pressure fill the hole.
    void wake_neighbours(int tx, int ty) {
        const int nx[3] = {tx, tx - 1, tx + 1}, ny[3] = {ty + 1, ty, ty};
        for (int k = 0; k < 3; ++k) {
            if (nx[k] < 0 || ny[k] < 0 || nx[k] >= TW || ny[k] >= TH) continue;
            for (int y = ny[k] * TC; y < ny[k] * TC + TC; ++y) { bool done = false;
                for (int x = nx[k] * TC; x < nx[k] * TC + TC; ++x) { auto m = at(x, y);
                    if (m && is_fluid[m]) { submit({ele::CommandType::SetCell, x, y, 0, 0, 0, 0}); submit({ele::CommandType::SetCell, x, y, 0, 0, m, 0}); done = true; break; } }
                if (done) break; }
        }
    }
    // Settle: step one tick at a time until g_quiet consecutive quiet ticks.
    long settle() {
        flush();
        long t = 0; int quiet = 0;
        while (t < g_max_ticks) {
            w->step(); ++t;
            const auto& s = w->stats();
            if (s.active_chunks == 0 && s.queue_size == 0) ++quiet; else quiet = 0;
            if (quiet >= g_quiet) break;
        }
        if (t >= g_max_ticks) log += "  !! settle hit max_ticks\n";
        return t;
    }
    // Water region (tile level, 4-connected WATER tiles) top row reachable from seeds.
    int water_top(const std::vector<std::pair<int,int>>& seeds) const {
        std::set<std::pair<int,int>> seen; std::vector<std::pair<int,int>> st; int top = 1 << 30;
        for (auto s : seeds) if (cls(s.first, s.second) == WATER && !seen.count(s)) { seen.insert(s); st.push_back(s); }
        while (!st.empty()) { auto [x, y] = st.back(); st.pop_back(); top = std::min(top, y);
            const int dx[4] = {1, -1, 0, 0}, dy[4] = {0, 0, 1, -1};
            for (int k = 0; k < 4; ++k) { std::pair<int,int> n{x + dx[k], y + dy[k]};
                if (!seen.count(n) && cls(n.first, n.second) == WATER) { seen.insert(n); st.push_back(n); } } }
        return top;
    }
    bool box_supported(const Box& b) const {
        int x = b.x, y = b.y + 1; auto k = cls(x, y);
        if (k == SOLID || k == SAND || k == BOX) return true;
        if (px == x && py == y) return true;
        if (b.floats && counts(x, y).f >= g_support) return true;
        return false;
    }
    bool player_supported() const {
        if (ladder(px, py) || ladder(px, py + 1)) return true;
        auto k = cls(px, py + 1); return k == SOLID || k == SAND || k == BOX;
    }
    // One resolution pass; returns true if anything changed.
    bool resolve() {
        bool changed = false;
        if (crumble_pending) {
            crumble_pending = false;
            for (int ty = (blast_cy - 20) / TC; ty <= (blast_cy + 20) / TC; ++ty) for (int tx = (blast_cx - 20) / TC; tx <= (blast_cx + 20) / TC; ++tx) {
                if (tx < 0 || ty < 0 || tx >= TW || ty >= TH) continue;
                auto c = counts(tx, ty);
                if (c.brk > 0 && c.brk < 128) {
                    for (int y = ty * TC; y < ty * TC + TC; ++y) for (int x = tx * TC; x < tx * TC + TC; ++x) if (is_breakable[at(x, y)]) set_cell(x, y, 0);
                    log += "  crumble tile (" + std::to_string(tx - ox) + "," + std::to_string(ty - oy) + ") left " + std::to_string(c.brk) + "\n";
                    changed = true;
                }
            }
        }
        std::vector<int> order(boxes.size()); for (size_t i = 0; i < order.size(); ++i) order[i] = int(i);
        std::sort(order.begin(), order.end(), [&](int a, int b) { return std::tuple(-boxes[a].y, boxes[a].x) < std::tuple(-boxes[b].y, boxes[b].x); });
        for (int i : order) {
            auto& b = boxes[i];
            if (!box_supported(b)) {
                while (!box_supported(b)) { swap_box(b.x, b.y, b.x, b.y + 1); b.y += 1; }
                log += "  box " + b.id + " falls to (" + std::to_string(b.x - ox) + "," + std::to_string(b.y - oy) + ")\n"; changed = true; continue;
            }
            if (!b.floats) continue;
            bool above_free = enterable(b.x, b.y - 1) && !(px == b.x && py == b.y - 1);
            if (!above_free) continue;
            bool rise = false;
            if (cls(b.x, b.y + 1) == WATER && water_top({{b.x, b.y + 1}}) <= b.y) rise = true;
            else if (water_top({{b.x - 1, b.y}, {b.x + 1, b.y}}) <= b.y - 1) rise = true;
            if (rise) { swap_box(b.x, b.y, b.x, b.y - 1); b.y -= 1; changed = true;
                log += "  box " + b.id + " rises to (" + std::to_string(b.x - ox) + "," + std::to_string(b.y - oy) + ")\n"; }
        }
        auto pk = cls(px, py);
        if (pk == SOLID || pk == SAND) {
            int y = py - 1; while (y >= 0 && !enterable(px, y)) --y;
            if (y < 0) log += "  !! player buried with no way up\n"; else { py = y; changed = true; log += "  player pushed up\n"; }
        }
        if (!player_supported()) { while (!player_supported() && enterable(px, py + 1)) ++py; changed = true; }
        for (auto& g : gates) {
            bool want = g.cond();
            if (want && !g.open) { for (auto [tx, ty] : g.tiles) { submit({ele::CommandType::ClearRect, tx * TC, ty * TC, TC, TC, 0, 0});
                    for (int y = ty * TC; y < ty * TC + TC; ++y) for (int x = tx * TC; x < tx * TC + TC; ++x) ids[y * 320 + x] = 0; }
                g.open = true; changed = true; log += "  gate " + g.id + " opens\n"; }
            if (!want && g.open) {
                int stuff = 0; bool occupied = false;
                for (auto [tx, ty] : g.tiles) { auto c = counts(tx, ty); stuff += 256 - c.empty; if (box_at(tx, ty) || (px == tx && py == ty)) occupied = true; }
                if (!occupied && stuff <= g_crush) { for (auto [tx, ty] : g.tiles) paint_tile(tx, ty, m_gate); g.open = false; changed = true;
                    log += "  gate " + g.id + " closes (crushed " + std::to_string(stuff) + ")\n"; }
                else log += "  gate " + g.id + " close deferred (" + std::to_string(stuff) + " cells" + (occupied ? ", occupied" : "") + ")\n";
            }
        }
        return changed;
    }
    void turn() {
        ticks_last = 0; rounds_last = 0;
        // Oscillation check: configurations are recorded only after rounds in which a box or the player moved.
        auto key = [&] { std::vector<int> k{px, py}; for (auto& b : boxes) { k.push_back(b.x); k.push_back(b.y); }
                         for (auto& g2 : gates) k.push_back(g2.open); for (auto& l : levers) k.push_back(l.on); return k; };
        std::set<std::vector<int>> seen{key()};
        for (int round = 0; round < g_max_rounds; ++round) {
            ticks_last += settle(); ++rounds_last;
            read_world();
            std::vector<int> before{px, py}; for (auto& b : boxes) { before.push_back(b.x); before.push_back(b.y); }
            if (!resolve()) break;
            std::vector<int> after{px, py}; for (auto& b : boxes) { after.push_back(b.x); after.push_back(b.y); }
            if (after != before && !seen.insert(key()).second) { log += "  !! oscillation: configuration repeated after a move, stop\n"; flush(); break; }
            if (round == g_max_rounds - 1) log += "  !! max_rounds reached\n";
        }
        ticks_total += ticks_last;
    }
    bool won() const { for (auto t : targets) if (!box_at(t.first, t.second)) return false; return boxes.size() == targets.size(); }
    // --- actions ---
    bool act(const std::string& a) {
        auto dir = [&](char c) { return c == 'L' ? -1 : 1; };
        if (a == "L" || a == "R") {
            int d = dir(a[0]), tx = px + d;
            if (enterable(tx, py)) { px = tx; return true; }
            if (cls(tx, py) == BOX) {
                bool box_on_top = box_at(tx, py - 1);
                if (!box_on_top && enterable(tx + d, py) && true) {
                    for (auto& b : boxes) if (b.x == tx && b.y == py) { swap_box(b.x, b.y, b.x + d, b.y); b.x += d; }
                    px = tx; return true;
                }
            }
            if (enterable(px, py - 1) && enterable(tx, py - 1)) { px = tx; py -= 1; return true; }  // step up
            return false;
        }
        if (a == "U") { if (ladder(px, py) && enterable(px, py - 1)) { py -= 1; return true; } return false; }
        if (a == "D") { if (ladder(px, py + 1) && enterable(px, py + 1)) { py += 1; return true; } return false; }
        if (a.rfind("DIG_", 0) == 0) {
            int tx = px, ty = py; if (a[4] == 'L') tx--; else if (a[4] == 'R') tx++; else ty++;
            if (cls(tx, ty) != SAND) return false;
            long n = 0;
            for (int y = ty * TC; y < ty * TC + TC; ++y) for (int x = tx * TC; x < tx * TC + TC; ++x) if (is_loose[at(x, y)]) { set_cell(x, y, 0); ++n; }
            bag += n; log += "  dug " + std::to_string(n) + "\n"; return true;
        }
        if (a.rfind("POUR_", 0) == 0) {
            int tx = px + dir(a[5]), ty = py;
            if (!enterable(tx, ty) || bag <= 0) return false;
            long n = 0;
            for (int y = ty * TC; y < ty * TC + TC && n < bag && n < 256; ++y) for (int x = tx * TC; x < tx * TC + TC && n < bag && n < 256; ++x)
                if (at(x, y) == 0) { set_cell(x, y, m_sand); ++n; }
            if (n == 0) return false;
            bag -= n; log += "  poured " + std::to_string(n) + "\n"; return true;
        }
        if (a.rfind("BOMB_", 0) == 0) {
            if (bombs <= 0) return false;
            int tx = px, ty = py; if (a[5] == 'L') tx--; else if (a[5] == 'R') tx++; else ty++;
            blast_cx = tx * TC + 8; blast_cy = ty * TC + 8;
            submit({ele::CommandType::Explode, blast_cx, blast_cy, 20, 8000}); --bombs; crumble_pending = true; return true;
        }
        if (a == "USE") { for (auto& l : levers) if (l.x == px && l.y == py) { l.on = !l.on; return true; } return false; }
        return false;
    }
    std::string grid() const {
        std::string s;
        for (int y = oy; y < TH; ++y) {
            bool any = false; for (int x = ox; x < TW; ++x) if (cls(x, y) != SOLID) any = true;
            if (!any && y > oy + 8) break;
            for (int x = ox; x < std::min(TW, ox + 12); ++x) {
                char ch = cls_char[cls(x, y)];
                if (px == x && py == y) ch = '@';
                s += ch;
            }
            s += "\n";
        }
        return s;
    }
    std::string tile_info(int lx, int ly) const {
        auto c = counts(lx + ox, ly + oy);
        char buf[96]; std::snprintf(buf, sizeof buf, "(%d,%d)%c solid %d loose %d fluid %d", lx, ly, cls_char[cls(lx + ox, ly + oy)], c.s, c.l, c.f);
        return buf;
    }
};

Level level(const std::string& name) {
    Level L; L.name = name;
    if (name == "D1") {
        L.map = {"##########", "#........#", "#........#", "#.####.###", "#.####.###", "##########"};
        L.px = 1; L.py = 4; L.boxes = {{"A", 3, 2, true}}; L.targets = {{6, 4}}; L.ladders = {{1, 2}, {1, 3}, {1, 4}};
        L.solution = {"U", "U", "R", "R", "R", "R"};
    } else if (name == "D2") {
        L.map = {"##########", "#........#", "#........#", "#....###.#", "#ss..###.#", "##########"};
        L.px = 3; L.py = 4; L.boxes = {{"A", 6, 2, true}}; L.targets = {{8, 4}};
        L.solution = {"DIG_L", "POUR_R", "R", "R", "R", "R"};
    } else if (name == "D3") {
        L.map = {"###########", "#......#..#", "#......#ww#", "#......#ww#", "#####.##ww#", "#####.##ww#", "#####..Gww#", "###########"};
        L.px = 1; L.py = 3; L.boxes = {{"A", 5, 6, true}}; L.targets = {{2, 3}}; L.ladders = {{5, 4}, {5, 5}, {5, 6}};
        L.levers = {{"L1", 6, 3, false}};
        L.solution = {"R", "R", "R", "R", "R", "USE", "L", "L", "L"};
    } else if (name == "D4") {
        L.map = {"############", "#.....G....#", "#.....G..c.#", "#####.######", "############"};
        L.px = 1; L.py = 2; L.boxes = {{"A", 3, 2, true}, {"B", 8, 2, true}}; L.targets = {{5, 3}, {7, 2}}; L.bombs = 1;
        L.solution = {"R", "R", "R", "R", "R", "R", "R", "R", "R", "BOMB_L", "L", "L"};
    } else if (name == "D5") {
        L.map = {"###########", "#s#.......#", "#sc.......#", "#s###.#.###", "#####w#w###", "#####www###", "#####w#####", "###########"};
        L.px = 3; L.py = 2; L.boxes = {{"A", 7, 3, true}}; L.targets = {{9, 2}}; L.ladders = {{5, 3}, {5, 4}, {7, 3}, {7, 4}}; L.bombs = 1;
        L.solution = {"BOMB_L", "L", "DIG_L", "L", "DIG_D", "R", "R", "R", "POUR_R", "POUR_R", "R", "R", "R", "R"};
    }
    return L;
}

void setup(Game& g, ele::World& w, const Level& L) {
    g.w = &w; g.init_tags();
    int lw = int(L.map[0].size()), lh = int(L.map.size());
    g.ox = (TW - lw) / 2; g.oy = (TH - lh) / 2;
    rect(w, 0, 0, 320, 192, "bedrock");
    for (int y = 0; y < lh; ++y) for (int x = 0; x < lw; ++x) {
        char c = L.map[y][x]; const char* m = c == '#' ? "bedrock" : c == 's' ? "sand" : c == 'w' ? "water" : c == 'c' ? "cracked_rock" : c == 'G' ? "gate" : nullptr;
        int tx = (g.ox + x) * TC, ty = (g.oy + y) * TC;
        if (m) rect(w, tx, ty, TC, TC, m); else clear(w, tx, ty, TC, TC);
    }
    for (auto b : L.boxes) { b.x += g.ox; b.y += g.oy; g.boxes.push_back(b); rect(w, b.x * TC, b.y * TC, TC, TC, "crate"); }
    for (auto t : L.targets) g.targets.insert({t.first + g.ox, t.second + g.oy});
    for (auto t : L.ladders) g.ladders.insert({t.first + g.ox, t.second + g.oy});
    for (auto l : L.levers) { l.x += g.ox; l.y += g.oy; g.levers.push_back(l); }
    g.px = L.px + g.ox; g.py = L.py + g.oy; g.bombs = L.bombs; g.bag = g_bag;
    Game* gp = &g;
    if (L.name == "D3") g.gates.push_back({"g1", {{7 + g.ox, 6 + g.oy}}, [gp]() { return gp->levers[0].on; }});
    if (L.name == "D4") { int plx = 5 + g.ox, ply = 3 + g.oy;
        g.gates.push_back({"g1", {{6 + g.ox, 1 + g.oy}, {6 + g.ox, 2 + g.oy}}, [gp, plx, ply]() { return gp->box_at(plx, ply) || (gp->px == plx && gp->py == ply); }}); }
}

int run(const std::string& name, const std::string& profile, std::vector<std::string> solution = {}, std::vector<std::pair<int,int>> watch = {}) {
    auto c = load("content/pushbox", profile);
    auto w = make_world(c, 320, 192, 1, g_threads);
    Level L = level(name); if (!solution.empty()) L.solution = solution;
    Game g; setup(g, *w, L);
    g.turn();  // settle the opening state
    std::printf("== %s (profile %s, T=%d, support=%d, quiet=%d) start: %ld ticks\n", name.c_str(), profile.c_str(), g_threshold, g_support, g_quiet, g.ticks_last);
    if (g_verbose) std::printf("%s", g.grid().c_str());
    int step = 0;
    for (auto& a : L.solution) {
        ++step; g.log.clear();
        bool ok = g.act(a);
        if (!ok) { std::printf("step %d %s: NOT ALLOWED\n", step, a.c_str()); if (g_verbose) std::printf("%s", g.grid().c_str()); return 1; }
        g.turn();
        std::printf("step %2d %-7s player (%d,%d) bag %ld ticks %ld rounds %d", step, a.c_str(), g.px - g.ox, g.py - g.oy, g.bag, g.ticks_last, g.rounds_last);
        for (auto& b : g.boxes) std::printf(" %s(%d,%d)", b.id.c_str(), b.x - g.ox, b.y - g.oy);
        std::printf("\n%s", g.log.c_str());
        for (auto t : watch) std::printf("    %s\n", g.tile_info(t.first, t.second).c_str());
        if (g_verbose) std::printf("%s", g.grid().c_str());
    }
    std::printf("%s %s total ticks %ld hash %016llx\n", name.c_str(), g.won() ? "WIN" : "NOT SOLVED", g.ticks_total, (unsigned long long)w->state_hash());
    return g.won() ? 0 : 1;
}
}

int main(int argc, char** argv) {
    std::string which = "all", profile = "profile.json"; std::vector<std::string> custom;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--profile") profile = argv[++i];
        else if (a == "--quiet") g_quiet = std::atoi(argv[++i]);
        else if (a == "--t") g_threshold = std::atoi(argv[++i]);
        else if (a == "--sup") g_support = std::atoi(argv[++i]);
        else if (a == "--verbose") g_verbose = true;
        else if (a == "--nowake") g_wake = false;
        else if (a == "--threads") g_threads = std::atoi(argv[++i]);
        else if (a == "--bag") g_bag = std::atol(argv[++i]);
        else if (a == "--solution") { std::string sol = argv[++i]; std::vector<std::string> v; std::stringstream ss(sol); std::string t; while (std::getline(ss, t, ',')) v.push_back(t); custom = v; }
        else which = a;
    }
    std::map<std::string, std::vector<std::pair<int,int>>> watch = {
        {"D2", {{4, 4}, {3, 4}}}, {"D3", {{5, 4}, {8, 3}, {8, 4}, {6, 6}}}, {"D4", {{9, 2}}},
        {"D5", {{1, 1}, {1, 2}, {1, 3}, {2, 2}, {5, 3}, {7, 3}, {5, 2}}}};
    int fails = 0;
    for (std::string n : {"D1", "D2", "D3", "D4", "D5"}) if (which == "all" || which == n) fails += run(n, profile, custom, watch[n]);
    return fails;
}
