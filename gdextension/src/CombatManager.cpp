#include "CombatManager.h"
#include "CharacterRegistry.h"
#include "CreatureRegistry.h"
#include "Dungeon.h"
#include "SpellRegistry.h"
#include "Behavior.h"
#include <algorithm>
#include <iostream>
#include <sstream>

namespace rimvale {

void CombatManager::start_combat() {
    std::sort(combatants_.begin(), combatants_.end(), [](const Combatant& a, const Combatant& b) {
        return a.initiative > b.initiative;
    });
    current_combatant_index_ = 0;
    round_count_ = 1;
    current_phase_ = CombatPhase::Player;
    last_action_log_ = "Combat started!";

    for (auto& c : combatants_) {
        if (c.is_player && c.player_ptr) c.player_ptr->reset_encounter();
        c.start_turn();
    }
    // MartialFocus T3: Tactical Surge — bonus AP at start of combat equal to Strength
    for (auto& c : combatants_) {
        if (c.is_player && c.player_ptr && c.player_ptr->get_feat_tier(FeatID::MartialFocus) >= 3) {
            c.gain_ap(c.player_ptr->get_stats().strength);
            last_action_log_ += "\n" + c.name + " gains " + std::to_string(c.player_ptr->get_stats().strength) + " bonus AP (Tactical Surge)!";
        }
    }
}

void CombatManager::clear_combatants() {
    combatants_.clear();
    current_combatant_index_ = 0;
    round_count_ = 1;
    current_phase_ = CombatPhase::Player;
}

void CombatManager::add_player(Character* character, Dice& dice) {
    if (!character) return;
    int init;
    // Quillari: Quick Reflexes — 2x Speed modifier for initiative
    if (character->get_lineage().name == "Quillari") {
        init = dice.roll(20) + 2 * character->get_stats().speed;
    } else {
        init = character->roll_stat_check(dice, StatType::Speed).total;
    }
    // Elf: Keen Senses — add Perception skill score to initiative roll
    if (character->get_lineage().name == "Elf") {
        init += character->get_skills().get_skill(SkillType::Perception);
    }
    int mv = character->get_movement_speed() / 5;
    combatants_.push_back({
        character->get_id(), character->get_name(), init, true,
        character, nullptr, {}, mv, false, false, 0, false, {}, {}, ""
    });
}

void CombatManager::add_creature(Creature* creature, Dice& dice, const std::string& id) {
    if (!creature) return;
    int init = dice.roll_d20(RollType::Normal, creature->get_stats().speed).total;
    int mv = creature->get_movement_speed() / 5;
    combatants_.push_back({
        id.empty() ? ("creature_" + std::to_string(reinterpret_cast<uintptr_t>(creature))) : id, creature->get_name(), init, false,
        nullptr, creature, {}, mv, false, false, 0, false, {}, {}, ""
    });
}

void CombatManager::sort_initiative() {
    std::sort(combatants_.begin(), combatants_.end(), [](const Combatant& a, const Combatant& b) {
        return a.initiative > b.initiative;
    });
}

void CombatManager::next_turn() {
    if (combatants_.empty()) return;

    combatants_[current_combatant_index_].has_acted = true;
    current_combatant_index_++;

    if (current_combatant_index_ >= combatants_.size()) {
        start_new_round();
    } else {
        process_start_of_turn(combatants_[current_combatant_index_]);
    }
}

void CombatManager::process_start_of_turn(Combatant& c) {
    Dice local_dice;

    // Crushing Hold (T2): deal 1d4 bludgeoning to each grappled target
    if (!c.grappling_ids.empty()) {
        int tier = (c.is_player && c.player_ptr) ? c.player_ptr->get_feat_tier(FeatID::GraspOfTheTitan) : 0;
        if (tier >= 2) {
            for (const auto& target_id : c.grappling_ids) {
                auto* target = find_combatant_by_id(target_id);
                if (target) {
                    int dmg = local_dice.roll(4);
                    if (target->is_player && target->player_ptr) target->player_ptr->take_damage(dmg, local_dice);
                    else if (target->creature_ptr) target->creature_ptr->take_damage(dmg, local_dice);
                    last_action_log_ += "\n" + c.name + " deals " + std::to_string(dmg) + " bludgeoning damage to " + target->name + " (Crushing Hold).";
                }
            }
        }
    }

    // Bleed: 1d4 per stack at start of turn
    {
        int stacks = 0;
        if (c.is_player && c.player_ptr) stacks = c.player_ptr->get_status().get_bleed_stacks();
        else if (c.creature_ptr) stacks = c.creature_ptr->get_status().get_bleed_stacks();
        if (stacks > 0 && c.get_current_hp() > 0) {
            int total_bleed = 0;
            for (int s = 0; s < stacks; ++s) total_bleed += local_dice.roll(4);
            if (c.is_player && c.player_ptr) c.player_ptr->take_damage(total_bleed, local_dice);
            else if (c.creature_ptr) c.creature_ptr->take_damage(total_bleed, local_dice);
            last_action_log_ += "\n" + c.name + " bleeds for " + std::to_string(total_bleed) + " damage (" + std::to_string(stacks) + " stack(s)).";
        }
    }

    // Squeeze: 1d4 bludgeoning at start of turn
    {
        bool squeezed = false;
        if (c.is_player && c.player_ptr) squeezed = c.player_ptr->get_status().has_condition(ConditionType::Squeeze);
        else if (c.creature_ptr) squeezed = c.creature_ptr->get_status().has_condition(ConditionType::Squeeze);
        if (squeezed && c.get_current_hp() > 0) {
            int dmg = local_dice.roll(4);
            if (c.is_player && c.player_ptr) c.player_ptr->take_damage(dmg, local_dice);
            else if (c.creature_ptr) c.creature_ptr->take_damage(dmg, local_dice);
            last_action_log_ += "\n" + c.name + " takes " + std::to_string(dmg) + " bludgeoning damage (Squeeze).";
        }
    }

    // Thornwrought Human: Barbed Embrace — when grappling or grappled, deal 1d6 to the other creature at start of turn
    if (c.is_player && c.player_ptr && c.player_ptr->get_lineage().name == "Thornwrought Human" && c.get_current_hp() > 0) {
        // Barbed Embrace against things we are grappling
        for (const auto& grappled_id : c.grappling_ids) {
            auto* grappled = find_combatant_by_id(grappled_id);
            if (grappled && grappled->get_current_hp() > 0) {
                int barb_dmg = local_dice.roll(6);
                if (grappled->is_player && grappled->player_ptr) grappled->player_ptr->take_damage(barb_dmg, local_dice);
                else if (grappled->creature_ptr) grappled->creature_ptr->take_damage(barb_dmg, local_dice);
                last_action_log_ += "\n" + c.name + " deals " + std::to_string(barb_dmg) + " piercing to " + grappled->name + " (Barbed Embrace).";
            }
        }
        // Barbed Embrace against creature grappling us
        if (!c.grappled_by_id.empty()) {
            auto* grappler = find_combatant_by_id(c.grappled_by_id);
            if (grappler && grappler->get_current_hp() > 0) {
                int barb_dmg = local_dice.roll(6);
                if (grappler->is_player && grappler->player_ptr) grappler->player_ptr->take_damage(barb_dmg, local_dice);
                else if (grappler->creature_ptr) grappler->creature_ptr->take_damage(barb_dmg, local_dice);
                last_action_log_ += "\n" + grappler->name + " takes " + std::to_string(barb_dmg) + " piercing (Barbed Embrace).";
            }
        }
    }

    // Blightmire: Toxic Seep — deal 1 poison damage to all nearby enemies at start of turn
    if (c.is_player && c.player_ptr && c.player_ptr->get_lineage().name == "Blightmire" && c.get_current_hp() > 0) {
        for (auto& t : combatants_) {
            if (t.is_player == c.is_player || t.get_current_hp() <= 0) continue;
            if (t.is_player && t.player_ptr) t.player_ptr->take_damage(1, local_dice);
            else if (t.creature_ptr) t.creature_ptr->take_damage(1, local_dice);
        }
        last_action_log_ += "\n" + c.name + "'s Toxic Seep deals 1 poison to all nearby enemies!";
    }

    // Telekinesis: Animate Weapon — auto-attack at start of turn
    if (c.is_player && c.player_ptr && c.player_ptr->tk_animate_weapon_active_ && c.get_current_hp() > 0) {
        int attacks = c.player_ptr->tk_animate_weapon_sp_committed_ / 2;
        // Find nearest living enemy
        Combatant* tk_target = nullptr;
        for (auto& t : combatants_) {
            if (t.is_player || t.get_current_hp() <= 0) continue;
            if (!tk_target) { tk_target = &t; continue; }
            // Prefer the one with fewer HP (nearest-to-dead heuristic keeps things simple)
        }
        if (tk_target) {
            for (int atk = 0; atk < attacks; ++atk) {
                RollResult tk_roll = c.player_ptr->roll_magic_attack(local_dice);
                int target_ac = tk_target->creature_ptr ? (10 + tk_target->creature_ptr->get_stats().speed) : (tk_target->player_ptr ? tk_target->player_ptr->get_armor_class() : 10);
                if (tk_roll.total >= target_ac) {
                    // Damage: weapon die + Strength, or 1d8 Force if no weapon
                    int dmg = 0;
                    Weapon* wpn = c.player_ptr->get_weapon();
                    if (wpn) {
                        dmg = local_dice.roll(8) + c.player_ptr->get_stats().strength; // default 1d8 + STR
                    } else {
                        dmg = local_dice.roll(8); // 1d8 Force
                    }
                    if (tk_target->creature_ptr) tk_target->creature_ptr->take_damage(dmg, local_dice);
                    else if (tk_target->player_ptr) tk_target->player_ptr->take_damage(dmg, local_dice);
                    last_action_log_ += "\n" + c.name + "'s Animated Weapon strikes " + tk_target->name + " for " + std::to_string(dmg) + " force damage! (Roll: " + std::to_string(tk_roll.die_roll) + "+" + std::to_string(tk_roll.modifier) + "=" + std::to_string(tk_roll.total) + " vs AC " + std::to_string(target_ac) + ")";
                } else {
                    last_action_log_ += "\n" + c.name + "'s Animated Weapon misses " + tk_target->name + ". (Roll: " + std::to_string(tk_roll.die_roll) + "+" + std::to_string(tk_roll.modifier) + "=" + std::to_string(tk_roll.total) + " vs AC " + std::to_string(target_ac) + ")";
                }
            }
        }
    }

    // Hellforged: Infernal Stare — deal 1d4 fire damage to all enemies each turn while active
    if (c.is_player && c.player_ptr && c.player_ptr->infernal_stare_rounds_ > 0 && c.get_current_hp() > 0) {
        int fire_dmg = local_dice.roll(4);
        for (auto& t : combatants_) {
            if (t.is_player == c.is_player || t.get_current_hp() <= 0) continue;
            if (t.is_player && t.player_ptr) t.player_ptr->take_damage(fire_dmg, local_dice);
            else if (t.creature_ptr) t.creature_ptr->take_damage(fire_dmg, local_dice);
        }
        last_action_log_ += "\n" + c.name + "'s Infernal Stare burns for " + std::to_string(fire_dmg) + " fire! (" + std::to_string(c.player_ptr->infernal_stare_rounds_) + " rounds left)";
    }

    // Ashrot Human: Smoldering Aura — deal 1 fire damage to all enemies at start of turn while active
    if (c.is_player && c.player_ptr && c.player_ptr->ashrot_aura_active_ && c.get_current_hp() > 0) {
        for (auto& t : combatants_) {
            if (t.is_player == c.is_player || t.get_current_hp() <= 0) continue;
            if (t.is_player && t.player_ptr) t.player_ptr->take_damage(1, local_dice);
            else if (t.creature_ptr) t.creature_ptr->take_damage(1, local_dice);
        }
        last_action_log_ += "\n" + c.name + "'s Smoldering Aura deals 1 fire to nearby enemies!";
    }

    // Cindervolk: Smoldering Glare — deal 1d4 fire to all enemies each turn while active
    if (c.is_player && c.player_ptr && c.player_ptr->smoldering_glare_rounds_ > 0 && c.get_current_hp() > 0) {
        int glare_dmg = local_dice.roll(4);
        for (auto& t : combatants_) {
            if (t.is_player == c.is_player || t.get_current_hp() <= 0) continue;
            if (t.is_player && t.player_ptr) t.player_ptr->take_damage(glare_dmg, local_dice);
            else if (t.creature_ptr) t.creature_ptr->take_damage(glare_dmg, local_dice);
        }
        last_action_log_ += "\n" + c.name + "'s Smoldering Glare burns for " + std::to_string(glare_dmg) + " fire! (" + std::to_string(c.player_ptr->smoldering_glare_rounds_) + " rounds left)";
    }

    // Kelpheart Human: Ocean's Embrace — regen 1 HP at start of turn while alive
    if (c.is_player && c.player_ptr && c.player_ptr->get_lineage().name == "Kelpheart Human" && c.get_current_hp() > 0) {
        c.player_ptr->heal(1);
        last_action_log_ += "\n" + c.name + "'s Ocean's Embrace regenerates 1 HP!";
    }

    // Rotborn Herald: Festering Aura — deal 1d4 necrotic to all enemies at start of their turn
    if (c.is_player && c.player_ptr && c.player_ptr->get_lineage().name == "Rotborn Herald" && c.get_current_hp() > 0) {
        int rot_dmg = local_dice.roll(4);
        for (auto& t : combatants_) {
            if (t.is_player == c.is_player || t.get_current_hp() <= 0) continue;
            if (t.is_player && t.player_ptr) t.player_ptr->take_damage(rot_dmg, local_dice);
            else if (t.creature_ptr) t.creature_ptr->take_damage(rot_dmg, local_dice);
        }
        last_action_log_ += "\n" + c.name + "'s Festering Aura deals " + std::to_string(rot_dmg) + " necrotic!";
    }

    // Bilecrawler: Corrosive Slime — enemies adjacent to the Bilecrawler take 1d4 acid at start of their turn
    for (auto& player_c : combatants_) {
        if (!c.is_player && player_c.is_player && player_c.player_ptr &&
            player_c.player_ptr->get_lineage().name == "Bilecrawler" && player_c.get_current_hp() > 0) {
            if (DungeonManager::instance().get_distance(c.id, player_c.id) <= 1) {
                int slime_dmg = local_dice.roll(4);
                if (c.creature_ptr) c.creature_ptr->take_damage(slime_dmg, local_dice);
                last_action_log_ += "\n" + c.name + " takes " + std::to_string(slime_dmg) + " acid from " + player_c.name + "'s Corrosive Slime!";
            }
        }
    }

    // Mossling: Photosynthetic Resilience — regain 1 HP in natural sunlight (not active in dungeons)
    // (dungeon environments don't provide natural sunlight; skipped in dungeon combat)

    // Sludgeling: Toxic Seep — while active, enemies adjacent take 1d4 acid + VIT DC 12 or Poisoned
    if (c.is_player && c.player_ptr && c.player_ptr->get_lineage().name == "Sludgeling" &&
        c.player_ptr->toxic_seep_rounds_ > 0 && c.get_current_hp() > 0) {
        int seep_dmg = local_dice.roll(4);
        int dc = 12;
        for (auto& t : combatants_) {
            if (t.is_player == c.is_player || t.get_current_hp() <= 0) continue;
            if (DungeonManager::instance().get_distance(c.id, t.id) <= 1) {
                if (t.creature_ptr) t.creature_ptr->take_damage(seep_dmg, local_dice);
                int save = t.creature_ptr ? local_dice.roll(20) + t.creature_ptr->get_stats().vitality : local_dice.roll(20);
                if (save < dc) {
                    if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Poisoned);
                }
                last_action_log_ += "\n" + t.name + " takes " + std::to_string(seep_dmg) + " acid from " + c.name + "'s Toxic Seep!";
            }
        }
    }

    // Bespoker: Anti-Magic Cone — while active, enemies within 6 tiles get Silent (cannot cast spells)
    for (auto& player_c : combatants_) {
        if (player_c.is_player && player_c.player_ptr &&
            player_c.player_ptr->anti_magic_cone_active_ && player_c.get_current_hp() > 0) {
            if (!c.is_player && c.creature_ptr && c.get_current_hp() > 0 &&
                DungeonManager::instance().get_distance(c.id, player_c.id) <= 6) {
                c.creature_ptr->get_status().add_condition(ConditionType::Silent);
                last_action_log_ += "\n" + c.name + " is silenced by " + player_c.name + "'s Anti-Magic Cone!";
            }
        }
    }

    // Pulsebound Hierophant: Resonant Sermon — enemies within 30ft (6 tiles) make DIV save or have disadvantage on spells
    for (auto& player_c : combatants_) {
        if (player_c.is_player && player_c.player_ptr &&
            player_c.player_ptr->resonant_sermon_active_ && player_c.get_current_hp() > 0) {
            if (!c.is_player && c.creature_ptr && c.get_current_hp() > 0 &&
                DungeonManager::instance().get_distance(c.id, player_c.id) <= 6) {
                int dc = 10 + player_c.player_ptr->get_stats().divinity;
                int save = local_dice.roll(20) + c.creature_ptr->get_stats().divinity;
                if (save < dc) {
                    c.creature_ptr->get_status().add_condition(ConditionType::Silent);
                    last_action_log_ += "\n" + c.name + " fails Resonant Sermon save — silenced this turn! (" + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                }
            }
        }
    }

    // Threnody Warden: Pulse of Silence — enemies within 2 tiles get Silent each turn
    for (auto& player_c : combatants_) {
        if (player_c.is_player && player_c.player_ptr &&
            player_c.player_ptr->get_lineage().name == "Threnody Warden" && player_c.get_current_hp() > 0) {
            if (!c.is_player && c.creature_ptr && c.get_current_hp() > 0 &&
                DungeonManager::instance().get_distance(c.id, player_c.id) <= 2) {
                c.creature_ptr->get_status().add_condition(ConditionType::Silent);
                last_action_log_ += "\n" + c.name + " is silenced by " + player_c.name + "'s Pulse of Silence!";
            }
        }
    }

    // Quillari: Quill Defense — when a combatant grapples a Quillari player, they take 1d6 at the start of their turn
    if (!c.grappling_ids.empty() && c.get_current_hp() > 0) {
        for (const auto& grappled_id : c.grappling_ids) {
            auto* grappled = find_combatant_by_id(grappled_id);
            if (grappled && grappled->is_player && grappled->player_ptr &&
                grappled->player_ptr->get_lineage().name == "Quillari") {
                int quill_dmg = local_dice.roll(6);
                if (c.is_player && c.player_ptr) c.player_ptr->take_damage(quill_dmg, local_dice);
                else if (c.creature_ptr) c.creature_ptr->take_damage(quill_dmg, local_dice);
                last_action_log_ += "\n" + c.name + " takes " + std::to_string(quill_dmg) + " piercing from " + grappled->name + "'s Quill Defense!";
            }
        }
    }

    // Perma-Heal matrix: 1d4 HP regenerated at start of each turn
    {
        bool has_perma = std::any_of(c.active_matrices.begin(), c.active_matrices.end(),
            [](const SpellMatrix& m) { return m.spell_name == "Perma-Heal" && !m.suppressed; });
        if (has_perma && c.get_current_hp() > 0) {
            int regen = local_dice.roll(4);
            if (c.is_player && c.player_ptr) c.player_ptr->heal(regen);
            else if (c.creature_ptr) c.creature_ptr->heal(regen);
            last_action_log_ += "\n" + c.name + " regenerates " + std::to_string(regen) + " HP (Perma-Heal).";
        }
    }

    // ArcaneWellspring T3: Spell Echo — echo the stored spell at start of next turn (free, no SP cost)
    if (c.is_player && c.player_ptr && !c.player_ptr->aw_spell_echo_spell_name_.empty() && c.get_current_hp() > 0) {
        std::string echo_spell = c.player_ptr->aw_spell_echo_spell_name_;
        c.player_ptr->aw_spell_echo_spell_name_ = "";
        last_action_log_ += "\n" + c.name + "'s Spell Echo fires " + echo_spell + " again (free)!";
        execute_spell(c, echo_spell, nullptr, local_dice);
    }
}

void CombatManager::start_new_round() {
    current_combatant_index_ = 0;
    round_count_++;
    for (auto& c : combatants_) {
        c.reset_round();

        auto it = c.active_matrices.begin();
        while (it != c.active_matrices.end()) {
            if (it->duration_rounds > 0) {
                it->duration_rounds--;
                if (it->duration_rounds == 0) {
                    last_action_log_ = "Spell " + it->spell_name + " on " + c.name + " has faded.";

                    for (const auto& entity_id : it->affected_entities) {
                        auto* affected = find_combatant_by_id(entity_id);
                        if (affected) {
                            const auto* spell = SpellRegistry::instance().find_spell(it->spell_name);
                            if (spell) {
                                for (auto cond : spell->conditions) {
                                    if (affected->is_player && affected->player_ptr) affected->player_ptr->get_status().remove_condition(cond);
                                    else if (affected->creature_ptr) affected->creature_ptr->get_status().remove_condition(cond);
                                }
                            }
                        }
                    }

                    // Reset Telekinesis sustained state when matrix expires
                    if (c.is_player && c.player_ptr) {
                        if (it->spell_name == "Telekinesis: Animate Weapon") {
                            c.player_ptr->tk_animate_weapon_active_ = false;
                            c.player_ptr->tk_animate_weapon_sp_committed_ = 0;
                        } else if (it->spell_name == "Telekinesis: Animate Shield" || it->spell_name == "Telekinesis: Animate Tower Shield") {
                            c.player_ptr->tk_animated_shield_ac_bonus_ = 0;
                        }
                    }

                    it = c.active_matrices.erase(it);
                    continue;
                }
            }

            const auto* spell = SpellRegistry::instance().find_spell(it->spell_name);
            if (spell && !spell->conditions.empty()) {
                auto ent_it = it->affected_entities.begin();
                while (ent_it != it->affected_entities.end()) {
                    auto* ent = find_combatant_by_id(*ent_it);
                    bool still_has = false;
                    if (ent && ent->get_current_hp() > 0) {
                        for (auto cond : spell->conditions) {
                            if (ent->is_player && ent->player_ptr && ent->player_ptr->get_status().has_condition(cond)) { still_has = true; break; }
                            else if (ent->creature_ptr && ent->creature_ptr->get_status().has_condition(cond)) { still_has = true; break; }
                        }
                    }
                    if (!still_has) ent_it = it->affected_entities.erase(ent_it);
                    else ++ent_it;
                }
            }

            bool focus_ok = true;
            if (!it->bound_item_name.empty() && c.is_player && c.player_ptr) {
                focus_ok = (c.player_ptr->get_weapon() && c.player_ptr->get_weapon()->get_name() == it->bound_item_name) ||
                           (c.player_ptr->get_shield() && c.player_ptr->get_shield()->get_name() == it->bound_item_name);
            }
            it->suppressed = !focus_ok;

            ++it;
        }

        c.start_turn();
    }
    // Kindlekin: Combustive Touch post-death spark decay — each round after going down,
    // the spark fires decrementing d4 damage to nearby creatures until fully faded.
    {
        Dice decay_dice;
        for (auto& kc : combatants_) {
            if (!kc.is_player || !kc.player_ptr) continue;
            if (kc.player_ptr->get_lineage().name != "Kindlekin") continue;
            if (kc.player_ptr->kindlekin_death_dice_count_ <= 0) continue;
            bool is_down = kc.player_ptr->get_status().has_condition(ConditionType::Dying) ||
                           kc.player_ptr->get_status().has_condition(ConditionType::Dead);
            if (!is_down) continue;
            int decay_n = kc.player_ptr->kindlekin_death_dice_count_;
            int range_tiles = 1 + (decay_n / 5);
            int decay_total = 0;
            for (int k = 0; k < decay_n; ++k) decay_total += decay_dice.roll(4);
            int affected = 0;
            for (auto& c : combatants_) {
                if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                int dist = dungeon_mode_ ? DungeonManager::instance().get_distance(kc.id, c.id) : 1;
                if (dist <= range_tiles) {
                    c.creature_ptr->take_damage(decay_total, decay_dice);
                    affected++;
                }
            }
            kc.player_ptr->kindlekin_death_dice_count_--;
            std::string fade_msg = kc.player_ptr->kindlekin_death_dice_count_ > 0
                ? " (" + std::to_string(kc.player_ptr->kindlekin_death_dice_count_) + "d4 remaining)"
                : " (spark fully faded)";
            last_action_log_ += "\n" + kc.name + "'s dying spark: " + std::to_string(decay_n) +
                "d4=" + std::to_string(decay_total) + " fire in " +
                std::to_string(range_tiles * 5) + "ft (" + std::to_string(affected) + " hit)" + fade_msg;
        }
    }

    // Fire start-of-turn effects for the first combatant in this new round
    if (!combatants_.empty()) {
        process_start_of_turn(combatants_[0]);
    }
}

bool CombatManager::set_current_combatant_by_id(const std::string& id) {
    for (size_t i = 0; i < combatants_.size(); ++i) {
        if (combatants_[i].id == id) {
            current_combatant_index_ = i;
            return true;
        }
    }
    return false;
}

Combatant* CombatManager::get_current_combatant() {
    if (current_combatant_index_ >= combatants_.size()) return nullptr;
    return &combatants_[current_combatant_index_];
}

Combatant* CombatManager::find_combatant_by_id(const std::string& id) {
    for (auto& c : combatants_) if (c.id == id) return &c;
    return nullptr;
}

int CombatManager::get_action_cost(ActionType type, const std::string& extra_param) const {
    auto* current = const_cast<CombatManager*>(this)->get_current_combatant();
    if (!current) return 1;

    // Watchling: Static Surge — all actions cost 0 AP while active
    if (current->is_player && current->player_ptr && current->player_ptr->static_surge_active_) {
        return 0;
    }

    auto apply_conditions = [&](int cost) -> int {
        if (cost == 0 || cost >= 999) return cost;
        StatusManager* cond_status = nullptr;
        if (current->is_player && current->player_ptr) cond_status = &current->player_ptr->get_status();
        else if (current->creature_ptr) cond_status = &current->creature_ptr->get_status();
        if (!cond_status) return cost;
        if (cond_status->has_condition(ConditionType::Confused) || cond_status->has_condition(ConditionType::Stunned)) cost *= 2;
        if (cond_status->has_condition(ConditionType::Dazed)) {
            int non_free = 0;
            for (auto const& [at, cnt] : current->actions_taken_this_round) {
                if (at != ActionType::Move && at != ActionType::Free && at != ActionType::EndSustainedSpell) non_free += cnt;
            }
            if (non_free >= 1) cost = 999;
        }
        return cost;
    };

    if (type == ActionType::Rest) {
        if (current->is_player && current->player_ptr) {
            int tier = current->player_ptr->get_feat_tier(FeatID::RestAndRecovery);
            if (tier >= 1 && current->player_ptr->sr_rest_free_available_) return 0;
        }
        int uses = 0;
        for (auto const& [a_type, count] : current->actions_taken_this_round) {
            if (is_basic_action(a_type) && !is_attack_action(a_type)) uses += count;
        }
        return apply_conditions(uses + 1);
    } else if (type == ActionType::EfficientRecuperation) {
        return 0;
    } else if (is_attack_action(type)) {
        // Sunderborn: Blood Frenzy — first attack after a kill costs 0 AP
        if (current->is_player && current->player_ptr &&
            current->player_ptr->get_lineage().name == "Sunderborn Human" &&
            current->player_ptr->sunderborn_frenzy_available_) {
            return 0;
        }
        {
            int cost = current->total_attacks_this_round + 1;
            // MartialFocus T1: Battle-Ready — armed flag reduces next attack cost by 1
            if (current->is_player && current->player_ptr && current->player_ptr->mf_battle_ready_armed_) {
                cost = std::max(0, cost - 1);
            }
            return apply_conditions(cost);
        }
    } else if (type == ActionType::ActivateSustainedSpell) {
        size_t sep = extra_param.find('|');
        std::string s_name = (sep == std::string::npos) ? extra_param : extra_param.substr(0, sep);

        const auto* spell = SpellRegistry::instance().find_spell(s_name);
        if (spell && spell->is_attack) {
            return apply_conditions(current->total_attacks_this_round + 1);
        }

        auto it = std::find_if(current->active_matrices.begin(), current->active_matrices.end(),
            [&](const SpellMatrix& m) { return m.spell_name == s_name; });

        if (it != current->active_matrices.end() && !it->used_free_activation_this_turn) return 0;
        return apply_conditions(1);
    } else if (is_basic_action(type)) {
        int uses = 0;
        for (auto const& [a_type, count] : current->actions_taken_this_round) {
            if (is_basic_action(a_type) && !is_attack_action(a_type)) uses += count;
        }
        return apply_conditions(uses + 1);
    } else if (type == ActionType::Move) {
        if (dungeon_mode_) {
            int budget = current->movement_tiles_remaining;
            bool grappling = !current->grappling_ids.empty();
            int tier = (current->is_player && current->player_ptr) ? current->player_ptr->get_feat_tier(FeatID::GraspOfTheTitan) : 0;
            int threshold = (grappling && tier < 2) ? 2 : 1;
            return (budget >= threshold) ? 0 : 999; // free within budget, blocked when exhausted
        }
        return 0;
    } else if (type == ActionType::ExtraMove) {
        if (!current->has_used_extra_movement) return apply_conditions(1); // costs 1 AP
        return 999; // already used this turn
    } else if (type == ActionType::Free || type == ActionType::EndSustainedSpell) {
        return 0;
    } else if (type == ActionType::LineageTrait) {
        // Plains lineage traits
        if (extra_param == "SunsFavor") return apply_conditions(3);
        if (extra_param == "Regrowth") return apply_conditions(2);
        if (extra_param == "IllusoryEcho") return apply_conditions(2);
        if (extra_param == "ArmoredPlating") return apply_conditions(2);
        if (extra_param == "MechanicalMindRecall") return apply_conditions(2);
        // SubEden lineage traits
        if (extra_param == "EnchantingPresence") return apply_conditions(2);
        if (extra_param == "SporeCloud") return apply_conditions(2);
        if (extra_param == "FungalFortitude") return apply_conditions(2);
        if (extra_param == "Photosynthesis") return apply_conditions(1);
        if (extra_param == "FeyStep") return apply_conditions(1);
        // Eternal Library lineage traits
        if (extra_param == "Origami") return apply_conditions(3);
        if (extra_param == "OrigamiMaintain") return apply_conditions(1);
        if (extra_param == "MnemonicRecall") return apply_conditions(0);
        if (extra_param == "SentinelStand") return apply_conditions(1);
        // House of Arachana lineage traits
        if (extra_param == "ToxicRoots") return apply_conditions(2);
        if (extra_param == "WitherbornDecay") return apply_conditions(0); // free after short rest
        if (extra_param == "SilkenTrap") return apply_conditions(2);
        if (extra_param == "DrainingFangs") return apply_conditions(1);
        if (extra_param == "LurkerStep") return apply_conditions(0); // free action
        if (extra_param == "VenomousBite") return apply_conditions(1);
        if (extra_param == "ExtractVenom") return apply_conditions(1);
        if (extra_param == "HypnoticGaze") return apply_conditions(3);
        // Wilds of Endero lineage traits
        if (extra_param == "PackHowl") return apply_conditions(0);  // Free Action
        if (extra_param == "NaturesGrace") return apply_conditions(1);
        if (extra_param == "AdaptiveHide") return apply_conditions(1);
        if (extra_param == "VerdantCurse") return apply_conditions(0); // reaction
        // Qunorum lineage traits
        if (extra_param == "KindleFlame") return apply_conditions(2);
        if (extra_param == "QuillLaunch") return apply_conditions(2);
        if (extra_param == "VersatileGrant") return apply_conditions(1);
        // AlchemicalAffinity, ResilientSpirit, QuickReflexes are 0-cost (reaction/free)
        // Metropolitan lineage traits
        if (extra_param == "ArcaneSurge") return apply_conditions(0);
        if (extra_param == "ScrapInstinct") return apply_conditions(0);
        if (extra_param == "SteamJet") return apply_conditions(2);
        if (extra_param == "TetherStep") return apply_conditions(3);
        if (extra_param == "ResonantVoice") return apply_conditions(0);
        if (extra_param == "MarketWhisperer") return apply_conditions(0);
        // Upper Forty lineage traits
        if (extra_param == "ArcaneTinker") return apply_conditions(0);
        if (extra_param == "GremlinsLuck") return apply_conditions(0);
        if (extra_param == "HexMark") return apply_conditions(2);
        if (extra_param == "Witchblood") return apply_conditions(0);
        if (extra_param == "CommandingVoice") return apply_conditions(2);
        // Lower Forty lineage traits
        if (extra_param == "OverdriveCore") return apply_conditions(0);
        if (extra_param == "GremlinTinker") return apply_conditions(0);
        if (extra_param == "GremlinSabotage") return apply_conditions(0);
        if (extra_param == "ReflectHex") return apply_conditions(0);
        if (extra_param == "ScrapSense") return apply_conditions(0);
        if (extra_param == "IronStomachPoison") return apply_conditions(2);
        // Shadows Beneath lineage traits
        if (extra_param == "ShadowGlide") return apply_conditions(3);
        if (extra_param == "Shadowgrasp") return apply_conditions(3);
        if (extra_param == "QuackAlarm") return apply_conditions(0);
        if (extra_param == "SableNightVision") return apply_conditions(0);
        if (extra_param == "Veilstep") return apply_conditions(0);
        if (extra_param == "DuskbornGrace") return apply_conditions(0);
        // Corrupted Marshes lineage traits
        if (extra_param == "MossyShroud") return apply_conditions(0);
        if (extra_param == "MireBurst") return apply_conditions(0);
        if (extra_param == "SoothingAura") return apply_conditions(0);
        if (extra_param == "Dreamscent") return apply_conditions(0);
        // Crypt lineage traits
        if (extra_param == "BloodlettingBlow") return apply_conditions(3);
        if (extra_param == "Boneclatter") return apply_conditions(3);
        if (extra_param == "DiseasebornCurse") return apply_conditions(0);
        if (extra_param == "UmbralDodge") return apply_conditions(3);
        if (extra_param == "GnawingGrin") return apply_conditions(0);
        // Spindle York's Schism lineage traits
        if (extra_param == "StonesEndurance") return apply_conditions(0);
        if (extra_param == "CrystalResilience") return apply_conditions(0);
        if (extra_param == "HarmonicLink") return apply_conditions(0);
        // Peaks of Isolation lineage traits
        if (extra_param == "WinterBreath") return apply_conditions(3);
        if (extra_param == "FrostBurst") return apply_conditions(2);
        if (extra_param == "FrostbornIcewalk") return apply_conditions(0);
        if (extra_param == "FrozenVeil") return apply_conditions(0);
        if (extra_param == "StormCall") return apply_conditions(3);
        if (extra_param == "GraveBind") return apply_conditions(3);
        // Pharaoh's Den lineage traits
        if (extra_param == "Sporespit") return apply_conditions(3);
        if (extra_param == "RotbornItem") return apply_conditions(0);
        if (extra_param == "BloodlettingTouch") return apply_conditions(3);
        if (extra_param == "VelvetTerror") return apply_conditions(0);
        if (extra_param == "TombSense") return apply_conditions(0);
        if (extra_param == "Mindscratch") return apply_conditions(0);
        // The Darkness lineage traits
        if (extra_param == "GravitationalLeap") return apply_conditions(0);
        if (extra_param == "NightborneVeilstep") return apply_conditions(3);
        if (extra_param == "CreepingDark") return apply_conditions(0);
        // Arcane Collapse lineage traits
        if (extra_param == "AbsorbMagic") return apply_conditions(0);
        if (extra_param == "DregspawnExtend") return apply_conditions(0);
        if (extra_param == "AberrantFlex") return apply_conditions(0);
        if (extra_param == "VoidAura") return apply_conditions(0);
        if (extra_param == "CrystalSlash") return apply_conditions(0);
        // Argent Hall lineage traits
        if (extra_param == "SealOfFrost") return apply_conditions(0);
        if (extra_param == "SilentLedger") return apply_conditions(3);
        if (extra_param == "GlacialWall") return apply_conditions(3);
        if (extra_param == "UnyieldingBulwark") return apply_conditions(0);
        if (extra_param == "StoneMoldReshape") return apply_conditions(0);
        if (extra_param == "ArchitectsShield") return apply_conditions(3);
        if (extra_param == "MinersInstinct") return apply_conditions(3);
        // Glass Passage lineage traits
        if (extra_param == "WindCloak") return apply_conditions(0);
        if (extra_param == "Gustcaller") return apply_conditions(3);
        if (extra_param == "PangolArmorReact") return apply_conditions(0);
        if (extra_param == "CurlUp") return apply_conditions(0);
        if (extra_param == "Uncurl") return apply_conditions(1);
        if (extra_param == "GildedBearing") return apply_conditions(0);
        if (extra_param == "ChromaticShift") return apply_conditions(0);
        if (extra_param == "PrismaticReflection") return apply_conditions(0);
        if (extra_param == "DustShroud") return apply_conditions(0);
        if (extra_param == "DustStrike") return apply_conditions(0);
        // Sacral Separation lineage traits
        if (extra_param == "ShatterPulseGlassborn") return apply_conditions(0);
        if (extra_param == "PrismVeins") return apply_conditions(0);
        if (extra_param == "DeathsWhisper") return apply_conditions(0);
        if (extra_param == "UnstableMutation") return apply_conditions(0);
        if (extra_param == "FracturedMind") return apply_conditions(0);
        // Infernal Machine lineage traits
        if (extra_param == "LuminousToggle") return apply_conditions(0);
        if (extra_param == "WaxenForm") return apply_conditions(3);
        if (extra_param == "PainMadeFlesh") return apply_conditions(0);
        if (extra_param == "InfernalStare") return apply_conditions(0);
        if (extra_param == "InfernalSmite") return apply_conditions(0);
        if (extra_param == "WhipLash") return apply_conditions(3);
        // Titan's Lament lineage traits
        if (extra_param == "CursedSpark") return apply_conditions(0);
        if (extra_param == "DesertWalker") return apply_conditions(0);
        if (extra_param == "Gore") return apply_conditions(0);
        if (extra_param == "StubbornWill") return apply_conditions(0);
        if (extra_param == "HibernateUrsari") return apply_conditions(0);
        // The Mortal Arena lineage traits
        if (extra_param == "Blazeblood") return apply_conditions(0);
        if (extra_param == "SootSight") return apply_conditions(0);
        if (extra_param == "ShockPulse") return apply_conditions(3);
        if (extra_param == "SunderbornHibernate") return apply_conditions(0);
        if (extra_param == "LimbRegrowth") return apply_conditions(0);
        // Vulcan Valley lineage traits
        if (extra_param == "AshrotAuraToggle") return apply_conditions(0);
        if (extra_param == "AshrotAuraBurst") return apply_conditions(0);
        if (extra_param == "SmolderingGlare") return apply_conditions(0);
        if (extra_param == "DraconicAwakening") return apply_conditions(0);
        if (extra_param == "BreathWeapon") return apply_conditions(3);
        // The Isles lineage traits
        if (extra_param == "AbyssariGlowToggle") return apply_conditions(0);
        if (extra_param == "AbyssariPulse") return apply_conditions(0);
        if (extra_param == "MirelingEscape") return apply_conditions(0);
        if (extra_param == "LunarRadiance") return apply_conditions(0);
        if (extra_param == "BrineCone") return apply_conditions(3);
        if (extra_param == "EbbAndFlow") return apply_conditions(0);
        // The Depths of Denorim lineage traits
        if (extra_param == "HydrasResilience") return apply_conditions(0);
        if (extra_param == "LimbSacrifice") return apply_conditions(0);
        if (extra_param == "Tidebind") return apply_conditions(3);
        if (extra_param == "AbyssalMutation") return apply_conditions(0);
        // Moroboros lineage traits
        if (extra_param == "CloudlingFly") return apply_conditions(0);
        if (extra_param == "MistForm") return apply_conditions(0);
        if (extra_param == "SurgeStep") return apply_conditions(0);
        if (extra_param == "HuntersFocus") return apply_conditions(0);
        if (extra_param == "WeirdResilience") return apply_conditions(0);
        if (extra_param == "RotVoice") return apply_conditions(3);
        // Gloamfen Hollow lineage traits
        if (extra_param == "VoluntaryGasVent") return apply_conditions(0);
        if (extra_param == "ObedientAuraToggle") return apply_conditions(0);
        if (extra_param == "MemoryEchoToggle") return apply_conditions(0);
        if (extra_param == "LeechHex") return apply_conditions(0);
        if (extra_param == "WitchsDraught") return apply_conditions(3);
        if (extra_param == "HexOfWithering") return apply_conditions(2);
        // The Astral Tear lineage traits
        if (extra_param == "EtherealStep") return apply_conditions(0);
        if (extra_param == "VeiledPresence") return apply_conditions(0);
        if (extra_param == "ConvergentSynthesis") return apply_conditions(0);
        if (extra_param == "Dreamwalk") return apply_conditions(0);
        if (extra_param == "PhaseStep") return apply_conditions(3);
        if (extra_param == "Flicker") return apply_conditions(0);
        if (extra_param == "Shadowmeld") return apply_conditions(0);
        if (extra_param == "VoidStep") return apply_conditions(0);
        // L.I.T.O. lineage traits
        if (extra_param == "CorruptBreath") return apply_conditions(3);
        if (extra_param == "DarkLineagePulse") return apply_conditions(0);
        if (extra_param == "SapHealing") return apply_conditions(0);
        if (extra_param == "EntropyTouch") return apply_conditions(0);
        if (extra_param == "Unravel") return apply_conditions(0);
        if (extra_param == "MindBleed") return apply_conditions(0);
        if (extra_param == "NullMindShare") return apply_conditions(0);
        if (extra_param == "AmorphousSplit") return apply_conditions(0);
        if (extra_param == "ToxicSeep") return apply_conditions(3);
        // The West End Gullet lineage traits
        if (extra_param == "DeathEaterMemory") return apply_conditions(0);
        if (extra_param == "WingsOfForgotten") return apply_conditions(3);
        if (extra_param == "ShiftingFormToggle") return apply_conditions(0);
        if (extra_param == "DisjointedLeap") return apply_conditions(0);
        if (extra_param == "TemporalFlicker") return apply_conditions(0);
        if (extra_param == "HauntingWail") return apply_conditions(3);
        if (extra_param == "MirrorMove") return apply_conditions(3);
        if (extra_param == "SilentScream") return apply_conditions(0);
        if (extra_param == "RealitySlip") return apply_conditions(0);
        if (extra_param == "UnnervinGaze") return apply_conditions(3);
        // The Cradling Depths lineage traits
        if (extra_param == "ResonantFormMimic") return apply_conditions(0);
        if (extra_param == "DivineMimicry") return apply_conditions(0);
        if (extra_param == "VitalSurge") return apply_conditions(0);
        if (extra_param == "AbyssalGlow") return apply_conditions(3);
        // Terminus Volarus lineage traits
        if (extra_param == "LanternbornGlowToggle") return apply_conditions(0);
        if (extra_param == "GuidingLight") return apply_conditions(3);
        if (extra_param == "BeaconAbsorb") return apply_conditions(0);
        if (extra_param == "KeenSightFocus") return apply_conditions(3);
        if (extra_param == "RadiantPulse") return apply_conditions(3);
        // The City of Eternal Light lineage traits
        if (extra_param == "LightStepTeleport") return apply_conditions(0);
        if (extra_param == "DawnsBlessingActivate") return apply_conditions(0);
        if (extra_param == "RadiantWard") return apply_conditions(0);
        if (extra_param == "Flareburst") return apply_conditions(0);
        if (extra_param == "RunicSurgePrime") return apply_conditions(0);
        if (extra_param == "MysticPulse") return apply_conditions(0);
        if (extra_param == "Windstep") return apply_conditions(0);
        // The Hallowed Sacrament lineage traits
        if (extra_param == "GlimmerfolkGlowToggle") return apply_conditions(0);
        if (extra_param == "Dazzle") return apply_conditions(0);
        if (extra_param == "VaporFormActivate") return apply_conditions(0);
        if (extra_param == "DriftingFog") return apply_conditions(0);
        if (extra_param == "SporeBloom") return apply_conditions(3);
        if (extra_param == "WindswiftActivate") return apply_conditions(0);
        // The Land of Tomorrow lineage traits
        if (extra_param == "TemporalShift") return apply_conditions(0);
        if (extra_param == "ArcanePulse") return apply_conditions(3);
        if (extra_param == "RunicFlowAuto") return apply_conditions(0);
        if (extra_param == "SparkforgedArcaneSurge") return apply_conditions(0);
        if (extra_param == "StaticSurge") return apply_conditions(0);
        // Sublimini Dominus lineage traits
        if (extra_param == "EchoReflection") return apply_conditions(3);
        if (extra_param == "MemoryTap") return apply_conditions(0);
        if (extra_param == "VoidCloakToggle") return apply_conditions(0);
        if (extra_param == "SpellSink") return apply_conditions(3);
        if (extra_param == "WarpResistanceToggle") return apply_conditions(0);
        if (extra_param == "SurgePulse") return apply_conditions(3);
        // Beating Heart of The Void lineage traits
        if (extra_param == "ParalyzingRay") return apply_conditions(2);
        if (extra_param == "FearRay") return apply_conditions(2);
        if (extra_param == "HealingRay") return apply_conditions(2);
        if (extra_param == "NecroticRay") return apply_conditions(1);
        if (extra_param == "DisintegrationRay") return apply_conditions(3);
        if (extra_param == "AntiMagicConeToggle") return apply_conditions(0);
        if (extra_param == "NeuralLiquefaction") return apply_conditions(2);
        if (extra_param == "SkullDrill") return apply_conditions(3);
        if (extra_param == "ResonantSermonToggle") return apply_conditions(0);
        if (extra_param == "VoidCommunion") return apply_conditions(0);
        if (extra_param == "ThrenodySlamAttack") return apply_conditions(3);
        // Stat feat active actions
        if (extra_param == "DeepReserves") return apply_conditions(1);
        if (extra_param == "SpellEchoArm") return apply_conditions(1);
        if (extra_param == "InfiniteFont") return apply_conditions(1);
        if (extra_param == "BattleReady") return apply_conditions(1);
        if (extra_param == "EnduringHeal") return apply_conditions(0);
        if (extra_param == "SG_Reroll") return apply_conditions(0);
        if (extra_param == "SG_Advantage") return apply_conditions(0);
        if (extra_param == "SG_AutoSucceed") return apply_conditions(0);
        if (extra_param == "SG_Heal") return apply_conditions(0);
        return 0; // Reactions and free traits cost 0 AP
    }

    return apply_conditions(1);
}

bool CombatManager::perform_action(ActionType type, Dice& dice, const std::string& param) {
    auto* current = get_current_combatant();
    if (!current) return false;

    int cost = get_action_cost(type, param);
    int current_ap = current->get_current_ap();

    if (current_ap < cost) {
        last_action_log_ = current->name + " does not have enough AP!";
        return false;
    }

    bool success = handle_action_logic(type, *current, dice, param);

    if (success) {
        if (is_attack_action(type)) {
            current->total_attacks_this_round++;
        } else if (type == ActionType::ActivateSustainedSpell) {
            size_t sep = param.find('|');
            std::string s_name = (sep == std::string::npos) ? param : param.substr(0, sep);
            const auto* spell = SpellRegistry::instance().find_spell(s_name);
            if (spell && spell->is_attack) {
                current->total_attacks_this_round++;
            }
        }
        current->spend_ap(cost);
        current->actions_taken_this_round[type]++;
        // Watchling: Static Surge — count actions taken while surge is active
        if (current->is_player && current->player_ptr && current->player_ptr->static_surge_active_
            && type != ActionType::Free && type != ActionType::Move && type != ActionType::EndSustainedSpell
            && !(type == ActionType::LineageTrait && param == "StaticSurge")) {
            current->player_ptr->static_surge_action_count_++;
        }
        return true;
    }
    return false;
}

bool CombatManager::handle_action_logic(ActionType action, Combatant& current, Dice& dice, const std::string& param) {
    switch (action) {
        case ActionType::Move: {
            size_t sep = param.find('|');
            if (sep != std::string::npos) {
                int nx = std::stoi(param.substr(0, sep));
                int ny = std::stoi(param.substr(sep + 1));
                if (dungeon_mode_) {
                   // Capture grappler's old position before moving so we can apply the
                   // same delta to any grappled targets (maintaining relative position).
                   Vector2i old_pos = DungeonManager::instance().get_entity_position(current.id);

                   if (DungeonManager::instance().move_entity(current.id, nx, ny)) {
                       int cost_in_tiles = 1;
                       if (!current.grappling_ids.empty()) {
                           int tier = (current.is_player && current.player_ptr) ? current.player_ptr->get_feat_tier(FeatID::GraspOfTheTitan) : 0;
                           if (tier < 2) cost_in_tiles = 2;
                       }
                       // Elevation change (+5ft up or down) costs an extra movement tile
                       const DungeonMap* dmap = DungeonManager::instance().get_map();
                       if (dmap) {
                           int old_elev = dmap->get_elevation(old_pos.x, old_pos.y);
                           int new_elev = dmap->get_elevation(nx, ny);
                           if (std::abs(new_elev - old_elev) >= 1) cost_in_tiles++;
                       }

                       if (current.movement_tiles_remaining >= cost_in_tiles) {
                           current.movement_tiles_remaining -= cost_in_tiles;
                       } else {
                           current.movement_tiles_remaining = 0; // clamp, shouldn't reach here normally
                       }
                       // WorldbreakerStep: track movement tiles this turn
                       if (current.is_player && current.player_ptr &&
                           current.player_ptr->get_feat_tier(FeatID::WorldbreakerStep) >= 1) {
                           current.player_ptr->worldbreaker_step_movement_this_turn_ += cost_in_tiles;
                       }

                       if (!current.grappling_ids.empty()) {
                           int dx = nx - old_pos.x;
                           int dy = ny - old_pos.y;
                           last_action_log_ = current.name + " moves and attempts to drag their grappled targets.";
                           auto it = current.grappling_ids.begin();
                           while (it != current.grappling_ids.end()) {
                               auto* target = find_combatant_by_id(*it);
                               if (!target) {
                                   it = current.grappling_ids.erase(it);
                                   continue;
                               }

                               int titan_tier = (current.is_player && current.player_ptr) ? current.player_ptr->get_feat_tier(FeatID::GraspOfTheTitan) : 0;
                               RollType attacker_type = (titan_tier >= 1) ? RollType::Advantage : RollType::Normal;
                               RollResult attacker_roll;
                               if (current.is_player && current.player_ptr) attacker_roll = current.player_ptr->roll_skill_check(dice, SkillType::Exertion, attacker_type);
                               else if (current.creature_ptr) attacker_roll = dice.roll_d20(attacker_type, current.creature_ptr->get_stats().strength);

                               RollResult defender_roll;
                               int def_exert = (target->is_player && target->player_ptr) ? target->player_ptr->get_skills().get_skill(SkillType::Exertion) : (target->creature_ptr ? target->creature_ptr->get_stats().strength : 0);
                               int def_nimble = (target->is_player && target->player_ptr) ? target->player_ptr->get_skills().get_skill(SkillType::Nimble) : (target->creature_ptr ? target->creature_ptr->get_stats().speed : 0);
                               SkillType def_skill = (def_exert >= def_nimble) ? SkillType::Exertion : SkillType::Nimble;

                               if (target->is_player && target->player_ptr) defender_roll = target->player_ptr->roll_skill_check(dice, def_skill);
                               else if (target->creature_ptr) defender_roll = dice.roll_d20(RollType::Normal, (def_skill == SkillType::Exertion ? target->creature_ptr->get_stats().strength : target->creature_ptr->get_stats().speed));

                               if (attacker_roll.total >= defender_roll.total) {
                                   // Move target by the same delta to preserve relative position
                                   Vector2i tpos = DungeonManager::instance().get_entity_position(target->id);
                                   DungeonManager::instance().move_entity(target->id, tpos.x + dx, tpos.y + dy);
                                   last_action_log_ += "\n- " + target->name + " is dragged along. (" + std::to_string(attacker_roll.total) + " vs " + std::to_string(defender_roll.total) + ")";
                                   ++it;
                               } else {
                                   last_action_log_ += "\n- " + target->name + " resists! The grapple is broken. (" + std::to_string(attacker_roll.total) + " vs " + std::to_string(defender_roll.total) + ")";
                                   target->grappled_by_id = "";
                                   if (target->is_player && target->player_ptr) {
                                       target->player_ptr->get_status().remove_condition(ConditionType::Grappled);
                                       target->player_ptr->get_status().remove_condition(ConditionType::Restrained);
                                   } else if (target->creature_ptr) {
                                       target->creature_ptr->get_status().remove_condition(ConditionType::Grappled);
                                       target->creature_ptr->get_status().remove_condition(ConditionType::Restrained);
                                   }
                                   it = current.grappling_ids.erase(it);
                               }
                           }
                       }

                       // Panoplian: Sentinel's Stand — opportunity attack on any creature that moves away
                       for (auto& sentinel : combatants_) {
                           if (sentinel.id != current.id && sentinel.is_player && sentinel.player_ptr &&
                               sentinel.player_ptr->get_lineage().name == "Panoplian" &&
                               sentinel.player_ptr->panoplian_sentinel_stand_active_ &&
                               sentinel.get_current_hp() > 0) {
                               Vector2i spos = DungeonManager::instance().get_entity_position(sentinel.id);
                               int old_dist = std::abs(old_pos.x - spos.x) + std::abs(old_pos.y - spos.y);
                               if (old_dist <= 1) { // was adjacent before move
                                   last_action_log_ += "\n[Sentinel's Stand: " + sentinel.name + " takes an opportunity attack!]";
                                   execute_attack(sentinel, current, dice, false, 0);
                               }
                           }
                       }

                       return true;
                   }
                }
            }
            return false;
        }
        case ActionType::ExtraMove: {
            // Spend 1 AP to gain a full second movement this turn
            current.movement_tiles_remaining = current.get_movement_speed() / 5;
            current.has_used_extra_movement = true;
            last_action_log_ = current.name + " uses an action to move again! (" + std::to_string(current.movement_tiles_remaining) + " tiles)";
            return true;
        }
        case ActionType::MeleeAttack:
        case ActionType::RangedAttack:
        case ActionType::UnarmedAttack: {
            size_t sep = param.find('|');
            std::string t_id = (sep == std::string::npos) ? param : param.substr(0, sep);
            std::string s_name = (sep == std::string::npos) ? "" : param.substr(sep + 1);

            auto* target = find_combatant_by_id(t_id);
            if (target && target->get_current_hp() > 0) {
                int elevation_mod = 0;
                if (dungeon_mode_) {
                    int dist = DungeonManager::instance().get_distance(current.id, target->id);
                    if (action == ActionType::MeleeAttack || action == ActionType::UnarmedAttack) {
                        if (dist > 1) {
                            last_action_log_ = "Target is too far for a melee attack!";
                            return false;
                        }
                    } else if (action == ActionType::RangedAttack) {
                        if (dist > 20) { // 100ft approx
                            last_action_log_ = "Target is beyond maximum range!";
                            return false;
                        }
                        const DungeonMap* dmap = DungeonManager::instance().get_map();
                        Vector2i apos = DungeonManager::instance().get_entity_position(current.id);
                        Vector2i tpos = DungeonManager::instance().get_entity_position(target->id);
                        if (dmap) {
                            if (!DungeonManager::instance().has_ranged_los(apos, tpos)) {
                                last_action_log_ = "High ground is blocking the shot!";
                                return false;
                            }
                            int a_elev = dmap->get_elevation(apos.x, apos.y);
                            int t_elev = dmap->get_elevation(tpos.x, tpos.y);
                            if (t_elev > a_elev) elevation_mod = -2;       // Shooting uphill: -2 penalty
                            else if (a_elev > t_elev) elevation_mod = 2;   // Shooting downhill: +2 bonus
                        }
                    }
                }

                bool hit = execute_attack(current, *target, dice, (action == ActionType::UnarmedAttack), elevation_mod);

                // TitanicDamage T1: push target 10ft on hit (represented as speed penalty in dungeon mode)
                if (hit && current.is_player && current.player_ptr &&
                    current.player_ptr->get_feat_tier(FeatID::TitanicDamage) >= 1 &&
                    action != ActionType::UnarmedAttack && current.player_ptr->get_weapon() &&
                    current.player_ptr->get_weapon()->get_category() == WeaponCategory::Martial) {
                    if (target->is_player && target->player_ptr) {
                        target->player_ptr->speed_penalty_ += 10;
                        last_action_log_ += " [Mighty Blow: pushed back!]";
                    } else if (target->creature_ptr) {
                        last_action_log_ += " [Mighty Blow: pushed back!]";
                    }
                }

                // MartialFocus T1: Battle-Ready — consume armed flag after attack
                if (current.is_player && current.player_ptr && current.player_ptr->mf_battle_ready_armed_) {
                    current.player_ptr->mf_battle_ready_armed_ = false;
                }
                // MartialFocus T5: Unstoppable Assault — first attack each round grants +1 movement tile
                if (current.is_player && current.player_ptr &&
                    current.player_ptr->get_feat_tier(FeatID::MartialFocus) >= 5 &&
                    !current.player_ptr->mf_unstoppable_assault_used_rnd_) {
                    current.player_ptr->mf_unstoppable_assault_used_rnd_ = true;
                    current.movement_tiles_remaining += 1;
                    last_action_log_ += " [Unstoppable Assault: +1 movement tile!]";
                }

                if (hit && !s_name.empty()) {
                    auto it = std::find_if(current.active_matrices.begin(), current.active_matrices.end(),
                        [&](const SpellMatrix& m) { return m.spell_name == s_name; });

                    bool focus_ok = true;
                    if (it != current.active_matrices.end() && !it->bound_item_name.empty() && current.is_player && current.player_ptr) {
                        focus_ok = (current.player_ptr->get_weapon() && current.player_ptr->get_weapon()->get_name() == it->bound_item_name) ||
                                   (current.player_ptr->get_shield() && current.player_ptr->get_shield()->get_name() == it->bound_item_name);
                    }

                    if (it != current.active_matrices.end() && !it->suppressed && focus_ok) {
                        execute_spell(current, s_name, target, dice, true, true);
                        it->used_free_activation_this_turn = true;
                    }
                }
                return true;
            }
            return false;
        }
        case ActionType::ThrowItem: {
            auto* target = find_combatant_by_id(param);
            if (!target || target->get_current_hp() <= 0) return false;
            if (dungeon_mode_) {
                int dist = DungeonManager::instance().get_distance(current.id, target->id);
                if (dist > 6) { last_action_log_ = "Target is out of throwing range!"; return false; }
            }
            int iw_tier = (current.is_player && current.player_ptr) ? current.player_ptr->get_feat_tier(FeatID::ImprovisedWeaponMastery) : 0;
            int base_dmg;
            if (iw_tier >= 3) base_dmg = dice.roll(10);
            else if (iw_tier >= 2) base_dmg = dice.roll(6);
            else base_dmg = dice.roll(4);
            int mod = 0;
            if (current.is_player && current.player_ptr)
                mod = iw_tier >= 2 ? current.player_ptr->get_stats().strength : 0;
            int total = base_dmg + mod;
            // T5: magical + splash to adjacent
            if (iw_tier >= 5) {
                for (auto& c : combatants_) {
                    if (c.id != target->id && !c.is_player && c.get_current_hp() > 0) {
                        if (dungeon_mode_ && DungeonManager::instance().get_distance(target->id, c.id) <= 1) {
                            int splash = dice.roll(4);
                            if (c.creature_ptr) c.creature_ptr->take_damage(splash, dice);
                        }
                    }
                }
            }
            if (target->is_player && target->player_ptr) target->player_ptr->take_damage(total, dice);
            else if (target->creature_ptr) target->creature_ptr->take_damage(total, dice);
            last_action_log_ = current.name + " throws an item at " + target->name + " for " + std::to_string(total) + " bludgeoning damage!";
            return true;
        }
        case ActionType::Grapple: {
            auto* target = find_combatant_by_id(param);
            if (!target || target->get_current_hp() <= 0) return false;

            if (dungeon_mode_) {
                if (DungeonManager::instance().get_distance(current.id, target->id) > 1) {
                    last_action_log_ = "Target is too far to grapple!";
                    return false;
                }
            }

            int titan_tier = (current.is_player && current.player_ptr) ? current.player_ptr->get_feat_tier(FeatID::GraspOfTheTitan) : 0;
            int max_grapples = (titan_tier >= 3) ? 2 : 1;

            if (titan_tier >= 3) {
                bool is_too_big = (!target->is_player && target->creature_ptr && (target->creature_ptr->get_category() == CreatureCategory::ApexMonster || target->creature_ptr->get_category() == CreatureCategory::Kaiju));
                if (is_too_big) {
                    last_action_log_ = target->name + " is too large to grapple with one hand!";
                    return false;
                }
            }

            if ((int)current.grappling_ids.size() >= max_grapples) {
                last_action_log_ = current.name + " cannot grapple any more creatures!";
                return false;
            }

            RollType attacker_type = (titan_tier >= 1) ? RollType::Advantage : RollType::Normal;
            RollResult attacker_roll;
            if (current.is_player && current.player_ptr) attacker_roll = current.player_ptr->roll_skill_check(dice, SkillType::Exertion, attacker_type);
            else if (current.creature_ptr) attacker_roll = dice.roll_d20(attacker_type, current.creature_ptr->get_stats().strength);

            RollResult defender_roll;
            int def_exert = (target->is_player && target->player_ptr) ? target->player_ptr->get_skills().get_skill(SkillType::Exertion) : (target->creature_ptr ? target->creature_ptr->get_stats().strength : 0);
            int def_nimble = (target->is_player && target->player_ptr) ? target->player_ptr->get_skills().get_skill(SkillType::Nimble) : (target->creature_ptr ? target->creature_ptr->get_stats().speed : 0);

            SkillType def_skill = (def_exert >= def_nimble) ? SkillType::Exertion : SkillType::Nimble;
            if (target->is_player && target->player_ptr) defender_roll = target->player_ptr->roll_skill_check(dice, def_skill);
            else if (target->creature_ptr) defender_roll = dice.roll_d20(RollType::Normal, (def_skill == SkillType::Exertion ? target->creature_ptr->get_stats().strength : target->creature_ptr->get_stats().speed));

            last_action_log_ = current.name + " attempts to grapple " + target->name + " (Roll: " + std::to_string(attacker_roll.total) + " vs " + std::to_string(defender_roll.total) + ")";

            if (attacker_roll.total >= defender_roll.total) {
                last_action_log_ += " - SUCCESS!";
                current.grappling_ids.push_back(target->id);
                target->grappled_by_id = current.id;
                if (target->is_player && target->player_ptr) {
                    target->player_ptr->get_status().add_condition(ConditionType::Grappled);
                    target->player_ptr->get_status().add_condition(ConditionType::Restrained);
                } else if (target->creature_ptr) {
                    target->creature_ptr->get_status().add_condition(ConditionType::Grappled);
                    target->creature_ptr->get_status().add_condition(ConditionType::Restrained);
                }
            } else {
                last_action_log_ += " - FAILED.";
            }
            return true;
        }
        case ActionType::EscapeGrapple: {
            if (current.grappled_by_id.empty()) return false;
            auto* grappler = find_combatant_by_id(current.grappled_by_id);
            if (!grappler) { current.grappled_by_id = ""; return true; }

            int titan_tier = (current.is_player && current.player_ptr) ? current.player_ptr->get_feat_tier(FeatID::GraspOfTheTitan) : 0;
            int grappler_tier = (grappler->is_player && grappler->player_ptr) ? grappler->player_ptr->get_feat_tier(FeatID::GraspOfTheTitan) : 0;

            RollType escape_type = (titan_tier >= 1) ? RollType::Advantage : RollType::Normal;
            if (grappler_tier >= 3) escape_type = RollType::Disadvantage; // Master of Holds (T3) secondary
            // Bookborn: Origami — advantage on escape grapple/restraint checks
            if (current.is_player && current.player_ptr &&
                current.player_ptr->get_lineage().name == "Bookborn" &&
                current.player_ptr->bookborn_origami_active_) {
                escape_type = RollType::Advantage;
            }
            // Duckslings: Slippery — advantage on escape grapple checks
            if (current.is_player && current.player_ptr &&
                current.player_ptr->get_lineage().name == "Duckslings" &&
                escape_type == RollType::Normal) {
                escape_type = RollType::Advantage;
            }

            int def_exert = (current.is_player && current.player_ptr) ? current.player_ptr->get_skills().get_skill(SkillType::Exertion) : (current.creature_ptr ? current.creature_ptr->get_stats().strength : 0);
            int def_nimble = (current.is_player && current.player_ptr) ? current.player_ptr->get_skills().get_skill(SkillType::Nimble) : (current.creature_ptr ? current.creature_ptr->get_stats().speed : 0);
            SkillType def_skill = (def_exert >= def_nimble) ? SkillType::Exertion : SkillType::Nimble;

            RollResult escape_roll;
            if (current.is_player && current.player_ptr) escape_roll = current.player_ptr->roll_skill_check(dice, def_skill, escape_type);
            else if (current.creature_ptr) escape_roll = dice.roll_d20(escape_type, (def_skill == SkillType::Exertion ? current.creature_ptr->get_stats().strength : current.creature_ptr->get_stats().speed));

            RollType maintain_type = (grappler_tier >= 1) ? RollType::Advantage : RollType::Normal;
            RollResult maintain_roll;
            if (grappler->is_player && grappler->player_ptr) maintain_roll = grappler->player_ptr->roll_skill_check(dice, SkillType::Exertion, maintain_type);
            else if (grappler->creature_ptr) maintain_roll = dice.roll_d20(maintain_type, grappler->creature_ptr->get_stats().strength);

            last_action_log_ = current.name + " attempts to escape grapple by " + grappler->name + " (Roll: " + std::to_string(escape_roll.total) + " vs " + std::to_string(maintain_roll.total) + ")";

            if (escape_roll.total >= maintain_roll.total) {
                last_action_log_ += " - SUCCESS!";
                current.grappled_by_id = "";
                auto it = std::find(grappler->grappling_ids.begin(), grappler->grappling_ids.end(), current.id);
                if (it != grappler->grappling_ids.end()) grappler->grappling_ids.erase(it);

                if (current.is_player && current.player_ptr) {
                    current.player_ptr->get_status().remove_condition(ConditionType::Grappled);
                    current.player_ptr->get_status().remove_condition(ConditionType::Restrained);
                } else if (current.creature_ptr) {
                    current.creature_ptr->get_status().remove_condition(ConditionType::Grappled);
                    current.creature_ptr->get_status().remove_condition(ConditionType::Restrained);
                }

                // Iron Grip (T1) Secondary: Knock Prone on escape
                if (grappler_tier >= 1 && grappler->is_player && grappler->player_ptr->has_iron_grip_prone_available_) {
                    if (current.is_player && current.player_ptr) current.player_ptr->get_status().add_condition(ConditionType::Prone);
                    else if (current.creature_ptr) current.creature_ptr->get_status().add_condition(ConditionType::Prone);
                    grappler->player_ptr->has_iron_grip_prone_available_ = false;
                    last_action_log_ += " " + grappler->name + " immediately knocks " + current.name + " prone! (Iron Grip)";
                }
            } else {
                last_action_log_ += " - FAILED.";
            }
            return true;
        }
        case ActionType::CastSpell: {
            std::stringstream ss(param);
            std::string s_name, t_ids_str, focus, cx_str, cy_str;
            std::getline(ss, s_name, '|');
            std::getline(ss, t_ids_str, '|');
            std::getline(ss, focus, '|');
            std::getline(ss, cx_str, '|');
            std::getline(ss, cy_str, '|');

            const auto* spell = SpellRegistry::instance().find_spell(s_name);
            if (!spell) return false;

            // --- Teleport handling ---
            if (spell->is_teleport) {
                if (cx_str.empty() || cy_str.empty()) { last_action_log_ = "No destination specified!"; return false; }
                int dx = std::stoi(cx_str), dy = std::stoi(cy_str);

                bool is_self = (t_ids_str.empty() || t_ids_str == current.id);
                Combatant* teleport_target = is_self ? &current : find_combatant_by_id(t_ids_str);
                if (!teleport_target) { last_action_log_ = "Invalid teleport target!"; return false; }

                int dist_tiles = DungeonManager::instance().get_distance_to_point(teleport_target->id, dx, dy);
                int dist_feet = dist_tiles * 5;
                int bracket = std::max(1, (dist_feet + 9) / 10);
                int sp_cost = 1 << (bracket - 1);

                if (spell->base_sp_cost > 0 && sp_cost > spell->base_sp_cost) {
                    last_action_log_ = "Destination exceeds spell range! Need " + std::to_string(sp_cost) + " SP but spell budget is " + std::to_string(spell->base_sp_cost) + " SP (" + std::to_string(dist_feet) + "ft).";
                    return false;
                }
                if (current.get_current_sp() < sp_cost) {
                    last_action_log_ = "Not enough SP! Need " + std::to_string(sp_cost) + " SP to teleport " + std::to_string(dist_feet) + "ft.";
                    return false;
                }

                // Unwilling enemy creature: Divinity saving throw
                if (!is_self && !teleport_target->is_player && teleport_target->creature_ptr) {
                    int caster_div = (current.is_player && current.player_ptr) ? current.player_ptr->get_stats_const().get_stat(StatType::Divinity) : 10;
                    int spell_dc = (current.is_player && current.player_ptr)
                        ? current.player_ptr->get_spell_save_dc()
                        : 8 + (caster_div - 10) / 2;
                    RollResult save = dice.roll_d20(RollType::Normal, 0, 0);
                    if (save.total >= spell_dc) {
                        current.spend_sp(sp_cost);
                        last_action_log_ = teleport_target->name + " resisted the teleport! (Save: " + std::to_string(save.total) + " vs DC " + std::to_string(spell_dc) + ")";
                        return true;
                    }
                }

                if (DungeonManager::instance().move_entity(teleport_target->id, dx, dy)) {
                    current.spend_sp(sp_cost);
                    last_action_log_ = teleport_target->name + " teleported " + std::to_string(dist_feet) + "ft! (" + std::to_string(sp_cost) + " SP spent)";
                    return true;
                } else {
                    last_action_log_ = "Teleport failed — destination is blocked!";
                    return false;
                }
            }

            if (current.get_current_sp() < spell->base_sp_cost) {
                last_action_log_ = "Not enough SP to cast " + s_name + "!";
                return false;
            }

            std::vector<Combatant*> targets;

            if (spell->area_type != SpellAreaType::None && !cx_str.empty() && !cy_str.empty()) {
                // Area spell: gather all entities within radius of the given center point
                int cx = std::stoi(cx_str), cy = std::stoi(cy_str);
                if (dungeon_mode_ && spell->range != SpellRange::Self) {
                    int dist = DungeonManager::instance().get_distance_to_point(current.id, cx, cy);
                    if (dist > SpellRegistry::get_range_tiles(spell->range)) {
                        last_action_log_ = "Target area is out of range for " + spell->name + "!";
                        return false;
                    }
                }
                int radius = SpellRegistry::get_area_radius_tiles(spell->area_type);
                for (const auto& eid : DungeonManager::instance().get_entities_in_area(cx, cy, radius)) {
                    auto* t = find_combatant_by_id(eid);
                    if (t) targets.push_back(t);
                }
            } else if (!t_ids_str.empty()) {
                // Single or comma-separated multi-target
                std::stringstream tid_ss(t_ids_str);
                std::string tid;
                while (std::getline(tid_ss, tid, ',')) {
                    if (tid.empty()) continue;
                    auto* t = find_combatant_by_id(tid);
                    if (!t) continue;
                    if (dungeon_mode_ && spell->range != SpellRange::Self) {
                        int dist = DungeonManager::instance().get_distance(current.id, t->id);
                        if (dist > SpellRegistry::get_range_tiles(spell->range)) {
                            last_action_log_ = t->name + " is out of range for " + spell->name + "!";
                            continue;
                        }
                    }
                    targets.push_back(t);
                }
                // If explicit targets were requested but all were out of range, abort
                if (targets.empty()) {
                    return false;
                }
            }

            {
                int sp_to_spend = spell->base_sp_cost;
                // Kindlekin: Alchemical Affinity — reduce SP cost by 4 (once per activation)
                if (current.is_player && current.player_ptr && current.player_ptr->pending_alchemical_affinity_) {
                    sp_to_spend = std::max(0, sp_to_spend - 4);
                    current.player_ptr->pending_alchemical_affinity_ = false;
                    last_action_log_ += " [Alchemical Affinity: -4 SP]";
                }
                // ArcaneWellspring T5: Infinite Font — next spell costs 0 SP
                if (current.is_player && current.player_ptr && current.player_ptr->aw_infinite_font_armed_) {
                    current.player_ptr->aw_infinite_font_armed_ = false;
                    last_action_log_ += " [Infinite Font: 0 SP cost!]";
                    sp_to_spend = 0;
                }
                // ArcaneWellspring T1: Deep Reserves — next spell costs half SP
                else if (current.is_player && current.player_ptr && current.player_ptr->aw_deep_reserves_armed_) {
                    current.player_ptr->aw_deep_reserves_armed_ = false;
                    sp_to_spend = std::max(0, sp_to_spend / 2);
                    last_action_log_ += " [Deep Reserves: SP halved!]";
                }
                // Domain expertise: SP discount for domain spells
                if (current.is_player && current.player_ptr && spell) {
                    int domain_disc = current.player_ptr->get_domain_cast_discount(spell->domain);
                    if (domain_disc > 0) {
                        sp_to_spend = std::max(0, sp_to_spend - domain_disc);
                        last_action_log_ += " [Domain Expertise: -" + std::to_string(domain_disc) + " SP]";
                    }
                }
                // PhysicalDomain T1: Ember Manipulator — 1/SR reduce fire spell cost by 3 SP
                if (current.is_player && current.player_ptr && spell &&
                    spell->damage_type == DamageType::Fire &&
                    current.player_ptr->get_feat_tier(FeatID::PhysicalDomain) >= 1 &&
                    current.player_ptr->sr_phys_ember_available_) {
                    sp_to_spend = std::max(0, sp_to_spend - 3);
                    current.player_ptr->sr_phys_ember_available_ = false;
                    last_action_log_ += " [Ember Manipulator: -3 SP]";
                }
                // Scholar orb: -1 SP when orb is active (within 5ft assumed)
                if (current.is_player && current.player_ptr) {
                    bool orb_active =
                        (current.player_ptr->cs_chaos_orb_active_ && current.player_ptr->get_feat_tier(FeatID::ChaosScholar) >= 3) ||
                        (current.player_ptr->us_light_orb_active_ && current.player_ptr->get_feat_tier(FeatID::UnityScholar) >= 3) ||
                        (current.player_ptr->vs_shadow_orb_active_ && current.player_ptr->get_feat_tier(FeatID::VoidScholar) >= 3);
                    if (orb_active) {
                        sp_to_spend = std::max(0, sp_to_spend - 1);
                        last_action_log_ += " [Scholar Orb: -1 SP]";
                    }
                }
                if (current.is_player && current.player_ptr) {
                    // SacredFragmentation: next spell costs half SP
                    if (current.player_ptr->sacred_frag_pending_) {
                        sp_to_spend = std::max(0, (sp_to_spend + 1) / 2);
                        current.player_ptr->sacred_frag_pending_ = false;
                        last_action_log_ += " [Sacred Fragment: half SP cost!]";
                    }
                    current.player_ptr->aw_last_spell_cost_ = sp_to_spend;
                }
                current.spend_sp(sp_to_spend);
                // BiologicalDomain T2: after casting bio spell, next attack gets +SP_spent bonus
                if (current.is_player && current.player_ptr && spell &&
                    spell->domain == Domain::Biological &&
                    current.player_ptr->get_feat_tier(FeatID::BiologicalDomain) >= 2) {
                    current.player_ptr->bio_attack_bonus_pending_ += current.player_ptr->aw_last_spell_cost_;
                    if (current.player_ptr->bio_attack_bonus_pending_ > 0)
                        last_action_log_ += " [Verdant Channeler: +" + std::to_string(current.player_ptr->bio_attack_bonus_pending_) + " to next attack]";
                }
            }
            if (spell->duration_rounds != 0) {
                current.active_matrices.push_back({s_name, spell->duration_rounds, focus, true, false, {}});
            }

            // ── Summon effect: spawn a friendly creature at the target area ──────
            bool is_summon_spell = (spell->domain == Domain::Spiritual &&
                (spell->description.find("ummon") != std::string::npos || spell->name.find("ummon") != std::string::npos));
            // ── Undeath effect: raise a nearby corpse as a friendly undead ──────
            bool is_undeath_spell = (spell->domain == Domain::Biological &&
                (spell->description.find("ndeath") != std::string::npos || spell->name.find("ndeath") != std::string::npos));

            if (dungeon_mode_ && !cx_str.empty() && !cy_str.empty()) {
                int cxv = std::stoi(cx_str), cyv = std::stoi(cy_str);
                if (is_undeath_spell) {
                    if (DungeonManager::instance().raise_dead_at(cxv, cyv)) {
                        last_action_log_ = current.name + " channels Undeath — a corpse stirs and rises as an undead ally!";
                    } else {
                        last_action_log_ = current.name + " channels Undeath, but there are no bodies nearby to animate!";
                    }
                    return true;
                }
                if (is_summon_spell) {
                    int sum_level = current.is_player && current.player_ptr ? current.player_ptr->get_level() : 1;
                    // Choose summon name based on caster level
                    std::string sum_name;
                    if (sum_level >= 8) sum_name = "Greater Elemental";
                    else if (sum_level >= 5) sum_name = "Spirit Guardian";
                    else if (sum_level >= 3) sum_name = "Lesser Spirit";
                    else sum_name = "Spirit Wisp";
                    std::string sid = DungeonManager::instance().spawn_summon(sum_name, sum_level, true, cxv, cyv);
                    if (!sid.empty()) {
                        last_action_log_ = current.name + " summons " + sum_name + "!";
                    } else {
                        last_action_log_ = current.name + " attempts to summon, but there is no room!";
                    }
                    return true;
                }
            }

            if (targets.empty()) {
                execute_spell(current, s_name, nullptr, dice);
            } else {
                for (auto* t : targets) {
                    execute_spell(current, s_name, t, dice);
                }
            }
            // ArcaneWellspring T3: Spell Echo — store spell name for echo on next turn
            if (current.is_player && current.player_ptr && current.player_ptr->aw_spell_echo_armed_) {
                current.player_ptr->aw_spell_echo_spell_name_ = s_name;
                current.player_ptr->aw_spell_echo_armed_ = false;
                last_action_log_ += " [Spell Echo armed: " + s_name + " will echo next turn!]";
            }
            return true;
        }
        case ActionType::ActivateSustainedSpell: {
            // Param format: "spellName|target1,target2" or "spellName||cx|cy" for area spells
            std::stringstream pss(param);
            std::string s_name, t_ids_str, cx_str, cy_str;
            std::getline(pss, s_name, '|');
            std::getline(pss, t_ids_str, '|');
            std::getline(pss, cx_str, '|');
            std::getline(pss, cy_str, '|');

            auto it = std::find_if(current.active_matrices.begin(), current.active_matrices.end(),
                [&](const SpellMatrix& m) { return m.spell_name == s_name; });
            if (it == current.active_matrices.end()) return false;

            bool focus_ok = true;
            if (!it->bound_item_name.empty() && current.is_player && current.player_ptr) {
                focus_ok = (current.player_ptr->get_weapon() && current.player_ptr->get_weapon()->get_name() == it->bound_item_name) ||
                           (current.player_ptr->get_shield() && current.player_ptr->get_shield()->get_name() == it->bound_item_name);
            }
            if (!focus_ok) {
                last_action_log_ = "Spell suppressed: arcane focus (" + it->bound_item_name + ") not in use.";
                return false;
            }
            if (it->suppressed) return false;

            const auto* spell = SpellRegistry::instance().find_spell(s_name);
            std::vector<Combatant*> targets;

            if (spell && spell->area_type != SpellAreaType::None && !cx_str.empty() && !cy_str.empty()) {
                // Area activation: gather all entities within radius
                int cx = std::stoi(cx_str), cy = std::stoi(cy_str);
                if (dungeon_mode_ && spell->range != SpellRange::Self) {
                    int dist = DungeonManager::instance().get_distance_to_point(current.id, cx, cy);
                    if (dist > SpellRegistry::get_range_tiles(spell->range)) {
                        last_action_log_ = "Target area is out of range for " + spell->name + " activation!";
                        return false;
                    }
                }
                int radius = SpellRegistry::get_area_radius_tiles(spell->area_type);
                for (const auto& eid : DungeonManager::instance().get_entities_in_area(cx, cy, radius)) {
                    auto* t = find_combatant_by_id(eid);
                    if (t) targets.push_back(t);
                }
            } else if (!t_ids_str.empty()) {
                // Targeted activation: comma-separated IDs with range checks
                std::stringstream tid_ss(t_ids_str);
                std::string tid;
                while (std::getline(tid_ss, tid, ',')) {
                    if (tid.empty()) continue;
                    auto* t = find_combatant_by_id(tid);
                    if (!t) continue;
                    if (dungeon_mode_ && spell && spell->range != SpellRange::Self) {
                        int dist = DungeonManager::instance().get_distance(current.id, t->id);
                        if (dist > SpellRegistry::get_range_tiles(spell->range)) {
                            last_action_log_ = t->name + " is out of range for " + spell->name + " activation!";
                            continue;
                        }
                    }
                    targets.push_back(t);
                }
                if (targets.empty()) return false;
            }

            if (targets.empty()) {
                execute_spell(current, s_name, nullptr, dice, true);
            } else {
                for (auto* t : targets) {
                    execute_spell(current, s_name, t, dice, true);
                }
            }
            it->used_free_activation_this_turn = true;
            return true;
        }
        case ActionType::EndSustainedSpell: {
            auto it = current.active_matrices.end();
            try {
                int idx = std::stoi(param);
                if (idx >= 0 && idx < (int)current.active_matrices.size()) {
                    it = current.active_matrices.begin() + idx;
                }
            } catch (...) {
                it = std::find_if(current.active_matrices.begin(), current.active_matrices.end(),
                    [&](const SpellMatrix& m) { return m.spell_name == param; });
            }

            if (it != current.active_matrices.end()) {
                const auto* spell = SpellRegistry::instance().find_spell(it->spell_name);
                if (spell) {
                    for (const auto& entity_id : it->affected_entities) {
                        auto* affected = find_combatant_by_id(entity_id);
                        if (affected) {
                            for (auto cond : spell->conditions) {
                                if (affected->is_player && affected->player_ptr) affected->player_ptr->get_status().remove_condition(cond);
                                else if (affected->creature_ptr) affected->creature_ptr->get_status().remove_condition(cond);
                            }
                        }
                    }
                }
                std::string s_name = it->spell_name;
                // Reset Telekinesis sustained state on manual cancel
                if (current.is_player && current.player_ptr) {
                    if (s_name == "Telekinesis: Animate Weapon") {
                        current.player_ptr->tk_animate_weapon_active_ = false;
                        current.player_ptr->tk_animate_weapon_sp_committed_ = 0;
                    } else if (s_name == "Telekinesis: Animate Shield" || s_name == "Telekinesis: Animate Tower Shield") {
                        current.player_ptr->tk_animated_shield_ac_bonus_ = 0;
                    }
                }
                current.active_matrices.erase(it);
                last_action_log_ = current.name + " ends the spell " + s_name + ".";
                return true;
            }
            return false;
        }
        case ActionType::Dodge: {
            if (current.is_player && current.player_ptr) current.player_ptr->add_dodge_bonus();
            last_action_log_ = current.name + " takes a defensive stance.";
            return true;
        }
        case ActionType::Rest: {
            int recovery = dice.roll(4);
            int str = 0;
            std::string log;

            if (current.is_player && current.player_ptr) {
                Character* p = current.player_ptr;
                str = p->get_stats().strength;
                int tier = p->get_feat_tier(FeatID::RestAndRecovery);

                // Tier 1: +2 AP
                if (tier >= 1) recovery += 2;
                recovery += str;
                current.gain_ap(recovery);
                log = current.name + " rests and recovers " + std::to_string(recovery) + " AP.";

                // Check for Free Action use (Tier 1 Secondary)
                if (tier >= 1 && p->sr_rest_free_available_) {
                    if (get_action_cost(ActionType::Rest) == 0) {
                        p->sr_rest_free_available_ = false;
                        log += " (Free Action)";
                    }
                }

                // Tier 2 Secondary: Grant half recovery to ally within 5ft (1 tile)
                if (tier >= 2) {
                    int ally_recovery = recovery / 2;
                    for (auto& target : combatants_) {
                        if (target.id != current.id && target.is_player && target.get_current_hp() > 0) {
                            if (DungeonManager::instance().get_distance(current.id, target.id) <= 1) {
                                target.gain_ap(ally_recovery);
                                log += " " + target.name + " also regains " + std::to_string(ally_recovery) + " AP.";
                                break;
                            }
                        }
                    }
                }

                // Tier 3 Primary: 1d4+2 SP (1/LR)
                if (tier >= 3 && p->lr_tireless_spirit_available_) {
                    int sp_rec = dice.roll(4) + 2;
                    p->restore_sp(sp_rec);
                    p->lr_tireless_spirit_available_ = false;
                    log += " Regained " + std::to_string(sp_rec) + " SP (Tireless Spirit).";
                }

                // Tier 3 Secondary: remove one minor negative condition
                if (tier >= 3) {
                    if (p->get_status().has_condition(ConditionType::Confused)) {
                        p->get_status().remove_condition(ConditionType::Confused);
                        log += " [Confused removed]";
                    } else if (p->get_status().has_condition(ConditionType::Dazed)) {
                        p->get_status().remove_condition(ConditionType::Dazed);
                        log += " [Dazed removed]";
                    }
                }

                // Tier 4 Primary: Advantage on rolls until end of next turn (1/LR)
                if (tier >= 4 && p->lr_unyielding_vitality_available_) {
                    p->advantage_until_tick_ = 2; // Lasts current turn and next
                    p->lr_unyielding_vitality_available_ = false;
                    log += " Gained advantage on next rolls.";
                }

                // Tier 4 Secondary: Allies within 10ft regain 1d4+STR AP
                if (tier >= 4) {
                    int area_recovery = dice.roll(4) + str;
                    for (auto& target : combatants_) {
                        if (target.id != current.id && target.is_player && target.get_current_hp() > 0) {
                            if (DungeonManager::instance().get_distance(current.id, target.id) <= 2) {
                                target.gain_ap(area_recovery);
                                log += " " + target.name + " regains " + std::to_string(area_recovery) + " AP.";
                            }
                        }
                    }
                }
                // Hearthkin: Kindle Flame — any nearby Hearthkin with flame active grants +1d4 AP on rest
                for (auto& hearthkin : combatants_) {
                    if (hearthkin.id != current.id && hearthkin.is_player && hearthkin.player_ptr &&
                        hearthkin.player_ptr->get_lineage().name == "Hearthkin" &&
                        hearthkin.player_ptr->kindle_flame_active_) {
                        int flame_bonus = dice.roll(4);
                        current.gain_ap(flame_bonus);
                        log += " [Kindle Flame: +" + std::to_string(flame_bonus) + " AP from " + hearthkin.name + "'s flame!]";
                    }
                }
            } else if (current.creature_ptr) {
                recovery += current.creature_ptr->get_stats().strength;
                current.gain_ap(recovery);
                log = current.name + " rests and recovers " + std::to_string(recovery) + " AP.";
            }

            last_action_log_ = log;
            return true;
        }
        case ActionType::EfficientRecuperation: {
            if (current.is_player && current.player_ptr && current.player_ptr->sr_efficient_recuperation_available_) {
                Combatant* target = find_combatant_by_id(param);
                if (!target) target = &current;

                if (target->is_player && target->player_ptr) {
                    target->player_ptr->has_recuperation_advantage_ = true;
                    current.player_ptr->sr_efficient_recuperation_available_ = false;
                    last_action_log_ = current.name + " grants Efficient Recuperation to " + target->name + ".";
                    return true;
                }
            }
            return false;
        }
        case ActionType::Reaction_Defense: {
            if (current.is_player && current.player_ptr) {
                // param can be "DR" or "Weapon" or "Armor" or "Shield"
                if (param == "DR") {
                    int dr = dice.roll(4);
                    last_action_log_ = current.name + " uses Defense Reaction for " + std::to_string(dr) + " DR.";
                    current.player_ptr->pending_damage_reduction_ = dr;
                } else {
                    last_action_log_ = current.name + " uses Defense Reaction to absorb damage with " + param + ".";
                    current.player_ptr->pending_absorb_item_ = param;
                }
                return true;
            }
            return false;
        }
        case ActionType::UseItem: {
            size_t sep = param.find('|');
            if (sep != std::string::npos) {
                std::string i_name = param.substr(0, sep);
                std::string t_id = param.substr(sep + 1);
                auto* target = find_combatant_by_id(t_id);
                if (!target) target = &current;

                if (current.is_player && current.player_ptr) {
                    auto& inv = current.player_ptr->get_inventory();
                    auto& items = inv.get_items();
                    for (auto& item : items) {
                        if (item->get_name() == i_name && item->is_consumable()) {
                            auto* consumable = dynamic_cast<Consumable*>(item.get());
                            if (consumable) {
                                if (target->is_player && target->player_ptr) {
                                    last_action_log_ = current.name + " used " + i_name + " on " + target->name + ": " + consumable->use(target->player_ptr);
                                } else {
                                    last_action_log_ = current.name + " used " + i_name + " on " + target->name + ".";
                                }
                                inv.remove_item(i_name);
                                return true;
                            }
                        }
                    }
                }
            }
            return false;
        }
        case ActionType::Hide: {
            if (current.is_player && current.player_ptr) {
                rimvale::Dice dice_local;
                auto roll = current.player_ptr->roll_skill_check(dice_local, SkillType::Sneak);
                current.player_ptr->get_status().add_condition(ConditionType::Hidden);
                last_action_log_ = current.name + " hides (Sneak: " + std::to_string(roll.total) + ").";
                return true;
            } else if (current.creature_ptr) {
                current.creature_ptr->get_status().add_condition(ConditionType::Hidden);
                last_action_log_ = current.name + " attempts to hide.";
                return true;
            }
            return false;
        }
        case ActionType::Interact: {
            last_action_log_ = current.name + " interacts with the surroundings.";
            return true;
        }
        case ActionType::Reload: {
            last_action_log_ = current.name + " reloads their weapon.";
            return true;
        }
        case ActionType::LineageTrait: {
            auto* player = current.player_ptr;
            if (!player) return false;
            const std::string& lineage = player->get_lineage().name;

            // BoundingEscape — Bouncian, 1/SR, 0 AP reaction: gain Dodging this round
            if (param == "BoundingEscape") {
                if (!player->sr_bouncian_escape_available_) { last_action_log_ = current.name + ": Bounding Escape already used this rest."; return false; }
                player->get_status().add_condition(ConditionType::Dodging);
                player->sr_bouncian_escape_available_ = false;
                last_action_log_ = current.name + " uses Bounding Escape — leaps aside, gaining Dodge until next turn!";
                return true;
            }

            // HeatedScalesToggle — Goldscale, no per-rest limit: manually trigger heated scales for 1 round
            if (param == "HeatedScalesToggle") {
                player->get_status().add_condition(ConditionType::HeatedScales);
                last_action_log_ = current.name + "'s scales ignite! Heated Scales active until next turn.";
                return true;
            }

            // SunsFavor — Goldscale, 1/LR, 3 AP: fire resistance + radiant burst (Blinded 10ft)
            if (param == "SunsFavor") {
                if (!player->lr_goldscale_sun_favor_available_) { last_action_log_ = current.name + ": Sun's Favor already used this rest."; return false; }
                player->has_fire_resistance_ = true;
                player->lr_goldscale_sun_favor_available_ = false;
                // Apply Blinded to all enemies in range
                int blinded_count = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dc = 10 + player->get_stats().vitality;
                        auto save = dice.roll(20) + c.creature_ptr->get_stats().vitality;
                        if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Blinded); blinded_count++; }
                    }
                }
                last_action_log_ = current.name + " calls on Sun's Favor — fire resistance gained! Radiant burst: " + std::to_string(blinded_count) + " enemies blinded.";
                return true;
            }

            // ArmoredPlating — Ironhide, 1/LR, 2 AP: +2 AC for 10 rounds
            if (param == "ArmoredPlating") {
                if (!player->lr_ironhide_plating_available_) { last_action_log_ = current.name + ": Armored Plating already used this rest."; return false; }
                player->get_status().add_condition(ConditionType::ArmoredPlating);
                player->lr_ironhide_plating_available_ = false;
                last_action_log_ = current.name + " hardens their plating! +2 AC active (move actions cost +1 AP).";
                return true;
            }

            // MechanicalMindRecall — Ironhide, 1/SR, 2 AP: auto-succeed on Intellect recall check
            if (param == "MechanicalMindRecall") {
                if (!player->sr_ironhide_mind_available_) { last_action_log_ = current.name + ": Mechanical Mind recall already used this rest."; return false; }
                player->sr_ironhide_mind_available_ = false;
                last_action_log_ = current.name + " accesses perfect recall — automatically succeeds on the Intellect check!";
                return true;
            }

            // Regrowth — Verdant, 1/SR, 2 AP: heal level + VIT HP
            if (param == "Regrowth") {
                if (!player->sr_verdant_regrowth_available_) { last_action_log_ = current.name + ": Regrowth already used this rest."; return false; }
                int heal_amount = player->get_level() + player->get_stats().vitality;
                player->heal(heal_amount);
                player->sr_verdant_regrowth_available_ = false;
                last_action_log_ = current.name + " channels Regrowth, recovering " + std::to_string(heal_amount) + " HP!";
                return true;
            }

            // NaturesVoice — Verdant, 1/LR, 0 AP: commune with plants (narrative; no combat effect)
            if (param == "NaturesVoice") {
                if (!player->lr_verdant_natures_voice_available_) { last_action_log_ = current.name + ": Nature's Voice already used this rest."; return false; }
                player->lr_verdant_natures_voice_available_ = false;
                last_action_log_ = current.name + " communes with the surrounding plant life through Nature's Voice.";
                return true;
            }

            // IllusoryEcho — Vulpin, 1/LR, 2 AP: advantage on all checks for 10 rounds
            if (param == "IllusoryEcho") {
                if (!player->lr_vulpin_echo_available_) { last_action_log_ = current.name + ": Illusory Echo already used this rest."; return false; }
                player->advantage_until_tick_ = 10;
                player->lr_vulpin_echo_available_ = false;
                last_action_log_ = current.name + " creates an Illusory Echo — advantage on all checks for 10 rounds!";
                return true;
            }

            // TrickstersDodge — Vulpin, 1 SP reaction: impose disadvantage on one attack
            if (param == "TrickstersDodge") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Trickster's Dodge."; return false; }
                player->current_sp_--;
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " uses Trickster's Dodge — attackers have disadvantage until next turn!";
                return true;
            }

            // Photosynthesis — Bramblekin, 1 AP: produce a ration for an ally (costs 1 SP)
            if (param == "Photosynthesis") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Photosynthesis."; return false; }
                player->current_sp_--;
                last_action_log_ = current.name + " uses Photosynthesis to produce a ration for an ally. (1 SP spent)";
                return true;
            }

            // EnchantingPresence — Fae-Touched Human, 1/SR, 2 AP: +1d4 to Speechcraft for 10 rounds
            if (param == "EnchantingPresence") {
                if (!player->sr_fae_enchanting_available_) { last_action_log_ = current.name + ": Enchanting Presence already used this rest."; return false; }
                player->speechcraft_bonus_rounds_ = 10;
                player->sr_fae_enchanting_available_ = false;
                last_action_log_ = current.name + " shimmers with fey magic — +1d4 to Speechcraft for 10 rounds!";
                return true;
            }

            // FeyStep — Fae-Touched Human, 1 AP: refill movement budget (teleport-style movement)
            if (param == "FeyStep") {
                auto* cmb = get_current_combatant();
                if (cmb) {
                    int full_tiles = player->get_movement_speed() / 5;
                    cmb->movement_tiles_remaining = full_tiles;
                    last_action_log_ = current.name + " uses Fey Step — teleports up to " + std::to_string(full_tiles * 5) + "ft!";
                }
                return true;
            }

            // SporeCloud — Myconid, 1/LR, 2 AP: poison enemies in 10ft radius
            if (param == "SporeCloud") {
                if (!player->lr_myconid_spore_available_) { last_action_log_ = current.name + ": Spore Cloud already used this rest."; return false; }
                player->lr_myconid_spore_available_ = false;
                int dc = 10 + player->get_stats().vitality;
                int poisoned_count = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int save = dice.roll(20) + c.creature_ptr->get_stats().vitality;
                        if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Poisoned); poisoned_count++; }
                    }
                }
                last_action_log_ = current.name + " releases Spore Cloud (DC " + std::to_string(dc) + ")! " + std::to_string(poisoned_count) + " enemies poisoned.";
                return true;
            }

            // FungalFortitude — Myconid, 1/SR, 2 AP: heal 2d6 (4d6 if poisoned)
            if (param == "FungalFortitude") {
                if (!player->sr_myconid_fortitude_available_) { last_action_log_ = current.name + ": Fungal Fortitude already used this rest."; return false; }
                bool is_poisoned = player->get_status().has_condition(ConditionType::Poisoned);
                int heal_amount = (is_poisoned ? dice.roll(6) + dice.roll(6) + dice.roll(6) + dice.roll(6)
                                               : dice.roll(6) + dice.roll(6));
                player->heal(heal_amount);
                player->sr_myconid_fortitude_available_ = false;
                last_action_log_ = current.name + " channels Fungal Fortitude" + (is_poisoned ? " (boosted)" : "") + ", healing " + std::to_string(heal_amount) + " HP!";
                return true;
            }

            // Origami — Bookborn, 3 AP: enter 2D folded form for 2 turns (advantage on escape grapple, can't attack)
            if (param == "Origami") {
                player->bookborn_origami_active_ = true;
                player->bookborn_origami_rounds_ = 2;
                last_action_log_ = current.name + " folds into a 2D form — advantage on escape checks, cannot attack for 2 rounds!";
                return true;
            }

            // OrigamiMaintain — Bookborn, 1 AP: extend Origami by another round
            if (param == "OrigamiMaintain") {
                if (!player->bookborn_origami_active_) { last_action_log_ = current.name + ": Not currently in Origami form."; return false; }
                player->bookborn_origami_rounds_ = std::max(player->bookborn_origami_rounds_, 2);
                last_action_log_ = current.name + " maintains the folded Origami form for another round.";
                return true;
            }

            // MnemonicRecall — Archivist, 1/SR, free: auto-succeed on a knowledge/recall check
            if (param == "MnemonicRecall") {
                if (!player->sr_archivist_recall_available_) { last_action_log_ = current.name + ": Mnemonic Recall already used this rest."; return false; }
                player->sr_archivist_recall_available_ = false;
                last_action_log_ = current.name + " accesses perfect recall — automatically succeeds on the knowledge check!";
                return true;
            }

            // SentinelStand — Panoplian, 1 AP: gain Dodging + anchor (speed 0, unlimited OAs)
            if (param == "SentinelStand") {
                player->get_status().add_condition(ConditionType::Dodging);
                player->panoplian_sentinel_stand_active_ = true;
                last_action_log_ = current.name + " plants their feet in Sentinel's Stand — Dodging, speed 0, unlimited opportunity attacks!";
                return true;
            }

            // ToxicRoots — Blackroot, 1/LR, 2 AP: poison gas 10ft radius, DC 13 VIT save or Poisoned
            if (param == "ToxicRoots") {
                if (!player->lr_toxic_roots_available_) { last_action_log_ = current.name + ": Toxic Roots already used this rest."; return false; }
                player->lr_toxic_roots_available_ = false;
                int dc = 13;
                int hit_count = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int save = dice.roll(20) + c.creature_ptr->get_stats().vitality;
                        if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Poisoned); hit_count++; }
                    }
                }
                last_action_log_ = current.name + " emits a toxic cloud (DC " + std::to_string(dc) + ")! " + std::to_string(hit_count) + " enemies poisoned.";
                return true;
            }

            // WitherbornDecay — Blackroot, 1/LR, free: absorb decay after short rest; heal 1d6+VIT, gain poison resist + +1d4 poison attacks
            if (param == "WitherbornDecay") {
                if (!player->lr_witherborn_decay_available_) { last_action_log_ = current.name + ": Witherborn Decay already used this rest."; return false; }
                player->lr_witherborn_decay_available_ = false;
                int heal_amount = dice.roll(6) + player->get_stats().vitality;
                player->heal(heal_amount);
                player->has_poison_resistance_ = true;
                player->witherborn_decay_rounds_ = 10; // ~1 minute in rounds
                last_action_log_ = current.name + " absorbs ambient decay — healed " + std::to_string(heal_amount) + " HP, poison resistance and +1d4 poison on melee for 10 rounds!";
                return true;
            }

            // SilkenTrap — Bloodsilk Human, 1/SR, 2 AP: restrain nearest enemy within 15ft for 10 rounds
            if (param == "SilkenTrap") {
                if (!player->sr_silken_trap_available_) { last_action_log_ = current.name + ": Silken Trap already used this rest."; return false; }
                // Find nearest enemy within 3 tiles (15ft)
                Combatant* trap_target = nullptr;
                int min_dist = 999;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dist = dungeon_mode_ ? DungeonManager::instance().get_distance(current.id, c.id) : 1;
                        if (dist <= 3 && dist < min_dist) { min_dist = dist; trap_target = &c; }
                    }
                }
                if (!trap_target) { last_action_log_ = current.name + ": No enemy within 15ft for Silken Trap!"; return false; }
                player->sr_silken_trap_available_ = false;
                int dc = 10 + player->get_stats().speed;
                int save = dice.roll(20) + trap_target->creature_ptr->get_stats().speed;
                if (save < dc) {
                    trap_target->creature_ptr->get_status().add_condition(ConditionType::Restrained);
                    last_action_log_ = current.name + " conjures crimson webs — " + trap_target->name + " is Restrained! (DC " + std::to_string(dc) + ", rolled " + std::to_string(save) + ")";
                } else {
                    last_action_log_ = current.name + " launches Silken Trap — " + trap_target->name + " resists! (DC " + std::to_string(dc) + ", rolled " + std::to_string(save) + ")";
                }
                return true;
            }

            // DrainingFangs — Bloodsilk Human, 1 AP: deal 1d4 to a restrained creature nearby and heal 1 HP
            if (param == "DrainingFangs") {
                Combatant* drain_target = nullptr;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr &&
                        c.creature_ptr->get_status().has_condition(ConditionType::Restrained)) {
                        int dist = dungeon_mode_ ? DungeonManager::instance().get_distance(current.id, c.id) : 1;
                        if (dist <= 1) { drain_target = &c; break; }
                    }
                }
                if (!drain_target) { last_action_log_ = current.name + ": No restrained target within 5ft!"; return false; }
                int drain_dmg = dice.roll(4);
                drain_target->creature_ptr->take_damage(drain_dmg, dice);
                player->heal(1);
                last_action_log_ = current.name + " drains " + drain_target->name + " for " + std::to_string(drain_dmg) + " damage, regaining 1 HP!";
                return true;
            }

            // LurkerStep — Mirevenom, 1/SR, free: gain advantage on Sneak for 5 rounds (emerge hidden)
            if (param == "LurkerStep") {
                if (!player->sr_lurker_step_available_) { last_action_log_ = current.name + ": Lurker's Step already used this rest."; return false; }
                player->sr_lurker_step_available_ = false;
                player->advantage_until_tick_ = std::max(player->advantage_until_tick_, 5);
                last_action_log_ = current.name + " surfaces from the murk — Hidden and advantage on Sneak for 5 rounds!";
                return true;
            }

            // VenomousBite — Serpentine, 1 AP: natural bite dealing 1d4 poison to nearest melee enemy
            if (param == "VenomousBite") {
                Combatant* bite_target = nullptr;
                int min_dist = 999;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dist = dungeon_mode_ ? DungeonManager::instance().get_distance(current.id, c.id) : 1;
                        if (dist <= 1 && dist < min_dist) { min_dist = dist; bite_target = &c; }
                    }
                }
                if (!bite_target) { last_action_log_ = current.name + ": No enemy in melee range to bite!"; return false; }
                int bite_dmg = dice.roll(4);
                bite_target->creature_ptr->take_damage(bite_dmg, dice);
                last_action_log_ = current.name + " bites " + bite_target->name + " for " + std::to_string(bite_dmg) + " poison damage!";
                return true;
            }

            // ExtractVenom — Serpentine, 1/LR, 1 AP: weapon deals +1d4 poison and forces Poisoned save (DC 10+DIV) for 10 rounds
            if (param == "ExtractVenom") {
                if (!player->lr_serpentine_venom_weapon_available_) { last_action_log_ = current.name + ": Extract Venom already used this rest."; return false; }
                player->lr_serpentine_venom_weapon_available_ = false;
                player->serpentine_venom_weapon_rounds_ = 10;
                last_action_log_ = current.name + " coats their weapon in venom — +1d4 poison and Poisoned save on hits for 10 rounds!";
                return true;
            }

            // HypnoticGaze — Serpentine, 3 AP: INT save (DC 10+DIV) or Dazed until end of next turn for all nearby enemies
            if (param == "HypnoticGaze") {
                int dc = 10 + player->get_stats().divinity;
                int dazed_count = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dist = dungeon_mode_ ? DungeonManager::instance().get_distance(current.id, c.id) : 1;
                        if (dist <= 2) { // 10ft = 2 tiles
                            int save = dice.roll(20) + c.creature_ptr->get_stats().intellect;
                            if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Dazed); dazed_count++; }
                        }
                    }
                }
                last_action_log_ = current.name + " fixes enemies with a Hypnotic Gaze (DC " + std::to_string(dc) + ")! " + std::to_string(dazed_count) + " enemies Dazed.";
                return true;
            }

            // PackHowl — Canidar, 1/LR, Free Action: all allies within combat gain advantage on rolls for 10 rounds
            if (param == "PackHowl") {
                if (!player->lr_pack_howl_available_) { last_action_log_ = current.name + ": Pack Howl already used this rest."; return false; }
                player->lr_pack_howl_available_ = false;
                int howled = 0;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        ally.player_ptr->advantage_until_tick_ = 10;
                        howled++;
                    }
                }
                last_action_log_ = current.name + " lets out a rallying howl! " + std::to_string(howled) + " allies gain advantage for 10 rounds!";
                return true;
            }

            // NaturesGrace — Cervin, 1/LR, 1 AP: grant +1d4 bonus to DIV allies for 10 rounds
            if (param == "NaturesGrace") {
                if (!player->lr_natures_grace_available_) { last_action_log_ = current.name + ": Nature's Grace already used this rest."; return false; }
                player->lr_natures_grace_available_ = false;
                int max_targets = std::max(1, player->get_stats().divinity);
                int granted = 0;
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr && granted < max_targets) {
                        ally.player_ptr->advantage_until_tick_ = 10;
                        granted++;
                    }
                }
                last_action_log_ = current.name + " channels Nature's Grace — " + std::to_string(granted) + " allies gain advantage for 10 rounds!";
                return true;
            }

            // AdaptiveHide — Tetrasimian, 1 AP: camouflage for advantage on Sneak while motionless
            if (param == "AdaptiveHide") {
                player->tetrasimian_sneak_advantage_ = true;
                last_action_log_ = current.name + " blends into the surroundings — advantage on Sneak checks!";
                return true;
            }

            // VerdantCurse — Thornwrought Human, 1/LR, 0 AP: shed affliction, remove all conditions
            if (param == "VerdantCurse") {
                if (!player->lr_verdant_curse_available_) { last_action_log_ = current.name + ": Verdant Curse already used this rest."; return false; }
                player->lr_verdant_curse_available_ = false;
                auto& status = player->get_status();
                static const std::vector<ConditionType> removable = {
                    ConditionType::Poisoned, ConditionType::Blinded, ConditionType::Confused,
                    ConditionType::Dazed, ConditionType::Slowed, ConditionType::Stunned,
                    ConditionType::Fever, ConditionType::Fear, ConditionType::Charm
                };
                for (auto cond : removable) status.remove_condition(cond);
                last_action_log_ = current.name + " sheds the affliction through Verdant Curse — all conditions cleared!";
                return true;
            }

            // KindleFlame — Hearthkin, 1/LR, 2 AP: kindle a flame; allies resting nearby gain +1d4 AP
            if (param == "KindleFlame") {
                if (!player->lr_kindle_flame_available_) { last_action_log_ = current.name + ": Kindle Flame already used this rest."; return false; }
                player->kindle_flame_active_ = true;
                player->lr_kindle_flame_available_ = false;
                last_action_log_ = current.name + " kindles a warm flame (20ft radius). Allies who rest nearby gain +1d4 AP!";
                return true;
            }

            // AlchemicalAffinity — Kindlekin, 1/LR, 0 AP: next Chemical spell costs 4 fewer SP
            if (param == "AlchemicalAffinity") {
                if (!player->lr_alchemical_affinity_available_) { last_action_log_ = current.name + ": Alchemical Affinity already used this rest."; return false; }
                player->pending_alchemical_affinity_ = true;
                player->lr_alchemical_affinity_available_ = false;
                last_action_log_ = current.name + " prepares an alchemical batch — next spell costs 4 fewer SP!";
                return true;
            }

            // ResilientSpirit — Regal Human, 2/SR, 0 AP: reroll a failed save (grants advantage on next stat check)
            if (param == "ResilientSpirit") {
                if (player->sr_resilient_spirit_uses_ <= 0) { last_action_log_ = current.name + ": Resilient Spirit uses exhausted this short rest."; return false; }
                player->has_recuperation_advantage_ = true;
                player->sr_resilient_spirit_uses_--;
                last_action_log_ = current.name + " invokes Resilient Spirit — advantage on the next save! (" + std::to_string(player->sr_resilient_spirit_uses_) + " uses remaining)";
                return true;
            }

            // VersatileGrant — Regal Human, DIV/LR, 1 AP: grant +1d4 to allies' next skill check
            if (param == "VersatileGrant") {
                if (player->lr_versatile_grant_remaining_ <= 0) { last_action_log_ = current.name + ": Versatile Grant uses exhausted."; return false; }
                player->lr_versatile_grant_remaining_--;
                int granted = 0;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        ally.player_ptr->has_recuperation_advantage_ = true;
                        granted++;
                    }
                }
                last_action_log_ = current.name + " shares Versatile inspiration — " + std::to_string(granted) + " allies gain advantage on their next check! (" + std::to_string(player->lr_versatile_grant_remaining_) + " uses remaining)";
                return true;
            }

            // QuillLaunch — Quillari, 1/LR, 2 AP: 2d6 to all enemies in a 30ft line
            if (param == "QuillLaunch") {
                if (!player->lr_quill_launch_available_) { last_action_log_ = current.name + ": Quill Launch already used this rest."; return false; }
                player->lr_quill_launch_available_ = false;
                int hit_count = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dmg = dice.roll(6) + dice.roll(6);
                        c.creature_ptr->take_damage(dmg, dice);
                        last_action_log_ += "\n  " + c.name + " takes " + std::to_string(dmg) + " piercing (Quill Launch).";
                        hit_count++;
                    }
                }
                last_action_log_ = current.name + " launches a volley of quills (30ft line)! " + std::to_string(hit_count) + " enemies hit." + last_action_log_;
                return true;
            }

            // QuickReflexes — Quillari, 1/SR, 0 AP: take a free action at the start of combat (grants +1 AP)
            if (param == "QuickReflexes") {
                if (!player->sr_quick_reflexes_available_) { last_action_log_ = current.name + ": Quick Reflexes already used this rest."; return false; }
                player->sr_quick_reflexes_available_ = false;
                current.gain_ap(1);
                last_action_log_ = current.name + " reacts with lightning speed — +1 AP (Quick Reflexes)!";
                return true;
            }

            // ===== METROPOLITAN LINEAGES =====

            // ArcaneSurge — Arcanite Human, 1/LR, 0 AP: +2 spell attack/DC for 1 round
            if (param == "ArcaneSurge") {
                if (!player->lr_arcane_surge_available_) { last_action_log_ = current.name + ": Arcane Surge already used this rest."; return false; }
                player->lr_arcane_surge_available_ = false;
                player->arcane_surge_rounds_ = 1;
                last_action_log_ = current.name + " channels raw arcane power — +2 spell attack and DC for 1 round (Arcane Surge)!";
                return true;
            }

            // ScrapInstinct — Groblodyte, 1/SR, 0 AP: Flashbang blinding gadget
            if (param == "ScrapInstinct") {
                if (!player->sr_groblodyte_scrap_available_) { last_action_log_ = current.name + ": Scrap Instinct already used this rest."; return false; }
                player->sr_groblodyte_scrap_available_ = false;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Blinded);
                        last_action_log_ = current.name + " hurls a Flashbang! " + c.name + " is Blinded!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " cobbles a Scrap gadget — no valid targets.";
                return true;
            }

            // SteamJet — Kettlekyn, 1/LR, 2 AP: 2d6+level fire damage to all enemies
            if (param == "SteamJet") {
                if (!player->lr_steam_jet_available_) { last_action_log_ = current.name + ": Steam Jet already used this rest."; return false; }
                player->lr_steam_jet_available_ = false;
                int hit_count = 0;
                std::string hit_log;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dmg = dice.roll(6) + dice.roll(6) + player->get_level();
                        c.creature_ptr->take_damage(dmg, dice);
                        hit_log += "\n  " + c.name + " takes " + std::to_string(dmg) + " fire.";
                        hit_count++;
                    }
                }
                last_action_log_ = current.name + " vents scalding Steam Jet! " + std::to_string(hit_count) + " enemies hit." + hit_log;
                return true;
            }

            // TetherStep — Marionox, 1/LR, 3 AP: teleport 30ft (refill movement)
            if (param == "TetherStep") {
                if (!player->lr_tether_step_available_) { last_action_log_ = current.name + ": Tether Step already used this rest."; return false; }
                player->lr_tether_step_available_ = false;
                current.movement_tiles_remaining = player->get_movement_speed() / 5;
                last_action_log_ = current.name + " snaps the ethereal tether — teleports up to 30ft (movement refilled)!";
                return true;
            }

            // ResonantVoice — Voxshell, INT/SR, 0 AP: Daze nearest enemy
            if (param == "ResonantVoice") {
                if (player->sr_resonant_voice_uses_ <= 0) { last_action_log_ = current.name + ": Resonant Voice uses exhausted this rest."; return false; }
                player->sr_resonant_voice_uses_--;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                        last_action_log_ = current.name + " emits a dissonant Resonant Voice — " + c.name + " is Dazed! (" + std::to_string(player->sr_resonant_voice_uses_) + " uses left)";
                        return true;
                    }
                }
                last_action_log_ = current.name + " resonates — no valid targets.";
                return true;
            }

            // MarketWhisperer — Gilded Human, 1/LR, 0 AP: advantage on next check
            if (param == "MarketWhisperer") {
                if (!player->lr_market_whisperer_available_) { last_action_log_ = current.name + ": Market Whisperer already used this rest."; return false; }
                player->lr_market_whisperer_available_ = false;
                player->advantage_until_tick_ = 3;
                last_action_log_ = current.name + " reads the room — advantage on next check (Market Whisperer)!";
                return true;
            }

            // ===== UPPER FORTY LINEAGES =====

            // ArcaneTinker — Gremlidian, 1/LR, 0 AP: Arc Spark gadget (1d6+INT lightning)
            if (param == "ArcaneTinker") {
                if (!player->lr_arcane_tinker_available_) { last_action_log_ = current.name + ": Arcane Tinker already used this rest."; return false; }
                player->lr_arcane_tinker_available_ = false;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dmg = dice.roll(6) + player->get_stats().intellect;
                        c.creature_ptr->take_damage(dmg, dice);
                        last_action_log_ = current.name + " fires an Arc Spark at " + c.name + " for " + std::to_string(dmg) + " lightning!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " tinkers an arcane gadget — no valid targets.";
                return true;
            }

            // GremlinsLuck — Gremlidian, 2/SR, 0 AP: advantage on next roll
            if (param == "GremlinsLuck") {
                if (player->sr_gremlins_luck_uses_ <= 0) { last_action_log_ = current.name + ": Gremlin's Luck uses exhausted this rest."; return false; }
                player->sr_gremlins_luck_uses_--;
                player->advantage_until_tick_ = 3;
                last_action_log_ = current.name + " burns some luck — advantage on next roll! (" + std::to_string(player->sr_gremlins_luck_uses_) + " uses left)";
                return true;
            }

            // HexMark — Hexkin, 1/LR, 2 AP: nearest enemy Dazed for 2 rounds (saves at disadvantage vs spells)
            if (param == "HexMark") {
                if (!player->lr_hex_mark_available_) { last_action_log_ = current.name + ": Hex Mark already used this rest."; return false; }
                player->lr_hex_mark_available_ = false;
                player->hex_mark_rounds_ = 2;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                        last_action_log_ = current.name + " inscribes a Hex Mark on " + c.name + " — disadvantage on saves vs spells for 2 rounds!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " raises Hex Mark — no valid targets.";
                return true;
            }

            // Witchblood — Hexkin, 1/SR, 0 AP: +2 spell DC for 1 round
            if (param == "Witchblood") {
                if (!player->sr_witchblood_available_) { last_action_log_ = current.name + ": Witchblood already used this rest."; return false; }
                player->sr_witchblood_available_ = false;
                player->witchblood_active_ = true;
                last_action_log_ = current.name + " draws on witch's blood — +2 spell save DC for 1 round!";
                return true;
            }

            // CommandingVoice — Voxilite, 1/LR, 2 AP: Charm nearest enemy (save vs DIV+Speechcraft)
            if (param == "CommandingVoice") {
                if (!player->lr_commanding_voice_available_) { last_action_log_ = current.name + ": Commanding Voice already used this rest."; return false; }
                player->lr_commanding_voice_available_ = false;
                int dc = 10 + player->get_stats().divinity + player->get_skills().get_skill(SkillType::Speechcraft) + player->get_spell_save_dc_bonus();
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int save_roll = dice.roll(20) + c.creature_ptr->get_stats().divinity;
                        if (save_roll < dc) {
                            c.creature_ptr->get_status().add_condition(ConditionType::Charm);
                            last_action_log_ = current.name + " issues Commanding Voice at " + c.name + " (DC " + std::to_string(dc) + ", save: " + std::to_string(save_roll) + ") — Charmed!";
                        } else {
                            last_action_log_ = current.name + " issues Commanding Voice at " + c.name + " — resisted! (DC " + std::to_string(dc) + ", save: " + std::to_string(save_roll) + ")";
                        }
                        return true;
                    }
                }
                last_action_log_ = current.name + " commands — no valid targets.";
                return true;
            }

            // ===== LOWER FORTY LINEAGES =====

            // OverdriveCore — Ferrusk, 1/SR, 0 AP: gain 2d4+VIT bonus AP
            if (param == "OverdriveCore") {
                if (!player->sr_overdrive_core_available_) { last_action_log_ = current.name + ": Overdrive Core already used this rest."; return false; }
                player->sr_overdrive_core_available_ = false;
                int bonus_ap = dice.roll(4) + dice.roll(4) + player->get_stats().vitality;
                current.gain_ap(bonus_ap);
                last_action_log_ = current.name + " kicks into Overdrive! +" + std::to_string(bonus_ap) + " AP!";
                return true;
            }

            // GremlinTinker — Gremlin, 1/LR, 0 AP: Grease gadget (Slow nearest enemy)
            if (param == "GremlinTinker") {
                if (!player->lr_gremlin_tinker_available_) { last_action_log_ = current.name + ": Tinker already used this rest."; return false; }
                player->lr_gremlin_tinker_available_ = false;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Slowed);
                        last_action_log_ = current.name + " tosses a Grease gadget — " + c.name + " is Slowed!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " tinkers a gadget.";
                return true;
            }

            // GremlinSabotage — Gremlin, 1/SR, 0 AP: narrative sabotage action
            if (param == "GremlinSabotage") {
                if (!player->sr_gremlin_sabotage_available_) { last_action_log_ = current.name + ": Sabotage already used this rest."; return false; }
                player->sr_gremlin_sabotage_available_ = false;
                last_action_log_ = current.name + " sabotages a mechanism — enemy formation disrupted!";
                return true;
            }

            // ReflectHex — Hexshell, 1/LR, 0 AP: prime reflection of next incoming spell condition
            if (param == "ReflectHex") {
                if (!player->lr_reflect_hex_available_) { last_action_log_ = current.name + ": Reflect Hex already used this rest."; return false; }
                player->lr_reflect_hex_available_ = false;
                player->reflect_hex_primed_ = true;
                last_action_log_ = current.name + " primes Reflect Hex — the next spell condition aimed at them is reflected back!";
                return true;
            }

            // ScrapSense — Scavenger Human, 1/SR, 0 AP: advantage on next Intellect/Perception check
            if (param == "ScrapSense") {
                if (!player->sr_scrap_sense_available_) { last_action_log_ = current.name + ": Scrap Sense already used this rest."; return false; }
                player->sr_scrap_sense_available_ = false;
                player->advantage_until_tick_ = 10;
                last_action_log_ = current.name + " scans the environment — advantage on next Perception/Intellect check (Scrap Sense)!";
                return true;
            }

            // IronStomachPoison — Ironjaw, 1/SR, 2 AP: acid-poison spit attack (1d8+VIT + Poisoned save)
            if (param == "IronStomachPoison") {
                if (!player->sr_iron_stomach_available_) { last_action_log_ = current.name + ": Iron Stomach already used this rest."; return false; }
                player->sr_iron_stomach_available_ = false;
                int dc = 10 + player->get_stats().vitality + player->get_spell_save_dc_bonus();
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int dmg = dice.roll(8) + player->get_stats().vitality;
                        c.creature_ptr->take_damage(dmg, dice);
                        int save_roll = dice.roll(20) + c.creature_ptr->get_stats().vitality;
                        if (save_roll < dc) c.creature_ptr->get_status().add_condition(ConditionType::Poisoned);
                        last_action_log_ = current.name + " spits iron-acid at " + c.name + " for " + std::to_string(dmg) + " poison" + (save_roll < dc ? " [Poisoned!]" : "") + "!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " uses Iron Stomach — no valid targets.";
                return true;
            }

            // ===== SHADOWS BENEATH LINEAGES =====

            // ShadowGlide — Corvian, 3 AP: +20ft movement + Dodging until next turn
            if (param == "ShadowGlide") {
                current.movement_tiles_remaining += 4; // +20ft = +4 tiles
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " shadow-glides — +20ft movement, flight, Dodging in dim light!";
                return true;
            }

            // Shadowgrasp — Duskling, 3 AP: Restrain a creature within 10ft (Speed save DC 10+INT)
            if (param == "Shadowgrasp") {
                int dc = 10 + player->get_stats().intellect;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int save_roll = dice.roll(20) + c.creature_ptr->get_stats().speed;
                        if (save_roll < dc) {
                            c.creature_ptr->get_status().add_condition(ConditionType::Restrained);
                            last_action_log_ = current.name + " grasps " + c.name + " with shadow tendrils — Restrained! (DC " + std::to_string(dc) + ", save: " + std::to_string(save_roll) + ")";
                        } else {
                            last_action_log_ = current.name + " Shadowgrasp resisted by " + c.name + "! (DC " + std::to_string(dc) + ", save: " + std::to_string(save_roll) + ")";
                        }
                        return true;
                    }
                }
                last_action_log_ = current.name + " Shadowgrasp — no valid targets.";
                return true;
            }

            // QuackAlarm — Duckslings, 1/LR, 0 AP: all allies gain advantage on next roll
            if (param == "QuackAlarm") {
                if (!player->lr_quack_alarm_available_) { last_action_log_ = current.name + ": Quack Alarm already used this rest."; return false; }
                player->lr_quack_alarm_available_ = false;
                int count = 0;
                for (auto& c : combatants_) {
                    if (c.is_player && c.player_ptr && c.player_ptr->get_current_hp() > 0) {
                        c.player_ptr->advantage_until_tick_ = 3;
                        count++;
                    }
                }
                last_action_log_ = current.name + " lets out a startling QUACK! " + std::to_string(count) + " allies gain advantage on their next roll!";
                return true;
            }

            // SableNightVision — Sable, 1/LR, 0 AP: create darkness cube (Blind nearest enemy)
            if (param == "SableNightVision") {
                if (!player->lr_sable_night_vision_available_) { last_action_log_ = current.name + ": Night Vision already used this rest."; return false; }
                player->lr_sable_night_vision_available_ = false;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Blinded);
                        last_action_log_ = current.name + " conjures a cube of magical darkness — " + c.name + " is Blinded!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " activates Night Vision — sight through magical darkness!";
                return true;
            }

            // Veilstep — Twilightkin, 1/SR, 0 AP: swap with ally in shadow (refill movement)
            if (param == "Veilstep") {
                if (!player->sr_veilstep_available_) { last_action_log_ = current.name + ": Veilstep already used this rest."; return false; }
                player->sr_veilstep_available_ = false;
                current.movement_tiles_remaining = player->get_movement_speed() / 5;
                last_action_log_ = current.name + " steps through shadow, swapping with an ally — movement refilled (Veilstep)!";
                return true;
            }

            // DuskbornGrace — Twilightkin, 1/SR, 0 AP: advantage on Sneak for 1 minute
            if (param == "DuskbornGrace") {
                if (!player->sr_duskborn_grace_available_) { last_action_log_ = current.name + ": Duskborn Grace already used this rest."; return false; }
                player->sr_duskborn_grace_available_ = false;
                player->advantage_until_tick_ = 10;
                last_action_log_ = current.name + " moves with Duskborn Grace — advantage on Sneak checks for 1 minute!";
                return true;
            }

            // ===== CORRUPTED MARSHES LINEAGES =====

            // MossyShroud — Bogtender, 1/LR, 0 AP: Sneak advantage + cold resistance for 1 hour
            if (param == "MossyShroud") {
                if (!player->lr_mossy_shroud_available_) { last_action_log_ = current.name + ": Mossy Shroud already used this rest."; return false; }
                player->lr_mossy_shroud_available_ = false;
                player->advantage_until_tick_ = 10;
                player->has_cold_resistance_ = true;
                last_action_log_ = current.name + " wraps in thick living moss — Sneak advantage and cold resistance for 1 hour!";
                return true;
            }

            // MireBurst — Mireborn Human, 1/SR, 0 AP: release foul poison burst on creatures within 5ft (DC 10+VIT)
            if (param == "MireBurst") {
                if (!player->sr_mire_burst_available_) { last_action_log_ = current.name + ": Mire Burst already used this rest."; return false; }
                player->sr_mire_burst_available_ = false;
                int dc = 10 + player->get_stats().vitality;
                int hit_count = 0;
                std::string hit_log;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int save_roll = dice.roll(20) + c.creature_ptr->get_stats().vitality;
                        if (save_roll < dc) {
                            int dmg = dice.roll(4);
                            c.creature_ptr->take_damage(dmg, dice);
                            hit_log += "\n  " + c.name + " takes " + std::to_string(dmg) + " poison.";
                            hit_count++;
                        }
                    }
                }
                last_action_log_ = current.name + " releases a foul burst (DC " + std::to_string(dc) + ")! " + std::to_string(hit_count) + " creatures hit." + hit_log;
                return true;
            }

            // SoothingAura — Myrrhkin, 1/LR, 0 AP: allies gain advantage vs fear/charm, Fear removed
            if (param == "SoothingAura") {
                if (!player->lr_soothing_aura_available_) { last_action_log_ = current.name + ": Soothing Aura already used this rest."; return false; }
                player->lr_soothing_aura_available_ = false;
                int count = 0;
                for (auto& c : combatants_) {
                    if (c.is_player && c.player_ptr && c.player_ptr->get_current_hp() > 0) {
                        c.player_ptr->advantage_until_tick_ = 3;
                        c.player_ptr->get_status().remove_condition(ConditionType::Fear);
                        c.player_ptr->get_status().remove_condition(ConditionType::Fear);
                        count++;
                    }
                }
                last_action_log_ = current.name + " emits a calming scent — " + std::to_string(count) + " allies gain advantage, Fear cleared!";
                return true;
            }

            // Dreamscent — Myrrhkin, 1/LR, 0 AP (1 SP per target): INT save DC 10+DIV or Unconscious
            if (param == "Dreamscent") {
                if (!player->lr_dreamscent_available_) { last_action_log_ = current.name + ": Dreamscent already used this rest."; return false; }
                if (player->current_sp_ <= 0) { last_action_log_ = current.name + ": Not enough SP for Dreamscent."; return false; }
                player->lr_dreamscent_available_ = false;
                int dc = 10 + player->get_stats().divinity + player->get_spell_save_dc_bonus();
                int hit_count = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr && player->current_sp_ > 0) {
                        int save_roll = dice.roll(20) + c.creature_ptr->get_stats().intellect;
                        if (save_roll < dc) {
                            c.creature_ptr->get_status().add_condition(ConditionType::Unconscious);
                            current.spend_sp(1);
                            hit_count++;
                        }
                    }
                }
                last_action_log_ = current.name + " releases dream-laced Dreamscent (DC " + std::to_string(dc) + ")! " + std::to_string(hit_count) + " creatures fall asleep.";
                return true;
            }

            // ===== CRYPT AT THE END OF THE VALLEY LINEAGES =====

            // BloodlettingBlow — Blood Spawn, 3 AP: melee strike deals extra 1d4 + heal for total damage
            if (param == "BloodlettingBlow") {
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        RollResult atk = player->roll_attack(dice, player->get_weapon());
                        int c_ac = 10 + c.creature_ptr->get_stats().speed;
                        if (atk.total >= c_ac) {
                            int base_dmg = player->get_weapon()
                                ? dice.roll_string(player->get_weapon()->get_damage_dice()) + player->get_stats().strength
                                : dice.roll(4) + player->get_stats().strength;
                            int extra = dice.roll(4);
                            int total_dmg = base_dmg + extra;
                            c.creature_ptr->take_damage(total_dmg, dice);
                            player->heal(total_dmg);
                            last_action_log_ = current.name + " strikes with Bloodletting Blow for " + std::to_string(total_dmg) + " and heals for the same!";
                        } else {
                            last_action_log_ = current.name + " Bloodletting Blow — MISS.";
                        }
                        return true;
                    }
                }
                last_action_log_ = current.name + " Bloodletting Blow — no valid targets.";
                return true;
            }

            // Boneclatter — Cryptkin Human, 3 AP: chilling rattle, Frightened to all in 15ft (DIV save)
            if (param == "Boneclatter") {
                int dc = 10 + player->get_stats().divinity;
                int count = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int save_roll = dice.roll(20) + c.creature_ptr->get_stats().divinity;
                        if (save_roll < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Fear); count++; }
                    }
                }
                last_action_log_ = current.name + " releases a Boneclatter rattle — " + std::to_string(count) + " enemies Frightened (DC " + std::to_string(dc) + ")!";
                return true;
            }

            // DiseasebornCurse — Cryptkin Human, 1/LR, 0 AP: curse nearest enemy (Poisoned + Dazed, free)
            if (param == "DiseasebornCurse") {
                if (!player->lr_diseaseborn_curse_available_) { last_action_log_ = current.name + ": Diseaseborn Curse already used this rest."; return false; }
                player->lr_diseaseborn_curse_available_ = false;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Poisoned);
                        c.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                        last_action_log_ = current.name + " channels bone-rot into " + c.name + " — Poisoned and Dazed (Diseaseborn Curse, no SP cost)!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " raises a bone curse — no valid targets.";
                return true;
            }

            // UmbralDodge — Gloomling, 3 AP: turn Dodging in darkness for 1 round
            if (param == "UmbralDodge") {
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " melts into shadow — Dodging for 1 round (Umbral Dodge)!";
                return true;
            }

            // GnawingGrin — Skulkin, 1/LR, 0 AP: curse nearest enemy (Frightened + Dazed, can't heal)
            if (param == "GnawingGrin") {
                if (!player->lr_gnawing_grin_available_) { last_action_log_ = current.name + ": Gnawing Grin already used this rest."; return false; }
                player->lr_gnawing_grin_available_ = false;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Fear);
                        c.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                        last_action_log_ = current.name + " flashes a gnawing grin at " + c.name + " — Frightened and cursed (cannot heal for 1 minute)!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " gnashes skeletal teeth — no valid targets.";
                return true;
            }

            // ===== SPINDLE YORK'S SCHISM LINEAGES =====

            // StonesEndurance — Gravari, VIT/SR, 0 AP: reduce next hit by 1d12+VIT
            if (param == "StonesEndurance") {
                if (player->sr_stones_endurance_uses_ <= 0) { last_action_log_ = current.name + ": Stone's Endurance uses exhausted this rest."; return false; }
                player->sr_stones_endurance_uses_--;
                int reduction = dice.roll(12) + player->get_stats().vitality;
                player->pending_damage_reduction_ += reduction;
                last_action_log_ = current.name + " hardens like stone — next hit reduced by " + std::to_string(reduction) + "! (" + std::to_string(player->sr_stones_endurance_uses_) + " uses left)";
                return true;
            }

            // CrystalResilience — Shardkin, 0 AP toggle (costs -3 max AP while active): lightly obscured + Sneak advantage
            if (param == "CrystalResilience") {
                player->shardkin_crystal_resilience_active_ = !player->shardkin_crystal_resilience_active_;
                if (player->shardkin_crystal_resilience_active_) {
                    player->advantage_until_tick_ = 10;
                    last_action_log_ = current.name + " bends light through crystal shards — lightly obscured, Sneak advantage active (-3 max AP)!";
                } else {
                    last_action_log_ = current.name + " releases the crystal refraction — Crystal Resilience deactivated, max AP restored.";
                }
                return true;
            }

            // HarmonicLink — Shardkin, 1/LR, 0 AP: mental link with up to 3 allies
            if (param == "HarmonicLink") {
                if (!player->lr_harmonic_link_available_) { last_action_log_ = current.name + ": Harmonic Link already used this rest."; return false; }
                player->lr_harmonic_link_available_ = false;
                int count = 0;
                for (auto& c : combatants_) {
                    if (c.is_player && c.player_ptr && c.player_ptr->get_current_hp() > 0 && count < 3) {
                        c.player_ptr->advantage_until_tick_ = 10;
                        count++;
                    }
                }
                last_action_log_ = current.name + " forms a Harmonic Link with " + std::to_string(count) + " allies — shared senses for 1 hour!";
                return true;
            }

            // ===== PEAKS OF ISOLATION LINEAGES =====

            // WinterBreath — Boreal Human, 3 AP: 2d4 cold in cone (VIT DC 13, half on save)
            if (param == "WinterBreath") {
                int total_dmg = dice.roll(4) + dice.roll(4);
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Vitality);
                        int dmg = (save.total >= 13) ? total_dmg / 2 : total_dmg;
                        t.player_ptr->take_damage(dmg, dice);
                    } else if (t.creature_ptr) {
                        int save_roll = dice.roll(20);
                        int dmg = (save_roll >= 13) ? total_dmg / 2 : total_dmg;
                        t.creature_ptr->take_damage(dmg, dice);
                    }
                    affected++;
                }
                last_action_log_ = current.name + " exhales Winter Breath — " + std::to_string(total_dmg) + " cold (VIT DC 13, half on save) to " + std::to_string(affected) + " target(s)!";
                return true;
            }

            // FrostBurst — Frostborn, 1/SR, 2 AP reaction: 1d4 cold + Slowed (Speed DC 10+VIT)
            if (param == "FrostBurst") {
                if (!player->sr_frost_burst_available_) { last_action_log_ = current.name + ": Frost Burst already used this rest."; return false; }
                player->sr_frost_burst_available_ = false;
                int dmg = dice.roll(4);
                int dc = 10 + player->get_stats().vitality;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        t.player_ptr->take_damage(dmg, dice);
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Speed);
                        if (save.total < dc) t.player_ptr->get_status().add_condition(ConditionType::Slowed);
                    } else if (t.creature_ptr) {
                        t.creature_ptr->take_damage(dmg, dice);
                    }
                }
                last_action_log_ = current.name + " releases a Frost Burst — " + std::to_string(dmg) + " cold + Slowed (Speed DC " + std::to_string(dc) + ")!";
                return true;
            }

            // FrostbornIcewalk — Frostborn, 1/SR, 0 AP: +2d4 cold to attacks for 6 rounds
            if (param == "FrostbornIcewalk") {
                if (!player->sr_frostborn_icewalk_available_) { last_action_log_ = current.name + ": Icewalk already used this rest."; return false; }
                player->sr_frostborn_icewalk_available_ = false;
                player->frostborn_icewalk_active_ = true;
                player->frostborn_icewalk_rounds_ = 6;
                last_action_log_ = current.name + " channels Icewalk — +2d4 cold damage on attacks for 6 rounds!";
                return true;
            }

            // FrozenVeil — Glaceari, 1/LR, 0 AP: Dodging stance for 6 rounds (+2 AC)
            if (param == "FrozenVeil") {
                if (!player->lr_frozen_veil_available_) { last_action_log_ = current.name + ": Frozen Veil already used this rest."; return false; }
                player->lr_frozen_veil_available_ = false;
                player->frozen_veil_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " enters a Frozen Veil — +2 AC and Dodging for 6 rounds!";
                return true;
            }

            // StormCall — Nimbari, 3 AP: Daze all enemies in 15ft (Speed DC 10+SPD)
            if (param == "StormCall") {
                int dc = 10 + player->get_stats().speed;
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Speed);
                        if (save.total < dc) { t.player_ptr->get_status().add_condition(ConditionType::Dazed); affected++; }
                    } else if (t.creature_ptr) {
                        t.creature_ptr->take_damage(dice.roll(4), dice);
                        affected++;
                    }
                }
                last_action_log_ = current.name + " calls a Stormcall — Dazed (Speed DC " + std::to_string(dc) + ") to " + std::to_string(affected) + " target(s)!";
                return true;
            }

            // GraveBind — Tombwalker, 3 AP: drain 1d4+DIV HP from target (VIT DC 10+DIV)
            if (param == "GraveBind") {
                int dc = 10 + player->get_stats().divinity;
                int drain = dice.roll(4) + player->get_stats().divinity;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    bool resisted = false;
                    if (t.is_player && t.player_ptr) {
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Vitality);
                        resisted = (save.total >= dc);
                        if (!resisted) t.player_ptr->take_damage(drain, dice);
                    } else {
                        int enemy_save = dice.roll(20) + (t.creature_ptr ? t.creature_ptr->get_stats().vitality : 0);
                        resisted = (enemy_save >= dc);
                        if (!resisted && t.creature_ptr) t.creature_ptr->take_damage(drain, dice);
                    }
                    if (!resisted) player->heal(drain);
                    last_action_log_ = current.name + " casts Gravebind on " + t.name + " — " + (resisted ? "resisted (VIT DC " + std::to_string(dc) + ")!" : "drained " + std::to_string(drain) + " HP, healed " + std::to_string(drain) + "!");
                    return true;
                }
                last_action_log_ = current.name + ": No target for Gravebind.";
                return false;
            }

            // ===== THE PHARAOH'S DEN LINEAGES =====

            // Sporespit — Chokeling, 3 AP: Silences enemies in range (VIT DC 10+VIT)
            if (param == "Sporespit") {
                int dc = 10 + player->get_stats().vitality;
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Vitality);
                        if (save.total < dc) { t.player_ptr->get_status().add_condition(ConditionType::Silent); affected++; }
                    } else {
                        affected++;
                    }
                }
                last_action_log_ = current.name + " spits choking spores — Silenced (VIT DC " + std::to_string(dc) + ") to " + std::to_string(affected) + " target(s)!";
                return true;
            }

            // RotbornItem — Chokeling, 1/LR, 0 AP: spend all SP to corrode target's gear (10 HP per SP)
            if (param == "RotbornItem") {
                if (!player->lr_rotborn_item_available_) { last_action_log_ = current.name + ": Rotborn already used this rest."; return false; }
                if (player->current_sp_ <= 0) { last_action_log_ = current.name + ": No SP to spend for Rotborn."; return false; }
                player->lr_rotborn_item_available_ = false;
                int sp_spent = player->current_sp_;
                player->current_sp_ = 0;
                int rot_amount = sp_spent * 10;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        Armor* arm = t.player_ptr->get_armor();
                        if (arm) arm->take_damage(rot_amount);
                    }
                    last_action_log_ = current.name + " channels Rotborn — spent " + std::to_string(sp_spent) + " SP dealing " + std::to_string(rot_amount) + " rot to " + t.name + "'s gear!";
                    return true;
                }
                last_action_log_ = current.name + " channels Rotborn — spent " + std::to_string(sp_spent) + " SP (no target gear found).";
                return true;
            }

            // BloodlettingTouch — Crimson Veil, 3 AP: unarmed strike + heal for half damage
            if (param == "BloodlettingTouch") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int dmg = dice.roll(4) + player->get_stats().strength;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    int heal_amt = dmg / 2;
                    player->heal(heal_amt);
                    last_action_log_ = current.name + " uses Bloodletting Touch on " + t.name + " — " + std::to_string(dmg) + " damage, heals " + std::to_string(heal_amt) + "!";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Bloodletting Touch.";
                return false;
            }

            // VelvetTerror — Crimson Veil, 0 AP (3 SP): Charm or Fear AoE (DIV DC 10+DIV)
            if (param == "VelvetTerror") {
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP for Velvet Terror (need 3)."; return false; }
                player->current_sp_ -= 3;
                int dc = 10 + player->get_stats().divinity;
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Divinity);
                        if (save.total < dc) {
                            if (dice.roll(2) == 1) t.player_ptr->get_status().add_condition(ConditionType::Charm);
                            else t.player_ptr->get_status().add_condition(ConditionType::Fear);
                            affected++;
                        }
                    } else { affected++; }
                }
                last_action_log_ = current.name + " projects Velvet Terror — Charmed/Feared (DIV DC " + std::to_string(dc) + ") to " + std::to_string(affected) + " target(s)!";
                return true;
            }

            // TombSense — Jackal Human, 1/LR, 0 AP: auto-detect undead and traps for 1 hour
            if (param == "TombSense") {
                if (!player->lr_tomb_sense_available_) { last_action_log_ = current.name + ": Tomb Sense already used this rest."; return false; }
                player->lr_tomb_sense_available_ = false;
                last_action_log_ = current.name + " activates Tomb Sense — auto-detects undead and traps for 1 hour!";
                return true;
            }

            // Mindscratch — Whisperspawn, 1/SR, 0 AP: 2d4 psychic + Confused on target
            if (param == "Mindscratch") {
                if (!player->sr_mindscratch_available_) { last_action_log_ = current.name + ": Mindscratch already used this rest."; return false; }
                player->sr_mindscratch_available_ = false;
                int dmg = dice.roll(4) + dice.roll(4);
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        t.player_ptr->take_damage(dmg, dice);
                        t.player_ptr->get_status().add_condition(ConditionType::Confused);
                    } else if (t.creature_ptr) { t.creature_ptr->take_damage(dmg, dice); }
                    last_action_log_ = current.name + " uses Mindscratch on " + t.name + " — " + std::to_string(dmg) + " psychic + Confused!";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Mindscratch.";
                return false;
            }

            // ===== THE DARKNESS LINEAGES =====

            // GravitationalLeap — Gravemantle, 1/SR, 0 AP: double speed + Flying for 6 rounds
            if (param == "GravitationalLeap") {
                if (!player->sr_gravitational_leap_available_) { last_action_log_ = current.name + ": Gravitational Leap already used this rest."; return false; }
                player->sr_gravitational_leap_available_ = false;
                player->gravitational_leap_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Flying);
                last_action_log_ = current.name + " launches into a Gravitational Leap — double speed and Flying for 6 rounds!";
                return true;
            }

            // NightborneVeilstep — Nightborne Human, 3 AP: teleport 20ft and become Hidden
            if (param == "NightborneVeilstep") {
                current.movement_tiles_remaining += 4; // +20ft = 4 tiles
                player->get_status().add_condition(ConditionType::Hidden);
                last_action_log_ = current.name + " vanishes with a Veilstep — teleports 20ft and becomes Hidden!";
                return true;
            }

            // CreepingDark — Nightborne Human, 1/LR, 0 AP: Sneak advantage + Invisible for 6 rounds
            if (param == "CreepingDark") {
                if (!player->lr_creeping_dark_available_) { last_action_log_ = current.name + ": Creeping Dark already used this rest."; return false; }
                player->lr_creeping_dark_available_ = false;
                player->creeping_dark_active_ = true;
                player->creeping_dark_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Invisible);
                last_action_log_ = current.name + " fades into Creeping Dark — Invisible and Sneak advantage for 6 rounds!";
                return true;
            }

            // ===== ARCANE COLLAPSE LINEAGES =====

            // AbsorbMagic — Blightmire, 1/SR, 0 AP reaction: gain damage reduction vs next spell
            if (param == "AbsorbMagic") {
                if (!player->sr_absorb_magic_available_) { last_action_log_ = current.name + ": Absorb Magic already used this rest."; return false; }
                player->sr_absorb_magic_available_ = false;
                int temp_shield = 2 * player->get_level();
                player->pending_damage_reduction_ = temp_shield;
                last_action_log_ = current.name + " channels Absorb Magic — absorbs " + std::to_string(temp_shield) + " damage from the next spell!";
                return true;
            }

            // DregspawnExtend — Dregspawn, 1/SR, 0 AP: extend reach (+5ft), advantage on next attack
            if (param == "DregspawnExtend") {
                if (!player->sr_dregspawn_extend_available_) { last_action_log_ = current.name + ": Reach extension already used this rest."; return false; }
                player->sr_dregspawn_extend_available_ = false;
                player->advantage_until_tick_ = 1;
                last_action_log_ = current.name + " extends its Mutant Grasp — +5ft reach, advantage on next attack!";
                return true;
            }

            // AberrantFlex — Dregspawn, 1/SR, 0 AP: instantly escape Grappled/Restrained/Prone
            if (param == "AberrantFlex") {
                if (!player->sr_aberrant_flex_available_) { last_action_log_ = current.name + ": Aberrant Flex already used this rest."; return false; }
                player->sr_aberrant_flex_available_ = false;
                player->get_status().remove_condition(ConditionType::Grappled);
                player->get_status().remove_condition(ConditionType::Restrained);
                player->get_status().remove_condition(ConditionType::Prone);
                current.grappled_by_id = "";
                last_action_log_ = current.name + " twists free with Aberrant Flex — Grappled/Restrained/Prone removed!";
                return true;
            }

            // VoidAura — Nullborn, 1/LR or 6 SP: anti-magic aura for 6 rounds + Confused/Dazed AoE
            if (param == "VoidAura") {
                bool use_sp = !player->lr_void_aura_available_ && player->current_sp_ >= 6;
                if (!player->lr_void_aura_available_ && player->current_sp_ < 6) {
                    last_action_log_ = current.name + ": Void Aura unavailable (LR used, need 6 SP)."; return false;
                }
                if (use_sp) { player->current_sp_ -= 6; } else { player->lr_void_aura_available_ = false; }
                player->void_aura_rounds_ = 6;
                int dc = 10 + player->get_stats().divinity;
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Divinity);
                        if (save.total < dc) {
                            t.player_ptr->get_status().add_condition(ConditionType::Confused);
                            t.player_ptr->get_status().add_condition(ConditionType::Dazed);
                            affected++;
                        }
                    } else { affected++; }
                }
                last_action_log_ = current.name + " opens a Void Aura — anti-magic for 6 rounds! Confused+Dazed (DIV DC " + std::to_string(dc) + ") to " + std::to_string(affected) + " target(s)!";
                return true;
            }

            // CrystalSlash — Shardwraith, 1/SR, 0 AP: 2d4+DIV force AoE (Speed DC 10+DIV, half on save)
            if (param == "CrystalSlash") {
                if (!player->sr_crystal_slash_available_) { last_action_log_ = current.name + ": Crystal Slash already used this rest."; return false; }
                player->sr_crystal_slash_available_ = false;
                int dmg = dice.roll(4) + dice.roll(4) + player->get_stats().divinity;
                int dc = 10 + player->get_stats().divinity;
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        auto save = t.player_ptr->roll_stat_check(dice, StatType::Speed);
                        int actual = (save.total >= dc) ? dmg / 2 : dmg;
                        t.player_ptr->take_damage(actual, dice);
                    } else {
                        int save_roll = dice.roll(20) + (t.creature_ptr ? t.creature_ptr->get_stats().speed : 0);
                        int actual = (save_roll >= dc) ? dmg / 2 : dmg;
                        if (t.creature_ptr) t.creature_ptr->take_damage(actual, dice);
                    }
                    affected++;
                }
                last_action_log_ = current.name + " launches Crystal Slash — " + std::to_string(dmg) + " force (Speed DC " + std::to_string(dc) + ", half on save) to " + std::to_string(affected) + " target(s)!";
                return true;
            }

            // ===== ARGENT HALL LINEAGES =====

            // SealOfFrost — Argent Dvarrim, 0 AP (1 SP): frostseal target — Slowed
            if (param == "SealOfFrost") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Seal of Frost (need 1)."; return false; }
                player->current_sp_--;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        t.player_ptr->get_status().add_condition(ConditionType::Slowed);
                        int frost_dmg = dice.roll(4) + dice.roll(4);
                        t.player_ptr->take_damage(frost_dmg, dice);
                        last_action_log_ = current.name + " places a Seal of Frost on " + t.name + " — " + std::to_string(frost_dmg) + " cold, Slowed!";
                    } else if (t.creature_ptr) {
                        int frost_dmg2 = dice.roll(4) + dice.roll(4);
                        t.creature_ptr->take_damage(frost_dmg2, dice);
                        last_action_log_ = current.name + " places a Seal of Frost on " + t.name + " — Slowed!";
                    }
                    return true;
                }
                last_action_log_ = current.name + ": No target for Seal of Frost.";
                return false;
            }

            // SilentLedger — Argent Dvarrim, 3 AP toggle: silence 15ft aura (-3 max AP while active)
            if (param == "SilentLedger") {
                player->argent_silent_ledger_active_ = !player->argent_silent_ledger_active_;
                if (player->argent_silent_ledger_active_) {
                    for (auto& t : combatants_) {
                        if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                        if (t.is_player && t.player_ptr) t.player_ptr->get_status().add_condition(ConditionType::Silent);
                    }
                    last_action_log_ = current.name + " opens the Silent Ledger — silence aura active, -3 max AP!";
                } else {
                    last_action_log_ = current.name + " closes the Silent Ledger — silence aura deactivated, max AP restored!";
                }
                return true;
            }

            // GlacialWall — Frostbound Dvarrim, 3 AP toggle: ice wall (+3 AC, -3 max AP while active)
            if (param == "GlacialWall") {
                player->glacial_wall_active_ = !player->glacial_wall_active_;
                if (player->glacial_wall_active_) {
                    last_action_log_ = current.name + " raises a Glacial Wall — +3 AC, -3 max AP while active!";
                } else {
                    last_action_log_ = current.name + " lowers the Glacial Wall — AC bonus removed, max AP restored!";
                }
                return true;
            }

            // UnyieldingBulwark — Frostbound Dvarrim, 0 AP (2 SP): resistance to all damage for 6 rounds
            if (param == "UnyieldingBulwark") {
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP for Unyielding Bulwark (need 2)."; return false; }
                player->current_sp_ -= 2;
                player->unyielding_bulwark_active_ = true;
                player->unyielding_bulwark_rounds_ = 6;
                player->has_physical_resistance_ = true;
                last_action_log_ = current.name + " enters Unyielding Bulwark — resistance to all damage for 6 rounds!";
                return true;
            }

            // StoneMoldReshape — Stonemind Dvarrim, 0 AP (2 SP): reshape stone permanently (narrative)
            if (param == "StoneMoldReshape") {
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP for Stoneflow Reshape (need 2)."; return false; }
                player->current_sp_ -= 2;
                last_action_log_ = current.name + " channels Stoneflow Reshape — molds a 5ft cube of stone permanently!";
                return true;
            }

            // ArchitectsShield — Stonemind Dvarrim, 3 AP toggle: +2 AC, ranged resistance aura (-3 max AP)
            if (param == "ArchitectsShield") {
                player->stonemind_architects_shield_active_ = !player->stonemind_architects_shield_active_;
                if (player->stonemind_architects_shield_active_) {
                    last_action_log_ = current.name + " raises the Architect's Shield — +2 AC, ranged resistance aura, -3 max AP!";
                } else {
                    last_action_log_ = current.name + " lowers the Architect's Shield — AC bonus removed, max AP restored!";
                }
                return true;
            }

            // MinersInstinct — Glaciervein Dvarrim, 3 AP toggle: tremorsense 30ft, Perception advantage (-3 max AP)
            if (param == "MinersInstinct") {
                player->miners_instinct_active_ = !player->miners_instinct_active_;
                if (player->miners_instinct_active_) {
                    last_action_log_ = current.name + " activates Miner's Instinct — tremorsense 30ft, Perception advantage, -3 max AP!";
                } else {
                    last_action_log_ = current.name + " deactivates Miner's Instinct — max AP restored!";
                }
                return true;
            }

            // ===== THE GLASS PASSAGE LINEAGES =====

            // WindCloak — Galesworn Human, 0 AP, 1/LR: envelop self in wind for 6 rounds (Dodging)
            if (param == "WindCloak") {
                if (!player->lr_wind_step_available_) { last_action_log_ = current.name + ": Wind Cloak already used this rest."; return false; }
                player->lr_wind_step_available_ = false;
                player->wind_cloak_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " wraps in whirling Wind Cloak — Dodging for 6 rounds!";
                return true;
            }

            // Gustcaller — Galesworn Human, 3 AP: burst of wind deals 2d4 to all enemies, pushes them back
            if (param == "Gustcaller") {
                int dmg = dice.roll(4) + dice.roll(4);
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    affected++;
                }
                last_action_log_ = current.name + " unleashes Gustcaller — " + std::to_string(dmg) + " wind damage to " + std::to_string(affected) + " target(s), pushed back!";
                return true;
            }

            // PangolArmorReact — Pangol, 0 AP, uses = Speed per LR: +5 AC reaction until next turn
            if (param == "PangolArmorReact") {
                if (player->lr_pangol_armor_reaction_uses_ <= 0) { last_action_log_ = current.name + ": No Armor Reaction uses remaining."; return false; }
                player->lr_pangol_armor_reaction_uses_--;
                player->pangol_armor_react_active_ = true;
                last_action_log_ = current.name + " curls plates into Armor Reaction — +5 AC until next turn! (" + std::to_string(player->lr_pangol_armor_reaction_uses_) + " uses left)";
                return true;
            }

            // CurlUp — Pangol, 0 AP, 1/SR: curl into shell (speed 0, Dodging, resistance to physical)
            if (param == "CurlUp") {
                if (!player->sr_curl_up_available_) { last_action_log_ = current.name + ": Curl Up already used this rest."; return false; }
                player->sr_curl_up_available_ = false;
                player->curl_up_active_ = true;
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " curls into its armored shell — speed 0, Dodging, physical resistance!";
                return true;
            }

            // Uncurl — Pangol, 1 AP: emerge from shell
            if (param == "Uncurl") {
                if (!player->curl_up_active_) { last_action_log_ = current.name + ": Not curled up."; return false; }
                player->curl_up_active_ = false;
                player->get_status().remove_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " uncurls from its shell — movement restored!";
                return true;
            }

            // GildedBearing — Porcelari, 0 AP, 1/SR: advantage on next Speechcraft check
            if (param == "GildedBearing") {
                if (!player->sr_gilded_bearing_available_) { last_action_log_ = current.name + ": Gilded Bearing already used this rest."; return false; }
                player->sr_gilded_bearing_available_ = false;
                player->advantage_until_tick_ = 1;
                last_action_log_ = current.name + " radiates Gilded Bearing — advantage on next Speechcraft check!";
                return true;
            }

            // ChromaticShift — Prismari, 0 AP, 1/SR: shift color (Invisible 6 rounds, Sneak advantage)
            if (param == "ChromaticShift") {
                if (!player->sr_chromatic_shift_available_) { last_action_log_ = current.name + ": Chromatic Shift already used this rest."; return false; }
                player->sr_chromatic_shift_available_ = false;
                player->chromatic_shift_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Invisible);
                last_action_log_ = current.name + " activates Chromatic Shift — Invisible for 6 rounds, Sneak advantage!";
                return true;
            }

            // PrismaticReflection — Prismari, 0 AP, 1/LR: reflect damage (Resistance 6 rounds)
            if (param == "PrismaticReflection") {
                if (!player->lr_prismatic_reflection_available_) { last_action_log_ = current.name + ": Prismatic Reflection already used this rest."; return false; }
                player->lr_prismatic_reflection_available_ = false;
                player->prismatic_reflection_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Resistance);
                last_action_log_ = current.name + " activates Prismatic Reflection — Resistance to next damage source for 6 rounds!";
                return true;
            }

            // DustShroud — Dustborn, 0 AP, 1/LR: cloak in swirling dust (Hidden + Dodging 6 rounds)
            if (param == "DustShroud") {
                if (!player->lr_dust_shroud_available_) { last_action_log_ = current.name + ": Dust Shroud already used this rest."; return false; }
                player->lr_dust_shroud_available_ = false;
                player->dust_shroud_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Hidden);
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " erupts in Dust Shroud — Hidden and Dodging for 6 rounds!";
                return true;
            }

            // DustStrike — Dustborn, 0 AP (while shrouded): deal 1d6+DIV grit damage to one enemy
            if (param == "DustStrike") {
                if (player->dust_shroud_rounds_ <= 0) { last_action_log_ = current.name + ": Dust Strike requires active Dust Shroud."; return false; }
                int dmg = dice.roll(6) + player->get_stats().divinity;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    last_action_log_ = current.name + " strikes from the dust — " + std::to_string(dmg) + " grit damage to " + t.name + "!";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Dust Strike.";
                return false;
            }

            // ===== SACRAL SEPARATION LINEAGES =====

            // ShatterPulseGlassborn — Glassborn, 0 AP, 1/LR: prime a shatter pulse (triggers on next crit)
            if (param == "ShatterPulseGlassborn") {
                if (!player->lr_shatter_pulse_glassborn_available_) { last_action_log_ = current.name + ": Shatter Pulse already used this rest."; return false; }
                player->lr_shatter_pulse_glassborn_available_ = false;
                last_action_log_ = current.name + " primes Shatter Pulse — next critical hit sends a glass shockwave!";
                return true;
            }

            // PrismVeins — Glassborn, 0 AP, 1/SR: activate radiant resistance for 6 rounds
            if (param == "PrismVeins") {
                if (!player->sr_prism_veins_available_) { last_action_log_ = current.name + ": Prism Veins already used this rest."; return false; }
                player->sr_prism_veins_available_ = false;
                player->has_radiant_resistance_ = true;
                last_action_log_ = current.name + " activates Prism Veins — radiant resistance until next short rest!";
                return true;
            }

            // DeathsWhisper — Gravetouched, 0 AP, 1/LR: commune with recently dead (narrative)
            if (param == "DeathsWhisper") {
                if (!player->lr_deaths_whisper_available_) { last_action_log_ = current.name + ": Death's Whisper already used this rest."; return false; }
                player->lr_deaths_whisper_available_ = false;
                last_action_log_ = current.name + " whispers to the dead — senses linger of those who fell here (Death's Whisper)!";
                return true;
            }

            // UnstableMutation — Madness-Touched Human, 0 AP: gain advantage on next 2 checks, then disadvantage on next 2
            if (param == "UnstableMutation") {
                player->advantage_until_tick_ = 2;
                player->unstable_mutation_disadvantage_remaining_ = 2;
                last_action_log_ = current.name + " triggers Unstable Mutation — advantage on next 2 checks, then disadvantage on 2!";
                return true;
            }

            // FracturedMind — Madness-Touched Human, 0 AP: spend insanity points to expand crit range
            if (param == "FracturedMind") {
                int ins = player->get_insanity_level();
                if (ins <= 0) { last_action_log_ = current.name + ": No insanity to channel for Fractured Mind."; return false; }
                player->set_insanity_level(0);
                player->madness_crit_bonus_ = std::min(ins, 5);
                last_action_log_ = current.name + " fractures their mind — spent " + std::to_string(ins) + " insanity for +" + std::to_string(player->madness_crit_bonus_) + " crit range!";
                return true;
            }

            // ===== THE INFERNAL MACHINE LINEAGES =====

            // LuminousToggle — Candlites, 0 AP: toggle internal flame on or off
            if (param == "LuminousToggle") {
                player->candlite_flame_lit_ = !player->candlite_flame_lit_;
                last_action_log_ = current.name + (player->candlite_flame_lit_ ? " ignites their flame — warmth and light radiate!" : " snuffs their flame — darkness takes hold!");
                return true;
            }

            // WaxenForm — Candlites, 3 AP: melt wax over self or wound (sacrifice 1d4 HP to heal target 2d4)
            if (param == "WaxenForm") {
                if (!player->candlite_flame_lit_) { last_action_log_ = current.name + ": Flame must be lit to use Waxen Form."; return false; }
                int cost = dice.roll(4);
                int heal_amt = dice.roll(4) + dice.roll(4);
                player->take_damage(cost, dice);
                for (auto& t : combatants_) {
                    if (!t.is_player || !t.player_ptr || t.player_ptr == player) continue;
                    if (t.get_current_hp() <= 0) continue;
                    t.player_ptr->heal(heal_amt);
                    last_action_log_ = current.name + " pours Waxen Form onto " + t.name + " — spent " + std::to_string(cost) + " HP to heal " + std::to_string(heal_amt) + " HP!";
                    return true;
                }
                // No ally — apply to self
                player->heal(heal_amt);
                last_action_log_ = current.name + " pours Waxen Form on self — spent " + std::to_string(cost) + " HP to heal " + std::to_string(heal_amt) + " HP!";
                return true;
            }

            // PainMadeFlesh — Flenskin, 0 AP, 1/LR: become Invulnerable for 3 rounds
            if (param == "PainMadeFlesh") {
                if (!player->lr_pain_made_flesh_available_) { last_action_log_ = current.name + ": Pain Made Flesh already used this rest."; return false; }
                player->lr_pain_made_flesh_available_ = false;
                player->pain_made_flesh_active_ = true;
                player->pain_made_flesh_rounds_ = 3;
                player->get_status().add_condition(ConditionType::Invulnerable);
                last_action_log_ = current.name + " channels Pain Made Flesh — Invulnerable for 3 rounds!";
                return true;
            }

            // InfernalStare — Hellforged, 0 AP, 1/LR: lock gaze on enemies (1d4 fire per turn to all for 4 rounds)
            if (param == "InfernalStare") {
                if (!player->lr_infernal_stare_available_) { last_action_log_ = current.name + ": Infernal Stare already used this rest."; return false; }
                player->lr_infernal_stare_available_ = false;
                player->infernal_stare_rounds_ = 4;
                last_action_log_ = current.name + " locks an Infernal Stare — 1d4 fire damage to all enemies each turn for 4 rounds!";
                return true;
            }

            // InfernalSmite — Hellforged, 0 AP, 1/SR: next attack deals +2d4 fire bonus damage
            if (param == "InfernalSmite") {
                if (!player->sr_infernal_smite_available_) { last_action_log_ = current.name + ": Infernal Smite already used this rest."; return false; }
                player->sr_infernal_smite_available_ = false;
                player->infernal_smite_rounds_ = 1;
                last_action_log_ = current.name + " channels Infernal Smite — next attack deals +2d4 fire bonus damage!";
                return true;
            }

            // WhipLash — Scourling Human, 3 AP: lashing whip strike 1d6+STR, target goes Prone
            if (param == "WhipLash") {
                int dmg = dice.roll(6) + player->get_stats().strength;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) {
                        t.player_ptr->take_damage(dmg, dice);
                        t.player_ptr->get_status().add_condition(ConditionType::Prone);
                    } else if (t.creature_ptr) {
                        t.creature_ptr->take_damage(dmg, dice);
                    }
                    last_action_log_ = current.name + " cracks Whip Lash at " + t.name + " — " + std::to_string(dmg) + " damage, Prone!";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Whip Lash.";
                return false;
            }

            // ===== TITAN'S LAMENT LINEAGES =====

            // CursedSpark — Ashenborn, 0 AP, 1/SR: add 1d4 fire to next attack/spell for 6 rounds
            if (param == "CursedSpark") {
                if (!player->sr_cursed_spark_available_) { last_action_log_ = current.name + ": Cursed Spark already used this rest."; return false; }
                player->sr_cursed_spark_available_ = false;
                player->cursed_spark_rounds_ = 6;
                last_action_log_ = current.name + " ignites Cursed Spark — next attacks deal +1d4 fire for 6 rounds!";
                return true;
            }

            // DesertWalker — Sandstrider Human, 0 AP, 1/LR: summon swirling sand cloud (Dodging 6 rounds)
            if (param == "DesertWalker") {
                if (!player->lr_desert_walker_available_) { last_action_log_ = current.name + ": Desert Walker already used this rest."; return false; }
                player->lr_desert_walker_available_ = false;
                player->desert_walker_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " summons a Desert Walker sand cloud — Dodging for 6 rounds!";
                return true;
            }

            // Gore — Taurin, 0 AP, VIT uses/SR: horn attack 1d6+STR or SPD piercing (free action)
            if (param == "Gore") {
                if (player->sr_gore_uses_ <= 0) { last_action_log_ = current.name + ": No Gore uses remaining."; return false; }
                player->sr_gore_uses_--;
                int mod = std::max(player->get_stats().strength, player->get_stats().speed);
                int dmg = dice.roll(6) + mod;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    last_action_log_ = current.name + " gores with their horns — " + std::to_string(dmg) + " piercing to " + t.name + "! (" + std::to_string(player->sr_gore_uses_) + " uses left)";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Gore.";
                return false;
            }

            // StubbornWill — Taurin, 0 AP, 1/SR: advantage on next stat save (anti-knockdown)
            if (param == "StubbornWill") {
                if (!player->sr_stubborn_will_available_) { last_action_log_ = current.name + ": Stubborn Will already used this rest."; return false; }
                player->sr_stubborn_will_available_ = false;
                player->advantage_until_tick_ = 1;
                last_action_log_ = current.name + " braces with Stubborn Will — advantage on next save!";
                return true;
            }

            // HibernateUrsari — Ursari, 0 AP, 1/LR: fully heal + bonus HP = level, then Unconscious
            if (param == "HibernateUrsari") {
                if (!player->lr_hibernate_available_) { last_action_log_ = current.name + ": Hibernate already used this rest."; return false; }
                player->lr_hibernate_available_ = false;
                player->heal(player->get_max_hp() + player->get_level());
                player->get_status().add_condition(ConditionType::Unconscious);
                last_action_log_ = current.name + " enters Hibernate — fully healed + " + std::to_string(player->get_level()) + " bonus HP, now Unconscious for ~1 minute!";
                return true;
            }

            // ===== THE MORTAL ARENA LINEAGES =====

            // Blazeblood — Emberkin, 0 AP, 1/SR: add 1d4 fire to melee attacks for 6 rounds
            if (param == "Blazeblood") {
                if (!player->sr_blazeblood_available_) { last_action_log_ = current.name + ": Blazeblood already used this rest."; return false; }
                player->sr_blazeblood_available_ = false;
                player->blazeblood_rounds_ = 6;
                last_action_log_ = current.name + " activates Blazeblood — +1d4 fire on melee attacks for 6 rounds!";
                return true;
            }

            // SootSight — Emberkin, 0 AP, 1/LR: create smoke cloud (Dodging, enemies have disadvantage) 6 rounds
            if (param == "SootSight") {
                if (!player->lr_soot_sight_available_) { last_action_log_ = current.name + ": Soot Sight already used this rest."; return false; }
                player->lr_soot_sight_available_ = false;
                player->soot_sight_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " erupts in smoke (Soot Sight) — Dodging for 6 rounds, others can't see through it!";
                return true;
            }

            // ShockPulse — Stormclad, 3 AP, 1 SP: 3d6 lightning AoE (VIT DC 10+DIV for half)
            if (param == "ShockPulse") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Shock Pulse (need 1)."; return false; }
                player->current_sp_--;
                int dc = 10 + player->get_stats().divinity;
                int total_dmg = dice.roll(6) + dice.roll(6) + dice.roll(6);
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    bool saved = false;
                    int save_roll = (t.is_player && t.player_ptr)
                        ? t.player_ptr->roll_stat_check(dice, StatType::Vitality).total
                        : (t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20));
                    saved = (save_roll >= dc);
                    int dmg = saved ? std::max(1, total_dmg / 2) : total_dmg;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    affected++;
                }
                last_action_log_ = current.name + " unleashes Shock Pulse — " + std::to_string(total_dmg) + " lightning to " + std::to_string(affected) + " target(s) (VIT DC " + std::to_string(dc) + ")!";
                return true;
            }

            // SunderbornHibernate — Sunderborn Human, 0 AP, 1/LR: spend SP to appear dead (narrative)
            if (param == "SunderbornHibernate") {
                if (!player->lr_sunderborn_hibernate_available_) { last_action_log_ = current.name + ": Lifeforce Hibernation already used this rest."; return false; }
                player->lr_sunderborn_hibernate_available_ = false;
                player->get_status().add_condition(ConditionType::Unconscious);
                last_action_log_ = current.name + " enters Lifeforce Hibernation — appears dead to observers!";
                return true;
            }

            // LimbRegrowth — Sunderborn Human, 0 AP, 2 SP: instantly regrow a lost limb
            if (param == "LimbRegrowth") {
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Need 2 SP for Limb Regrowth."; return false; }
                player->current_sp_ -= 2;
                last_action_log_ = current.name + " channels lifeforce — Limb Regrowth complete! Limb instantly restored.";
                return true;
            }

            // ===== VULCAN VALLEY LINEAGES =====

            // AshrotAuraToggle — Ashrot Human, 0 AP: toggle smoldering aura (1 fire/turn to nearby enemies)
            if (param == "AshrotAuraToggle") {
                player->ashrot_aura_active_ = !player->ashrot_aura_active_;
                last_action_log_ = current.name + (player->ashrot_aura_active_ ? "'s Smoldering Aura ignites — 1 fire/turn to nearby enemies!" : "'s Smoldering Aura snuffed out!");
                return true;
            }

            // AshrotAuraBurst — Ashrot Human, 0 AP, 1 SP: burst of aura energy (1d4 fire AoE)
            if (param == "AshrotAuraBurst") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Need 1 SP for Aura Burst."; return false; }
                player->current_sp_--;
                int burst = dice.roll(4);
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(burst, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(burst, dice);
                }
                last_action_log_ = current.name + " flares Aura Burst — " + std::to_string(burst) + " fire AoE!";
                return true;
            }

            // SmolderingGlare — Cindervolk, 0 AP, 1/LR: shed bright light + 1d4 fire to nearby each round (6 rounds)
            if (param == "SmolderingGlare") {
                if (!player->lr_smoldering_glare_available_) { last_action_log_ = current.name + ": Smoldering Glare already used this rest."; return false; }
                player->lr_smoldering_glare_available_ = false;
                player->smoldering_glare_rounds_ = 6;
                last_action_log_ = current.name + " activates Smoldering Glare — 1d4 fire to nearby enemies each round for 6 rounds!";
                return true;
            }

            // DraconicAwakening — Drakari, 0 AP, 1/LR or 4 SP: enter dragon form (Flying, +size, bonus elemental melee)
            if (param == "DraconicAwakening") {
                if (!player->lr_draconic_awakening_available_) {
                    if (player->current_sp_ < 4) { last_action_log_ = current.name + ": Need 4 SP to reuse Draconic Awakening."; return false; }
                    player->current_sp_ -= 4;
                } else {
                    player->lr_draconic_awakening_available_ = false;
                }
                player->draconic_form_active_ = true;
                player->draconic_form_rounds_ = 10;
                player->get_status().add_condition(ConditionType::Flying);
                last_action_log_ = current.name + " awakens Draconic Form — Flying, Large size, +" + std::to_string(player->get_level()) + "d4 " + player->draconic_element_ + " melee for 10 rounds!";
                return true;
            }

            // BreathWeapon — Drakari, 3 AP: elemental breath cone (2d6+level, or 4d6+level in dragon form; VIT DC 10+DIV half)
            if (param == "BreathWeapon") {
                int dc = 10 + player->get_stats().divinity;
                int base_dice = player->draconic_form_active_ ? 4 : 2;
                int total_dmg = 0;
                for (int i = 0; i < base_dice; ++i) total_dmg += dice.roll(6);
                total_dmg += player->get_level();
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save_roll = (t.is_player && t.player_ptr)
                        ? t.player_ptr->roll_stat_check(dice, StatType::Vitality).total
                        : (t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20));
                    int dmg = (save_roll >= dc) ? std::max(1, total_dmg / 2) : total_dmg;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    affected++;
                }
                last_action_log_ = current.name + " breathes " + player->draconic_element_ + " — " + std::to_string(total_dmg) + " damage to " + std::to_string(affected) + " target(s) (VIT DC " + std::to_string(dc) + ")!";
                return true;
            }

            // === THE ISLES ===
            // AbyssariGlowToggle — Abyssari, 0 AP: toggle bioluminescence (Hidden from blinded enemies)
            if (param == "AbyssariGlowToggle") {
                player->abyssari_glow_active_ = !player->abyssari_glow_active_;
                last_action_log_ = current.name + (player->abyssari_glow_active_ ? " activates Bioluminescence — emitting cold light!" : " dims Bioluminescence.");
                return true;
            }

            // AbyssariPulse — Abyssari, 0 AP, 1/LR: pulse aura blinding nearby enemies (Blinded 1 round, VIT DC 12+DIV)
            if (param == "AbyssariPulse") {
                if (!player->lr_abyssari_pulse_available_) { last_action_log_ = current.name + ": Abyssal Pulse already used this rest."; return false; }
                player->lr_abyssari_pulse_available_ = false;
                int dc = 12 + player->get_stats().divinity;
                int blinded = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    if (save < dc) { if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Blinded); blinded++; }
                }
                last_action_log_ = current.name + " unleashes Abyssal Pulse — " + std::to_string(blinded) + " target(s) blinded (VIT DC " + std::to_string(dc) + ")!";
                return true;
            }

            // MirelingEscape — Mireling, 0 AP, 1/LR: escape grapple or restrained, move 10 ft instantly
            if (param == "MirelingEscape") {
                if (!player->lr_mireling_escape_available_) { last_action_log_ = current.name + ": Slippery Escape already used this rest."; return false; }
                player->lr_mireling_escape_available_ = false;
                player->get_status().remove_condition(ConditionType::Grappled);
                player->get_status().remove_condition(ConditionType::Restrained);
                last_action_log_ = current.name + " slips free! Grappled/Restrained cleared, teleports 10 ft!";
                return true;
            }

            // LunarRadiance — Moonkin, 0 AP, 1/LR: radiance buff for 6 rounds (+1d6 radiant on attacks)
            if (param == "LunarRadiance") {
                if (!player->lr_lunar_radiance_available_) { last_action_log_ = current.name + ": Lunar Radiance already used this rest."; return false; }
                player->lr_lunar_radiance_available_ = false;
                player->lunar_radiance_rounds_ = 6;
                last_action_log_ = current.name + " channels Lunar Radiance — attacks deal +1d6 radiant for 6 rounds!";
                return true;
            }

            // BrineCone — Tiderunner Human, 3 AP: saltwater cone (2d6 + Blinded, VIT DC 12+DIV half and no blind)
            if (param == "BrineCone") {
                int dc = 12 + player->get_stats().divinity;
                int cone_dmg = dice.roll(6) + dice.roll(6);
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    int dmg = (save >= dc) ? std::max(1, cone_dmg / 2) : cone_dmg;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) { t.creature_ptr->take_damage(dmg, dice); if (save < dc) t.creature_ptr->get_status().add_condition(ConditionType::Blinded); }
                    affected++;
                }
                last_action_log_ = current.name + " unleashes Brine Cone — " + std::to_string(cone_dmg) + " damage + Blinded to " + std::to_string(affected) + " target(s) (VIT DC " + std::to_string(dc) + ")!";
                return true;
            }

            // EbbAndFlow — Fathomari, 0 AP, Speed/LR uses: surge movement this turn (+2 tiles)
            if (param == "EbbAndFlow") {
                if (player->lr_ebb_flow_uses_ <= 0) { last_action_log_ = current.name + ": No Ebb and Flow uses remaining."; return false; }
                player->lr_ebb_flow_uses_--;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += 2;
                last_action_log_ = current.name + " surges with Ebb and Flow — +10 ft movement! (" + std::to_string(player->lr_ebb_flow_uses_) + " uses left)";
                return true;
            }

            // === THE DEPTHS OF DENORIM ===
            // HydrasResilience — Hydrakari, 0 AP, 1/SR reaction: reduce next incoming damage by 1d6+VIT
            if (param == "HydrasResilience") {
                if (!player->sr_hydras_resilience_available_) { last_action_log_ = current.name + ": Hydra's Resilience already used this rest."; return false; }
                player->sr_hydras_resilience_available_ = false;
                int reduction = dice.roll(6) + player->get_stats().vitality;
                player->pending_damage_reduction_ = reduction;
                last_action_log_ = current.name + " braces with Hydra's Resilience — next " + std::to_string(reduction) + " damage absorbed!";
                return true;
            }

            // LimbSacrifice — Hydrakari, 0 AP, 1/LR: sacrifice a limb to break free + regrow next SR (auto-escape grapple/restrained)
            if (param == "LimbSacrifice") {
                if (!player->lr_hydra_limb_sacrifice_available_) { last_action_log_ = current.name + ": Limb Sacrifice already used this rest."; return false; }
                player->lr_hydra_limb_sacrifice_available_ = false;
                player->get_status().remove_condition(ConditionType::Grappled);
                player->get_status().remove_condition(ConditionType::Restrained);
                int self_dmg = dice.roll(6);
                player->take_damage(self_dmg, dice);
                last_action_log_ = current.name + " sacrifices a limb — breaks free from restraint! (" + std::to_string(self_dmg) + " self damage, regrows at SR)";
                return true;
            }

            // Tidebind — Kelpheart Human, 3 AP: bind target in water tendrils (Restrained + 1d8, STR DC 12+VIT)
            if (param == "Tidebind") {
                int dc = 12 + player->get_stats().vitality;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int bind_dmg = dice.roll(8);
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().strength : dice.roll(20);
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(bind_dmg, dice);
                    else if (t.creature_ptr) { t.creature_ptr->take_damage(bind_dmg, dice); if (save < dc) t.creature_ptr->get_status().add_condition(ConditionType::Restrained); }
                    last_action_log_ = current.name + " binds " + t.name + " with Tidebind — " + std::to_string(bind_dmg) + " damage" + (save < dc ? ", Restrained!" : " (saved vs restrained)") + "!";
                    return true;
                }
                last_action_log_ = current.name + ": No targets in range for Tidebind.";
                return false;
            }

            // AbyssalMutation — Trenchborn, 0 AP, 1/SR: random mutation buff (roll 1d4: 1=+STR, 2=+SPD, 3=+VIT, 4=all+1)
            if (param == "AbyssalMutation") {
                if (!player->sr_abyssal_mutation_available_) { last_action_log_ = current.name + ": Abyssal Mutation already used this rest."; return false; }
                player->sr_abyssal_mutation_available_ = false;
                int roll = dice.roll(4);
                std::string effect;
                if (roll == 1) { player->get_stats().strength++; effect = "+1 STR"; }
                else if (roll == 2) { player->get_stats().speed++; effect = "+1 SPD"; }
                else if (roll == 3) { player->get_stats().vitality++; effect = "+1 VIT"; }
                else { player->get_stats().strength++; player->get_stats().speed++; player->get_stats().vitality++; effect = "+1 STR/SPD/VIT"; }
                last_action_log_ = current.name + " mutates! Abyssal Mutation: " + effect + " until SR!";
                return true;
            }

            // === MOROBOROS ===
            // CloudlingFly — Cloudling, 0 AP: toggle flight (-3 max AP, gain Flying condition)
            if (param == "CloudlingFly") {
                player->cloudling_fly_active_ = !player->cloudling_fly_active_;
                if (player->cloudling_fly_active_) player->get_status().add_condition(ConditionType::Flying);
                else player->get_status().remove_condition(ConditionType::Flying);
                last_action_log_ = current.name + (player->cloudling_fly_active_ ? " takes flight! (-3 max AP)" : " lands, flying deactivated.");
                return true;
            }

            // MistForm — Cloudling, 0 AP, 1/SR free (subsequent cost 1 SP): become Intangible for 3 rounds
            if (param == "MistForm") {
                if (!player->sr_mist_form_available_) {
                    if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Need 1 SP to reuse Mist Form."; return false; }
                    player->current_sp_--;
                } else {
                    player->sr_mist_form_available_ = false;
                    player->mist_form_used_once_ = true;
                }
                player->mist_form_rounds_ = 3;
                player->get_status().add_condition(ConditionType::Intangible);
                last_action_log_ = current.name + " disperses into Mist Form — Intangible for 3 rounds!";
                return true;
            }

            // SurgeStep — Tidewoven, 0 AP: double movement speed this turn
            if (param == "SurgeStep") {
                player->surge_step_active_ = true;
                last_action_log_ = current.name + " surges forward — movement doubled this turn!";
                return true;
            }

            // HuntersFocus — Venari, 0 AP, 1/LR: mark nearest enemy for +1d6 bonus on all attacks against them
            if (param == "HuntersFocus") {
                if (!player->lr_hunters_focus_available_) { last_action_log_ = current.name + ": Hunter's Focus already used this rest."; return false; }
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    player->lr_hunters_focus_available_ = false;
                    player->hunters_focus_active_ = true;
                    player->hunters_focus_target_id_ = static_cast<int>(std::hash<std::string>{}(t.id) & 0x7FFFFFFF);
                    last_action_log_ = current.name + " focuses on " + t.name + " — +1d6 on all attacks against this target!";
                    return true;
                }
                last_action_log_ = current.name + ": No enemies to focus on.";
                return false;
            }

            // WeirdResilience — Weirkin Human, 0 AP, 1/LR: prime condition reflection (next condition applied to you is reflected to attacker)
            if (param == "WeirdResilience") {
                if (!player->lr_weird_resilience_available_) { last_action_log_ = current.name + ": Weird Resilience already used this rest."; return false; }
                player->lr_weird_resilience_available_ = false;
                player->weird_resilience_primed_ = true;
                last_action_log_ = current.name + " primes Weird Resilience — next condition is reflected back!";
                return true;
            }

            // RotVoice — Rotborn Herald, 3 AP: voice of rot poisons all enemies (1d6 poison + Diseased, VIT DC 12)
            if (param == "RotVoice") {
                int dc = 12 + player->get_stats().divinity;
                int poison_dmg = dice.roll(6);
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(poison_dmg, dice);
                    else if (t.creature_ptr) {
                        t.creature_ptr->take_damage(poison_dmg, dice);
                        if (save < dc) t.creature_ptr->get_status().add_condition(ConditionType::Diseased);
                    }
                    affected++;
                }
                last_action_log_ = current.name + " unleashes Rot Voice — " + std::to_string(poison_dmg) + " poison to " + std::to_string(affected) + " target(s) + Diseased (VIT DC " + std::to_string(dc) + ")!";
                return true;
            }

            // === GLOAMFEN HOLLOW ===
            // VoluntaryGasVent — Huskdrone, 0 AP, 1/LR: release toxic gas cloud (2d6 poison AoE, VIT DC 12 or Poisoned)
            if (param == "VoluntaryGasVent") {
                if (!player->lr_voluntary_gas_vent_available_) { last_action_log_ = current.name + ": Gas Vent already used this rest."; return false; }
                player->lr_voluntary_gas_vent_available_ = false;
                int dc = 12;
                int vent_dmg = dice.roll(6) + dice.roll(6);
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    int dmg = (save >= dc) ? std::max(1, vent_dmg / 2) : vent_dmg;
                    if (t.is_player && t.player_ptr) { t.player_ptr->take_damage(dmg, dice); if (save < dc) t.player_ptr->get_status().add_condition(ConditionType::Poisoned); }
                    else if (t.creature_ptr) { t.creature_ptr->take_damage(dmg, dice); if (save < dc) t.creature_ptr->get_status().add_condition(ConditionType::Poisoned); }
                    affected++;
                }
                last_action_log_ = current.name + " vents toxic gas — " + std::to_string(vent_dmg) + " poison to " + std::to_string(affected) + " target(s) + Poisoned (VIT DC " + std::to_string(dc) + ")!";
                return true;
            }

            // ObedientAuraToggle — Bloatfen Whisperer, 0 AP: toggle aura of compulsion (-3 max AP, enemies make DIV save or can't attack you)
            if (param == "ObedientAuraToggle") {
                player->obedient_aura_active_ = !player->obedient_aura_active_;
                last_action_log_ = current.name + (player->obedient_aura_active_ ? " activates Obedient Aura — enemies must save to attack you! (-3 max AP)" : " deactivates Obedient Aura.");
                return true;
            }

            // MemoryEchoToggle — Hagborn Crone, 0 AP: toggle memory echo (-3 max AP, melee hits replay a past injury on attacker)
            if (param == "MemoryEchoToggle") {
                player->memory_echo_active_ = !player->memory_echo_active_;
                last_action_log_ = current.name + (player->memory_echo_active_ ? " activates Memory Echo — attackers relive past pain! (-3 max AP)" : " deactivates Memory Echo.");
                return true;
            }

            // LeechHex — Hagborn Crone, 0 AP: drain 1d4 HP from nearest enemy (1/turn)
            if (param == "LeechHex") {
                if (player->leech_hex_used_this_turn_) { last_action_log_ = current.name + ": Leech Hex already used this turn."; return false; }
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    player->leech_hex_used_this_turn_ = true;
                    player->leech_hex_last_target_id_ = static_cast<int>(std::hash<std::string>{}(t.id) & 0x7FFFFFFF);
                    int drain = dice.roll(4);
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(drain, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(drain, dice);
                    player->heal(drain);
                    last_action_log_ = current.name + " leeches " + std::to_string(drain) + " HP from " + t.name + "!";
                    return true;
                }
                last_action_log_ = current.name + ": No targets for Leech Hex.";
                return false;
            }

            // WitchsDraught — Hagborn Crone, 3 AP: brew draught of curses (apply Poisoned + Slowed + 2d6, VIT DC 12+DIV)
            if (param == "WitchsDraught") {
                int dc = 12 + player->get_stats().divinity;
                int draught_dmg = dice.roll(6) + dice.roll(6);
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    int dmg = (save >= dc) ? std::max(1, draught_dmg / 2) : draught_dmg;
                    if (t.is_player && t.player_ptr) {
                        t.player_ptr->take_damage(dmg, dice);
                        if (save < dc) { t.player_ptr->get_status().add_condition(ConditionType::Poisoned); t.player_ptr->get_status().add_condition(ConditionType::Slowed); }
                    } else if (t.creature_ptr) {
                        t.creature_ptr->take_damage(dmg, dice);
                        if (save < dc) { t.creature_ptr->get_status().add_condition(ConditionType::Poisoned); t.creature_ptr->get_status().add_condition(ConditionType::Slowed); }
                    }
                    last_action_log_ = current.name + " brews Witch's Draught on " + t.name + " — " + std::to_string(dmg) + " damage" + (save < dc ? ", Poisoned + Slowed!" : " (saved)") + " (VIT DC " + std::to_string(dc) + ")";
                    return true;
                }
                last_action_log_ = current.name + ": No targets for Witch's Draught.";
                return false;
            }

            // HexOfWithering — Hagborn Crone, 2 AP: wither nearest enemy (-1 STR, -1 VIT, 1d8 necrotic; VIT DC 12+DIV)
            if (param == "HexOfWithering") {
                int dc = 12 + player->get_stats().divinity;
                int wither_dmg = dice.roll(8);
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    if (t.is_player && t.player_ptr) {
                        t.player_ptr->take_damage(wither_dmg, dice);
                        if (save < dc) { t.player_ptr->get_stats().strength = std::max(0, t.player_ptr->get_stats().strength - 1); t.player_ptr->get_stats().vitality = std::max(0, t.player_ptr->get_stats().vitality - 1); }
                    } else if (t.creature_ptr) {
                        t.creature_ptr->take_damage(wither_dmg, dice);
                        if (save < dc) { t.creature_ptr->get_stats().strength = std::max(0, t.creature_ptr->get_stats().strength - 1); t.creature_ptr->get_stats().vitality = std::max(0, t.creature_ptr->get_stats().vitality - 1); }
                    }
                    last_action_log_ = current.name + " withers " + t.name + " — " + std::to_string(wither_dmg) + " necrotic" + (save < dc ? ", -1 STR/-1 VIT!" : " (saved)") + " (VIT DC " + std::to_string(dc) + ")";
                    return true;
                }
                last_action_log_ = current.name + ": No targets for Hex of Withering.";
                return false;
            }

            // === THE ASTRAL TEAR ===
            // EtherealStep — Aetherian, 0 AP, 1 SP: become Intangible until end of next turn (as part of move)
            if (param == "EtherealStep") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Need 1 SP for Ethereal Step."; return false; }
                player->current_sp_--;
                player->get_status().add_condition(ConditionType::Intangible);
                player->mist_form_rounds_ = 1; // reuse mist_form_rounds_ timer for single-turn intangibility
                last_action_log_ = current.name + " phases ethereally — Intangible until end of next turn!";
                return true;
            }

            // VeiledPresence — Aetherian, 0 AP, 1/LR: advantage on Sneak for 12 rounds
            if (param == "VeiledPresence") {
                if (!player->lr_veiled_presence_available_) { last_action_log_ = current.name + ": Veiled Presence already used this rest."; return false; }
                player->lr_veiled_presence_available_ = false;
                player->veiled_presence_rounds_ = 12;
                last_action_log_ = current.name + " blurs into Veiled Presence — advantage on Sneak for 12 rounds!";
                return true;
            }

            // ConvergentSynthesis — Convergents, 0 AP, 1 SP: synthesize borrowed traits (Enraged) for 6 rounds
            if (param == "ConvergentSynthesis") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Need 1 SP for Convergent Synthesis."; return false; }
                player->current_sp_--;
                player->convergent_synthesis_active_ = true;
                player->convergent_synthesis_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Enraged);
                last_action_log_ = current.name + " synthesizes borrowed traits — Enraged for 6 rounds!";
                return true;
            }

            // Dreamwalk — Dreamer, 0 AP, 1/LR: lull nearest enemy into dreaming (Calm for 6 rounds)
            if (param == "Dreamwalk") {
                if (!player->lr_dreamwalk_available_) { last_action_log_ = current.name + ": Dreamwalk already used this rest."; return false; }
                player->lr_dreamwalk_available_ = false;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Calm);
                    last_action_log_ = current.name + " enters " + t.name + "'s dreams — Calm for 6 rounds!";
                    return true;
                }
                last_action_log_ = current.name + " dreamwalks but finds no sleeping minds nearby.";
                return true;
            }

            // PhaseStep — Riftborn Human, 3 AP: phase through solid objects (+3 movement tiles)
            if (param == "PhaseStep") {
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += 3;
                last_action_log_ = current.name + " phases through solid matter — +15 ft movement!";
                return true;
            }

            // Flicker — Riftborn Human, 0 AP, 1/SR: teleport burst (+3 movement tiles bonus)
            if (param == "Flicker") {
                if (!player->sr_flicker_available_) { last_action_log_ = current.name + ": Flicker already used this rest."; return false; }
                player->sr_flicker_available_ = false;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += 3;
                last_action_log_ = current.name + " flickers — teleports up to 15 ft!";
                return true;
            }

            // Shadowmeld — Shadewretch, 0 AP, 1/LR reaction: become Intangible until start of next turn
            if (param == "Shadowmeld") {
                if (!player->lr_shadowmeld_available_) { last_action_log_ = current.name + ": Shadowmeld already used this rest."; return false; }
                player->lr_shadowmeld_available_ = false;
                player->get_status().add_condition(ConditionType::Intangible);
                player->mist_form_rounds_ = 1;
                last_action_log_ = current.name + " melds into shadow — Intangible until start of next turn!";
                return true;
            }

            // VoidStep — Umbrawyrm, 0 AP, 1 SP: teleport up to 30 ft to dim light/darkness (+6 movement tiles)
            if (param == "VoidStep") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Need 1 SP for Void Step."; return false; }
                player->current_sp_--;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += 6;
                last_action_log_ = current.name + " void-steps through darkness — teleports up to 30 ft!";
                return true;
            }

            // === L.I.T.O. ===
            // CorruptBreath — Corrupted Wyrmblood, 3 AP: 15 ft necrotic cube (VIT DC 10+VIT, 2d4+level)
            if (param == "CorruptBreath") {
                int dc = 10 + player->get_stats().vitality;
                int breath_dmg = dice.roll(4) + dice.roll(4) + player->get_level();
                int affected = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    int dmg = (save >= dc) ? std::max(1, breath_dmg / 2) : breath_dmg;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    affected++;
                }
                last_action_log_ = current.name + " exhales Corrupt Breath — " + std::to_string(breath_dmg) + " necrotic to " + std::to_string(affected) + " target(s) (VIT DC " + std::to_string(dc) + ")!";
                return true;
            }

            // DarkLineagePulse — Corrupted Wyrmblood, 0 AP, DIV/LR: manual death pulse (1d4 necrotic AoE)
            if (param == "DarkLineagePulse") {
                if (player->lr_dark_lineage_uses_ <= 0) { last_action_log_ = current.name + ": No Dark Lineage uses remaining."; return false; }
                player->lr_dark_lineage_uses_--;
                int pulse = dice.roll(4);
                int hit = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 1) {
                        if (t.is_player && t.player_ptr) t.player_ptr->take_damage(pulse, dice);
                        else if (t.creature_ptr) t.creature_ptr->take_damage(pulse, dice);
                        hit++;
                    }
                }
                last_action_log_ = current.name + " pulses Dark Lineage — " + std::to_string(pulse) + " necrotic to " + std::to_string(hit) + " adjacent creature(s)! (" + std::to_string(player->lr_dark_lineage_uses_) + " uses left)";
                return true;
            }

            // SapHealing — Hollowroot, 0 AP, 1/SR: heal 1d8+level + remove one condition
            if (param == "SapHealing") {
                if (!player->sr_sap_healing_available_) { last_action_log_ = current.name + ": Sap Healing already used this rest."; return false; }
                player->sr_sap_healing_available_ = false;
                int heal_amt = dice.roll(8) + player->get_level();
                player->heal(heal_amt);
                // Remove most debilitating non-permanent condition
                static const ConditionType priority[] = { ConditionType::Stunned, ConditionType::Paralyzed, ConditionType::Poisoned, ConditionType::Blinded, ConditionType::Dazed, ConditionType::Slowed, ConditionType::Fear };
                std::string removed_cond;
                for (auto cond : priority) {
                    if (player->get_status().has_condition(cond)) {
                        player->get_status().remove_condition(cond);
                        removed_cond = StatusManager::get_condition_name(cond);
                        break;
                    }
                }
                last_action_log_ = current.name + " draws on Sap Healing — healed " + std::to_string(heal_amt) + " HP" + (removed_cond.empty() ? "!" : ", removed " + removed_cond + "!");
                return true;
            }

            // EntropyTouch — Nihilian, 0 AP: touch nearest enemy (1d4 necrotic + Dazed)
            if (param == "EntropyTouch") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int touch_dmg = dice.roll(4);
                    if (t.is_player && t.player_ptr) { t.player_ptr->take_damage(touch_dmg, dice); t.player_ptr->get_status().add_condition(ConditionType::Dazed); }
                    else if (t.creature_ptr) { t.creature_ptr->take_damage(touch_dmg, dice); t.creature_ptr->get_status().add_condition(ConditionType::Dazed); }
                    last_action_log_ = current.name + " touches " + t.name + " with Entropy — " + std::to_string(touch_dmg) + " necrotic, Dazed!";
                    return true;
                }
                last_action_log_ = current.name + ": No targets in range for Entropy Touch.";
                return false;
            }

            // Unravel — Nihilian, 0 AP, 1/LR: VIT DC 10+DIV, on fail: 6 bleed stacks + Dazed 6 rounds; half on save
            if (param == "Unravel") {
                if (!player->lr_unravel_available_) { last_action_log_ = current.name + ": Unravel already used this rest."; return false; }
                player->lr_unravel_available_ = false;
                int dc = 10 + player->get_stats().divinity;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    if (save < dc) {
                        int unravel_dmg = dice.roll(6);
                        if (t.is_player && t.player_ptr) { t.player_ptr->take_damage(unravel_dmg, dice); t.player_ptr->get_status().set_bleed_stacks(t.player_ptr->get_status().get_bleed_stacks() + 6); t.player_ptr->get_status().add_condition(ConditionType::Dazed); }
                        else if (t.creature_ptr) { t.creature_ptr->take_damage(unravel_dmg, dice); t.creature_ptr->get_status().set_bleed_stacks(t.creature_ptr->get_status().get_bleed_stacks() + 6); t.creature_ptr->get_status().add_condition(ConditionType::Dazed); }
                        last_action_log_ = current.name + " unravels " + t.name + " — " + std::to_string(unravel_dmg) + " necrotic, +6 Bleed, Dazed! (VIT DC " + std::to_string(dc) + ")";
                    } else {
                        int half_dmg = std::max(1, dice.roll(6) / 2);
                        if (t.is_player && t.player_ptr) t.player_ptr->take_damage(half_dmg, dice);
                        else if (t.creature_ptr) t.creature_ptr->take_damage(half_dmg, dice);
                        last_action_log_ = current.name + " unravels " + t.name + " — " + std::to_string(half_dmg) + " necrotic (saved, half effect).";
                    }
                    return true;
                }
                last_action_log_ = current.name + ": No targets in range for Unravel.";
                return false;
            }

            // MindBleed — Oblivari Human, 0 AP, 1/LR: INT DC 10+DIV on nearest enemy, fail: 2d6 psychic + Confused
            if (param == "MindBleed") {
                if (!player->lr_mind_bleed_available_) { last_action_log_ = current.name + ": Mind Bleed already used this rest."; return false; }
                player->lr_mind_bleed_available_ = false;
                int dc = 10 + player->get_stats().divinity;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().intellect : dice.roll(20);
                    int bleed_dmg = dice.roll(6) + dice.roll(6);
                    if (save < dc) {
                        if (t.is_player && t.player_ptr) { t.player_ptr->take_damage(bleed_dmg, dice); t.player_ptr->get_status().add_condition(ConditionType::Confused); }
                        else if (t.creature_ptr) { t.creature_ptr->take_damage(bleed_dmg, dice); t.creature_ptr->get_status().add_condition(ConditionType::Confused); }
                        last_action_log_ = current.name + " bleeds " + t.name + "'s mind — " + std::to_string(bleed_dmg) + " psychic, Confused! (INT DC " + std::to_string(dc) + ")";
                    } else {
                        last_action_log_ = current.name + " attempts Mind Bleed on " + t.name + " — saved (INT DC " + std::to_string(dc) + ")!";
                    }
                    return true;
                }
                last_action_log_ = current.name + ": No targets in range for Mind Bleed.";
                return false;
            }

            // NullMindShare — Oblivari Human, 0 AP, 1/LR: self becomes Hidden for 6 rounds
            if (param == "NullMindShare") {
                if (!player->lr_null_mind_share_available_) { last_action_log_ = current.name + ": Null Mind Share already used this rest."; return false; }
                player->lr_null_mind_share_available_ = false;
                player->get_status().add_condition(ConditionType::Hidden);
                last_action_log_ = current.name + " activates Null Mind — undetectable to divination for 1 hour, Hidden!";
                return true;
            }

            // AmorphousSplit — Sludgeling, 0 AP, 1/LR: split on next slashing hit (pending dodge + resistance)
            if (param == "AmorphousSplit") {
                if (!player->lr_amorphous_split_available_) { last_action_log_ = current.name + ": Amorphous Split already used this rest."; return false; }
                player->lr_amorphous_split_available_ = false;
                player->get_status().add_condition(ConditionType::Dodging);
                player->pending_damage_reduction_ = player->get_level() + player->get_stats().vitality;
                last_action_log_ = current.name + " splits amorphously — Dodging, next " + std::to_string(player->get_level() + player->get_stats().vitality) + " slashing damage absorbed!";
                return true;
            }

            // ToxicSeep — Sludgeling, 3 AP: 5 ft toxic aura for 6 rounds (VIT save each turn or Poisoned)
            if (param == "ToxicSeep") {
                player->toxic_seep_rounds_ = 6;
                last_action_log_ = current.name + " exudes Toxic Seep — poisonous aura active for 6 rounds!";
                return true;
            }

            // === THE WEST END GULLET ===
            // DeathEaterMemory — Carrionari, 0 AP, 1/LR: absorb memories (advantage on next INT/Intuition checks)
            if (param == "DeathEaterMemory") {
                if (!player->lr_death_eater_memory_available_) { last_action_log_ = current.name + ": Death-Eater's Memory already used this rest."; return false; }
                player->lr_death_eater_memory_available_ = false;
                player->advantage_until_tick_ = 10;
                last_action_log_ = current.name + " absorbs the memory of the fallen — advantage on next checks!";
                return true;
            }

            // WingsOfForgotten — Carrionari, 3 AP: fly at foot speed for 1 round
            if (param == "WingsOfForgotten") {
                player->get_status().add_condition(ConditionType::Flying);
                player->carrionari_flight_rounds_ = 1;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += self_comb->get_movement_speed() / 5;
                last_action_log_ = current.name + " spreads wings — Flying this round!";
                return true;
            }

            // ShiftingFormToggle — Disjointed Hounds, 0 AP: toggle beast form (+10 ft movement while active)
            if (param == "ShiftingFormToggle") {
                player->disjointed_beast_form_active_ = !player->disjointed_beast_form_active_;
                auto* self_comb = find_combatant_by_id(current.id);
                if (player->disjointed_beast_form_active_ && self_comb) self_comb->movement_tiles_remaining += 2;
                last_action_log_ = current.name + (player->disjointed_beast_form_active_ ? " shifts to Beast Form — +10 ft movement!" : " shifts back to Humanoid Form.");
                return true;
            }

            // DisjointedLeap — Disjointed Hounds, 0 AP, 1/SR: leap 40 ft ignoring obstacles (+8 movement tiles)
            if (param == "DisjointedLeap") {
                if (!player->sr_disjointed_leap_available_) { last_action_log_ = current.name + ": Disjointed Leap already used this rest."; return false; }
                player->sr_disjointed_leap_available_ = false;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += 8;
                last_action_log_ = current.name + " lunges with Disjointed Leap — +40 ft movement, ignores obstacles!";
                return true;
            }

            // TemporalFlicker — Lost, 0 AP, 1/LR: become Intangible for 12 rounds
            if (param == "TemporalFlicker") {
                if (!player->lr_temporal_flicker_available_) { last_action_log_ = current.name + ": Temporal Flicker already used this rest."; return false; }
                player->lr_temporal_flicker_available_ = false;
                player->temporal_flicker_rounds_ = 12;
                player->get_status().add_condition(ConditionType::Intangible);
                last_action_log_ = current.name + " flickers out of time — Intangible for 12 rounds!";
                return true;
            }

            // HauntingWail — Lost, 3 AP: dissonant cry; INT save or Stunned until end of next turn (15 ft AoE)
            if (param == "HauntingWail") {
                int dc = 10 + player->get_stats().divinity;
                int stunned_count = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().intellect : dice.roll(20);
                    if (save < dc) {
                        if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Stunned);
                        stunned_count++;
                    }
                }
                last_action_log_ = current.name + " unleashes Haunting Wail — " + std::to_string(stunned_count) + " target(s) Stunned! (INT DC " + std::to_string(dc) + ")";
                return true;
            }

            // MirrorMove — Gullet Mimes, 3 AP: copy nearest attack (deal 1d8+STR force damage)
            if (param == "MirrorMove") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int mirror_dmg = dice.roll(8) + player->get_stats().strength;
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(mirror_dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(mirror_dmg, dice);
                    last_action_log_ = current.name + " mirrors an attack — " + std::to_string(mirror_dmg) + " force damage to " + t.name + "!";
                    return true;
                }
                last_action_log_ = current.name + ": No targets for Mirror Move.";
                return false;
            }

            // SilentScream — Gullet Mimes, 0 AP, 1/LR: INT DC 10+DIV or Silent + Dazed for 6 rounds
            if (param == "SilentScream") {
                if (!player->lr_silent_scream_available_) { last_action_log_ = current.name + ": Silent Scream already used this rest."; return false; }
                player->lr_silent_scream_available_ = false;
                int dc = 10 + player->get_stats().divinity;
                int silenced = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().intellect : dice.roll(20);
                    if (save < dc) {
                        if (t.creature_ptr) { t.creature_ptr->get_status().add_condition(ConditionType::Silent); t.creature_ptr->get_status().add_condition(ConditionType::Dazed); }
                        silenced++;
                    }
                }
                last_action_log_ = current.name + " unleashes Silent Scream — " + std::to_string(silenced) + " target(s) Silenced + Dazed! (INT DC " + std::to_string(dc) + ")";
                return true;
            }

            // RealitySlip — Parallax Watchers, 0 AP, 1/SR: teleport 30 ft to shadow (+6 movement tiles)
            if (param == "RealitySlip") {
                if (!player->sr_reality_slip_available_) { last_action_log_ = current.name + ": Reality Slip already used this rest."; return false; }
                player->sr_reality_slip_available_ = false;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += 6;
                last_action_log_ = current.name + " slips through reality — teleports up to 30 ft!";
                return true;
            }

            // UnnervinGaze — Parallax Watchers, 3 AP: INT save or Fear for 6 rounds (30 ft range)
            if (param == "UnnervinGaze") {
                int dc = 10 + player->get_stats().divinity;
                int feared = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().intellect : dice.roll(20);
                    if (save < dc) {
                        if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Fear);
                        feared++;
                    }
                }
                last_action_log_ = current.name + " fixes an Unnerving Gaze — " + std::to_string(feared) + " target(s) Feared! (INT DC " + std::to_string(dc) + ")";
                return true;
            }

            // === THE CRADLING DEPTHS ===
            // ResonantFormMimic — Echo-Touched, 0 AP, 1/SR: gain advantage on all checks for 3 rounds
            if (param == "ResonantFormMimic") {
                if (!player->sr_resonant_form_available_) { last_action_log_ = current.name + ": Resonant Form already used this rest."; return false; }
                player->sr_resonant_form_available_ = false;
                player->advantage_until_tick_ = 3;
                last_action_log_ = current.name + " resonates with divine energy — advantage on all checks for 3 rounds!";
                return true;
            }

            // DivineMimicry — Echo-Touched, 0 AP, 1/LR: tap nearest creature's divine spark (gain advantage for rest)
            if (param == "DivineMimicry") {
                if (!player->lr_divine_mimicry_available_) { last_action_log_ = current.name + ": Divine Mimicry already used this rest."; return false; }
                player->lr_divine_mimicry_available_ = false;
                for (auto& t : combatants_) {
                    if (t.id == current.id || t.get_current_hp() <= 0) continue;
                    player->advantage_until_tick_ = 50;
                    last_action_log_ = current.name + " mimics " + t.name + "'s divine spark — lineage trait advantage until next LR!";
                    return true;
                }
                last_action_log_ = current.name + " finds no divine spark nearby.";
                return true;
            }

            // VitalSurge — Lifeborne, 0 AP: heal self or ally from surge pool (1d6+DIV per use)
            if (param == "VitalSurge") {
                int heal_amt = dice.roll(6) + player->get_stats().divinity;
                if (player->vital_surge_pool_ <= 0) { last_action_log_ = current.name + ": Vital Surge pool is empty."; return false; }
                int actual_heal = std::min(heal_amt, player->vital_surge_pool_);
                player->vital_surge_pool_ -= actual_heal;
                player->heal(actual_heal);
                last_action_log_ = current.name + " surges vital energy — healed " + std::to_string(actual_heal) + " HP! (" + std::to_string(player->vital_surge_pool_) + " pool remaining)";
                return true;
            }

            // AbyssalGlow — Lifeborne, 3 AP, 1/LR: radiant glow heals all allies 1d6+DIV, enemies DIV save vs disadvantage
            if (param == "AbyssalGlow") {
                if (!player->lr_abyssal_glow_available_) { last_action_log_ = current.name + ": Abyssal Glow already used this rest."; return false; }
                player->lr_abyssal_glow_available_ = false;
                int dc = 10 + player->get_stats().divinity;
                int glow_heal = dice.roll(6) + player->get_stats().divinity;
                int healed = 0, dazzled = 0;
                for (auto& t : combatants_) {
                    if (t.get_current_hp() <= 0) continue;
                    if (t.is_player == current.is_player) {
                        if (t.is_player && t.player_ptr) { t.player_ptr->heal(glow_heal); healed++; }
                    } else {
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().divinity : dice.roll(20);
                        if (save < dc && t.creature_ptr) { t.creature_ptr->get_status().add_condition(ConditionType::Blinded); dazzled++; }
                    }
                }
                last_action_log_ = current.name + " radiates Abyssal Glow — healed " + std::to_string(healed) + " allies for " + std::to_string(glow_heal) + " HP, " + std::to_string(dazzled) + " enemies dazzled!";
                return true;
            }

            // ===== TERMINUS VOLARUS =====

            // LanternbornGlowToggle — Lanternborn, 0 AP: toggle bioluminescent glow
            if (param == "LanternbornGlowToggle") {
                player->lanternborn_glow_active_ = !player->lanternborn_glow_active_;
                last_action_log_ = current.name + (player->lanternborn_glow_active_ ? " lights up — Glow active! (Allies +1 AC; all have disadvantage on Sneak)" : " dims — Glow deactivated.");
                return true;
            }

            // GuidingLight — Lanternborn, 3 AP: grant ally within 30ft advantage on a saving throw
            if (param == "GuidingLight") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player && t.id != current.id && t.get_current_hp() > 0) {
                        if (t.player_ptr) t.player_ptr->advantage_until_tick_ = 1;
                        last_action_log_ = current.name + " grants Guiding Light to " + t.name + " — advantage on next save!";
                        return true;
                    }
                }
                last_action_log_ = current.name + ": No ally to guide.";
                return false;
            }

            // BeaconAbsorb — Luminar Human, 0 AP, 1/SR: absorb Fear from ally, self becomes Frightened but gets all-damage resistance
            if (param == "BeaconAbsorb") {
                if (!player->sr_beacon_available_) { last_action_log_ = current.name + ": Beacon already used this rest."; return false; }
                player->sr_beacon_available_ = false;
                bool absorbed = false;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player && t.id != current.id && t.player_ptr && t.get_current_hp() > 0) {
                        if (t.player_ptr->get_status().has_condition(ConditionType::Fear)) {
                            t.player_ptr->get_status().remove_condition(ConditionType::Fear);
                            player->get_status().add_condition(ConditionType::Fear);
                            player->beacon_resistance_rounds_ = 2;
                            last_action_log_ = current.name + " absorbs " + t.name + "'s Fear via Beacon — now Frightened but gains damage resistance for 1 round!";
                            absorbed = true;
                            break;
                        }
                    }
                }
                if (!absorbed) {
                    player->beacon_resistance_rounds_ = 2;
                    last_action_log_ = current.name + " activates Beacon — resistance to all damage for 1 round!";
                }
                return true;
            }

            // KeenSightFocus — Skysworn, 3 AP: automatically detect invisible/illusory creature within 30ft for 1 round
            if (param == "KeenSightFocus") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (t.creature_ptr) {
                        t.creature_ptr->get_status().remove_condition(ConditionType::Invisible);
                        t.creature_ptr->get_status().remove_condition(ConditionType::Hidden);
                    }
                }
                last_action_log_ = current.name + " focuses Keen Sight — all hidden/invisible enemies revealed for 1 round!";
                return true;
            }

            // RadiantPulse — Starborn, 3 AP: AoE burst, all within 10ft make VIT save or Blinded until end of next turn
            if (param == "RadiantPulse") {
                int dc = 10 + player->get_stats().vitality;
                int blinded_count = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 2) {
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                        if (save < dc) {
                            if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Blinded);
                            blinded_count++;
                        }
                    }
                }
                last_action_log_ = current.name + " emits a Radiant Pulse — " + std::to_string(blinded_count) + " enemies blinded (DC " + std::to_string(dc) + ")!";
                return true;
            }

            // ===== THE CITY OF ETERNAL LIGHT =====

            // LightStepTeleport — Auroran, 0 AP, 1/SR: teleport up to 10ft to a lit space
            if (param == "LightStepTeleport") {
                if (!player->sr_light_step_available_) { last_action_log_ = current.name + ": Light Step already used this rest."; return false; }
                player->sr_light_step_available_ = false;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += 2;
                last_action_log_ = current.name + " takes a Light Step — +10ft movement (teleport to light)!";
                return true;
            }

            // DawnsBlessingActivate — Auroran, 0 AP, 1/LR: become immune to Blinded for 6 rounds
            if (param == "DawnsBlessingActivate") {
                if (!player->lr_dawns_blessing_available_) { last_action_log_ = current.name + ": Dawn's Blessing already used this rest."; return false; }
                player->lr_dawns_blessing_available_ = false;
                player->dawns_blessing_rounds_ = 6;
                player->get_status().remove_condition(ConditionType::Blinded);
                last_action_log_ = current.name + " invokes Dawn's Blessing — immune to Blinded for 6 rounds!";
                return true;
            }

            // RadiantWard — Lightbound, 0 AP, 1/SR: grant radiant resistance for 6 rounds + heal 1d6
            if (param == "RadiantWard") {
                if (!player->sr_radiant_ward_available_) { last_action_log_ = current.name + ": Radiant Ward already used this rest."; return false; }
                player->sr_radiant_ward_available_ = false;
                player->radiant_ward_rounds_ = 6;
                int ward_heal = dice.roll(6);
                player->heal(ward_heal);
                last_action_log_ = current.name + " activates Radiant Ward — healed " + std::to_string(ward_heal) + " HP, radiant resistance for 6 rounds!";
                return true;
            }

            // Flareburst — Lightbound, 0 AP, 1/SR: prime next melee hit for +2d6 fire and Blinded
            if (param == "Flareburst") {
                if (!player->sr_flareburst_available_) { last_action_log_ = current.name + ": Flareburst already used this rest."; return false; }
                player->sr_flareburst_available_ = false;
                player->flareburst_primed_ = true;
                last_action_log_ = current.name + " primes Flareburst — next melee hit deals +2d6 fire and blinds the target!";
                return true;
            }

            // RunicSurgePrime — Runeborn Human, 0 AP, 1/LR: prime +1d4 bonus to next spell attack/DC
            if (param == "RunicSurgePrime") {
                if (!player->lr_runic_surge_available_) { last_action_log_ = current.name + ": Runic Surge already used this rest."; return false; }
                player->lr_runic_surge_available_ = false;
                player->runic_surge_primed_ = true;
                last_action_log_ = current.name + " channels Runic Surge — next spell gets +1d4 to attack/DC!";
                return true;
            }

            // MysticPulse — Runeborn Human, 0 AP, 1/SR: grant bonus HP = INT to all allies within 10ft
            if (param == "MysticPulse") {
                if (!player->sr_mystic_pulse_available_) { last_action_log_ = current.name + ": Mystic Pulse already used this rest."; return false; }
                player->sr_mystic_pulse_available_ = false;
                int bonus_hp = player->get_stats().intellect;
                int healed = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player && t.get_current_hp() > 0) {
                        if (DungeonManager::instance().get_distance(current.id, t.id) <= 2) {
                            if (t.player_ptr) { t.player_ptr->heal(bonus_hp); healed++; }
                        }
                    }
                }
                last_action_log_ = current.name + " emits a Mystic Pulse — " + std::to_string(healed) + " allies gain " + std::to_string(bonus_hp) + " HP!";
                return true;
            }

            // Windstep — Zephyrkin, 0 AP, SPD/SR: move full speed as free action + immunity to opportunity attacks this turn
            if (param == "Windstep") {
                if (player->sr_windstep_uses_ <= 0) { last_action_log_ = current.name + ": No Windstep uses remaining."; return false; }
                player->sr_windstep_uses_--;
                auto* self_comb = find_combatant_by_id(current.id);
                if (self_comb) self_comb->movement_tiles_remaining += player->get_movement_speed() / 5;
                last_action_log_ = current.name + " Windsteps — full speed movement, immune to opportunity attacks! (" + std::to_string(player->sr_windstep_uses_) + " uses left)";
                return true;
            }

            // ===== THE HALLOWED SACRAMENT =====

            // GlimmerfolkGlowToggle — Glimmerfolk, 0 AP: toggle iridescent glow
            if (param == "GlimmerfolkGlowToggle") {
                player->glimmerfolk_glow_active_ = !player->glimmerfolk_glow_active_;
                last_action_log_ = current.name + (player->glimmerfolk_glow_active_ ? " glows — Luminous active! (Allies +1 to attack rolls in light)" : " dims — Luminous deactivated.");
                return true;
            }

            // Dazzle — Glimmerfolk, 0 AP, 1 SP: force adjacent creature to save vs Blinded
            if (param == "Dazzle") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Dazzle."; return false; }
                player->current_sp_--;
                int dc = 10 + player->get_stats().vitality;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 1) {
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                        if (save < dc) {
                            if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Blinded);
                            last_action_log_ = current.name + " Dazzles " + t.name + " — Blinded! (DC " + std::to_string(dc) + ", rolled " + std::to_string(save) + ")";
                        } else {
                            last_action_log_ = current.name + " Dazzles " + t.name + " — resisted! (DC " + std::to_string(dc) + ", rolled " + std::to_string(save) + ")";
                        }
                        return true;
                    }
                }
                last_action_log_ = current.name + ": No adjacent target for Dazzle.";
                return false;
            }

            // VaporFormActivate — Mistborn Human, 0 AP, 1 SP: Intangible for 1 turn
            if (param == "VaporFormActivate") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Vapor Form."; return false; }
                player->current_sp_--;
                player->get_status().add_condition(ConditionType::Intangible);
                player->mist_form_rounds_ = 1;
                last_action_log_ = current.name + " shifts to Vapor Form — Intangible until next turn!";
                return true;
            }

            // DriftingFog — Mistborn Human, 0 AP, 1/LR: create fog for 6 rounds (enemies have disadvantage on attacks against you)
            if (param == "DriftingFog") {
                if (!player->lr_drifting_fog_available_) { last_action_log_ = current.name + ": Drifting Fog already used this rest."; return false; }
                player->lr_drifting_fog_available_ = false;
                player->drifting_fog_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Dodging);
                last_action_log_ = current.name + " exhales Drifting Fog — enemies have disadvantage attacking you for 6 rounds!";
                return true;
            }

            // SporeBloom — Mossling, 3 AP, 1/LR: calm spores in 10ft radius, VIT save or Dazed for 1 minute
            if (param == "SporeBloom") {
                if (!player->lr_spore_bloom_available_) { last_action_log_ = current.name + ": Spore Bloom already used this rest."; return false; }
                player->lr_spore_bloom_available_ = false;
                int dc = 10 + player->get_stats().vitality;
                int dazed_count = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 2) {
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                        if (save < dc) {
                            if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                            dazed_count++;
                        }
                    }
                }
                last_action_log_ = current.name + " releases Spore Bloom — " + std::to_string(dazed_count) + " enemies Dazed (DC " + std::to_string(dc) + ")!";
                return true;
            }

            // WindswiftActivate — Zephyrite, 0 AP, 1 SP: hover up to 30ft for 6 rounds (+1 AC, advantage on Speed saves)
            if (param == "WindswiftActivate") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Windswift."; return false; }
                player->current_sp_--;
                player->windswift_active_ = true;
                player->windswift_rounds_ = 6;
                player->get_status().add_condition(ConditionType::Flying);
                last_action_log_ = current.name + " activates Windswift — Flying for 6 rounds! (+1 AC, advantage on Speed saves)";
                return true;
            }

            // ===== THE LAND OF TOMORROW =====

            // TemporalShift — Chronogears, 0 AP, 1/SR: prime to halve next incoming damage
            if (param == "TemporalShift") {
                if (!player->sr_temporal_shift_available_) { last_action_log_ = current.name + ": Temporal Shift already used this rest."; return false; }
                player->sr_temporal_shift_available_ = false;
                player->temporal_shift_primed_ = true;
                last_action_log_ = current.name + " engages Temporal Shift — next incoming hit will be halved!";
                return true;
            }

            // ArcanePulse — Silverblood, 3 AP, 1/LR: AoE Dazed in 10ft (DIV save DC 10+DIV)
            if (param == "ArcanePulse") {
                if (!player->lr_arcane_pulse_available_) { last_action_log_ = current.name + ": Arcane Pulse already used this rest."; return false; }
                player->lr_arcane_pulse_available_ = false;
                int dc = 10 + player->get_stats().divinity;
                int dazed_count = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 2) {
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().divinity : dice.roll(20);
                        if (save < dc) {
                            if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                            dazed_count++;
                        }
                    }
                }
                last_action_log_ = current.name + " releases an Arcane Pulse — " + std::to_string(dazed_count) + " enemies Dazed (DC " + std::to_string(dc) + ")!";
                return true;
            }

            // RunicFlowAuto — Silverblood, 0 AP, 1/LR: auto-succeed on next Arcane check
            if (param == "RunicFlowAuto") {
                if (!player->lr_runic_flow_auto_available_) { last_action_log_ = current.name + ": Runic Flow auto-succeed already used this rest."; return false; }
                player->lr_runic_flow_auto_available_ = false;
                player->runic_flow_auto_primed_ = true;
                last_action_log_ = current.name + " channels Runic Flow — next Arcane check automatically succeeds!";
                return true;
            }

            // SparkforgedArcaneSurge — Sparkforged Human, 0 AP, 1/LR: prime +2 to next spell attack/DC
            if (param == "SparkforgedArcaneSurge") {
                if (!player->lr_sparkforged_arcane_surge_available_) { last_action_log_ = current.name + ": Arcane Surge already used this rest."; return false; }
                player->lr_sparkforged_arcane_surge_available_ = false;
                player->sparkforged_arcane_surge_primed_ = true;
                last_action_log_ = current.name + " surges arcane power — next spell gets +2 to attack/DC!";
                return true;
            }

            // StaticSurge — Watchling, 0 AP: all actions cost 0 AP this turn; penalty at start of next turn
            if (param == "StaticSurge") {
                player->static_surge_active_ = true;
                player->static_surge_action_count_ = 0;
                last_action_log_ = current.name + " overloads circuits — all actions cost 0 AP this turn! (Penalty: Dazed + 1d4 per action next turn)";
                return true;
            }

            // ===== SUBLIMINI DOMINUS =====

            // EchoReflection — Echoform Warden, 3 AP: force caster INT save DC 10+DIV or spell suppressed
            if (param == "EchoReflection") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int dc = 10 + player->get_stats().divinity;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().intellect : dice.roll(20);
                    if (save < dc) {
                        if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Silent);
                        last_action_log_ = current.name + " reflects Echo at " + t.name + " — spell suppressed! (INT save " + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                    } else {
                        last_action_log_ = current.name + " attempts Echo Reflection on " + t.name + " — resisted! (" + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                    }
                    return true;
                }
                last_action_log_ = current.name + ": No target for Echo Reflection.";
                return false;
            }

            // MemoryTap — Echoform Warden, 0 AP, 1 SP: touch creature, DC 14 DIV save or reveal memory (Confused)
            if (param == "MemoryTap") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Memory Tap."; return false; }
                player->current_sp_--;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 1) {
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().divinity : dice.roll(20);
                        if (save < 14) {
                            if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Confused);
                            last_action_log_ = current.name + " taps " + t.name + "'s memory — Confused from revealed trauma! (DIV " + std::to_string(save) + " vs DC 14)";
                        } else {
                            last_action_log_ = current.name + " attempts Memory Tap on " + t.name + " — resisted! (" + std::to_string(save) + " vs DC 14)";
                        }
                        return true;
                    }
                }
                last_action_log_ = current.name + ": No adjacent target for Memory Tap.";
                return false;
            }

            // VoidCloakToggle — Nullborn Ascetic, 0 AP: toggle void cloak (immune to magical detection; -3 max AP)
            if (param == "VoidCloakToggle") {
                player->void_cloak_active_ = !player->void_cloak_active_;
                last_action_log_ = current.name + (player->void_cloak_active_ ? " shrouds in Void Cloak — immune to magical detection! (-3 max AP; extends 15ft to allies)" : " drops Void Cloak.");
                return true;
            }

            // SpellSink — Nullborn Ascetic, 3 AP: absorb magical residue, gain 1 SP
            if (param == "SpellSink") {
                player->restore_sp(1);
                last_action_log_ = current.name + " activates Spell Sink — absorbed residual magic for 1 SP!";
                return true;
            }

            // WarpResistanceToggle — Mistborne Hatchling, 0 AP: toggle warp resistance aura (-3 max AP)
            if (param == "WarpResistanceToggle") {
                player->warp_resistance_active_ = !player->warp_resistance_active_;
                last_action_log_ = current.name + (player->warp_resistance_active_ ? " activates Warp Resistance — resistance to magical terrain effects! (-3 max AP; extends 15ft to allies)" : " deactivates Warp Resistance.");
                return true;
            }

            // SurgePulse — Mistborne Hatchling, 3 AP, 1 SP: mist burst 10ft, VIT save DC 10+DIV or Slowed
            if (param == "SurgePulse") {
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Surge Pulse."; return false; }
                player->current_sp_--;
                int dc = 10 + player->get_stats().divinity;
                int slowed_count = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 2) {
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                        if (save < dc) {
                            if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Slowed);
                            slowed_count++;
                        }
                    }
                }
                last_action_log_ = current.name + " releases a Surge Pulse — " + std::to_string(slowed_count) + " enemies Slowed (DC " + std::to_string(dc) + ")!";
                return true;
            }

            // ===== BEATING HEART OF THE VOID =====

            // ParalyzingRay — Bespoker, 2 AP: VIT save or Paralyzed 1 round (can't repeat consecutive ray)
            if (param == "ParalyzingRay") {
                if (player->bespoker_last_ray_name_ == "ParalyzingRay") { last_action_log_ = current.name + ": Cannot use the same ray twice in a row!"; return false; }
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int dc = 10 + player->get_stats().divinity;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                    if (save < dc) {
                        if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Paralyzed);
                        last_action_log_ = current.name + " fires Paralyzing Ray at " + t.name + " — Paralyzed! (VIT " + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                    } else {
                        last_action_log_ = current.name + " fires Paralyzing Ray at " + t.name + " — resisted!";
                    }
                    player->bespoker_last_ray_name_ = "ParalyzingRay";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Paralyzing Ray.";
                return false;
            }

            // FearRay — Bespoker, 2 AP: DIV save or Frightened 2 rounds
            if (param == "FearRay") {
                if (player->bespoker_last_ray_name_ == "FearRay") { last_action_log_ = current.name + ": Cannot use the same ray twice in a row!"; return false; }
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int dc = 10 + player->get_stats().divinity;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().divinity : dice.roll(20);
                    if (save < dc) {
                        if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Fear);
                        last_action_log_ = current.name + " fires Fear Ray at " + t.name + " — Frightened! (DIV " + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                    } else {
                        last_action_log_ = current.name + " fires Fear Ray at " + t.name + " — resisted!";
                    }
                    player->bespoker_last_ray_name_ = "FearRay";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Fear Ray.";
                return false;
            }

            // HealingRay — Bespoker, 2 AP: target ally or self regains 2d6 HP
            if (param == "HealingRay") {
                if (player->bespoker_last_ray_name_ == "HealingRay") { last_action_log_ = current.name + ": Cannot use the same ray twice in a row!"; return false; }
                int heal_amt = dice.roll(6) + dice.roll(6);
                player->heal(heal_amt);
                player->bespoker_last_ray_name_ = "HealingRay";
                last_action_log_ = current.name + " fires Healing Ray — healed " + std::to_string(heal_amt) + " HP!";
                return true;
            }

            // NecroticRay — Bespoker, 1 AP: deal 2d6 necrotic to target
            if (param == "NecroticRay") {
                if (player->bespoker_last_ray_name_ == "NecroticRay") { last_action_log_ = current.name + ": Cannot use the same ray twice in a row!"; return false; }
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int dmg = dice.roll(6) + dice.roll(6);
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    player->bespoker_last_ray_name_ = "NecroticRay";
                    last_action_log_ = current.name + " fires Necrotic Ray at " + t.name + " — " + std::to_string(dmg) + " necrotic damage!";
                    return true;
                }
                last_action_log_ = current.name + ": No target for Necrotic Ray.";
                return false;
            }

            // DisintegrationRay — Bespoker, 3 AP: DIV save DC 10+DIV or (level)d10 force, no damage on save
            if (param == "DisintegrationRay") {
                if (player->bespoker_last_ray_name_ == "DisintegrationRay") { last_action_log_ = current.name + ": Cannot use the same ray twice in a row!"; return false; }
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int dc = 10 + player->get_stats().divinity;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().divinity : dice.roll(20);
                    player->bespoker_last_ray_name_ = "DisintegrationRay";
                    if (save < dc) {
                        int dmg = 0;
                        for (int i = 0; i < player->get_level(); i++) dmg += dice.roll(10);
                        if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                        else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                        last_action_log_ = current.name + " fires Disintegration Ray at " + t.name + " — " + std::to_string(dmg) + " force damage! (DIV " + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                    } else {
                        last_action_log_ = current.name + " fires Disintegration Ray at " + t.name + " — saved! (no damage)";
                    }
                    return true;
                }
                last_action_log_ = current.name + ": No target for Disintegration Ray.";
                return false;
            }

            // AntiMagicConeToggle — Bespoker, 0 AP: toggle anti-magic cone (-3 max AP; suppresses spells in 30ft cone)
            if (param == "AntiMagicConeToggle") {
                player->anti_magic_cone_active_ = !player->anti_magic_cone_active_;
                last_action_log_ = current.name + (player->anti_magic_cone_active_ ? " activates Anti-Magic Cone — suppresses spells (SP ≤ level) within 30ft! (-3 max AP)" : " deactivates Anti-Magic Cone.");
                return true;
            }

            // NeuralLiquefaction — Brain Eater, 2 AP: DC 10+DIV VIT save or 2d6 psychic + lose 1 SP
            if (param == "NeuralLiquefaction") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 1) {
                        int dc = 10 + player->get_stats().divinity;
                        int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().vitality : dice.roll(20);
                        if (save < dc) {
                            int dmg = dice.roll(6) + dice.roll(6);
                            if (t.is_player && t.player_ptr) { t.player_ptr->take_damage(dmg, dice); t.player_ptr->current_sp_ = std::max(0, t.player_ptr->current_sp_ - 1); }
                            else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                            last_action_log_ = current.name + " liquefies " + t.name + "'s neural matter — " + std::to_string(dmg) + " psychic damage, -1 SP!";
                        } else {
                            last_action_log_ = current.name + " attempts Neural Liquefaction on " + t.name + " — resisted!";
                        }
                        return true;
                    }
                }
                last_action_log_ = current.name + ": No adjacent target for Neural Liquefaction.";
                return false;
            }

            // SkullDrill — Brain Eater, 3 AP: target must be stunned or restrained; 2d6 + heal 2d6
            if (param == "SkullDrill") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    if (DungeonManager::instance().get_distance(current.id, t.id) <= 1) {
                        bool vulnerable = false;
                        if (t.is_player && t.player_ptr) vulnerable = t.player_ptr->get_status().has_condition(ConditionType::Stunned) || t.player_ptr->get_status().has_condition(ConditionType::Restrained);
                        else if (t.creature_ptr) vulnerable = t.creature_ptr->get_status().has_condition(ConditionType::Stunned) || t.creature_ptr->get_status().has_condition(ConditionType::Restrained);
                        if (!vulnerable) { last_action_log_ = current.name + ": Skull Drill requires target to be Stunned or Restrained!"; return false; }
                        int dmg = dice.roll(6) + dice.roll(6);
                        int heal_amt = dice.roll(6) + dice.roll(6);
                        if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                        else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                        player->heal(heal_amt);
                        last_action_log_ = current.name + " drills into " + t.name + "'s skull — " + std::to_string(dmg) + " damage, healed " + std::to_string(heal_amt) + " HP!";
                        return true;
                    }
                }
                last_action_log_ = current.name + ": No adjacent target for Skull Drill.";
                return false;
            }

            // ResonantSermonToggle — Pulsebound Hierophant, 0 AP: toggle sermon aura (-3 max AP; allies +1 saves, enemies save vs disadvantage)
            if (param == "ResonantSermonToggle") {
                player->resonant_sermon_active_ = !player->resonant_sermon_active_;
                last_action_log_ = current.name + (player->resonant_sermon_active_ ? " begins Resonant Sermon — allies +1 to saves/checks, enemies must save vs spell disadvantage! (-3 max AP)" : " ends Resonant Sermon.");
                return true;
            }

            // VoidCommunion — Pulsebound Hierophant, 0 AP, 1/LR: grant nearby allies 1d4+DIV SP
            if (param == "VoidCommunion") {
                if (!player->lr_void_communion_available_) { last_action_log_ = current.name + ": Void Communion already used this rest."; return false; }
                player->lr_void_communion_available_ = false;
                int sp_grant = dice.roll(4) + player->get_stats().divinity;
                int healed = 0;
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player && t.get_current_hp() > 0 && t.player_ptr) {
                        t.player_ptr->restore_sp(sp_grant);
                        healed++;
                    }
                }
                last_action_log_ = current.name + " performs Void Communion — " + std::to_string(healed) + " allies gain " + std::to_string(sp_grant) + " SP!";
                return true;
            }

            // ThrenodySlamAttack — Threnody Warden, 3 AP: 3d6 force + DIV save or Silent 1 round
            if (param == "ThrenodySlamAttack") {
                for (auto& t : combatants_) {
                    if (t.is_player == current.is_player || t.get_current_hp() <= 0) continue;
                    int dmg = dice.roll(6) + dice.roll(6) + dice.roll(6);
                    if (t.is_player && t.player_ptr) t.player_ptr->take_damage(dmg, dice);
                    else if (t.creature_ptr) t.creature_ptr->take_damage(dmg, dice);
                    int dc = 10 + player->get_stats().divinity;
                    int save = t.creature_ptr ? dice.roll(20) + t.creature_ptr->get_stats().divinity : dice.roll(20);
                    if (save < dc) {
                        if (t.creature_ptr) t.creature_ptr->get_status().add_condition(ConditionType::Silent);
                        else if (t.is_player && t.player_ptr) t.player_ptr->get_status().add_condition(ConditionType::Silent);
                        last_action_log_ = current.name + " slams " + t.name + " — " + std::to_string(dmg) + " force damage, Silenced!";
                    } else {
                        last_action_log_ = current.name + " slams " + t.name + " — " + std::to_string(dmg) + " force damage!";
                    }
                    return true;
                }
                last_action_log_ = current.name + ": No target for Threnody Slam.";
                return false;
            }

            // ===== Stat Feat Active Actions =====

            // ArcaneWellspring T1: Deep Reserves — halve SP cost of next spell (once/LR)
            if (param == "DeepReserves") {
                if (!player->aw_deep_reserves_lr_available_) { last_action_log_ = current.name + ": Deep Reserves already used (LR)."; return false; }
                player->aw_deep_reserves_lr_available_ = false;
                player->aw_deep_reserves_armed_ = true;
                last_action_log_ = current.name + " arms Deep Reserves — next spell costs half SP!";
                return true;
            }
            // ArcaneWellspring T3: Spell Echo — echo next spell cast at start of next turn (once/enc)
            if (param == "SpellEchoArm") {
                if (!player->aw_spell_echo_enc_available_) { last_action_log_ = current.name + ": Spell Echo already used this encounter."; return false; }
                player->aw_spell_echo_enc_available_ = false;
                player->aw_spell_echo_armed_ = true;
                last_action_log_ = current.name + " arms Spell Echo — next spell will echo on their next turn!";
                return true;
            }
            // ArcaneWellspring T5: Infinite Font — next spell costs 0 SP (once/LR)
            if (param == "InfiniteFont") {
                if (!player->aw_infinite_font_lr_available_) { last_action_log_ = current.name + ": Infinite Font already used (LR)."; return false; }
                player->aw_infinite_font_lr_available_ = false;
                player->aw_infinite_font_armed_ = true;
                last_action_log_ = current.name + " arms Infinite Font — next spell costs 0 SP!";
                return true;
            }
            // MartialFocus T1: Battle-Ready — arm flag to reduce next attack AP cost by 1 (once/enc)
            if (param == "BattleReady") {
                if (!player->mf_battle_ready_enc_available_) { last_action_log_ = current.name + ": Battle-Ready already used this encounter."; return false; }
                player->mf_battle_ready_enc_available_ = false;
                player->mf_battle_ready_armed_ = true;
                last_action_log_ = current.name + " is Battle-Ready — next attack costs 1 less AP!";
                return true;
            }
            // IronVitality T3: Enduring Spirit secondary — heal = level (once/LR, free action)
            if (param == "EnduringHeal") {
                if (!player->iv_enduring_spirit_lr_available_) { last_action_log_ = current.name + ": Enduring Heal already used (LR)."; return false; }
                player->iv_enduring_spirit_lr_available_ = false;
                int heal_amt = player->get_level();
                player->heal(heal_amt);
                last_action_log_ = current.name + " recovers " + std::to_string(heal_amt) + " HP (Enduring Spirit)!";
                return true;
            }
            // Safeguard T1: Reroll — arm reroll flag for next stat check (once/LR, free)
            if (param == "SG_Reroll") {
                if (!player->sg_reroll_lr_available_) { last_action_log_ = current.name + ": Safeguard Reroll already used (LR)."; return false; }
                player->sg_reroll_lr_available_ = false;
                player->sg_reroll_armed_ = true;
                last_action_log_ = current.name + " arms Safeguard Reroll — next stat check will reroll!";
                return true;
            }
            // Safeguard T2: Advantage — arm advantage flag for next stat check (once/SR, free)
            if (param == "SG_Advantage") {
                if (!player->sg_advantage_sr_available_) { last_action_log_ = current.name + ": Safeguard Advantage already used (SR)."; return false; }
                player->sg_advantage_sr_available_ = false;
                player->sg_advantage_armed_ = true;
                last_action_log_ = current.name + " arms Safeguard Advantage — next stat check rolls with advantage!";
                return true;
            }
            // Safeguard T4: Auto-Succeed — arm auto-succeed flag for next stat check (once/LR, free)
            if (param == "SG_AutoSucceed") {
                if (!player->sg_auto_succeed_lr_available_) { last_action_log_ = current.name + ": Safeguard Auto-Succeed already used (LR)."; return false; }
                player->sg_auto_succeed_lr_available_ = false;
                player->sg_auto_succeed_armed_ = true;
                last_action_log_ = current.name + " arms Auto-Succeed — next stat check automatically succeeds!";
                return true;
            }
            // Safeguard T5: Heal = level (once/SR, free)
            if (param == "SG_Heal") {
                if (!player->sg_heal_sr_available_) { last_action_log_ = current.name + ": Safeguard Heal already used (SR)."; return false; }
                player->sg_heal_sr_available_ = false;
                int heal_amt = player->get_level();
                player->heal(heal_amt);
                last_action_log_ = current.name + " recovers " + std::to_string(heal_amt) + " HP (Paragon of Safeguards)!";
                return true;
            }

            // ArcLightSurge — T1, 1/LR basic: electric discharge 10 ft, Speed save or 1d6 lightning + drop metal (+1d6/SP)
            if (param == "ArcLightSurge") {
                if (player->get_feat_tier(FeatID::ArcLightSurge) < 1) { last_action_log_ = current.name + ": Requires Arc-Light Surge."; return false; }
                if (!player->lr_arc_light_available_) { last_action_log_ = current.name + ": Arc-Light Surge already used this rest."; return false; }
                int extra_sp = std::min(player->current_sp_, 3); // allow up to 3 extra SP
                player->current_sp_ -= extra_sp;
                player->lr_arc_light_available_ = false;
                int dc = 10 + player->get_stats().speed;
                int hit_count = 0;
                for (auto& c : combatants_) {
                    if (c.id == current.id) continue;
                    auto* cs = c.is_player ? (c.player_ptr ? &c.player_ptr->get_status() : nullptr) : (c.creature_ptr ? &c.creature_ptr->get_status() : nullptr);
                    int spd = c.is_player && c.player_ptr ? c.player_ptr->get_stats().speed : (c.creature_ptr ? c.creature_ptr->get_stats().speed : 0);
                    int save = dice.roll(20) + spd;
                    if (save < dc) {
                        int dmg = dice.roll(6);
                        for (int i = 0; i < extra_sp; ++i) dmg += dice.roll(6);
                        if (c.is_player && c.player_ptr) c.player_ptr->take_damage(dmg, dice);
                        else if (c.creature_ptr) c.creature_ptr->take_damage(dmg, dice);
                        hit_count++;
                    }
                }
                last_action_log_ = current.name + " releases an Arc-Light Surge! " + std::to_string(hit_count) + " creature(s) struck (DC " + std::to_string(dc) + ", " + std::to_string(1 + extra_sp) + "d6 lightning)!";
                return true;
            }

            // BarkskinToggle — BarkskinRitual T1, 1/LR: grow bark (+2 AC, slash resistance, 1 piercing retaliation)
            if (param == "BarkskinToggle") {
                if (player->get_feat_tier(FeatID::BarkskinRitual) < 1) { last_action_log_ = current.name + ": Requires Barkskin Ritual."; return false; }
                if (!player->lr_barkskin_available_) { last_action_log_ = current.name + ": Barkskin Ritual already used this rest."; return false; }
                player->lr_barkskin_available_ = false;
                player->lr_barkskin_active_ = true;
                player->add_temp_ac(2);
                last_action_log_ = current.name + " grows bark over their skin — +2 AC, resistance to slashing, melee attackers take 1 piercing for 1 hour!";
                return true;
            }

            // BladeScriptureToggle — BladeScripture T1, 1/LR: inscribe weapon rune (+1d6 radiant/necrotic, heal 1 on hit)
            if (param == "BladeScriptureRadiant") {
                if (player->get_feat_tier(FeatID::BladeScripture) < 1) { last_action_log_ = current.name + ": Requires Blade Scripture."; return false; }
                if (!player->lr_blade_scripture_available_) { last_action_log_ = current.name + ": Blade Scripture already used this rest."; return false; }
                player->lr_blade_scripture_available_ = false;
                player->lr_blade_scripture_active_ = true;
                player->blade_scripture_radiant_ = true;
                last_action_log_ = current.name + " inscribes a radiant rune — +1d6 radiant on hits, heal 1 HP per hit for 10 minutes!";
                return true;
            }
            if (param == "BladeScriptureNecrotic") {
                if (player->get_feat_tier(FeatID::BladeScripture) < 1) { last_action_log_ = current.name + ": Requires Blade Scripture."; return false; }
                if (!player->lr_blade_scripture_available_) { last_action_log_ = current.name + ": Blade Scripture already used this rest."; return false; }
                player->lr_blade_scripture_available_ = false;
                player->lr_blade_scripture_active_ = true;
                player->blade_scripture_radiant_ = false;
                last_action_log_ = current.name + " inscribes a necrotic rune — +1d6 necrotic on hits, heal 1 HP per hit for 10 minutes!";
                return true;
            }

            // BreathOfStone — BreathOfStone T1, 1/LR move action: brace stance (+2 AC, immune push/prone)
            if (param == "BreathOfStone") {
                if (player->get_feat_tier(FeatID::BreathOfStone) < 1) { last_action_log_ = current.name + ": Requires Breath of Stone."; return false; }
                if (!player->lr_breath_of_stone_available_) { last_action_log_ = current.name + ": Breath of Stone already used this rest."; return false; }
                player->lr_breath_of_stone_available_ = false;
                player->lr_breath_of_stone_active_ = true;
                player->add_temp_ac(2);
                last_action_log_ = current.name + " braces into stone stance — +2 AC, immune to push/pull/prone for 1 minute!";
                return true;
            }

            // EchoedSteps — EchoedSteps T1, 1/SR: free move action
            if (param == "EchoedSteps") {
                if (player->get_feat_tier(FeatID::EchoedSteps) < 1) { last_action_log_ = current.name + ": Requires Echoed Steps."; return false; }
                if (!player->sr_echoed_steps_available_) { last_action_log_ = current.name + ": Echoed Steps already used this rest."; return false; }
                player->sr_echoed_steps_available_ = false;
                last_action_log_ = current.name + " moves with ghostly echoes as a free action!";
                return true;
            }

            // FlareOfDefiance — T1, 1/LR free when below half HP: Speed save or disadv + Enraged
            if (param == "FlareOfDefiance") {
                if (player->get_feat_tier(FeatID::FlareOfDefiance) < 1) { last_action_log_ = current.name + ": Requires Flare of Defiance."; return false; }
                if (!player->lr_flare_defiance_available_) { last_action_log_ = current.name + ": Flare of Defiance already used this rest."; return false; }
                if (player->get_current_hp() >= player->get_max_hp() / 2) { last_action_log_ = current.name + ": Flare of Defiance requires being below half HP."; return false; }
                player->lr_flare_defiance_available_ = false;
                int dc = 10 + player->get_stats().strength;
                int fail_count = 0;
                int bonus_hp = 0;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        int save = dice.roll(20) + c.creature_ptr->get_stats().speed;
                        if (save < dc) {
                            c.creature_ptr->get_status().add_condition(ConditionType::Enraged);
                            fail_count++;
                            bonus_hp += dice.roll(4);
                        }
                    }
                }
                if (fail_count > 0) {
                    player->heal(bonus_hp);
                    last_action_log_ = current.name + " shouts defiance! " + std::to_string(fail_count) + " enemies Enraged — gained " + std::to_string(bonus_hp) + " bonus HP!";
                } else {
                    last_action_log_ = current.name + " shouts defiance! No enemies failed the save.";
                }
                return true;
            }

            // FlickerSparkyReaction — T1, 1/SR reaction on taking damage: teleport 10 ft, attacker takes 1d4 lightning
            if (param == "FlickerSparky") {
                if (player->get_feat_tier(FeatID::FlickerSparky) < 1) { last_action_log_ = current.name + ": Requires Flicker Sparky."; return false; }
                if (!player->sr_flicker_sparky_available_) { last_action_log_ = current.name + ": Flicker Sparky already used this rest."; return false; }
                player->sr_flicker_sparky_available_ = false;
                player->flicker_resistance_active_ = true;
                int lightning = dice.roll(4);
                // Find last attacker (nearest enemy) and deal lightning
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->take_damage(lightning, dice);
                        last_action_log_ = current.name + " flickers away in a bolt of lightning — attacker " + c.name + " takes " + std::to_string(lightning) + " lightning! Resistance to all damage until next turn!";
                        return true;
                    }
                }
                last_action_log_ = current.name + " flickers in a bolt of lightning! Resistance to all damage until next turn!";
                return true;
            }

            // IllusoryDouble — T1, 1/SR basic: create illusory double (3 hits, d6 deflection)
            if (param == "IllusoryDouble") {
                if (player->get_feat_tier(FeatID::IllusoryDouble) < 1) { last_action_log_ = current.name + ": Requires Illusory Double."; return false; }
                if (!player->sr_illusory_double_available_) { last_action_log_ = current.name + ": Illusory Double already used this rest."; return false; }
                player->sr_illusory_double_available_ = false;
                player->illusory_double_hp_ = 3;
                last_action_log_ = current.name + " conjures an Illusory Double (3 deflections remaining)!";
                return true;
            }

            // PlanarGraze — T1, 1/SR: next hit +1d8 force + push 15 ft
            if (param == "PlanarGraze") {
                if (player->get_feat_tier(FeatID::PlanarGraze) < 1) { last_action_log_ = current.name + ": Requires Planar Graze."; return false; }
                if (!player->sr_planar_graze_available_) { last_action_log_ = current.name + ": Planar Graze already used this rest."; return false; }
                player->sr_planar_graze_available_ = false;
                player->planar_graze_pending_ = true;
                last_action_log_ = current.name + " charges their strike with planar energy — next hit deals +1d8 force and pushes 15 ft!";
                return true;
            }

            // ResonantPulse — T1, 1/LR: pulse allies 10 ft, +1d4 to checks 1 min, regain SP per ally
            if (param == "ResonantPulse") {
                if (player->get_feat_tier(FeatID::ResonantPulse) < 1) { last_action_log_ = current.name + ": Requires Resonant Pulse."; return false; }
                if (!player->lr_resonant_pulse_available_) { last_action_log_ = current.name + ": Resonant Pulse already used this rest."; return false; }
                player->lr_resonant_pulse_available_ = false;
                int buff_count = 0;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        ally.player_ptr->advantage_until_tick_ = std::max(ally.player_ptr->advantage_until_tick_, 10);
                        buff_count++;
                    }
                }
                int sp_gain = std::min(buff_count, player->get_max_sp() - player->current_sp_);
                player->current_sp_ += sp_gain;
                last_action_log_ = current.name + " emits a Resonant Pulse — " + std::to_string(buff_count) + " allies buffed, +" + std::to_string(sp_gain) + " SP regained!";
                return true;
            }

            // SacredFragmentation — T1, 1/SR: mark next spell as half SP cost (not counterable)
            if (param == "SacredFragmentation") {
                if (player->get_feat_tier(FeatID::SacredFragmentation) < 1) { last_action_log_ = current.name + ": Requires Sacred Fragmentation."; return false; }
                if (!player->sr_sacred_frag_available_) { last_action_log_ = current.name + ": Sacred Fragmentation already used this rest."; return false; }
                player->sr_sacred_frag_available_ = false;
                player->sacred_frag_pending_ = true;
                last_action_log_ = current.name + " fragments their arcane focus — next spell costs half SP and cannot be countered!";
                return true;
            }

            // FeatSacrificeHP — FeatSacrifice T1, 1/LR free: sacrifice HP, ally gains 2× HP
            if (param == "FeatSacrificeHP") {
                if (player->get_feat_tier(FeatID::FeatSacrifice) < 1) { last_action_log_ = current.name + ": Requires Sacrifice."; return false; }
                if (!player->lr_sacrifice_available_) { last_action_log_ = current.name + ": Sacrifice already used this rest."; return false; }
                int sacrifice = std::min(player->get_current_hp() - 1, player->get_stats().vitality); // don't kill self
                if (sacrifice <= 0) { last_action_log_ = current.name + ": Not enough HP to sacrifice."; return false; }
                player->lr_sacrifice_available_ = false;
                rimvale::Dice local_dice;
                player->take_damage(sacrifice, local_dice);
                Combatant* chosen = nullptr;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) { chosen = &ally; break; }
                }
                auto* heal_ptr = chosen ? chosen->player_ptr : player;
                heal_ptr->heal(sacrifice * 2);
                std::string tname = chosen ? chosen->name : current.name;
                last_action_log_ = current.name + " sacrifices " + std::to_string(sacrifice) + " HP — " + tname + " gains " + std::to_string(sacrifice * 2) + " HP!";
                return true;
            }

            // SparkLeech — T1, 1/SR reaction: force Divinity save or steal SP
            if (param == "SparkLeech") {
                if (player->get_feat_tier(FeatID::SparkLeech) < 1) { last_action_log_ = current.name + ": Requires Spark Leech."; return false; }
                if (!player->sr_spark_leech_available_) { last_action_log_ = current.name + ": Spark Leech already used this rest."; return false; }
                Combatant* target_caster = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_caster = &c; break; } }
                if (!target_caster) { last_action_log_ = current.name + ": No enemy caster nearby."; return false; }
                player->sr_spark_leech_available_ = false;
                int dc = 10 + player->get_stats().divinity;
                int save = dice.roll(20) + target_caster->creature_ptr->get_stats().divinity;
                if (save < dc) {
                    int stolen = player->get_stats().divinity;
                    int actual = std::min(stolen, player->get_max_sp() - player->current_sp_);
                    player->current_sp_ += actual;
                    last_action_log_ = current.name + " leeches " + std::to_string(actual) + " SP from " + target_caster->name + "!";
                } else {
                    last_action_log_ = current.name + " attempts Spark Leech on " + target_caster->name + " — resisted!";
                }
                return true;
            }

            // SplitSecondRead — T1, 1/LR free: learn emotional state of one creature, +1 AC vs them
            if (param == "SplitSecondRead") {
                if (player->get_feat_tier(FeatID::SplitSecondRead) < 1) { last_action_log_ = current.name + ": Requires Split Second Read."; return false; }
                if (!player->lr_split_second_available_) { last_action_log_ = current.name + ": Split Second Read already used this rest."; return false; }
                player->lr_split_second_available_ = false;
                player->split_second_ac_bonus_rounds_ = 10;
                player->add_temp_ac(1);
                last_action_log_ = current.name + " reads the room in an instant — +1 AC and saves vs that creature for 10 rounds!";
                return true;
            }

            // TemporalShift — T1, 1/LR basic: bless allies or curse enemies (SP spent = targets)
            if (param == "TemporalShiftBless") {
                if (player->get_feat_tier(FeatID::TemporalShift) < 1) { last_action_log_ = current.name + ": Requires Temporal Shift."; return false; }
                if (!player->lr_temporal_shift_available_) { last_action_log_ = current.name + ": Temporal Shift already used this rest."; return false; }
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Temporal Shift."; return false; }
                int sp_spent = std::min(player->current_sp_, 3);
                player->current_sp_ -= sp_spent;
                player->lr_temporal_shift_available_ = false;
                int blessed = 0;
                for (auto& ally : combatants_) {
                    if (blessed >= sp_spent) break;
                    if (ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        ally.player_ptr->advantage_until_tick_ = std::max(ally.player_ptr->advantage_until_tick_, 10);
                        blessed++;
                    }
                }
                last_action_log_ = current.name + " invokes Temporal Shift — " + std::to_string(blessed) + " allies blessed with +1d4 to checks and +5 ft movement for 1 minute!";
                return true;
            }
            if (param == "TemporalShiftCurse") {
                if (player->get_feat_tier(FeatID::TemporalShift) < 1) { last_action_log_ = current.name + ": Requires Temporal Shift."; return false; }
                if (!player->lr_temporal_shift_available_) { last_action_log_ = current.name + ": Temporal Shift already used this rest."; return false; }
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Temporal Shift."; return false; }
                int sp_spent = std::min(player->current_sp_, 3);
                player->current_sp_ -= sp_spent;
                player->lr_temporal_shift_available_ = false;
                int cursed = 0;
                for (auto& c : combatants_) {
                    if (cursed >= sp_spent) break;
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                        cursed++;
                    }
                }
                last_action_log_ = current.name + " invokes Temporal Shift — " + std::to_string(cursed) + " enemies cursed (-1d4 to checks, -5 ft movement)!";
                return true;
            }

            // TetherLink — T1, 1/LR: link with nearest ally for HP transfer
            if (param == "TetherLink") {
                if (player->get_feat_tier(FeatID::TetherLink) < 1) { last_action_log_ = current.name + ": Requires Tether Link."; return false; }
                if (!player->lr_tether_link_available_) { last_action_log_ = current.name + ": Tether Link already used this rest."; return false; }
                Combatant* chosen = nullptr;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) { chosen = &ally; break; }
                }
                if (!chosen) { last_action_log_ = current.name + ": No ally to tether to."; return false; }
                player->lr_tether_link_available_ = false;
                last_action_log_ = current.name + " creates a Tether Link with " + chosen->name + " — HP can now be freely transferred between them!";
                return true;
            }

            // TetherTransfer — HP transfer via active tether
            if (param == "TetherTransfer") {
                if (player->get_feat_tier(FeatID::TetherLink) < 1) { last_action_log_ = current.name + ": Requires Tether Link."; return false; }
                int transfer = std::min(player->get_current_hp() - 1, player->get_stats().vitality);
                if (transfer <= 0) { last_action_log_ = current.name + ": Not enough HP to transfer."; return false; }
                Combatant* chosen = nullptr;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) { chosen = &ally; break; }
                }
                if (!chosen) { last_action_log_ = current.name + ": No linked ally found."; return false; }
                rimvale::Dice local_dice;
                player->take_damage(transfer, local_dice);
                chosen->player_ptr->heal(transfer);
                last_action_log_ = current.name + " transfers " + std::to_string(transfer) + " HP to " + chosen->name + " via Tether Link!";
                return true;
            }

            // VeilbreakerVoice — T3, 1/LR: suppress illusions 20 ft, remove Charmed/Frightened from allies
            if (param == "VeilbreakerVoice") {
                if (player->get_feat_tier(FeatID::VeilbreakerVoice) < 3) { last_action_log_ = current.name + ": Requires Veilbreaker Voice T3."; return false; }
                if (!player->lr_veilbreaker_available_) { last_action_log_ = current.name + ": Veilbreaker Voice already used this rest."; return false; }
                player->lr_veilbreaker_available_ = false;
                int freed = 0;
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        auto& st = ally.player_ptr->get_status();
                        if (st.has_condition(ConditionType::Charm) || st.has_condition(ConditionType::Fear)) {
                            st.remove_condition(ConditionType::Charm);
                            st.remove_condition(ConditionType::Fear);
                            freed++;
                        }
                    }
                }
                last_action_log_ = current.name + " shatters the veil with supernatural force — illusions suppressed, " + std::to_string(freed) + " allies freed from Charm/Fear!";
                return true;
            }

            // Whispers — T1, 1/LR reaction: roll escalating/de-escalating die for bonus on any check
            if (param == "Whispers") {
                if (player->get_feat_tier(FeatID::Whispers) < 1) { last_action_log_ = current.name + ": Requires Whispers."; return false; }
                if (!player->lr_whispers_available_ || player->lr_whispers_consumed_) { last_action_log_ = current.name + ": Whispers is exhausted."; return false; }
                int roll = dice.roll(player->whispers_die_size_);
                int bonus = roll;
                std::string die_change;
                if (roll == 1 && player->whispers_die_size_ < 12) {
                    player->whispers_die_size_ = std::min(12, player->whispers_die_size_ + 2);
                    die_change = " [Die upgraded to d" + std::to_string(player->whispers_die_size_) + "]";
                } else if (roll == player->whispers_die_size_ && player->whispers_die_size_ > 4) {
                    player->whispers_die_size_ = std::max(4, player->whispers_die_size_ - 2);
                    die_change = " [Die downgraded to d" + std::to_string(player->whispers_die_size_) + "]";
                }
                if (roll == 4 && player->whispers_die_size_ == 4) {
                    player->lr_whispers_consumed_ = true;
                    die_change += " [Whispers consumed!]";
                }
                last_action_log_ = current.name + " hears the Whispers — +" + std::to_string(bonus) + " on next check!" + die_change;
                return true;
            }

            // MusicalHeal — MusicalInstrument T1, 1/LR, free (10 min): heal allies within 30 ft for 4d4+DIV per SP spent
            if (param == "MusicalHeal") {
                if (player->get_feat_tier(FeatID::MusicalInstrument) < 1) { last_action_log_ = current.name + ": Requires Musical Instrument T1."; return false; }
                if (!player->lr_music_heal_available_) { last_action_log_ = current.name + ": Melodic Heal already used this rest."; return false; }
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP for Melodic Heal."; return false; }
                int sp_spent = player->current_sp_; // spend all available SP for maximum effect
                player->current_sp_ = 0;
                player->lr_music_heal_available_ = false;
                int heal_per_sp = dice.roll(4) + dice.roll(4) + dice.roll(4) + dice.roll(4) + player->get_stats().divinity;
                int total_heal = heal_per_sp * sp_spent;
                int healed_count = 0;
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        ally.player_ptr->heal(total_heal);
                        healed_count++;
                    }
                }
                last_action_log_ = current.name + " plays a healing melody — " + std::to_string(healed_count) + " allies healed " + std::to_string(total_heal) + " HP (" + std::to_string(sp_spent) + " SP spent)!";
                return true;
            }

            // CulinaryAPBoost — CulinaryVirtuoso T1, 1/LR, free: grant bonus AP = INT to an ally
            if (param == "CulinaryAPBoost") {
                if (player->get_feat_tier(FeatID::CulinaryVirtuoso) < 1) { last_action_log_ = current.name + ": Requires Culinary Virtuoso T1."; return false; }
                if (!player->lr_cul_ap_boost_available_) { last_action_log_ = current.name + ": Culinary AP Boost already used this rest."; return false; }
                player->lr_cul_ap_boost_available_ = false;
                // Grant to nearest living ally (or self if no allies)
                Combatant* chosen = nullptr;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) { chosen = &ally; break; }
                }
                auto* target_ptr = chosen ? chosen->player_ptr : player;
                int bonus_ap = player->get_stats().intellect;
                target_ptr->restore_ap(bonus_ap);
                std::string tname = chosen ? chosen->name : current.name;
                last_action_log_ = current.name + " shares an energizing meal — " + tname + " gains " + std::to_string(bonus_ap) + " bonus AP this turn!";
                return true;
            }

            // AlchemicalDishHeal — CulinaryVirtuoso T2, consume a prepared dish: heal 1d4
            if (param == "AlchemicalDishHeal") {
                if (player->get_feat_tier(FeatID::CulinaryVirtuoso) < 2) { last_action_log_ = current.name + ": Requires Culinary Virtuoso T2."; return false; }
                int healed = dice.roll(4);
                player->heal(healed);
                last_action_log_ = current.name + " consumes an alchemical dish and recovers " + std::to_string(healed) + " HP!";
                return true;
            }

            // AlchemicalDishAC — CulinaryVirtuoso T2, consume a prepared dish: +2 AC for 10 rounds
            if (param == "AlchemicalDishAC") {
                if (player->get_feat_tier(FeatID::CulinaryVirtuoso) < 2) { last_action_log_ = current.name + ": Requires Culinary Virtuoso T2."; return false; }
                player->add_temp_ac(2);
                last_action_log_ = current.name + " consumes an alchemical dish — +2 AC for 1 minute!";
                return true;
            }

            // AlchemicalDishAttack — CulinaryVirtuoso T2, consume a prepared dish: +2 to attack rolls for 10 rounds
            if (param == "AlchemicalDishAttack") {
                if (player->get_feat_tier(FeatID::CulinaryVirtuoso) < 2) { last_action_log_ = current.name + ": Requires Culinary Virtuoso T2."; return false; }
                player->culinary_attack_bonus_rounds_ += 10;
                last_action_log_ = current.name + " consumes an alchemical dish — +2 to attack rolls for 1 minute!";
                return true;
            }

            // HerbalismSalve — HerbalismKit T1, 1/LR: brew and apply a healing salve (1d6 + DIV HP)
            if (param == "HerbalismSalve") {
                if (player->get_feat_tier(FeatID::HerbalismKit) < 1) { last_action_log_ = current.name + ": Requires Herbalism Kit T1."; return false; }
                if (!player->lr_herb_salve_available_) { last_action_log_ = current.name + ": Herbalism Salve already used this rest."; return false; }
                player->lr_herb_salve_available_ = false;
                int healed = dice.roll(6) + player->get_stats().divinity;
                // Apply to nearest injured ally or self
                Combatant* chosen = nullptr;
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr && ally.get_current_hp() < ally.get_max_hp()) {
                        chosen = &ally; break;
                    }
                }
                auto* heal_ptr = chosen ? chosen->player_ptr : player;
                heal_ptr->heal(healed);
                std::string tname = chosen ? chosen->name : current.name;
                last_action_log_ = current.name + " applies a healing salve to " + tname + " — +" + std::to_string(healed) + " HP!";
                return true;
            }

            // PoisonWeapon — PoisonersKit T1, 1/LR: apply poison to weapon
            // Param suffix: "PoisonWeaponDisadv" for disadvantage, "PoisonWeaponDamage" for +1d4 poison
            if (param == "PoisonWeaponDisadv") {
                if (player->get_feat_tier(FeatID::PoisonersKit) < 1) { last_action_log_ = current.name + ": Requires Poisoner's Kit T1."; return false; }
                if (!player->lr_pois_poison_available_) { last_action_log_ = current.name + ": Poison already applied this rest."; return false; }
                player->lr_pois_poison_available_ = false;
                player->pois_weapon_disadvantage_ = true;
                player->pois_weapon_rounds_ = 3;
                last_action_log_ = current.name + " coats their weapon with a disorienting toxin — next hit inflicts disadvantage on target!";
                return true;
            }
            if (param == "PoisonWeaponDamage") {
                if (player->get_feat_tier(FeatID::PoisonersKit) < 1) { last_action_log_ = current.name + ": Requires Poisoner's Kit T1."; return false; }
                if (!player->lr_pois_poison_available_) { last_action_log_ = current.name + ": Poison already applied this rest."; return false; }
                player->lr_pois_poison_available_ = false;
                player->pois_weapon_extra_damage_ = true;
                player->pois_weapon_rounds_ = 3;
                last_action_log_ = current.name + " coats their weapon with a toxic compound — next hit deals +1d4 poison damage!";
                return true;
            }

            // HuntingQuarry — HuntingMastery T3, 1/LR: designate nearest enemy as quarry
            if (param == "HuntingQuarry") {
                if (player->get_feat_tier(FeatID::HuntingMastery) < 3) { last_action_log_ = current.name + ": Requires Hunting Mastery T3."; return false; }
                if (player->lr_hunt_quarry_active_) { last_action_log_ = current.name + ": Already tracking a quarry."; return false; }
                Combatant* q = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { q = &c; break; } }
                if (!q) { last_action_log_ = current.name + ": No enemy to designate as quarry."; return false; }
                player->lr_hunt_quarry_active_ = true;
                player->lr_hunt_quarry_id_ = q->id;
                last_action_log_ = current.name + " marks " + q->name + " as their quarry — advantage on tracking and +1d6 first damage hit each round!";
                return true;
            }

            // HuntingFieldDress — HuntingMastery T3, 1/LR: ritualistic field dressing, restore 1d4 bonus AP
            if (param == "HuntingFieldDress") {
                if (player->get_feat_tier(FeatID::HuntingMastery) < 3) { last_action_log_ = current.name + ": Requires Hunting Mastery T3."; return false; }
                if (!player->lr_hunt_field_dress_available_) { last_action_log_ = current.name + ": Field Dressing already used this rest."; return false; }
                player->lr_hunt_field_dress_available_ = false;
                int ap_bonus = dice.roll(4);
                player->restore_ap(ap_bonus);
                last_action_log_ = current.name + " performs a ritualistic field dressing — +" + std::to_string(ap_bonus) + " AP this turn!";
                return true;
            }

            // CoreSpendDamage — CraftingArtifice T3: spend 1 SP from energy core for +1d6 elemental damage
            if (param == "CoreSpendDamage") {
                if (player->get_feat_tier(FeatID::CraftingArtifice) < 3) { last_action_log_ = current.name + ": Requires Crafting & Artifice T3."; return false; }
                if (player->ca_core_sp_ < 1) { last_action_log_ = current.name + ": Energy core is empty."; return false; }
                player->ca_core_sp_--;
                player->ca_core_damage_bonus_pending_ = dice.roll(6);
                last_action_log_ = current.name + " activates the energy core — next attack deals +" + std::to_string(player->ca_core_damage_bonus_pending_) + " bonus damage!";
                return true;
            }

            // TemporalTouchAdvantage — TemporalTouch T1, free: spend 1 use (DIV/LR) to grant ally advantage on next attack
            if (param == "TemporalTouchAdvantage") {
                if (player->get_feat_tier(FeatID::TemporalTouch) < 1) { last_action_log_ = current.name + ": Requires Temporal Touch T1."; return false; }
                if (player->lr_tt_advantage_uses_ <= 0) { last_action_log_ = current.name + ": No Temporal Touch uses remaining."; return false; }
                player->lr_tt_advantage_uses_--;
                // Grant advantage to nearest living ally
                Combatant* chosen = nullptr;
                for (auto& ally : combatants_) {
                    if (ally.id != current.id && ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        chosen = &ally;
                        break;
                    }
                }
                if (chosen) {
                    chosen->player_ptr->advantage_until_tick_ = std::max(chosen->player_ptr->advantage_until_tick_, 2);
                    last_action_log_ = current.name + " bends time — " + chosen->name + " gains advantage on their next attack! (" + std::to_string(player->lr_tt_advantage_uses_) + " uses left)";
                } else {
                    player->advantage_until_tick_ = std::max(player->advantage_until_tick_, 2);
                    last_action_log_ = current.name + " bends time — gains advantage on next attack! (" + std::to_string(player->lr_tt_advantage_uses_) + " uses left)";
                }
                return true;
            }

            // TemporalTouchCurse — TemporalTouch T1, free: spend 1 use to impose disadvantage (Dazed) on nearest enemy's next action
            if (param == "TemporalTouchCurse") {
                if (player->get_feat_tier(FeatID::TemporalTouch) < 1) { last_action_log_ = current.name + ": Requires Temporal Touch T1."; return false; }
                if (player->lr_tt_advantage_uses_ <= 0) { last_action_log_ = current.name + ": No Temporal Touch uses remaining."; return false; }
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; }
                }
                if (!target_enemy) { last_action_log_ = current.name + ": No enemy to curse."; return false; }
                player->lr_tt_advantage_uses_--;
                target_enemy->creature_ptr->get_status().add_condition(ConditionType::Dazed);
                last_action_log_ = current.name + " reaches through time — " + target_enemy->name + " is Dazed (temporal disorientation)! (" + std::to_string(player->lr_tt_advantage_uses_) + " uses left)";
                return true;
            }

            // ===== ASCENDANT FEATS =====

            // ----- PsychicMaw -----
            if (param == "VoidExposure") {
                if (player->get_feat_tier(FeatID::PsychicMaw) < 1) { last_action_log_ = current.name + ": Requires Psychic Maw."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int total_dmg = 0; int healed = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6) + dice.roll(6) + dice.roll(6) + dice.roll(6);
                    total_dmg += dmg;
                    c.creature_ptr->take_damage(dmg, dice);
                    c.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                    c.creature_ptr->get_status().add_condition(ConditionType::Confused);
                }
                healed = total_dmg / 2;
                player->heal(healed);
                last_action_log_ = current.name + " unleashes Void Exposure! " + std::to_string(total_dmg) + " psychic AoE (60ft), enemies Dazed+Confused for 1 min! Healed " + std::to_string(healed) + " HP!";
                return true;
            }
            if (param == "MindBreak") {
                if (player->get_feat_tier(FeatID::PsychicMaw) < 1) { last_action_log_ = current.name + ": Requires Psychic Maw."; return false; }
                int ap_cost = player->calculate_action_cost(3);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (3 AP required)."; return false; }
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target for Mind Break."; return false; }
                player->current_ap_ -= ap_cost;
                int dc = 10 + player->get_stats().intellect;
                int save = dice.roll(20) + target_enemy->creature_ptr->get_stats().intellect;
                if (save < dc) {
                    int dmg = dice.roll(6) + dice.roll(6);
                    target_enemy->creature_ptr->take_damage(dmg, dice);
                    target_enemy->creature_ptr->get_status().add_condition(ConditionType::Stunned);
                    last_action_log_ = current.name + " breaks " + target_enemy->name + "'s mind! " + std::to_string(dmg) + " psychic + Stunned!";
                } else {
                    last_action_log_ = current.name + " attempts Mind Break on " + target_enemy->name + " — save succeeded (" + std::to_string(save) + " vs DC " + std::to_string(dc) + ")!";
                }
                return true;
            }
            if (param == "PhaseShiftPsychic") {
                if (player->get_feat_tier(FeatID::PsychicMaw) < 1) { last_action_log_ = current.name + ": Requires Psychic Maw."; return false; }
                int ap_cost = player->calculate_action_cost(2);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (2 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                player->psychic_maw_phase_shift_rounds_ = 2;
                player->get_status().add_condition(ConditionType::Intangible);
                last_action_log_ = current.name + " Phase Shifts — Intangible until end of next turn! Immune to nonmagical attacks!";
                return true;
            }

            // ----- AbyssalUnleashing -----
            if (param == "FrenziedFlurry") {
                if (player->get_feat_tier(FeatID::AbyssalUnleashing) < 1) { last_action_log_ = current.name + ": Requires Abyssal Unleashing."; return false; }
                int ap_cost = player->calculate_action_cost(1);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (1 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target for Frenzied Flurry."; return false; }
                last_action_log_ = current.name + " unleashes Frenzied Flurry on " + target_enemy->name + "!";
                for (int i = 0; i < 3; ++i) {
                    bool hit = execute_attack(current, *target_enemy, dice, false, 0);
                    if (hit && i == 2) {
                        int bonus = dice.roll(6) + dice.roll(6);
                        if (target_enemy->creature_ptr) target_enemy->creature_ptr->take_damage(bonus, dice);
                        last_action_log_ += " [Final strike +2d6: " + std::to_string(bonus) + "!]";
                    }
                }
                return true;
            }
            if (param == "TissueDetonation") {
                if (player->get_feat_tier(FeatID::AbyssalUnleashing) < 1) { last_action_log_ = current.name + ": Requires Abyssal Unleashing."; return false; }
                int ap_cost = player->calculate_action_cost(3);
                if (player->current_ap_ < ap_cost || player->current_hp_ <= 6) { last_action_log_ = current.name + ": Not enough AP or HP (3 AP, 6 HP required)."; return false; }
                player->current_ap_ -= ap_cost;
                rimvale::Dice local_d;
                player->take_damage(6, local_d);
                int dc = 10 + player->get_stats().divinity;
                int total_dmg = dice.roll(6) + dice.roll(6) + dice.roll(6);
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().speed;
                    int dmg = (save >= dc) ? std::max(1, total_dmg / 2) : total_dmg;
                    c.creature_ptr->take_damage(dmg, dice);
                    hits++;
                }
                last_action_log_ = current.name + " detonates blood — sacrificed 6 HP, " + std::to_string(total_dmg) + " force to " + std::to_string(hits) + " creature(s) in 5ft (DC " + std::to_string(dc) + " SPD)!";
                return true;
            }
            if (param == "AbyssalTerrify") {
                if (player->get_feat_tier(FeatID::AbyssalUnleashing) < 1) { last_action_log_ = current.name + ": Requires Abyssal Unleashing."; return false; }
                int ap_cost = player->calculate_action_cost(2);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (2 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                int frightened = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    if (c.get_current_hp() < current.get_current_hp()) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Fear);
                        frightened++;
                    }
                }
                last_action_log_ = current.name + " terrifies " + std::to_string(frightened) + " weaker creature(s) within 30 ft!";
                return true;
            }
            if (param == "Sporestorm") {
                if (player->get_feat_tier(FeatID::AbyssalUnleashing) < 1) { last_action_log_ = current.name + ": Requires Abyssal Unleashing."; return false; }
                int ap_cost = player->calculate_action_cost(3);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (3 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                int affected = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->get_status().add_condition(ConditionType::Poisoned);
                    c.creature_ptr->get_status().add_condition(ConditionType::Confused);
                    affected++;
                }
                last_action_log_ = current.name + " releases a Sporestorm — " + std::to_string(affected) + " creature(s) Poisoned+Confused in 20 ft for 1 round!";
                return true;
            }
            if (param == "TrueName") {
                if (player->get_feat_tier(FeatID::AbyssalUnleashing) < 1) { last_action_log_ = current.name + ": Requires Abyssal Unleashing."; return false; }
                if (player->abyssal_true_name_used_today_) { last_action_log_ = current.name + ": True Name already invoked today."; return false; }
                player->abyssal_true_name_used_today_ = true;
                last_action_log_ = current.name + " speaks their True Name — next spell costs 2 SP less (minimum 1) this turn!";
                return true;
            }

            // ----- AngelicRebirth -----
            if (param == "AngelicFlight") {
                if (player->get_feat_tier(FeatID::AngelicRebirth) < 1) { last_action_log_ = current.name + ": Requires Angelic Rebirth."; return false; }
                player->angelic_flight_active_ = !player->angelic_flight_active_;
                if (player->angelic_flight_active_) player->get_status().add_condition(ConditionType::Flying);
                else player->get_status().remove_condition(ConditionType::Flying);
                last_action_log_ = current.name + (player->angelic_flight_active_ ? " takes flight! (Max AP -1)" : " lands.");
                return true;
            }
            if (param == "RadiantPulse") {
                if (player->get_feat_tier(FeatID::AngelicRebirth) < 1) { last_action_log_ = current.name + ": Requires Angelic Rebirth."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int blinded = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6) + dice.roll(6) + dice.roll(6) + dice.roll(6);
                    c.creature_ptr->take_damage(dmg, dice);
                    c.creature_ptr->get_status().add_condition(ConditionType::Blinded);
                    blinded++;
                }
                last_action_log_ = current.name + " releases a Radiant Pulse! " + std::to_string(blinded) + " enemy/enemies in 30 ft hit and Blinded!";
                return true;
            }
            if (param == "AngelicHeal") {
                if (player->get_feat_tier(FeatID::AngelicRebirth) < 1) { last_action_log_ = current.name + ": Requires Angelic Rebirth."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                int total_healed = 0; int ally_count = 0;
                for (auto& ally : combatants_) {
                    if (!ally.is_player || ally.get_current_hp() <= 0 || !ally.player_ptr) continue;
                    int h = dice.roll(6) + dice.roll(6) + dice.roll(6);
                    ally.player_ptr->heal(h);
                    total_healed += h; ally_count++;
                }
                last_action_log_ = current.name + " channels Angelic Healing — " + std::to_string(ally_count) + " ally/allies in 30 ft healed " + std::to_string(total_healed / std::max(1, ally_count)) + " HP each!";
                return true;
            }
            if (param == "SafeguardAura") {
                if (player->get_feat_tier(FeatID::AngelicRebirth) < 1) { last_action_log_ = current.name + ": Requires Angelic Rebirth."; return false; }
                player->angelic_safeguard_active_ = !player->angelic_safeguard_active_;
                if (player->angelic_safeguard_active_) {
                    for (auto& ally : combatants_) { if (ally.is_player && ally.id != current.id && ally.player_ptr && ally.get_current_hp() > 0) ally.player_ptr->add_temp_ac(2); }
                }
                last_action_log_ = current.name + (player->angelic_safeguard_active_ ? " activates Safeguard Aura — allies within 15 ft gain +2 AC! (Max AP -3)" : " deactivates Safeguard Aura.");
                return true;
            }

            // ----- CryptbornSovereign -----
            if (param == "CryptbornToggle") {
                if (player->get_feat_tier(FeatID::CryptbornSovereign) < 1) { last_action_log_ = current.name + ": Requires Cryptborn Sovereign."; return false; }
                player->cryptborn_regen_active_ = !player->cryptborn_regen_active_;
                last_action_log_ = current.name + (player->cryptborn_regen_active_ ? " awakens undead regeneration — 1d6 HP/turn!" : " suppresses regeneration.");
                return true;
            }
            if (param == "BlightTouch") {
                if (player->get_feat_tier(FeatID::CryptbornSovereign) < 1) { last_action_log_ = current.name + ": Requires Cryptborn Sovereign."; return false; }
                int ap_cost = player->calculate_action_cost(2);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (2 AP required)."; return false; }
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target in range for Blight Touch."; return false; }
                player->current_ap_ -= ap_cost;
                int dmg = dice.roll(6) + dice.roll(6);
                target_enemy->creature_ptr->take_damage(dmg, dice);
                player->cryptborn_blight_target_id_ = target_enemy->id;
                player->cryptborn_blight_rounds_ = 1;
                last_action_log_ = current.name + " touches " + target_enemy->name + " with blight — " + std::to_string(dmg) + " necrotic, cannot heal for 1 round!";
                return true;
            }
            if (param == "DeathRattle") {
                if (player->get_feat_tier(FeatID::CryptbornSovereign) < 1) { last_action_log_ = current.name + ": Requires Cryptborn Sovereign."; return false; }
                int sp_to_spend = player->current_sp_;
                player->current_sp_ = 0;
                int dmg = dice.roll(6);
                for (int i = 0; i < sp_to_spend; ++i) dmg += dice.roll(6);
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.id == current.id || c.get_current_hp() <= 0) continue;
                    if (c.is_player && c.player_ptr) c.player_ptr->take_damage(dmg, dice);
                    else if (c.creature_ptr) c.creature_ptr->take_damage(dmg, dice);
                    hits++;
                }
                last_action_log_ = current.name + " releases a Death Rattle — " + std::to_string(dmg) + " necrotic to " + std::to_string(hits) + " creature(s) in 10 ft! (" + std::to_string(sp_to_spend) + " SP spent)";
                return true;
            }

            // ----- DraconicApotheosis -----
            if (param == "DraconicFlight") {
                if (player->get_feat_tier(FeatID::DraconicApotheosis) < 1) { last_action_log_ = current.name + ": Requires Draconic Apotheosis."; return false; }
                player->draconic_apo_flight_active_ = !player->draconic_apo_flight_active_;
                if (player->draconic_apo_flight_active_) player->get_status().add_condition(ConditionType::Flying);
                else player->get_status().remove_condition(ConditionType::Flying);
                last_action_log_ = current.name + (player->draconic_apo_flight_active_ ? " spreads draconic wings and takes flight! (Max AP -1)" : " lands.");
                return true;
            }
            if (param == "BreathWeapon") {
                if (player->get_feat_tier(FeatID::DraconicApotheosis) < 1) { last_action_log_ = current.name + ": Requires Draconic Apotheosis."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                int total_dmg = 0; int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                    total_dmg += dmg; hits++;
                    c.creature_ptr->take_damage(dmg, dice);
                }
                last_action_log_ = current.name + " breathes " + player->draconic_apo_element_ + "! " + std::to_string(hits) + " creature(s) hit for " + std::to_string(total_dmg / std::max(1, hits)) + " elemental damage (60ft cone)!";
                return true;
            }
            if (param == "DraconicScales") {
                if (player->get_feat_tier(FeatID::DraconicApotheosis) < 1) { last_action_log_ = current.name + ": Requires Draconic Apotheosis."; return false; }
                player->draconic_apo_scales_active_ = !player->draconic_apo_scales_active_;
                last_action_log_ = current.name + (player->draconic_apo_scales_active_ ? " hardens draconic scales — +2 AC and " + player->draconic_apo_element_ + " resistance!" : " relaxes scales.");
                return true;
            }
            if (param == "DraconicTerrify") {
                if (player->get_feat_tier(FeatID::DraconicApotheosis) < 1) { last_action_log_ = current.name + ": Requires Draconic Apotheosis."; return false; }
                int ap_cost = player->calculate_action_cost(2);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (2 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                int frightened = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    if (c.get_current_hp() < current.get_current_hp()) { c.creature_ptr->get_status().add_condition(ConditionType::Fear); frightened++; }
                }
                last_action_log_ = current.name + " roars — " + std::to_string(frightened) + " weaker creature(s) Frightened in 30 ft!";
                return true;
            }

            // ----- FeyLordsPact -----
            if (param == "TeleportSwarm") {
                if (player->get_feat_tier(FeatID::FeyLordsPact) < 1) { last_action_log_ = current.name + ": Requires Fey Lord's Pact."; return false; }
                int ap_cost = player->calculate_action_cost(4);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (4 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                int teleported = 1; // self
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.id != current.id && ally.player_ptr && ally.get_current_hp() > 0 && teleported <= 3) {
                        teleported++;
                    }
                }
                last_action_log_ = current.name + " weaves fey magic — teleports self + " + std::to_string(teleported - 1) + " ally/allies 120 ft!";
                return true;
            }
            if (param == "FeyCharmGaze") {
                if (player->get_feat_tier(FeatID::FeyLordsPact) < 1) { last_action_log_ = current.name + ": Requires Fey Lord's Pact."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target for Charm Gaze."; return false; }
                int dc = 10 + player->get_stats().divinity;
                int save = dice.roll(20) + target_enemy->creature_ptr->get_stats().intellect;
                if (save < dc) {
                    target_enemy->creature_ptr->get_status().add_condition(ConditionType::Charm);
                    last_action_log_ = current.name + " charms " + target_enemy->name + " with a Fey Gaze for 1 minute! (DC " + std::to_string(dc) + ")";
                } else {
                    last_action_log_ = current.name + " attempts Charm Gaze — " + target_enemy->name + " resists (" + std::to_string(save) + " vs DC " + std::to_string(dc) + ")!";
                }
                return true;
            }
            if (param == "FeyRealityDistort") {
                if (player->get_feat_tier(FeatID::FeyLordsPact) < 1) { last_action_log_ = current.name + ": Requires Fey Lord's Pact."; return false; }
                player->fey_reality_distort_active_ = !player->fey_reality_distort_active_;
                if (player->fey_reality_distort_active_) {
                    int dc = 10 + player->get_stats().divinity;
                    int confused = 0;
                    for (auto& c : combatants_) {
                        if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                        int save = dice.roll(20) + c.creature_ptr->get_stats().intellect;
                        if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Confused); confused++; }
                    }
                    last_action_log_ = current.name + " distorts reality (120 ft) — " + std::to_string(confused) + " creature(s) accept illusions as real! (Max AP -3)";
                } else {
                    last_action_log_ = current.name + " collapses the reality distortion.";
                }
                return true;
            }

            // ----- HagMothersCovenant -----
            if (param == "NightmareBrood") {
                if (player->get_feat_tier(FeatID::HagMothersCovenant) < 1) { last_action_log_ = current.name + ": Requires Hag Mother's Covenant."; return false; }
                player->hag_nightmare_brood_active_ = !player->hag_nightmare_brood_active_;
                if (player->hag_nightmare_brood_active_) {
                    player->hag_dreamspawn_count_ = 3;
                    last_action_log_ = current.name + " summons the Nightmare Brood — 3 Dreamspawn arise! (Max AP -3, HP=4, AC=12, resist psychic)";
                } else {
                    player->hag_dreamspawn_count_ = 0;
                    last_action_log_ = current.name + " dismisses the Nightmare Brood.";
                }
                return true;
            }
            if (param == "TwistedBoon") {
                if (player->get_feat_tier(FeatID::HagMothersCovenant) < 1) { last_action_log_ = current.name + ": Requires Hag Mother's Covenant."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                Combatant* chosen = nullptr;
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.id != current.id && ally.player_ptr && ally.get_current_hp() > 0) { chosen = &ally; break; }
                }
                if (!chosen) { last_action_log_ = current.name + ": No ally to offer a Twisted Boon."; return false; }
                player->current_sp_ -= 2;
                chosen->player_ptr->add_temp_ac(2);
                chosen->player_ptr->advantage_until_tick_ = std::max(chosen->player_ptr->advantage_until_tick_, 12);
                last_action_log_ = current.name + " offers " + chosen->name + " a Twisted Boon — +2 AC and advantage for 24 hrs! They are now vulnerable to your spells and hexes.";
                return true;
            }
            if (param == "SoulrootEffigy") {
                if (player->get_feat_tier(FeatID::HagMothersCovenant) < 1) { last_action_log_ = current.name + ": Requires Hag Mother's Covenant."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->hag_soulroot_active_ = true;
                int dc = 13; int unnerved = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().divinity;
                    if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Fear); unnerved++; }
                }
                last_action_log_ = current.name + " activates the Soulroot Effigy — perceive and cast from afar! " + std::to_string(unnerved) + " creature(s) unnerved (DC " + std::to_string(dc) + " DIV)!";
                return true;
            }

            // ----- InfernalCoronation -----
            if (param == "Hellfire") {
                if (player->get_feat_tier(FeatID::InfernalCoronation) < 1) { last_action_log_ = current.name + ": Requires Infernal Coronation."; return false; }
                if (player->current_sp_ < 5) { last_action_log_ = current.name + ": Not enough SP (5 SP required)."; return false; }
                player->current_sp_ -= 5;
                int fire = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                int thunder = dice.roll(6)+dice.roll(6);
                int total = fire + thunder;
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->take_damage(total, dice); hits++;
                }
                last_action_log_ = current.name + " calls down Hellfire! " + std::to_string(total) + " fire+thunder to " + std::to_string(hits) + " creature(s) in 10 ft radius!";
                return true;
            }
            if (param == "DemonicAuthority") {
                if (player->get_feat_tier(FeatID::InfernalCoronation) < 1) { last_action_log_ = current.name + ": Requires Infernal Coronation."; return false; }
                int frightened = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    if (c.creature_ptr->get_stats().divinity < player->get_stats().divinity) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Fear); frightened++;
                    }
                }
                last_action_log_ = current.name + " exerts Demonic Authority — " + std::to_string(frightened) + " lower-Divinity creature(s) auto-Frightened within 10 ft!";
                return true;
            }
            if (param == "FlameFlickerSacrifice") {
                if (player->get_feat_tier(FeatID::InfernalCoronation) < 1) { last_action_log_ = current.name + ": Requires Infernal Coronation."; return false; }
                int sacrifice = player->current_hp_ / 4; // sacrifice 25% HP
                if (sacrifice <= 0) { last_action_log_ = current.name + ": Not enough HP to sacrifice."; return false; }
                rimvale::Dice local_d;
                player->take_damage(sacrifice, local_d);
                player->infernal_flame_flicker_hp_sacrificed_ = sacrifice;
                player->infernal_flame_flicker_primed_ = true;
                last_action_log_ = current.name + " sacrifices " + std::to_string(sacrifice) + " HP — next melee hit deals " + std::to_string(sacrifice) + "d4 fire damage!";
                return true;
            }
            if (param == "TailWhip") {
                if (player->get_feat_tier(FeatID::InfernalCoronation) < 1) { last_action_log_ = current.name + ": Requires Infernal Coronation."; return false; }
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target for Tail Whip."; return false; }
                int atk = player->roll_attack(dice, nullptr).total;
                int t_ac = 10 + target_enemy->creature_ptr->get_stats().speed;
                if (atk >= t_ac) {
                    int dmg = dice.roll(4);
                    target_enemy->creature_ptr->take_damage(dmg, dice);
                    last_action_log_ = current.name + " whips " + target_enemy->name + " with a devil tail — " + std::to_string(dmg) + " magical slashing!";
                } else {
                    last_action_log_ = current.name + " tail whip misses " + target_enemy->name + "!";
                }
                return true;
            }

            // ----- KaijuCoreIntegration -----
            if (param == "KaijuTitanicBoost") {
                if (player->get_feat_tier(FeatID::KaijuCoreIntegration) < 1) { last_action_log_ = current.name + ": Requires Kaiju Core Integration."; return false; }
                if (player->kaiju_titanic_applied_) { last_action_log_ = current.name + ": Titanic Strength already applied."; return false; }
                player->kaiju_titanic_applied_ = true;
                player->get_stats().strength = std::min(10, player->get_stats().strength + 2);
                player->get_stats().vitality = std::min(10, player->get_stats().vitality + 2);
                // +5 AP: handled via the base bonus — grant directly to current AP
                player->restore_ap(5);
                last_action_log_ = current.name + " undergoes Titanic Strength — +2 STR, +2 VIT, +5 AP permanently!";
                return true;
            }
            if (param == "StampedeCAll") {
                if (player->get_feat_tier(FeatID::KaijuCoreIntegration) < 1) { last_action_log_ = current.name + ": Requires Kaiju Core Integration."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int total_dmg = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->take_damage(total_dmg, dice);
                    c.creature_ptr->get_status().add_condition(ConditionType::Prone);
                    hits++;
                }
                last_action_log_ = current.name + " unleashes a Stampede Call — " + std::to_string(total_dmg) + " damage (60ft cone), " + std::to_string(hits) + " creature(s) pushed 30 ft and Prone!";
                return true;
            }
            if (param == "GravitySlam") {
                if (player->get_feat_tier(FeatID::KaijuCoreIntegration) < 1) { last_action_log_ = current.name + ": Requires Kaiju Core Integration."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6) + dice.roll(6) + dice.roll(6);
                    c.creature_ptr->take_damage(dmg, dice);
                    c.creature_ptr->get_status().add_condition(ConditionType::Prone);
                    hits++;
                }
                last_action_log_ = current.name + " slams gravity into adjacent enemies — 3d6 force to " + std::to_string(hits) + " adjacent creature(s) Prone!";
                return true;
            }

            // ----- ShapeshiftersPath -----
            if (param == "BeastShift") {
                int sp_tier = player->get_feat_tier(FeatID::ShapeshiftersPath);
                if (sp_tier < 1) { last_action_log_ = current.name + ": Requires ShapeshiftersPath."; return false; }
                player->shapeshift_beast_form_active_ = !player->shapeshift_beast_form_active_;
                if (player->shapeshift_beast_form_active_) {
                    // Apply beast stat bonuses
                    int str_bonus = (sp_tier >= 4) ? 4 : (sp_tier >= 2) ? 3 : 2;
                    int spd_bonus = (sp_tier >= 3) ? 3 : 2;
                    player->get_stats().strength = std::min(10, player->get_stats().strength + str_bonus);
                    player->get_stats().speed     = std::min(10, player->get_stats().speed + spd_bonus);
                    // T3+: resistance to non-magical damage
                    if (sp_tier >= 3) player->has_physical_resistance_ = true;
                    last_action_log_ = current.name + " shifts into Beast Form! +" + std::to_string(str_bonus) + " STR, +" + std::to_string(spd_bonus) + " SPD" + (sp_tier >= 3 ? ", resistance to non-magical damage!" : "!");
                } else {
                    int str_bonus = (sp_tier >= 4) ? 4 : (sp_tier >= 2) ? 3 : 2;
                    int spd_bonus = (sp_tier >= 3) ? 3 : 2;
                    player->get_stats().strength = std::max(0, player->get_stats().strength - str_bonus);
                    player->get_stats().speed     = std::max(0, player->get_stats().speed - spd_bonus);
                    if (sp_tier >= 3) player->has_physical_resistance_ = false;
                    last_action_log_ = current.name + " reverts to Humanoid Form.";
                }
                return true;
            }

            // ----- LycanthropicCurse -----
            if (param == "HybridForm") {
                if (player->get_feat_tier(FeatID::LycanthropicCurse) < 1) { last_action_log_ = current.name + ": Requires Lycanthropic Curse."; return false; }
                player->lycanthrope_hybrid_active_ = !player->lycanthrope_hybrid_active_;
                if (player->lycanthrope_hybrid_active_) {
                    player->get_stats().strength = std::min(10, player->get_stats().strength + 3);
                    player->get_stats().speed = std::min(10, player->get_stats().speed + 2);
                    last_action_log_ = current.name + " transforms into Hybrid Form! +3 STR, +2 SPD, +20ft move, threshold, immune to non-silver/non-magical damage, 1d6 regen!";
                } else {
                    player->get_stats().strength = std::max(0, player->get_stats().strength - 3);
                    player->get_stats().speed = std::max(0, player->get_stats().speed - 2);
                    last_action_log_ = current.name + " reverts from Hybrid Form.";
                }
                return true;
            }
            if (param == "RendingBite") {
                if (player->get_feat_tier(FeatID::LycanthropicCurse) < 1) { last_action_log_ = current.name + ": Requires Lycanthropic Curse."; return false; }
                if (!player->lycanthrope_hybrid_active_) { last_action_log_ = current.name + ": Must be in Hybrid Form for Rending Bite."; return false; }
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target for Rending Bite."; return false; }
                bool bite_hit = execute_attack(current, *target_enemy, dice, true, 0);
                if (bite_hit) {
                    target_enemy->creature_ptr->get_status().add_condition(ConditionType::Bleed);
                    target_enemy->creature_ptr->get_status().set_bleed_stacks(target_enemy->creature_ptr->get_status().get_bleed_stacks() + 3);
                    last_action_log_ += " [Rending Bite: 3 bleed stacks — 1d4/turn for 3 rounds!]";
                }
                return true;
            }
            if (param == "BloodHowl") {
                if (player->get_feat_tier(FeatID::LycanthropicCurse) < 1) { last_action_log_ = current.name + ": Requires Lycanthropic Curse."; return false; }
                player->lycanthrope_blood_howl_rounds_ = 12; // 1 minute
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.id != current.id && ally.player_ptr && ally.get_current_hp() > 0)
                        ally.player_ptr->advantage_until_tick_ = std::max(ally.player_ptr->advantage_until_tick_, 12);
                }
                last_action_log_ = current.name + " lets out a Blood Howl! Allies within 30 ft gain +1d4 bonus damage for 1 minute!";
                return true;
            }

            // ----- LichBinding -----
            if (param == "SoulDrain") {
                if (player->get_feat_tier(FeatID::LichBinding) < 1) { last_action_log_ = current.name + ": Requires Lich Binding."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int total_dmg = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                    total_dmg += dmg;
                    c.creature_ptr->take_damage(dmg, dice);
                }
                player->heal(total_dmg / 2);
                last_action_log_ = current.name + " drains souls — " + std::to_string(total_dmg) + " necrotic, healed " + std::to_string(total_dmg / 2) + " HP!";
                return true;
            }
            if (param == "SparkSteal") {
                if (player->get_feat_tier(FeatID::LichBinding) < 1) { last_action_log_ = current.name + ": Requires Lich Binding."; return false; }
                int ap_cost = player->calculate_action_cost(4);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (4 AP required)."; return false; }
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target for Spark Steal."; return false; }
                player->current_ap_ -= ap_cost;
                int dc = 10 + player->get_stats().divinity;
                int save = dice.roll(20) + target_enemy->creature_ptr->get_stats().vitality;
                if (save < dc) {
                    int stolen = dice.roll(4);
                    player->restore_sp(stolen);
                    last_action_log_ = current.name + " steals " + std::to_string(stolen) + " SP from " + target_enemy->name + "! (Failed DC " + std::to_string(dc) + ")";
                } else {
                    last_action_log_ = current.name + " attempts Spark Steal on " + target_enemy->name + " — resisted! (" + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                }
                return true;
            }
            if (param == "PhylacteryToggle") {
                if (player->get_feat_tier(FeatID::LichBinding) < 1) { last_action_log_ = current.name + ": Requires Lich Binding."; return false; }
                player->lich_phylactery_intact_ = !player->lich_phylactery_intact_;
                last_action_log_ = current.name + (player->lich_phylactery_intact_ ? " bonds to the Phylactery — will reform after death!" : " severs the Phylactery bond.");
                return true;
            }

            // ----- PrimordialElementalFusion -----
            if (param == "ElementalBurst") {
                if (player->get_feat_tier(FeatID::PrimordialElementalFusion) < 1) { last_action_log_ = current.name + ": Requires Primordial Elemental Fusion."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                int total_dmg = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->take_damage(total_dmg, dice); hits++;
                }
                last_action_log_ = current.name + " detonates an Elemental Burst — " + std::to_string(total_dmg) + " elemental damage to " + std::to_string(hits) + " creature(s) in 15 ft radius!";
                return true;
            }
            if (param == "ShiftingHideAdd") {
                if (player->get_feat_tier(FeatID::PrimordialElementalFusion) < 1) { last_action_log_ = current.name + ": Requires Primordial Elemental Fusion."; return false; }
                player->elemental_shifting_hide_stacks_++;
                player->get_status().add_condition(ConditionType::Resistance);
                last_action_log_ = current.name + " adds a Shifting Hide resistance layer — " + std::to_string(player->elemental_shifting_hide_stacks_) + " active resistance(s), Max AP -" + std::to_string(2 * player->elemental_shifting_hide_stacks_) + "!";
                return true;
            }
            if (param == "ShiftingHideRemove") {
                if (player->get_feat_tier(FeatID::PrimordialElementalFusion) < 1) { last_action_log_ = current.name + ": Requires Primordial Elemental Fusion."; return false; }
                if (player->elemental_shifting_hide_stacks_ <= 0) { last_action_log_ = current.name + ": No Shifting Hide stacks active."; return false; }
                player->elemental_shifting_hide_stacks_--;
                if (player->elemental_shifting_hide_stacks_ == 0) player->get_status().remove_condition(ConditionType::Resistance);
                last_action_log_ = current.name + " removes a Shifting Hide layer — " + std::to_string(player->elemental_shifting_hide_stacks_) + " remaining.";
                return true;
            }
            if (param == "SunfirePulse") {
                if (player->get_feat_tier(FeatID::PrimordialElementalFusion) < 1) { last_action_log_ = current.name + ": Requires Primordial Elemental Fusion."; return false; }
                int ap_cost = player->calculate_action_cost(3);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (3 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6) + dice.roll(6);
                    c.creature_ptr->take_damage(dmg, dice);
                    c.creature_ptr->get_status().add_condition(ConditionType::Exhausted);
                    hits++;
                }
                last_action_log_ = current.name + " pulses sunfire — 2d6 fire + Exhausted to " + std::to_string(hits) + " creature(s) in 15 ft aura!";
                return true;
            }
            if (param == "FrozenGrasp") {
                if (player->get_feat_tier(FeatID::PrimordialElementalFusion) < 1) { last_action_log_ = current.name + ": Requires Primordial Elemental Fusion."; return false; }
                int ap_cost = player->calculate_action_cost(3);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (3 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                int dc = 10 + player->get_stats().speed;
                int frozen = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().speed;
                    if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Restrained); c.creature_ptr->get_status().add_condition(ConditionType::Slowed); frozen++; }
                }
                last_action_log_ = current.name + " extends a Frozen Grasp — " + std::to_string(frozen) + " creature(s) frozen (Speed=0) in 10 ft cone (DC " + std::to_string(dc) + " SPD)!";
                return true;
            }

            // ----- SeraphicFlame -----
            if (param == "FlameFlickerToggle") {
                if (player->get_feat_tier(FeatID::SeraphicFlame) < 1) { last_action_log_ = current.name + ": Requires Seraphic Flame."; return false; }
                if (player->seraphic_flame_flicker_ap_cost_ < 3) {
                    player->seraphic_flame_flicker_ap_cost_++;
                    last_action_log_ = current.name + " intensifies Flame Flicker — +" + std::to_string(player->seraphic_flame_flicker_ap_cost_) + "d4 fire on melee hits! (Max AP -" + std::to_string(player->seraphic_flame_flicker_ap_cost_) + ")";
                } else {
                    player->seraphic_flame_flicker_ap_cost_ = 0;
                    last_action_log_ = current.name + " extinguishes Flame Flicker.";
                }
                return true;
            }
            if (param == "ExplosiveMix") {
                if (player->get_feat_tier(FeatID::SeraphicFlame) < 1) { last_action_log_ = current.name + ": Requires Seraphic Flame."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int fire = 0, thunder = 0;
                for (int i = 0; i < 4; ++i) { int r = dice.roll(6); fire += (r == 1) ? dice.roll(6) : r; }
                for (int i = 0; i < 2; ++i) { int r = dice.roll(6); thunder += (r == 1) ? dice.roll(6) : r; }
                int total = fire + thunder;
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->take_damage(total, dice); hits++;
                }
                last_action_log_ = current.name + " detonates an Explosive Mix — " + std::to_string(total) + " fire+thunder (rerolled 1s) to " + std::to_string(hits) + " creature(s) in 10 ft!";
                return true;
            }
            if (param == "ReflectiveVeil") {
                if (player->get_feat_tier(FeatID::SeraphicFlame) < 1) { last_action_log_ = current.name + ": Requires Seraphic Flame."; return false; }
                if (!player->seraphic_reflective_veil_available_) { last_action_log_ = current.name + ": Reflective Veil already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->seraphic_reflective_veil_available_ = false;
                player->seraphic_reflective_veil_rounds_ = 12;
                player->advantage_until_tick_ = std::max(player->advantage_until_tick_, 12);
                last_action_log_ = current.name + " raises the Reflective Veil — advantage vs magic for 1 minute, reflects next spell!";
                return true;
            }
            if (param == "SeraphicHeal") {
                if (player->get_feat_tier(FeatID::SeraphicFlame) < 1) { last_action_log_ = current.name + ": Requires Seraphic Flame."; return false; }
                if (!player->seraphic_heal_lr_available_) { last_action_log_ = current.name + ": Healing already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->seraphic_heal_lr_available_ = false;
                int ally_count = 0;
                for (auto& ally : combatants_) {
                    if (!ally.is_player || ally.get_current_hp() <= 0 || !ally.player_ptr) continue;
                    int h = dice.roll(6) + dice.roll(6) + dice.roll(6);
                    ally.player_ptr->heal(h); ally_count++;
                }
                last_action_log_ = current.name + " channels Seraphic Healing — " + std::to_string(ally_count) + " ally/allies in 30 ft healed!";
                return true;
            }

            // ----- StormboundTitan -----
            if (param == "StormboundGrow") {
                if (player->get_feat_tier(FeatID::StormboundTitan) < 1) { last_action_log_ = current.name + ": Requires Stormbound Titan."; return false; }
                if (player->stormbound_grow_ap_cost_ < 4) {
                    player->stormbound_grow_ap_cost_++;
                    last_action_log_ = current.name + " grows larger — size +" + std::to_string(player->stormbound_grow_ap_cost_) + "! (Max AP -" + std::to_string(player->stormbound_grow_ap_cost_) + ")";
                } else {
                    player->stormbound_grow_ap_cost_ = 0;
                    last_action_log_ = current.name + " returns to normal size.";
                }
                return true;
            }
            if (param == "LightningRod") {
                if (player->get_feat_tier(FeatID::StormboundTitan) < 1) { last_action_log_ = current.name + ": Requires Stormbound Titan."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int lightning = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->take_damage(lightning, dice); hits++;
                }
                last_action_log_ = current.name + " releases the Lightning Rod — " + std::to_string(lightning) + " lightning to " + std::to_string(hits) + " creature(s) within 10 ft!";
                return true;
            }
            if (param == "ArcshockBlink") {
                if (player->get_feat_tier(FeatID::StormboundTitan) < 1) { last_action_log_ = current.name + ": Requires Stormbound Titan."; return false; }
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP (1 SP required)."; return false; }
                player->current_sp_ -= 1;
                int arc_dmg = dice.roll(6) + dice.roll(6);
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->take_damage(arc_dmg, dice); hits++;
                }
                last_action_log_ = current.name + " blinks 30 ft with Arcshock — lightning arcs deal " + std::to_string(arc_dmg) + " to " + std::to_string(hits) + " creature(s) in path!";
                return true;
            }
            if (param == "StormboundStampede") {
                if (player->get_feat_tier(FeatID::StormboundTitan) < 1) { last_action_log_ = current.name + ": Requires Stormbound Titan."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int dmg = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->take_damage(dmg, dice); c.creature_ptr->get_status().add_condition(ConditionType::Prone); hits++;
                }
                last_action_log_ = current.name + " calls a Stampede — " + std::to_string(dmg) + " damage (60ft cone), " + std::to_string(hits) + " creature(s) pushed+Prone!";
                return true;
            }
            if (param == "StormboundGravitySlam") {
                if (player->get_feat_tier(FeatID::StormboundTitan) < 1) { last_action_log_ = current.name + ": Requires Stormbound Titan."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6) + dice.roll(6) + dice.roll(6);
                    c.creature_ptr->take_damage(dmg, dice); c.creature_ptr->get_status().add_condition(ConditionType::Prone); hits++;
                }
                last_action_log_ = current.name + " slams gravity — 3d6 force to " + std::to_string(hits) + " adjacent creature(s) Prone!";
                return true;
            }

            // ----- VampiricAscension -----
            if (param == "VampireFlightToggle") {
                if (player->get_feat_tier(FeatID::VampiricAscension) < 1) { last_action_log_ = current.name + ": Requires Vampiric Ascension."; return false; }
                player->vampire_flight_intangible_active_ = !player->vampire_flight_intangible_active_;
                if (player->vampire_flight_intangible_active_) {
                    player->get_status().add_condition(ConditionType::Flying);
                    player->get_status().add_condition(ConditionType::Intangible);
                    last_action_log_ = current.name + " takes vampiric flight — Flying+Intangible! (Max AP -3)";
                } else {
                    player->get_status().remove_condition(ConditionType::Flying);
                    player->get_status().remove_condition(ConditionType::Intangible);
                    last_action_log_ = current.name + " descends from vampiric flight.";
                }
                return true;
            }
            if (param == "VampireCharmGaze") {
                if (player->get_feat_tier(FeatID::VampiricAscension) < 1) { last_action_log_ = current.name + ": Requires Vampiric Ascension."; return false; }
                if (player->current_sp_ < 1) { last_action_log_ = current.name + ": Not enough SP."; return false; }
                player->current_sp_ -= 1;
                Combatant* target_enemy = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { target_enemy = &c; break; } }
                if (!target_enemy) { last_action_log_ = current.name + ": No target for Charm Gaze."; return false; }
                int dc = 16;
                int save = dice.roll(20) + target_enemy->creature_ptr->get_stats().intellect;
                if (save < dc) {
                    target_enemy->creature_ptr->get_status().add_condition(ConditionType::Charm);
                    last_action_log_ = current.name + " charms " + target_enemy->name + " with vampiric gaze for 1 minute! (DC " + std::to_string(dc) + ")";
                } else {
                    last_action_log_ = current.name + " attempts Vampire Charm — resisted! (" + std::to_string(save) + " vs DC " + std::to_string(dc) + ")";
                }
                return true;
            }

            // ----- VoidbornMutation -----
            if (param == "VoidbornPhaseShift") {
                if (player->get_feat_tier(FeatID::VoidbornMutation) < 1) { last_action_log_ = current.name + ": Requires Voidborn Mutation."; return false; }
                int ap_cost = player->calculate_action_cost(1);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP (1 AP required)."; return false; }
                player->current_ap_ -= ap_cost;
                player->voidborn_phase_shift_rounds_ = 2;
                player->get_status().add_condition(ConditionType::Intangible);
                last_action_log_ = current.name + " phase shifts — Intangible for 1 round!";
                return true;
            }
            if (param == "VoidbornVoidExposure") {
                if (player->get_feat_tier(FeatID::VoidbornMutation) < 1) { last_action_log_ = current.name + ": Requires Voidborn Mutation."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                int dc = 10 + player->get_stats().divinity;
                int total_dmg = 0; int hits = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dmg = dice.roll(6)+dice.roll(6)+dice.roll(6)+dice.roll(6);
                    total_dmg += dmg;
                    c.creature_ptr->take_damage(dmg, dice);
                    int save = dice.roll(20) + c.creature_ptr->get_stats().vitality;
                    if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Dazed); c.creature_ptr->get_status().add_condition(ConditionType::Confused); }
                    hits++;
                }
                last_action_log_ = current.name + " unleashes Void Exposure — " + std::to_string(total_dmg) + " psychic to " + std::to_string(hits) + " creature(s) in 60 ft (DC " + std::to_string(dc) + " VIT or Dazed+Confused)!";
                return true;
            }
            if (param == "VoidbornRealityDistort") {
                if (player->get_feat_tier(FeatID::VoidbornMutation) < 1) { last_action_log_ = current.name + ": Requires Voidborn Mutation."; return false; }
                player->voidborn_reality_distort_active_ = !player->voidborn_reality_distort_active_;
                if (player->voidborn_reality_distort_active_) {
                    int dc = 10 + player->get_stats().divinity;
                    int confused = 0;
                    for (auto& c : combatants_) {
                        if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                        int save = dice.roll(20) + c.creature_ptr->get_stats().intellect;
                        if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Confused); confused++; }
                    }
                    last_action_log_ = current.name + " distorts reality (30 ft) — " + std::to_string(confused) + " creature(s) fail INT save (DC " + std::to_string(dc) + ")! (Max AP -3)";
                } else {
                    last_action_log_ = current.name + " collapses the void distortion.";
                }
                return true;
            }

            // ===== APEX FEATS =====

            // ArcaneOverdrive — T5, 1/LR, 5 SP: 3 rounds of triple AP regen, max melee dmg, +2 AC, immune forced movement
            if (param == "ArcaneOverdrive") {
                if (player->get_feat_tier(FeatID::ArcaneOverdrive) < 1) { last_action_log_ = current.name + ": Requires Arcane Overdrive."; return false; }
                if (!player->lr_arcane_overdrive_available_) { last_action_log_ = current.name + ": Arcane Overdrive already used this rest."; return false; }
                if (player->current_sp_ < 5) { last_action_log_ = current.name + ": Not enough SP for Arcane Overdrive (5 SP required)."; return false; }
                player->current_sp_ -= 5;
                player->lr_arcane_overdrive_available_ = false;
                player->arcane_overdrive_active_ = true;
                player->arcane_overdrive_rounds_ = 3;
                player->add_temp_ac(2);
                last_action_log_ = current.name + " enters Arcane Overdrive! 3x AP regen, max melee dmg, +2 AC for 3 rounds!";
                return true;
            }

            // BloodOfTheAncients — T5, 1/LR, 2 SP Bonus Action: 2 rounds of +2 saves, ignore first dmg/round, temp HP = DIV
            if (param == "BloodOfTheAncients") {
                if (player->get_feat_tier(FeatID::BloodOfTheAncients) < 1) { last_action_log_ = current.name + ": Requires Blood of the Ancients."; return false; }
                if (!player->lr_boa_available_) { last_action_log_ = current.name + ": Blood of the Ancients already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->lr_boa_available_ = false;
                player->boa_active_ = true;
                player->boa_rounds_ = 2;
                player->get_status().add_condition(ConditionType::Resistance);
                int temp_hp = player->get_stats().divinity;
                player->heal(temp_hp);
                last_action_log_ = current.name + " channels the Blood of the Ancients! +" + std::to_string(temp_hp) + " HP, +2 saves, ignore first damage each round for 2 rounds!";
                return true;
            }

            // CataclysmicLeap — T5, 4 AP Move: leap 100ft, 4d10 force AoE 30ft DC17 STR or prone + difficult terrain
            if (param == "CataclysmicLeap") {
                if (player->get_feat_tier(FeatID::CataclysmicLeap) < 1) { last_action_log_ = current.name + ": Requires Cataclysmic Leap."; return false; }
                int ap_cost = player->calculate_action_cost(4);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP for Cataclysmic Leap (4 AP)."; return false; }
                player->current_ap_ -= ap_cost;
                int total_dmg = dice.roll(10) + dice.roll(10) + dice.roll(10) + dice.roll(10);
                int proned = 0;
                int dc = 17;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().strength;
                    int dmg = (save >= dc) ? std::max(1, total_dmg / 2) : total_dmg;
                    c.creature_ptr->take_damage(dmg, dice);
                    if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Prone); proned++; }
                }
                last_action_log_ = current.name + " leaps 100ft and crashes down! " + std::to_string(total_dmg) + " force AoE, " + std::to_string(proned) + " creature(s) Prone (DC " + std::to_string(dc) + " STR)!";
                return true;
            }

            // DivineReversal — T5, 1/LR, reaction: arm the ability to flip the next failed save into a success
            if (param == "DivineReversal") {
                if (player->get_feat_tier(FeatID::DivineReversal) < 1) { last_action_log_ = current.name + ": Requires Divine Reversal."; return false; }
                if (!player->lr_divine_reversal_available_) { last_action_log_ = current.name + ": Divine Reversal already used this rest."; return false; }
                player->lr_divine_reversal_available_ = false;
                player->advantage_until_tick_ = std::max(player->advantage_until_tick_, 3); // grants strong advantage on next saves
                last_action_log_ = current.name + " invokes Divine Reversal — next failed save becomes a success and reflects the effect back!";
                return true;
            }

            // EclipseVeil — T5, 1/LR, 2 SP: 120ft darkness (12 rounds), DC18 INT save or disadv attacks/perception
            if (param == "EclipseVeil") {
                if (player->get_feat_tier(FeatID::EclipseVeil) < 1) { last_action_log_ = current.name + ": Requires Eclipse Veil."; return false; }
                if (!player->lr_eclipse_veil_available_) { last_action_log_ = current.name + ": Eclipse Veil already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->lr_eclipse_veil_available_ = false;
                player->eclipse_veil_active_ = true;
                player->eclipse_veil_rounds_ = 12;
                int dc = 18;
                int affected = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().intellect;
                    if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Blinded); affected++; }
                }
                last_action_log_ = current.name + " draws an Eclipse Veil — 120ft darkness for 1 minute! " + std::to_string(affected) + " enemy/enemies Blinded (DC " + std::to_string(dc) + " INT)!";
                return true;
            }

            // GravityShatter — T5, 1/LR, 2 SP: pull all within 30ft to center (Restrained), flying fall 30ft
            if (param == "GravityShatter") {
                if (player->get_feat_tier(FeatID::GravityShatter) < 1) { last_action_log_ = current.name + ": Requires Gravity Shatter."; return false; }
                if (!player->lr_gravity_shatter_available_) { last_action_log_ = current.name + ": Gravity Shatter already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->lr_gravity_shatter_available_ = false;
                int pulled = 0; int falling = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    c.creature_ptr->get_status().add_condition(ConditionType::Restrained);
                    pulled++;
                    if (c.creature_ptr->get_status().has_condition(ConditionType::Flying)) {
                        int fall_dmg = dice.roll(10) + dice.roll(10) + dice.roll(10);
                        c.creature_ptr->take_damage(fall_dmg, dice);
                        c.creature_ptr->get_status().add_condition(ConditionType::Prone);
                        c.creature_ptr->get_status().remove_condition(ConditionType::Flying);
                        falling++;
                        last_action_log_ += "\n[" + c.name + " falls 30ft: " + std::to_string(fall_dmg) + " fall damage!]";
                    }
                }
                last_action_log_ = current.name + " shatters gravity — " + std::to_string(pulled) + " creature(s) pulled and Restrained! " + std::to_string(falling) + " flying creature(s) fall 30ft!";
                return true;
            }

            // HowlOfTheForgotten — T5, 1/LR, 2 SP: DC17 INT save or Dazed, allies +2 to fear saves
            if (param == "HowlOfTheForgotten") {
                if (player->get_feat_tier(FeatID::HowlOfTheForgotten) < 1) { last_action_log_ = current.name + ": Requires Howl of the Forgotten."; return false; }
                if (!player->lr_howl_available_) { last_action_log_ = current.name + ": Howl of the Forgotten already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->lr_howl_available_ = false;
                int dc = 17;
                int dazed = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().intellect;
                    if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Dazed); dazed++; }
                }
                // Grant allies bonus advantage until next tick
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.id != current.id && ally.player_ptr)
                        ally.player_ptr->advantage_until_tick_ = std::max(ally.player_ptr->advantage_until_tick_, 1);
                }
                last_action_log_ = current.name + " unleashes the Howl of the Forgotten! " + std::to_string(dazed) + " enemy/enemies Dazed (DC " + std::to_string(dc) + " INT)! Allies resist fear!";
                return true;
            }

            // IronTempest — T5, 5 AP: 20ft AoE 6d6 slashing, DC16 STR or pushed/prone, free 30ft move
            if (param == "IronTempest") {
                if (player->get_feat_tier(FeatID::IronTempest) < 1) { last_action_log_ = current.name + ": Requires Iron Tempest."; return false; }
                if (!player->lr_iron_tempest_available_) { last_action_log_ = current.name + ": Iron Tempest already used this rest."; return false; }
                int ap_cost = player->calculate_action_cost(5);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP for Iron Tempest (5 AP)."; return false; }
                player->current_ap_ -= ap_cost;
                player->lr_iron_tempest_available_ = false;
                int total_dmg = dice.roll(6) + dice.roll(6) + dice.roll(6) + dice.roll(6) + dice.roll(6) + dice.roll(6);
                int dc = 16;
                int pushed = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().strength;
                    int dmg = (save >= dc) ? std::max(1, total_dmg / 2) : total_dmg;
                    c.creature_ptr->take_damage(dmg, dice);
                    if (save < dc) { c.creature_ptr->get_status().add_condition(ConditionType::Prone); pushed++; }
                }
                // Grant free movement (restore AP for movement)
                player->restore_ap(2);
                last_action_log_ = current.name + " unleashes Iron Tempest! " + std::to_string(total_dmg) + " slashing AoE, " + std::to_string(pushed) + " creature(s) Prone (DC " + std::to_string(dc) + ")! +2 free AP for movement!";
                return true;
            }

            // PhantomLegion — T5, 5 SP: summon 3 clones (HP=2×DIV), enemies disadvantage, clones attack in sync
            if (param == "PhantomLegion") {
                if (player->get_feat_tier(FeatID::PhantomLegion) < 1) { last_action_log_ = current.name + ": Requires Phantom Legion."; return false; }
                if (!player->lr_phantom_legion_available_) { last_action_log_ = current.name + ": Phantom Legion already used this rest."; return false; }
                if (player->current_sp_ < 5) { last_action_log_ = current.name + ": Not enough SP (5 SP required)."; return false; }
                player->current_sp_ -= 5;
                player->lr_phantom_legion_available_ = false;
                player->phantom_legion_active_ = true;
                player->phantom_legion_clones_ = 3;
                last_action_log_ = current.name + " summons the Phantom Legion! 3 clones (HP=" + std::to_string(2 * player->get_stats().divinity) + ") surround them. Enemies have disadvantage against " + current.name + "!";
                return true;
            }

            // RunebreakerSurge — T5, 1/LR, 3 SP: ignore resistance, double vs shields/constructs, second attack on hit
            if (param == "RunebreakerSurge") {
                if (player->get_feat_tier(FeatID::RunebreakerSurge) < 1) { last_action_log_ = current.name + ": Requires Runebreaker Surge."; return false; }
                if (!player->lr_runebreaker_available_) { last_action_log_ = current.name + ": Runebreaker Surge already used this rest."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                player->lr_runebreaker_available_ = false;
                player->runebreaker_active_rounds_ = 3;
                last_action_log_ = current.name + " surges with Runebreaker energy! Ignore resistance, double damage vs constructs, second attack on hit for 3 rounds!";
                return true;
            }

            // Soulbrand — T5, 1/round free: brand nearest enemy (no healing, disadv saves vs you; on death +10 HP +1 SP)
            if (param == "Soulbrand") {
                if (player->get_feat_tier(FeatID::Soulbrand) < 1) { last_action_log_ = current.name + ": Requires Soulbrand."; return false; }
                if (player->soulbrand_used_this_round_) { last_action_log_ = current.name + ": Soulbrand already used this round."; return false; }
                Combatant* q = nullptr;
                for (auto& c : combatants_) { if (!c.is_player && c.get_current_hp() > 0 && c.creature_ptr) { q = &c; break; } }
                if (!q) { last_action_log_ = current.name + ": No enemy to brand."; return false; }
                player->soulbrand_used_this_round_ = true;
                player->soulbrand_target_id_ = q->id;
                last_action_log_ = current.name + " brands " + q->name + " with a Soulbrand! Cannot heal, disadvantage on saves vs " + current.name + ". On death: +10 HP +1 SP!";
                return true;
            }

            // SoulflarePulse — T5, 1/LR, 3 SP: DC18 DIV save or Blinded+Silenced 1 min, allies +10 HP +advantage
            if (param == "SoulflarePulse") {
                if (player->get_feat_tier(FeatID::SoulflarePulse) < 1) { last_action_log_ = current.name + ": Requires Soulflare Pulse."; return false; }
                if (!player->lr_soulflare_available_) { last_action_log_ = current.name + ": Soulflare Pulse already used this rest."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                player->lr_soulflare_available_ = false;
                int dc = 18;
                int blinded = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().divinity;
                    if (save < dc) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Blinded);
                        c.creature_ptr->get_status().add_condition(ConditionType::Silent);
                        blinded++;
                    }
                }
                // Empower allies
                int ally_count = 0;
                for (auto& ally : combatants_) {
                    if (ally.is_player && ally.get_current_hp() > 0 && ally.player_ptr) {
                        ally.player_ptr->heal(10);
                        ally.player_ptr->advantage_until_tick_ = std::max(ally.player_ptr->advantage_until_tick_, 2);
                        ally_count++;
                    }
                }
                last_action_log_ = current.name + " releases a Soulflare Pulse! " + std::to_string(blinded) + " enemy/enemies Blinded+Silenced (DC " + std::to_string(dc) + " DIV), " + std::to_string(ally_count) + " ally/allies healed 10 HP + advantage!";
                return true;
            }

            // StormboundMantle — T5, 1/LR, 3 SP reaction: ranged disadv 3 rounds, melee attackers take 2d6 lightning
            if (param == "StormboundMantle") {
                if (player->get_feat_tier(FeatID::StormboundMantle) < 1) { last_action_log_ = current.name + ": Requires Stormbound Mantle."; return false; }
                if (!player->lr_stormbound_available_) { last_action_log_ = current.name + ": Stormbound Mantle already used this rest."; return false; }
                if (player->current_sp_ < 3) { last_action_log_ = current.name + ": Not enough SP (3 SP required)."; return false; }
                player->current_sp_ -= 3;
                player->lr_stormbound_available_ = false;
                player->stormbound_mantle_rounds_ = 3;
                last_action_log_ = current.name + " summons the Stormbound Mantle! Ranged attacks have disadvantage, melee attackers take 2d6 lightning for 3 rounds!";
                return true;
            }

            // TemporalRift — T5, 1/LR, 2 SP: immediate extra turn + resistance during bonus turn
            if (param == "TemporalRift") {
                if (player->get_feat_tier(FeatID::TemporalRift) < 1) { last_action_log_ = current.name + ": Requires Temporal Rift."; return false; }
                if (!player->lr_temporal_rift_available_) { last_action_log_ = current.name + ": Temporal Rift already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->lr_temporal_rift_available_ = false;
                player->temporal_rift_active_ = true;
                // Grant a full extra turn's worth of AP + resistance
                player->restore_ap(player->get_max_ap());
                player->get_status().add_condition(ConditionType::Resistance);
                last_action_log_ = current.name + " rips open a Temporal Rift — gains a full extra turn! Resistance to all damage this bonus turn!";
                return true;
            }

            // TitansEcho — T5, 5 AP: VIT save DC18 or Deafened+Prone 300ft, 4d10 thunder to structures
            if (param == "TitansEcho") {
                if (player->get_feat_tier(FeatID::TitansEcho) < 1) { last_action_log_ = current.name + ": Requires Titan's Echo."; return false; }
                if (!player->lr_titans_echo_available_) { last_action_log_ = current.name + ": Titan's Echo already used this rest."; return false; }
                int ap_cost = player->calculate_action_cost(5);
                if (player->current_ap_ < ap_cost) { last_action_log_ = current.name + ": Not enough AP for Titan's Echo (5 AP)."; return false; }
                player->current_ap_ -= ap_cost;
                player->lr_titans_echo_available_ = false;
                int dc = 18;
                int affected = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().vitality;
                    if (save < dc) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Deafened);
                        c.creature_ptr->get_status().add_condition(ConditionType::Prone);
                        c.creature_ptr->get_status().add_condition(ConditionType::Fear);
                        affected++;
                    }
                }
                int thunder_dmg = dice.roll(10) + dice.roll(10) + dice.roll(10) + dice.roll(10);
                last_action_log_ = current.name + " unleashes Titan's Echo! " + std::to_string(affected) + " enemy/enemies Deafened+Frightened+Prone (DC " + std::to_string(dc) + " VIT)! " + std::to_string(thunder_dmg) + " thunder damage to structures!";
                return true;
            }

            // VoidbrandCurse — T5, 1/LR, arm: next melee hit curses target 2 rounds (no healing, -2 saves); on death +10 HP +1 SP
            if (param == "VoidbrandCurse") {
                if (player->get_feat_tier(FeatID::VoidbrandCurse) < 1) { last_action_log_ = current.name + ": Requires Voidbrand Curse."; return false; }
                if (!player->lr_voidbrand_available_) { last_action_log_ = current.name + ": Voidbrand Curse already used this rest."; return false; }
                if (player->current_sp_ < 2) { last_action_log_ = current.name + ": Not enough SP (2 SP required)."; return false; }
                player->current_sp_ -= 2;
                player->lr_voidbrand_available_ = false;
                player->voidbrand_primed_ = true;
                last_action_log_ = current.name + " arms the Voidbrand Curse — next melee hit brands target: no healing, -2 saves for 2 rounds. On death: +10 HP +1 SP!";
                return true;
            }

            // WorldbreakerStepCheck — T5, passive: manually trigger check if >50ft moved this turn
            if (param == "WorldbreakerStepCheck") {
                if (player->get_feat_tier(FeatID::WorldbreakerStep) < 1) { last_action_log_ = current.name + ": Requires Worldbreaker Step."; return false; }
                if (player->worldbreaker_step_movement_this_turn_ < 10) { last_action_log_ = current.name + ": Worldbreaker Step requires >50ft movement this turn."; return false; }
                int dc = 16;
                int proned = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int save = dice.roll(20) + c.creature_ptr->get_stats().strength;
                    if (save < dc) {
                        c.creature_ptr->get_status().add_condition(ConditionType::Prone);
                        int wb_dmg = dice.roll(10);
                        c.creature_ptr->take_damage(wb_dmg, dice);
                        proned++;
                        last_action_log_ += "\n[" + c.name + " fails STR save: Prone + " + std::to_string(wb_dmg) + " bludgeoning!]";
                    }
                }
                last_action_log_ = current.name + "'s Worldbreaker Step triggers! " + std::to_string(proned) + " creature(s) Prone+damaged in the devastated path!";
                return true;
            }

            last_action_log_ = current.name + ": Unknown lineage trait '" + param + "'.";
            return false;
        }
        default: return false;
    }
}

void CombatManager::execute_spell(Combatant& caster, const std::string& spell_name, Combatant* target, Dice& dice, bool is_activation, bool skip_attack_roll) {
    const auto* spell = SpellRegistry::instance().find_spell(spell_name);
    if (!spell) return;

    if (is_activation) {
        last_action_log_ = caster.name + " activates " + spell->name + "!";
    } else {
        last_action_log_ = caster.name + " cast " + spell->name + "!";
    }

    // Nullborn: Void Aura — enemy spells have 50% failure chance while aura is active
    if (!caster.is_player) {
        for (auto& ally : combatants_) {
            if (ally.is_player && ally.player_ptr &&
                ally.player_ptr->get_lineage().name == "Nullborn" &&
                ally.player_ptr->void_aura_rounds_ > 0) {
                if (dice.roll(2) == 1) {
                    last_action_log_ += "\n[Void Aura: " + ally.name + "'s anti-magic field disrupts the spell!]";
                    return;
                }
                break;
            }
        }
    }

    SpellMatrix* matrix = nullptr;
    auto matrix_it = std::find_if(caster.active_matrices.begin(), caster.active_matrices.end(),
        [&](const SpellMatrix& m) { return m.spell_name == spell_name; });
    if (matrix_it != caster.active_matrices.end()) matrix = &(*matrix_it);

    if (target && !spell->conditions.empty()) {
        bool already_affected = false;
        if (matrix) {
            already_affected = std::find(matrix->affected_entities.begin(), matrix->affected_entities.end(), target->id) != matrix->affected_entities.end();
        }

        if (already_affected) {
            last_action_log_ += " Effect already active on " + target->name + ".";
            return;
        }

        if (matrix && (int)matrix->affected_entities.size() >= spell->max_targets) {
            std::string old_id = matrix->affected_entities.front();
            auto* old_target = find_combatant_by_id(old_id);
            if (old_target) {
                for (auto cond : spell->conditions) {
                    if (old_target->is_player && old_target->player_ptr) old_target->player_ptr->get_status().remove_condition(cond);
                    else if (old_target->creature_ptr) old_target->creature_ptr->get_status().remove_condition(cond);
                }
            }
            matrix->affected_entities.erase(matrix->affected_entities.begin());
            last_action_log_ += " [Effect moved from " + (old_target ? old_target->name : "old target") + "]";
        }
    }

    std::string roll_details;

    if (spell->is_attack && target && !skip_attack_roll) {
        RollResult attack_roll;
        if (caster.is_player && caster.player_ptr) {
            attack_roll = caster.player_ptr->roll_magic_attack(dice);
            // Runeborn Human: Runic Surge — primed +1d4 bonus to spell attack roll
            if (caster.player_ptr->runic_surge_primed_) {
                int surge_bonus = dice.roll(4);
                attack_roll.total += surge_bonus;
                caster.player_ptr->runic_surge_primed_ = false;
                roll_details += " [Runic Surge: +" + std::to_string(surge_bonus) + "]";
            }
            // Sparkforged Human: Arcane Surge — primed +2 to spell attack roll
            if (caster.player_ptr->sparkforged_arcane_surge_primed_) {
                attack_roll.total += 2;
                caster.player_ptr->sparkforged_arcane_surge_primed_ = false;
                roll_details += " [Arcane Surge: +2]";
            }
            // Groblodyte: Arcane Misfire — natural 1 on spell attack deals 1d6 to self
            if (attack_roll.is_critical_failure && caster.player_ptr->get_lineage().name == "Groblodyte") {
                int misfire = dice.roll(6);
                caster.player_ptr->take_damage(misfire, dice);
                last_action_log_ += " [Arcane Misfire: " + caster.name + " takes " + std::to_string(misfire) + " overcharge!]";
            }
        } else if (caster.creature_ptr) {
            attack_roll = dice.roll_d20(RollType::Normal, caster.creature_ptr->get_stats().intellect);
        }

        // Dodging: caster rolls at disadvantage
        {
            auto* ts = (target->is_player && target->player_ptr) ? &target->player_ptr->get_status() : (target->creature_ptr ? &target->creature_ptr->get_status() : nullptr);
            bool caster_has_advantage = (caster.is_player && caster.player_ptr && caster.player_ptr->advantage_until_tick_ > 0);
            if (ts && ts->has_condition(ConditionType::Dodging) && !caster_has_advantage) {
                int reroll = dice.roll(20);
                if (reroll < attack_roll.die_roll) {
                    attack_roll.die_roll = reroll;
                    attack_roll.total = reroll + attack_roll.modifier;
                    attack_roll.is_critical_success = (reroll >= 20);
                    attack_roll.is_critical_failure = (reroll <= 1);
                }
            }
        }

        int target_ac = (target->is_player && target->player_ptr) ? target->player_ptr->get_armor_class() : (target->creature_ptr ? (10 + target->creature_ptr->get_stats().speed) : 10);
        roll_details = " (Attack: " + std::to_string(attack_roll.die_roll) + "+" + std::to_string(attack_roll.modifier) + "=" + std::to_string(attack_roll.total) + " vs AC " + std::to_string(target_ac) + ")";

        if (attack_roll.total < target_ac) {
            last_action_log_ += roll_details + " - MISS.";
            return;
        }
        roll_details += " - HIT!";
    } else if (spell->is_attack && target && skip_attack_roll) {
        roll_details = " (Matrix auto-hit!)";
    }

    // Invulnerable target: skip damage
    if (target && spell->die_count > 0 && !spell->is_healing) {
        auto* ts = (target->is_player && target->player_ptr) ? &target->player_ptr->get_status() : (target->creature_ptr ? &target->creature_ptr->get_status() : nullptr);
        if (ts && ts->has_condition(ConditionType::Invulnerable)) {
            last_action_log_ += " " + target->name + " is Invulnerable — damage blocked!";
            return;
        }
    }

    if (spell->die_count > 0) {
        int total = 0;
        std::string rolls_str;
        bool me_maximized = false; // MagicExpertise T3: maximize first die once per turn
        for (int i = 0; i < spell->die_count; ++i) {
            int r = dice.roll(spell->die_sides);
            // MagicExpertise T3: once per turn, maximize one damage die
            if (!spell->is_healing && caster.is_player && caster.player_ptr &&
                caster.player_ptr->get_feat_tier(FeatID::MagicExpertise) >= 3 &&
                !caster.player_ptr->me_max_die_used_this_turn_ && !me_maximized) {
                r = spell->die_sides;
                me_maximized = true;
                caster.player_ptr->me_max_die_used_this_turn_ = true;
            }
            total += r;
            rolls_str += std::to_string(r) + (i == spell->die_count - 1 ? "" : "+");
        }
        // BloodMagic T2: add Vitality score to spell damage or healing rolls
        if (caster.is_player && caster.player_ptr && caster.player_ptr->get_feat_tier(FeatID::BloodMagic) >= 2) {
            int vit = caster.player_ptr->get_stats().vitality;
            total += vit;
            rolls_str += "+" + std::to_string(vit) + "(BloodVIT)";
        }

        if (spell->is_healing) {
            auto* heal_target = target ? target : &caster;
            // HealingRestoration: add DIV bonus to healing spells
            if (caster.is_player && caster.player_ptr) {
                int hr_bonus = caster.player_ptr->get_healing_bonus();
                if (hr_bonus > 0) {
                    total += hr_bonus;
                    rolls_str += "+" + std::to_string(hr_bonus) + "(HR)";
                }
            }
            if (spell->name == "Revivify" && heal_target->is_player && heal_target->player_ptr && heal_target->player_ptr->get_current_hp() <= 0) {
                heal_target->player_ptr->revivify();
                last_action_log_ += roll_details + " " + heal_target->name + " has been revived with 1 HP!";
            } else {
                if (heal_target->is_player && heal_target->player_ptr) {
                    heal_target->player_ptr->heal(total);
                    // HealingRestoration T3: remove one condition on heal
                    if (caster.is_player && caster.player_ptr && caster.player_ptr->can_remove_condition_on_heal()) {
                        heal_target->player_ptr->get_status().remove_one_condition();
                    }
                } else if (heal_target->creature_ptr) heal_target->creature_ptr->heal(total);
                last_action_log_ += roll_details + " Healed " + heal_target->name + " for " + std::to_string(total) + " HP. (Roll: " + rolls_str + ")";
            }
        } else if (target) {
            if (target->get_current_hp() > 0) {
                int adjusted_total = total;
                bool fire_halved = false;
                bool scales_ignited = false;
                bool poison_halved = false;
                bool cold_halved = false;
                if (spell->damage_type == DamageType::Cold) {
                    if (target->is_player && target->player_ptr && target->player_ptr->has_cold_immunity_) {
                        adjusted_total = 0;
                        cold_halved = true;
                    } else if (target->is_player && target->player_ptr && target->player_ptr->has_cold_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                        cold_halved = true;
                    }
                }
                if (spell->damage_type == DamageType::Fire) {
                    if (target->is_player && target->player_ptr && target->player_ptr->has_fire_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                        fire_halved = true;
                    }
                    if (target->is_player && target->player_ptr &&
                        target->player_ptr->get_lineage().name == "Goldscale") {
                        target->player_ptr->get_status().add_condition(ConditionType::HeatedScales);
                        scales_ignited = true;
                    }
                } else if (spell->damage_type == DamageType::Poison) {
                    // Myconid/Chokeling: poison resistance
                    if (target->is_player && target->player_ptr && target->player_ptr->has_poison_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                        poison_halved = true;
                    }
                } else if (spell->damage_type == DamageType::Necrotic) {
                    // Jackal Human / Gravetouched / Obsidian Seraph: necrotic resistance
                    if (target->is_player && target->player_ptr && target->player_ptr->has_necrotic_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                    }
                } else if (spell->damage_type == DamageType::Acid) {
                    // Rustspawn: acid resistance
                    if (target->is_player && target->player_ptr && target->player_ptr->has_acid_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                    }
                } else if (spell->damage_type == DamageType::Psychic) {
                    // Madness-Touched Human: psychic resistance
                    if (target->is_player && target->player_ptr && target->player_ptr->has_psychic_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                    }
                } else if (spell->damage_type == DamageType::Radiant) {
                    // Glassborn / Obsidian Seraph / Luminar Human: radiant resistance; Lightbound Radiant Ward
                    if (target->is_player && target->player_ptr &&
                        (target->player_ptr->has_radiant_resistance_ || target->player_ptr->radiant_ward_rounds_ > 0)) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                    }
                } else if (spell->damage_type == DamageType::Lightning) {
                    // Stormclad / Obsidian: lightning resistance
                    if (target->is_player && target->player_ptr && target->player_ptr->has_lightning_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                    }
                } else if (spell->damage_type == DamageType::Thunder) {
                    // Stormclad / Obsidian: thunder resistance
                    if (target->is_player && target->player_ptr && target->player_ptr->has_thunder_resistance_) {
                        adjusted_total = std::max(1, adjusted_total / 2);
                    }
                }
                // Obsidian: Magma Blood — heal 1d4 when taking elemental damage
                if (target->is_player && target->player_ptr &&
                    target->player_ptr->get_lineage().name == "Obsidian" && adjusted_total > 0 &&
                    (spell->damage_type == DamageType::Fire || spell->damage_type == DamageType::Cold ||
                     spell->damage_type == DamageType::Lightning || spell->damage_type == DamageType::Thunder ||
                     spell->damage_type == DamageType::Acid || spell->damage_type == DamageType::Radiant)) {
                    int magma_heal = dice.roll(4);
                    target->player_ptr->heal(magma_heal);
                    last_action_log_ += " [Magma Blood: healed " + std::to_string(magma_heal) + "!]";
                }
                // Rustspawn: Ironrot — accumulate stacks when hit by acid spells
                if (spell->damage_type == DamageType::Acid && caster.is_player && caster.player_ptr) {
                    caster.player_ptr->ironrot_acid_stacks_++;
                    last_action_log_ += " [Ironrot on " + caster.name + ": stack " + std::to_string(caster.player_ptr->ironrot_acid_stacks_) + "]";
                }
                // Obsidian Seraph: Cracked Resilience — accumulate stacks when hit by magic damage
                if (target->is_player && target->player_ptr &&
                    target->player_ptr->get_lineage().name == "Obsidian Seraph" && adjusted_total > 0) {
                    target->player_ptr->cracked_resilience_stacks_ += std::max(1, adjusted_total / 4);
                    last_action_log_ += " [Cracked Resilience: +" + std::to_string(std::max(1, adjusted_total / 4)) + " stack!]";
                }
                // Vulnerable: target takes double damage
                {
                    auto* ts = (target->is_player && target->player_ptr) ? &target->player_ptr->get_status() : (target->creature_ptr ? &target->creature_ptr->get_status() : nullptr);
                    if (ts && ts->has_condition(ConditionType::Vulnerable)) {
                        adjusted_total *= 2;
                        last_action_log_ += " [Vulnerable: x2!]";
                    }
                }
                int spell_prev_target_hp = target->get_current_hp();
                if (target->is_player && target->player_ptr) target->player_ptr->take_damage(adjusted_total, dice);
                else if (target->creature_ptr) target->creature_ptr->take_damage(adjusted_total, dice);

                std::string dam_type_str = "Force";
                switch(spell->damage_type) {
                    case DamageType::Bludgeoning: dam_type_str = "Bludgeoning"; break;
                    case DamageType::Piercing: dam_type_str = "Piercing"; break;
                    case DamageType::Slashing: dam_type_str = "Slashing"; break;
                    case DamageType::Fire: dam_type_str = "Fire"; break;
                    case DamageType::Cold: dam_type_str = "Cold"; break;
                    case DamageType::Lightning: dam_type_str = "Lightning"; break;
                    case DamageType::Acid: dam_type_str = "Acid"; break;
                    case DamageType::Poison: dam_type_str = "Poison"; break;
                    case DamageType::Radiant: dam_type_str = "Radiant"; break;
                    case DamageType::Necrotic: dam_type_str = "Necrotic"; break;
                    case DamageType::Psychic: dam_type_str = "Psychic"; break;
                    case DamageType::Thunder: dam_type_str = "Thunder"; break;
                    case DamageType::Force: dam_type_str = "Force"; break;
                }

                last_action_log_ += roll_details + " Dealt " + std::to_string(adjusted_total) + " " + dam_type_str + " damage to " + target->name + ". (Roll: " + rolls_str + ")";
                if (cold_halved) last_action_log_ += " [Cold Resistance: halved]";
                if (fire_halved) last_action_log_ += " [Fire Resistance: halved]";
                if (scales_ignited) last_action_log_ += " [Heated Scales ignited!]";
                if (poison_halved) last_action_log_ += " [Poison Resistance: halved]";

                if (target->get_current_hp() <= 0 && dungeon_mode_) {
                    DungeonManager::instance().remove_dead_entities();
                }
                // Sparkforged Human: Overload Pulse — 2d6 force AoE when killed by a spell
                if (target->is_player && target->player_ptr &&
                    target->player_ptr->get_lineage().name == "Sparkforged Human" &&
                    target->get_current_hp() <= 0 && spell_prev_target_hp > 0) {
                    int pulse = dice.roll(6) + dice.roll(6);
                    for (auto& c : combatants_) {
                        if (c.id == target->id || c.get_current_hp() <= 0) continue;
                        if (DungeonManager::instance().get_distance(target->id, c.id) <= 2) {
                            if (c.is_player && c.player_ptr) c.player_ptr->take_damage(pulse, dice);
                            else if (c.creature_ptr) c.creature_ptr->take_damage(pulse, dice);
                        }
                    }
                    target->player_ptr->take_damage(pulse, dice);
                    last_action_log_ += " [Overload Pulse: " + std::to_string(pulse) + " force AoE!]";
                }
                // BloodMagic T5: Blood Archon — on kill with a spell, regain 2×DIV HP + free spell available
                if (caster.is_player && caster.player_ptr &&
                    caster.player_ptr->get_feat_tier(FeatID::BloodMagic) >= 5 &&
                    spell_prev_target_hp > 0 && target->get_current_hp() <= 0) {
                    int div = caster.player_ptr->get_stats().divinity;
                    caster.player_ptr->heal(2 * div);
                    last_action_log_ += " [Blood Archon: regained " + std::to_string(2 * div) + " HP on kill! Free blood magic spell available.]";
                }
                // BloodMagic T4: Blood Sage — 1/LR regain SP equal to DIV on kill
                if (caster.is_player && caster.player_ptr &&
                    caster.player_ptr->get_feat_tier(FeatID::BloodMagic) >= 4 &&
                    !caster.player_ptr->lr_bm_kill_sp_regain_used_ &&
                    spell_prev_target_hp > 0 && target->get_current_hp() <= 0) {
                    int div = caster.player_ptr->get_stats().divinity;
                    caster.player_ptr->restore_sp(div);
                    caster.player_ptr->lr_bm_kill_sp_regain_used_ = true;
                    last_action_log_ += " [Blood Sage: regained " + std::to_string(div) + " SP on kill!]";
                }
            }
        }
    } else if (target) {
        last_action_log_ += roll_details + " Effect applied to " + target->name + ".";
    } else {
        last_action_log_ += roll_details + " Effect applied.";
    }

    // Telekinesis: Animate Weapon — mark weapon as animated on caster
    if (spell_name == "Telekinesis: Animate Weapon" && caster.is_player && caster.player_ptr) {
        // Collapse duplicate matrices — only one Animate Weapon matrix should exist at a time
        int tk_matrix_count = static_cast<int>(std::count_if(caster.active_matrices.begin(), caster.active_matrices.end(),
            [](const SpellMatrix& m) { return m.spell_name == "Telekinesis: Animate Weapon"; }));
        if (tk_matrix_count > 1) {
            // Remove the most recently pushed duplicate (last in the list)
            auto last_it = std::find_if(caster.active_matrices.rbegin(), caster.active_matrices.rend(),
                [](const SpellMatrix& m) { return m.spell_name == "Telekinesis: Animate Weapon"; });
            if (last_it != caster.active_matrices.rend()) {
                caster.active_matrices.erase(std::next(last_it).base());
            }
        }
        caster.player_ptr->tk_animate_weapon_active_ = true;
        caster.player_ptr->tk_animate_weapon_sp_committed_ += 2;
        int atk_count = caster.player_ptr->tk_animate_weapon_sp_committed_ / 2;
        last_action_log_ += " [Animated Weapon: now " + std::to_string(atk_count) + " attack(s)/round, " + std::to_string(atk_count * 15) + " ft move.]";
    }

    // Telekinesis: Animate Shield / Tower Shield — grant AC bonus without equipping
    if ((spell_name == "Telekinesis: Animate Shield" || spell_name == "Telekinesis: Animate Tower Shield") && caster.is_player && caster.player_ptr) {
        if (caster.player_ptr->tk_animated_shield_ac_bonus_ != 0) {
            last_action_log_ += " [Already have an animated shield — dismiss the current one first.]";
        } else {
            // Derive AC bonus: use equipped shield if available, otherwise defaults
            int ac_bonus = (spell_name == "Telekinesis: Animate Tower Shield") ? 3 : 2;
            if (caster.player_ptr->get_shield() && !caster.player_ptr->get_shield()->is_broken()) {
                ac_bonus = caster.player_ptr->get_shield()->get_ac_bonus();
            }
            caster.player_ptr->tk_animated_shield_ac_bonus_ = ac_bonus;
            last_action_log_ += " [Animated Shield active: +" + std::to_string(ac_bonus) + " AC!]";
        }
    }

    if (target && !spell->conditions.empty()) {
        // Saving throw for non-attack spells targeting an unwilling recipient (opposite side).
        // Pure healing spells and self-buffs never reach here with a cross-side target.
        // Bless spells on allies (both players) skip this since caster.is_player == target->is_player.
        bool condition_blocked = false;
        if (!spell->is_attack && (caster.is_player != target->is_player)) {
            int dc = 10 + (caster.is_player && caster.player_ptr ? caster.player_ptr->get_stats().divinity : 2);
            int save_mod = 0;
            if (target->is_player && target->player_ptr) {
                save_mod = target->player_ptr->get_stats().divinity;
            } else if (target->creature_ptr) {
                save_mod = target->creature_ptr->get_stats().divinity;
            }
            int save_roll = dice.roll(20);
            int save_total = save_roll + save_mod;
            if (save_total >= dc) {
                condition_blocked = true;
                last_action_log_ += " [Save: " + std::to_string(save_roll) + "+" + std::to_string(save_mod) + "=" + std::to_string(save_total) + " vs DC " + std::to_string(dc) + " — " + target->name + " resists!]";
            } else {
                last_action_log_ += " [Save: " + std::to_string(save_roll) + "+" + std::to_string(save_mod) + "=" + std::to_string(save_total) + " vs DC " + std::to_string(dc) + " — effect lands!]";
            }
        }

        if (!condition_blocked) {
            // Hexshell: Reflect Hex — if primed, redirect condition to caster
            Combatant* condition_target = target;
            if (target->is_player && target->player_ptr && target->player_ptr->reflect_hex_primed_) {
                target->player_ptr->reflect_hex_primed_ = false;
                condition_target = &caster;
                last_action_log_ += " [Reflect Hex: condition reflected to " + caster.name + "!]";
            }
            // Weirkin Human: Weird Resilience — if primed, redirect condition to caster
            if (target->is_player && target->player_ptr && target->player_ptr->weird_resilience_primed_) {
                target->player_ptr->weird_resilience_primed_ = false;
                condition_target = &caster;
                last_action_log_ += " [Weird Resilience: condition reflected to " + caster.name + "!]";
            }
            for (auto condition : spell->conditions) {
                if (condition_target->is_player && condition_target->player_ptr) {
                    condition_target->player_ptr->get_status().add_condition(condition);
                } else if (condition_target->creature_ptr) {
                    condition_target->creature_ptr->get_status().add_condition(condition);
                }
                last_action_log_ += " [" + StatusManager::get_condition_name(condition) + " applied]";
            }
            if (matrix) matrix->affected_entities.push_back(target->id);
        }
    }
}

bool CombatManager::execute_attack(Combatant& attacker, Combatant& target, Dice& dice, bool is_unarmed, int elevation_mod) {
    RollResult attack_roll;
    int damage = 0;
    bool is_critical = false;
    std::string damage_roll_str;

    // Bookborn: cannot attack while in Origami form
    if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->bookborn_origami_active_) {
        last_action_log_ = attacker.name + " cannot attack while folded (Origami)!";
        return false;
    }

    // Calm: cannot take hostile actions
    {
        bool calm = (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_status().has_condition(ConditionType::Calm)) ||
                    (!attacker.is_player && attacker.creature_ptr && attacker.creature_ptr->get_status().has_condition(ConditionType::Calm));
        if (calm) {
            last_action_log_ = attacker.name + " is Calm and cannot take hostile actions!";
            return false;
        }
    }

    // Invulnerable: immune to damage
    {
        bool inv = (target.is_player && target.player_ptr && target.player_ptr->get_status().has_condition(ConditionType::Invulnerable)) ||
                   (!target.is_player && target.creature_ptr && target.creature_ptr->get_status().has_condition(ConditionType::Invulnerable));
        if (inv) {
            last_action_log_ = target.name + " is Invulnerable and cannot be harmed!";
            return false;
        }
    }

    if (attacker.is_player && attacker.player_ptr) {
        int ruthless_tier = attacker.player_ptr->get_feat_tier(FeatID::AssassinsExecution);
        bool use_ruthless = (ruthless_tier >= 2 && attacker.player_ptr->has_ruthless_crit_available_ && !target.has_acted);

        if (use_ruthless) {
            attack_roll = attacker.player_ptr->roll_attack(dice, is_unarmed ? nullptr : attacker.player_ptr->get_weapon());
            attack_roll.is_critical_success = true;
            attack_roll.total = 99;
            attacker.player_ptr->has_ruthless_crit_available_ = false;
        } else {
            attack_roll = attacker.player_ptr->roll_attack(dice, is_unarmed ? nullptr : attacker.player_ptr->get_weapon());
        }
        // BiologicalDomain T2: Verdant Channeler — bonus to attack equal to SP spent on last bio spell
        if (attacker.player_ptr->bio_attack_bonus_pending_ > 0) {
            attack_roll.total += attacker.player_ptr->bio_attack_bonus_pending_;
            damage_roll_str += " [VerdantBonus:+" + std::to_string(attacker.player_ptr->bio_attack_bonus_pending_) + "]";
            attacker.player_ptr->bio_attack_bonus_pending_ = 0;
        }
        // CulinaryVirtuoso T2: Alchemical Chef — +2 to attack rolls (dish consumed)
        if (attacker.player_ptr->culinary_attack_bonus_rounds_ > 0) {
            attack_roll.total += 2;
            attacker.player_ptr->culinary_attack_bonus_rounds_--;
            damage_roll_str += " [CulinaryDish:+2]";
        }
        // CraftingArtifice T3: energy core pending damage bonus
        if (attacker.player_ptr->ca_core_damage_bonus_pending_ > 0) {
            damage_roll_str += " [CoreBonus:+" + std::to_string(attacker.player_ptr->ca_core_damage_bonus_pending_) + "]";
        }
        // Diseased: -2 penalty to attack rolls
        if (attacker.player_ptr->get_status().has_condition(ConditionType::Diseased)) {
            attack_roll.total -= 2;
            damage_roll_str += " [Diseased:-2atk]";
        }

        if (is_unarmed) {
            int iron_fist_tier = attacker.player_ptr->get_feat_tier(FeatID::IronFist);
            int r;
            if (iron_fist_tier >= 3) r = dice.roll(10);
            else if (iron_fist_tier >= 2) r = dice.roll(8);
            else if (iron_fist_tier >= 1) r = dice.roll(6);
            else r = dice.roll(4);
            int mod = attacker.player_ptr->get_stats().strength;
            // Iron Fist T3: 2x stat to damage
            if (iron_fist_tier >= 3) mod = 2 * mod;
            damage = r + mod;
            damage_roll_str = std::to_string(r) + "+" + std::to_string(mod);
            // Iron Fist T3: choose max damage (auto-consume if uses remain)
            if (iron_fist_tier >= 3 && attacker.player_ptr->if_max_damage_uses_remaining_ > 0) {
                int max_dmg = (iron_fist_tier >= 3 ? 10 : (iron_fist_tier >= 2 ? 8 : 6)) + mod;
                if (max_dmg > damage) { damage = max_dmg; damage_roll_str += "[Max]"; attacker.player_ptr->if_max_damage_uses_remaining_--; }
            }
        } else {
            Weapon* weapon = attacker.player_ptr->get_weapon();
            int r = 0;
            int mod = attacker.player_ptr->get_stats().strength;

            if (weapon) {
                bool is_speed_weapon = false;
                for (const auto& prop : weapon->get_properties()) {
                    if (prop == "Finesse" || prop.find("Range") != std::string::npos) {
                        is_speed_weapon = true; break;
                    }
                }
                if (is_speed_weapon) mod = attacker.player_ptr->get_stats().speed;

                // SwiftStriker T2: 2x stat for simple weapons
                int ss_tier = attacker.player_ptr->get_feat_tier(FeatID::SwiftStriker);
                if (ss_tier >= 2 && weapon->get_category() == WeaponCategory::Simple) mod *= 2;

                // TitanicDamage T2: 2x stat for martial weapons
                int td_tier = attacker.player_ptr->get_feat_tier(FeatID::TitanicDamage);
                if (td_tier >= 2 && weapon->get_category() == WeaponCategory::Martial) mod *= 2;

                int hammer_tier = attacker.player_ptr->get_feat_tier(FeatID::IronHammer);
                int edge_tier = attacker.player_ptr->get_feat_tier(FeatID::CrimsonEdge);
                int thorn_tier = attacker.player_ptr->get_feat_tier(FeatID::IronThorn);

                if (weapon->get_damage_type() == DamageType::Bludgeoning && hammer_tier >= 2) {
                    std::string formula = weapon->get_damage_dice();
                    if (hammer_tier >= 5) {
                        if (formula == "1d12" || formula == "2d6") formula = "2d12";
                        else formula = "1d12";
                    } else if (hammer_tier >= 3) {
                        if (formula == "1d10") formula = "2d10";
                        else formula = "1d10";
                    } else if (hammer_tier >= 2) {
                        if (formula == "1d8") formula = "2d8";
                        else formula = "1d8";
                    }
                    r = dice.roll_string(formula);
                } else if (weapon->get_damage_type() == DamageType::Slashing && edge_tier >= 2) {
                    std::string formula = weapon->get_damage_dice();
                    if (edge_tier >= 5) formula = "1d10";
                    else if (edge_tier >= 3) formula = "1d8";
                    else if (weapon->get_category() == WeaponCategory::Simple) formula = "1d6";
                    r = dice.roll_string(formula);
                } else if (weapon->get_damage_type() == DamageType::Piercing && thorn_tier >= 2) {
                    std::string formula = weapon->get_damage_dice();
                    if (thorn_tier >= 5) formula = "1d10";
                    else if (thorn_tier >= 3) formula = "1d8";
                    else if (thorn_tier >= 2 && weapon->get_category() == WeaponCategory::Simple) formula = "1d6";
                    r = dice.roll_string(formula);
                } else {
                    r = dice.roll_string(weapon->get_damage_dice());
                }

                // TitanicDamage T3 / SwiftStriker T3: choose max damage (auto-consume if uses remain)
                if (td_tier >= 3 && weapon->get_category() == WeaponCategory::Martial && attacker.player_ptr->td_max_damage_uses_remaining_ > 0) {
                    int base_faces = 8;
                    r = base_faces; // approximate max die
                    damage_roll_str = "[MaxDmg-TD]";
                    attacker.player_ptr->td_max_damage_uses_remaining_--;
                }
                if (ss_tier >= 3 && weapon->get_category() == WeaponCategory::Simple && attacker.player_ptr->ss_max_damage_uses_remaining_ > 0) {
                    int base_faces = 6;
                    r = base_faces;
                    damage_roll_str = "[MaxDmg-SS]";
                    attacker.player_ptr->ss_max_damage_uses_remaining_--;
                }
            } else {
                r = dice.roll(8);
            }

            damage = r + mod;
            if (weapon && weapon->is_broken()) {
                damage /= 2;
                damage_roll_str = "(" + std::to_string(r) + "+" + std::to_string(mod) + ")/2 [Broken]";
            } else {
                damage_roll_str = std::to_string(r) + "+" + std::to_string(mod);
            }
        }
        is_critical = attack_roll.is_critical_success;
    } else if (attacker.creature_ptr) {
        attack_roll = dice.roll_d20(RollType::Normal, attacker.creature_ptr->get_stats().strength);
        int r = dice.roll(8);
        int mod = attacker.creature_ptr->get_stats().strength;
        damage = r + mod;
        damage_roll_str = std::to_string(r) + "+" + std::to_string(mod);
        is_critical = attack_roll.is_critical_success;
    }

    // Canidar: Pack Tactics — advantage if an ally is adjacent to the target
    if (attacker.is_player && attacker.player_ptr &&
        attacker.player_ptr->get_lineage().name == "Canidar" &&
        attacker.player_ptr->advantage_until_tick_ <= 0 && !attack_roll.is_critical_success) {
        for (const auto& ally : combatants_) {
            if (ally.id != attacker.id && ally.is_player && ally.get_current_hp() > 0) {
                if (DungeonManager::instance().get_distance(ally.id, target.id) <= 1) {
                    RollResult reroll = attacker.player_ptr->roll_attack(dice, is_unarmed ? nullptr : attacker.player_ptr->get_weapon());
                    if (reroll.total > attack_roll.total) attack_roll = reroll;
                    damage_roll_str += " [Pack Tactics]";
                    break;
                }
            }
        }
    }

    // Auto-hit conditions on target
    bool target_auto_hit = false;
    {
        auto* ts = (target.is_player && target.player_ptr) ? &target.player_ptr->get_status() : (target.creature_ptr ? &target.creature_ptr->get_status() : nullptr);
        if (ts && (ts->has_condition(ConditionType::Paralyzed) || ts->has_condition(ConditionType::Unconscious) || ts->has_condition(ConditionType::Incapacitated) || ts->has_condition(ConditionType::Petrified))) {
            target_auto_hit = true;
            attack_roll.total = 999;
            attack_roll.is_critical_success = true;
        }
    }

    // Dodging: attacker rolls at disadvantage (reroll, take worse)
    if (!target_auto_hit) {
        auto* ts = (target.is_player && target.player_ptr) ? &target.player_ptr->get_status() : (target.creature_ptr ? &target.creature_ptr->get_status() : nullptr);
        bool attacker_has_advantage = (attacker.is_player && attacker.player_ptr && (attacker.player_ptr->advantage_until_tick_ > 0));
        if (ts && ts->has_condition(ConditionType::Dodging) && !attacker_has_advantage) {
            int reroll = dice.roll(20);
            if (reroll < attack_roll.die_roll) {
                attack_roll.die_roll = reroll;
                attack_roll.total = reroll + attack_roll.modifier;
                attack_roll.is_critical_success = (reroll >= 20);
                attack_roll.is_critical_failure = (reroll <= 1);
            }
        }
    }

    // Prone: melee attackers gain advantage, ranged attackers suffer disadvantage
    if (!target_auto_hit) {
        auto* ts = (target.is_player && target.player_ptr) ? &target.player_ptr->get_status() : (target.creature_ptr ? &target.creature_ptr->get_status() : nullptr);
        if (ts && ts->has_condition(ConditionType::Prone)) {
            bool attacker_is_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_is_ranged = true; break; }
            }
            if (attacker_is_ranged) {
                // Ranged: disadvantage — reroll, take worse
                int reroll = dice.roll(20);
                if (reroll < attack_roll.die_roll) {
                    attack_roll.die_roll = reroll;
                    attack_roll.total = reroll + attack_roll.modifier;
                    attack_roll.is_critical_success = (reroll >= 20);
                    attack_roll.is_critical_failure = (reroll <= 1);
                }
                damage_roll_str += " [Prone-RngDisadv]";
            } else {
                // Melee: advantage — reroll, take better
                int reroll = dice.roll(20);
                if (reroll > attack_roll.die_roll) {
                    attack_roll.die_roll = reroll;
                    attack_roll.total = reroll + attack_roll.modifier;
                    attack_roll.is_critical_success = (reroll >= 20);
                    attack_roll.is_critical_failure = (reroll <= 1);
                }
                damage_roll_str += " [Prone-MeleeAdv]";
            }
        }
    }

    // Apply elevation modifier (ranged attacks: +2 downhill, -2 uphill)
    std::string elevation_log;
    if (elevation_mod != 0) {
        attack_roll.total += elevation_mod;
        elevation_log = (elevation_mod > 0) ? " [+2 High Ground]" : " [-2 Uphill]";
    }

    int target_ac = (target.is_player && target.player_ptr) ? target.player_ptr->get_armor_class() : (target.creature_ptr ? (10 + target.creature_ptr->get_stats().speed) : 10);

    // Blood Spawn: Bloodsense — reroll attack against damaged (below max HP) creatures, take higher
    if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Blood Spawn") {
        int t_max = target.get_max_hp();
        int t_cur = target.get_current_hp();
        if (t_cur < t_max) {
            int reroll = dice.roll(20);
            if (reroll + attack_roll.modifier > attack_roll.total) {
                attack_roll.die_roll = reroll;
                attack_roll.total = reroll + attack_roll.modifier;
                attack_roll.is_critical_success = (reroll >= 20);
            }
        }
    }

    bool ignore_resistance = false;
    bool ignore_immunity = false;
    if (attacker.is_player && attacker.player_ptr) {
        if (attacker.player_ptr->get_weapon() && attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Bludgeoning) {
            int tier = attacker.player_ptr->get_feat_tier(FeatID::IronHammer);
            if (tier >= 5 && !attacker.player_ptr->has_ignored_bludgeoning_immunity_this_turn_) {
                ignore_immunity = true; attacker.player_ptr->has_ignored_bludgeoning_immunity_this_turn_ = true;
            } else if (tier >= 2 && !attacker.player_ptr->has_ignored_bludgeoning_resistance_this_turn_) {
                ignore_resistance = true; attacker.player_ptr->has_ignored_bludgeoning_resistance_this_turn_ = true;
            }
        }
        if (attacker.player_ptr->get_weapon() && attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Slashing) {
            int ce_tier = attacker.player_ptr->get_feat_tier(FeatID::CrimsonEdge);
            if (ce_tier >= 5 && !attacker.player_ptr->ce_ignore_immunity_used_this_turn_) {
                ignore_immunity = true; attacker.player_ptr->ce_ignore_immunity_used_this_turn_ = true;
            } else if (ce_tier >= 2 && !attacker.player_ptr->ce_ignore_resist_used_this_turn_) {
                ignore_resistance = true; attacker.player_ptr->ce_ignore_resist_used_this_turn_ = true;
            }
        }
        if (attacker.player_ptr->get_weapon() && attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Piercing) {
            int it_tier = attacker.player_ptr->get_feat_tier(FeatID::IronThorn);
            if (it_tier >= 5 && !attacker.player_ptr->it_ignore_immunity_used_this_turn_) {
                ignore_immunity = true; attacker.player_ptr->it_ignore_immunity_used_this_turn_ = true;
            } else if (it_tier >= 2 && !attacker.player_ptr->it_ignore_resist_used_this_turn_) {
                ignore_resistance = true; attacker.player_ptr->it_ignore_resist_used_this_turn_ = true;
            }
        }
        if (is_unarmed) {
            int if_tier = attacker.player_ptr->get_feat_tier(FeatID::IronFist);
            if (if_tier >= 1 && !attacker.player_ptr->if_ignore_resist_used_this_turn_) {
                ignore_resistance = true; attacker.player_ptr->if_ignore_resist_used_this_turn_ = true;
            }
        }
    }

    std::string hit_log = attacker.name + " attacks " + target.name + " (Roll: " + std::to_string(attack_roll.die_roll) + "+" + std::to_string(attack_roll.modifier) + " = " + std::to_string(attack_roll.total) + " vs AC " + std::to_string(target_ac) + ")" + elevation_log;

    if (attack_roll.is_critical_failure && attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
        attacker.player_ptr->get_weapon()->on_critical_failure();
        hit_log += " [Weapon damaged by critical failure!]";
    }

    if (attack_roll.total >= target_ac) {
        // IllusoryDouble: roll d6, on 3 or less the illusion absorbs the hit
        if (target.is_player && target.player_ptr && target.player_ptr->illusory_double_hp_ > 0) {
            int d6 = dice.roll(6);
            if (d6 <= 3) {
                target.player_ptr->illusory_double_hp_--;
                last_action_log_ = hit_log + " — Illusory Double absorbs the hit! (" + std::to_string(target.player_ptr->illusory_double_hp_) + " deflections left)";
                if (target.player_ptr->illusory_double_hp_ == 0) last_action_log_ += " [Illusion destroyed!]";
                return false;
            }
        }

        if (is_critical) {
            damage *= 2;
            damage_roll_str = "(" + damage_roll_str + ") x2 [CRITICAL]";
        }

        int prev_target_hp = target.get_current_hp();
        int final_damage = damage;

        // Intangible: resistance to non-magical (physical weapon) damage
        {
            bool target_intangible = (target.is_player && target.player_ptr && target.player_ptr->get_status().has_condition(ConditionType::Intangible)) ||
                                     (!target.is_player && target.creature_ptr && target.creature_ptr->get_status().has_condition(ConditionType::Intangible));
            if (target_intangible) {
                final_damage = std::max(1, final_damage / 2);
                damage_roll_str += " /2 [Intangible]";
            }
        }

        int assassin_tier = (attacker.is_player && attacker.player_ptr) ? attacker.player_ptr->get_feat_tier(FeatID::AssassinsExecution) : 0;
        if (assassin_tier >= 1 && (prev_target_hp > 0 && (prev_target_hp - damage) <= 0)) {
            int extra = (attacker.is_player && attacker.player_ptr->get_weapon()) ? dice.roll_string(attacker.player_ptr->get_weapon()->get_damage_dice()) : dice.roll(8);
            final_damage += extra;
            damage_roll_str += " + " + std::to_string(extra) + " [Lethal Precision]";
        }

        // Iron Hammer T3 secondary: speed penalty on hit
        if (attacker.is_player && attacker.player_ptr && !is_unarmed &&
            attacker.player_ptr->get_weapon() &&
            attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Bludgeoning &&
            attacker.player_ptr->get_feat_tier(FeatID::IronHammer) >= 3 &&
            !attacker.player_ptr->ih_speed_penalty_used_this_turn_) {
            if (target.is_player && target.player_ptr) target.player_ptr->speed_penalty_ += 10;
            attacker.player_ptr->ih_speed_penalty_used_this_turn_ = true;
            damage_roll_str += " [-10ft]";
        }

        // Iron Fist T2 secondary: speed penalty on hit
        if (is_unarmed && attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_feat_tier(FeatID::IronFist) >= 2 &&
            !attacker.player_ptr->if_speed_penalty_used_this_turn_) {
            if (target.is_player && target.player_ptr) target.player_ptr->speed_penalty_ += 10;
            attacker.player_ptr->if_speed_penalty_used_this_turn_ = true;
            damage_roll_str += " [-10ft]";
        }

        // Iron Fist T3 secondary: extra die on hit (once per turn)
        if (is_unarmed && attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_feat_tier(FeatID::IronFist) >= 3 &&
            !attacker.player_ptr->if_extra_die_used_this_turn_) {
            int extra = dice.roll(10);
            final_damage += extra;
            damage_roll_str += " + " + std::to_string(extra) + " [IF Extra]";
            attacker.player_ptr->if_extra_die_used_this_turn_ = true;
        }

        // Crimson Edge T3 secondary: extra die of damage once per turn
        if (!is_unarmed && attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_weapon() &&
            attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Slashing &&
            attacker.player_ptr->get_feat_tier(FeatID::CrimsonEdge) >= 3 &&
            !attacker.player_ptr->ce_extra_die_used_this_turn_) {
            int extra = dice.roll_string(attacker.player_ptr->get_weapon()->get_damage_dice());
            final_damage += extra;
            damage_roll_str += " + " + std::to_string(extra) + " [Rending]";
            attacker.player_ptr->ce_extra_die_used_this_turn_ = true;
        }

        // Iron Thorn T3 secondary: -1 AC to target until end of next turn
        if (!is_unarmed && attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_weapon() &&
            attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Piercing &&
            attacker.player_ptr->get_feat_tier(FeatID::IronThorn) >= 3 &&
            !attacker.player_ptr->it_ac_reduction_used_this_turn_) {
            if (target.is_player && target.player_ptr) target.player_ptr->add_temp_ac(-1);
            attacker.player_ptr->it_ac_reduction_used_this_turn_ = true;
            damage_roll_str += " [-1AC]";
        }

        // Twin Fang tracking: count weapon hits this turn
        if (!is_unarmed && attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_feat_tier(FeatID::TwinFang) >= 1) {
            attacker.player_ptr->tf_hits_this_turn_++;
            // T1 secondary: both hit bonus +1d4
            if (attacker.player_ptr->tf_hits_this_turn_ == 2) {
                int tf_bonus = dice.roll(4);
                final_damage += tf_bonus;
                damage_roll_str += " + " + std::to_string(tf_bonus) + " [TwinFang]";
            }
        }

        // Precise Tactician on-crit effects
        if (is_critical && attacker.is_player && attacker.player_ptr) {
            int pt_tier = attacker.player_ptr->get_feat_tier(FeatID::PreciseTactician);
            if (pt_tier >= 2) {
                // T2: gain 2 AP on crit
                attacker.player_ptr->restore_ap(2);
                last_action_log_ += " [PT Crit: +2 AP]";
            }
            if (pt_tier >= 3) {
                // T3: force target VIT save (DC 10+INT) or Stunned
                int dc = 10 + attacker.player_ptr->get_stats().intellect;
                int save = (target.is_player && target.player_ptr)
                    ? target.player_ptr->roll_stat_check(dice, StatType::Vitality).total
                    : (target.creature_ptr ? dice.roll(20) + target.creature_ptr->get_stats().vitality : dice.roll(20));
                if (save < dc) {
                    if (target.is_player && target.player_ptr) target.player_ptr->get_status().add_condition(ConditionType::Stunned);
                    else if (target.creature_ptr) target.creature_ptr->get_status().add_condition(ConditionType::Stunned);
                    last_action_log_ += " [PT Crit: Stunned!]";
                }
            }
        }

        if (ignore_immunity) last_action_log_ = "[Bypassing Immunity] ";
        else if (ignore_resistance) last_action_log_ = "[Bypassing Resistance] ";
        else last_action_log_ = "";

        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
            attacker.player_ptr->get_weapon()->on_hit();
        }

        if (target.is_player && target.player_ptr) {
            if (is_critical) {
                if (target.player_ptr->get_armor()) target.player_ptr->get_armor()->on_critical_hit_taken();
                if (target.player_ptr->get_shield()) target.player_ptr->get_shield()->on_critical_hit_taken();
            } else {
                if (target.player_ptr->get_armor()) target.player_ptr->get_armor()->on_hit_taken();
                if (target.player_ptr->get_shield()) target.player_ptr->get_shield()->on_hit_taken();
            }
        }

        // Lithari: Rooted Form — resistance to all non-magical (physical) damage
        if (target.is_player && target.player_ptr && target.player_ptr->has_physical_resistance_) {
            final_damage = std::max(1, final_damage / 2);
            damage_roll_str += " /2 [Rooted Form]";
        } else if (target.creature_ptr) {
            // creatures don't have physical resistance tracking here
        }

        // Beetlefolk: Carapace Deflect — VIT/SR reaction on melee hit: reduce damage by 1d6+VIT
        std::string carapace_log;
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Beetlefolk" &&
            target.player_ptr->sr_beetlefolk_deflect_uses_ > 0) {
            bool this_attack_is_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { this_attack_is_ranged = true; break; }
            }
            if (!this_attack_is_ranged) {
                target.player_ptr->sr_beetlefolk_deflect_uses_--;
                int reduction = dice.roll(6) + target.player_ptr->get_stats().vitality;
                int pre_deflect = final_damage;
                final_damage = std::max(0, final_damage - reduction);
                carapace_log = " [Carapace: -" + std::to_string(reduction) + " damage";
                if (final_damage == 0 && pre_deflect > 0) {
                    // Attacker takes 1d4 piercing from shell ridges
                    int rebound = dice.roll(4);
                    if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(rebound, dice);
                    else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(rebound, dice);
                    carapace_log += ", " + attacker.name + " takes " + std::to_string(rebound) + " piercing rebound!";
                }
                carapace_log += " (" + std::to_string(target.player_ptr->sr_beetlefolk_deflect_uses_) + " uses left)]";
            }
        }

        // Grimshell: Heavy Frame — reaction on melee hit: spend 1 AP to reduce damage by 1d4+STR
        std::string heavy_frame_log;
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Grimshell" &&
            target.player_ptr->current_ap_ >= 1) {
            bool this_attack_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { this_attack_ranged = true; break; }
            }
            if (!this_attack_ranged) {
                target.player_ptr->current_ap_--;
                int reduction = dice.roll(4) + target.player_ptr->get_stats().strength;
                final_damage = std::max(0, final_damage - reduction);
                int push_dc = 10;
                int attacker_str_save = (attacker.is_player && attacker.player_ptr)
                    ? attacker.player_ptr->roll_stat_check(dice, StatType::Strength).total
                    : (attacker.creature_ptr ? dice.roll(20) + attacker.creature_ptr->get_stats().strength : dice.roll(20));
                heavy_frame_log = " [Heavy Frame: -" + std::to_string(reduction) + " damage";
                if (attacker_str_save < push_dc) heavy_frame_log += ", " + attacker.name + " pushed back!";
                heavy_frame_log += "]";
            }
        }

        // Ferrusk: Scrap Resilience — resistance to slashing weapon damage + AC+1 on first hit per turn
        std::string scrap_res_log;
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Ferrusk" &&
            target.player_ptr->has_slashing_resistance_ && !is_unarmed) {
            bool is_slashing = attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon() &&
                               attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Slashing;
            if (is_slashing) {
                final_damage = std::max(1, final_damage / 2);
                scrap_res_log = " [Scrap Resilience: slashing halved]";
                if (!target.player_ptr->ferrusk_scrap_ac_used_) {
                    target.player_ptr->add_temp_ac(1);
                    target.player_ptr->ferrusk_scrap_ac_used_ = true;
                    scrap_res_log += " [+1 AC this round]";
                }
            }
        }

        // Vulnerable: target takes double weapon damage
        {
            bool target_vul = (target.is_player && target.player_ptr && target.player_ptr->get_status().has_condition(ConditionType::Vulnerable)) ||
                              (!target.is_player && target.creature_ptr && target.creature_ptr->get_status().has_condition(ConditionType::Vulnerable));
            if (target_vul) {
                final_damage *= 2;
                damage_roll_str += " x2[Vulnerable]";
            }
        }
        // Stoneskin: reduce physical weapon damage by 2d4
        {
            bool target_stoneskin = (target.is_player && target.player_ptr && target.player_ptr->get_status().has_condition(ConditionType::Stoneskin)) ||
                                    (!target.is_player && target.creature_ptr && target.creature_ptr->get_status().has_condition(ConditionType::Stoneskin));
            if (target_stoneskin) {
                bool is_physical = !is_unarmed && attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon() &&
                    (attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Bludgeoning ||
                     attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Piercing ||
                     attacker.player_ptr->get_weapon()->get_damage_type() == DamageType::Slashing);
                if (is_physical) {
                    int reduction = dice.roll(4) + dice.roll(4);
                    final_damage = std::max(0, final_damage - reduction);
                    damage_roll_str += " -" + std::to_string(reduction) + "[Stoneskin]";
                }
            }
        }

        if (target.is_player && target.player_ptr) target.player_ptr->take_damage(final_damage, dice, is_critical);
        else if (target.creature_ptr) target.creature_ptr->take_damage(final_damage, dice);

        last_action_log_ += hit_log + " - HIT for " + std::to_string(final_damage) + " damage! (" + damage_roll_str + ")" + heavy_frame_log + carapace_log + scrap_res_log;

        // Flaming Attacks matrix: add 2d6 fire damage on hit
        {
            bool has_flaming = std::any_of(attacker.active_matrices.begin(), attacker.active_matrices.end(),
                [](const SpellMatrix& m) { return m.spell_name == "Flaming Attacks" && !m.suppressed; });
            if (has_flaming) {
                int fire_dmg = dice.roll(6) + dice.roll(6);
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(fire_dmg, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(fire_dmg, dice);
                last_action_log_ += " [Flaming Attacks: +" + std::to_string(fire_dmg) + " fire!]";
            }
        }

        // CraftingArtifice T3: energy core bonus elemental damage
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->ca_core_damage_bonus_pending_ > 0) {
            int core_dmg = attacker.player_ptr->ca_core_damage_bonus_pending_;
            attacker.player_ptr->ca_core_damage_bonus_pending_ = 0;
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(core_dmg, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(core_dmg, dice);
            last_action_log_ += " [Energy Core: +" + std::to_string(core_dmg) + " bonus!]";
        }

        // PoisonersKit T1: weapon poison effects on hit
        if (attacker.is_player && attacker.player_ptr) {
            if (attacker.player_ptr->pois_weapon_disadvantage_) {
                attacker.player_ptr->pois_weapon_disadvantage_ = false;
                attacker.player_ptr->pois_weapon_rounds_ = 0;
                if (target.is_player && target.player_ptr) target.player_ptr->get_status().add_condition(ConditionType::Dazed);
                else if (target.creature_ptr) target.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                last_action_log_ += " [Poison: target Dazed — disadvantage next action!]";
            } else if (attacker.player_ptr->pois_weapon_extra_damage_) {
                attacker.player_ptr->pois_weapon_extra_damage_ = false;
                attacker.player_ptr->pois_weapon_rounds_ = 0;
                int pois_dmg = dice.roll(4);
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(pois_dmg, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(pois_dmg, dice);
                last_action_log_ += " [Poison: +" + std::to_string(pois_dmg) + " poison damage!]";
            }
        }

        // HuntingMastery T3: quarry — +1d6 damage on first hit per round
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->lr_hunt_quarry_active_ &&
            attacker.player_ptr->lr_hunt_quarry_id_ == target.id &&
            !attacker.player_ptr->lr_hunt_quarry_hit_this_round_) {
            attacker.player_ptr->lr_hunt_quarry_hit_this_round_ = true;
            int quarry_dmg = dice.roll(6);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(quarry_dmg, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(quarry_dmg, dice);
            last_action_log_ += " [Wild Hunt: +" + std::to_string(quarry_dmg) + " quarry bonus!]";
        }

        // BladeScripture: +1d6 radiant/necrotic on hit, caster heals 1 HP
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->lr_blade_scripture_active_) {
            int bs_dmg = dice.roll(6);
            std::string bs_type = attacker.player_ptr->blade_scripture_radiant_ ? "radiant" : "necrotic";
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(bs_dmg, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(bs_dmg, dice);
            attacker.player_ptr->heal(1);
            last_action_log_ += " [Blade Scripture: +" + std::to_string(bs_dmg) + " " + bs_type + ", caster heals 1!]";
        }

        // PlanarGraze: +1d8 force + push 15 ft on this hit
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->planar_graze_pending_) {
            attacker.player_ptr->planar_graze_pending_ = false;
            int pg_dmg = dice.roll(8);
            int pg_psychic = dice.roll(6);
            if (target.is_player && target.player_ptr) { target.player_ptr->take_damage(pg_dmg, dice); target.player_ptr->take_damage(pg_psychic, dice); }
            else if (target.creature_ptr) { target.creature_ptr->take_damage(pg_dmg, dice); target.creature_ptr->take_damage(pg_psychic, dice); }
            last_action_log_ += " [Planar Graze: +" + std::to_string(pg_dmg) + " force, pushed 15 ft, +" + std::to_string(pg_psychic) + " psychic on impact!]";
        }

        // BarkskinRitual: melee attacker takes 1 piercing damage when hitting a barkskin target
        bool bs_attacker_ranged = !is_unarmed && attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon() &&
            std::any_of(attacker.player_ptr->get_weapon()->get_properties().begin(), attacker.player_ptr->get_weapon()->get_properties().end(),
                [](const std::string& p){ return p.find("Range") != std::string::npos; });
        if (target.is_player && target.player_ptr && target.player_ptr->lr_barkskin_active_ && !bs_attacker_ranged) {
            rimvale::Dice local_dice;
            if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(1, local_dice);
            else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(1, local_dice);
            last_action_log_ += " [Barkskin: attacker takes 1 piercing!]";
        }

        // Goldscale: Heated Scales retaliation — when a melee attacker hits a Goldscale with HeatedScales active
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Goldscale" &&
            target.player_ptr->get_status().has_condition(ConditionType::HeatedScales)) {
            // Check if this is melee (not ranged): weapon without Range property, or unarmed
            bool attacker_is_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties()) {
                    if (prop.find("Range") != std::string::npos) { attacker_is_ranged = true; break; }
                }
            }
            if (!attacker_is_ranged) {
                int retaliation = dice.roll(4);
                if (attacker.is_player && attacker.player_ptr) {
                    attacker.player_ptr->take_damage(retaliation, dice);
                    // DC 10+DIV check or drop weapon
                    int dc = 10 + target.player_ptr->get_stats().divinity;
                    if (attacker.player_ptr->roll_stat_check(dice, StatType::Divinity).total < dc) {
                        // Equip nullptr to represent dropping the weapon
                        if (attacker.player_ptr->get_weapon()) {
                            attacker.player_ptr->equip_weapon(nullptr);
                            last_action_log_ += " [Heated Scales: " + attacker.name + " takes " + std::to_string(retaliation) + " fire, drops weapon!]";
                        } else {
                            last_action_log_ += " [Heated Scales: " + attacker.name + " takes " + std::to_string(retaliation) + " fire!]";
                        }
                    } else {
                        last_action_log_ += " [Heated Scales: " + attacker.name + " takes " + std::to_string(retaliation) + " fire!]";
                    }
                } else if (attacker.creature_ptr) {
                    attacker.creature_ptr->take_damage(retaliation, dice);
                    last_action_log_ += " [Heated Scales: attacker takes " + std::to_string(retaliation) + " fire!]";
                }
            }
        }

        // Goldscale: HeatedScales — +1d4 fire bonus on the attacker's own strike
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Goldscale" &&
            attacker.player_ptr->get_status().has_condition(ConditionType::HeatedScales)) {
            int fire_bonus = dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(fire_bonus, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(fire_bonus, dice);
            last_action_log_ += " [+1d4 fire: " + std::to_string(fire_bonus) + "]";
        }

        // Bramblekin: Thorny Hide — when a melee attacker hits Bramblekin, or Bramblekin hits with melee
        bool is_melee = !is_unarmed; // unarmed is separate; treat all weapon/unarmed attacks as melee unless ranged
        {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties()) {
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
                }
            }
            if (!attacker_ranged) {
                // Target is Bramblekin — attacker takes thorns
                if (target.is_player && target.player_ptr && target.player_ptr->get_lineage().name == "Bramblekin") {
                    int thorns = dice.roll(4);
                    if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(thorns, dice);
                    else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(thorns, dice);
                    last_action_log_ += " [Thorny Hide: " + attacker.name + " takes " + std::to_string(thorns) + " piercing!]";
                }
                // Attacker is Bramblekin — target takes thorns
                if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Bramblekin") {
                    int thorns = dice.roll(4);
                    if (target.is_player && target.player_ptr) target.player_ptr->take_damage(thorns, dice);
                    else if (target.creature_ptr) target.creature_ptr->take_damage(thorns, dice);
                    last_action_log_ += " [Thorny Hide: " + std::to_string(thorns) + " piercing!]";
                }
            }
        }

        // Mirevenom: Venomous Blood — melee/unarmed attacker must make VIT save or take 1d4 poison
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Mirevenom") {
            bool natural_weapon = is_unarmed || (!attacker.is_player && attacker.creature_ptr);
            if (natural_weapon) {
                int dc = 10 + target.player_ptr->get_stats().vitality;
                int save_roll = (attacker.is_player && attacker.player_ptr)
                    ? attacker.player_ptr->roll_stat_check(dice, StatType::Vitality).total
                    : (attacker.creature_ptr ? dice.roll(20) + attacker.creature_ptr->get_stats().vitality : dice.roll(20));
                if (save_roll < dc) {
                    int venom = dice.roll(4);
                    if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(venom, dice);
                    else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(venom, dice);
                    last_action_log_ += " [Venomous Blood: " + attacker.name + " takes " + std::to_string(venom) + " poison!]";
                }
            }
        }
        // Mirevenom: Venomous Blood — when Mirevenom hits with unarmed, target makes VIT save or 1d4 poison
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Mirevenom" && is_unarmed) {
            int dc = 10 + attacker.player_ptr->get_stats().vitality;
            int save_roll = target.creature_ptr ? dice.roll(20) + target.creature_ptr->get_stats().vitality : dice.roll(20);
            if (save_roll < dc) {
                int venom = dice.roll(4);
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(venom, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(venom, dice);
                last_action_log_ += " [Venomous Blood: " + std::to_string(venom) + " poison!]";
            }
        }
        // Serpentine: Extract Venom weapon — active venom adds +1d4 poison and Poisoned save
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Serpentine" &&
            attacker.player_ptr->serpentine_venom_weapon_rounds_ > 0 &&
            !is_unarmed) {
            int venom_bonus = dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(venom_bonus, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(venom_bonus, dice);
            int dc = 10 + attacker.player_ptr->get_stats().divinity;
            int save_roll = target.creature_ptr ? dice.roll(20) + target.creature_ptr->get_stats().vitality : dice.roll(20);
            if (save_roll < dc && target.creature_ptr) target.creature_ptr->get_status().add_condition(ConditionType::Poisoned);
            last_action_log_ += " [Venom: +" + std::to_string(venom_bonus) + " poison" + (save_roll < dc ? ", Poisoned!" : "") + "]";
        }
        // Blackroot: Witherborn Decay — active bonus adds +1d4 poison on melee attacks
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Blackroot" &&
            attacker.player_ptr->witherborn_decay_rounds_ > 0) {
            int decay_bonus = dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(decay_bonus, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(decay_bonus, dice);
            last_action_log_ += " [Witherborn: +" + std::to_string(decay_bonus) + " poison]";
        }

        // Oozeling: Corrosive Touch (attacker) — armor/weapon of target corrodes when Oozeling hits unarmed
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Oozeling" && is_unarmed) {
            int acid = dice.roll(4);
            Armor* t_armor = (target.is_player && target.player_ptr) ? target.player_ptr->get_armor() : nullptr;
            if (t_armor && !t_armor->is_broken()) {
                t_armor->take_damage(acid);
                last_action_log_ += " [Corrosive Touch: target armor -" + std::to_string(acid) + " durability!]";
            }
        }
        // Oozeling: Corrosive Touch — weapon/armor of attacker corrodes when Oozeling is hit melee
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Oozeling") {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            }
            if (!attacker_ranged) {
                int acid = dice.roll(4);
                Weapon* a_wpn = (attacker.is_player && attacker.player_ptr) ? attacker.player_ptr->get_weapon() : nullptr;
                if (a_wpn && !a_wpn->is_broken()) {
                    a_wpn->take_damage(acid);
                    last_action_log_ += " [Corrosive Touch: attacker's weapon -" + std::to_string(acid) + " durability!]";
                }
            }
        }
        // Kindlekin: Combustive Touch — explosion on hit; +1d4 per hit, +5ft range per 5 hits
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Kindlekin") {
            bool this_hit_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { this_hit_ranged = true; break; }
            }
            if (!this_hit_ranged) {
                target.player_ptr->kindlekin_hit_count_++;
                int hit_n = target.player_ptr->kindlekin_hit_count_;
                // Base 5ft range (1 tile), +5ft (1 tile) per 5 hits
                int range_tiles = 1 + (hit_n / 5);
                int explosion_total = 0;
                for (int k = 0; k < hit_n; ++k) explosion_total += dice.roll(4);
                int affected = 0;
                for (auto& c : combatants_) {
                    if (c.is_player || c.get_current_hp() <= 0 || !c.creature_ptr) continue;
                    int dist = dungeon_mode_ ? DungeonManager::instance().get_distance(target.id, c.id) : 1;
                    if (dist <= range_tiles) {
                        c.creature_ptr->take_damage(explosion_total, dice);
                        affected++;
                    }
                }
                last_action_log_ += " [Combustive Touch: " + std::to_string(hit_n) + "d4=" +
                    std::to_string(explosion_total) + " fire in " + std::to_string(range_tiles * 5) + "ft radius (" +
                    std::to_string(affected) + " hit)!]";
            }
        }

        // Frostborn: Icewalk — +2d4 cold bonus damage + movement halved on failed Speed save
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Frostborn" &&
            attacker.player_ptr->frostborn_icewalk_active_) {
            int cold_dmg = dice.roll(4) + dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(cold_dmg, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(cold_dmg, dice);
            last_action_log_ += " [Icewalk: +" + std::to_string(cold_dmg) + " cold!]";
            if (target.is_player && target.player_ptr) {
                int ice_dc = 10 + attacker.player_ptr->get_stats().vitality;
                auto save = target.player_ptr->roll_stat_check(dice, StatType::Speed);
                if (save.total < ice_dc) {
                    target.player_ptr->speed_penalty_ += target.player_ptr->get_movement_speed() / 2;
                    last_action_log_ += " [movement halved!]";
                }
            }
        }

        // Snareling: Tangle Teeth — on melee hit, target loses 10ft movement (stackable)
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Snareling") {
            if (target.is_player && target.player_ptr) {
                target.player_ptr->speed_penalty_ += 10;
            }
            last_action_log_ += " [Tangle Teeth: -10ft movement on " + target.name + "]";
        }

        // Huskdrone: Gas Vent on death — 2d6 poison AoE to all enemies when Huskdrone is killed (VIT DC 12)
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Huskdrone" &&
            target.get_current_hp() <= 0 && prev_target_hp > 0) {
            int vent_dmg = dice.roll(6) + dice.roll(6);
            int dc = 12;
            for (auto& c : combatants_) {
                if (c.id == target.id || c.get_current_hp() <= 0) continue;
                int save = (c.is_player && c.player_ptr)
                    ? c.player_ptr->roll_stat_check(dice, StatType::Vitality).total
                    : (c.creature_ptr ? dice.roll(20) + c.creature_ptr->get_stats().vitality : dice.roll(20));
                int dmg = (save >= dc) ? std::max(1, vent_dmg / 2) : vent_dmg;
                if (c.is_player && c.player_ptr) c.player_ptr->take_damage(dmg, dice);
                else if (c.creature_ptr) c.creature_ptr->take_damage(dmg, dice);
            }
            last_action_log_ += " [Huskdrone Gas Vent: " + std::to_string(vent_dmg) + " poison AoE on death!]";
        }
        // Nullborn: Devour Essence — regain SP equal to DIV when killing a creature
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Nullborn" &&
            target.get_current_hp() <= 0 && prev_target_hp > 0) {
            int sp_gain = attacker.player_ptr->get_stats().divinity;
            attacker.player_ptr->restore_sp(sp_gain);
            last_action_log_ += " [Devour Essence: +" + std::to_string(sp_gain) + " SP!]";
        }

        // Porcelari: Shatter Pulse — on a critical hit, send a glass shockwave to all enemies (1d6 force)
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Porcelari" && is_critical) {
            int pulse = dice.roll(6);
            for (auto& c : combatants_) {
                if (c.is_player == attacker.is_player || c.get_current_hp() <= 0) continue;
                if (c.is_player && c.player_ptr) c.player_ptr->take_damage(pulse, dice);
                else if (c.creature_ptr) c.creature_ptr->take_damage(pulse, dice);
            }
            last_action_log_ += " [Shatter Pulse: " + std::to_string(pulse) + " force AoE on crit!]";
        }

        // Flenskin: Agonized Form — when Flenskin is hit by melee, attacker takes 1 psychic damage
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Flenskin") {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            }
            if (!attacker_ranged) {
                if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(1, dice);
                else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(1, dice);
                last_action_log_ += " [Agonized Form: " + attacker.name + " takes 1 psychic!]";
            }
        }

        // Rustspawn: Corrosive Aura — weapon attacks on Rustspawn deal triple durability damage to the weapon
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Rustspawn") {
            Weapon* a_wpn = (attacker.is_player && attacker.player_ptr) ? attacker.player_ptr->get_weapon() : nullptr;
            if (a_wpn && !a_wpn->is_broken()) {
                int normal = 1;
                a_wpn->take_damage(normal * 3);
                last_action_log_ += " [Corrosive Aura: attacker's weapon -" + std::to_string(normal * 3) + " durability!]";
            }
        }

        // Rustspawn: Ironrot — attacker attacking Rustspawn with a weapon gains Ironrot stacks
        if (attacker.is_player && attacker.player_ptr && target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Rustspawn") {
            attacker.player_ptr->ironrot_acid_stacks_++;
            last_action_log_ += " [Ironrot: " + attacker.name + " gains stack (" + std::to_string(attacker.player_ptr->ironrot_acid_stacks_) + ")!]";
        }

        // Rustspawn: Ironrot — if attacker has Ironrot stacks, take 1d4 acid per stack (consumed on attack)
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name != "Rustspawn" &&
            attacker.player_ptr->ironrot_acid_stacks_ > 0) {
            int acid_total = 0;
            for (int i = 0; i < attacker.player_ptr->ironrot_acid_stacks_; ++i) acid_total += dice.roll(4);
            attacker.player_ptr->take_damage(acid_total, dice);
            attacker.player_ptr->ironrot_acid_stacks_ = 0;
            last_action_log_ += " [Ironrot: " + attacker.name + " takes " + std::to_string(acid_total) + " acid!]";
        }

        // Scourling Human: Fury of the Marked — bonus 1d6 damage when target is below half HP
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Scourling Human" &&
            prev_target_hp > 0 && prev_target_hp < (target.get_max_hp() / 2)) {
            int fury = dice.roll(6);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(fury, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(fury, dice);
            last_action_log_ += " [Fury of the Marked: +" + std::to_string(fury) + " bonus!]";
        }

        // Obsidian Seraph: Cracked Resilience — apply stacks as bonus damage on attack
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Obsidian Seraph" &&
            attacker.player_ptr->cracked_resilience_stacks_ > 0) {
            int bonus = attacker.player_ptr->cracked_resilience_stacks_;
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(bonus, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(bonus, dice);
            attacker.player_ptr->cracked_resilience_stacks_ = 0;
            last_action_log_ += " [Cracked Resilience: +" + std::to_string(bonus) + " discharge!]";
        }

        // Hellforged: Infernal Smite — next attack deals +2d4 fire damage
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Hellforged" &&
            attacker.player_ptr->infernal_smite_rounds_ > 0) {
            int smite = dice.roll(4) + dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(smite, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(smite, dice);
            attacker.player_ptr->infernal_smite_rounds_ = 0;
            last_action_log_ += " [Infernal Smite: +" + std::to_string(smite) + " fire!]";
        }

        // Sunderborn Human: Blood Frenzy — on kill, consume frenzy if set; grant new frenzy + advantage
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Sunderborn Human" &&
            target.get_current_hp() <= 0 && prev_target_hp > 0) {
            attacker.player_ptr->sunderborn_frenzy_available_ = true;
            attacker.player_ptr->advantage_until_tick_ = 1;
            last_action_log_ += " [Blood Frenzy: free attack available!]";
        }
        // Volcant: Lava Burst — when hit by melee, deal 1d4 fire to attacker
        if (target.is_player && target.player_ptr && target.player_ptr->get_lineage().name == "Volcant") {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            }
            if (!attacker_ranged) {
                int lava = dice.roll(4);
                if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(lava, dice);
                else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(lava, dice);
                last_action_log_ += " [Lava Burst: " + attacker.name + " takes " + std::to_string(lava) + " fire!]";
            }
        }
        // Saurian: Tail Lash — when hit by melee, deal 1d4 bludgeoning to attacker
        if (target.is_player && target.player_ptr && target.player_ptr->get_lineage().name == "Saurian") {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            }
            if (!attacker_ranged) {
                int tail = dice.roll(4);
                if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(tail, dice);
                else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(tail, dice);
                last_action_log_ += " [Tail Lash: " + attacker.name + " takes " + std::to_string(tail) + " bludgeoning!]";
            }
        }
        // Saurian: Scaled Resilience — 1/SR, auto-reduce damage from next melee attack
        if (target.is_player && target.player_ptr && target.player_ptr->get_lineage().name == "Saurian" &&
            target.player_ptr->sr_scaled_resilience_available_) {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            }
            if (!attacker_ranged) {
                // damage already dealt — grant healing back as the scales absorb
                int reduction = dice.roll(4) + target.player_ptr->get_stats().vitality;
                target.player_ptr->heal(reduction);
                target.player_ptr->sr_scaled_resilience_available_ = false;
                last_action_log_ += " [Scaled Resilience: absorbed " + std::to_string(reduction) + " damage!]";
            }
        }
        // Obsidian: Shard Skin — when hit by melee, attacker takes 1d4 thunder
        if (target.is_player && target.player_ptr && target.player_ptr->get_lineage().name == "Obsidian") {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            }
            if (!attacker_ranged) {
                int shard = dice.roll(4);
                if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(shard, dice);
                else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(shard, dice);
                last_action_log_ += " [Shard Skin: " + attacker.name + " takes " + std::to_string(shard) + " thunder!]";
            }
        }
        // Scornshard: Fracture Burst — 1/SR when hit by melee weapon, blind adjacent creatures (Speed/VIT DC 10+VIT)
        if (target.is_player && target.player_ptr && target.player_ptr->get_lineage().name == "Scornshard" &&
            target.player_ptr->sr_fracture_burst_available_ && !is_unarmed) {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            }
            if (!attacker_ranged) {
                target.player_ptr->sr_fracture_burst_available_ = false;
                int dc = 10 + target.player_ptr->get_stats().vitality;
                int blinded = 0;
                for (auto& c : combatants_) {
                    if (c.is_player == target.is_player || c.get_current_hp() <= 0) continue;
                    int save_roll = (c.is_player && c.player_ptr)
                        ? c.player_ptr->roll_stat_check(dice, StatType::Speed).total
                        : (c.creature_ptr ? dice.roll(20) + c.creature_ptr->get_stats().speed : dice.roll(20));
                    if (save_roll < dc) {
                        if (c.is_player && c.player_ptr) c.player_ptr->get_status().add_condition(ConditionType::Blinded);
                        blinded++;
                    }
                }
                last_action_log_ += " [Fracture Burst: " + std::to_string(blinded) + " adjacent creature(s) Blinded (DC " + std::to_string(dc) + ")!]";
            }
        }
        // Scornshard: Crackling Edge — unarmed attacks deal +Speed bonus once per turn (slashing damage)
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Scornshard" &&
            is_unarmed && !attacker.player_ptr->crackling_edge_used_) {
            int speed_bonus = attacker.player_ptr->get_stats().speed;
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(speed_bonus, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(speed_bonus, dice);
            attacker.player_ptr->crackling_edge_used_ = true;
            last_action_log_ += " [Crackling Edge: +" + std::to_string(speed_bonus) + " slashing!]";
        }
        // Emberkin: Blazeblood — +1d4 fire on melee attacks while active
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Emberkin" &&
            attacker.player_ptr->blazeblood_rounds_ > 0) {
            int fire_bonus = dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(fire_bonus, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(fire_bonus, dice);
            last_action_log_ += " [Blazeblood: +" + std::to_string(fire_bonus) + " fire!]";
        }
        // Ashenborn: Cursed Spark — +1d4 fire on weapon/unarmed attacks while active
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Ashenborn" &&
            attacker.player_ptr->cursed_spark_rounds_ > 0) {
            int spark = dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(spark, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(spark, dice);
            last_action_log_ += " [Cursed Spark: +" + std::to_string(spark) + " fire!]";
        }
        // Drakari: Draconic Awakening — +1d4 per level elemental bonus on melee attacks in dragon form
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Drakari" &&
            attacker.player_ptr->draconic_form_active_) {
            int elem_bonus = 0;
            for (int i = 0; i < attacker.player_ptr->get_level(); ++i) elem_bonus += dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(elem_bonus, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(elem_bonus, dice);
            last_action_log_ += " [Draconic Form: +" + std::to_string(elem_bonus) + " " + attacker.player_ptr->draconic_element_ + "!]";
        }
        // Moonkin: Lunar Blessing — +1d6 radiant on attacks while Lunar Radiance is active
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Moonkin" &&
            attacker.player_ptr->lunar_radiance_rounds_ > 0) {
            int lunar_dmg = dice.roll(6);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(lunar_dmg, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(lunar_dmg, dice);
            last_action_log_ += " [Lunar Blessing: +" + std::to_string(lunar_dmg) + " radiant!]";
        }
        // Venari: Hunter's Focus — +1d6 bonus on attacks against marked target
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->hunters_focus_active_) {
            int target_hash = static_cast<int>(std::hash<std::string>{}(target.id) & 0x7FFFFFFF);
            if (target_hash == attacker.player_ptr->hunters_focus_target_id_) {
                int focus_dmg = dice.roll(6);
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(focus_dmg, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(focus_dmg, dice);
                last_action_log_ += " [Hunter's Focus: +" + std::to_string(focus_dmg) + "!]";
            }
        }
        // Venari: Pack Instinct — if ally is adjacent to target, attacker gets advantage reroll (+1d6 bonus)
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Venari") {
            for (auto& ally : combatants_) {
                if (ally.id == attacker.id || !ally.is_player || ally.get_current_hp() <= 0) continue;
                if (DungeonManager::instance().get_distance(ally.id, target.id) <= 1) {
                    int pack_dmg = dice.roll(6);
                    if (target.is_player && target.player_ptr) target.player_ptr->take_damage(pack_dmg, dice);
                    else if (target.creature_ptr) target.creature_ptr->take_damage(pack_dmg, dice);
                    last_action_log_ += " [Pack Instinct: +" + std::to_string(pack_dmg) + "!]";
                    break;
                }
            }
        }
        // Rotborn Herald: Diseasebound — unarmed attacks deal +1d4 poison damage
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_lineage().name == "Rotborn Herald" && is_unarmed) {
            int rot_dmg = dice.roll(4);
            if (target.is_player && target.player_ptr) target.player_ptr->take_damage(rot_dmg, dice);
            else if (target.creature_ptr) target.creature_ptr->take_damage(rot_dmg, dice);
            last_action_log_ += " [Diseasebound: +" + std::to_string(rot_dmg) + " poison!]";
        }
        // Filthlit Spawn: Toxic Form — melee attackers take 1d4 poison retaliation
        bool attacker_is_ranged = false;
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon())
            for (const auto& p : attacker.player_ptr->get_weapon()->get_properties()) if (p.find("Range") != std::string::npos) { attacker_is_ranged = true; break; }
        if (target.is_player && target.player_ptr && target.player_ptr->get_lineage().name == "Filthlit Spawn" && !attacker_is_ranged) {
            int toxic_dmg = dice.roll(4);
            if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(toxic_dmg, dice);
            else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(toxic_dmg, dice);
            last_action_log_ += " [Toxic Form: " + std::to_string(toxic_dmg) + " poison retaliation!]";
        }

        // Sparkforged Human: Overload Pulse — 2d6 force AoE to all within 10ft when killed (includes self)
        if (target.is_player && target.player_ptr &&
            target.player_ptr->get_lineage().name == "Sparkforged Human" &&
            target.get_current_hp() <= 0 && prev_target_hp > 0) {
            int pulse = dice.roll(6) + dice.roll(6);
            for (auto& c : combatants_) {
                if (c.id == target.id || c.get_current_hp() <= 0) continue;
                if (DungeonManager::instance().get_distance(target.id, c.id) <= 2) {
                    if (c.is_player && c.player_ptr) c.player_ptr->take_damage(pulse, dice);
                    else if (c.creature_ptr) c.creature_ptr->take_damage(pulse, dice);
                }
            }
            target.player_ptr->take_damage(pulse, dice);
            last_action_log_ += " [Overload Pulse: " + std::to_string(pulse) + " force AoE on death!]";
        }
        // Shadewretch: Unseen Hunger — gain 2 SP when reducing a creature to 0 HP
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Shadewretch" &&
            target.get_current_hp() <= 0 && prev_target_hp > 0) {
            attacker.player_ptr->restore_sp(2);
            last_action_log_ += " [Unseen Hunger: +2 SP!]";
        }

        // Corrupted Wyrmblood: Dark Lineage — on kill, if uses remain, adjacent enemies take 1d4 necrotic
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Corrupted Wyrmblood" &&
            target.get_current_hp() <= 0 && prev_target_hp > 0 &&
            attacker.player_ptr->lr_dark_lineage_uses_ > 0) {
            attacker.player_ptr->lr_dark_lineage_uses_--;
            int necrotic_dmg = dice.roll(4);
            for (auto& c : combatants_) {
                if (c.id == attacker.id || c.is_player == attacker.is_player || c.get_current_hp() <= 0) continue;
                if (DungeonManager::instance().get_distance(attacker.id, c.id) <= 1) {
                    if (c.creature_ptr) c.creature_ptr->take_damage(necrotic_dmg, dice);
                }
            }
            last_action_log_ += " [Dark Lineage: " + std::to_string(necrotic_dmg) + " necrotic pulse on kill!]";
        }

        // Lightbound: Flareburst — primed next melee hit: +2d6 fire + Blinded
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->flareburst_primed_) {
            bool fb_is_ranged = false;
            if (attacker.player_ptr->get_weapon())
                for (const auto& p : attacker.player_ptr->get_weapon()->get_properties()) if (p.find("Range") != std::string::npos) { fb_is_ranged = true; break; }
            if (!fb_is_ranged) {
                attacker.player_ptr->flareburst_primed_ = false;
                int fb_dmg = dice.roll(6) + dice.roll(6);
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(fb_dmg, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(fb_dmg, dice);
                if (target.creature_ptr) target.creature_ptr->get_status().add_condition(ConditionType::Blinded);
                else if (target.is_player && target.player_ptr) target.player_ptr->get_status().add_condition(ConditionType::Blinded);
                last_action_log_ += " [Flareburst: +" + std::to_string(fb_dmg) + " fire, Blinded!]";
            }
        }
        // ===== APEX FEAT PASSIVE HOOKS =====

        // StormboundMantle: melee attackers take 2d6 lightning when they hit the player
        if (target.is_player && target.player_ptr && target.player_ptr->stormbound_mantle_rounds_ > 0) {
            bool this_attack_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon()) {
                for (const auto& prop : attacker.player_ptr->get_weapon()->get_properties())
                    if (prop.find("Range") != std::string::npos) { this_attack_ranged = true; break; }
            }
            if (!this_attack_ranged) {
                int storm_dmg = dice.roll(6) + dice.roll(6);
                if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(storm_dmg, dice);
                else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(storm_dmg, dice);
                last_action_log_ += " [Stormbound Mantle: " + attacker.name + " takes " + std::to_string(storm_dmg) + " lightning!]";
            }
        }

        // VoidbrandCurse: if primed and attacker hits with melee, brand the target
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->voidbrand_primed_) {
            bool vb_ranged = false;
            if (attacker.player_ptr->get_weapon())
                for (const auto& p : attacker.player_ptr->get_weapon()->get_properties()) if (p.find("Range") != std::string::npos) { vb_ranged = true; break; }
            if (!vb_ranged) {
                attacker.player_ptr->voidbrand_primed_ = false;
                attacker.player_ptr->voidbrand_target_id_ = target.id;
                attacker.player_ptr->voidbrand_rounds_ = 2;
                last_action_log_ += " [Voidbrand: " + target.name + " branded — no healing, -2 saves for 2 rounds!]";
            }
        }

        // Soulbrand: on kill of branded target, regain 10 HP + 1 SP
        if (attacker.is_player && attacker.player_ptr &&
            !attacker.player_ptr->soulbrand_target_id_.empty() &&
            attacker.player_ptr->soulbrand_target_id_ == target.id &&
            target.get_current_hp() <= 0 && prev_target_hp > 0) {
            attacker.player_ptr->heal(10);
            attacker.player_ptr->restore_sp(1);
            attacker.player_ptr->soulbrand_target_id_ = "";
            last_action_log_ += " [Soulbrand: branded target slain! +10 HP +1 SP!]";
        }

        // VoidbrandCurse: on kill of voidbranded target, regain 10 HP + 1 SP
        if (attacker.is_player && attacker.player_ptr &&
            !attacker.player_ptr->voidbrand_target_id_.empty() &&
            attacker.player_ptr->voidbrand_target_id_ == target.id &&
            target.get_current_hp() <= 0 && prev_target_hp > 0) {
            attacker.player_ptr->heal(10);
            attacker.player_ptr->restore_sp(1);
            attacker.player_ptr->voidbrand_target_id_ = "";
            attacker.player_ptr->voidbrand_rounds_ = 0;
            last_action_log_ += " [Voidbrand Curse: cursed target slain! +10 HP +1 SP!]";
        }

        // RunebreakerSurge: second attack on hit (once per original attack)
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->runebreaker_active_rounds_ > 0) {
            // Only trigger on the "primary" hit (not recursive), guard via a temp flag
            if (!attacker.player_ptr->me_max_die_used_this_turn_) { // reuse flag to guard recursion
                attacker.player_ptr->me_max_die_used_this_turn_ = true;
                last_action_log_ += "\n[RunebreakerSurge: bonus attack!] ";
                execute_attack(attacker, target, dice, is_unarmed, elevation_mod);
                attacker.player_ptr->me_max_die_used_this_turn_ = false;
            }
        }

        // PhantomLegion: each surviving clone makes a sync attack
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->phantom_legion_active_
            && attacker.player_ptr->phantom_legion_clones_ > 0) {
            for (int ci = 0; ci < attacker.player_ptr->phantom_legion_clones_; ++ci) {
                int clone_atk = dice.roll(20) + attacker.player_ptr->get_stats().speed;
                int t_ac = target.is_player && target.player_ptr ? target.player_ptr->get_armor_class()
                         : (target.creature_ptr ? 10 + target.creature_ptr->get_stats().speed : 10);
                if (clone_atk >= t_ac) {
                    int clone_dmg = dice.roll(6) + attacker.player_ptr->get_stats().speed;
                    if (target.is_player && target.player_ptr) target.player_ptr->take_damage(clone_dmg, dice);
                    else if (target.creature_ptr) target.creature_ptr->take_damage(clone_dmg, dice);
                    last_action_log_ += " [Phantom Clone " + std::to_string(ci + 1) + ": HIT +" + std::to_string(clone_dmg) + "!]";
                } else {
                    last_action_log_ += " [Phantom Clone " + std::to_string(ci + 1) + ": miss]";
                }
            }
        }

        // Disjointed Hounds: Warped Bite — on unarmed hit, VIT DC (10+attacker VIT), fail = Dazed
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Disjointed Hounds" && is_unarmed) {
            int dc = 10 + attacker.player_ptr->get_stats().vitality;
            int save = (target.is_player && target.player_ptr)
                ? target.player_ptr->roll_stat_check(dice, StatType::Vitality).total
                : (target.creature_ptr ? dice.roll(20) + target.creature_ptr->get_stats().vitality : dice.roll(20));
            if (save < dc) {
                if (target.is_player && target.player_ptr) target.player_ptr->get_status().add_condition(ConditionType::Dazed);
                else if (target.creature_ptr) target.creature_ptr->get_status().add_condition(ConditionType::Dazed);
                last_action_log_ += " [Warped Bite: Dazed!]";
            }
        }

        // ===== ASCENDANT FEAT PASSIVE HOOKS =====

        // KaijuCoreIntegration: Molten Skin — melee attacker takes 1d6 fire when hitting Kaiju player
        if (target.is_player && target.player_ptr && target.player_ptr->kaiju_titanic_applied_
            && target.player_ptr->get_feat_tier(FeatID::KaijuCoreIntegration) >= 1) {
            bool attacker_ranged = false;
            if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->get_weapon())
                for (const auto& p : attacker.player_ptr->get_weapon()->get_properties()) if (p.find("Range") != std::string::npos) { attacker_ranged = true; break; }
            if (!attacker_ranged) {
                int molten = dice.roll(6);
                if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(molten, dice);
                else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(molten, dice);
                last_action_log_ += " [Molten Skin: " + attacker.name + " takes " + std::to_string(molten) + " fire!]";
            }
        }

        // InfernalCoronation: Flame Flicker Smite — if primed, next melee hit deals N×d4 fire (N = HP sacrificed)
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->infernal_flame_flicker_primed_
            && attacker.player_ptr->infernal_flame_flicker_hp_sacrificed_ > 0
            && attacker.player_ptr->get_feat_tier(FeatID::InfernalCoronation) >= 1) {
            bool ff_ranged = false;
            if (attacker.player_ptr->get_weapon())
                for (const auto& p : attacker.player_ptr->get_weapon()->get_properties()) if (p.find("Range") != std::string::npos) { ff_ranged = true; break; }
            if (!ff_ranged) {
                attacker.player_ptr->infernal_flame_flicker_primed_ = false;
                int ff_total = 0;
                for (int i = 0; i < attacker.player_ptr->infernal_flame_flicker_hp_sacrificed_; ++i) ff_total += dice.roll(4);
                attacker.player_ptr->infernal_flame_flicker_hp_sacrificed_ = 0;
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(ff_total, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(ff_total, dice);
                last_action_log_ += " [Flame Flicker Smite: +" + std::to_string(ff_total) + " fire!]";
            }
        }

        // SeraphicFlame: Flame Flicker fire bonus — +1d4 fire per AP invested while toggle active
        if (attacker.is_player && attacker.player_ptr && attacker.player_ptr->seraphic_flame_flicker_ap_cost_ > 0
            && attacker.player_ptr->get_feat_tier(FeatID::SeraphicFlame) >= 1) {
            bool sf_ranged = false;
            if (attacker.player_ptr->get_weapon())
                for (const auto& p : attacker.player_ptr->get_weapon()->get_properties()) if (p.find("Range") != std::string::npos) { sf_ranged = true; break; }
            if (!sf_ranged) {
                int sf_fire = 0;
                for (int i = 0; i < attacker.player_ptr->seraphic_flame_flicker_ap_cost_; ++i) sf_fire += dice.roll(4);
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(sf_fire, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(sf_fire, dice);
                last_action_log_ += " [Seraphic Flame Flicker: +" + std::to_string(sf_fire) + " fire!]";
            }
        }

        // VampiricAscension: Blood Drain — on unarmed (bite) hit, attacker heals half damage dealt
        if (attacker.is_player && attacker.player_ptr && is_unarmed
            && attacker.player_ptr->get_feat_tier(FeatID::VampiricAscension) >= 1) {
            int drain_heal = std::max(1, final_damage / 2);
            attacker.player_ptr->heal(drain_heal);
            last_action_log_ += " [Blood Drain: +" + std::to_string(drain_heal) + " HP!]";
        }

        // LycanthropicCurse: BloodHowl aura — attacker (or any allied player) gains +1d4 damage while howl active
        if (attacker.is_player && attacker.player_ptr) {
            bool howl_active = (attacker.player_ptr->lycanthrope_blood_howl_rounds_ > 0);
            if (!howl_active) {
                for (const auto& ally : combatants_) {
                    if (ally.id != attacker.id && ally.is_player && ally.player_ptr
                        && ally.player_ptr->lycanthrope_blood_howl_rounds_ > 0) { howl_active = true; break; }
                }
            }
            if (howl_active && attacker.player_ptr->get_feat_tier(FeatID::LycanthropicCurse) < 1) howl_active = false;
            if (howl_active) {
                int howl_bonus = dice.roll(4);
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(howl_bonus, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(howl_bonus, dice);
                last_action_log_ += " [BloodHowl: +" + std::to_string(howl_bonus) + " bonus!]";
            }
        }

        if (attacker.is_player && attacker.player_ptr) {
            if (target.get_current_hp() <= 0 && prev_target_hp > 0) {
                if (assassin_tier >= 3) { attacker.player_ptr->advantage_until_tick_ = 10; last_action_log_ += " [Death's Hand: Advantage Gained]"; }
            }
            if (assassin_tier >= 2 && target.get_current_hp() <= 0) {
                if (std::abs(target.get_current_hp()) >= target.get_max_hp()) {
                    if (target.is_player && target.player_ptr) target.player_ptr->current_hp_ = -2 * target.player_ptr->get_max_hp();
                    else if (target.creature_ptr) target.creature_ptr->take_damage(999, dice);
                    last_action_log_ += " [RUTHLESS FINISHER: INSTANT DEATH]";
                }
            }
            if (assassin_tier >= 3 && target.get_current_hp() <= 0 && prev_target_hp > 0) {
                int excess = std::abs(target.get_current_hp());
                int dc = 10 + excess;
                bool instant_death = false;
                if (target.is_player && target.player_ptr) {
                    if (target.player_ptr->roll_stat_check(dice, StatType::Vitality).total < dc) {
                        target.player_ptr->current_hp_ = -2 * target.player_ptr->get_max_hp();
                        instant_death = true;
                    }
                } else if (target.creature_ptr) {
                    int save = dice.roll(20) + target.creature_ptr->get_stats().vitality;
                    if (save < dc) {
                        target.creature_ptr->take_damage(999, dice);
                        instant_death = true;
                    }
                }
                if (instant_death) last_action_log_ += " [Death's Hand: Instant Death (Failed Save DC " + std::to_string(dc) + ")]";
            }
            // TitanicDamage T2: on kill, free attack vs another target
            if (attacker.player_ptr->get_feat_tier(FeatID::TitanicDamage) >= 2 &&
                target.get_current_hp() <= 0 && prev_target_hp > 0) {
                for (auto& potential : combatants_) {
                    if (potential.id != target.id && !potential.is_player && potential.get_current_hp() > 0) {
                        last_action_log_ += "\n[Crushing Impact: free attack on " + potential.name + "] ";
                        bool bonus_hit = execute_attack(attacker, potential, dice, false, 0);
                        last_action_log_ += bonus_hit ? "HIT!" : "MISS.";
                        break;
                    }
                }
            }
            // TwinFang T5: on kill, two free attacks vs another target
            if (attacker.player_ptr->get_feat_tier(FeatID::TwinFang) >= 5 &&
                target.get_current_hp() <= 0 && prev_target_hp > 0) {
                for (auto& potential : combatants_) {
                    if (potential.id != target.id && !potential.is_player && potential.get_current_hp() > 0) {
                        last_action_log_ += "\n[Executioner's Rhythm: free attacks on " + potential.name + "] ";
                        bool h1 = execute_attack(attacker, potential, dice, false, 0);
                        bool h2 = execute_attack(attacker, potential, dice, false, 0);
                        if ((h1 || h2) && potential.get_current_hp() > 0 && potential.get_max_hp() / 2 >= potential.get_current_hp()) {
                            // T5 secondary: follow-up deals +1d6 if target <50% HP
                            int extra = dice.roll(6);
                            if (potential.is_player && potential.player_ptr) potential.player_ptr->take_damage(extra, dice);
                            else if (potential.creature_ptr) potential.creature_ptr->take_damage(extra, dice);
                            last_action_log_ += " [+1d6 below half HP]";
                        }
                        break;
                    }
                }
            }
            // PreciseTactician T5: on crit, chain attack
            if (is_critical && attacker.player_ptr->get_feat_tier(FeatID::PreciseTactician) >= 5) {
                last_action_log_ += "\n[PT V: Chain Attack on crit] ";
                execute_attack(attacker, target, dice, is_unarmed, 0);
            }
        }

        // Canidar: Loyal Strike — when a player ally is hit, a nearby Canidar ally retaliates
        if (target.is_player && target.player_ptr) {
            for (auto& ally : combatants_) {
                if (ally.id != target.id && ally.is_player && ally.player_ptr &&
                    ally.player_ptr->get_lineage().name == "Canidar" &&
                    ally.player_ptr->loyal_strike_reaction_available_ &&
                    ally.get_current_hp() > 0) {
                    if (DungeonManager::instance().get_distance(ally.id, attacker.id) <= 2) {
                        ally.player_ptr->loyal_strike_reaction_available_ = false;
                        // Loyal counter-attack: simplified inline strike (1d8+STR)
                        RollResult loyal_roll = ally.player_ptr->roll_attack(dice, ally.player_ptr->get_weapon());
                        int loyal_ac = attacker.is_player && attacker.player_ptr ? attacker.player_ptr->get_armor_class()
                                     : (attacker.creature_ptr ? 10 + attacker.creature_ptr->get_stats().speed : 10);
                        last_action_log_ += "\n[Loyal Strike: " + ally.name + " retaliates!] ";
                        if (loyal_roll.total >= loyal_ac) {
                            int loyal_dmg = dice.roll(8) + ally.player_ptr->get_stats().strength;
                            if (attacker.is_player && attacker.player_ptr) attacker.player_ptr->take_damage(loyal_dmg, dice);
                            else if (attacker.creature_ptr) attacker.creature_ptr->take_damage(loyal_dmg, dice);
                            last_action_log_ += "HIT for " + std::to_string(loyal_dmg) + "!";
                        } else {
                            last_action_log_ += "MISS.";
                        }
                        break; // only one Canidar reacts per hit
                    }
                }
            }
        }

        // Tetrasimian: Four Arms — one extra light weapon strike per round (1d4+SPD)
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Tetrasimian" &&
            attacker.player_ptr->has_secondary_arms_attack_available_) {
            attacker.player_ptr->has_secondary_arms_attack_available_ = false;
            RollResult sec_roll = attacker.player_ptr->roll_attack(dice, nullptr);
            int sec_ac = (target.is_player && target.player_ptr) ? target.player_ptr->get_armor_class()
                       : (target.creature_ptr ? 10 + target.creature_ptr->get_stats().speed : 10);
            last_action_log_ += "\n[Four Arms: secondary strike] ";
            if (sec_roll.total >= sec_ac) {
                int sec_dmg = dice.roll(4) + attacker.player_ptr->get_stats().speed;
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(sec_dmg, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(sec_dmg, dice);
                last_action_log_ += "HIT for " + std::to_string(sec_dmg) + "!";
            } else {
                last_action_log_ += "MISS.";
            }
        }

        return true;
    } else {
        last_action_log_ = hit_log + " - MISS.";
        if (target.is_player && target.player_ptr) target.player_ptr->on_attack_evaded();

        // Graze effect: AssassinsExecution T1 secondary + SwiftStriker T2 secondary
        if (attacker.is_player && attacker.player_ptr) {
            bool can_graze = false;
            int graze_dmg = 0;
            int ae_tier = attacker.player_ptr->get_feat_tier(FeatID::AssassinsExecution);
            int ss_tier = attacker.player_ptr->get_feat_tier(FeatID::SwiftStriker);
            const auto& wpn_props = attacker.player_ptr->get_weapon() ? attacker.player_ptr->get_weapon()->get_properties() : std::vector<std::string>{};
            bool is_speed_wpn = !is_unarmed && attacker.player_ptr->get_weapon() &&
                std::any_of(wpn_props.begin(), wpn_props.end(), [](const std::string& p){
                    return p == "Finesse" || p.find("Range") != std::string::npos;
                });
            if (ae_tier >= 1 && attacker.player_ptr->graze_uses_remaining_ > 0) {
                can_graze = true;
                graze_dmg = is_speed_wpn ? attacker.player_ptr->get_stats().speed : attacker.player_ptr->get_stats().strength;
                attacker.player_ptr->graze_uses_remaining_--;
            } else if (ss_tier >= 2 && !is_unarmed && attacker.player_ptr->get_weapon() &&
                       attacker.player_ptr->get_weapon()->get_category() == WeaponCategory::Simple) {
                can_graze = true;
                graze_dmg = is_speed_wpn ? attacker.player_ptr->get_stats().speed : attacker.player_ptr->get_stats().strength;
            }
            if (can_graze && graze_dmg > 0) {
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(graze_dmg, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(graze_dmg, dice);
                last_action_log_ += " [Graze: " + std::to_string(graze_dmg) + " dmg]";
            }
            // MartialProwess T3: glancing blow on miss (once per turn)
            if (attacker.player_ptr->get_feat_tier(FeatID::MartialProwess) >= 3 &&
                !attacker.player_ptr->mp_glancing_used_this_turn_) {
                bool single_opponent = true;
                int live_enemies = 0;
                for (const auto& c : combatants_) {
                    if (!c.is_player && c.get_current_hp() > 0) live_enemies++;
                }
                if (live_enemies == 1) single_opponent = true;
                if (single_opponent) {
                    int stat_dmg = is_speed_wpn ? attacker.player_ptr->get_stats().speed : attacker.player_ptr->get_stats().strength;
                    if (target.is_player && target.player_ptr) target.player_ptr->take_damage(stat_dmg, dice);
                    else if (target.creature_ptr) target.creature_ptr->take_damage(stat_dmg, dice);
                    attacker.player_ptr->mp_glancing_used_this_turn_ = true;
                    last_action_log_ += " [Glancing Blow: " + std::to_string(stat_dmg) + "]";
                }
            }
        }

        // Tetrasimian: Four Arms fires on a miss too (it's an action-based extra attack, not hit-based)
        if (attacker.is_player && attacker.player_ptr &&
            attacker.player_ptr->get_lineage().name == "Tetrasimian" &&
            attacker.player_ptr->has_secondary_arms_attack_available_) {
            attacker.player_ptr->has_secondary_arms_attack_available_ = false;
            RollResult sec_roll = attacker.player_ptr->roll_attack(dice, nullptr);
            int sec_ac = (target.is_player && target.player_ptr) ? target.player_ptr->get_armor_class()
                       : (target.creature_ptr ? 10 + target.creature_ptr->get_stats().speed : 10);
            last_action_log_ += "\n[Four Arms: secondary strike] ";
            if (sec_roll.total >= sec_ac) {
                int sec_dmg = dice.roll(4) + attacker.player_ptr->get_stats().speed;
                if (target.is_player && target.player_ptr) target.player_ptr->take_damage(sec_dmg, dice);
                else if (target.creature_ptr) target.creature_ptr->take_damage(sec_dmg, dice);
                last_action_log_ += "HIT for " + std::to_string(sec_dmg) + "!";
            } else {
                last_action_log_ += "MISS.";
            }
        }

        return false;
    }
}

void CombatManager::end_player_phase() {
    current_phase_ = CombatPhase::Enemy;
}

std::string CombatManager::process_enemy_phase(Dice& dice) {
    if (current_phase_ != CombatPhase::Enemy) return "Not enemy phase.";

    std::string log;
    for (size_t i = 0; i < combatants_.size(); ++i) {
        auto& c = combatants_[i];
        if (!c.is_player && c.get_current_hp() > 0 && !c.has_acted) {
            current_combatant_index_ = i;
            log += BehaviorEngine::decide_and_act(c, combatants_, dice) + "\n";
            c.has_acted = true;
        }
    }

    current_phase_ = CombatPhase::Player;
    current_combatant_index_ = 0;
    for (auto& c : combatants_) {
        c.reset_round();
        c.start_turn(); // resets movement_tiles_remaining and AP for the new round
    }
    round_count_++;

    return log.empty() ? "No enemies acted." : log;
}

void CombatManager::end_player_turn() {
    if (current_phase_ != CombatPhase::Player) return;

    auto* current = get_current_combatant();
    if (current && current->is_player) {
        next_turn();
    }
}

} // namespace rimvale
