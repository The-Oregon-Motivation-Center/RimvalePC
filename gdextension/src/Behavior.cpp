#include "Behavior.h"
#include "CombatManager.h"
#include "Dungeon.h"
#include <algorithm>
#include <cmath>
#include <map>

namespace rimvale {

std::string BehaviorEngine::decide_and_act(Combatant& enemy, std::vector<Combatant>& all_combatants, Dice& dice) {
    if (enemy.is_player) return "";

    auto& dm = DungeonManager::instance();
    auto entities = dm.get_entities();
    auto enemy_ent_it = std::find_if(entities.begin(), entities.end(), [&](const DungeonEntity& e) {
        return e.id == enemy.id;
    });

    if (enemy_ent_it == entities.end()) return enemy.name + " is not on the map.";

    // Identify target pressure (players + friendly summons are all valid targets)
    auto is_valid_target = [](const Combatant& c) {
        return (c.is_player || c.is_friendly_summon) && c.get_current_hp() > 0;
    };

    std::map<std::string, int> target_pressure;
    for (auto& p : all_combatants) {
        if (is_valid_target(p)) {
            auto p_it = std::find_if(entities.begin(), entities.end(), [&](const DungeonEntity& e) { return e.id == p.id; });
            if (p_it != entities.end()) {
                for (const auto& other_e : all_combatants) {
                    if (!other_e.is_player && !other_e.is_friendly_summon && other_e.id != enemy.id && other_e.get_current_hp() > 0) {
                        auto oe_it = std::find_if(entities.begin(), entities.end(), [&](const DungeonEntity& e) { return e.id == other_e.id; });
                        if (oe_it != entities.end()) {
                            int d = std::max(std::abs(oe_it->position.x - p_it->position.x), std::abs(oe_it->position.y - p_it->position.y));
                            if (d <= 1) target_pressure[p.id]++;
                        }
                    }
                }
            }
        }
    }

    // Find best target (players and friendly summons)
    Combatant* target = nullptr;
    int min_dist = 1000000;

    for (int pass = 0; pass < 2; ++pass) {
        for (auto& c : all_combatants) {
            if (is_valid_target(c)) {
                if (pass == 0 && target_pressure[c.id] >= 2) continue;

                auto t_ent_it = std::find_if(entities.begin(), entities.end(), [&](const DungeonEntity& e) {
                    return e.id == c.id;
                });
                if (t_ent_it != entities.end()) {
                    int dx = std::abs(enemy_ent_it->position.x - t_ent_it->position.x);
                    int dy = std::abs(enemy_ent_it->position.y - t_ent_it->position.y);
                    int d = std::max(dx, dy);
                    if (d < min_dist) {
                        min_dist = d;
                        target = &c;
                    }
                }
            }
        }
        if (target) break;
    }

    if (!target) return enemy.name + " scans the area but finds no suitable targets.";

    bool is_ranged = (enemy.name.find("Archer") != std::string::npos || enemy.name.find("Stinger") != std::string::npos);
    std::string log = enemy.name + "'s turn:\n";
    bool acted = false;

    auto target_ent_it = std::find_if(entities.begin(), entities.end(), [&](const DungeonEntity& e) {
        return e.id == target->id;
    });

    if (target_ent_it != entities.end()) {
        bool needs_move = false;
        if (is_ranged) {
            bool has_los = dm.has_los(enemy_ent_it->position, target_ent_it->position);
            if (!has_los || min_dist < 3 || min_dist > 5) needs_move = true;
        } else {
            if (min_dist > 1) needs_move = true;
        }

        if (needs_move) {
            Vector2i best_tile = enemy_ent_it->position;
            int best_score = -1000;

            auto reachable = dm.get_reachable_tiles(enemy.id);
            reachable.emplace_back(enemy_ent_it->position, 0);

            for (const auto& r : reachable) {
                int d = std::max(std::abs(r.first.x - target_ent_it->position.x), std::abs(r.first.y - target_ent_it->position.y));
                bool has_los = dm.has_los(r.first, target_ent_it->position);
                int score = 0;

                if (is_ranged) {
                    if (has_los) score += 50;
                    if (d >= 3 && d <= 5) score += 30;
                    else if (d > 5) score -= (d - 5) * 5;
                    else if (d < 3) score -= (3 - d) * 20;
                } else {
                    if (d == 1) score += 100;
                    else score -= d * 10;
                }

                if (!is_ranged && d > min_dist) score -= 50;

                if (score > best_score) {
                    best_score = score;
                    best_tile = r.first;
                }
            }

            if (best_tile != enemy_ent_it->position) {
                auto path = dm.get_path(enemy.id, best_tile.x, best_tile.y);
                int steps_taken = 0;
                for (const auto& step : path) {
                    std::string pos_param = std::to_string(step.x) + "|" + std::to_string(step.y);
                    if (CombatManager::instance().perform_action(ActionType::Move, dice, pos_param)) {
                        steps_taken++;
                    } else break;
                }
                if (steps_taken > 0) {
                    log += " - Moved " + std::to_string(steps_taken) + " tiles.\n";
                    acted = true;
                    auto entities_after = dm.get_entities();
                    enemy_ent_it = std::find_if(entities_after.begin(), entities_after.end(), [&](const DungeonEntity& e) { return e.id == enemy.id; });
                }
            }
        }
    }

    // Action phase
    int actions_limit = 3;
    while (enemy.get_current_ap() > 0 && actions_limit > 0) {
        auto entities_now = dm.get_entities();
        auto e_it = std::find_if(entities_now.begin(), entities_now.end(), [&](const DungeonEntity& e) { return e.id == enemy.id; });
        auto t_it = std::find_if(entities_now.begin(), entities_now.end(), [&](const DungeonEntity& e) { return e.id == target->id; });

        if (e_it == entities_now.end() || t_it == entities_now.end()) break;

        int dist = std::max(std::abs(e_it->position.x - t_it->position.x), std::abs(e_it->position.y - t_it->position.y));
        bool has_los = dm.has_los(e_it->position, t_it->position);

        if (is_ranged && has_los && dist >= 1 && dist <= 8) {
            if (CombatManager::instance().perform_action(ActionType::RangedAttack, dice, target->id)) {
                log += " - " + CombatManager::instance().get_last_action_log() + "\n";
                acted = true;
            } else break;
        } else if (!is_ranged && dist <= 1) {
            if (CombatManager::instance().perform_action(ActionType::MeleeAttack, dice, target->id)) {
                log += " - " + CombatManager::instance().get_last_action_log() + "\n";
                acted = true;
            } else break;
        } else {
             auto path = dm.get_path(enemy.id, t_it->position.x, t_it->position.y);
             if (!path.empty()) {
                 std::string pos_param = std::to_string(path[0].x) + "|" + std::to_string(path[0].y);
                 if (CombatManager::instance().perform_action(ActionType::Move, dice, pos_param)) {
                     log += " - Stepped forward.\n";
                     acted = true;
                     continue;
                 }
             }
             break;
        }
        actions_limit--;
        if (target->get_current_hp() <= 0) break;
    }

    if (!acted) log += " - " + enemy.name + " bides its time.";
    return log;
}

}
