#include "rimvale_extension.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// Engine headers (same as jni_bridge.cpp)
#include <string>
#include <sstream>
#include <vector>
#include <memory>
#include <algorithm>
#include <set>
#include <unordered_set>
#include <cstdint>
#include "Character.h"
#include "CharacterCreator.h"
#include "Dice.h"
#include "LineageRegistry.h"
#include "Feats.h"
#include "Creature.h"
#include "ItemRegistry.h"
#include "NPC.h"
#include "NpcRegistry.h"
#include "World.h"
#include "Quest.h"
#include "Faction.h"
#include "CombatManager.h"
#include "Base.h"
#include "SpellRegistry.h"
#include "Dungeon.h"
#include "SocietalRoleRegistry.h"
#include "CharacterRegistry.h"
#include "CreatureRegistry.h"

using namespace godot;

// ─── Internal helpers ────────────────────────────────────────────────────────

namespace rimvale {
    static Character* getSafeChar(int64_t handle) {
        return CharacterRegistry::instance().get_character_by_handle(handle);
    }
    static Creature* getSafeCreature(int64_t handle) {
        auto* c = CreatureRegistry::instance().get_creature(handle);
        if (!c) return reinterpret_cast<Creature*>(getSafeChar(handle));
        return c;
    }
}

static PackedStringArray to_psa(const std::vector<std::string>& vec) {
    PackedStringArray arr;
    for (const auto& s : vec) arr.push_back(String(s.c_str()));
    return arr;
}

static std::string dam_to_str(rimvale::DamageType type) {
    switch (type) {
        case rimvale::DamageType::Bludgeoning: return "Bludgeoning";
        case rimvale::DamageType::Piercing:    return "Piercing";
        case rimvale::DamageType::Slashing:    return "Slashing";
        case rimvale::DamageType::Force:       return "Force";
        case rimvale::DamageType::Fire:        return "Fire";
        case rimvale::DamageType::Cold:        return "Cold";
        case rimvale::DamageType::Lightning:   return "Lightning";
        case rimvale::DamageType::Thunder:     return "Thunder";
        case rimvale::DamageType::Acid:        return "Acid";
        case rimvale::DamageType::Poison:      return "Poison";
        case rimvale::DamageType::Psychic:     return "Psychic";
        case rimvale::DamageType::Radiant:     return "Radiant";
        case rimvale::DamageType::Necrotic:    return "Necrotic";
        default:                               return "Unknown";
    }
}

static std::vector<std::string> get_item_info_vec(const rimvale::Item* item) {
    std::vector<std::string> d;
    if (!item) return d;
    std::string r;
    switch (item->get_rarity()) {
        case rimvale::Rarity::Mundane:   r = "Mundane";    break;
        case rimvale::Rarity::Common:    r = "Common";     break;
        case rimvale::Rarity::Uncommon:  r = "Uncommon";   break;
        case rimvale::Rarity::Rare:      r = "Rare";       break;
        case rimvale::Rarity::VeryRare:  r = "Very Rare";  break;
        case rimvale::Rarity::Legendary: r = "Legendary";  break;
        case rimvale::Rarity::Apex:      r = "Apex";       break;
    }
    d.push_back(r);
    d.push_back(std::to_string(item->get_current_hp()));
    d.push_back(std::to_string(item->get_max_hp()));
    d.push_back(std::to_string(item->get_cost_gp()));
    if (auto* w = dynamic_cast<const rimvale::Weapon*>(item)) {
        d.push_back("Weapon"); d.push_back(w->get_damage_dice());
        d.push_back(dam_to_str(w->get_damage_type()));
        d.push_back(w->get_category() == rimvale::WeaponCategory::Simple ? "Simple" : "Martial");
        std::string p; for (const auto& s : w->get_properties()) p += s + ", "; d.push_back(p);
        d.push_back(w->get_mastery());
    } else if (auto* a = dynamic_cast<const rimvale::Armor*>(item)) {
        d.push_back("Armor"); d.push_back(std::to_string(a->get_ac_bonus()));
        d.push_back(std::to_string(a->get_strength_req()));
        d.push_back(a->has_stealth_disadvantage() ? "True" : "False");
        std::string cat;
        switch (a->get_category()) {
            case rimvale::ArmorCategory::Light:       cat = "Light";        break;
            case rimvale::ArmorCategory::Medium:      cat = "Medium";       break;
            case rimvale::ArmorCategory::Heavy:       cat = "Heavy";        break;
            case rimvale::ArmorCategory::Shield:      cat = "Shield";       break;
            case rimvale::ArmorCategory::TowerShield: cat = "Tower Shield"; break;
        }
        d.push_back(cat);
    } else if (item->is_consumable()) {
        d.push_back("Consumable");
    } else {
        d.push_back("General");
    }
    d.push_back(item->get_description());
    return d;
}

static Array spells_to_array(const std::vector<rimvale::Spell>& spells) {
    Array result;
    for (const auto& sp : spells) {
        PackedStringArray sd;
        sd.push_back(String(sp.name.c_str()));
        sd.push_back(String(std::to_string(static_cast<int>(sp.domain)).c_str()));
        sd.push_back(String(std::to_string(sp.base_sp_cost).c_str()));
        sd.push_back(String(sp.description.c_str()));
        sd.push_back(String(std::to_string(static_cast<int>(sp.range)).c_str()));
        sd.push_back(sp.is_attack ? "true" : "false");
        sd.push_back(String(std::to_string(static_cast<int>(sp.area_type)).c_str()));
        sd.push_back(String(std::to_string(sp.max_targets).c_str()));
        sd.push_back(sp.is_teleport ? "true" : "false");
        result.push_back(sd);
    }
    return result;
}

// ─── _bind_methods ────────────────────────────────────────────────────────────

