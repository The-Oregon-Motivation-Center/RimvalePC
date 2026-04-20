#ifndef RIMVALE_DUNGEON_H
#define RIMVALE_DUNGEON_H

#include <vector>
#include <random>
#include <string>
#include <algorithm>
#include <queue>
#include <set>
#include <map>
#include <memory>
#include <cstdint>
#include "Creature.h"
#include "CombatManager.h"
#include "ItemRegistry.h"
#include "Character.h"
#include "CharacterRegistry.h"
#include "CreatureRegistry.h"
#include "Mob.h"
#include "Militia.h"

namespace rimvale {

enum class TileType {
    Floor = 0,
    Wall = 1,
    Obstacle = 2
};

enum class TerrainStyle {
    Cave = 0,
    Open = 1,
    Dense = 2,
    Urban = 3,
    Volcanic = 4,
    Aquatic = 5,
    Arcane = 6,
    Necromantic = 7
};

struct Vector2i {
    int x;
    int y;

    bool operator==(const Vector2i& other) const { return x == other.x && y == other.y; }
    bool operator<(const Vector2i& other) const { return x != other.x ? x < other.x : y < other.y; }
    bool operator!=(const Vector2i& other) const { return !(*this == other); }
};

class DungeonMap {
public:
    static constexpr int SIZE = 25;

    explicit DungeonMap(TerrainStyle style = TerrainStyle::Cave)
        : grid_(SIZE, std::vector<TileType>(SIZE, TileType::Floor)),
          elevation_(SIZE, std::vector<int>(SIZE, 1)),
          style_(style) {
        generate();
    }

    void generate() {
        if (style_ == TerrainStyle::Urban) {
            generate_urban();
        } else {
            initialize_grid();
            int iterations = ca_iterations();
            apply_cellular_automata(iterations);
            ensure_connectivity({1, 1}, {SIZE - 3, SIZE - 3});
        }
        generate_elevation();
    }

    [[nodiscard]] TileType get_tile(int x, int y) const {
        if (x < 0 || x >= SIZE || y < 0 || y >= SIZE) return TileType::Wall;
        return grid_[y][x];
    }

    [[nodiscard]] bool is_walkable(int x, int y) const { return get_tile(x, y) == TileType::Floor; }
    [[nodiscard]] bool is_opaque(int x, int y) const {
        TileType t = get_tile(x, y);
        return t == TileType::Wall || t == TileType::Obstacle;
    }

    // Returns elevation level: 0 = sunken, 1 = ground, 2 = raised
    [[nodiscard]] int get_elevation(int x, int y) const {
        if (x < 0 || x >= SIZE || y < 0 || y >= SIZE) return 1;
        return elevation_[y][x];
    }

private:
    std::vector<std::vector<TileType>> grid_;
    std::vector<std::vector<int>> elevation_;
    TerrainStyle style_;

    double obstacle_density() const {
        switch (style_) {
            case TerrainStyle::Open:       return 0.18;
            case TerrainStyle::Dense:      return 0.62;
            case TerrainStyle::Volcanic:   return 0.38;
            case TerrainStyle::Aquatic:    return 0.28;
            case TerrainStyle::Arcane:     return 0.42;
            case TerrainStyle::Necromantic:return 0.52;
            case TerrainStyle::Cave:
            default:                       return 0.45;
        }
    }

    int ca_iterations() const {
        switch (style_) {
            case TerrainStyle::Open:       return 2;
            case TerrainStyle::Dense:      return 5;
            case TerrainStyle::Volcanic:   return 3;
            case TerrainStyle::Aquatic:    return 3;
            case TerrainStyle::Arcane:     return 3;
            case TerrainStyle::Necromantic:return 4;
            case TerrainStyle::Cave:
            default:                       return 4;
        }
    }

    void initialize_grid() {
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<> prob(0.0, 1.0);
        double density = obstacle_density();

        for (int y = 0; y < SIZE; ++y) {
            for (int x = 0; x < SIZE; ++x) {
                if (is_protected_zone(x, y)) {
                    grid_[y][x] = TileType::Floor;
                } else {
                    grid_[y][x] = (prob(gen) < density) ? TileType::Obstacle : TileType::Floor;
                }
            }
        }
    }

    // Urban: carve rectangular rooms connected by corridors
    void generate_urban() {
        // Fill everything with obstacle first
        for (int y = 0; y < SIZE; ++y)
            for (int x = 0; x < SIZE; ++x)
                grid_[y][x] = TileType::Obstacle;

        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> roomX(2, SIZE - 8);
        std::uniform_int_distribution<> roomY(2, SIZE - 8);
        std::uniform_int_distribution<> roomW(3, 7);
        std::uniform_int_distribution<> roomH(3, 6);

        struct Room { int x, y, w, h;
            int cx() const { return x + w/2; }
            int cy() const { return y + h/2; } };
        std::vector<Room> rooms;

        for (int attempt = 0; attempt < 20; ++attempt) {
            Room r { roomX(gen), roomY(gen), roomW(gen), roomH(gen) };
            if (r.x + r.w >= SIZE - 1 || r.y + r.h >= SIZE - 1) continue;
            // Check overlap
            bool overlaps = false;
            for (const auto& existing : rooms) {
                if (r.x < existing.x + existing.w + 1 && r.x + r.w + 1 > existing.x &&
                    r.y < existing.y + existing.h + 1 && r.y + r.h + 1 > existing.y) {
                    overlaps = true; break;
                }
            }
            if (overlaps) continue;
            // Carve room
            for (int ry = r.y; ry < r.y + r.h; ++ry)
                for (int rx = r.x; rx < r.x + r.w; ++rx)
                    grid_[ry][rx] = TileType::Floor;
            rooms.push_back(r);
        }

        // Connect rooms with L-shaped corridors
        for (size_t i = 1; i < rooms.size(); ++i) {
            int x1 = rooms[i-1].cx(), y1 = rooms[i-1].cy();
            int x2 = rooms[i].cx(),   y2 = rooms[i].cy();
            // Horizontal then vertical
            int cx = x1;
            while (cx != x2) {
                if (cx >= 0 && cx < SIZE && y1 >= 0 && y1 < SIZE) grid_[y1][cx] = TileType::Floor;
                cx += (x2 > x1) ? 1 : -1;
            }
            int cy = y1;
            while (cy != y2) {
                if (x2 >= 0 && x2 < SIZE && cy >= 0 && cy < SIZE) grid_[cy][x2] = TileType::Floor;
                cy += (y2 > y1) ? 1 : -1;
            }
        }

        // Ensure start/end corners are walkable
        for (int y = 1; y <= 3; ++y) for (int x = 1; x <= 3; ++x) grid_[y][x] = TileType::Floor;
        for (int y = SIZE-4; y < SIZE-1; ++y) for (int x = SIZE-4; x < SIZE-1; ++x) grid_[y][x] = TileType::Floor;
    }

    bool is_protected_zone(int x, int y) const {
        return (x <= 3 && y <= 3) || (x >= SIZE - 4 && y >= SIZE - 4);
    }

    void apply_cellular_automata(int iterations) {
        for (int i = 0; i < iterations; ++i) {
            std::vector<std::vector<TileType>> next_grid = grid_;
            for (int y = 0; y < SIZE; ++y) {
                for (int x = 0; x < SIZE; ++x) {
                    if (is_protected_zone(x, y)) continue;
                    int neighbors = count_neighbors(x, y, TileType::Obstacle);
                    if (neighbors > 4) next_grid[y][x] = TileType::Obstacle;
                    else if (neighbors < 4) next_grid[y][x] = TileType::Floor;
                }
            }
            grid_ = next_grid;
        }
    }

