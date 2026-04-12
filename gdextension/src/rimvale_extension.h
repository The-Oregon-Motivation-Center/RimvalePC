#pragma once
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>

using namespace godot;

class RimvaleEngine : public Object {
    GDCLASS(RimvaleEngine, Object)

protected:
    static void _bind_methods();

public:
    // --- Lineages & Feats ---
    PackedStringArray get_all_lineages();
    PackedStringArray get_lineage_details(String name);
    PackedStringArray get_all_feat_categories();
    PackedStringArray get_feat_trees_by_category(String category);
    PackedStringArray get_feat_trees_by_character(int64_t handle);
    PackedStringArray get_feats_by_tree(String tree_name);
    PackedStringArray get_feats_by_category(String category);
    PackedStringArray get_feats_by_tier(int tier);
    PackedStringArray get_feat_details(String feat_name, int tier);
    String get_feat_description(String feat_name, int tier);

    // --- Societal Roles ---
    PackedStringArray get_all_societal_roles();
    PackedStringArray get_societal_role_details(String name);
    void add_societal_role(int64_t handle, String name);
    String get_character_societal_role_name(int64_t handle);
    void set_societal_role(int64_t handle, String name);
    void set_character_name(int64_t handle, String name);

    // --- Character Management ---
    int64_t create_character(String name, String lineage_name, int age);
    void fuse_characters(int64_t target, int64_t sacrifice);
    String get_character_name(int64_t handle);
    String get_character_id(int64_t handle);
    String get_character_lineage_name(int64_t handle);
    int get_character_level(int64_t handle);
    int get_character_xp(int64_t handle);
    int get_character_xp_required(int64_t handle);
    void add_xp(int64_t handle, int amount, int level_limit);
    void add_gold(int64_t handle, int amount);
    int get_character_stat_points(int64_t handle);
    int get_character_feat_points(int64_t handle);
    int get_character_skill_points(int64_t handle);
    int get_character_stat(int64_t handle, int stat_type);
    int get_character_skill(int64_t handle, int skill_type);
    int get_character_feat_tier(int64_t handle, String feat_name);
    bool can_unlock_feat(int64_t handle, String feat_name, int tier);
    bool spend_stat_point(int64_t handle, int stat_type);
    bool spend_skill_point(int64_t handle, int skill_type);
    bool spend_feat_point(int64_t handle, String feat_name, int tier);
    int get_character_hp(int64_t handle);
    int get_character_max_hp(int64_t handle);
    int get_character_ap(int64_t handle);
    int get_character_max_ap(int64_t handle);
    int get_character_sp(int64_t handle);
    int get_character_max_sp(int64_t handle);
    bool spend_character_sp(int64_t handle, int amount);
    void restore_character_sp(int64_t handle, int amount);
    int get_character_ac(int64_t handle);
    int get_character_movement_speed(int64_t handle);
    PackedStringArray get_character_injuries(int64_t handle);
    PackedStringArray get_character_conditions(int64_t handle);
    int character_take_damage(int64_t handle, int amount);
    void character_start_turn(int64_t handle);
    void short_rest(int64_t handle);
    void long_rest(int64_t handle);
    bool rest_party(PackedInt64Array handles);
    String serialize_character(int64_t handle);
    int64_t deserialize_character(String data);
    void destroy_character(int64_t handle);
    bool is_proficient_in_saving_throw(int64_t handle, int stat_type);
    void toggle_saving_throw_proficiency(int64_t handle, int stat_type);
    bool is_favored_skill(int64_t handle, int skill_type);
    bool toggle_favored_skill(int64_t handle, int skill_type);

    // --- Magic ---
    PackedStringArray get_learned_spells(int64_t handle);
    void learn_spell(int64_t handle, String spell_name);
    void forget_spell(int64_t handle, String spell_name);
    Array get_all_spells();
    Array get_spells_by_domain(int domain);
    Array get_custom_spells();
    void add_custom_spell(String name, int domain, int cost, String description,
                          int range, bool is_attack, int die_count, int die_sides,
                          int damage_type, bool is_healing, int duration_rounds,
                          int max_targets, int area_type, String conditions_csv,
                          bool is_teleport);
    PackedStringArray get_active_matrices(String combatant_id);

    // --- Inventory ---
    int get_inventory_gold(int64_t handle);
    PackedStringArray get_inventory_items(int64_t handle);
    String use_consumable(int64_t handle, String item_name);
    PackedStringArray get_item_details(int64_t handle, String item_name);
    PackedStringArray get_registry_item_details(String item_name);
    void add_item_to_inventory(int64_t handle, String item_name);
    void remove_item_from_inventory(int64_t handle, String item_name);
    void equip_item(int64_t handle, String item_name);
    void unequip_item(int64_t handle, int slot);
    String get_equipped_weapon(int64_t handle);
    String get_equipped_armor(int64_t handle);
    String get_equipped_shield(int64_t handle);
    String get_equipped_light_source(int64_t handle);
    PackedStringArray get_all_registry_weapons();
    PackedStringArray get_all_registry_armor();
    PackedStringArray get_all_registry_general_items();
    PackedStringArray get_all_registry_magic_items();
    PackedStringArray get_all_registry_mundane_items();