void RimvaleEngine::_bind_methods() {
    // Lineages & Feats
    ClassDB::bind_method(D_METHOD("get_all_lineages"), &RimvaleEngine::get_all_lineages);
    ClassDB::bind_method(D_METHOD("get_lineage_details", "name"), &RimvaleEngine::get_lineage_details);
    ClassDB::bind_method(D_METHOD("get_all_feat_categories"), &RimvaleEngine::get_all_feat_categories);
    ClassDB::bind_method(D_METHOD("get_feat_trees_by_category", "category"), &RimvaleEngine::get_feat_trees_by_category);
    ClassDB::bind_method(D_METHOD("get_feat_trees_by_character", "handle"), &RimvaleEngine::get_feat_trees_by_character);
    ClassDB::bind_method(D_METHOD("get_feats_by_tree", "tree_name"), &RimvaleEngine::get_feats_by_tree);
    ClassDB::bind_method(D_METHOD("get_feats_by_category", "category"), &RimvaleEngine::get_feats_by_category);
    ClassDB::bind_method(D_METHOD("get_feats_by_tier", "tier"), &RimvaleEngine::get_feats_by_tier);
    ClassDB::bind_method(D_METHOD("get_feat_details", "feat_name", "tier"), &RimvaleEngine::get_feat_details);
    ClassDB::bind_method(D_METHOD("get_feat_description", "feat_name", "tier"), &RimvaleEngine::get_feat_description);
    // Societal Roles
    ClassDB::bind_method(D_METHOD("get_all_societal_roles"), &RimvaleEngine::get_all_societal_roles);
    ClassDB::bind_method(D_METHOD("get_societal_role_details", "name"), &RimvaleEngine::get_societal_role_details);
    ClassDB::bind_method(D_METHOD("add_societal_role", "handle", "name"), &RimvaleEngine::add_societal_role);
    ClassDB::bind_method(D_METHOD("get_character_societal_role_name", "handle"), &RimvaleEngine::get_character_societal_role_name);
    ClassDB::bind_method(D_METHOD("set_societal_role", "handle", "name"), &RimvaleEngine::set_societal_role);
    ClassDB::bind_method(D_METHOD("set_character_name", "handle", "name"), &RimvaleEngine::set_character_name);
    // Character Management
    ClassDB::bind_method(D_METHOD("create_character", "name", "lineage_name", "age"), &RimvaleEngine::create_character);
    ClassDB::bind_method(D_METHOD("fuse_characters", "target", "sacrifice"), &RimvaleEngine::fuse_characters);
    ClassDB::bind_method(D_METHOD("get_character_name", "handle"), &RimvaleEngine::get_character_name);
    ClassDB::bind_method(D_METHOD("get_character_id", "handle"), &RimvaleEngine::get_character_id);
    ClassDB::bind_method(D_METHOD("get_character_lineage_name", "handle"), &RimvaleEngine::get_character_lineage_name);
    ClassDB::bind_method(D_METHOD("get_character_level", "handle"), &RimvaleEngine::get_character_level);
    ClassDB::bind_method(D_METHOD("get_character_xp", "handle"), &RimvaleEngine::get_character_xp);
    ClassDB::bind_method(D_METHOD("get_character_xp_required", "handle"), &RimvaleEngine::get_character_xp_required);
    ClassDB::bind_method(D_METHOD("add_xp", "handle", "amount", "level_limit"), &RimvaleEngine::add_xp);
    ClassDB::bind_method(D_METHOD("add_gold", "handle", "amount"), &RimvaleEngine::add_gold);
    ClassDB::bind_method(D_METHOD("get_character_stat_points", "handle"), &RimvaleEngine::get_character_stat_points);
    ClassDB::bind_method(D_METHOD("get_character_feat_points", "handle"), &RimvaleEngine::get_character_feat_points);
    ClassDB::bind_method(D_METHOD("get_character_skill_points", "handle"), &RimvaleEngine::get_character_skill_points);
    ClassDB::bind_method(D_METHOD("get_character_stat", "handle", "stat_type"), &RimvaleEngine::get_character_stat);
    ClassDB::bind_method(D_METHOD("get_character_skill", "handle", "skill_type"), &RimvaleEngine::get_character_skill);
    ClassDB::bind_method(D_METHOD("get_character_feat_tier", "handle", "feat_name"), &RimvaleEngine::get_character_feat_tier);
    ClassDB::bind_method(D_METHOD("can_unlock_feat", "handle", "feat_name", "tier"), &RimvaleEngine::can_unlock_feat);
    ClassDB::bind_method(D_METHOD("spend_stat_point", "handle", "stat_type"), &RimvaleEngine::spend_stat_point);
    ClassDB::bind_method(D_METHOD("spend_skill_point", "handle", "skill_type"), &RimvaleEngine::spend_skill_point);
    ClassDB::bind_method(D_METHOD("spend_feat_point", "handle", "feat_name", "tier"), &RimvaleEngine::spend_feat_point);
    ClassDB::bind_method(D_METHOD("get_character_hp", "handle"), &RimvaleEngine::get_character_hp);
    ClassDB::bind_method(D_METHOD("get_character_max_hp", "handle"), &RimvaleEngine::get_character_max_hp);
    ClassDB::bind_method(D_METHOD("get_character_ap", "handle"), &RimvaleEngine::get_character_ap);
    ClassDB::bind_method(D_METHOD("get_character_max_ap", "handle"), &RimvaleEngine::get_character_max_ap);
    ClassDB::bind_method(D_METHOD("get_character_sp", "handle"), &RimvaleEngine::get_character_sp);
    ClassDB::bind_method(D_METHOD("get_character_max_sp", "handle"), &RimvaleEngine::get_character_max_sp);
    ClassDB::bind_method(D_METHOD("spend_character_sp", "handle", "amount"), &RimvaleEngine::spend_character_sp);
    ClassDB::bind_method(D_METHOD("restore_character_sp", "handle", "amount"), &RimvaleEngine::restore_character_sp);
    ClassDB::bind_method(D_METHOD("get_character_ac", "handle"), &RimvaleEngine::get_character_ac);
    ClassDB::bind_method(D_METHOD("get_character_movement_speed", "handle"), &RimvaleEngine::get_character_movement_speed);
    ClassDB::bind_method(D_METHOD("get_character_injuries", "handle"), &RimvaleEngine::get_character_injuries);
    ClassDB::bind_method(D_METHOD("get_character_conditions", "handle"), &RimvaleEngine::get_character_conditions);
    ClassDB::bind_method(D_METHOD("character_take_damage", "handle", "amount"), &RimvaleEngine::character_take_damage);
    ClassDB::bind_method(D_METHOD("character_start_turn", "handle"), &RimvaleEngine::character_start_turn);
    ClassDB::bind_method(D_METHOD("short_rest", "handle"), &RimvaleEngine::short_rest);
    ClassDB::bind_method(D_METHOD("long_rest", "handle"), &RimvaleEngine::long_rest);
    ClassDB::bind_method(D_METHOD("rest_party", "handles"), &RimvaleEngine::rest_party);
    ClassDB::bind_method(D_METHOD("serialize_character", "handle"), &RimvaleEngine::serialize_character);
    ClassDB::bind_method(D_METHOD("deserialize_character", "data"), &RimvaleEngine::deserialize_character);
    ClassDB::bind_method(D_METHOD("destroy_character", "handle"), &RimvaleEngine::destroy_character);
    ClassDB::bind_method(D_METHOD("is_proficient_in_saving_throw", "handle", "stat_type"), &RimvaleEngine::is_proficient_in_saving_throw);
    ClassDB::bind_method(D_METHOD("toggle_saving_throw_proficiency", "handle", "stat_type"), &RimvaleEngine::toggle_saving_throw_proficiency);
    ClassDB::bind_method(D_METHOD("is_favored_skill", "handle", "skill_type"), &RimvaleEngine::is_favored_skill);
    ClassDB::bind_method(D_METHOD("toggle_favored_skill", "handle", "skill_type"), &RimvaleEngine::toggle_favored_skill);
    // Magic
    ClassDB::bind_method(D_METHOD("get_learned_spells", "handle"), &RimvaleEngine::get_learned_spells);
    ClassDB::bind_method(D_METHOD("learn_spell", "handle", "spell_name"), &RimvaleEngine::learn_spell);
    ClassDB::bind_method(D_METHOD("forget_spell", "handle", "spell_name"), &RimvaleEngine::forget_spell);
    ClassDB::bind_method(D_METHOD("get_all_spells"), &RimvaleEngine::get_all_spells);
    ClassDB::bind_method(D_METHOD("get_spells_by_domain", "domain"), &RimvaleEngine::get_spells_by_domain);
    ClassDB::bind_method(D_METHOD("get_custom_spells"), &RimvaleEngine::get_custom_spells);
    ClassDB::bind_method(D_METHOD("add_custom_spell", "name", "domain", "cost", "description", "range", "is_attack", "die_count", "die_sides", "damage_type", "is_healing", "duration_rounds", "max_targets", "area_type", "conditions_csv", "is_teleport"), &RimvaleEngine::add_custom_spell);
    ClassDB::bind_method(D_METHOD("get_active_matrices", "combatant_id"), &RimvaleEngine::get_active_matrices);
    // Inventory
    ClassDB::bind_method(D_METHOD("get_inventory_gold", "handle"), &RimvaleEngine::get_inventory_gold);
    ClassDB::bind_method(D_METHOD("get_inventory_items", "handle"), &RimvaleEngine::get_inventory_items);
    ClassDB::bind_method(D_METHOD("use_consumable", "handle", "item_name"), &RimvaleEngine::use_consumable);
    ClassDB::bind_method(D_METHOD("get_item_details", "handle", "item_name"), &RimvaleEngine::get_item_details);
    ClassDB::bind_method(D_METHOD("get_registry_item_details", "item_name"), &RimvaleEngine::get_registry_item_details);
    ClassDB::bind_method(D_METHOD("add_item_to_inventory", "handle", "item_name"), &RimvaleEngine::add_item_to_inventory);
    ClassDB::bind_method(D_METHOD("remove_item_from_inventory", "handle", "item_name"), &RimvaleEngine::remove_item_from_inventory);
    ClassDB::bind_method(D_METHOD("equip_item", "handle", "item_name"), &RimvaleEngine::equip_item);
    ClassDB::bind_method(D_METHOD("unequip_item", "handle", "slot"), &RimvaleEngine::unequip_item);
    ClassDB::bind_method(D_METHOD("get_equipped_weapon", "handle"), &RimvaleEngine::get_equipped_weapon);
    ClassDB::bind_method(D_METHOD("get_equipped_armor", "handle"), &RimvaleEngine::get_equipped_armor);
    ClassDB::bind_method(D_METHOD("get_equipped_shield", "handle"), &RimvaleEngine::get_equipped_shield);
    ClassDB::bind_method(D_METHOD("get_equipped_light_source", "handle"), &RimvaleEngine::get_equipped_light_source);
    ClassDB::bind_method(D_METHOD("get_all_registry_weapons"), &RimvaleEngine::get_all_registry_weapons);
    ClassDB::bind_method(D_METHOD("get_all_registry_armor"), &RimvaleEngine::get_all_registry_armor);
    ClassDB::bind_method(D_METHOD("get_all_registry_general_items"), &RimvaleEngine::get_all_registry_general_items);
    ClassDB::bind_method(D_METHOD("get_all_registry_magic_items"), &RimvaleEngine::get_all_registry_magic_items);
    ClassDB::bind_method(D_METHOD("get_all_registry_mundane_items"), &RimvaleEngine::get_all_registry_mundane_items);
    // Creatures
    ClassDB::bind_method(D_METHOD("spawn_creature", "name", "category", "level"), &RimvaleEngine::spawn_creature);
    ClassDB::bind_method(D_METHOD("set_creature_stats", "handle", "str", "spd", "intel", "vit", "div"), &RimvaleEngine::set_creature_stats);
    ClassDB::bind_method(D_METHOD("set_creature_feat", "handle", "feat_name", "tier"), &RimvaleEngine::set_creature_feat);
    ClassDB::bind_method(D_METHOD("get_creature_name", "handle"), &RimvaleEngine::get_creature_name);
    ClassDB::bind_method(D_METHOD("get_creature_id", "handle"), &RimvaleEngine::get_creature_id);
    ClassDB::bind_method(D_METHOD("get_creature_hp", "handle"), &RimvaleEngine::get_creature_hp);
    ClassDB::bind_method(D_METHOD("get_creature_max_hp", "handle"), &RimvaleEngine::get_creature_max_hp);
    ClassDB::bind_method(D_METHOD("get_creature_ap", "handle"), &RimvaleEngine::get_creature_ap);
    ClassDB::bind_method(D_METHOD("get_creature_max_ap", "handle"), &RimvaleEngine::get_creature_max_ap);
    ClassDB::bind_method(D_METHOD("get_creature_movement_speed", "handle"), &RimvaleEngine::get_creature_movement_speed);
    ClassDB::bind_method(D_METHOD("get_creature_threshold", "handle"), &RimvaleEngine::get_creature_threshold);
    ClassDB::bind_method(D_METHOD("get_creature_ac", "handle"), &RimvaleEngine::get_creature_ac);
    ClassDB::bind_method(D_METHOD("get_creature_conditions", "handle"), &RimvaleEngine::get_creature_conditions);
    ClassDB::bind_method(D_METHOD("creature_take_damage", "handle", "amount"), &RimvaleEngine::creature_take_damage);
    ClassDB::bind_method(D_METHOD("destroy_creature", "handle"), &RimvaleEngine::destroy_creature);
    ClassDB::bind_method(D_METHOD("get_creature_inventory_items", "handle"), &RimvaleEngine::get_creature_inventory_items);
    ClassDB::bind_method(D_METHOD("loot_creature", "creature_handle", "player_handle"), &RimvaleEngine::loot_creature);
    // NPCs
    ClassDB::bind_method(D_METHOD("get_all_registered_npcs"), &RimvaleEngine::get_all_registered_npcs);
    ClassDB::bind_method(D_METHOD("spawn_registered_npc", "name"), &RimvaleEngine::spawn_registered_npc);
    ClassDB::bind_method(D_METHOD("set_npc_drivers", "handle", "community", "validation", "resources"), &RimvaleEngine::set_npc_drivers);
    ClassDB::bind_method(D_METHOD("get_npc_disposition", "handle"), &RimvaleEngine::get_npc_disposition);
    ClassDB::bind_method(D_METHOD("get_npc_disposition_text", "handle"), &RimvaleEngine::get_npc_disposition_text);
    ClassDB::bind_method(D_METHOD("interact_with_npc", "handle", "community_mod", "validation_mod", "resource_mod"), &RimvaleEngine::interact_with_npc);
    ClassDB::bind_method(D_METHOD("spawn_adversary", "name", "level"), &RimvaleEngine::spawn_adversary);
    ClassDB::bind_method(D_METHOD("get_adversary_vengeance_bonus", "handle"), &RimvaleEngine::get_adversary_vengeance_bonus);
    ClassDB::bind_method(D_METHOD("adversary_survive_encounter", "handle"), &RimvaleEngine::adversary_survive_encounter);
    // World
    ClassDB::bind_method(D_METHOD("get_all_regions"), &RimvaleEngine::get_all_regions);
    ClassDB::bind_method(D_METHOD("get_region_details", "region_name"), &RimvaleEngine::get_region_details);
    ClassDB::bind_method(D_METHOD("get_region_terrains", "region_name"), &RimvaleEngine::get_region_terrains);
    ClassDB::bind_method(D_METHOD("get_terrain_details", "region_name", "terrain_name"), &RimvaleEngine::get_terrain_details);
    ClassDB::bind_method(D_METHOD("get_quests_by_region", "region_name"), &RimvaleEngine::get_quests_by_region);
    ClassDB::bind_method(D_METHOD("get_quest_regions"), &RimvaleEngine::get_quest_regions);
    ClassDB::bind_method(D_METHOD("generate_quest"), &RimvaleEngine::generate_quest);
    // Factions
    ClassDB::bind_method(D_METHOD("get_all_factions"), &RimvaleEngine::get_all_factions);
    ClassDB::bind_method(D_METHOD("get_faction_details", "faction_name"), &RimvaleEngine::get_faction_details);
    ClassDB::bind_method(D_METHOD("get_faction_ranks", "faction_name"), &RimvaleEngine::get_faction_ranks);
    // Combat
    ClassDB::bind_method(D_METHOD("start_combat"), &RimvaleEngine::start_combat);
    ClassDB::bind_method(D_METHOD("add_player_to_combat", "handle"), &RimvaleEngine::add_player_to_combat);
    ClassDB::bind_method(D_METHOD("add_creature_to_combat", "handle"), &RimvaleEngine::add_creature_to_combat);
    ClassDB::bind_method(D_METHOD("next_turn"), &RimvaleEngine::next_turn);
    ClassDB::bind_method(D_METHOD("set_current_combatant_by_id", "id"), &RimvaleEngine::set_current_combatant_by_id);
    ClassDB::bind_method(D_METHOD("end_player_phase"), &RimvaleEngine::end_player_phase);
    ClassDB::bind_method(D_METHOD("get_current_combatant_name"), &RimvaleEngine::get_current_combatant_name);
    ClassDB::bind_method(D_METHOD("get_current_combatant_id"), &RimvaleEngine::get_current_combatant_id);
    ClassDB::bind_method(D_METHOD("get_current_combatant_is_player"), &RimvaleEngine::get_current_combatant_is_player);
    ClassDB::bind_method(D_METHOD("get_current_combatant_ap"), &RimvaleEngine::get_current_combatant_ap);
    ClassDB::bind_method(D_METHOD("get_current_combatant_hp"), &RimvaleEngine::get_current_combatant_hp);
    ClassDB::bind_method(D_METHOD("get_combat_round"), &RimvaleEngine::get_combat_round);
    ClassDB::bind_method(D_METHOD("get_action_cost", "action", "extra_param"), &RimvaleEngine::get_action_cost);
    ClassDB::bind_method(D_METHOD("perform_action", "action", "extra_param"), &RimvaleEngine::perform_action);
    ClassDB::bind_method(D_METHOD("process_enemy_phase"), &RimvaleEngine::process_enemy_phase);
    ClassDB::bind_method(D_METHOD("get_last_action_log"), &RimvaleEngine::get_last_action_log);
    ClassDB::bind_method(D_METHOD("get_initiative_order"), &RimvaleEngine::get_initiative_order);
    ClassDB::bind_method(D_METHOD("set_mission_active", "active"), &RimvaleEngine::set_mission_active);
    // Base Building
    ClassDB::bind_method(D_METHOD("create_base", "name", "tier"), &RimvaleEngine::create_base);
    ClassDB::bind_method(D_METHOD("get_base_name", "handle"), &RimvaleEngine::get_base_name);
    ClassDB::bind_method(D_METHOD("get_base_tier", "handle"), &RimvaleEngine::get_base_tier);
    ClassDB::bind_method(D_METHOD("get_base_stats", "handle"), &RimvaleEngine::get_base_stats);
    ClassDB::bind_method(D_METHOD("get_base_max_facilities", "handle"), &RimvaleEngine::get_base_max_facilities);
    ClassDB::bind_method(D_METHOD("get_base_facilities", "handle"), &RimvaleEngine::get_base_facilities);
    ClassDB::bind_method(D_METHOD("add_facility_to_base", "handle", "type"), &RimvaleEngine::add_facility_to_base);
    ClassDB::bind_method(D_METHOD("get_base_defense_modifier", "handle"), &RimvaleEngine::get_base_defense_modifier);
    ClassDB::bind_method(D_METHOD("destroy_base", "handle"), &RimvaleEngine::destroy_base);
    // Dice
    ClassDB::bind_method(D_METHOD("roll_skill", "handle", "skill_id"), &RimvaleEngine::roll_skill);
    ClassDB::bind_method(D_METHOD("roll_skill_check", "handle", "skill_id", "stat_id"), &RimvaleEngine::roll_skill_check);
    // Dungeon
    ClassDB::bind_method(D_METHOD("start_dungeon", "player_handles", "enemy_level", "specific_enemy_handle", "terrain_style"), &RimvaleEngine::start_dungeon);
    ClassDB::bind_method(D_METHOD("end_dungeon"), &RimvaleEngine::end_dungeon);
    ClassDB::bind_method(D_METHOD("get_dungeon_map"), &RimvaleEngine::get_dungeon_map);
    ClassDB::bind_method(D_METHOD("get_dungeon_elevation"), &RimvaleEngine::get_dungeon_elevation);
    ClassDB::bind_method(D_METHOD("get_dungeon_entities"), &RimvaleEngine::get_dungeon_entities);
    ClassDB::bind_method(D_METHOD("move_dungeon_player", "id", "nx", "ny"), &RimvaleEngine::move_dungeon_player);
    ClassDB::bind_method(D_METHOD("get_valid_dungeon_moves", "id"), &RimvaleEngine::get_valid_dungeon_moves);
    ClassDB::bind_method(D_METHOD("is_dungeon_player_phase"), &RimvaleEngine::is_dungeon_player_phase);
    ClassDB::bind_method(D_METHOD("collect_loot", "player_handle"), &RimvaleEngine::collect_loot);
    ClassDB::bind_method(D_METHOD("get_lineage_trait_states", "handle"), &RimvaleEngine::get_lineage_trait_states);
    ClassDB::bind_method(D_METHOD("get_feat_action_states", "handle"), &RimvaleEngine::get_feat_action_states);
    ClassDB::bind_method(D_METHOD("get_safeguard_chosen_stats", "handle"), &RimvaleEngine::get_safeguard_chosen_stats);
    ClassDB::bind_method(D_METHOD("set_safeguard_chosen_stats", "handle", "stats"), &RimvaleEngine::set_safeguard_chosen_stats);
}