    int count_neighbors(int x, int y, TileType type) const {
        int count = 0;
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                if (dx == 0 && dy == 0) continue;
                if (get_tile(x + dx, y + dy) == type) count++;
            }
        }
        return count;
    }

    void ensure_connectivity(Vector2i start, Vector2i target) {
        auto visited = flood_fill(start);
        if (visited.find(target) == visited.end()) {
            dig_tunnel(start, target);
            visited = flood_fill(start);
        }

        for (int y = 0; y < SIZE; ++y) {
            for (int x = 0; x < SIZE; ++x) {
                if (grid_[y][x] == TileType::Floor && visited.find({x, y}) == visited.end()) {
                    grid_[y][x] = TileType::Obstacle;
                }
            }
        }
    }

    std::set<Vector2i> flood_fill(Vector2i start) {
        std::set<Vector2i> visited;
        std::queue<Vector2i> q;
        if (is_walkable(start.x, start.y)) {
            q.push(start);
            visited.insert(start);
        }
        while (!q.empty()) {
            Vector2i curr = q.front(); q.pop();
            Vector2i dirs[] = {{0,1}, {0,-1}, {1,0}, {-1,0}, {1,1}, {1,-1}, {-1,1}, {-1,-1}};
            for (auto d : dirs) {
                Vector2i next = {curr.x + d.x, curr.y + d.y};
                if (is_walkable(next.x, next.y) && visited.find(next) == visited.end()) {
                    visited.insert(next);
                    q.push(next);
                }
            }
        }
        return visited;
    }

    void dig_tunnel(Vector2i start, Vector2i end) {
        int cx = start.x, cy = start.y;
        while (cx != end.x || cy != end.y) {
            if (cx < end.x) cx++; else if (cx > end.x) cx--;
            if (cy < end.y) cy++; else if (cy > end.y) cy--;
            grid_[cy][cx] = TileType::Floor;
        }
    }

    void apply_elevation_blob(int cx, int cy, int radius, int level, std::mt19937& gen) {
        std::uniform_int_distribution<> jitter(-1, 1);
        for (int dy = -(radius + 1); dy <= (radius + 1); ++dy) {
            for (int dx = -(radius + 1); dx <= (radius + 1); ++dx) {
                int x = cx + dx, y = cy + dy;
                if (x < 1 || x >= SIZE - 1 || y < 1 || y >= SIZE - 1) continue;
                int r = radius + jitter(gen);
                if (dx * dx + dy * dy <= r * r)
                    elevation_[y][x] = level;
            }
        }
    }

    void generate_elevation() {
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> coord(3, SIZE - 4);
        std::uniform_int_distribution<> radius(2, 3);
        std::uniform_int_distribution<> count(2, 3);

        int raised = count(gen);
        for (int i = 0; i < raised; ++i)
            apply_elevation_blob(coord(gen), coord(gen), radius(gen), 2, gen);

        int sunken = count(gen);
        for (int i = 0; i < sunken; ++i)
            apply_elevation_blob(coord(gen), coord(gen), radius(gen), 0, gen);
    }
};

struct DungeonEntity {
    std::string id;
    std::string name;
    Vector2i position;
    bool is_player;
    int64_t handle;
    bool is_dead = false;     // corpse: entity died, body remains on map
    bool is_friendly = false; // allied creature (summon, raised undead)
};

class DungeonManager {
public:
    static DungeonManager& instance() {
        static DungeonManager manager;
        return manager;
    }

    bool find_walkable_spawn(std::uniform_int_distribution<>& dis, std::mt19937& gen, int& out_x, int& out_y);
    void spawn_players(const std::vector<int64_t>& player_handles);
    void spawn_enemies(int summoner_level, int64_t specific_enemy_handle);
    void spawn_kaiju(int kaiju_index);
    void spawn_apex(int apex_index);
    void spawn_militia(int militia_index);
    void spawn_mob(int member_count, int level, CreatureCategory cat,
                   MobTrait trait, MobLeaderType leader, MobMood mood);

    void start_militia_dungeon(const std::vector<int64_t>& player_handles, int militia_index, int terrain_style = 0) {
        for (auto& monster : spawned_monsters_) {
            CreatureRegistry::instance().unregister_creature(reinterpret_cast<int64_t>(monster.get()));
        }
        entities_.clear();
        spawned_monsters_.clear();

        map_ = std::make_unique<DungeonMap>(static_cast<TerrainStyle>(terrain_style));

        CombatManager::instance().set_dungeon_mode(true);
        CombatManager::instance().clear_combatants();

        spawn_players(player_handles);
        spawn_militia(militia_index);

        CombatManager::instance().start_combat();
    }

    void start_apex_dungeon(const std::vector<int64_t>& player_handles, int apex_index, int terrain_style = 0) {
        for (auto& monster : spawned_monsters_) {
            CreatureRegistry::instance().unregister_creature(reinterpret_cast<int64_t>(monster.get()));
        }
        entities_.clear();
        spawned_monsters_.clear();

        map_ = std::make_unique<DungeonMap>(static_cast<TerrainStyle>(terrain_style));

        CombatManager::instance().set_dungeon_mode(true);
        CombatManager::instance().clear_combatants();

        spawn_players(player_handles);
        spawn_apex(apex_index);

        CombatManager::instance().start_combat();
    }

    void start_kaiju_dungeon(const std::vector<int64_t>& player_handles, int kaiju_index, int terrain_style = 0) {
        for (auto& monster : spawned_monsters_) {
            CreatureRegistry::instance().unregister_creature(reinterpret_cast<int64_t>(monster.get()));
        }
        entities_.clear();
        spawned_monsters_.clear();

        map_ = std::make_unique<DungeonMap>(static_cast<TerrainStyle>(terrain_style));

        CombatManager::instance().set_dungeon_mode(true);
        CombatManager::instance().clear_combatants();

        spawn_players(player_handles);
        spawn_kaiju(kaiju_index);

        CombatManager::instance().start_combat();
    }

    // mob_count: total members; mob_level: enemy level 1-10; trait/leader/mood packed as ints
    void start_mob_dungeon(const std::vector<int64_t>& player_handles,
                           int mob_count, int mob_level,
                           int terrain_style = 0,
                           int trait_idx = static_cast<int>(MobTrait::Unstoppable),
                           int leader_idx = static_cast<int>(MobLeaderType::None),
                           int mood_idx   = static_cast<int>(MobMood::Enraged)) {
        for (auto& monster : spawned_monsters_) {
            CreatureRegistry::instance().unregister_creature(reinterpret_cast<int64_t>(monster.get()));
        }
        entities_.clear();
        spawned_monsters_.clear();

        map_ = std::make_unique<DungeonMap>(static_cast<TerrainStyle>(terrain_style));

        CombatManager::instance().set_dungeon_mode(true);
        CombatManager::instance().clear_combatants();

        spawn_players(player_handles);
        spawn_mob(mob_count, mob_level,
                  CreatureCategory::Monster,
                  static_cast<MobTrait>(trait_idx),
                  static_cast<MobLeaderType>(leader_idx),
                  static_cast<MobMood>(mood_idx));

        CombatManager::instance().start_combat();
    }

    void start_new_dungeon(const std::vector<int64_t>& player_handles, int enemy_level = 1, int64_t specific_enemy_handle = 0, int terrain_style = 0) {
        for (auto& monster : spawned_monsters_) {
            CreatureRegistry::instance().unregister_creature(reinterpret_cast<int64_t>(monster.get()));
        }
        entities_.clear();
        spawned_monsters_.clear();

        map_ = std::make_unique<DungeonMap>(static_cast<TerrainStyle>(terrain_style));

        CombatManager::instance().set_dungeon_mode(true);
        CombatManager::instance().clear_combatants();

        spawn_players(player_handles);
        spawn_enemies(enemy_level, specific_enemy_handle);

        CombatManager::instance().start_combat();
    }

    [[nodiscard]] const DungeonMap* get_map() const { return map_.get(); }
    [[nodiscard]] const std::vector<DungeonEntity>& get_entities() const { return entities_; }

    void remove_dead_entities() {
        // Mark dead entities as corpses instead of removing them — they stay on the map
        for (auto& e : entities_) {
            if (e.is_dead) continue;
            bool just_died = false;
            if (e.is_player) {
                auto* c = CharacterRegistry::instance().get_character_by_handle(e.handle);
                if (!c || c->current_hp_ <= 0) just_died = true;
            } else {
                auto* c = CreatureRegistry::instance().get_creature(e.handle);
                if (!c || c->get_current_hp() <= 0) just_died = true;
            }
            if (just_died) e.is_dead = true;
        }
    }

    bool move_entity(const std::string& id, int nx, int ny) {
        auto it = std::find_if(entities_.begin(), entities_.end(), [&](const DungeonEntity& e) { return e.id == id; });
        if (it == entities_.end() || !map_) return false;

        bool intangible = false;
        auto* combatant = rimvale::CombatManager::instance().find_combatant_by_id(id);
        if (combatant) {
            auto* status = (combatant->is_player && combatant->player_ptr)
                ? &combatant->player_ptr->get_status()
                : (combatant->creature_ptr ? &combatant->creature_ptr->get_status() : nullptr);
            if (status) intangible = status->has_condition(ConditionType::Intangible);
        }

        bool mover_is_player_team = it->is_player || it->is_friendly;
        bool target_walkable = map_->is_walkable(nx, ny);
        // Dead entities and same-team allies don't block movement — only live enemies do
        bool target_blocked = std::any_of(entities_.begin(), entities_.end(), [&](const DungeonEntity& e) {
            if (e.id == id || e.is_dead) return false;
            if (e.position.x != nx || e.position.y != ny) return false;
            bool e_is_player_team = e.is_player || e.is_friendly;
            return e_is_player_team != mover_is_player_team;
        });

        if ((target_walkable || intangible) && !target_blocked) {
            it->position = {nx, ny};
            return true;
        }
        return false;
    }