    // --- Creatures ---
    int64_t spawn_creature(String name, int category, int level);
    void set_creature_stats(int64_t handle, int str, int spd, int intel, int vit, int div);
    void set_creature_feat(int64_t handle, String feat_name, int tier);
    String get_creature_name(int64_t handle);
    String get_creature_id(int64_t handle);
    int get_creature_hp(int64_t handle);
    int get_creature_max_hp(int64_t handle);
    int get_creature_ap(int64_t handle);
    int get_creature_max_ap(int64_t handle);
    int get_creature_movement_speed(int64_t handle);
    int get_creature_threshold(int64_t handle);
    int get_creature_ac(int64_t handle);
    PackedStringArray get_creature_conditions(int64_t handle);
    int creature_take_damage(int64_t handle, int amount);
    void destroy_creature(int64_t handle);
    PackedStringArray get_creature_inventory_items(int64_t handle);
    bool loot_creature(int64_t creature_handle, int64_t player_handle);

    // --- NPCs ---
    PackedStringArray get_all_registered_npcs();
    int64_t spawn_registered_npc(String name);
    void set_npc_drivers(int64_t handle, int community, int validation, int resources);
    int get_npc_disposition(int64_t handle);
    String get_npc_disposition_text(int64_t handle);
    void interact_with_npc(int64_t handle, int community_mod, int validation_mod, int resource_mod);
    int64_t spawn_adversary(String name, int level);
    int get_adversary_vengeance_bonus(int64_t handle);
    void adversary_survive_encounter(int64_t handle);

    // --- World & Quests ---
    PackedStringArray get_all_regions();
    PackedStringArray get_region_details(String region_name);
    PackedStringArray get_region_terrains(String region_name);
    Array get_terrain_details(String region_name, String terrain_name);
    Array get_quests_by_region(String region_name);
    PackedStringArray get_quest_regions();
    PackedStringArray generate_quest();

    // --- Factions ---
    PackedStringArray get_all_factions();
    PackedStringArray get_faction_details(String faction_name);
    PackedStringArray get_faction_ranks(String faction_name);

    // --- Combat ---
    void start_combat();
    void add_player_to_combat(int64_t handle);
    void add_creature_to_combat(int64_t handle);
    void next_turn();
    bool set_current_combatant_by_id(String id);
    void end_player_phase();
    String get_current_combatant_name();
    String get_current_combatant_id();
    bool get_current_combatant_is_player();
    int get_current_combatant_ap();
    int get_current_combatant_hp();
    int get_combat_round();
    int get_action_cost(int action, String extra_param);
    bool perform_action(int action, String extra_param);
    String process_enemy_phase();
    String get_last_action_log();
    PackedStringArray get_initiative_order();
    void set_mission_active(bool active);

    // --- Base Building ---
    int64_t create_base(String name, int tier);
    String get_base_name(int64_t handle);
    int get_base_tier(int64_t handle);
    PackedInt32Array get_base_stats(int64_t handle);
    int get_base_max_facilities(int64_t handle);
    PackedStringArray get_base_facilities(int64_t handle);
    bool add_facility_to_base(int64_t handle, int type);
    int get_base_defense_modifier(int64_t handle);
    void destroy_base(int64_t handle);

    // --- Dice & Skills ---
    int roll_skill(int64_t handle, int skill_id);
    PackedStringArray roll_skill_check(int64_t handle, int skill_id, int stat_id);

    // --- Dungeon ---
    void start_dungeon(PackedInt64Array player_handles, int enemy_level,
                       int64_t specific_enemy_handle, int terrain_style);
    void end_dungeon();
    PackedInt32Array get_dungeon_map();
    PackedInt32Array get_dungeon_elevation();
    Array get_dungeon_entities();
    bool move_dungeon_player(String id, int nx, int ny);
    Array get_valid_dungeon_moves(String id);
    bool is_dungeon_player_phase();
    PackedStringArray collect_loot(int64_t player_handle);
    PackedStringArray get_lineage_trait_states(int64_t handle);
    PackedStringArray get_feat_action_states(int64_t handle);
    PackedInt32Array get_safeguard_chosen_stats(int64_t handle);
    void set_safeguard_chosen_stats(int64_t handle, PackedInt32Array stats);
};