// ─── Implementations ──────────────────────────────────────────────────────────

PackedStringArray RimvaleEngine::get_all_lineages() {
    return to_psa(rimvale::LineageRegistry::instance().get_all_names());
}
PackedStringArray RimvaleEngine::get_lineage_details(String name) {
    const auto* l = rimvale::LineageRegistry::instance().get_lineage(name.utf8().get_data());
    std::vector<std::string> d;
    if (l) {
        d.push_back(l->type); d.push_back(std::to_string(l->base_speed));
        std::string f; for (const auto& s : l->features) f += s + "||"; d.push_back(f);
        std::string ln; for (const auto& s : l->languages) ln += s + ", "; d.push_back(ln);
        d.push_back(l->description); d.push_back(l->culture);
    }
    return to_psa(d);
}
PackedStringArray RimvaleEngine::get_all_feat_categories() {
    return to_psa({"Stat feats", "Weapons and Combat feats", "Armor feats", "Magic feats",
                   "Alignment feats", "Domain feats", "Exploration feats", "Crafting feats",
                   "Apex feats", "Ascendant Feats"});
}
PackedStringArray RimvaleEngine::get_feat_trees_by_category(String category) {
    auto feats = rimvale::FeatRegistry::instance().get_feats_by_category(category.utf8().get_data());
    std::set<std::string> trees;
    for (const auto& f : feats) if (!f.tree_name.empty()) trees.insert(f.tree_name);
    return to_psa(std::vector<std::string>(trees.begin(), trees.end()));
}
PackedStringArray RimvaleEngine::get_feat_trees_by_character(int64_t handle) {
    auto* c = rimvale::getSafeChar(handle);
    if (!c) return PackedStringArray();
    std::string dom;
    switch (c->get_domain()) {
        case rimvale::Domain::Biological: dom = "Biological Domain"; break;
        case rimvale::Domain::Chemical:   dom = "Chemical Domain";   break;
        case rimvale::Domain::Physical:   dom = "Physical Domain";   break;
        case rimvale::Domain::Spiritual:  dom = "Spiritual Domain";  break;
    }
    return to_psa({dom, "Arcane Wellspring", "Iron Vitality", "Martial Focus", "Safeguard"});
}
PackedStringArray RimvaleEngine::get_feats_by_tree(String tree_name) {
    auto feats = rimvale::FeatRegistry::instance().get_feats_by_tree(tree_name.utf8().get_data());
    std::vector<std::string> names;
    for (const auto& f : feats) names.push_back(f.name + " (Tier " + std::to_string(f.tier) + ")");
    return to_psa(names);
}
PackedStringArray RimvaleEngine::get_feats_by_category(String category) {
    auto feats = rimvale::FeatRegistry::instance().get_feats_by_category(category.utf8().get_data());
    std::vector<std::string> names;
    for (const auto& f : feats) names.push_back(f.name);
    return to_psa(names);
}
PackedStringArray RimvaleEngine::get_feats_by_tier(int tier) {
    auto feats = rimvale::FeatRegistry::instance().get_feats_by_tier(tier);
    std::vector<std::string> names;
    for (const auto& f : feats) names.push_back(f.name);
    return to_psa(names);
}
PackedStringArray RimvaleEngine::get_feat_details(String feat_name, int tier) {
    const auto* f = rimvale::FeatRegistry::instance().find_feat_by_name(feat_name.utf8().get_data());
    return to_psa({f ? f->description : "Not found", f ? f->category : "Unknown", f ? f->tree_name : ""});
}
String RimvaleEngine::get_feat_description(String feat_name, int tier) {
    std::string desc = "Not found";
    for (const auto& f : rimvale::FeatRegistry::instance().get_all_feats())
        if (f.name == feat_name.utf8().get_data() && f.tier == tier) { desc = f.description; break; }
    return String(desc.c_str());
}