    [[nodiscard]] Vector2i get_entity_position(const std::string& id) const {
        auto it = std::find_if(entities_.begin(), entities_.end(), [&](const DungeonEntity& e) { return e.id == id; });
        if (it != entities_.end()) return it->position;
        return {-1, -1};
    }

    [[nodiscard]] int get_distance(const std::string& id1, const std::string& id2) const {
        Vector2i p1 = get_entity_position(id1);
        Vector2i p2 = get_entity_position(id2);
        if (p1.x == -1 || p2.x == -1) return 999;
        return std::max(std::abs(p1.x - p2.x), std::abs(p1.y - p2.y)); // Chebyshev distance for 8-way movement
    }

    [[nodiscard]] int get_distance_to_point(const std::string& id, int tx, int ty) const {
        Vector2i p1 = get_entity_position(id);
        if (p1.x == -1) return 999;
        return std::max(std::abs(p1.x - tx), std::abs(p1.y - ty));
    }

    [[nodiscard]] std::vector<std::string> get_entities_in_area(int cx, int cy, int radius) const {
        std::vector<std::string> result;
        for (const auto& e : entities_)
            if (!e.is_dead && std::abs(e.position.x - cx) <= radius && std::abs(e.position.y - cy) <= radius)
                result.push_back(e.id);
        return result;
    }

    // Returns the entity ID of the nearest dead body within radius tiles of (cx, cy), or "" if none.
    [[nodiscard]] std::string find_dead_entity_near(int cx, int cy, int radius = 2) const {
        for (const auto& e : entities_)
            if (e.is_dead && !e.is_player && std::abs(e.position.x - cx) <= radius && std::abs(e.position.y - cy) <= radius)
                return e.id;
        return "";
    }

    // Raise a dead entity at/near (cx, cy) as a friendly ally. Returns true on success.
    bool raise_dead_at(int cx, int cy) {
        std::string dead_id = find_dead_entity_near(cx, cy, 2);
        if (dead_id.empty()) return false;

        auto it = std::find_if(entities_.begin(), entities_.end(), [&](const DungeonEntity& e){ return e.id == dead_id; });
        if (it == entities_.end()) return false;

        auto* creature = CreatureRegistry::instance().get_creature(it->handle);
        if (!creature) return false;

        it->is_dead = false;
        it->is_friendly = true;
        creature->heal(std::max(1, creature->get_max_hp() / 2));

        auto* comb = rimvale::CombatManager::instance().find_combatant_by_id(dead_id);
        if (comb) comb->is_friendly_summon = true;

        return true;
    }

    // Spawn a new summoned creature near (near_x, near_y). Returns the entity ID, or "" on failure.
    std::string spawn_summon(const std::string& name, int level, bool is_friendly_to_player, int near_x, int near_y) {
        if (!map_) return "";
        // Search expanding ring around caster for an empty walkable tile
        int spawn_x = -1, spawn_y = -1;
        for (int r = 1; r <= 5 && spawn_x == -1; ++r) {
            for (int dx = -r; dx <= r && spawn_x == -1; ++dx) {
                for (int dy = -r; dy <= r && spawn_x == -1; ++dy) {
                    if (std::abs(dx) != r && std::abs(dy) != r) continue;
                    int tx = near_x + dx, ty = near_y + dy;
                    if (!map_->is_walkable(tx, ty)) continue;
                    bool occ = std::any_of(entities_.begin(), entities_.end(), [&](const DungeonEntity& e){
                        return !e.is_dead && e.position.x == tx && e.position.y == ty;
                    });
                    if (!occ) { spawn_x = tx; spawn_y = ty; }
                }
            }
        }
        if (spawn_x == -1) return "";

        rimvale::Dice dice;
        auto monster = std::make_unique<Creature>(name, CreatureCategory::Monster, level);
        monster->reset_resources();

        static int summon_counter = 0;
        std::string m_id = "summon_" + std::to_string(++summon_counter);
        int64_t m_handle = reinterpret_cast<int64_t>(monster.get());

        DungeonEntity ent;
        ent.id = m_id; ent.name = monster->get_name();
        ent.position = {spawn_x, spawn_y};
        ent.is_player = false; ent.handle = m_handle;
        ent.is_dead = false; ent.is_friendly = is_friendly_to_player;
        entities_.push_back(ent);

        auto* raw = monster.get();
        rimvale::CombatManager::instance().add_creature(raw, dice, m_id);
        CreatureRegistry::instance().register_creature(raw);

        auto* comb = rimvale::CombatManager::instance().find_combatant_by_id(m_id);
        if (comb) comb->is_friendly_summon = is_friendly_to_player;

        spawned_monsters_.push_back(std::move(monster));
        return m_id;
    }

    std::vector<std::pair<Vector2i, int>> get_reachable_tiles(const std::string& id) {
        auto it = std::find_if(entities_.begin(), entities_.end(), [&](const DungeonEntity& e) { return e.id == id; });
        if (it == entities_.end() || !map_) return {};
        auto* combatant = rimvale::CombatManager::instance().find_combatant_by_id(id);
        if (!combatant) return {};

        bool intangible = false;
        {
            auto* status = (combatant->is_player && combatant->player_ptr)
                ? &combatant->player_ptr->get_status()
                : (combatant->creature_ptr ? &combatant->creature_ptr->get_status() : nullptr);
            if (status) intangible = status->has_condition(ConditionType::Intangible);
        }

        bool mover_is_player_team = it->is_player || it->is_friendly;
        int max_ap = 0;
        int initial_move = combatant->movement_tiles_remaining, refill = std::max(1, combatant->get_movement_speed() / 5);
        struct Node { Vector2i pos; int ap; int mv; };
        std::map<Vector2i, std::pair<int, int>> best;
        std::queue<Node> q; q.push({it->position, 0, initial_move});
        best[it->position] = {0, initial_move};

        while(!q.empty()){
            Node c = q.front(); q.pop();
            Vector2i dirs[] = {{0,1}, {0,-1}, {1,0}, {-1,0}, {1,1}, {1,-1}, {-1,1}, {-1,-1}};
            for(auto d : dirs){
                Vector2i n_pos = {c.pos.x + d.x, c.pos.y + d.y};
                bool n_obstacle = !map_->is_walkable(n_pos.x, n_pos.y);
                if (n_obstacle && !intangible) continue;

                // Classify what's on this tile
                bool n_live_enemy = false, n_live_ally = false;
                for (const auto& e : entities_) {
                    if (e.is_dead || e.position != n_pos) continue;
                    bool e_team = e.is_player || e.is_friendly;
                    if (e_team != mover_is_player_team) n_live_enemy = true;
                    else n_live_ally = true;
                }
                if (n_live_enemy && !intangible) continue; // enemies block

                int tile_cost = 1;
                if (n_obstacle || n_live_ally) tile_cost = 2; // ally/obstacle = difficult terrain
                if (map_) {
                    int e1 = map_->get_elevation(c.pos.x, c.pos.y);
                    int e2 = map_->get_elevation(n_pos.x, n_pos.y);
                    if (std::abs(e2 - e1) >= 1) tile_cost = std::max(tile_cost, 2);
                }
                int n_ap = c.ap, n_mv = c.mv;
                for (int tc = 0; tc < tile_cost; ++tc) {
                    if (n_mv > 0) n_mv--; else { n_ap++; n_mv = refill - 1; }
                }
                if (n_ap <= max_ap) {
                    if (best.find(n_pos) == best.end() || n_ap < best[n_pos].first || (n_ap == best[n_pos].first && n_mv > best[n_pos].second)) {
                        best[n_pos] = {n_ap, n_mv}; q.push({n_pos, n_ap, n_mv});
                    }
                }
            }
        }
        std::vector<std::pair<Vector2i, int>> res;
        for(auto const& [pos, stats] : best) {
            if(pos == it->position) continue;
            if (!map_->is_walkable(pos.x, pos.y)) continue;
            // Cannot stop on a live ally's tile (can pass through, not stop)
            bool has_live_ally = std::any_of(entities_.begin(), entities_.end(), [&](const DungeonEntity& e) {
                if (e.id == id || e.is_dead || e.position != pos) return false;
                bool e_team = e.is_player || e.is_friendly;
                return e_team == mover_is_player_team;
            });
            if (has_live_ally) continue;
            res.emplace_back(pos, stats.first);
        }
        return res;
    }