PackedStringArray RimvaleEngine::get_all_societal_roles() {
    const auto& roles = rimvale::SocietalRoleRegistry::instance().get_all_roles();
    std::vector<std::string> names;
    for (const auto& r : roles) names.push_back(r.name);
    return to_psa(names);
}
PackedStringArray RimvaleEngine::get_societal_role_details(String name) {
    const auto* r = rimvale::SocietalRoleRegistry::instance().get_role(name.utf8().get_data());
    std::vector<std::string> d;
    if (r) { d.push_back(r->primary_benefit); d.push_back(r->secondary_benefit); d.push_back(r->description); }
    return to_psa(d);
}
void RimvaleEngine::add_societal_role(int64_t handle, String name) {
    auto* c = rimvale::getSafeChar(handle);
    const auto* r = rimvale::SocietalRoleRegistry::instance().get_role(name.utf8().get_data());
    if (c && r) c->add_societal_role(*r);
}
String RimvaleEngine::get_character_societal_role_name(int64_t handle) {
    auto* c = rimvale::getSafeChar(handle);
    if (c && !c->get_societal_roles().empty()) return String(c->get_societal_roles()[0].name.c_str());
    return String("");
}
void RimvaleEngine::set_societal_role(int64_t handle, String name) {
    auto* c = rimvale::getSafeChar(handle);
    const auto* r = rimvale::SocietalRoleRegistry::instance().get_role(name.utf8().get_data());
    if (c && r) { c->clear_societal_roles(); c->add_societal_role(*r); }
}
void RimvaleEngine::set_character_name(int64_t handle, String name) {
    auto* c = rimvale::getSafeChar(handle);
    if (c) c->set_name(name.utf8().get_data());
}

int64_t RimvaleEngine::create_character(String name, String lineage_name, int age) {
    const auto* l_ptr = rimvale::LineageRegistry::instance().get_lineage(lineage_name.utf8().get_data());
    auto* c = new rimvale::Character(name.utf8().get_data(),
                                      l_ptr ? *l_ptr : rimvale::Lineage{lineage_name.utf8().get_data(), "Unknown"});
    c->set_age(age);
    rimvale::CharacterRegistry::instance().register_character(c);
    return reinterpret_cast<int64_t>(c);
}
void RimvaleEngine::fuse_characters(int64_t target, int64_t sacrifice) {
    auto* t = rimvale::getSafeChar(target); auto* s = rimvale::getSafeChar(sacrifice);
    if (t && s) t->fuse_with(*s);
}
String RimvaleEngine::get_character_name(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c ? c->get_name().c_str() : ""); }
String RimvaleEngine::get_character_id(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c ? c->get_id().c_str() : ""); }
String RimvaleEngine::get_character_lineage_name(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c ? c->get_lineage().name.c_str() : "Unknown"); }
int RimvaleEngine::get_character_level(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_level() : 1; }
int RimvaleEngine::get_character_xp(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_xp() : 0; }
int RimvaleEngine::get_character_xp_required(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_xp_required() : 3; }
void RimvaleEngine::add_xp(int64_t handle, int amount, int level_limit) { if (auto* c = rimvale::getSafeChar(handle)) c->add_xp(amount, level_limit); }
void RimvaleEngine::add_gold(int64_t handle, int amount) { if (auto* c = rimvale::getSafeChar(handle)) c->add_gold(amount); }
int RimvaleEngine::get_character_stat_points(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_stat_points() : 0; }
int RimvaleEngine::get_character_feat_points(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_feat_points() : 0; }
int RimvaleEngine::get_character_skill_points(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_skill_points() : 0; }
int RimvaleEngine::get_character_stat(int64_t handle, int stat_type) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_stats().get_stat(static_cast<rimvale::StatType>(stat_type)) : 0; }
int RimvaleEngine::get_character_skill(int64_t handle, int skill_type) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_skills().get_skill(static_cast<rimvale::SkillType>(skill_type)) : 0; }
int RimvaleEngine::get_character_feat_tier(int64_t handle, String feat_name) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return 0;
    const auto* f = rimvale::FeatRegistry::instance().find_feat_by_name(feat_name.utf8().get_data());
    return f ? c->get_feat_tier(f->id) : 0;
}
bool RimvaleEngine::can_unlock_feat(int64_t handle, String feat_name, int tier) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return false;
    const auto* f = rimvale::FeatRegistry::instance().find_feat_by_name(feat_name.utf8().get_data());
    if (!f) return false;
    int cur = c->get_feat_tier(f->id); bool lvl_ok = true; int lvl = c->get_level();
    if (tier == 2 && lvl < 5)  lvl_ok = false;
    if (tier == 3 && lvl < 9)  lvl_ok = false;
    if (tier == 4 && lvl < 13) lvl_ok = false;
    if (tier == 5 && lvl < 17) lvl_ok = false;
    return lvl_ok && (cur < tier) && (c->get_feat_points() >= tier) &&
           rimvale::FeatRegistry::instance().is_next_available_tier(f->id, cur, tier);
}
bool RimvaleEngine::spend_stat_point(int64_t handle, int stat_type) { auto* c = rimvale::getSafeChar(handle); return c ? c->spend_stat_point(static_cast<rimvale::StatType>(stat_type)) : false; }
bool RimvaleEngine::spend_skill_point(int64_t handle, int skill_type) { auto* c = rimvale::getSafeChar(handle); return c ? c->spend_skill_point(static_cast<rimvale::SkillType>(skill_type)) : false; }
bool RimvaleEngine::spend_feat_point(int64_t handle, String feat_name, int tier) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return false;
    const auto* f = rimvale::FeatRegistry::instance().find_feat_by_name(feat_name.utf8().get_data());
    return f ? c->spend_feat_point(f->id, tier) : false;
}
int RimvaleEngine::get_character_hp(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->current_hp_ : 0; }
int RimvaleEngine::get_character_max_hp(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_max_hp() : 0; }
int RimvaleEngine::get_character_ap(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->current_ap_ : 0; }
int RimvaleEngine::get_character_max_ap(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_max_ap() : 0; }
int RimvaleEngine::get_character_sp(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->current_sp_ : 0; }
int RimvaleEngine::get_character_max_sp(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_max_sp() : 0; }
bool RimvaleEngine::spend_character_sp(int64_t handle, int amount) { auto* c = rimvale::getSafeChar(handle); if (!c || c->current_sp_ < amount) return false; c->current_sp_ -= amount; return true; }
void RimvaleEngine::restore_character_sp(int64_t handle, int amount) { if (auto* c = rimvale::getSafeChar(handle)) c->restore_sp(amount); }
int RimvaleEngine::get_character_ac(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_armor_class() : 0; }
int RimvaleEngine::get_character_movement_speed(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_movement_speed() : 0; }
PackedStringArray RimvaleEngine::get_character_injuries(int64_t handle) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return PackedStringArray();
    std::vector<std::string> names; for (const auto& i : c->injuries_) names.push_back(i.name);
    return to_psa(names);
}
PackedStringArray RimvaleEngine::get_character_conditions(int64_t handle) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return PackedStringArray();
    std::vector<std::string> names;
    for (const auto& cond : c->get_status().get_conditions())
        names.push_back(rimvale::StatusManager::get_condition_name(cond));
    return to_psa(names);
}
int RimvaleEngine::character_take_damage(int64_t handle, int amount) { auto* c = rimvale::getSafeChar(handle); if (c) { rimvale::Dice d; c->take_damage(amount, d); return c->current_hp_; } return 0; }
void RimvaleEngine::character_start_turn(int64_t handle) { if (auto* c = rimvale::getSafeChar(handle)) c->start_turn(); }
void RimvaleEngine::short_rest(int64_t handle) { if (auto* c = rimvale::getSafeChar(handle)) { rimvale::Dice d; c->short_rest(d); } }
void RimvaleEngine::long_rest(int64_t handle) { if (auto* c = rimvale::getSafeChar(handle)) c->long_rest(); }
bool RimvaleEngine::rest_party(PackedInt64Array handles) {
    if (rimvale::CombatManager::instance().is_dungeon_mode() || rimvale::CombatManager::instance().is_mission_active()) return false;
    for (int i = 0; i < handles.size(); ++i) { if (auto* c = rimvale::getSafeChar(handles[i])) c->long_rest(); }
    return true;
}
String RimvaleEngine::serialize_character(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c ? c->serialize().c_str() : ""); }
int64_t RimvaleEngine::deserialize_character(String data) {
    auto c = rimvale::Character::deserialize(data.utf8().get_data());
    if (!c) return 0L;
    auto* ptr = c.release();
    rimvale::CharacterRegistry::instance().register_character(ptr);
    return reinterpret_cast<int64_t>(ptr);
}
void RimvaleEngine::destroy_character(int64_t handle) { auto* c = rimvale::getSafeChar(handle); if (c) { rimvale::CharacterRegistry::instance().unregister_character(handle); delete c; } }
bool RimvaleEngine::is_proficient_in_saving_throw(int64_t handle, int stat_type) { auto* c = rimvale::getSafeChar(handle); return c ? c->is_proficient_in_saving_throw(static_cast<rimvale::StatType>(stat_type)) : false; }
void RimvaleEngine::toggle_saving_throw_proficiency(int64_t handle, int stat_type) { if (auto* c = rimvale::getSafeChar(handle)) c->toggle_saving_throw_proficiency(static_cast<rimvale::StatType>(stat_type)); }
bool RimvaleEngine::is_favored_skill(int64_t handle, int skill_type) { auto* c = rimvale::getSafeChar(handle); return c ? c->is_favored_skill(static_cast<rimvale::SkillType>(skill_type)) : false; }
bool RimvaleEngine::toggle_favored_skill(int64_t handle, int skill_type) { auto* c = rimvale::getSafeChar(handle); return c ? c->toggle_favored_skill(static_cast<rimvale::SkillType>(skill_type)) : false; }

PackedStringArray RimvaleEngine::get_learned_spells(int64_t handle) { auto* c = rimvale::getSafeChar(handle); if (!c) return PackedStringArray(); return to_psa(c->get_learned_spells()); }
void RimvaleEngine::learn_spell(int64_t handle, String spell_name) { if (auto* c = rimvale::getSafeChar(handle)) c->add_learned_spell(spell_name.utf8().get_data()); }
void RimvaleEngine::forget_spell(int64_t handle, String spell_name) { if (auto* c = rimvale::getSafeChar(handle)) c->remove_learned_spell(spell_name.utf8().get_data()); }
Array RimvaleEngine::get_all_spells() { return spells_to_array(rimvale::SpellRegistry::instance().get_all_spells()); }
Array RimvaleEngine::get_spells_by_domain(int domain) { return spells_to_array(rimvale::SpellRegistry::instance().get_spells_by_domain(static_cast<rimvale::Domain>(domain))); }
Array RimvaleEngine::get_custom_spells() { return spells_to_array(rimvale::SpellRegistry::instance().get_custom_spells()); }
void RimvaleEngine::add_custom_spell(String name, int domain, int cost, String description, int range, bool is_attack, int die_count, int die_sides, int damage_type, bool is_healing, int duration_rounds, int max_targets, int area_type, String conditions_csv, bool is_teleport) {
    std::vector<rimvale::ConditionType> conds;
    std::string csv(conditions_csv.utf8().get_data()); std::stringstream ss(csv); std::string token;
    while (std::getline(ss, token, ',')) { if (!token.empty()) { try { conds.push_back(static_cast<rimvale::ConditionType>(std::stoi(token))); } catch (...) {} } }
    rimvale::Spell s = { name.utf8().get_data(), static_cast<rimvale::Domain>(domain), cost, description.utf8().get_data(), static_cast<rimvale::SpellRange>(range), is_attack, die_count, die_sides, true, static_cast<rimvale::DamageType>(damage_type), is_healing, conds, duration_rounds, max_targets, static_cast<rimvale::SpellAreaType>(area_type), is_teleport };
    rimvale::SpellRegistry::instance().add_custom_spell(s);
}
PackedStringArray RimvaleEngine::get_active_matrices(String combatant_id) {
    auto* c = rimvale::CombatManager::instance().find_combatant_by_id(combatant_id.utf8().get_data());
    std::vector<std::string> res;
    if (c) {
        for (const auto& m : c->active_matrices) {
            bool is_atk = false;
            const auto* spell = rimvale::SpellRegistry::instance().find_spell(m.spell_name);
            if (spell) is_atk = spell->is_attack;
            res.push_back(m.spell_name + "|" + std::to_string(m.duration_rounds) + "|" + m.bound_item_name + "|" + (m.suppressed ? "true" : "false") + "|" + (is_atk ? "true" : "false"));
        }
    }
    return to_psa(res);
}