    std::vector<Vector2i> get_path(const std::string& id, int tx, int ty) {
        auto it = std::find_if(entities_.begin(), entities_.end(), [&](const DungeonEntity& e) { return e.id == id; });
        if (it == entities_.end() || !map_) return {};

        bool intangible = false;
        auto* combatant = rimvale::CombatManager::instance().find_combatant_by_id(id);
        if (combatant) {
            auto* status = (combatant->is_player && combatant->player_ptr)
                ? &combatant->player_ptr->get_status()
                : (combatant->creature_ptr ? &combatant->creature_ptr->get_status() : nullptr);
            if (status) intangible = status->has_condition(ConditionType::Intangible);
        }

        bool mover_is_player_team = it->is_player || it->is_friendly;
        std::map<Vector2i, Vector2i> parent;
        std::queue<Vector2i> q; q.push(it->position);
        std::set<Vector2i> visited = {it->position};
        bool found = false;
        while(!q.empty()){
            Vector2i c = q.front(); q.pop();
            if (c.x == tx && c.y == ty) { found = true; break; }
            Vector2i dirs[] = {{0,1}, {0,-1}, {1,0}, {-1,0}, {1,1}, {1,-1}, {-1,1}, {-1,-1}};
            for(auto d : dirs){
                Vector2i n = {c.x + d.x, c.y + d.y};
                bool n_walkable = map_->is_walkable(n.x, n.y);
                if (!n_walkable && !intangible) continue;
                if (visited.find(n) != visited.end()) continue;
                bool is_dest = (n.x == tx && n.y == ty);
                // Only live enemies block pathfinding; dead bodies and allies are passable
                bool has_blocking = std::any_of(entities_.begin(), entities_.end(), [&](const DungeonEntity& e) {
                    if (e.is_dead || e.position != n) return false;
                    bool e_team = e.is_player || e.is_friendly;
                    return e_team != mover_is_player_team;
                });
                if (is_dest || !has_blocking || intangible) {
                    visited.insert(n); parent[n] = c; q.push(n);
                }
            }
        }
        if(!found) return {};
        std::vector<Vector2i> path; Vector2i curr = {tx, ty};
        while(curr != it->position){ path.push_back(curr); curr = parent[curr]; }
        std::reverse(path.begin(), path.end());
        return path;
    }

    static bool is_player_phase() { return rimvale::CombatManager::instance().get_phase() == CombatPhase::Player; }

    [[nodiscard]] bool has_los(Vector2i start, Vector2i end) const {
        if (!map_) return true;
        int x1 = start.x, y1 = start.y, x2 = end.x, y2 = end.y;
        int dx = std::abs(x2 - x1), dy = std::abs(y2 - y1);
        int sx = (x1 < x2) ? 1 : -1, sy = (y1 < y2) ? 1 : -1;
        int err = dx - dy;
        while (true) {
            if (x1 == x2 && y1 == y2) break;
            if (map_->is_opaque(x1, y1) && !((x1 == start.x && y1 == start.y) || (x1 == end.x && y1 == end.y))) return false;
            int e2 = 2 * err;
            if (e2 > -dy) { err -= dy; x1 += sx; }
            if (e2 < dx) { err += dx; y1 += sy; }
        }
        return true;
    }

    // Returns false if any intermediate tile has elevation > attacker's elevation (high ground blocks shot).
    // Attackers on high ground (elev 2) can fire past other high-ground tiles at the same level.
    [[nodiscard]] bool has_ranged_los(Vector2i start, Vector2i end) const {
        if (!map_) return true;
        int attacker_elev = map_->get_elevation(start.x, start.y);
        int x1 = start.x, y1 = start.y, x2 = end.x, y2 = end.y;
        int dx = std::abs(x2 - x1), dy = std::abs(y2 - y1);
        int sx = (x1 < x2) ? 1 : -1, sy = (y1 < y2) ? 1 : -1;
        int err = dx - dy;
        while (true) {
            if (x1 == x2 && y1 == y2) break;
            bool is_start = (x1 == start.x && y1 == start.y);
            if (!is_start && map_->get_elevation(x1, y1) > attacker_elev) return false;
            int e2 = 2 * err;
            if (e2 > -dy) { err -= dy; x1 += sx; }
            if (e2 < dx) { err += dx; y1 += sy; }
        }
        return true;
    }

    std::vector<std::string> collect_loot(Character* player = nullptr) {
        std::vector<std::string> loot_log;
        for (auto& monster : spawned_monsters_) {
            if (monster && monster->get_current_hp() <= 0) {
                auto items = monster->get_inventory().take_all_items();
                int gold = monster->get_inventory().get_gold();
                for (auto& item : items) {
                    if (item) {
                        loot_log.push_back(item->get_name());
                        if (player) player->get_inventory().add_item(std::move(item));
                    }
                }
                if (gold > 0) {
                    loot_log.push_back(std::to_string(gold) + " Gold");
                    if (player) player->add_gold(gold);
                    monster->get_inventory().set_gold(0);
                }
            }
        }

        auto armor_names = ItemRegistry::instance().get_all_armor_names();
        if (!armor_names.empty()) {
            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_int_distribution<> dis(0, static_cast<int>(armor_names.size() - 1));
            const std::string& random_armor_name = armor_names[dis(gen)];
            auto armor = ItemRegistry::instance().create_armor(random_armor_name);
            if (armor) {
                loot_log.push_back(armor->get_name());
                if (player) {
                    player->get_inventory().add_item(std::move(armor));
                }
            }
        }

        return loot_log;
    }

private:
    DungeonManager() = default;
    std::unique_ptr<DungeonMap> map_;
    std::vector<DungeonEntity> entities_;
    std::vector<std::unique_ptr<Creature>> spawned_monsters_;
};

inline bool DungeonManager::find_walkable_spawn(std::uniform_int_distribution<>& dis, std::mt19937& gen, int& out_x, int& out_y) {
    for (int tries = 0; tries < 100; ++tries) {
        int tx = dis(gen), ty = dis(gen);
        if (map_ && map_->is_walkable(tx, ty)) {
            auto it = std::find_if(entities_.begin(), entities_.end(), [&](const DungeonEntity& e){ return e.position.x == tx && e.position.y == ty; });
            if (it == entities_.end()) { out_x = tx; out_y = ty; return true; }
        }
    }
    return false;
}

inline void DungeonManager::spawn_players(const std::vector<int64_t>& player_handles) {
    std::random_device rd;
    std::mt19937 gen(rd());
    // Prefer top-left quadrant (safe zone) for player spawns
    std::uniform_int_distribution<> topleft_dis(1, DungeonMap::SIZE / 2 - 1);
    std::uniform_int_distribution<> full_dis(1, DungeonMap::SIZE - 2);
    rimvale::Dice combat_dice;
    for (int64_t handle : player_handles) {
        auto* character = CharacterRegistry::instance().get_character_by_handle(handle);
        if (!character) continue;
        int px = 1, py = 1;
        if (!find_walkable_spawn(topleft_dis, gen, px, py)) {
            find_walkable_spawn(full_dis, gen, px, py);
        }
        entities_.push_back({ character->get_id(), character->get_name(), {px, py}, true, handle, false, false });
        CombatManager::instance().add_player(character, combat_dice);
    }
}

inline void DungeonManager::spawn_enemies(int summoner_level, int64_t specific_enemy_handle) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(12, DungeonMap::SIZE - 2);
    rimvale::Dice combat_dice;

    if (specific_enemy_handle != 0) {
        auto* creature = CreatureRegistry::instance().get_creature(specific_enemy_handle);
        if (creature) {
            int ex, ey;
            if (find_walkable_spawn(dis, gen, ex, ey)) {
                std::string id = "enemy_practice_" + std::to_string(specific_enemy_handle);
                entities_.push_back({ id, creature->get_name(), {ex, ey}, false, specific_enemy_handle, false, false });
                CombatManager::instance().add_creature(creature, combat_dice, id);
            }
        }
    } else {
        int budget = std::max(1, summoner_level);
        int enemy_count = 0;
        auto weapons = ItemRegistry::instance().get_all_weapon_names();

        std::vector<std::string> animal_names = {"Wolf", "Bear", "Boar", "Python", "Hawk", "Panther"};
        std::vector<std::string> villager_names = {"Bandit", "Thug", "Guard", "Cultist", "Mercenary"};
        std::vector<std::string> monster_names = {"Crawler", "Stinger", "Gorgon", "Imp", "Wraith", "Ogre"};

        auto spawn_one = [&](int lvl) {
            int ex, ey;
            if (find_walkable_spawn(dis, gen, ex, ey)) {
                std::uniform_int_distribution<> cat_dis(0, 2);
                int cat_idx = cat_dis(gen);
                CreatureCategory category = CreatureCategory::Monster;
                std::string name;
                if (cat_idx == 0) { category = CreatureCategory::Animal; name = animal_names[std::uniform_int_distribution<>(0, animal_names.size()-1)(gen)]; }
                else if (cat_idx == 1) { category = CreatureCategory::Villager; name = villager_names[std::uniform_int_distribution<>(0, villager_names.size()-1)(gen)]; }
                else { category = CreatureCategory::Monster; name = monster_names[std::uniform_int_distribution<>(0, monster_names.size()-1)(gen)]; }

                auto monster = std::make_unique<Creature>(name, category, lvl);
                monster->reset_resources();

                if (category == CreatureCategory::Villager || category == CreatureCategory::Monster) {
                    if (!weapons.empty()) {
                        monster->get_inventory().add_item(ItemRegistry::instance().create_weapon(weapons[std::uniform_int_distribution<>(0, weapons.size()-1)(gen)]));
                    }
                }
                monster->get_inventory().add_gold((lvl + 1) * 15);

                std::string m_id = "enemy_" + std::to_string(enemy_count++) + "_" + std::to_string(gen());
                int64_t m_handle = reinterpret_cast<int64_t>(monster.get());
                entities_.push_back({ m_id, monster->get_name(), {ex, ey}, false, m_handle, false, false });
                CombatManager::instance().add_creature(monster.get(), combat_dice, m_id);
                CreatureRegistry::instance().register_creature(monster.get());
                spawned_monsters_.push_back(std::move(monster));
                return true;
            }
            return false;
        };

        while (budget > 0) {
            int max_lvl = std::min(budget, 5);
            std::uniform_int_distribution<> lvl_dis(1, max_lvl);
            int lvl = lvl_dis(gen);
            if (spawn_one(lvl)) {
                budget -= lvl;
            } else break;
        }

        // Always add 2 more level 1 enemies
        for (int i = 0; i < 2; ++i) {
            spawn_one(1);
        }
    }
}