int RimvaleEngine::get_inventory_gold(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return c ? c->get_inventory().get_gold() : 0; }
PackedStringArray RimvaleEngine::get_inventory_items(int64_t handle) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return PackedStringArray();
    std::vector<std::string> names; for (const auto& i : c->get_inventory().get_items()) names.push_back(i->get_name());
    return to_psa(names);
}
String RimvaleEngine::use_consumable(int64_t handle, String item_name) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return String("No char.");
    std::string res = "Not found"; auto& inv = c->get_inventory();
    for (const auto& i : inv.get_items()) if (i->get_name() == item_name.utf8().get_data() && i->is_consumable()) {
        res = dynamic_cast<rimvale::Consumable*>(i.get())->use(c); inv.remove_item(item_name.utf8().get_data()); break;
    }
    return String(res.c_str());
}
PackedStringArray RimvaleEngine::get_item_details(int64_t handle, String item_name) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return PackedStringArray();
    std::vector<std::string> det;
    for (const auto& i : c->get_inventory().get_items()) if (i->get_name() == item_name.utf8().get_data()) { det = get_item_info_vec(i.get()); break; }
    return to_psa(det);
}
PackedStringArray RimvaleEngine::get_registry_item_details(String item_name) {
    std::unique_ptr<rimvale::Item> i_ptr;
    auto w = rimvale::ItemRegistry::instance().create_weapon(item_name.utf8().get_data());
    if (w) i_ptr = std::move(w);
    else { auto a = rimvale::ItemRegistry::instance().create_armor(item_name.utf8().get_data()); if (a) i_ptr = std::move(a); else i_ptr = rimvale::ItemRegistry::instance().create_general_item(item_name.utf8().get_data()); }
    return to_psa(get_item_info_vec(i_ptr.get()));
}
void RimvaleEngine::add_item_to_inventory(int64_t handle, String item_name) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return;
    auto w = rimvale::ItemRegistry::instance().create_weapon(item_name.utf8().get_data()); if (w) c->get_inventory().add_item(std::move(w));
    else { auto a = rimvale::ItemRegistry::instance().create_armor(item_name.utf8().get_data()); if (a) c->get_inventory().add_item(std::move(a)); else { auto i = rimvale::ItemRegistry::instance().create_general_item(item_name.utf8().get_data()); if (i) c->get_inventory().add_item(std::move(i)); } }
}
void RimvaleEngine::remove_item_from_inventory(int64_t handle, String item_name) { auto* c = rimvale::getSafeChar(handle); if (c) c->get_inventory().remove_item(item_name.utf8().get_data()); }
void RimvaleEngine::equip_item(int64_t handle, String item_name) {
    static const std::unordered_set<std::string> kLightSources = {"Torch", "Lantern, Bullseye", "Lantern, Hooded", "Lamp", "Candle"};
    auto* c = rimvale::getSafeChar(handle); if (!c) return;
    std::string nameStr(item_name.utf8().get_data());
    if (kLightSources.count(nameStr)) { c->equip_light_source(nameStr); return; }
    for (const auto& i : c->get_inventory().get_items()) if (i->get_name() == nameStr) {
        if (dynamic_cast<rimvale::Weapon*>(i.get())) c->equip_weapon(rimvale::ItemRegistry::instance().create_weapon(nameStr));
        else if (auto* a = dynamic_cast<rimvale::Armor*>(i.get())) {
            if (a->get_category() == rimvale::ArmorCategory::Shield || a->get_category() == rimvale::ArmorCategory::TowerShield)
                c->equip_shield(rimvale::ItemRegistry::instance().create_armor(nameStr));
            else c->equip_armor(rimvale::ItemRegistry::instance().create_armor(nameStr));
        }
        break;
    }
}
void RimvaleEngine::unequip_item(int64_t handle, int slot) { auto* c = rimvale::getSafeChar(handle); if (c) { if (slot==0) c->equip_weapon(nullptr); else if (slot==1) c->equip_armor(nullptr); else if (slot==2) c->equip_shield(nullptr); else if (slot==3) c->unequip_light_source(); } }
String RimvaleEngine::get_equipped_weapon(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c && c->get_weapon() ? c->get_weapon()->get_name().c_str() : "None"); }
String RimvaleEngine::get_equipped_armor(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c && c->get_armor() ? c->get_armor()->get_name().c_str() : "None"); }
String RimvaleEngine::get_equipped_shield(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c && c->get_shield() ? c->get_shield()->get_name().c_str() : "None"); }
String RimvaleEngine::get_equipped_light_source(int64_t handle) { auto* c = rimvale::getSafeChar(handle); return String(c && !c->get_light_source().empty() ? c->get_light_source().c_str() : "None"); }
PackedStringArray RimvaleEngine::get_all_registry_weapons() { return to_psa(rimvale::ItemRegistry::instance().get_all_weapon_names()); }
PackedStringArray RimvaleEngine::get_all_registry_armor() { return to_psa(rimvale::ItemRegistry::instance().get_all_armor_names()); }
PackedStringArray RimvaleEngine::get_all_registry_general_items() { return to_psa(rimvale::ItemRegistry::instance().get_all_general_item_names()); }
PackedStringArray RimvaleEngine::get_all_registry_magic_items() {
    std::vector<std::string> res;
    for (const auto& n : rimvale::ItemRegistry::instance().get_all_weapon_names()) { auto it = rimvale::ItemRegistry::instance().create_weapon(n); if (it && it->is_magical()) res.push_back(n); }
    for (const auto& n : rimvale::ItemRegistry::instance().get_all_armor_names()) { auto it = rimvale::ItemRegistry::instance().create_armor(n); if (it && it->is_magical()) res.push_back(n); }
    for (const auto& n : rimvale::ItemRegistry::instance().get_all_general_item_names()) { auto it = rimvale::ItemRegistry::instance().create_general_item(n); if (it && it->is_magical()) res.push_back(n); }
    return to_psa(res);
}
PackedStringArray RimvaleEngine::get_all_registry_mundane_items() {
    std::vector<std::string> res;
    for (const auto& n : rimvale::ItemRegistry::instance().get_all_weapon_names()) { auto it = rimvale::ItemRegistry::instance().create_weapon(n); if (it && !it->is_magical()) res.push_back(n); }
    for (const auto& n : rimvale::ItemRegistry::instance().get_all_armor_names()) { auto it = rimvale::ItemRegistry::instance().create_armor(n); if (it && !it->is_magical()) res.push_back(n); }
    for (const auto& n : rimvale::ItemRegistry::instance().get_all_general_item_names()) { auto it = rimvale::ItemRegistry::instance().create_general_item(n); if (it && !it->is_magical()) res.push_back(n); }
    return to_psa(res);
}