inline void DungeonManager::spawn_kaiju(int kaiju_index) {
    std::random_device rd;
    std::mt19937 gen(rd());
    // Kaiju spawn in bottom-right quadrant — far from players
    std::uniform_int_distribution<> dis(DungeonMap::SIZE / 2 + 2, DungeonMap::SIZE - 3);
    rimvale::Dice combat_dice;

    struct KaijuDef {
        std::string name;
        int level;
        int str, spd, intel, vit, div;
        int ac;
        std::vector<std::string> immunities;
        std::vector<std::string> resistances;
        std::vector<std::tuple<std::string,int,int,std::string>> abilities; // name, ap, sp, desc
    };

    std::vector<KaijuDef> kaiju_defs = {
        // 0: Pyroclast
        { "Pyroclast", 12, 8, 3, 2, 8, 5, 13,
          {"fire"},
          {"thunder", "non-magical physical", "ranged", "cold", "acid"},
          {
            {"Magma Breath", 4, 0, "Xd6 fire damage in a 30ft cube. X = AP spent."},
            {"Molten Hide", 0, 0, "Passive: melee attackers take 1d6 fire damage on hit."},
            {"Earthquake", 2, 0, "Creatures within 30ft must save SPD vs DC 10+STR or fall prone."},
            {"Regeneration", 0, 0, "Passive: regenerates 2d6 HP at start of turn."},
            {"Legendary Resistance", 0, 0, "Auto-succeed on a saving throw (VIT times per short rest)."},
            {"Leap", 3, 0, "Jump up to 100ft; creatures in 30ft on landing save or fall prone (3d6 dmg)."},
            {"Enhanced Explosive Mix", 0, 4, "30ft radius; 6d6 fire + 3d6 thunder; reroll 1s."}
          }
        },
        // 1: Grondar
        { "Grondar", 13, 9, 6, 4, 7, 3, 16,
          {"fear", "charm"},
          {"non-magical physical", "bludgeoning", "thunder"},
          {
            {"Multiattack", 2, 0, "Make two basic melee attacks this action."},
            {"Regeneration", 0, 0, "Passive: regenerates 2d6 HP at start of turn."},
            {"Thunderous Roar", 3, 2, "Cone of thunder; creatures must save vs stun."},
            {"Crushing Grip", 2, 0, "Grapple target; deals 2d8 bludgeoning per round held."},
            {"Boulder Throw", 2, 0, "Hurl terrain; ranged 60ft, 4d10 bludgeoning."},
            {"Earthquake", 2, 0, "On landing from Leap: creatures within 60ft save or fall prone."},
            {"Leap", 3, 0, "Jump up to 100ft; causes Earthquake on landing."},
            {"Legendary Resistance", 0, 0, "Auto-succeed on a saving throw (VIT times per short rest)."}
          }
        },
        // 2: Thal'Zuur
        { "Thal'Zuur", 14, 7, 4, 6, 9, 8, 14,
          {"poison", "psychic", "charm", "fear", "disease"},
          {"cold", "acid", "magical"},
          {
            {"Tentacle Barrage", 3, 0, "Multi-target melee (3 targets within 15ft); bludgeoning + poison."},
            {"Abyssal Howl", 3, 2, "Cone of psychic damage; causes confusion or fear."},
            {"Digestive Bloom", 2, 2, "Release spores that dissolve organic matter in 20ft."},
            {"Rot Pulse", 0, 5, "Once per long rest: 60ft radius; organic matter decays rapidly."},
            {"Regeneration", 0, 0, "Passive: heals 10 HP per round unless dealt radiant or fire."},
            {"Legendary Resistance", 0, 0, "Auto-succeed on a saving throw (VIT times per short rest)."},
            {"Disguise", 0, 0, "Can appear as a sunken island or coral reef."}
          }
        },
        // 3: Ny'Zorrak
        { "Ny'Zorrak", 15, 6, 5, 10, 8, 10, 15,
          {"psychic", "poison", "charm"},
          {"magical", "cold", "radiant"},
          {
            {"Legendary Resistance", 0, 0, "Auto-succeed on a saving throw (VIT times per short rest)."},
            {"Regeneration", 0, 0, "Passive: regenerates 2d6 HP at start of turn."},
            {"Multiattack", 2, 0, "Make two tentacle attacks targeting up to 3 creatures within 15ft."},
            {"Mind Rend", 3, 2, "Cone of psychic damage; causes hallucinations on fail."},
            {"Reality Warp", 2, 3, "Distort terrain and cause confusion in 30ft radius."},
            {"Void Pulse", 0, 4, "Destroys all active magical effects in 60ft radius."},
            {"Starfall", 4, 3, "Summon meteors in 60ft radius; 6d10 force each meteor (3 meteors)."}
          }
        },
        // 4: Mirecoast Sleeper
        { "Mirecoast Sleeper", 14, 10, 3, 2, 10, 4, 12,
          {"non-magical physical", "cold", "psychic", "prone", "stun", "fear", "charm"},
          {"thunder", "acid"},
          {
            {"Primordial Tread", 0, 0, "Passive: creatures within 100ft while moving save SPD DC 20 or fall prone (4d6+4d6 dmg)."},
            {"Tidal Collapse", 10, 0, "150ft cone or 200ft line; 8d6 bludgeoning + 8d6 cold; pushed 50ft."},
            {"Abyssal Pulse", 12, 0, "200ft radius; 6d6 force + 6d6 thunder; structures take max damage."},
            {"Leviathan Hide", 0, 0, "Passive: reduce all incoming damage by 14 (20 while submerged)."},
            {"Tidal Regeneration", 0, 0, "Passive: regenerates 2d6 + 10 HP at start of turn unless radiant."},
            {"Submerge", 0, 0, "Sink beneath deep water; become untargetable until rising."},
            {"Legendary Resistance", 0, 0, "Auto-succeed on a saving throw (VIT times per short rest)."}
          }
        },
        // 5: Aegis Ultima
        { "Aegis Ultima", 13, 7, 4, 6, 8, 6, 25,
          {"force", "paralysis", "charm"},
          {"non-magical physical", "piercing", "slashing", "thunder", "radiant"},
          {
            {"Multiattack", 2, 0, "Fire two arcane weapons in one attack action."},
            {"Arcane Baton Strike", 2, 0, "Melee; 6d6 force; VIT save DC 16 or paralyzed."},
            {"Arcane Cannon", 2, 0, "Ranged 150/300ft; 8d10 force (costs 2 Spark Tank charges)."},
            {"Disruption Blast", 3, 0, "20ft radius within 120ft; VIT save DC 18 or stunned."},
            {"Force Field", 2, 0, "Grant +4 AC to allies within 30ft for 1 round."},
            {"Bulwark Mode", 0, 3, "30ft dome; immunity to forced movement, +4 AC for 3 rounds."},
            {"Regeneration", 0, 0, "Passive: repairs 10 HP per round unless EMP or void damage."},
            {"Legendary Resistance", 0, 0, "Auto-succeed on a saving throw (VIT times per short rest)."}
          }
        }
    };

    int idx = std::max(0, std::min(kaiju_index, (int)kaiju_defs.size() - 1));
    const auto& kd = kaiju_defs[idx];

    auto kaiju = std::make_unique<Creature>(kd.name, CreatureCategory::Kaiju, kd.level);
    // Override auto-distributed stats with exact Kaiju stat block
    kaiju->get_stats().strength  = kd.str;
    kaiju->get_stats().speed     = kd.spd;
    kaiju->get_stats().intellect = kd.intel;
    kaiju->get_stats().vitality  = kd.vit;
    kaiju->get_stats().divinity  = kd.div;

    for (const auto& imm : kd.immunities)   kaiju->add_damage_immunity(imm);
    for (const auto& res : kd.resistances)  kaiju->add_damage_resistance(res);

    // Replace default abilities with Kaiju-specific ones
    kaiju->get_abilities_mutable().clear();
    for (const auto& [aname, ap, sp, desc] : kd.abilities) {
        kaiju->get_abilities_mutable().push_back({aname, ap, sp, desc});
    }

    kaiju->reset_resources(); // Must be AFTER setting stats

    int ex, ey;
    if (!find_walkable_spawn(dis, gen, ex, ey)) {
        ex = DungeonMap::SIZE - 4;
        ey = DungeonMap::SIZE - 4;
    }

    std::string k_id = "kaiju_" + kd.name;
    int64_t k_handle = reinterpret_cast<int64_t>(kaiju.get());
    entities_.push_back({ k_id, kaiju->get_name(), {ex, ey}, false, k_handle, false, false });
    CombatManager::instance().add_creature(kaiju.get(), combat_dice, k_id);
    CreatureRegistry::instance().register_creature(kaiju.get());
    spawned_monsters_.push_back(std::move(kaiju));
}

inline void DungeonManager::spawn_mob(int member_count, int level,
                                      CreatureCategory /*cat*/,
                                      MobTrait trait, MobLeaderType leader, MobMood mood) {
    std::random_device rd;
    std::mt19937 gen(rd());
    // Mobs spawn in bottom-right quadrant, away from players
    std::uniform_int_distribution<> dis(DungeonMap::SIZE / 2 + 2, DungeonMap::SIZE - 3);
    rimvale::Dice combat_dice;

    // Clamp member count to a playable range (10 – 100)
    int mc = std::max(10, std::min(member_count, 100));

    static const std::vector<std::string> mob_names = {
        "Rioters", "Villagers", "Cultists", "Bandits", "Peasants",
        "Raiders", "Scavengers", "Zealots", "Rebels", "Thralls"
    };
    std::string mob_name = mob_names[std::uniform_int_distribution<>(0, (int)mob_names.size()-1)(gen)];

    // GMG formula: hp_per_member = 3 × Level + VIT
    // Use a temporary Creature to read auto-allocated VIT for this level/category
    Creature temp_c(mob_name, CreatureCategory::Adversary, level);
    int hp_per_member = 3 * level + temp_c.get_stats().vitality;

    auto mob = std::make_unique<Mob>(mob_name, CreatureCategory::Adversary, level,
                                     mc, hp_per_member, trait, leader, mood);
    mob->reset_resources();

    int ex, ey;
    if (!find_walkable_spawn(dis, gen, ex, ey)) {
        ex = DungeonMap::SIZE - 4;
        ey = DungeonMap::SIZE - 4;
    }

    std::string m_id = "mob_" + mob_name + "_" + std::to_string(gen());
    int64_t m_handle = reinterpret_cast<int64_t>(mob.get());
    entities_.push_back({ m_id, mob->get_name(), {ex, ey}, false, m_handle, false, false });
    CombatManager::instance().add_creature(mob.get(), combat_dice, m_id);
    CreatureRegistry::instance().register_creature(mob.get());
    spawned_monsters_.push_back(std::move(mob));
}

inline void DungeonManager::spawn_militia(int militia_index) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(DungeonMap::SIZE / 2 + 2, DungeonMap::SIZE - 3);
    rimvale::Dice combat_dice;

    struct MilitiaDef {
        std::string name;
        int level;
        int str, spd, vit, intel, div;
        int members;
        MilitiaType type;
        EquipmentTier tier;
        MilitiaTrait trait;
        CommanderRole commander;
        std::vector<std::string> immunities;
        std::vector<std::string> resistances;
    };

    std::vector<MilitiaDef> militia_defs = {
        // 0: Ironroot Guard
        { "Ironroot Guard", 5, 5, 5, 5, 5, 2, 10,
          MilitiaType::Guard, EquipmentTier::Standard,
          MilitiaTrait::ShieldWall, CommanderRole::Veteran, {}, {} },
        // 1: Emberveil Recon
        { "Emberveil Recon", 4, 3, 6, 5, 5, 2, 5,
          MilitiaType::Recon, EquipmentTier::Improvised,
          MilitiaTrait::AmbushTactics, CommanderRole::Tactician, {}, {} },
        // 2: Crimson Crusaders
        { "Crimson Crusaders", 6, 5, 4, 6, 3, 4, 10,
          MilitiaType::Crusader, EquipmentTier::Elite,
          MilitiaTrait::BattleChant, CommanderRole::Priest, {}, {} },
        // 3: Shadow Blade Company
        { "Shadow Blades", 5, 4, 6, 4, 5, 3, 5,
          MilitiaType::Shadow, EquipmentTier::Standard,
          MilitiaTrait::AmbushTactics, CommanderRole::None, {}, {} },
        // 4: Iron Legion Vanguard
        { "Iron Legion", 7, 6, 4, 6, 4, 2, 20,
          MilitiaType::IronLegionnaire, EquipmentTier::Elite,
          MilitiaTrait::IronDiscipline, CommanderRole::Veteran, {}, {} },
        // 5: Void-Touched Warband
        { "Void Warband", 6, 6, 5, 5, 3, 4, 10,
          MilitiaType::Raid, EquipmentTier::Standard,
          MilitiaTrait::VoidTouchedFrenzy, CommanderRole::None, {"charm", "fear"}, {} },
        // 6: Storm Riders
        { "Storm Riders", 5, 4, 6, 4, 4, 4, 10,
          MilitiaType::Storm, EquipmentTier::Standard,
          MilitiaTrait::Skirmishers, CommanderRole::Tactician, {}, {"lightning", "thunder"} },
        // 7: Sacred Vigil
        { "Sacred Vigil", 5, 4, 4, 5, 4, 6, 10,
          MilitiaType::Sacred, EquipmentTier::Elite,
          MilitiaTrait::DivineZeal, CommanderRole::Priest, {"fear"}, {} }
    };

    int idx = std::max(0, std::min(militia_index, (int)militia_defs.size() - 1));
    const auto& md = militia_defs[idx];

    auto militia = std::make_unique<Militia>(md.name, md.type, md.level, md.members,
                                             md.tier, md.trait, md.commander);
    militia->get_stats().strength  = md.str;
    militia->get_stats().speed     = md.spd;
    militia->get_stats().vitality  = md.vit;
    militia->get_stats().intellect = md.intel;
    militia->get_stats().divinity  = md.div;

    for (const auto& imm : md.immunities)  militia->add_damage_immunity(imm);
    for (const auto& res : md.resistances) militia->add_damage_resistance(res);

    militia->reset_resources();

    int ex, ey;
    if (!find_walkable_spawn(dis, gen, ex, ey)) {
        ex = DungeonMap::SIZE - 4;
        ey = DungeonMap::SIZE - 4;
    }

    std::string m_id = "militia_" + md.name + "_" + std::to_string(gen());
    int64_t m_handle = reinterpret_cast<int64_t>(militia.get());
    entities_.push_back({ m_id, militia->get_name(), {ex, ey}, false, m_handle, false, false });
    CombatManager::instance().add_creature(militia.get(), combat_dice, m_id);
    CreatureRegistry::instance().register_creature(militia.get());
    spawned_monsters_.push_back(std::move(militia));
}