int64_t RimvaleEngine::spawn_creature(String name, int category, int level) {
    auto* c = new rimvale::Creature(name.utf8().get_data(), static_cast<rimvale::CreatureCategory>(category), level);
    c->get_inventory().add_item(rimvale::ItemRegistry::instance().create_weapon("Rusty Dagger"));
    c->get_inventory().add_gold((level + 1) * 10);
    rimvale::CreatureRegistry::instance().register_creature(c);
    return reinterpret_cast<int64_t>(c);
}
void RimvaleEngine::set_creature_stats(int64_t handle, int str, int spd, int intel, int vit, int div) {
    auto* c = rimvale::getSafeCreature(handle); if (c) { auto& s = c->get_stats(); s.strength = str; s.speed = spd; s.intellect = intel; s.vitality = vit; s.divinity = div; c->reset_resources(); }
}
void RimvaleEngine::set_creature_feat(int64_t handle, String feat_name, int tier) { auto* c = rimvale::getSafeCreature(handle); if (c) c->set_feat_tier(feat_name.utf8().get_data(), tier); }
String RimvaleEngine::get_creature_name(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return String(c ? c->get_name().c_str() : ""); }
String RimvaleEngine::get_creature_id(int64_t handle) { return String(("creature_" + std::to_string(handle)).c_str()); }
int RimvaleEngine::get_creature_hp(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return c ? c->get_current_hp() : 0; }
int RimvaleEngine::get_creature_max_hp(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return c ? c->get_max_hp() : 0; }
int RimvaleEngine::get_creature_ap(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return c ? c->get_current_ap() : 0; }
int RimvaleEngine::get_creature_max_ap(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return c ? c->get_max_ap() : 0; }
int RimvaleEngine::get_creature_movement_speed(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return c ? c->get_movement_speed() : 0; }
int RimvaleEngine::get_creature_threshold(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return c ? c->get_damage_threshold() : 0; }
int RimvaleEngine::get_creature_ac(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); return c ? 10 + c->get_stats().speed : 10; }
PackedStringArray RimvaleEngine::get_creature_conditions(int64_t handle) {
    auto* c = rimvale::getSafeCreature(handle); if (!c) return PackedStringArray();
    std::vector<std::string> names;
    for (const auto& cond : c->get_status().get_conditions())
        names.push_back(rimvale::StatusManager::get_condition_name(cond));
    return to_psa(names);
}
int RimvaleEngine::creature_take_damage(int64_t handle, int amount) { auto* c = rimvale::getSafeCreature(handle); if (c) { rimvale::Dice d; c->take_damage(amount, d); return c->get_current_hp(); } return 0; }
void RimvaleEngine::destroy_creature(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); if (c) { rimvale::CreatureRegistry::instance().unregister_creature(handle); delete c; } }
PackedStringArray RimvaleEngine::get_creature_inventory_items(int64_t handle) {
    auto* c = rimvale::getSafeCreature(handle); if (!c) return PackedStringArray();
    std::vector<std::string> names; for (const auto& i : c->get_inventory().get_items()) names.push_back(i->get_name());
    return to_psa(names);
}
bool RimvaleEngine::loot_creature(int64_t creature_handle, int64_t player_handle) {
    auto* c = rimvale::getSafeCreature(creature_handle); auto* p = rimvale::getSafeChar(player_handle); if (!c || !p) return false;
    auto items = c->get_inventory().take_all_items(); for (auto& i : items) p->get_inventory().add_item(std::move(i));
    p->get_inventory().add_gold(c->get_inventory().get_gold()); c->get_inventory().set_gold(0); return true;
}

PackedStringArray RimvaleEngine::get_all_registered_npcs() { return to_psa(rimvale::NpcRegistry::instance().get_all_npc_names()); }
int64_t RimvaleEngine::spawn_registered_npc(String name) {
    auto npc = rimvale::NpcRegistry::instance().create_npc(name.utf8().get_data());
    if (npc) rimvale::CreatureRegistry::instance().register_creature(npc.get());
    return reinterpret_cast<int64_t>(npc.release());
}
void RimvaleEngine::set_npc_drivers(int64_t handle, int community, int validation, int resources) {
    auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(handle));
    if (n) { auto& d = n->get_drivers(); d.community = community; d.validation = validation; d.resources = resources; d.clamp(); }
}
int RimvaleEngine::get_npc_disposition(int64_t handle) { auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(handle)); return n ? n->get_disposition() : 0; }
String RimvaleEngine::get_npc_disposition_text(int64_t handle) { auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(handle)); return String(n ? n->get_disposition_text().c_str() : "Neutral"); }
void RimvaleEngine::interact_with_npc(int64_t handle, int cm, int vm, int rm) { auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(handle)); if (n) n->handle_interaction(cm, vm, rm); }
int64_t RimvaleEngine::spawn_adversary(String name, int level) {
    auto* a = new rimvale::Adversary(name.utf8().get_data(), level);
    rimvale::CreatureRegistry::instance().register_creature(a);
    return reinterpret_cast<int64_t>(a);
}
int RimvaleEngine::get_adversary_vengeance_bonus(int64_t handle) { auto* a = dynamic_cast<rimvale::Adversary*>(rimvale::getSafeCreature(handle)); return a ? a->get_vengeance_bonus() : 0; }
void RimvaleEngine::adversary_survive_encounter(int64_t handle) { auto* a = dynamic_cast<rimvale::Adversary*>(rimvale::getSafeCreature(handle)); if (a) a->on_encounter_survived(); }

PackedStringArray RimvaleEngine::get_all_regions() { return to_psa(rimvale::WorldRegistry::instance().get_all_region_names()); }
PackedStringArray RimvaleEngine::get_region_details(String region_name) {
    const auto* r = rimvale::WorldRegistry::instance().get_region(region_name.utf8().get_data());
    std::vector<std::string> d; if (r) { d.push_back(r->climate_summary); d.push_back(std::to_string(r->base_trr)); }
    return to_psa(d);
}
PackedStringArray RimvaleEngine::get_region_terrains(String region_name) {
    const auto* r = rimvale::WorldRegistry::instance().get_region(region_name.utf8().get_data());
    std::vector<std::string> t; if (r) for (const auto& tr : r->terrains) t.push_back(tr.name);
    return to_psa(t);
}
Array RimvaleEngine::get_terrain_details(String region_name, String terrain_name) {
    const auto* r = rimvale::WorldRegistry::instance().get_region(region_name.utf8().get_data());
    Array result; result.resize(2); result[0] = PackedStringArray(); result[1] = PackedStringArray();
    if (r) for (const auto& t : r->terrains) if (t.name == terrain_name.utf8().get_data()) {
        result[0] = to_psa(t.beneficial_conditions); result[1] = to_psa(t.harmful_conditions); break;
    }
    return result;
}
Array RimvaleEngine::get_quests_by_region(String region_name) {
    auto quests = rimvale::QuestRegistry::instance().get_quests_by_region(region_name.utf8().get_data());
    Array result;
    for (const auto& q : quests) result.push_back(to_psa({q.title, q.type, q.threat, q.objective, q.anomaly, q.complication, q.description}));
    return result;
}
PackedStringArray RimvaleEngine::get_quest_regions() { return to_psa(rimvale::QuestRegistry::instance().get_all_regions()); }
PackedStringArray RimvaleEngine::generate_quest() {
    rimvale::Dice d; auto q = rimvale::QuestGenerator::generate_random_quest(d);
    return to_psa({q.region, q.type, q.threat, q.objective, q.anomaly, q.complication, q.description});
}

PackedStringArray RimvaleEngine::get_all_factions() { return to_psa(rimvale::FactionRegistry::instance().get_all_faction_names()); }
PackedStringArray RimvaleEngine::get_faction_details(String faction_name) {
    const auto* f = rimvale::FactionRegistry::instance().get_faction(faction_name.utf8().get_data());
    std::vector<std::string> d; if (f) { d.push_back(f->region); d.push_back(f->influence); d.push_back(f->territory_feature); }
    return to_psa(d);
}
PackedStringArray RimvaleEngine::get_faction_ranks(String faction_name) {
    const auto* f = rimvale::FactionRegistry::instance().get_faction(faction_name.utf8().get_data());
    std::vector<std::string> r; if (f) for (const auto& rk : f->ranks) r.push_back(rk.title + ": " + rk.benefit);
    return to_psa(r);
}

void RimvaleEngine::start_combat() { rimvale::CombatManager::instance().start_combat(); }
void RimvaleEngine::add_player_to_combat(int64_t handle) { auto* c = rimvale::getSafeChar(handle); if (c) { rimvale::Dice d; rimvale::CombatManager::instance().add_player(c, d); } }
void RimvaleEngine::add_creature_to_combat(int64_t handle) { auto* c = rimvale::getSafeCreature(handle); if (c) { rimvale::Dice d; rimvale::CombatManager::instance().add_creature(c, d); } }
void RimvaleEngine::next_turn() { rimvale::CombatManager::instance().next_turn(); }
bool RimvaleEngine::set_current_combatant_by_id(String id) { return rimvale::CombatManager::instance().set_current_combatant_by_id(id.utf8().get_data()); }
void RimvaleEngine::end_player_phase() { rimvale::CombatManager::instance().end_player_phase(); }
String RimvaleEngine::get_current_combatant_name() { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return String(c ? c->name.c_str() : "None"); }
String RimvaleEngine::get_current_combatant_id() { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return String(c ? c->id.c_str() : "None"); }
bool RimvaleEngine::get_current_combatant_is_player() { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return c ? c->is_player : false; }
int RimvaleEngine::get_current_combatant_ap() { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return c ? c->get_current_ap() : 0; }
int RimvaleEngine::get_current_combatant_hp() { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return c ? c->get_current_hp() : 0; }
int RimvaleEngine::get_combat_round() { return rimvale::CombatManager::instance().get_round(); }
int RimvaleEngine::get_action_cost(int action, String extra_param) { return rimvale::CombatManager::instance().get_action_cost(static_cast<rimvale::ActionType>(action), extra_param.utf8().get_data()); }
bool RimvaleEngine::perform_action(int action, String extra_param) { rimvale::Dice d; return rimvale::CombatManager::instance().perform_action(static_cast<rimvale::ActionType>(action), d, extra_param.utf8().get_data()); }
String RimvaleEngine::process_enemy_phase() { rimvale::Dice d; return String(rimvale::CombatManager::instance().process_enemy_phase(d).c_str()); }
String RimvaleEngine::get_last_action_log() { return String(rimvale::CombatManager::instance().get_last_action_log().c_str()); }
PackedStringArray RimvaleEngine::get_initiative_order() {
    const auto& combatants = rimvale::CombatManager::instance().get_combatants();
    std::vector<std::string> order;
    for (const auto& co : combatants) order.push_back(co.name + " (" + std::to_string(co.initiative) + ")");
    return to_psa(order);
}
void RimvaleEngine::set_mission_active(bool active) { rimvale::CombatManager::instance().set_mission_active(active); }

int64_t RimvaleEngine::create_base(String name, int tier) { auto* b = new rimvale::Base(name.utf8().get_data(), tier); return reinterpret_cast<int64_t>(b); }
String RimvaleEngine::get_base_name(int64_t handle) { auto* b = reinterpret_cast<rimvale::Base*>(handle); return String(b ? b->get_name().c_str() : ""); }
int RimvaleEngine::get_base_tier(int64_t handle) { auto* b = reinterpret_cast<rimvale::Base*>(handle); return b ? b->get_tier() : 1; }
PackedInt32Array RimvaleEngine::get_base_stats(int64_t handle) {
    auto* b = reinterpret_cast<rimvale::Base*>(handle); PackedInt32Array arr; arr.resize(4);
    if (b) { arr[0] = b->get_supplies(); arr[1] = b->get_defense(); arr[2] = b->get_morale(); arr[3] = b->get_acreage(); }
    return arr;
}
int RimvaleEngine::get_base_max_facilities(int64_t handle) { auto* b = reinterpret_cast<rimvale::Base*>(handle); return b ? b->get_max_facilities() : 0; }
PackedStringArray RimvaleEngine::get_base_facilities(int64_t handle) {
    auto* b = reinterpret_cast<rimvale::Base*>(handle); if (!b) return PackedStringArray();
    std::vector<std::string> fl; for (const auto& f : b->get_facilities()) fl.push_back(f.name + ": " + f.description);
    return to_psa(fl);
}
bool RimvaleEngine::add_facility_to_base(int64_t handle, int type) { auto* b = reinterpret_cast<rimvale::Base*>(handle); return b ? b->add_facility(static_cast<rimvale::FacilityType>(type)) : false; }
int RimvaleEngine::get_base_defense_modifier(int64_t handle) { auto* b = reinterpret_cast<rimvale::Base*>(handle); return b ? b->get_defense_modifier() : 0; }
void RimvaleEngine::destroy_base(int64_t handle) { delete reinterpret_cast<rimvale::Base*>(handle); }

int RimvaleEngine::roll_skill(int64_t handle, int skill_id) {
    auto* c = rimvale::getSafeChar(handle); if (c) { rimvale::Dice d; return c->roll_skill_check(d, static_cast<rimvale::SkillType>(skill_id)).total; } return 0;
}
PackedStringArray RimvaleEngine::roll_skill_check(int64_t handle, int skill_id, int stat_id) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return PackedStringArray();
    rimvale::Dice d; auto r = c->roll_skill_check(d, static_cast<rimvale::SkillType>(skill_id));
    std::string details = "Roll: " + std::to_string(r.die_roll) + " + Mod: " + std::to_string(r.modifier) + " = " + std::to_string(r.total);
    if (r.is_critical_success) details += " [CRIT SUCCESS]";
    if (r.is_critical_failure)  details += " [CRIT FAILURE]";
    return to_psa({std::to_string(r.die_roll), std::to_string(r.modifier), std::to_string(r.total), details});
}

void RimvaleEngine::start_dungeon(PackedInt64Array player_handles, int enemy_level, int64_t specific_enemy_handle, int terrain_style) {
    std::vector<int64_t> players;
    for (int i = 0; i < player_handles.size(); ++i) players.push_back(player_handles[i]);
    rimvale::DungeonManager::instance().start_new_dungeon(players, enemy_level, specific_enemy_handle, terrain_style);
}
void RimvaleEngine::end_dungeon() { rimvale::CombatManager::instance().set_dungeon_mode(false); }
PackedInt32Array RimvaleEngine::get_dungeon_map() {
    const auto* m = rimvale::DungeonManager::instance().get_map();
    int s = rimvale::DungeonMap::SIZE * rimvale::DungeonMap::SIZE;
    PackedInt32Array arr; arr.resize(s);
    if (m) for (int y = 0; y < rimvale::DungeonMap::SIZE; ++y)
               for (int x = 0; x < rimvale::DungeonMap::SIZE; ++x)
                   arr[y * rimvale::DungeonMap::SIZE + x] = static_cast<int>(m->get_tile(x, y));
    return arr;
}
PackedInt32Array RimvaleEngine::get_dungeon_elevation() {
    const auto* m = rimvale::DungeonManager::instance().get_map();
    int s = rimvale::DungeonMap::SIZE * rimvale::DungeonMap::SIZE;
    PackedInt32Array arr; arr.resize(s);
    for (int y = 0; y < rimvale::DungeonMap::SIZE; ++y)
        for (int x = 0; x < rimvale::DungeonMap::SIZE; ++x)
            arr[y * rimvale::DungeonMap::SIZE + x] = m ? m->get_elevation(x, y) : 1;
    return arr;
}
Array RimvaleEngine::get_dungeon_entities() {
    const auto& ent = rimvale::DungeonManager::instance().get_entities();
    Array result;
    for (const auto& e : ent)
        result.push_back(to_psa({e.id, e.name, std::to_string(e.position.x), std::to_string(e.position.y),
                                  e.is_player ? "true" : "false", std::to_string(e.handle)}));
    return result;
}
bool RimvaleEngine::move_dungeon_player(String id, int nx, int ny) {
    std::string sid(id.utf8().get_data());
    auto path = rimvale::DungeonManager::instance().get_path(sid, nx, ny);
    if (path.empty()) return false;
    rimvale::CombatManager::instance().set_current_combatant_by_id(sid);
    rimvale::Dice dice; bool moved = false;
    for (const auto& step : path) {
        std::string param = std::to_string(step.x) + "|" + std::to_string(step.y);
        if (!rimvale::CombatManager::instance().perform_action(rimvale::ActionType::Move, dice, param)) break;
        moved = true;
    }
    return moved;
}
Array RimvaleEngine::get_valid_dungeon_moves(String id) {
    auto moves = rimvale::DungeonManager::instance().get_reachable_tiles(id.utf8().get_data());
    Array result;
    for (const auto& mv : moves)
        result.push_back(to_psa({std::to_string(mv.first.x), std::to_string(mv.first.y), std::to_string(mv.second)}));
    return result;
}
bool RimvaleEngine::is_dungeon_player_phase() { return rimvale::DungeonManager::instance().is_player_phase(); }
PackedStringArray RimvaleEngine::collect_loot(int64_t player_handle) {
    auto* player = rimvale::getSafeChar(player_handle);
    if (!player) return PackedStringArray();
    // collect_loot(Character*) handles inventory addition internally and returns item name strings
    auto loot = rimvale::DungeonManager::instance().collect_loot(player);
    return to_psa(loot);
}
PackedStringArray RimvaleEngine::get_lineage_trait_states(int64_t handle) {
    // Not yet implemented in Character — return empty array
    (void)handle;
    return PackedStringArray();
}
PackedStringArray RimvaleEngine::get_feat_action_states(int64_t handle) {
    // Not yet implemented in Character — return empty array
    (void)handle;
    return PackedStringArray();
}
PackedInt32Array RimvaleEngine::get_safeguard_chosen_stats(int64_t handle) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return PackedInt32Array();
    PackedInt32Array arr;
    for (int s : c->safeguard_chosen_stats_) arr.push_back(s);
    return arr;
}
void RimvaleEngine::set_safeguard_chosen_stats(int64_t handle, PackedInt32Array stats) {
    auto* c = rimvale::getSafeChar(handle); if (!c) return;
    c->safeguard_chosen_stats_.clear();
    for (int i = 0; i < stats.size(); ++i) c->safeguard_chosen_stats_.insert(stats[i]);
}