inline void DungeonManager::spawn_apex(int apex_index) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(DungeonMap::SIZE / 2 + 2, DungeonMap::SIZE - 3);
    rimvale::Dice combat_dice;

    struct ApexDef {
        std::string name;
        int level;
        int str, spd, intel, vit, div;
        int ac;
        std::vector<std::string> immunities;
        std::vector<std::string> resistances;
        std::vector<std::tuple<std::string,int,int,std::string>> abilities;
        CreatureCategory category = CreatureCategory::ApexMonster;
        bool spawn_pair = false; // spawn two separate entities (e.g. Vorath Twins)
        std::string twin_name_a = "";
        std::string twin_name_b = "";
    };

    std::vector<ApexDef> apex_defs = {
        // 0: Varnok
        { "Varnok", 11, 6, 4, 2, 6, 3, 14,
          {"charm", "fear", "non-magical physical"},
          {"cold", "poison"},
          {
            {"Multiattack", 2, 0, "Two claw or bite attacks per turn."},
            {"Regeneration", 0, 0, "Passive: heals 10 HP per round unless exposed to silver or radiant."},
            {"Legendary Resistance", 0, 0, "6/day: auto-succeed on a failed saving throw."},
            {"Soulbrand", 2, 0, "On damage, brand the target: cannot heal, disadvantage on saves vs Varnok."},
            {"Moonshadow Pounce", 3, 0, "Move 30+ ft then teleport to shadow and make claw attack with advantage."},
            {"Alpha's Command", 0, 2, "Once/short rest: roar forces beasts and lycanthropes to obey for 1 round (DC 17 INT)."},
            {"Feral Eclipse", 0, 0, "At 0 HP: become spectral wolf for 2 rounds — intangible, fly, +2d6 melee, +20 HP/round."},
            {"Lunar Apex Instinct", 0, 0, "Passive: +2 attacks and saves in moonlight. Can act in surprise rounds."}
          }
        },
        // 1: Lady Nyssara
        { "Lady Nyssara", 12, 4, 3, 6, 5, 6, 15,
          {"charm", "sleep", "necrotic"},
          {"slashing", "psychic"},
          {
            {"Multiattack", 2, 0, "Two melee attacks per turn."},
            {"Legendary Resistance", 0, 0, "5/day: auto-succeed on a failed saving throw."},
            {"Eclipse Veil", 0, 2, "120ft radius magical darkness for 1 min; INT save DC 18 or disadvantage on attacks."},
            {"Phantom Legion", 0, 5, "Summon 4 spectral clones for 3 rounds; attacks against Nyssara have 50% miss chance."},
            {"Blood of the Ancients", 0, 2, "+2 saves, ignore first damage instance each round for 2 rounds."},
            {"Bloodborne Dominion", 3, 0, "Dominate creature below half HP (DC 18 DIV); obeying for 1d4 rounds."},
            {"Crimson Mirage", 0, 0, "Once/short rest: split into 3 illusions; 50% chance attacks hit illusion."},
            {"Arcane Overdrive", 0, 5, "Triple AP regen 3 rounds; max damage melee; push 10ft; +2 AC."},
            {"Sanguine Reversal", 0, 2, "On damage taken: reflect half as necrotic to attacker."},
            {"Regeneration", 0, 0, "Passive: heals 10 HP per round unless exposed to sunlight."}
          }
        },
        // 2: Malgrin
        { "Malgrin", 13, 2, 2, 10, 4, 7, 13,
          {"necrotic", "psychic", "charm", "sleep"},
          {"cold", "non-magical physical"},
          {
            {"Legendary Resistance", 0, 0, "4/day: auto-succeed on a failed saving throw."},
            {"Teleport", 1, 0, "Blink up to 300ft as a bonus action."},
            {"Gravity Shatter", 0, 2, "60ft range, 30ft pull: STR save DC 17 or restrained for 1 round."},
            {"Temporal Rift", 0, 2, "Take an extra turn immediately."},
            {"Terrain Manipulation", 2, 0, "Raise bone spires; create cursed difficult terrain with necrotic damage."},
            {"Chrono-Phylactery", 0, 0, "Once/long rest: when reduced to 0 HP, rewind 1 round undoing all damage."},
            {"Soulfracture Glyph", 2, 0, "Inscribe glyph; DC 18 INT save or lose 1 SP and disadvantage on spells for 1 min."},
            {"Temporal Collapse", 0, 6, "Once/long rest: freeze time 1 round — all other creatures stunned."},
            {"Grave Sovereignty", 0, 0, "Passive: undead within 60ft +2 saves and +1d6 necrotic damage."},
            {"Cursed Immortality", 0, 0, "If phylactery intact, body reforms there instead of dying."}
          }
        },
        // 3: Sithra
        { "Sithra", 1, 1, 2, 1, 1, 1, 11,
          {"disease"},
          {"poison"},
          {
            {"Venom Pulse", 3, 0, "10ft cube bile spit; VIT save DC 11 or 1d6 poison + lose 3 AP."},
            {"Slitherstep", 0, 0, "Passive: move through enemy spaces without provoking opportunity attacks."}
          }
        },
        // 4: Korrak
        { "Korrak", 3, 2, 2, 1, 2, 1, 12,
          {"charm"},
          {"necrotic", "poison"},
          {
            {"Packbound Howl", 0, 0, "Once/short rest: summon 2 skeletal hyenas for 2 rounds (1d4 necrotic each)."},
            {"Boneburst Leap", 2, 0, "Leap 30ft; 1d6 piercing to all within 5ft of landing."},
            {"Carrion Feast", 0, 0, "On kill: regain 1d6 HP and +1 attack rolls for 1 round."}
          }
        },
        // 5: Veltraxis
        { "Veltraxis", 5, 4, 3, 2, 3, 2, 13,
          {"fear"},
          {"fire", "slashing"},
          {
            {"Infernal Riposte", 1, 0, "On melee hit: deal 1d6 fire and push attacker 5ft."},
            {"Blazing Dash", 0, 0, "Once/short rest: move 60ft straight; enemies passed take 1d4 fire."},
            {"Ash Veil", 2, 0, "Create 10ft smoke cloud 1 min; Veltraxis invisible inside."},
            {"Arena's Echo", 0, 0, "Passive: in crowd/arena, +2 attack rolls and saving throws."}
          }
        },
        // 6: Xal'Thuun
        { "Xal'Thuun", 20, 6, 6, 10, 8, 10, 16,
          {"charm", "sleep", "fear", "necrotic"},
          {"psychic", "magical"},
          {
            {"Dream Consumption", 0, 0, "Once/round: DIV save DC 20 or lose 1d4 SP, disadvantage all checks 1 min."},
            {"Astral Bloom", 0, 5, "60ft warped gravity field; INT save or stunned 1 round."},
            {"Mind Fracture", 0, 0, "Once/short rest: DC 20 INT save or forget allies and attack randomly 2 rounds."},
            {"Reality Unraveled", 0, 10, "30ft radius void collapse; structures take 10d10 force damage."},
            {"Cosmic Rebirth", 0, 0, "At 0 HP: phase out 1 round then return with full HP and +5 saves for 3 rounds."}
          }
        },
        // --- Choir of Reclamation ---
        // 7: High Null Sereth
        { "High Null Sereth", 15, 1, 2, 8, 4, 10, 14,
          {"psychic", "charm", "sleep"},
          {"necrotic", "force"},
          {
            {"Null Silence", 3, 0, "60ft range; INT save DC 19 or target cannot cast spells or use SP abilities for 2 rounds."},
            {"Unwritten Word", 0, 4, "Erase a target's memory of one event; they cannot use abilities tied to that knowledge this combat."},
            {"Temporal Rewrite", 0, 8, "Once/long rest: rewind initiative by 1 full round, restoring all HP and SP to their prior state."},
            {"Null Field", 0, 6, "30ft aura for 3 rounds; no spells above 2 SP can be cast within."},
            {"Legendary Resistance", 0, 0, "5/day: auto-succeed on a failed saving throw."},
            {"Reality Edit", 0, 0, "Passive: once/round, negate one incoming spell automatically."}
          },
          CreatureCategory::Adversary
        },
        // 8: Veyra's Echo (Nyra)
        { "Veyra's Echo", 15, 0, 3, 6, 3, 9, 13,
          {"charm", "psychic"},
          {"radiant", "force"},
          {
            {"Foreseen Strike", 0, 0, "Passive: once/round, impose disadvantage on one attack roll against Veyra's Echo."},
            {"Echo Step", 0, 2, "Teleport up to 30ft to any position seen in a vision this combat."},
            {"Fate Redirect", 0, 3, "When an ally would take damage, redirect half to a different target within 60ft (DIV save DC 18)."},
            {"Chrono-Vision", 0, 0, "Once/short rest: learn the actions enemies will take next round."},
            {"Prophet's Lament", 0, 5, "Force all enemies to re-roll all d20s next round and take the lower result."},
            {"Legendary Resistance", 0, 0, "4/day: auto-succeed on a failed saving throw."}
          },
          CreatureCategory::Adversary
        },
        // 9: Korrin of the Forgotten Flame
        { "Korrin of the Forgotten Flame", 15, 2, 3, 9, 5, 8, 13,
          {"fire", "charm"},
          {"psychic", "cold"},
          {
            {"Memory Burn", 0, 3, "Target loses memory of one combat ability for 1d4 rounds; cannot use it (INT save DC 18)."},
            {"Forgotten Flame", 3, 0, "Fire attack that also deals psychic damage; ignores fire resistance."},
            {"Pyre of the Past", 0, 6, "20ft radius; INT save DC 18 or target relives their worst memory — stunned 1 round."},
            {"Ashen Recall", 0, 0, "Passive: at start of each round, randomly restore or destroy one ability Korrin has used."},
            {"Legendary Resistance", 0, 0, "4/day: auto-succeed on a failed saving throw."},
            {"Inferno Crescendo", 0, 0, "Passive: fire damage increases by 1d6 each round, resetting on a miss."}
          },
          CreatureCategory::Adversary
        },
        // 10: The Culled (mob entity, ApexMonster for threshold/token)
        { "The Culled", 10, 3, 4, 5, 4, 5, 13,
          {"charm", "fear", "psychic", "identity"},
          {"necrotic", "poison"},
          {
            {"Cacophony", 0, 0, "Passive: all enemies within 30ft must make INT save DC 15 or lose concentration at start of their turn."},
            {"Void Vessels", 0, 0, "Passive: immune to effects that target a single mind; ability scores cannot be reduced."},
            {"Mass Surge", 3, 0, "All creatures in 15ft arc take 2d6 bludgeoning and are knocked prone (STR save DC 15)."},
            {"Swarm Resilience", 0, 0, "Passive: halve damage from attacks that target a single creature."},
            {"Collective Scream", 0, 4, "60ft radius; DIV save DC 16 or deafened and frightened for 1 round."}
          }
        },
        // --- Eclipsed Enclave ---
        // 11: Zorin Blackscale
        { "Zorin Blackscale", 8, 2, 1, 2, 5, 3, 21,
          {"charm"},
          {"slashing", "bludgeoning"},
          {
            {"Scale Bastion", 0, 0, "Passive: halve damage from non-magical ranged attacks."},
            {"Obsidian Slam", 2, 0, "Melee; STR save DC 15 or target knocked prone and loses 3 AP."},
            {"Iron Warden", 0, 0, "Passive: allies within 5ft gain +1 AC."},
            {"Retaliation", 0, 0, "Once/round: when hit, make a free melee attack against attacker."}
          },
          CreatureCategory::Adversary
        },
        // 12: Thalia Darksong
        { "Thalia Darksong", 5, 1, 3, 3, 1, 2, 12,
          {},
          {"psychic"},
          {
            {"Discordant Verse", 0, 2, "60ft; target must make INT save DC 13 or lose concentration and take 1d6 psychic."},
            {"Shadow Refrain", 0, 2, "Create 15ft illusion zone; enemies have disadvantage on attack rolls inside."},
            {"Bard's Retreat", 0, 0, "Once/short rest: disengage as bonus action and move full speed without provoking."}
          },
          CreatureCategory::Adversary
        },
        // 13: Gorrim Ironfist
        { "Gorrim Ironfist", 5, 3, 1, 2, 3, 1, 13,
          {"fear"},
          {},
          {
            {"Reckless Charge", 2, 0, "Move 20ft and make melee attack; if hits, deal +1d6 and push 5ft."},
            {"Iron Resolve", 0, 0, "Passive: when reduced below half HP, gain +2 to all attack rolls and saves."},
            {"Battering Blow", 3, 0, "Single heavy melee; STR save DC 14 or target is staggered (lose 2 AP next turn)."}
          },
          CreatureCategory::Adversary
        },
        // 14: Seraphina Windwalker
        { "Seraphina Windwalker", 5, 1, 2, 2, 2, 3, 12,
          {},
          {"thunder"},
          {
            {"Gust Step", 0, 0, "Passive: movement does not provoke opportunity attacks."},
            {"Wind Slash", 2, 0, "Ranged melee; 30ft; 1d6 slashing + push 5ft."},
            {"Tailwind Burst", 0, 2, "Ally within 30ft can immediately move up to their speed as a free action."}
          },
          CreatureCategory::Adversary
        },
        // 15: Rurik Stormbringer
        { "Rurik Stormbringer", 5, 2, 2, 2, 2, 2, 12,
          {},
          {"lightning", "thunder"},
          {
            {"Chain Lightning", 0, 3, "Strike up to 3 targets in a chain; each takes 1d8 lightning (SPD save DC 13)."},
            {"Thunderclap", 2, 0, "5ft burst; VIT save DC 13 or deafened and pushed 10ft."},
            {"Storm Surge", 0, 0, "Passive: once/round, after landing a spell, gain 2 AP."}
          },
          CreatureCategory::Adversary
        },
        // 16: Lyra Moonshadow
        { "Lyra Moonshadow", 5, 0, 2, 4, 2, 2, 11,
          {"charm"},
          {"psychic"},
          {
            {"Mirror Image", 0, 2, "Create 2 duplicates; 33% chance attacks hit a duplicate instead."},
            {"Phantasmal Step", 0, 0, "Once/short rest: become invisible until next attack."},
            {"Moonveil", 0, 3, "Target must make DIV save DC 14 or believe an ally is an enemy for 1 round."}
          },
          CreatureCategory::Adversary
        },
        // 17: Vorath Twins (Ilyra & Kael) — spawn_pair
        { "The Vorath Twins", 5, 0, 3, 3, 2, 2, 12,
          {},
          {"psychic"},
          {
            {"Twin Strike", 2, 0, "Each twin makes one attack against the same target; share advantage if both adjacent."},
            {"Oath Bond", 0, 0, "Passive: when one twin drops below half HP, the other gains +2 to all rolls until end of combat."},
            {"Mirrored Defense", 0, 0, "Once/round: one twin can absorb an attack intended for the other (within 5ft)."}
          },
          CreatureCategory::Adversary, true, "Ilyra", "Kael"
        },
        // 18: Morthis the Binder
        { "Morthis the Binder", 5, 3, 1, 2, 3, 2, 13,
          {},
          {"slashing"},
          {
            {"Chain Snare", 2, 0, "60ft; target restrained for 1 round (STR save DC 14 to break free each turn)."},
            {"Binding Circle", 0, 3, "10ft zone; creatures inside cannot teleport or move more than 5ft/turn for 2 rounds."},
            {"Drag Down", 0, 0, "Once/round: if target is restrained, make a free grapple attempt as bonus action."}
          },
          CreatureCategory::Adversary
        },
        // 19: Kaelen the Hollow
        { "Kaelen the Hollow", 5, 1, 3, 2, 2, 3, 12,
          {},
          {"necrotic"},
          {
            {"Vitality Drain", 2, 0, "Melee; deal 1d6 necrotic and heal Kaelen for half the damage dealt."},
            {"Shadow Fade", 0, 0, "Once/short rest: when hit, teleport 15ft and become invisible until next turn."},
            {"Hollow Touch", 3, 0, "Target loses 2 max HP until they take a long rest (VIT save DC 13)."}
          },
          CreatureCategory::Adversary
        },
        // 20: Nirael of the Glass Veil
        { "Nirael of the Glass Veil", 5, 0, 2, 4, 1, 3, 11,
          {"sleep"},
          {"psychic"},
          {
            {"Glass Suggestion", 0, 2, "60ft; INT save DC 14 or target uses their next action to aid Nirael's allies."},
            {"Memory Shard", 2, 0, "Implant a false memory mid-combat; target has disadvantage on INT/DIV saves vs Nirael for 2 rounds."},
            {"Veil of Confusion", 0, 3, "20ft radius; all enemies make INT save DC 14 or randomly retarget their next attack."}
          },
          CreatureCategory::Adversary
        }
    };

    int idx = std::max(0, std::min(apex_index, (int)apex_defs.size() - 1));
    const auto& ad = apex_defs[idx];

    auto spawn_one = [&](const std::string& name, int dx, int dy) {
        auto apex = std::make_unique<Creature>(name, ad.category, ad.level);
        apex->get_stats().strength  = ad.str;
        apex->get_stats().speed     = ad.spd;
        apex->get_stats().intellect = ad.intel;
        apex->get_stats().vitality  = ad.vit;
        apex->get_stats().divinity  = ad.div;

        for (const auto& imm : ad.immunities)  apex->add_damage_immunity(imm);
        for (const auto& res : ad.resistances) apex->add_damage_resistance(res);

        apex->get_abilities_mutable().clear();
        for (const auto& [aname, ap, sp, desc] : ad.abilities)
            apex->get_abilities_mutable().push_back({aname, ap, sp, desc});

        apex->reset_resources();

        int ex, ey;
        if (!find_walkable_spawn(dis, gen, ex, ey)) {
            ex = DungeonMap::SIZE - 4 + dx;
            ey = DungeonMap::SIZE - 4 + dy;
        }

        std::string a_id = "apex_" + name;
        int64_t a_handle = reinterpret_cast<int64_t>(apex.get());
        entities_.push_back({ a_id, apex->get_name(), {ex, ey}, false, a_handle, false, false });
        CombatManager::instance().add_creature(apex.get(), combat_dice, a_id);
        CreatureRegistry::instance().register_creature(apex.get());
        spawned_monsters_.push_back(std::move(apex));
    };

    if (ad.spawn_pair) {
        spawn_one(ad.twin_name_a, 0, 0);
        spawn_one(ad.twin_name_b, 1, 1);
    } else {
        spawn_one(ad.name, 0, 0);
    }
}

} // namespace rimvale

#endif // RIMVALE_DUNGEON_H
