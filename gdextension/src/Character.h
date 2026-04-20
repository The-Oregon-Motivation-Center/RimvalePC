#ifndef RIMVALE_CHARACTER_H
#define RIMVALE_CHARACTER_H

#include "Stats.h"
#include "Feats.h"
#include "Dice.h"
#include "Status.h"
#include "Injuries.h"
#include "Weapon.h"
#include "Armor.h"
#include "Inventory.h"
#include "World.h"
#include "SocietalRoleRegistry.h"
#include <string>
#include <vector>
#include <algorithm>
#include <memory>
#include <sstream>
#include <map>
#include <random>
#include <set>

namespace rimvale {

enum class Alignment { Unity, Void, Chaos };
enum class Domain { Biological, Chemical, Physical, Spiritual };

struct Lineage {
    std::string name;
    std::string type;
    int base_speed = 20;
    std::vector<std::string> features;
    std::vector<std::string> languages;
    std::string description;
    std::string culture;
};

class Character {
public:
    Character(std::string name, Lineage lineage)
        : name_(std::move(name)), lineage_(std::move(lineage)) {
        level_ = 1; xp_ = 0; age_ = 20; gold_ = 100; insanity_level_ = 0;
        stat_points_ = 6; feat_points_ = 6; skill_points_ = 12;
        current_region_ = "The Plains";
        std::random_device rd;
        unique_id_ = name_ + "_" + std::to_string(rd());
        saving_throw_proficiencies_.insert(StatType::Vitality);
        reset_resources();
    }

    void reset_resources() {
        current_hp_ = get_max_hp();
        current_ap_ = get_max_ap();
        current_sp_ = get_max_sp();
        unarmored_flow_uses_ = stats_.speed;
        has_evasion_advantage_ = false;
        has_used_free_counter_ = false;
        dodge_ac_bonus_ = 0;
        dodge_attack_bonus_ = 0;
        death_save_passes_ = 0;
        death_save_fails_ = 0;
        death_save_draws_ = 0;
        is_stabilized_ = false;
        graze_uses_remaining_ = stats_.speed;
        has_ruthless_crit_available_ = true;
        advantage_until_tick_ = 0;
        has_ignored_bludgeoning_resistance_this_turn_ = false;
        has_ignored_bludgeoning_immunity_this_turn_ = false;
        speed_penalty_ = 0;
        has_iron_grip_prone_available_ = true;

        sr_rest_free_available_ = true;
        sr_efficient_recuperation_available_ = true;
        lr_tireless_spirit_available_ = true;
        lr_unyielding_vitality_available_ = true;
        has_recuperation_advantage_ = false;
        // Feat resource resets
        sr_pt_reroll_available_ = true;
        ttb_uses_remaining_ = stats_.speed;
        sr_ttb_whirlwind_available_ = true;
        mp_double_attack_uses_remaining_ = stats_.strength;
        mp_dodge_avoid_bonus_ = 0;
        fc_enrage_uses_remaining_ = stats_.strength;
        sr_fc_sacrifice_ac_available_ = true;
        fc_bloodied_aura_triggered_ = false;
        sr_iw_explosion_available_ = true;
        sr_wm_auto_succeed_available_ = true;
        sr_la_shattershot_uses_ = 2;
        if_max_damage_uses_remaining_ = stats_.strength;
        ss_max_damage_uses_remaining_ = stats_.speed;
        td_max_damage_uses_remaining_ = stats_.strength;
        lr_ud_shrug_available_ = true;
        lr_ud_reroll_available_ = true;
        lr_dp_bastion_form_available_ = true;
        dp_bastion_form_active_ = false;
        dp_bastion_form_rounds_ = 0;
        lr_es_force_reroll_available_ = true;
        lr_es_second_target_available_ = true;
        lr_es_condition_available_ = true;
        // Magic feat resets
        lr_me_teleport_used_ = false;
        lr_ss_disadv_used_ = false;
        lr_ss_force_fail_used_ = false;
        lr_ss_chain_used_ = false;
        sr_ss_dc_boost_available_ = true;
        sr_bm_reroll_available_ = true;
        sr_bm_reservoir_save_available_ = true;
        lr_bm_immunity_used_ = false;
        lr_bm_kill_sp_regain_used_ = false;
        lr_bm_double_dice_used_ = false;
        // Alignment feat resets
        sr_cp_unpredictable_available_ = true;
        lr_cp_sense_chaos_available_ = true;
        sr_cp_reroll_save_available_ = true;
        sr_cp_insubstantial_available_ = true;
        sr_cp_summon_available_ = true;
        lr_cp_miracle_available_ = true;
        lr_cs_free_chaos_sp_available_ = true;
        lr_cs_upgrade_spell_available_ = true;
        sr_up_clarity_available_ = true;
        lr_up_sense_celestial_available_ = true;
        lr_up_dispel_blindness_available_ = true;
        sr_up_radiant_burst_available_ = true;
        sr_up_summon_available_ = true;
        lr_up_miracle_available_ = true;
        lr_us_free_unity_sp_available_ = true;
        lr_us_upgrade_spell_available_ = true;
        sr_vp_sneak_bonus_available_ = true;
        lr_vp_sense_void_available_ = true;
        sr_vp_intangible_available_ = true;
        sr_vp_summon_available_ = true;
        lr_vp_miracle_available_ = true;
        lr_vs_free_darkness_sp_available_ = true;
        lr_vs_upgrade_spell_available_ = true;
        // Domain feat resets
        bio_attack_bonus_pending_ = 0;
        lr_bio_heal_available_ = true;
        sr_chem_solution_available_ = true;
        sr_chem_free_spell_available_ = true;
        lr_chem_reaction_available_ = true;
        sr_phys_ember_available_ = true;
        lr_phys_illusion_available_ = true;
        sr_spir_telepathy_uses_ = stats_.divinity;
        lr_spir_nullify_available_ = true;
        // Exploration feat resets
        lr_ae_fall_avoid_available_ = true;
        sr_ae_ignore_terrain_available_ = true;
        ae_ignore_terrain_active_ = false;
        ae_ignore_terrain_rounds_ = 0;
        sr_ae_water_walk_ally_available_ = true;
        lr_eg_shortcut_available_ = true;
        lr_eg_lead_group_available_ = true;
        lr_eg_reroll_available_ = true;
        sr_hr_resistance_available_ = true;
        sr_hr_miracle_available_ = true;
        sr_id_illusion_available_ = true;
        lr_id_group_illusion_available_ = true;
        lr_moc_keen_mind_uses_ = stats_.intellect;
        sr_moc_reroll_available_ = true;
        sr_moc_auto_succeed_available_ = true;
        lr_moc_nat20_available_ = true;
        lr_mm_summon_available_ = true;
        lr_mm_consciousness_used_ = false;
        sr_ss_speechcraft_advantage_available_ = true;
        lr_ss_distraction_available_ = true;
        lr_ss_mimic_available_ = true;
        lr_ss_auto_escape_available_ = true;
        lr_tt_advantage_uses_ = stats_.divinity;
        lr_tt_env_change_available_ = true;
        lr_tt_reveal_available_ = true;
        lr_tt_foresight_active_ = false;
        lr_tt_foresight_rounds_ = 0;
        lr_tt_hint_available_ = true;
        lr_tt_convergence_available_ = true;
        pending_damage_reduction_ = 0;
        pending_absorb_item_ = "";
        // Crafting feat LR resets
        ca_core_damage_bonus_pending_ = 0;
        culinary_attack_bonus_rounds_ = 0;
        // Ascendant feat LR resets
        abyssal_true_name_used_today_ = false;
        angelic_flight_active_ = false;
        angelic_safeguard_active_ = false;
        angelic_safeguard_rounds_ = 0;
        draconic_apo_flight_active_ = false;
        fey_disguise_active_ = false;
        hag_nightmare_brood_active_ = false;
        hag_soulroot_active_ = false;
        infernal_second_chance_available_ = true;
        infernal_flame_flicker_hp_sacrificed_ = 0;
        infernal_flame_flicker_primed_ = false;
        lycanthrope_hybrid_active_ = false;
        lycanthrope_blood_howl_rounds_ = 0;
        seraphic_reflective_veil_available_ = true;
        seraphic_reflective_veil_rounds_ = 0;
        seraphic_heal_lr_available_ = true;
        stormbound_grow_ap_cost_ = 0;
        vampire_flight_intangible_active_ = false;
        voidborn_phase_shift_rounds_ = 0;
        voidborn_reality_distort_active_ = false;
        voidborn_immortal_mask_available_ = true;
        // Apex feat LR resets
        lr_arcane_overdrive_available_ = true;
        arcane_overdrive_active_ = false;
        arcane_overdrive_rounds_ = 0;
        lr_boa_available_ = true;
        boa_active_ = false;
        boa_rounds_ = 0;
        boa_damage_ignored_this_round_ = false;
        lr_cataclysmic_leap_available_ = true;
        lr_divine_reversal_available_ = true;
        lr_eclipse_veil_available_ = true;
        eclipse_veil_active_ = false;
        eclipse_veil_rounds_ = 0;
        lr_gravity_shatter_available_ = true;
        lr_howl_available_ = true;
        lr_iron_tempest_available_ = true;
        lr_mythic_regrowth_available_ = true;
        mythic_regrowth_regen_turns_ = 0;
        lr_phantom_legion_available_ = true;
        phantom_legion_active_ = false;
        phantom_legion_clones_ = 0;
        lr_runebreaker_available_ = true;
        runebreaker_active_rounds_ = 0;
        soulbrand_target_id_ = "";
        soulbrand_used_this_round_ = false;
        lr_soulflare_available_ = true;
        lr_stormbound_available_ = true;
        stormbound_mantle_rounds_ = 0;
        lr_temporal_rift_available_ = true;
        temporal_rift_active_ = false;
        lr_titans_echo_available_ = true;
        lr_voidbrand_available_ = true;
        voidbrand_target_id_ = "";
        voidbrand_rounds_ = 0;
        voidbrand_primed_ = false;
        worldbreaker_step_movement_this_turn_ = 0;
        // Misc feat LR resets
        planar_graze_pending_ = false;
        sacred_frag_pending_ = false;
        lr_arc_light_available_ = true;
        lr_arcane_residue_available_ = true;
        sr_astral_shear_available_ = true;
        lr_bender_available_ = true;
        lr_blade_scripture_active_ = false;
        lr_blade_scripture_available_ = true;
        lr_breath_of_stone_active_ = false;
        lr_breath_of_stone_available_ = true;
        lr_barkskin_active_ = false;
        lr_barkskin_available_ = true;
        sr_chaos_flow_available_ = true;
        chaos_flow_bonus_rounds_ = 0;
        lr_coinreader_available_ = true;
        lr_dreamthief_available_ = true;
        sr_echoed_steps_available_ = true;
        sr_emberwake_available_ = true;
        lr_erylons_echo_available_ = true;
        lr_flare_defiance_available_ = true;
        sr_flicker_sparky_available_ = true;
        flicker_resistance_active_ = false;
        sr_hollow_voice_available_ = true;
        sr_hollowed_instinct_available_ = true;
        sr_illusory_double_available_ = true;
        illusory_double_hp_ = 0;
        lr_mirrorsteel_available_ = true;
        sr_planar_graze_available_ = true;
        sr_refraction_twist_available_ = true;
        lr_resonant_pulse_available_ = true;
        sr_rune_cipher_available_ = true;
        lr_rune_cipher_available_ = true;
        sr_sacred_frag_available_ = true;
        lr_sacrifice_available_ = true;
        lr_skywatcher_available_ = true;
        sr_spark_leech_available_ = true;
        lr_split_second_available_ = true;
        split_second_ac_bonus_rounds_ = 0;
        lr_soulmark_available_ = true;
        lr_temporal_shift_available_ = true;
        lr_tether_link_available_ = true;
        lr_veilbreaker_available_ = true;
        lr_verdant_pulse_available_ = true;
        lr_veyras_veil_active_ = false;
        lr_veyras_veil_available_ = true;
        lr_unitys_ebb_available_ = true;
        whispers_die_size_ = 6;
        lr_whispers_available_ = true;
        lr_whispers_consumed_ = false;
        lr_alch_concoction_available_ = true;
        lr_alch_autosucceed_available_ = true;
        lr_art_reroll_available_ = true;
        lr_art_reduce_available_ = true;
        lr_art_reinforce_available_ = true;
        lr_art_half_craft_available_ = true;
        sr_call_scroll_available_ = true;
        sr_call_glyph_available_ = true;
        lr_call_living_script_available_ = true;
        sr_ca_temp_tool_available_ = true;
        lr_ca_absorb_available_ = true;
        lr_cul_ap_boost_available_ = true;
        lr_cul_resistance_available_ = true;
        lr_cul_feast_prepared_ = false;
        lr_disg_halfcost_available_ = true;
        enc_disg_failsafe_available_ = true;
        day_fish_reroll_available_ = true;
        lr_fish_reagents_available_ = true;
        lr_herb_salve_available_ = true;
        lr_herb_autosucceed_available_ = true;
        lr_herb_elixir_available_ = true;
        sr_hunt_damage_available_ = true;
        lr_hunt_quarry_active_ = false;
        lr_hunt_quarry_id_ = "";
        lr_hunt_quarry_hit_this_round_ = false;
        lr_hunt_field_dress_available_ = true;
        lr_jew_identify_available_ = true;
        lr_jew_autosucceed_available_ = true;
        lr_music_heal_available_ = true;
        lr_music_autoperform_available_ = true;
        lr_nav_reroute_available_ = true;
        lr_paint_autosucceed_available_ = true;
        lr_pois_poison_available_ = true;
        lr_pois_autosucceed_available_ = true;
        pois_weapon_rounds_ = 0;
        pois_weapon_disadvantage_ = false;
        pois_weapon_extra_damage_ = false;
        lr_smith_repair_available_ = true;
        lr_smith_autosucceed_available_ = true;
        lr_thief_reroll_available_ = true;
        enc_thief_failsafe_available_ = true;
        lr_tink_autosucceed_available_ = true;
        lr_tink_unique_available_ = true;
        lr_tail_endurance_available_ = true;

        // Lineage trait resets
        sr_bouncian_escape_available_ = true;
        sr_ironhide_mind_available_ = true;
        sr_verdant_regrowth_available_ = true;
        lr_ironhide_plating_available_ = true;
        lr_goldscale_sun_favor_available_ = true;
        lr_vulpin_echo_available_ = true;
        lr_verdant_natures_voice_available_ = true;
        has_fire_resistance_ = (lineage_.name == "Goldscale" || lineage_.name == "Hearthkin" || lineage_.name == "Kettlekyn" ||
                               lineage_.name == "Hellforged" || lineage_.name == "Obsidian Seraph" ||
                               lineage_.name == "Volcant" || lineage_.name == "Emberkin" ||
                               lineage_.name == "Saurian" || lineage_.name == "Cindervolk" ||
                               lineage_.name == "Obsidian" || lineage_.name == "Driftwood Woken");
        has_cold_resistance_ = (lineage_.name == "Kettlekyn" || lineage_.name == "Frostborn" || lineage_.name == "Glaceari" ||
                                lineage_.name == "Frostbound Dvarrim" || lineage_.name == "Glaciervein Dvarrim" ||
                                lineage_.name == "Hellforged" || lineage_.name == "Volcant" ||
                                lineage_.name == "Saurian" || lineage_.name == "Obsidian" ||
                                lineage_.name == "Abyssari" || lineage_.name == "Driftwood Woken" ||
                                lineage_.name == "Fathomari" || lineage_.name == "Hydrakari");
        felinar_nine_lives_remaining_ = 9;
        sr_fae_enchanting_available_ = true;
        speechcraft_bonus_rounds_ = 0;
        lr_myconid_spore_available_ = true;
        sr_myconid_fortitude_available_ = true;
        has_poison_resistance_ = (lineage_.name == "Myconid" || lineage_.name == "Thornwrought Human" ||
                                  lineage_.name == "Mireborn Human" || lineage_.name == "Hollowborn Human" ||
                                  lineage_.name == "Chokeling" || lineage_.name == "Mistborne Hatchling");
        has_physical_resistance_ = (lineage_.name == "Lithari");

        // Wilds of Endero lineage resets
        sr_beetlefolk_deflect_uses_ = stats_.vitality;
        lr_pack_howl_available_ = true;
        loyal_strike_reaction_available_ = true;
        lr_natures_grace_available_ = true;
        has_secondary_arms_attack_available_ = true;
        tetrasimian_sneak_advantage_ = false;
        lr_verdant_curse_available_ = true;

        // Eternal Library lineage resets
        sr_paper_ward_uses_ = stats_.intellect;
        bookborn_origami_rounds_ = 0;
        bookborn_origami_active_ = false;
        sr_archivist_recall_available_ = true;
        panoplian_sentinel_stand_active_ = false;

        // House of Arachana lineage resets
        lr_toxic_roots_available_ = true;
        lr_witherborn_decay_available_ = true;
        witherborn_decay_rounds_ = 0;
        sr_silken_trap_available_ = true;
        sr_lurker_step_available_ = true;
        lr_serpentine_venom_weapon_available_ = true;
        serpentine_venom_weapon_rounds_ = 0;

        // Qunorum lineage resets
        grimshell_tomb_core_used_ = false;
        lr_kindle_flame_available_ = true;
        lr_alchemical_affinity_available_ = true;
        pending_alchemical_affinity_ = false;
        kindlekin_hit_count_ = 0;
        kindlekin_death_dice_count_ = 0;
        sr_resilient_spirit_uses_ = 2;
        lr_versatile_grant_remaining_ = stats_.divinity;
        lr_quill_launch_available_ = true;
        sr_quick_reflexes_available_ = true;

        // Metropolitan lineage resets
        lr_arcane_surge_available_ = true;
        arcane_surge_rounds_ = 0;
        sr_groblodyte_scrap_available_ = true;
        lr_steam_jet_available_ = true;
        lr_tether_step_available_ = true;
        sr_resonant_voice_uses_ = stats_.intellect;
        lr_market_whisperer_available_ = true;

        // Upper Forty lineage resets
        lr_arcane_tinker_available_ = true;
        sr_gremlins_luck_uses_ = 2;
        lr_hex_mark_available_ = true;
        hex_mark_rounds_ = 0;
        sr_witchblood_available_ = true;
        witchblood_active_ = false;
        lr_commanding_voice_available_ = true;

        // Lower Forty lineage resets
        sr_overdrive_core_available_ = true;
        has_slashing_resistance_ = (lineage_.name == "Ferrusk");
        ferrusk_scrap_ac_used_ = false;
        lr_gremlin_tinker_available_ = true;
        sr_gremlin_sabotage_available_ = true;
        lr_reflect_hex_available_ = true;
        reflect_hex_primed_ = false;
        sr_scrap_sense_available_ = true;
        sr_iron_stomach_available_ = true;

        // Shadows Beneath lineage resets
        lr_quack_alarm_available_ = true;
        lr_sable_night_vision_available_ = true;
        sr_veilstep_available_ = true;
        sr_duskborn_grace_available_ = true;

        // Corrupted Marshes lineage resets
        lr_mossy_shroud_available_ = true;
        sr_mire_burst_available_ = true;
        lr_soothing_aura_available_ = true;
        lr_dreamscent_available_ = true;

        // Crypt at the End of the Valley lineage resets
        lr_gnawing_grin_available_ = true;
        lr_diseaseborn_curse_available_ = true;

        // Spindle York's Schism lineage resets
        sr_stones_endurance_uses_ = stats_.vitality;
        shardkin_crystal_resilience_active_ = false;
        lr_harmonic_link_available_ = true;

        // Peaks of Isolation lineage resets
        lr_deathless_endurance_available_ = true;
        sr_frost_burst_available_ = true;
        sr_frostborn_icewalk_available_ = true;
        frostborn_icewalk_active_ = false;
        frostborn_icewalk_rounds_ = 0;
        lr_frozen_veil_available_ = true;
        frozen_veil_rounds_ = 0;
        sr_gravitational_leap_available_ = true;
        gravitational_leap_rounds_ = 0;

        // Pharaoh's Den lineage resets
        has_necrotic_resistance_ = (lineage_.name == "Jackal Human" || lineage_.name == "Gravetouched" || lineage_.name == "Obsidian Seraph" || lineage_.name == "Corrupted Wyrmblood");
        lr_tomb_sense_available_ = true;
        lr_rotborn_item_available_ = true;
        sr_mindscratch_available_ = true;

        // The Darkness lineage resets
        lr_creeping_dark_available_ = true;
        creeping_dark_active_ = false;
        creeping_dark_rounds_ = 0;

        // Arcane Collapse lineage resets
        sr_absorb_magic_available_ = true;
        sr_dregspawn_extend_available_ = true;
        sr_aberrant_flex_available_ = true;
        lr_void_aura_available_ = true;
        void_aura_rounds_ = 0;
        sr_crystal_slash_available_ = true;

        // Argent Hall lineage resets
        argent_silent_ledger_active_ = false;
        glacial_wall_active_ = false;
        unyielding_bulwark_active_ = false;
        unyielding_bulwark_rounds_ = 0;
        stonemind_architects_shield_active_ = false;
        sr_miners_instinct_available_ = true;
        miners_instinct_active_ = false;

        // Glass Passage lineage resets
        lr_wind_step_available_ = true;
        wind_cloak_rounds_ = 0;
        lr_pangol_armor_reaction_uses_ = stats_.speed;
        pangol_armor_react_active_ = false;
        sr_curl_up_available_ = true;
        curl_up_active_ = false;
        sr_gilded_bearing_available_ = true;
        sr_chromatic_shift_available_ = true;
        chromatic_shift_rounds_ = 0;
        lr_prismatic_reflection_available_ = true;
        prismatic_reflection_rounds_ = 0;
        has_acid_resistance_ = (lineage_.name == "Rustspawn");
        ironrot_acid_stacks_ = 0;

        // Sacral Separation lineage resets
        lr_dust_shroud_available_ = true;
        dust_shroud_rounds_ = 0;
        lr_shatter_pulse_glassborn_available_ = true;
        sr_prism_veins_available_ = true;
        lr_deaths_whisper_available_ = true;
        has_psychic_resistance_ = (lineage_.name == "Madness-Touched Human" || lineage_.name == "Mistborne Hatchling");
        madness_crit_bonus_ = 0;
        unstable_mutation_disadvantage_remaining_ = 0;
        has_radiant_resistance_ = (lineage_.name == "Glassborn" || lineage_.name == "Obsidian Seraph" || lineage_.name == "Luminar Human");

        // The Infernal Machine lineage resets
        candlite_flame_lit_ = true;
        lr_pain_made_flesh_available_ = true;
        pain_made_flesh_active_ = false;
        pain_made_flesh_rounds_ = 0;
        lr_infernal_stare_available_ = true;
        infernal_stare_rounds_ = 0;
        sr_infernal_smite_available_ = true;
        infernal_smite_rounds_ = 0;
        cracked_resilience_stacks_ = 0;

        // Titan's Lament lineage resets
        sr_cursed_spark_available_ = true;
        cursed_spark_rounds_ = 0;
        lr_burnt_offering_available_ = true;
        lr_desert_walker_available_ = true;
        desert_walker_rounds_ = 0;
        sr_gore_uses_ = stats_.vitality;
        sr_stubborn_will_available_ = true;
        lr_hibernate_available_ = true;

        // The Mortal Arena lineage resets
        sr_blazeblood_available_ = true;
        blazeblood_rounds_ = 0;
        lr_soot_sight_available_ = true;
        soot_sight_rounds_ = 0;
        sr_scaled_resilience_available_ = true;
        has_lightning_resistance_ = (lineage_.name == "Stormclad" || lineage_.name == "Obsidian");
        has_thunder_resistance_ = (lineage_.name == "Stormclad" || lineage_.name == "Obsidian");
        sunderborn_death_denied_sp_cost_ = 1;
        sunderborn_frenzy_available_ = false;
        lr_sunderborn_hibernate_available_ = true;

        // Vulcan Valley lineage resets
        ashrot_aura_active_ = false;
        lr_smoldering_glare_available_ = true;
        smoldering_glare_rounds_ = 0;
        lr_draconic_awakening_available_ = true;
        draconic_form_active_ = false;
        draconic_form_rounds_ = 0;
        sr_fracture_burst_available_ = true;
        crackling_edge_used_ = false;

        // The Isles lineage resets
        abyssari_glow_active_ = false;
        lr_abyssari_pulse_available_ = true;
        lr_mireling_escape_available_ = true;
        lr_lunar_radiance_available_ = true;
        lunar_radiance_rounds_ = 0;
        has_cold_immunity_ = (lineage_.name == "Tiderunner Human");
        lr_ebb_flow_uses_ = stats_.speed;

        // The Depths of Denorim lineage resets
        sr_hydras_resilience_available_ = true;
        lr_hydra_limb_sacrifice_available_ = true;
        sr_abyssal_mutation_available_ = true;

        // Moroboros lineage resets
        cloudling_fly_active_ = false;
        sr_mist_form_available_ = true;
        mist_form_used_once_ = false;
        mist_form_rounds_ = 0;
        surge_step_active_ = false;
        lr_hunters_focus_available_ = true;
        hunters_focus_active_ = false;
        hunters_focus_target_id_ = -1;
        lr_weird_resilience_available_ = true;
        weird_resilience_primed_ = false;

        // Gloamfen Hollow lineage resets
        lr_voluntary_gas_vent_available_ = true;
        obedient_aura_active_ = false;
        memory_echo_active_ = false;
        leech_hex_used_this_turn_ = false;
        leech_hex_last_target_id_ = -1;

        // The Astral Tear lineage resets
        lr_veiled_presence_available_ = true;
        veiled_presence_rounds_ = 0;
        convergent_synthesis_active_ = false;
        convergent_synthesis_rounds_ = 0;
        lr_dreamwalk_available_ = true;
        sr_flicker_available_ = true;
        lr_shadowmeld_available_ = true;

        // L.I.T.O. lineage resets
        lr_dark_lineage_uses_ = stats_.divinity;
        sr_sap_healing_available_ = true;
        lr_unravel_available_ = true;
        lr_mind_bleed_available_ = true;
        lr_null_mind_share_available_ = true;
        lr_amorphous_split_available_ = true;
        toxic_seep_rounds_ = 0;

        // The West End Gullet lineage resets
        lr_death_eater_memory_available_ = true;
        carrionari_flight_rounds_ = 0;
        disjointed_beast_form_active_ = false;
        shapeshift_beast_form_active_ = false;
        sr_disjointed_leap_available_ = true;
        lr_temporal_flicker_available_ = true;
        temporal_flicker_rounds_ = 0;
        lr_silent_scream_available_ = true;
        sr_reality_slip_available_ = true;

        // The Cradling Depths lineage resets
        sr_resonant_form_available_ = true;
        lr_divine_mimicry_available_ = true;
        vital_surge_pool_ = 4 * level_;
        lr_abyssal_glow_available_ = true;

        // Terminus Volarus lineage resets
        lanternborn_glow_active_ = false;
        sr_beacon_available_ = true; beacon_resistance_rounds_ = 0;

        // The City of Eternal Light lineage resets
        sr_light_step_available_ = true;
        lr_dawns_blessing_available_ = true; dawns_blessing_rounds_ = 0;
        sr_radiant_ward_available_ = true; radiant_ward_rounds_ = 0;
        sr_flareburst_available_ = true; flareburst_primed_ = false;
        lr_runic_surge_available_ = true; runic_surge_primed_ = false;
        sr_mystic_pulse_available_ = true;
        sr_windstep_uses_ = stats_.speed;

        // The Hallowed Sacrament lineage resets
        glimmerfolk_glow_active_ = false;
        lr_drifting_fog_available_ = true; drifting_fog_rounds_ = 0;
        lr_spore_bloom_available_ = true;
        windswift_active_ = false; windswift_rounds_ = 0;

        // The Land of Tomorrow lineage resets
        sr_temporal_shift_available_ = true; temporal_shift_primed_ = false;
        lr_arcane_pulse_available_ = true;
        lr_runic_flow_auto_available_ = true; runic_flow_auto_primed_ = false;
        lr_sparkforged_arcane_surge_available_ = true; sparkforged_arcane_surge_primed_ = false;
        static_surge_active_ = false; static_surge_action_count_ = 0; static_surge_daze_rounds_ = 0;

        // Sublimini Dominus lineage resets
        void_cloak_active_ = false;
        warp_resistance_active_ = false;

        // Beating Heart of The Void lineage resets
        anti_magic_cone_active_ = false;
        bespoker_last_ray_name_ = "";
        resonant_sermon_active_ = false;
        lr_void_communion_available_ = true;

        // Stat feat LR resets
        aw_deep_reserves_lr_available_ = true;
        aw_deep_reserves_armed_ = false;
        aw_sp_restore_lr_available_ = true;
        aw_infinite_font_lr_available_ = true;
        aw_infinite_font_armed_ = false;
        aw_last_spell_cost_ = 0;
        iv_enduring_spirit_lr_available_ = true;
        iv_titanic_endurance_lr_available_ = true;
        sg_reroll_lr_available_ = true;
        sg_reroll_armed_ = false;
        sg_auto_succeed_lr_available_ = true;
        sg_auto_succeed_armed_ = false;
        sg_advantage_sr_available_ = true;
        sg_advantage_armed_ = false;
        sg_heal_sr_available_ = true;
        reset_encounter();
    }

    // Called at start of each combat encounter
    void reset_encounter() {
        iv_resilient_frame_triggered_ = false;
        mf_battle_ready_enc_available_ = true;
        mf_battle_ready_armed_ = false;
        aw_spell_echo_enc_available_ = true;
        aw_spell_echo_armed_ = false;
        aw_spell_echo_spell_name_ = "";
        aw_infinite_font_armed_ = false;
        aw_last_spell_cost_ = 0;
        aw_deep_reserves_armed_ = false;
        sg_reroll_armed_ = false;
        sg_advantage_armed_ = false;
        sg_auto_succeed_armed_ = false;
        mf_unstoppable_assault_used_rnd_ = false;
    }

    void short_rest(Dice& dice) {
        int total_heal = 0;
        for (int i = 0; i < level_; ++i) total_heal += dice.roll(6);
        heal(total_heal);
        if (current_hp_ > 0) {
            death_save_passes_ = 0;
            death_save_fails_ = 0;
            death_save_draws_ = 0;
            is_stabilized_ = false;
            status_.remove_condition(ConditionType::Dying);
            status_.remove_condition(ConditionType::Unconscious);
        }
        graze_uses_remaining_ = stats_.speed;
        has_ruthless_crit_available_ = true;

        sr_rest_free_available_ = true;
        sr_efficient_recuperation_available_ = true;

        // Lineage SR resets
        sr_bouncian_escape_available_ = true;
        sr_ironhide_mind_available_ = true;
        sr_verdant_regrowth_available_ = true;
        sr_fae_enchanting_available_ = true;
        sr_myconid_fortitude_available_ = true;

        // Eternal Library SR resets
        sr_paper_ward_uses_ = stats_.intellect;
        sr_archivist_recall_available_ = true;

        // House of Arachana SR resets
        sr_silken_trap_available_ = true;
        sr_lurker_step_available_ = true;

        // Wilds of Endero SR resets
        sr_beetlefolk_deflect_uses_ = stats_.vitality;

        // Qunorum SR resets
        sr_resilient_spirit_uses_ = 2;
        sr_quick_reflexes_available_ = true;

        // Metropolitan SR resets
        sr_groblodyte_scrap_available_ = true;
        sr_resonant_voice_uses_ = stats_.intellect;

        // Upper Forty SR resets
        sr_gremlins_luck_uses_ = 2;
        sr_witchblood_available_ = true;
        witchblood_active_ = false;

        // Lower Forty SR resets
        sr_overdrive_core_available_ = true;
        sr_gremlin_sabotage_available_ = true;
        sr_scrap_sense_available_ = true;
        sr_iron_stomach_available_ = true;

        // Shadows Beneath SR resets
        sr_veilstep_available_ = true;
        sr_duskborn_grace_available_ = true;

        // Corrupted Marshes SR resets
        sr_mire_burst_available_ = true;

        // Spindle York's Schism SR resets
        sr_stones_endurance_uses_ = stats_.vitality;

        // Peaks of Isolation SR resets
        sr_frost_burst_available_ = true;
        sr_frostborn_icewalk_available_ = true;
        sr_gravitational_leap_available_ = true;

        // Pharaoh's Den SR resets
        sr_mindscratch_available_ = true;

        // Arcane Collapse SR resets
        sr_absorb_magic_available_ = true;
        sr_dregspawn_extend_available_ = true;
        sr_aberrant_flex_available_ = true;
        sr_crystal_slash_available_ = true;

        // Argent Hall SR resets
        sr_miners_instinct_available_ = true;

        // Glass Passage SR resets
        sr_curl_up_available_ = true;
        curl_up_active_ = false;
        sr_gilded_bearing_available_ = true;
        sr_chromatic_shift_available_ = true;

        // Sacral Separation SR resets
        sr_prism_veins_available_ = true;

        // The Infernal Machine SR resets
        sr_infernal_smite_available_ = true;

        // Titan's Lament SR resets
        sr_cursed_spark_available_ = true;
        sr_gore_uses_ = stats_.vitality;
        sr_stubborn_will_available_ = true;

        // The Mortal Arena SR resets
        sr_blazeblood_available_ = true;
        sr_scaled_resilience_available_ = true;
        sr_fracture_burst_available_ = true;

        // The Depths of Denorim SR resets
        sr_hydras_resilience_available_ = true;
        sr_abyssal_mutation_available_ = true;

        // Moroboros SR resets
        sr_mist_form_available_ = true;

        // The Astral Tear SR resets
        sr_flicker_available_ = true;

        // L.I.T.O. SR resets
        sr_sap_healing_available_ = true;

        // The West End Gullet SR resets
        sr_disjointed_leap_available_ = true;
        sr_reality_slip_available_ = true;

        // The Cradling Depths SR resets
        sr_resonant_form_available_ = true;

        // Terminus Volarus SR resets
        sr_beacon_available_ = true;
        // The City of Eternal Light SR resets
        sr_light_step_available_ = true;
        sr_radiant_ward_available_ = true;
        sr_flareburst_available_ = true;
        sr_mystic_pulse_available_ = true;
        sr_windstep_uses_ = stats_.speed;
        // The Land of Tomorrow SR resets
        sr_temporal_shift_available_ = true;

        // Stat feat SR resets
        sg_advantage_sr_available_ = true;
        sg_heal_sr_available_ = true;
        // Combat feat SR resets
        sr_pt_reroll_available_ = true;
        ttb_uses_remaining_ = stats_.speed;
        sr_ttb_whirlwind_available_ = true;
        mp_double_attack_uses_remaining_ = stats_.strength;
        sr_fc_sacrifice_ac_available_ = true;
        sr_iw_explosion_available_ = true;
        sr_wm_auto_succeed_available_ = true;
        sr_la_shattershot_uses_ = 2;
        mp_dodge_avoid_bonus_ = 0;
        // Magic feat SR resets
        sr_ss_dc_boost_available_ = true;
        sr_bm_reroll_available_ = true;
        sr_bm_reservoir_save_available_ = true;
        // Alignment feat SR resets
        sr_cp_unpredictable_available_ = true;
        sr_cp_reroll_save_available_ = true;
        sr_cp_insubstantial_available_ = true;
        sr_cp_summon_available_ = true;
        sr_up_clarity_available_ = true;
        sr_up_radiant_burst_available_ = true;
        sr_up_summon_available_ = true;
        sr_vp_sneak_bonus_available_ = true;
        sr_vp_intangible_available_ = true;
        sr_vp_summon_available_ = true;
        // Domain feat SR resets
        sr_chem_solution_available_ = true;
        sr_chem_free_spell_available_ = true;
        sr_phys_ember_available_ = true;
        sr_spir_telepathy_uses_ = stats_.divinity;
        // Misc feat SR resets
        sr_astral_shear_available_ = true;
        sr_chaos_flow_available_ = true;
        sr_echoed_steps_available_ = true;
        sr_emberwake_available_ = true;
        sr_flicker_sparky_available_ = true;
        sr_hollow_voice_available_ = true;
        sr_hollowed_instinct_available_ = true;
        sr_illusory_double_available_ = true;
        sr_planar_graze_available_ = true;
        sr_refraction_twist_available_ = true;
        sr_rune_cipher_available_ = true;
        sr_sacred_frag_available_ = true;
        sr_spark_leech_available_ = true;
        // Crafting feat SR resets
        sr_call_scroll_available_ = true;
        sr_call_glyph_available_ = true;
        sr_ca_temp_tool_available_ = true;
        sr_hunt_damage_available_ = true;
        enc_disg_failsafe_available_ = true;
        enc_thief_failsafe_available_ = true;
        // Exploration feat SR resets
        sr_ae_ignore_terrain_available_ = true;
        sr_ae_water_walk_ally_available_ = true;
        sr_hr_resistance_available_ = true;
        sr_hr_miracle_available_ = true;
        sr_id_illusion_available_ = true;
        sr_moc_reroll_available_ = true;
        sr_moc_auto_succeed_available_ = true;
        sr_ss_speechcraft_advantage_available_ = true;

        // Recovery: Twisted Joint, Ringing Ears, Winded (rest)
        auto it = injuries_.begin();
        while (it != injuries_.end()) {
            if (it->name == "Twisted Joint" || it->name == "Ringing Ears" || it->name == "Winded") {
                 it = injuries_.erase(it);
            } else {
                ++it;
            }
        }
    }

    void long_rest() {
        reset_resources();
        status_.reduce_exhaustion(1);
        if (insanity_level_ > 0) insanity_level_--;
        temporary_ac_bonus_ = 0;
        status_.remove_condition(ConditionType::Dying);
        status_.remove_condition(ConditionType::Dead);
        status_.remove_condition(ConditionType::Unconscious);
        has_iron_grip_prone_available_ = true;

        sr_rest_free_available_ = true;
        sr_efficient_recuperation_available_ = true;
        lr_tireless_spirit_available_ = true;
        lr_unyielding_vitality_available_ = true;
        // Combat feat LR resets
        if_max_damage_uses_remaining_ = stats_.strength;
        ss_max_damage_uses_remaining_ = stats_.speed;
        td_max_damage_uses_remaining_ = stats_.strength;
        lr_ud_shrug_available_ = true;
        lr_ud_reroll_available_ = true;
        lr_dp_bastion_form_available_ = true;
        dp_bastion_form_active_ = false;
        lr_es_force_reroll_available_ = true;
        lr_es_second_target_available_ = true;
        lr_es_condition_available_ = true;
        fc_enrage_uses_remaining_ = stats_.strength;
        fc_bloodied_aura_triggered_ = false;
        // Magic feat LR resets
        lr_me_teleport_used_ = false;
        lr_ss_disadv_used_ = false;
        lr_ss_force_fail_used_ = false;
        lr_ss_chain_used_ = false;
        lr_bm_immunity_used_ = false;
        lr_bm_kill_sp_regain_used_ = false;
        lr_bm_double_dice_used_ = false;
        // Alignment feat LR resets
        lr_cp_sense_chaos_available_ = true;
        lr_cp_miracle_available_ = true;
        lr_cs_free_chaos_sp_available_ = true;
        lr_cs_upgrade_spell_available_ = true;
        lr_up_sense_celestial_available_ = true;
        lr_up_dispel_blindness_available_ = true;
        lr_up_miracle_available_ = true;
        lr_us_free_unity_sp_available_ = true;
        lr_us_upgrade_spell_available_ = true;
        lr_vp_sense_void_available_ = true;
        lr_vp_miracle_available_ = true;
        lr_vs_free_darkness_sp_available_ = true;
        lr_vs_upgrade_spell_available_ = true;
        // Domain feat LR resets
        lr_bio_heal_available_ = true;
        lr_chem_reaction_available_ = true;
        lr_phys_illusion_available_ = true;
        lr_spir_nullify_available_ = true;

        // Recovery: Bruised Ribs, Blow to the Head, Minor Fracture, Cracked Skull, Severed Tendon, Torn Muscle
        auto it = injuries_.begin();
        while (it != injuries_.end()) {
            if (it->name == "Bruised Ribs" || it->name == "Blow to the Head" || it->name == "Minor Fracture" ||
                it->name == "Cracked Skull" || it->name == "Severed Tendon" || it->name == "Torn Muscle" ||
                it->name == "Twisted Joint" || it->name == "Ringing Ears" || it->name == "Winded" || it->name == "Rattled") {
                it = injuries_.erase(it);
            } else {
                ++it;
            }
        }
    }

    void revivify() {
        current_hp_ = 1;
        status_.remove_condition(ConditionType::Dead);
        status_.remove_condition(ConditionType::Dying);
        status_.remove_condition(ConditionType::Unconscious);
        is_stabilized_ = false;
        death_save_passes_ = 0;
        death_save_fails_ = 0;
        death_save_draws_ = 0;
    }

    void heal(int amount, bool is_magical = false) {
        // IronVitality T3 (Enduring Spirit): increase heals by Vitality score
        if (get_feat_tier(FeatID::IronVitality) >= 3 && amount > 0)
            amount += stats_.vitality;
        current_hp_ = std::min(get_max_hp(), current_hp_ + amount);
        if (current_hp_ > 0) {
            status_.remove_condition(ConditionType::Dying);
            status_.remove_condition(ConditionType::Dead);
            is_stabilized_ = false;
            death_save_passes_ = 0;
            death_save_fails_ = 0;
            death_save_draws_ = 0;
        }

        if (is_magical && current_hp_ == get_max_hp()) {
            // Magical healing to full clears most injuries
            auto it = injuries_.begin();
            while (it != injuries_.end()) {
                if (it->name != "Disfigured" && it->name != "Fractured Spine") { // Some are more permanent
                    it = injuries_.erase(it);
                } else {
                    ++it;
                }
            }
        }
    }

    void restore_sp(int amount) { current_sp_ = std::min(get_max_sp(), current_sp_ + amount); }
    void restore_ap(int amount) { current_ap_ = std::min(get_max_ap(), current_ap_ + amount); }

    [[nodiscard]] const std::string& get_name() const { return name_; }
    void set_name(const std::string& name) { name_ = name; }
    [[nodiscard]] const std::string& get_id() const { return unique_id_; }
    [[nodiscard]] int get_level() const { return level_; }
    void set_level(int level) { level_ = level; }
    [[nodiscard]] int get_xp() const { return xp_; }
    [[nodiscard]] int get_xp_required() const { return level_ * 3; }

    void add_xp(int amount, int level_limit = 20) {
        xp_ += amount;
        while (xp_ >= get_xp_required() && level_ < level_limit && level_ < 20) {
            xp_ -= get_xp_required();
            level_up();
        }
    }

    void fuse_with(const Character& other) { add_xp(other.get_level()); }

    [[nodiscard]] int get_stat_points() const { return stat_points_; }
    [[nodiscard]] int get_feat_points() const { return feat_points_; }
    [[nodiscard]] int get_skill_points() const { return skill_points_; }

    bool spend_stat_point(StatType stat) {
        int current_val = stats_.get_stat(stat);
        if (current_val >= 10) return false;
        int cost = (current_val >= 5) ? 2 : 1;
        if (stat_points_ < cost) return false;
        stats_.set_stat(stat, current_val + 1);
        stat_points_ -= cost;
        reset_resources();
        return true;
    }

    bool spend_skill_point(SkillType skill) {
        int current_val = skills_.get_skill(skill);
        if (current_val >= 10) return false;
        int cost = (current_val >= 5) ? 2 : 1;
        if (skill_points_ < cost) return false;
        skills_.set_skill(skill, current_val + 1);
        skill_points_ -= cost;
        return true;
    }

    bool spend_feat_point(FeatID id, int tier) {
        if (tier == 2 && level_ < 5) return false;
        if (tier == 3 && level_ < 9) return false;
        if (tier == 4 && level_ < 13) return false;
        if (tier == 5 && level_ < 17) return false;
        if (feat_points_ < tier) return false;
        int current_max = get_feat_tier(id);
        if (current_max >= tier || !FeatRegistry::instance().is_next_available_tier(id, current_max, tier)) return false;
        const auto* feat_ptr = FeatRegistry::instance().get_feat(id, tier);
        if (feat_ptr) { add_feat(*feat_ptr); feat_points_ -= tier; reset_resources(); return true; }
        return false;
    }

    void add_learned_spell(std::string spell_name) { learned_spells_.insert(std::move(spell_name)); }
    void remove_learned_spell(const std::string& spell_name) { learned_spells_.erase(spell_name); }
    [[nodiscard]] std::vector<std::string> get_learned_spells() const { return std::vector<std::string>(learned_spells_.begin(), learned_spells_.end()); }

    [[nodiscard]] Stats& get_stats() { return stats_; }
    [[nodiscard]] const Stats& get_stats_const() const { return stats_; }
    [[nodiscard]] Skills& get_skills() { return skills_; }
    [[nodiscard]] StatusManager& get_status() { return status_; }
    [[nodiscard]] int get_insanity_level() const { return insanity_level_; }
    void set_insanity_level(int level) { insanity_level_ = level; }
    [[nodiscard]] const std::vector<Injury>& get_injuries() const { return injuries_; }
    [[nodiscard]] int get_age() const { return age_; }
    void set_age(int age) { age_ = age; }
    [[nodiscard]] Alignment get_alignment() const { return alignment_; }
    void set_alignment(Alignment alignment) { alignment_ = alignment; }
    [[nodiscard]] Domain get_domain() const { return domain_affinity_; }
    void set_domain(Domain domain) { domain_affinity_ = domain; }
    [[nodiscard]] int get_gold() const { return gold_; }
    void set_gold(int gold) { gold_ = gold; }
    void add_gold(int amount) { gold_ += amount; }
    [[nodiscard]] const Lineage& get_lineage() const { return lineage_; }
    [[nodiscard]] const std::vector<SocietalRole>& get_societal_roles() const { return societal_roles_; }
    void add_societal_role(SocietalRole role) { societal_roles_.push_back(std::move(role)); }
    void clear_societal_roles() { societal_roles_.clear(); }
    [[nodiscard]] Inventory& get_inventory() { return inventory_; }
    [[nodiscard]] std::string get_current_region() const { return current_region_; }
    void set_current_region(std::string region) { current_region_ = std::move(region); }

    void add_feat(Feat feat) { feats_.push_back(std::move(feat)); }
    [[nodiscard]] int get_feat_tier(FeatID id) const {
        int max_tier = 0;
        for (const auto& feat : feats_) if (feat.id == id) max_tier = std::max(max_tier, feat.tier);
        return max_tier;
    }

    [[nodiscard]] std::string serialize() const;
    static std::unique_ptr<Character> deserialize(const std::string& data);

    [[nodiscard]] bool has_armor_proficiency(ArmorCategory category) const {
        if (category == ArmorCategory::Light) return get_feat_tier(FeatID::EvasiveWard) >= 1;
        if (category == ArmorCategory::Medium) return get_feat_tier(FeatID::BalancedBulwark) >= 1;
        if (category == ArmorCategory::Heavy) return get_feat_tier(FeatID::TitanicBastion) >= 1;
        if (category == ArmorCategory::TowerShield) return get_feat_tier(FeatID::TowerShield) >= 1;
        return true;
    }

    bool equip_weapon(std::unique_ptr<Weapon> weapon) { equipped_weapon_ = std::move(weapon); return true; }
    bool equip_armor(std::unique_ptr<Armor> armor) { if (armor && !has_armor_proficiency(armor->get_category())) return false; equipped_armor_ = std::move(armor); return true; }
    bool equip_shield(std::unique_ptr<Armor> shield) { if (shield && !has_armor_proficiency(shield->get_category())) return false; equipped_shield_ = std::move(shield); return true; }

    [[nodiscard]] Weapon* get_weapon() const { return equipped_weapon_.get(); }
    [[nodiscard]] Armor* get_armor() const { return equipped_armor_.get(); }
    [[nodiscard]] Armor* get_shield() const { return equipped_shield_.get(); }
    void equip_light_source(const std::string& name) { equipped_light_source_ = name; }
    void unequip_light_source() { equipped_light_source_.clear(); }
    [[nodiscard]] const std::string& get_light_source() const { return equipped_light_source_; }

    [[nodiscard]] int get_armor_class() const {
        if (equipped_armor_ && equipped_armor_->is_ruined()) {
            return 10 + stats_.speed + temporary_ac_bonus_ + dodge_ac_bonus_ - (has_injury("Minor Fracture") ? 2 : 0);
        }
        if (equipped_armor_ && equipped_armor_->is_broken()) {
            int shield_bonus = (equipped_shield_ && !equipped_shield_->is_broken()) ? equipped_shield_->get_ac_bonus() : 0;
            return 11 + stats_.speed + shield_bonus + temporary_ac_bonus_ + dodge_ac_bonus_ - (has_injury("Minor Fracture") ? 2 : 0);
        }

        int base_ac = 10 + stats_.speed;
        if (!equipped_armor_) {
            // Lineage natural armor (unarmored only)
            if (lineage_.name == "Goldscale") base_ac = std::max(base_ac, 13);
            else if (lineage_.name == "Ironhide") base_ac = std::max(base_ac, 13 + stats_.speed);
            else if (lineage_.name == "Beetlefolk") base_ac = std::max(base_ac, 13);
            else if (lineage_.name == "Tetrasimian") base_ac = std::max(base_ac, 13 + stats_.speed);
            else if (lineage_.name == "Panoplian") base_ac = 16; // Living Plate: fixed AC, no speed
            else if (lineage_.name == "Gilded Human") base_ac = std::max(base_ac, 13 + stats_.speed);
            else if (lineage_.name == "Pangol") base_ac = std::max(base_ac, 13 + stats_.speed); // Natural Armor: base 13
        }
        if (equipped_armor_) {
            base_ac = 10 + equipped_armor_->get_ac_bonus();
            if (equipped_armor_->get_category() != ArmorCategory::Heavy) {
                base_ac += stats_.speed;
            }
            // Panoplian: apply higher of armor AC vs Living Plate 16
            if (lineage_.name == "Panoplian") base_ac = std::max(base_ac, 16);
            // Gilded Human: Living Plate applies over armor too
            if (lineage_.name == "Gilded Human") base_ac = std::max(base_ac, 13 + stats_.speed);
            // Pangol: Natural Armor applies over armor too
            if (lineage_.name == "Pangol") base_ac = std::max(base_ac, 13 + stats_.speed);
        }
        if (equipped_shield_ && !equipped_shield_->is_broken()) {
            base_ac += equipped_shield_->get_ac_bonus();
        }

        int final_ac = base_ac + temporary_ac_bonus_ + dodge_ac_bonus_;
        if (status_.has_condition(ConditionType::ArmoredPlating)) final_ac += 2;
        if (has_injury("Minor Fracture")) final_ac -= 2;
        // Cragborn Human: Earth's Embrace — +1 AC on stone or earth (dungeon floors)
        if (lineage_.name == "Cragborn Human") final_ac += 1;
        // Stonemind Dvarrim: Architect's Shield — +2 AC while active
        if (stonemind_architects_shield_active_) final_ac += 2;
        // Telekinesis: Animated Shield — AC bonus without equipping a shield
        if (tk_animated_shield_ac_bonus_ > 0) final_ac += tk_animated_shield_ac_bonus_;
        // Shielded: magical barrier grants +2 AC
        if (status_.has_condition(ConditionType::Shielded)) final_ac += 2;
        // Frostbound Dvarrim: Glacial Wall — +3 AC while wall is raised
        if (glacial_wall_active_) final_ac += 3;
        // Glaceari: Frozen Veil — +2 AC while in frozen veil
        if (frozen_veil_rounds_ > 0) final_ac += 2;
        // Pangol: Natural Armor reaction — +5 AC until next turn
        if (pangol_armor_react_active_) final_ac += 5;
        // Saurian: Scaled Resilience — permanent +1 AC from natural scales
        if (lineage_.name == "Saurian") final_ac += 1;

        // Ascendant: Draconic Apotheosis Scales — +2 AC while active
        if (draconic_apo_scales_active_) final_ac += 2;

        // Unyielding Defender T1: +1 AC
        {
            int ud_tier = get_feat_tier(FeatID::UnyieldingDefender);
            if (ud_tier >= 1) final_ac += 1;
            // T2: additional +1 AC when at 1/3 or less health (total +2)
            if (ud_tier >= 2 && current_hp_ > 0 && current_hp_ <= get_max_hp() / 3) final_ac += 1;
        }

        return final_ac;
    }

    [[nodiscard]] int get_current_hp() const { return current_hp_; }
    [[nodiscard]] int get_max_hp() const {
        int vit_multiplier = get_feat_tier(FeatID::IronVitality) >= 5 ? 3 : (get_feat_tier(FeatID::IronVitality) >= 1 ? 2 : 1);
        // Sunderborn: Sanguine Immortality — HP = 3 + Level + (VIT multiplier * VIT), no 3x level bonus
        int base_hp = (lineage_.name == "Sunderborn Human")
            ? 3 + level_ + (vit_multiplier * stats_.vitality)
            : 3 + (3 * level_) + (vit_multiplier * stats_.vitality);
        for (const auto& injury : injuries_) if (injury.name == "Collapsed Lung") base_hp = static_cast<int>(base_hp * 0.75);
        return base_hp;
    }

    [[nodiscard]] int get_max_ap() const {
        int str_multiplier = get_feat_tier(FeatID::MartialFocus) >= 5 ? 3 : (get_feat_tier(FeatID::MartialFocus) >= 1 ? 2 : 1);
        int base = 3 + (str_multiplier * stats_.strength);
        if (shardkin_crystal_resilience_active_) base = std::max(0, base - 3);
        if (argent_silent_ledger_active_) base = std::max(0, base - 3);
        if (glacial_wall_active_) base = std::max(0, base - 3);
        if (stonemind_architects_shield_active_) base = std::max(0, base - 3);
        if (miners_instinct_active_) base = std::max(0, base - 3);
        if (cloudling_fly_active_) base = std::max(0, base - 3);
        if (memory_echo_active_) base = std::max(0, base - 3);
        if (obedient_aura_active_) base = std::max(0, base - 3);
        if (void_cloak_active_) base = std::max(0, base - 3);
        if (warp_resistance_active_) base = std::max(0, base - 3);
        if (anti_magic_cone_active_) base = std::max(0, base - 3);
        if (resonant_sermon_active_) base = std::max(0, base - 3);
        // Ascendant feat AP reductions
        if (angelic_flight_active_) base = std::max(0, base - 1);
        if (angelic_safeguard_active_) base = std::max(0, base - 3);
        if (draconic_apo_flight_active_) base = std::max(0, base - 1);
        if (fey_reality_distort_active_) base = std::max(0, base - 3);
        if (hag_nightmare_brood_active_) base = std::max(0, base - 3);
        if (vampire_flight_intangible_active_) base = std::max(0, base - 3);
        if (voidborn_reality_distort_active_) base = std::max(0, base - 3);
        if (seraphic_flame_flicker_ap_cost_ > 0) base = std::max(0, base - seraphic_flame_flicker_ap_cost_);
        if (stormbound_grow_ap_cost_ > 0) base = std::max(0, base - stormbound_grow_ap_cost_);
        if (elemental_shifting_hide_stacks_ > 0) base = std::max(0, base - (2 * elemental_shifting_hide_stacks_));
        return base;
    }

    [[nodiscard]] int get_max_sp() const {
        int div_multiplier = get_feat_tier(FeatID::ArcaneWellspring) >= 5 ? 3 : (get_feat_tier(FeatID::ArcaneWellspring) >= 1 ? 2 : 1);
        int base = 3 + level_ + (div_multiplier * stats_.divinity);
        if (lineage_.name == "Elf") base += level_; // Innate Magic: +1 SP per level
        return std::max(0, base);
    }

    [[nodiscard]] int get_movement_speed() const {
        if (panoplian_sentinel_stand_active_) return 0; // Sentinel's Stand: anchored
        if (curl_up_active_) return 0; // Pangol: Curl Up — speed drops to 0
        if (status_.has_condition(ConditionType::Restrained) || status_.has_condition(ConditionType::Grappled) || status_.has_condition(ConditionType::Paralyzed) || status_.has_condition(ConditionType::Petrified)) return 0;
        int base_speed = 20 + (10 * stats_.speed) - speed_penalty_;
        if (gravitational_leap_rounds_ > 0) base_speed *= 2; // Gravitational Leap: double speed
        if (surge_step_active_) base_speed *= 2; // Tidewoven: Surge Step — double speed this turn
        if (has_injury("Limping")) base_speed -= 10;

        for (const auto& inj : injuries_) {
            if (inj.name.find("Broken") != std::string::npos && (inj.limb_index == 3 || inj.limb_index == 4)) {
                return 15; // Speed reduced to 15ft per move action if it is a leg.
            }
        }

        if (status_.has_condition(ConditionType::Slowed)) return std::max(0, base_speed) / 2;
        return std::max(0, base_speed);
    }

    [[nodiscard]] bool has_injury(const std::string& name) const {
        return std::any_of(injuries_.begin(), injuries_.end(), [&](const Injury& i) { return i.name == name; });
    }

    void absorb_damage_with_item(int& damage_amount, const std::string& item_type) {
        Item* item = nullptr;
        if (item_type == "Weapon") item = get_weapon();
        else if (item_type == "Armor") item = get_armor();
        else if (item_type == "Shield") item = get_shield();

        if (item && !item->is_broken()) {
            int max_absorb = damage_amount / 2;
            int absorbed = std::min(max_absorb, item->get_current_hp());
            item->take_damage(absorbed);
            damage_amount -= absorbed;
        }
    }

    void take_damage(int amount, Dice& dice, bool is_critical = false) {
        if (pending_damage_reduction_ > 0) {
            amount = std::max(0, amount - pending_damage_reduction_);
            pending_damage_reduction_ = 0;
        }
        // Bookborn: Paper Ward — reduce damage by level + Intellect (INT/SR)
        if (lineage_.name == "Bookborn" && sr_paper_ward_uses_ > 0) {
            int ward = level_ + stats_.intellect;
            amount = std::max(0, amount - ward);
            sr_paper_ward_uses_--;
        }
        if (!pending_absorb_item_.empty()) {
            absorb_damage_with_item(amount, pending_absorb_item_);
            pending_absorb_item_ = "";
        }

        if (!equipped_armor_ && get_feat_tier(FeatID::UnarmoredMaster) >= 4) amount /= 2;

        // Chronogears: Temporal Shift — halve next incoming damage (1/SR reaction, primed)
        if (temporal_shift_primed_) {
            amount = std::max(1, amount / 2);
            temporal_shift_primed_ = false;
        }
        // Luminar Human: Beacon — resistance to all damage for 1 round after absorbing Fear
        if (beacon_resistance_rounds_ > 0) {
            amount = std::max(1, amount / 2);
        }
        // Lightbound: Radiant Ward — radiant resistance for duration (tracked via radiant_ward_rounds_)
        // (radiant damage is checked in execute_spell; this provides general damage reduction if ward active)
        if (has_injury("Punctured Organ") && is_critical) {
            amount += dice.roll(6) + dice.roll(6);
        }

        int prev_hp = current_hp_;
        current_hp_ -= amount;

        int max_hp = get_max_hp();
        HealthStatus status = status_.calculate_health_status(current_hp_, max_hp);

        // IronVitality T1 (Resilient Frame): once/enc, when HP crosses ≤ half threshold, gain Vitality HP
        if (get_feat_tier(FeatID::IronVitality) >= 1 && !iv_resilient_frame_triggered_
            && current_hp_ > 0 && current_hp_ <= max_hp / 2 && prev_hp > max_hp / 2) {
            iv_resilient_frame_triggered_ = true;
            current_hp_ = std::min(max_hp, current_hp_ + stats_.vitality);
        }

        // Instant Death
        if (current_hp_ <= -2 * max_hp) {
            current_hp_ = -2 * max_hp;
            status_.add_condition(ConditionType::Dead);
            return;
        }

        // IronVitality T5 (Titanic Endurance): once/LR, drop to 1 HP instead of 0 (if not outright death)
        if (current_hp_ <= 0 && prev_hp > 0 && iv_titanic_endurance_lr_available_
            && get_feat_tier(FeatID::IronVitality) >= 5 && current_hp_ > -2 * max_hp) {
            iv_titanic_endurance_lr_available_ = false;
            current_hp_ = 1;
            return;
        }

        // Felinar: Nine Lives — drop to 9 HP instead of 0 (9 uses per LR)
        if (current_hp_ <= 0 && prev_hp > 0 && lineage_.name == "Felinar" && felinar_nine_lives_remaining_ > 0) {
            current_hp_ = 9;
            felinar_nine_lives_remaining_--;
            return; // avoided death
        }
        // Tombwalker: Deathless Endurance — drop to 1 HP instead of 0 (1/LR)
        if (current_hp_ <= 0 && prev_hp > 0 && lineage_.name == "Tombwalker" && lr_deathless_endurance_available_) {
            current_hp_ = 1;
            lr_deathless_endurance_available_ = false;
            return;
        }
        // Ashenborn: Burnt Offering — gain 2 SP when reduced to 0 HP (1/LR), ember holds on
        if (current_hp_ <= 0 && prev_hp > 0 && lineage_.name == "Ashenborn" && lr_burnt_offering_available_) {
            lr_burnt_offering_available_ = false;
            restore_sp(2);
            current_hp_ = 1;
            return;
        }
        // Sunderborn: Death Denied — spend cumulative SP to pull back from death
        if (current_hp_ <= 0 && prev_hp > 0 && lineage_.name == "Sunderborn Human" && current_sp_ >= sunderborn_death_denied_sp_cost_) {
            current_sp_ -= sunderborn_death_denied_sp_cost_;
            sunderborn_death_denied_sp_cost_++;
            current_hp_ = dice.roll(6) + stats_.vitality;
            return;
        }
        // BloodOfTheAncients: ignore first damage instance each round
        if (boa_active_ && !boa_damage_ignored_this_round_ && prev_hp > 0 && amount > 0) {
            boa_damage_ignored_this_round_ = true;
            current_hp_ = prev_hp; // undo damage
            return;
        }
        // VoidbornMutation: Immortal Mask — 1/LR, when HP ≤ 0, restore to full HP
        if (current_hp_ <= 0 && prev_hp > 0 && voidborn_immortal_mask_available_
            && get_feat_tier(FeatID::VoidbornMutation) >= 1 && current_hp_ > -2 * max_hp) {
            voidborn_immortal_mask_available_ = false;
            current_hp_ = get_max_hp();
            return;
        }
        // InfernalCoronation: Second Chances — 1/LR, on 0 HP restore to 3×VIT
        if (current_hp_ <= 0 && prev_hp > 0 && infernal_second_chance_available_
            && get_feat_tier(FeatID::InfernalCoronation) >= 1 && current_hp_ > -2 * max_hp) {
            infernal_second_chance_available_ = false;
            current_hp_ = 3 * stats_.vitality;
            return;
        }
        // MythicRegrowth: once/LR, when reduced to 0 HP, rise to 1 HP + regen 50 HP for 2 turns + resistance
        if (current_hp_ <= 0 && prev_hp > 0 && lr_mythic_regrowth_available_
            && get_feat_tier(FeatID::MythicRegrowth) >= 1 && current_hp_ > -2 * max_hp) {
            lr_mythic_regrowth_available_ = false;
            current_hp_ = 1;
            mythic_regrowth_regen_turns_ = 2;
            status_.add_condition(ConditionType::Resistance);
            return;
        }
        // Sparkforged Human: Overload Pulse — flag trigger when killed (AoE handled in CombatManager)
        // (flag checked in execute_attack / execute_spell after damage)
        // Kelpheart Human: Ocean's Embrace — auto-stabilize when reduced to 0 HP (never drowns)
        if (current_hp_ <= 0 && prev_hp > 0 && lineage_.name == "Kelpheart Human") {
            current_hp_ = 0;
            is_stabilized_ = true;
            status_.add_condition(ConditionType::Unconscious);
            return;
        }

        // Dying / Unconscious transition
        if (current_hp_ <= 0 && prev_hp > 0) {
            status_.add_condition(ConditionType::Dying);
            status_.add_condition(ConditionType::Unconscious);
            death_save_passes_ = 0;
            death_save_fails_ = 0;
            death_save_draws_ = 0;
            // Kindlekin: capture hit count for post-death Combustive Touch spark decay
            if (lineage_.name == "Kindlekin" && kindlekin_hit_count_ > 0 && kindlekin_death_dice_count_ == 0) {
                kindlekin_death_dice_count_ = kindlekin_hit_count_;
            }
        }

        // Injury triggers
        bool trigger_injury = false;
        if (status == HealthStatus::Bloodied && prev_hp >= (2.0 * max_hp / 3.0)) trigger_injury = true;
        else if (status == HealthStatus::NearDeath) trigger_injury = true;

        if (trigger_injury) {
            if (roll_stat_check(dice, StatType::Vitality, RollType::Normal).total < 10 + amount) {
                Injury inj;
                if (status == HealthStatus::NearDeath) {
                    int roll = dice.roll(12);
                    int limb = (roll == 1) ? dice.roll(4) : 0;
                    int timer = (roll == 12) ? dice.roll(4) : 0;
                    inj = InjuryTable::get_near_death_injury(roll, limb, timer);
                } else {
                    inj = InjuryTable::get_bloodied_injury(dice.roll(12));
                }

                if (inj.name == "Glancing Blow") {
                    current_hp_ -= 2;
                } else {
                    injuries_.push_back(inj);
                    // Apply immediate secondary effects
                    if (!inj.effect_2_description.empty()) {
                        if (inj.effect_2_description == "Stunned") status_.add_condition(ConditionType::Stunned);
                        else if (inj.effect_2_description == "Poisoned") status_.add_condition(ConditionType::Poisoned);
                        else if (inj.effect_2_description == "Dazed") status_.add_condition(ConditionType::Dazed);
                        else if (inj.effect_2_description == "Slowed") status_.add_condition(ConditionType::Slowed);
                        else if (inj.effect_2_description == "Fall prone") status_.add_condition(ConditionType::Prone);
                        else if (inj.effect_2_description == "Blinded") status_.add_condition(ConditionType::Blinded);
                        else if (inj.effect_2_description == "Paralyzed") status_.add_condition(ConditionType::Paralyzed);
                        else if (inj.effect_2_description == "Unconscious") status_.add_condition(ConditionType::Unconscious);
                    }
                }
            }
        }
    }

    std::string perform_death_save(Dice& dice) {
        if (status_.has_condition(ConditionType::Dead) || !status_.has_condition(ConditionType::Dying)) return "";

        int roll = dice.roll(20);
        std::string result_msg = name_ + " rolls a death save: " + std::to_string(roll);

        if (roll == 20) {
            death_save_passes_ += 2;
            result_msg += " (Critical Success! 2 Passes)";
        } else if (roll == 1) {
            // Grimshell: Tomb Core — convert first failure to a success
            if (lineage_.name == "Grimshell" && !grimshell_tomb_core_used_) {
                death_save_passes_++;
                grimshell_tomb_core_used_ = true;
                result_msg += " (Critical Failure! — Tomb Core: Converted to Pass!)";
            } else {
                death_save_fails_ += 2;
                result_msg += " (Critical Failure! 2 Fails)";
            }
        } else if (roll > 10) {
            death_save_passes_++;
            result_msg += " (Pass)";
        } else if (roll < 10) {
            // Grimshell: Tomb Core — convert first failure to a success
            if (lineage_.name == "Grimshell" && !grimshell_tomb_core_used_) {
                death_save_passes_++;
                grimshell_tomb_core_used_ = true;
                result_msg += " (Fail — Tomb Core: Converted to Pass!)";
            } else {
                death_save_fails_++;
                result_msg += " (Fail)";
            }
        } else {
            death_save_draws_++;
            result_msg += " (Draw)";
        }

        if (death_save_fails_ >= 3) {
            status_.add_condition(ConditionType::Dead);
            status_.remove_condition(ConditionType::Dying);
            result_msg += " - " + name_ + " has died.";
        } else if (death_save_passes_ >= 3) {
            is_stabilized_ = true;
            status_.remove_condition(ConditionType::Dying);
            result_msg += " - " + name_ + " is stabilized but unconscious.";
        } else if (death_save_draws_ >= 3 && roll > 10) {
            // Special rule: 3 draws before 3 pass/fail, then a pass -> awaken with 1 HP
            current_hp_ = 1;
            status_.remove_condition(ConditionType::Dying);
            status_.remove_condition(ConditionType::Unconscious);
            death_save_passes_ = 0;
            death_save_fails_ = 0;
            death_save_draws_ = 0;
            result_msg += " - " + name_ + " awakens with 1 HP!";
        }

        return result_msg;
    }

    void start_turn() {
        if (!status_.has_condition(ConditionType::Depleted)) {
            int regen = std::max(1, stats_.strength);
            current_ap_ = std::min(get_max_ap(), current_ap_ + regen);
        }
        temporary_ac_bonus_ = 0; has_used_free_counter_ = false; dodge_ac_bonus_ = 0; dodge_attack_bonus_ = 0;
        status_.remove_condition(ConditionType::HeatedScales); // Heated Scales lasts until start of next turn
        if (speechcraft_bonus_rounds_ > 0) speechcraft_bonus_rounds_--;
        if (advantage_until_tick_ > 0) advantage_until_tick_--;
        loyal_strike_reaction_available_ = true;
        has_secondary_arms_attack_available_ = true;
        panoplian_sentinel_stand_active_ = false;
        if (bookborn_origami_rounds_ > 0) { bookborn_origami_rounds_--; if (bookborn_origami_rounds_ == 0) bookborn_origami_active_ = false; }
        if (witherborn_decay_rounds_ > 0) { witherborn_decay_rounds_--; if (witherborn_decay_rounds_ == 0) has_poison_resistance_ = (lineage_.name == "Myconid" || lineage_.name == "Thornwrought Human" || lineage_.name == "Mireborn Human" || lineage_.name == "Hollowborn Human" || lineage_.name == "Mistborne Hatchling"); }
        if (serpentine_venom_weapon_rounds_ > 0) serpentine_venom_weapon_rounds_--;
        if (arcane_surge_rounds_ > 0) arcane_surge_rounds_--;
        if (hex_mark_rounds_ > 0) hex_mark_rounds_--;
        witchblood_active_ = false;
        ferrusk_scrap_ac_used_ = false;
        if (frozen_veil_rounds_ > 0) frozen_veil_rounds_--;
        if (gravitational_leap_rounds_ > 0) { gravitational_leap_rounds_--; if (gravitational_leap_rounds_ == 0) status_.remove_condition(ConditionType::Flying); }
        if (frostborn_icewalk_rounds_ > 0) { frostborn_icewalk_rounds_--; if (frostborn_icewalk_rounds_ == 0) frostborn_icewalk_active_ = false; }
        if (void_aura_rounds_ > 0) void_aura_rounds_--;
        if (creeping_dark_rounds_ > 0) { creeping_dark_rounds_--; if (creeping_dark_rounds_ == 0) { creeping_dark_active_ = false; status_.remove_condition(ConditionType::Invisible); } }
        if (unyielding_bulwark_rounds_ > 0) { unyielding_bulwark_rounds_--; if (unyielding_bulwark_rounds_ == 0) { unyielding_bulwark_active_ = false; has_physical_resistance_ = (lineage_.name == "Lithari"); } }
        if (wind_cloak_rounds_ > 0) wind_cloak_rounds_--;
        if (chromatic_shift_rounds_ > 0) chromatic_shift_rounds_--;
        if (dust_shroud_rounds_ > 0) dust_shroud_rounds_--;
        if (prismatic_reflection_rounds_ > 0) { prismatic_reflection_rounds_--; if (prismatic_reflection_rounds_ == 0) status_.remove_condition(ConditionType::Resistance); }
        if (pain_made_flesh_rounds_ > 0) { pain_made_flesh_rounds_--; if (pain_made_flesh_rounds_ == 0) { pain_made_flesh_active_ = false; status_.remove_condition(ConditionType::Invulnerable); } }
        if (infernal_stare_rounds_ > 0) infernal_stare_rounds_--;
        if (infernal_smite_rounds_ > 0) infernal_smite_rounds_--;
        pangol_armor_react_active_ = false; // clears per-turn AC reaction
        if (cursed_spark_rounds_ > 0) cursed_spark_rounds_--;
        if (desert_walker_rounds_ > 0) desert_walker_rounds_--;
        if (blazeblood_rounds_ > 0) blazeblood_rounds_--;
        if (soot_sight_rounds_ > 0) { soot_sight_rounds_--; if (soot_sight_rounds_ == 0) status_.remove_condition(ConditionType::Dodging); }
        if (smoldering_glare_rounds_ > 0) smoldering_glare_rounds_--;
        if (draconic_form_rounds_ > 0) { draconic_form_rounds_--; if (draconic_form_rounds_ == 0) { draconic_form_active_ = false; status_.remove_condition(ConditionType::Flying); } }
        crackling_edge_used_ = false;
        sunderborn_frenzy_available_ = false;
        if (lunar_radiance_rounds_ > 0) lunar_radiance_rounds_--;
        if (mist_form_rounds_ > 0) { mist_form_rounds_--; if (mist_form_rounds_ == 0) { status_.remove_condition(ConditionType::Intangible); } }
        surge_step_active_ = false;
        leech_hex_used_this_turn_ = false;
        if (veiled_presence_rounds_ > 0) veiled_presence_rounds_--;
        if (convergent_synthesis_rounds_ > 0) { convergent_synthesis_rounds_--; if (convergent_synthesis_rounds_ == 0) { convergent_synthesis_active_ = false; status_.remove_condition(ConditionType::Enraged); } }
        if (carrionari_flight_rounds_ > 0) { carrionari_flight_rounds_--; if (carrionari_flight_rounds_ == 0) status_.remove_condition(ConditionType::Flying); }
        if (temporal_flicker_rounds_ > 0) { temporal_flicker_rounds_--; if (temporal_flicker_rounds_ == 0) status_.remove_condition(ConditionType::Intangible); }
        if (toxic_seep_rounds_ > 0) toxic_seep_rounds_--;
        // Terminus Volarus / City of Eternal Light / Hallowed Sacrament / Land of Tomorrow timers
        if (beacon_resistance_rounds_ > 0) beacon_resistance_rounds_--;
        if (dawns_blessing_rounds_ > 0) { dawns_blessing_rounds_--; status_.remove_condition(ConditionType::Blinded); }
        if (radiant_ward_rounds_ > 0) radiant_ward_rounds_--;
        if (drifting_fog_rounds_ > 0) drifting_fog_rounds_--;
        if (windswift_rounds_ > 0) { windswift_rounds_--; if (windswift_rounds_ == 0) { windswift_active_ = false; status_.remove_condition(ConditionType::Flying); } }
        // Static Surge countdown (before penalty so timing is correct)
        if (static_surge_daze_rounds_ > 0) { static_surge_daze_rounds_--; if (static_surge_daze_rounds_ == 0) status_.remove_condition(ConditionType::Dazed); }
        if (static_surge_active_) {
            static_surge_active_ = false;
            int n = static_surge_action_count_;
            if (n > 0) {
                rimvale::Dice local_d;
                int total_dmg = 0;
                for (int i = 0; i < n; i++) total_dmg += local_d.roll(4);
                take_damage(total_dmg, local_d);
                static_surge_daze_rounds_ = n;
                status_.add_condition(ConditionType::Dazed);
            }
        }
        has_ignored_bludgeoning_resistance_this_turn_ = false;
        has_ignored_bludgeoning_immunity_this_turn_ = false;
        ih_speed_penalty_used_this_turn_ = false;
        speed_penalty_ = 0;
        mf_unstoppable_assault_used_rnd_ = false;
        // Feat per-turn resets
        ce_ignore_resist_used_this_turn_ = false;
        ce_ignore_immunity_used_this_turn_ = false;
        ce_extra_die_used_this_turn_ = false;
        it_ignore_resist_used_this_turn_ = false;
        it_ac_reduction_used_this_turn_ = false;
        it_ignore_immunity_used_this_turn_ = false;
        if_ignore_resist_used_this_turn_ = false;
        if_speed_penalty_used_this_turn_ = false;
        if_extra_die_used_this_turn_ = false;
        mp_glancing_used_this_turn_ = false;
        ss_flurry_used_this_turn_ = false;
        td_ignore_disadv_used_this_turn_ = false;
        tf_hits_this_turn_ = 0;
        tf_third_attack_reaction_used_ = false;
        wm_reroll_used_this_turn_ = false;
        dp_feint_used_this_round_ = false;
        iw_disarm_used_this_turn_ = false;
        me_max_die_used_this_turn_ = false;
        lr_hunt_quarry_hit_this_round_ = false;
        if (pois_weapon_rounds_ > 0) { pois_weapon_rounds_--; if (pois_weapon_rounds_ == 0) { pois_weapon_disadvantage_ = false; pois_weapon_extra_damage_ = false; } }
        if (culinary_attack_bonus_rounds_ > 0) culinary_attack_bonus_rounds_--;
        if (split_second_ac_bonus_rounds_ > 0) { split_second_ac_bonus_rounds_--; if (split_second_ac_bonus_rounds_ == 0) temporary_ac_bonus_ = std::max(0, temporary_ac_bonus_ - 1); }
        if (chaos_flow_bonus_rounds_ > 0) chaos_flow_bonus_rounds_--;
        if (flicker_resistance_active_) flicker_resistance_active_ = false; // lasts until end of next turn
        // Apex feat per-turn updates
        soulbrand_used_this_round_ = false;
        boa_damage_ignored_this_round_ = false;
        worldbreaker_step_movement_this_turn_ = 0;
        if (arcane_overdrive_rounds_ > 0) {
            // Triple AP regen: grant double the normal regen (normal regen already applied above)
            if (!status_.has_condition(ConditionType::Depleted)) restore_ap(2 * std::max(1, stats_.strength));
            arcane_overdrive_rounds_--;
            if (arcane_overdrive_rounds_ == 0) arcane_overdrive_active_ = false;
        }
        if (boa_rounds_ > 0) { boa_rounds_--; if (boa_rounds_ == 0) { boa_active_ = false; status_.remove_condition(ConditionType::Resistance); } }
        if (eclipse_veil_rounds_ > 0) { eclipse_veil_rounds_--; if (eclipse_veil_rounds_ == 0) eclipse_veil_active_ = false; }
        if (runebreaker_active_rounds_ > 0) runebreaker_active_rounds_--;
        if (stormbound_mantle_rounds_ > 0) stormbound_mantle_rounds_--;
        if (voidbrand_rounds_ > 0) voidbrand_rounds_--;
        if (mythic_regrowth_regen_turns_ > 0) {
            rimvale::Dice local_d;
            heal(50);
            mythic_regrowth_regen_turns_--;
        }
        // Ascendant per-turn effects
        if (psychic_maw_phase_shift_rounds_ > 0) {
            psychic_maw_phase_shift_rounds_--;
            if (psychic_maw_phase_shift_rounds_ == 0) status_.remove_condition(ConditionType::Intangible);
        }
        if (voidborn_phase_shift_rounds_ > 0) {
            voidborn_phase_shift_rounds_--;
            if (voidborn_phase_shift_rounds_ == 0) status_.remove_condition(ConditionType::Intangible);
        }
        if (seraphic_reflective_veil_rounds_ > 0) seraphic_reflective_veil_rounds_--;
        if (cryptborn_blight_rounds_ > 0) cryptborn_blight_rounds_--;
        if (lycanthrope_blood_howl_rounds_ > 0) lycanthrope_blood_howl_rounds_--;
        if (lycanthrope_hybrid_active_) {
            // Regeneration: 1d6 HP/turn while in hybrid form
            rimvale::Dice local_d;
            heal(local_d.roll(6));
        }
        if (cryptborn_regen_active_) {
            // CryptbornSovereign Regeneration: 1d6 HP/turn (even at 0 HP)
            rimvale::Dice local_d;
            int regen_hp = local_d.roll(6);
            current_hp_ = std::min(get_max_hp(), current_hp_ + regen_hp);
            // If at 0 HP, clear dying state (zombie keeps going)
            if (current_hp_ > 0) {
                status_.remove_condition(ConditionType::Dying);
                is_stabilized_ = false;
                death_save_passes_ = 0; death_save_fails_ = 0; death_save_draws_ = 0;
            }
        }
        if (vampire_flight_intangible_active_) {
            // Vampire regeneration: if not staked and near death, begin regen countdown
            if (current_hp_ <= 0 && !vampire_staked_) {
                if (vampire_regen_timer_ == 0) vampire_regen_timer_ = 288; // ~24 hours in 5-min turns
                else { vampire_regen_timer_--; if (vampire_regen_timer_ == 0) { current_hp_ = 1; status_.remove_condition(ConditionType::Dead); status_.remove_condition(ConditionType::Dying); status_.remove_condition(ConditionType::Unconscious); } }
            }
        }

        if (has_injury("Shallow Bleed")) {
            rimvale::Dice dice;
            take_damage(1, dice);
        }

        if (has_injury("Concussion")) {
            rimvale::Dice dice;
            if (roll_stat_check(dice, StatType::Vitality).total < 13) {
                status_.add_condition(ConditionType::Unconscious);
            }
        }

        auto it = injuries_.begin();
        while (it != injuries_.end()) {
            if (it->rounds_remaining > 0) {
                it->rounds_remaining--;
                if (it->rounds_remaining == 0) {
                    it = injuries_.erase(it);
                    continue;
                }
            }

            if (it->name == "Near Death Experience") {
                if (it->rounds_until_death > 0) {
                    it->rounds_until_death--;
                    if (it->rounds_until_death == 0) {
                        current_hp_ = 0;
                        status_.add_condition(ConditionType::Dying);
                    }
                }
            }
            ++it;
        }
    }

    void add_dodge_bonus() { temporary_ac_bonus_ += 1; if (get_feat_tier(FeatID::DeflectiveStance) >= 1) dodge_ac_bonus_ += 1; }
    void add_temp_ac(int amount) { temporary_ac_bonus_ += amount; }
    [[nodiscard]] int calculate_action_cost(int base_cost) const { return (status_.has_condition(ConditionType::Confused) || status_.has_condition(ConditionType::Stunned)) ? base_cost * 2 : base_cost; }

    RollResult roll_skill_check(Dice& dice, SkillType skill, RollType type = RollType::Normal) {
        if ((has_evasion_advantage_ || (advantage_until_tick_ > 0) || has_recuperation_advantage_) && type == RollType::Normal) {
            type = RollType::Advantage;
            if (!has_recuperation_advantage_ && advantage_until_tick_ <= 0) has_evasion_advantage_ = false;
            if (has_recuperation_advantage_) has_recuperation_advantage_ = false;
        }
        // Felinar: Cat's Balance — advantage on Nimble, Cunning checks
        if (lineage_.name == "Felinar" && type == RollType::Normal &&
            (skill == SkillType::Nimble || skill == SkillType::Cunning)) {
            type = RollType::Advantage;
        }
        // Lithari / Blackroot: advantage on Survival checks
        if ((lineage_.name == "Lithari" || lineage_.name == "Blackroot") && skill == SkillType::Survival && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Mirevenom: Lurker's Step — advantage on Sneak checks
        if (lineage_.name == "Mirevenom" && skill == SkillType::Sneak && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Cervin: Fleet of Foot — advantage on Exertion (counts as Large for STR)
        if (lineage_.name == "Cervin" && skill == SkillType::Exertion && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Tetrasimian: Adaptive Hide — advantage on Sneak when camouflaged
        if (lineage_.name == "Tetrasimian" && skill == SkillType::Sneak && tetrasimian_sneak_advantage_ && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Arcanite Human: Magic Sense — advantage on Arcane checks
        if (lineage_.name == "Arcanite Human" && skill == SkillType::Arcane && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Voxilite: Golden Tongue — advantage on Speechcraft checks
        if (lineage_.name == "Voxilite" && skill == SkillType::Speechcraft && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Ironjaw: Magnetic Grip — advantage on Exertion (grapple) checks
        if (lineage_.name == "Ironjaw" && skill == SkillType::Exertion && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Duskling / Sable / Skulkin: advantage on Sneak checks
        if ((lineage_.name == "Duskling" || lineage_.name == "Sable" || lineage_.name == "Skulkin") &&
            skill == SkillType::Sneak && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Cragborn Human: Stonecunning — advantage on Crafting and Perception checks
        if (lineage_.name == "Cragborn Human" && (skill == SkillType::Crafting || skill == SkillType::Perception) && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Gravari: Stone Sense — advantage on Perception
        if (lineage_.name == "Gravari" && skill == SkillType::Perception && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Snareling: Ambusher's Gift — advantage on initiative (Cunning)
        if (lineage_.name == "Snareling" && skill == SkillType::Cunning && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Nightborne Human: Creeping Dark — advantage on Sneak while active
        if (lineage_.name == "Nightborne Human" && creeping_dark_active_ && skill == SkillType::Sneak && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Glaciervein Dvarrim: Miner's Instinct — advantage on Perception while active
        if (lineage_.name == "Glaciervein Dvarrim" && miners_instinct_active_ && (skill == SkillType::Perception || skill == SkillType::Learnedness) && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Porcelari: Gilded Bearing — advantage on Speechcraft checks
        if (lineage_.name == "Porcelari" && skill == SkillType::Speechcraft && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Prismari: Chromatic Shift — advantage on Sneak while active
        if (lineage_.name == "Prismari" && chromatic_shift_rounds_ > 0 && skill == SkillType::Sneak && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Weirkin Human: Eerie Insight — advantage on Learnedness checks
        if (lineage_.name == "Weirkin Human" && skill == SkillType::Learnedness && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Aetherian: Veiled Presence — advantage on Sneak while active
        if (lineage_.name == "Aetherian" && veiled_presence_rounds_ > 0 && skill == SkillType::Sneak && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Umbrawyrm: Shadow Coil — advantage on Sneak checks
        if (lineage_.name == "Umbrawyrm" && skill == SkillType::Sneak && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Echo-Touched: Resonant Form — advantage on Arcane checks (detecting/identifying magic)
        if (lineage_.name == "Echo-Touched" && skill == SkillType::Arcane && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Skysworn: Keen Sight — advantage on Perception checks
        if (lineage_.name == "Skysworn" && skill == SkillType::Perception && type == RollType::Normal)
            type = RollType::Advantage;
        // Starborn: Cosmic Awareness — advantage on Learnedness checks
        if (lineage_.name == "Starborn" && skill == SkillType::Learnedness && type == RollType::Normal)
            type = RollType::Advantage;
        // Silverblood: Runic Flow — advantage on Arcane checks
        if (lineage_.name == "Silverblood" && skill == SkillType::Arcane && type == RollType::Normal)
            type = RollType::Advantage;
        // Silverblood: Runic Flow Auto-Succeed — next Arcane check automatically succeeds
        if (lineage_.name == "Silverblood" && runic_flow_auto_primed_ && skill == SkillType::Arcane) {
            runic_flow_auto_primed_ = false;
            RollResult result;
            result.total = 999; result.die_roll = 20; result.details = "Runic Flow: Auto-succeed!";
            return result;
        }
        // Watchling: Broadcast Eye — advantage on Perception and Intuition checks
        if (lineage_.name == "Watchling" &&
            (skill == SkillType::Perception || skill == SkillType::Intuition) && type == RollType::Normal)
            type = RollType::Advantage;
        // Madness-Touched Human: Unstable Mutation — disadvantage on next 2 checks after advantage window
        if (lineage_.name == "Madness-Touched Human" && unstable_mutation_disadvantage_remaining_ > 0 &&
            advantage_until_tick_ == 0 && type == RollType::Normal) {
            type = RollType::Disadvantage;
            unstable_mutation_disadvantage_remaining_--;
        }

        // Apply Injury Disadvantages
        if (type != RollType::Disadvantage) {
            if ((skill == SkillType::Exertion || skill == SkillType::Nimble) && (has_injury("Twisted Joint") || has_injury("Collapsed Lung"))) type = RollType::Disadvantage;
            if (skill == SkillType::Perception && (has_injury("Ringing Ears") || has_injury("Vision Impaired"))) type = RollType::Disadvantage;
            if (skill == SkillType::Speechcraft && has_injury("Disfigured")) type = RollType::Disadvantage;
            if (has_injury("Cracked Skull")) {
                if (skill == SkillType::Arcane || skill == SkillType::Crafting || skill == SkillType::Learnedness || skill == SkillType::Medical || skill == SkillType::Perception) type = RollType::Disadvantage;
            }
        }

        int governing_stat_val = 0;
        switch (skill) {
            case SkillType::Arcane: case SkillType::Crafting: case SkillType::Learnedness: case SkillType::Medical: case SkillType::Perception: governing_stat_val = stats_.intellect; break;
            case SkillType::CreatureHandling: case SkillType::Intuition: case SkillType::Perform: case SkillType::Speechcraft: governing_stat_val = stats_.divinity; break;
            case SkillType::Cunning: case SkillType::Nimble: case SkillType::Sneak: governing_stat_val = stats_.speed; break;
            case SkillType::Exertion: governing_stat_val = stats_.strength; break;
            case SkillType::Survival: governing_stat_val = stats_.vitality; break;
        }

        int mod_bonus = 0;
        if (has_injury("Torn Muscle") && governing_stat_val == stats_.strength) mod_bonus -= 2;
        // Echoform Warden: Resonant Archive — +2 to Arcane checks
        if (lineage_.name == "Echoform Warden" && skill == SkillType::Arcane) mod_bonus += 2;

        // MindOverChallenge T2: 2x INT on skill checks; T3: 3x INT
        int int_mult = 1;
        if (get_feat_tier(FeatID::MindOverChallenge) >= 3) int_mult = 3;
        else if (get_feat_tier(FeatID::MindOverChallenge) >= 2) int_mult = 2;
        int int_bonus = stats_.intellect * int_mult;

        if (favored_skills_.count(skill)) {
            int passive_val = 10 + int_bonus + skills_.get_skill(skill) + mod_bonus;
            RollResult roll = dice.roll_d20(type, governing_stat_val + int_bonus + skills_.get_skill(skill) - status_.get_exhaustion_level() + mod_bonus, insanity_level_);
            if (passive_val > roll.total) {
                roll.die_roll = 10;
                roll.modifier = int_bonus + skills_.get_skill(skill) + mod_bonus;
                roll.total = passive_val;
                roll.details = "Used Favored Skill Passive (10 + " + std::to_string(roll.modifier) + ")";
            }
            // Elf: Keen Senses — +1d4 to Perception checks
            if (lineage_.name == "Elf" && skill == SkillType::Perception) {
                int bonus = dice.roll(4);
                roll.total += bonus;
                roll.details += " [+1d4 Perception: +" + std::to_string(bonus) + "]";
            }
            // Fae-Touched: Enchanting Presence shimmer — +1d4 to Speechcraft
            if (lineage_.name == "Fae-Touched Human" && skill == SkillType::Speechcraft && speechcraft_bonus_rounds_ > 0) {
                int bonus = dice.roll(4);
                roll.total += bonus;
                roll.details += " [+1d4 Shimmer: +" + std::to_string(bonus) + "]";
            }
            // Regal Human: Versatile — +1d4 to all skill checks
            if (lineage_.name == "Regal Human") {
                int bonus = dice.roll(4);
                roll.total += bonus;
                roll.details += " [+1d4 Versatile: +" + std::to_string(bonus) + "]";
            }
            // Gravetouched: Death's Echo — +1d4 to Intuition and Perception
            if (lineage_.name == "Gravetouched" && (skill == SkillType::Intuition || skill == SkillType::Perception)) {
                int bonus = dice.roll(4);
                roll.total += bonus;
                roll.details += " [+1d4 Death's Echo: +" + std::to_string(bonus) + "]";
            }
            return roll;
        }

        RollResult result = dice.roll_d20(type, governing_stat_val + int_bonus + skills_.get_skill(skill) - status_.get_exhaustion_level() + mod_bonus, insanity_level_);
        // Elf: Keen Senses — +1d4 to Perception checks
        if (lineage_.name == "Elf" && skill == SkillType::Perception) {
            int bonus = dice.roll(4);
            result.total += bonus;
            result.details += " [+1d4 Perception: +" + std::to_string(bonus) + "]";
        }
        // Fae-Touched: Enchanting Presence shimmer — +1d4 to Speechcraft
        if (lineage_.name == "Fae-Touched Human" && skill == SkillType::Speechcraft && speechcraft_bonus_rounds_ > 0) {
            int bonus = dice.roll(4);
            result.total += bonus;
            result.details += " [+1d4 Shimmer: +" + std::to_string(bonus) + "]";
        }
        // Regal Human: Versatile — +1d4 to all skill checks
        if (lineage_.name == "Regal Human") {
            int bonus = dice.roll(4);
            result.total += bonus;
            result.details += " [+1d4 Versatile: +" + std::to_string(bonus) + "]";
        }
        // Gravetouched: Death's Echo — +1d4 to Intuition and Perception
        if (lineage_.name == "Gravetouched" && (skill == SkillType::Intuition || skill == SkillType::Perception)) {
            int bonus = dice.roll(4);
            result.total += bonus;
            result.details += " [+1d4 Death's Echo: +" + std::to_string(bonus) + "]";
        }
        return result;
    }

    RollResult roll_stat_check(Dice& dice, StatType stat, RollType type = RollType::Normal) {
        if ((has_recuperation_advantage_ || advantage_until_tick_ > 0) && type == RollType::Normal) {
            type = RollType::Advantage;
            if (has_recuperation_advantage_) has_recuperation_advantage_ = false;
        }
        // Ironhide: Mechanical Mind — advantage on saves vs Charm
        if (lineage_.name == "Ironhide" && status_.has_condition(ConditionType::Charm) && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Marionox: Wooden Frame — advantage on saves when Grappled/Paralyzed/Prone/Stunned
        if (lineage_.name == "Marionox" && type == RollType::Normal &&
            (status_.has_condition(ConditionType::Grappled) || status_.has_condition(ConditionType::Paralyzed) ||
             status_.has_condition(ConditionType::Prone) || status_.has_condition(ConditionType::Stunned))) {
            type = RollType::Advantage;
        }
        // Ironjaw / Scavenger Human / Hollowborn Human: advantage on Vitality saves
        if ((lineage_.name == "Ironjaw" || lineage_.name == "Scavenger Human" || lineage_.name == "Hollowborn Human") && stat == StatType::Vitality && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Mireborn Human: Mud Sense — advantage on saves when Grappled or Restrained
        if (lineage_.name == "Mireborn Human" && type == RollType::Normal &&
            (status_.has_condition(ConditionType::Grappled) || status_.has_condition(ConditionType::Restrained))) {
            type = RollType::Advantage;
        }
        // Cragborn Human: Earth's Embrace — advantage on Strength saves
        if (lineage_.name == "Cragborn Human" && stat == StatType::Strength && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Boreal Human: Icewalk — advantage on Strength saves
        if (lineage_.name == "Boreal Human" && stat == StatType::Strength && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Glaciervein Dvarrim: Frostwaste Adaptation — advantage on Vitality saves
        if (lineage_.name == "Glaciervein Dvarrim" && stat == StatType::Vitality && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Madness-Touched Human: Unstable Mutation — disadvantage on next N stat saves
        if (lineage_.name == "Madness-Touched Human" && unstable_mutation_disadvantage_remaining_ > 0 &&
            type == RollType::Normal) {
            type = RollType::Disadvantage;
            unstable_mutation_disadvantage_remaining_--;
        }
        // Sandstrider Human: Heat Endurance — advantage on Vitality saves (exhaustion/heat)
        if (lineage_.name == "Sandstrider Human" && stat == StatType::Vitality && type == RollType::Normal) {
            type = RollType::Advantage;
        }
        // Hollowroot: Rooted — advantage on Strength saves (vs being moved, grappled, knocked prone)
        if (lineage_.name == "Hollowroot" && stat == StatType::Strength && type == RollType::Normal) {
            type = RollType::Advantage;
        }

        if (type != RollType::Disadvantage) {
            if (stat == StatType::Vitality && (has_injury("Bruised Ribs") || has_injury("Collapsed Lung"))) type = RollType::Disadvantage;
            if (stat == StatType::Intellect && has_injury("Blow to the Head")) type = RollType::Disadvantage;
            if (stat == StatType::Speed && has_injury("Fractured Spine")) type = RollType::Disadvantage;
        }

        int modifier = stats_.get_stat(stat) - status_.get_exhaustion_level();
        if (saving_throw_proficiencies_.count(stat)) modifier += (1 + level_ / 4);

        // Safeguard feat: double stat modifier for chosen (or all) stats
        {
            int sg_tier = get_feat_tier(FeatID::Safeguard);
            if (sg_tier >= 1) {
                int stat_idx = static_cast<int>(stat);
                bool is_sg_stat = (sg_tier >= 5) ||
                    (!safeguard_chosen_stats_.empty() && safeguard_chosen_stats_.count(stat_idx) > 0);
                if (is_sg_stat) {
                    modifier += stats_.get_stat(stat); // double the stat contribution
                    if (sg_tier >= 2) modifier += 2;   // Hardened Reflexes +2
                    // T4: auto-succeed armed
                    if (sg_auto_succeed_armed_ && sg_tier >= 4) {
                        sg_auto_succeed_armed_ = false;
                        RollResult r; r.total = 999; r.die_roll = 20;
                        r.details = "Safeguard: Auto-Succeed!";
                        return r;
                    }
                    // T2 or T1 reroll arm → grant advantage
                    if ((sg_advantage_armed_ || sg_reroll_armed_) && type == RollType::Normal) {
                        type = RollType::Advantage;
                        sg_advantage_armed_ = false;
                        sg_reroll_armed_ = false;
                    }
                }
            }
        }

        return dice.roll_d20(type, modifier, insanity_level_);
    }

    RollResult roll_attack(Dice& dice, Weapon* weapon) {
        RollType type = (has_evasion_advantage_ || advantage_until_tick_ > 0 || has_recuperation_advantage_) ? RollType::Advantage : RollType::Normal;
        has_evasion_advantage_ = false;
        if (has_recuperation_advantage_) has_recuperation_advantage_ = false;

        if (type != RollType::Disadvantage) {
            if (status_.has_condition(ConditionType::Fever) || status_.has_condition(ConditionType::Fear) || status_.has_condition(ConditionType::Blinded)) type = RollType::Disadvantage;
            if (has_injury("Weapon Arm Strain")) type = RollType::Disadvantage;
            for (const auto& inj : injuries_) {
                if (inj.name.find("Broken") != std::string::npos && (inj.limb_index == 1 || inj.limb_index == 2)) {
                    type = RollType::Disadvantage;
                }
            }

            if (weapon) {
                bool is_ranged = false;
                for (const auto& prop : weapon->get_properties()) if (prop.find("Range") != std::string::npos) { is_ranged = true; break; }
                if (is_ranged && has_injury("Vision Impaired")) type = RollType::Disadvantage;
            }
        }

        int modifier = 0;
        int stat_mod = 0;
        if (weapon) {
            bool is_speed = false;
            for (const auto& prop : weapon->get_properties()) if (prop == "Finesse" || prop.find("Range") != std::string::npos) { is_speed = true; break; }
            stat_mod = is_speed ? stats_.speed : stats_.strength;
            modifier = is_speed ? (stats_.speed + skills_.get_skill(SkillType::Nimble)) : (stats_.strength + skills_.get_skill(SkillType::Exertion));
        } else {
            stat_mod = stats_.strength;
            modifier = stats_.strength + skills_.get_skill(SkillType::Exertion);
        }

        if (has_injury("Torn Muscle") && stat_mod == stats_.strength) modifier -= 2;

        RollResult res = dice.roll_d20(type, modifier + dodge_attack_bonus_, insanity_level_);
        if (weapon && weapon->is_broken()) {
            res.is_critical_success = false;
        } else {
            // Precise Tactician expands crit range: T1=19+, T2=18+, T3=17+, T4=16+, T5=15+
            int pt_tier = get_feat_tier(FeatID::PreciseTactician);
            if (pt_tier > 0 && res.die_roll >= (21 - pt_tier)) res.is_critical_success = true;
            // Madness-Touched Human: Fractured Mind — bonus crit range from madness stacks
            if (lineage_.name == "Madness-Touched Human" && madness_crit_bonus_ > 0 &&
                res.die_roll >= (20 - madness_crit_bonus_)) res.is_critical_success = true;
        }
        return res;
    }

    RollResult roll_magic_attack(Dice& dice) {
        RollType type = (status_.has_condition(ConditionType::Fever) || status_.has_condition(ConditionType::Blinded)) ? RollType::Disadvantage : RollType::Normal;
        int surge_bonus = (arcane_surge_rounds_ > 0) ? 2 : 0;
        // MagicExpertise T2: double Divinity on magic attack rolls
        int div_bonus = (get_feat_tier(FeatID::MagicExpertise) >= 2) ? stats_.divinity * 2 : stats_.divinity;
        // BloodMagic T2: add Vitality to magic attack rolls
        int vit_bonus = (get_feat_tier(FeatID::BloodMagic) >= 2) ? stats_.vitality : 0;
        return dice.roll_d20(type, div_bonus + skills_.get_skill(SkillType::Arcane) - status_.get_exhaustion_level() + surge_bonus + vit_bonus, insanity_level_);
    }

    [[nodiscard]] int get_spell_save_dc_bonus() const {
        int bonus = 0;
        if (witchblood_active_) bonus += 2;
        if (lineage_.name == "Hexshell" && current_hp_ * 3 < get_max_hp() * 2) bonus += 2;
        return bonus;
    }

    // IllusionDeception: +1/+2/+3 to illusion DCs based on tier
    [[nodiscard]] int get_illusion_dc_bonus() const {
        return get_feat_tier(FeatID::IllusionDeception);
    }

    // HealingRestoration: add DIV × multiplier to healing rolls (T1=1x, T3=2x, T5=3x)
    [[nodiscard]] int get_healing_bonus() const {
        int hr_tier = get_feat_tier(FeatID::HealingRestoration);
        if (hr_tier >= 5) return 3 * stats_.divinity;
        if (hr_tier >= 3) return 2 * stats_.divinity;
        if (hr_tier >= 1) return stats_.divinity;
        return 0;
    }

    // HealingRestoration T3: when healing, also remove one minor condition
    [[nodiscard]] bool can_remove_condition_on_heal() const {
        return get_feat_tier(FeatID::HealingRestoration) >= 3;
    }

    // Domain feat: SP discount when casting domain spells (approximated per tier)
    [[nodiscard]] int get_domain_cast_discount(Domain d) const {
        FeatID fid;
        switch (d) {
            case Domain::Biological: fid = FeatID::BiologicalDomain; break;
            case Domain::Chemical:   fid = FeatID::ChemicalDomain;   break;
            case Domain::Physical:   fid = FeatID::PhysicalDomain;   break;
            case Domain::Spiritual:  fid = FeatID::SpiritualDomain;  break;
            default: return 0;
        }
        int tier = get_feat_tier(fid);
        if (tier >= 3) return 6;
        if (tier >= 2) return 4;
        if (tier >= 1) return 2;
        return 0;
    }

    // VoidPact T2: passive ability to see in magical darkness
    [[nodiscard]] bool has_magical_darkvision() const {
        return get_feat_tier(FeatID::VoidPact) >= 2;
    }

    // SpellShaper T1: Spell DC = 10 + 2×Divinity; base otherwise = 8 + (DIV−10)/2
    [[nodiscard]] int get_spell_save_dc() const {
        int base_dc = (get_feat_tier(FeatID::SpellShaper) >= 1)
            ? 10 + 2 * stats_.divinity
            : 8 + (stats_.divinity - 10) / 2;
        return base_dc + get_spell_save_dc_bonus();
    }

    void on_attack_evaded() {
        if (!equipped_armor_ && get_feat_tier(FeatID::UnarmoredMaster) >= 4) has_evasion_advantage_ = true;
        if (get_feat_tier(FeatID::DeflectiveStance) >= 1) dodge_attack_bonus_ += 1;
    }

    void level_up() { if (level_ < 20) { level_++; stat_points_++; feat_points_ += 4; skill_points_ += 3; reset_resources(); } }

    [[nodiscard]] bool is_proficient_in_saving_throw(StatType stat) const { return saving_throw_proficiencies_.count(stat) > 0; }
    void toggle_saving_throw_proficiency(StatType stat) { if (saving_throw_proficiencies_.count(stat)) saving_throw_proficiencies_.erase(stat); else saving_throw_proficiencies_.insert(stat); }

    [[nodiscard]] bool is_favored_skill(SkillType skill) const { return favored_skills_.count(skill) > 0; }
    bool toggle_favored_skill(SkillType skill) {
        if (favored_skills_.count(skill)) {
            favored_skills_.erase(skill);
            return true;
        }
        if (favored_skills_.size() < (size_t)stats_.intellect) {
            favored_skills_.insert(skill);
            return true;
        }
        return false;
    }
    [[nodiscard]] const std::set<SkillType>& get_favored_skills() const { return favored_skills_; }

    int current_hp_ = 0, current_ap_ = 0, current_sp_ = 0, gold_ = 0, xp_ = 0, stat_points_ = 0, feat_points_ = 0, skill_points_ = 0;
    bool has_used_free_counter_ = false;
    std::vector<Injury> injuries_;

    // Death save counters
    int death_save_passes_ = 0;
    int death_save_fails_ = 0;
    int death_save_draws_ = 0;
    bool is_stabilized_ = false;

    // Assassin's Execution Tracking
    int graze_uses_remaining_ = 0;
    bool has_ruthless_crit_available_ = true;
    int advantage_until_tick_ = 0; // Tick index or round count

    // Iron Hammer Tracking
    bool has_ignored_bludgeoning_resistance_this_turn_ = false;
    bool has_ignored_bludgeoning_immunity_this_turn_ = false;
    bool ih_speed_penalty_used_this_turn_ = false;
    int speed_penalty_ = 0;

    // Crimson Edge Tracking (per-turn)
    bool ce_ignore_resist_used_this_turn_ = false;
    bool ce_ignore_immunity_used_this_turn_ = false;
    bool ce_extra_die_used_this_turn_ = false;

    // Iron Thorn Tracking (per-turn)
    bool it_ignore_resist_used_this_turn_ = false;
    bool it_ac_reduction_used_this_turn_ = false;
    bool it_ignore_immunity_used_this_turn_ = false;

    // Iron Fist Tracking (additions)
    bool if_ignore_resist_used_this_turn_ = false;
    bool if_speed_penalty_used_this_turn_ = false;
    bool if_extra_die_used_this_turn_ = false;
    int  if_max_damage_uses_remaining_ = 0;

    // Martial Prowess Tracking
    int  mp_double_attack_uses_remaining_ = 0;
    int  mp_dodge_avoid_bonus_ = 0;
    bool mp_glancing_used_this_turn_ = false;

    // Swift Striker Tracking
    int  ss_max_damage_uses_remaining_ = 0;
    bool ss_flurry_used_this_turn_ = false;

    // Titanic Damage Tracking
    int  td_max_damage_uses_remaining_ = 0;
    bool td_ignore_disadv_used_this_turn_ = false;

    // Precise Tactician Tracking
    bool sr_pt_reroll_available_ = true;

    // Twin Fang Tracking
    int  tf_hits_this_turn_ = 0;
    bool tf_third_attack_reaction_used_ = false;

    // Turn the Blade Tracking
    int  ttb_uses_remaining_ = 0;
    bool sr_ttb_whirlwind_available_ = true;

    // Unyielding Defender Tracking
    bool lr_ud_shrug_available_ = true;
    bool lr_ud_reroll_available_ = true;

    // Improvised Weapon Mastery Tracking
    bool sr_iw_explosion_available_ = true;
    bool iw_disarm_used_this_turn_ = false;

    // Weapon Mastery Tracking
    bool wm_reroll_used_this_turn_ = false;
    bool sr_wm_auto_succeed_available_ = true;

    // Fury's Call Tracking
    int  fc_enrage_uses_remaining_ = 0;
    bool sr_fc_sacrifice_ac_available_ = true;
    bool fc_bloodied_aura_triggered_ = false;

    // Effect Shaper Tracking
    bool lr_es_force_reroll_available_ = true;
    bool lr_es_second_target_available_ = true;
    bool lr_es_condition_available_ = true;

    // Duelist's Path Tracking
    bool lr_dp_bastion_form_available_ = true;
    bool dp_bastion_form_active_ = false;
    int  dp_bastion_form_rounds_ = 0;
    bool dp_feint_used_this_round_ = false;

    // Linebreaker's Aim Tracking
    int  sr_la_shattershot_uses_ = 0;

    // Magic Expertise Tracking
    bool me_max_die_used_this_turn_ = false;   // T3: maximize one die per turn
    bool lr_me_teleport_used_ = false;         // T3: teleport 15ft after magic hit (1/LR)

    // Spell Shaper Tracking
    bool sr_ss_dc_boost_available_ = true;     // T2: 1/SR add 1d4 to Spell DC or attack
    bool lr_ss_disadv_used_ = false;           // T2: 1/LR impose disadv on creature that succeeded save
    bool lr_ss_force_fail_used_ = false;       // T3: 1/LR force all to fail first save
    bool lr_ss_chain_used_ = false;            // T3: 1/LR chain-cast half-cost spell on fail

    // Alignment Feat Tracking — Chaos Pact
    bool sr_cp_unpredictable_available_ = true; // T1: 1/rest +1d4 Speechcraft/Nimble
    bool lr_cp_sense_chaos_available_ = true;   // T1: 1/LR sense chaos within 1 mile
    bool sr_cp_reroll_save_available_ = true;   // T2: 1/rest reroll failed save
    bool sr_cp_insubstantial_available_ = true; // T2: 1/rest partially insubstantial 1 min
    bool sr_cp_summon_available_ = true;        // T3: 1/rest summon chaos entity
    bool lr_cp_miracle_available_ = true;       // T3: 1/LR chaos miracle

    // Alignment Feat Tracking — Chaos Scholar
    bool lr_cs_free_chaos_sp_available_ = true; // T2: 1/LR free effect SP for chaos spell
    bool cs_chaos_orb_active_ = false;          // T3: orb of chaos active (-1 spell cost nearby)
    bool lr_cs_upgrade_spell_available_ = true; // T3: 1/LR upgrade chaos spell

    // Alignment Feat Tracking — Unity Pact
    bool sr_up_clarity_available_ = true;       // T1: 1/rest +1d4 Speechcraft/Insight in bright light
    bool lr_up_sense_celestial_available_ = true;// T1: 1/LR sense celestial within 1 mile
    bool lr_up_dispel_blindness_available_ = true;// T2: 1/LR dispel blindness
    bool sr_up_radiant_burst_available_ = true; // T2: 1/rest radiant burst (attackers disadvantage)
    bool sr_up_summon_available_ = true;        // T3: 1/rest summon radiant guardian
    bool lr_up_miracle_available_ = true;       // T3: 1/LR unity miracle

    // Alignment Feat Tracking — Unity Scholar
    bool lr_us_free_unity_sp_available_ = true; // T2: 1/LR free effect SP for unity spell
    bool us_light_orb_active_ = false;          // T3: orb of light active (-1 spell cost nearby)
    bool lr_us_upgrade_spell_available_ = true; // T3: 1/LR upgrade unity spell

    // Alignment Feat Tracking — Void Pact
    bool sr_vp_sneak_bonus_available_ = true;   // T1: 1/rest +1d4 Sneak in darkness
    bool lr_vp_sense_void_available_ = true;    // T1: 1/LR sense void/necrotic within 1 mile
    bool sr_vp_intangible_available_ = true;    // T2: 1/rest intangible 1 round
    bool sr_vp_summon_available_ = true;        // T3: 1/rest summon shadow minion
    bool lr_vp_miracle_available_ = true;       // T3: 1/LR shadow miracle

    // Alignment Feat Tracking — Void Scholar
    bool lr_vs_free_darkness_sp_available_ = true;// T2: 1/LR free effect SP for darkness spell
    bool vs_shadow_orb_active_ = false;         // T3: orb of shadows active (-1 spell cost nearby)
    bool lr_vs_upgrade_spell_available_ = true; // T3: 1/LR upgrade darkness spell

    // Domain Feat Tracking — Biological
    int  bio_attack_bonus_pending_ = 0;         // T2: next attack gets +SP_spent bonus after bio spell
    bool lr_bio_heal_available_ = true;         // T3: 1/LR heal 3×DIV + remove minor condition

    // Domain Feat Tracking — Chemical
    bool sr_chem_solution_available_ = true;    // T1: 1/SR create basic solution
    bool sr_chem_free_spell_available_ = true;  // T2: 1/SR cast ≤4 SP chem spell for free
    bool lr_chem_reaction_available_ = true;    // T3: 1/LR controlled chemical reaction area

    // Domain Feat Tracking — Physical
    bool sr_phys_ember_available_ = true;       // T1: 1/SR fire spell -3 SP (free action ignite)
    bool lr_phys_illusion_available_ = true;    // T2: 1/LR illusion (disadv on attacks 1 min)

    // Domain Feat Tracking — Spiritual
    int  sr_spir_telepathy_uses_ = 0;           // T1: DIV/SR telepathic messages (set on SR reset)
    bool lr_spir_nullify_available_ = true;     // T2: 1/LR nullify magical effect/barrier 1 round

    // Exploration Feat Tracking — Agile Explorer
    bool lr_ae_fall_avoid_available_ = true;    // T1: 1/LR auto-succeed fall/prone check
    bool sr_ae_ignore_terrain_available_ = true;// T2: 1/rest ignore difficult terrain 1 min
    bool ae_ignore_terrain_active_ = false;     // T2: currently ignoring difficult terrain
    int  ae_ignore_terrain_rounds_ = 0;         // T2: rounds remaining
    bool sr_ae_water_walk_ally_available_ = true;// T3: 1/rest bring ally on water walk

    // Exploration Feat Tracking — Explorer's Grit
    bool lr_eg_shortcut_available_ = true;      // T1: 1/LR find safe path/shortcut
    bool lr_eg_lead_group_available_ = true;    // T3: 1/LR lead group (allies get advantage 1 hr)
    bool lr_eg_reroll_available_ = true;        // T3: 1/LR reroll failed survival/navigation

    // Exploration Feat Tracking — Healing & Restoration
    bool sr_hr_resistance_available_ = true;    // T1: 1/SR give damaged ally resistance 1 min
    bool sr_hr_miracle_available_ = true;       // T5: 1/SR powerful restoration at no SP cost

    // Exploration Feat Tracking — Illusion & Deception
    bool sr_id_illusion_available_ = true;      // T1: 1/SR fleeting illusion 1 min
    bool lr_id_group_illusion_available_ = true;// T3: 1/LR large group illusion

    // Exploration Feat Tracking — Mind Over Challenge
    int  lr_moc_keen_mind_uses_ = 0;            // T1: INT times/LR +1d4 to skill check
    bool sr_moc_reroll_available_ = true;       // T1: 1/SR reroll failed skill check
    bool sr_moc_auto_succeed_available_ = true; // T2: 1/rest auto-succeed DC ≤10 INT check
    bool lr_moc_nat20_available_ = true;        // T3: 1/LR treat failed check as nat 20

    // Exploration Feat Tracking — Minion Master
    bool lr_mm_summon_available_ = true;        // T1: 1/LR summon basic minion
    bool lr_mm_consciousness_used_ = false;     // T3: 1/LR transfer consciousness to minion

    // Exploration Feat Tracking — Stealth & Subterfuge
    bool sr_ss_speechcraft_advantage_available_ = true; // T1: 1/rest advantage on Speechcraft
    bool lr_ss_distraction_available_ = true;   // T1: 1/LR create distraction/disguise
    bool lr_ss_mimic_available_ = true;         // T2: 1/LR mimic voice/mannerisms
    bool lr_ss_auto_escape_available_ = true;   // T3: 1/LR auto-escape restraints

    // Exploration Feat Tracking — Temporal Touch
    int  lr_tt_advantage_uses_ = 0;             // T1: DIV times/LR grant adv / impose disadv
    bool lr_tt_env_change_available_ = true;    // T1: 1/LR small environmental change
    bool lr_tt_reveal_available_ = true;        // T2: 1/LR reveal hidden/invisible 1 min
    bool lr_tt_foresight_active_ = false;       // T3: +1d4 to skill checks active
    int  lr_tt_foresight_rounds_ = 0;           // T3: rounds remaining (12 rounds = 1 hr)
    bool lr_tt_hint_available_ = true;          // T3: 1/LR ask question for hint
    bool lr_tt_convergence_available_ = true;   // T4: 1/LR Chronal Convergence

    // Crafting Feat Tracking — Alchemist's Supplies
    bool lr_alch_concoction_available_ = true;   // T1: 1/LR brew basic concoction
    bool lr_alch_autosucceed_available_ = true;  // T2: 1/LR auto-succeed failed check

    // Crafting Feat Tracking — Artisan's Tools
    bool lr_art_reroll_available_ = true;        // T1: 1/LR reroll crafting check
    bool lr_art_reduce_available_ = true;        // T1: 1/LR reduce time/cost 25%
    bool lr_art_reinforce_available_ = true;     // T2: 1/LR reinforce item (temp HP)
    bool lr_art_half_craft_available_ = true;    // T3: 1/LR half time/cost

    // Crafting Feat Tracking — Calligrapher's Supplies
    bool sr_call_scroll_available_ = true;       // T1: 1/SR create advantage scroll
    bool sr_call_glyph_available_ = true;        // T2: 1/SR inscribe glyph
    bool lr_call_living_script_available_ = true;// T3: 1/LR Living Script

    // Crafting Feat Tracking — Crafting & Artifice
    bool sr_ca_temp_tool_available_ = true;      // T1: 1/SR temporary tool
    int  ca_core_sp_ = 0;                        // T3: energy core stored SP (max 3)
    bool lr_ca_absorb_available_ = true;         // T3: 1/LR absorb spell to core
    int  ca_core_damage_bonus_pending_ = 0;      // T3: pending bonus damage from core

    // Crafting Feat Tracking — Culinary Virtuoso
    bool lr_cul_ap_boost_available_ = true;      // T1: 1/LR grant bonus AP = INT
    bool lr_cul_resistance_available_ = true;    // T2: 1/LR ally env resistance
    bool lr_cul_feast_prepared_ = false;         // T3: feast active (+2 max AP allies)
    int  culinary_attack_bonus_rounds_ = 0;      // T2: dish +2 attack active (rounds)

    // Crafting Feat Tracking — Disguise Kit
    bool lr_disg_halfcost_available_ = true;     // T1: 1/LR half-time disguise
    bool enc_disg_failsafe_available_ = true;    // T2: 1/encounter avoid detection

    // Crafting Feat Tracking — Fishing Mastery
    bool day_fish_reroll_available_ = true;      // T2: 1/day reroll fishing check
    bool lr_fish_reagents_available_ = true;     // T3: 1/LR harvest magical reagents

    // Crafting Feat Tracking — Herbalism Kit
    bool lr_herb_salve_available_ = true;        // T1: 1/LR brew healing salve (1d6+DIV)
    bool lr_herb_autosucceed_available_ = true;  // T2: 1/LR auto-succeed brew check
    bool lr_herb_elixir_available_ = true;       // T3: 1/LR brew resistance elixir

    // Crafting Feat Tracking — Hunting Mastery
    bool sr_hunt_damage_available_ = true;       // T2: 1/SR +1d4 after tracking
    bool lr_hunt_quarry_active_ = false;         // T3: quarry designation active
    std::string lr_hunt_quarry_id_ = "";         // T3: quarry combatant ID
    bool lr_hunt_quarry_hit_this_round_ = false; // T3: first-hit bonus used this round
    bool lr_hunt_field_dress_available_ = true;  // T3: 1/LR ritualistic field dressing

    // Crafting Feat Tracking — Jeweler's Tools
    bool lr_jew_identify_available_ = true;      // T1: 1/LR identify gemstone
    bool lr_jew_autosucceed_available_ = true;   // T2: 1/LR auto-succeed jewelry check

    // Crafting Feat Tracking — Musical Instrument
    bool lr_music_heal_available_ = true;        // T1: 1/LR heal allies (4d4+DIV per SP)
    bool lr_music_autoperform_available_ = true; // T2: 1/LR auto-succeed perform

    // Crafting Feat Tracking — Navigator's Tools
    bool lr_nav_reroute_available_ = true;       // T1: 1/LR avoid lost / reroute

    // Crafting Feat Tracking — Painter's Supplies
    bool lr_paint_autosucceed_available_ = true; // T2: 1/LR auto-succeed art check

    // Crafting Feat Tracking — Poisoner's Kit
    bool lr_pois_poison_available_ = true;       // T1: 1/LR create basic poison
    bool lr_pois_autosucceed_available_ = true;  // T2: 1/LR auto-succeed poison check
    int  pois_weapon_rounds_ = 0;               // T1: weapon poison active (rounds)
    bool pois_weapon_disadvantage_ = false;      // T1: next hit imposes Dazed on target
    bool pois_weapon_extra_damage_ = false;      // T1: next hit adds 1d4 poison

    // Crafting Feat Tracking — Smith's Tools
    bool lr_smith_repair_available_ = true;      // T1: 1/LR repair weapon/armor
    bool lr_smith_autosucceed_available_ = true; // T2: 1/LR auto-succeed smithing

    // Crafting Feat Tracking — Thieves' Tools
    bool lr_thief_reroll_available_ = true;      // T1: 1/LR reroll Thieves' Tools check
    bool enc_thief_failsafe_available_ = true;   // T2: 1/encounter avoid trap trigger

    // Crafting Feat Tracking — Tinker's Tools
    bool lr_tink_autosucceed_available_ = true;  // T2: 1/LR auto-succeed repair check
    bool lr_tink_unique_available_ = true;       // T3: 1/LR unique item benefit

    // Crafting Feat Tracking — Weatherwise Tailoring
    bool lr_tail_endurance_available_ = true;    // T2: 1/LR ally advantage on Endurance

    // Miscellaneous Feat Tracking
    bool lr_arc_light_available_ = true;         // ArcLightSurge T1: 1/LR electric discharge
    bool lr_arcane_residue_available_ = true;    // ArcaneResidue T1: 1/LR lingering zone after 3+SP spell
    bool sr_astral_shear_available_ = true;      // AstralShear T1: 1/SR pass through walls
    bool lr_bender_available_ = true;            // Bender T1: 1/LR free spell 1-4 SP
    bool lr_blade_scripture_active_ = false;     // BladeScripture T1: weapon rune active
    bool lr_blade_scripture_available_ = true;   // BladeScripture T1: 1/LR
    bool blade_scripture_radiant_ = true;        // BladeScripture: true=radiant, false=necrotic
    bool lr_breath_of_stone_active_ = false;     // BreathOfStone T1: stance active
    bool lr_breath_of_stone_available_ = true;   // BreathOfStone T1: 1/LR
    bool lr_barkskin_active_ = false;            // BarkskinRitual T1: bark active
    bool lr_barkskin_available_ = true;          // BarkskinRitual T1: 1/LR
    bool sr_chaos_flow_available_ = true;        // ChaosFlow T1: 1/SR impose disadvantage
    int  chaos_flow_bonus_rounds_ = 0;           // ChaosFlow T1: +1d4 to next roll active
    bool lr_coinreader_available_ = true;        // CoinreadersWink T1: 1/LR
    bool lr_dreamthief_available_ = true;        // Dreamthief T1: 1/LR
    bool sr_echoed_steps_available_ = true;      // EchoedSteps T1: 1/SR free move
    bool sr_emberwake_available_ = true;         // Emberwake T1: 1/SR ember trail
    bool lr_erylons_echo_available_ = true;      // ErylonsEcho T2: 1/LR party skill boost
    bool lr_flare_defiance_available_ = true;    // FlareOfDefiance T1: 1/LR below half HP
    bool sr_flicker_sparky_available_ = true;    // FlickerSparky T1: 1/SR teleport on damage
    bool flicker_resistance_active_ = false;     // FlickerSparky: resistance until next turn
    bool sr_hollow_voice_available_ = true;      // HollowVoice T1: 1/SR mimic sound
    bool sr_hollowed_instinct_available_ = true; // HollowedInstinct T1: 1/SR negate adv
    bool sr_illusory_double_available_ = true;   // IllusoryDouble T1: 1/SR
    int  illusory_double_hp_ = 0;               // IllusoryDouble: hits remaining (3 max)
    bool lr_mirrorsteel_available_ = true;       // MirrorsteelGlint T1: 1/LR reflect spell
    bool sr_planar_graze_available_ = true;      // PlanarGraze T1: 1/SR +1d8 force + push
    bool planar_graze_pending_ = false;          // PlanarGraze: next hit applies effect
    bool sr_refraction_twist_available_ = true;  // RefractionTwist T1: 1/SR half damage
    bool lr_resonant_pulse_available_ = true;    // ResonantPulse T1: 1/LR party buff
    bool sr_rune_cipher_available_ = true;       // RuneCipher T1: 1/SR read languages
    bool lr_rune_cipher_available_ = true;       // RuneCipher T1: 1/LR auto-uncover
    bool sr_sacred_frag_available_ = true;       // SacredFragmentation T1: 1/SR half SP spell
    bool sacred_frag_pending_ = false;           // SacredFragmentation: next spell halved
    bool lr_sacrifice_available_ = true;         // FeatSacrifice T1: 1/LR HP transfer
    bool lr_skywatcher_available_ = true;        // SkywatchersSight T1: 1/LR
    bool sr_spark_leech_available_ = true;       // SparkLeech T1: 1/SR steal SP
    bool lr_split_second_available_ = true;      // SplitSecondRead T1: 1/LR
    int  split_second_ac_bonus_rounds_ = 0;     // SplitSecondRead: +1 AC active (rounds)
    bool lr_soulmark_available_ = true;          // Soulmark T1: 1/LR
    bool lr_temporal_shift_available_ = true;    // TemporalShift T1: 1/LR bless/curse
    bool lr_tether_link_available_ = true;       // TetherLink T1: 1/LR
    bool lr_veilbreaker_available_ = true;       // VeilbreakerVoice T3: 1/LR
    bool lr_verdant_pulse_available_ = true;     // VerdantPulse T1: 1/LR
    bool lr_veyras_veil_active_ = false;         // VeyrasVeil T2: advantage on Sneak/Cunning
    bool lr_veyras_veil_available_ = true;       // VeyrasVeil T2: 1/LR
    bool lr_unitys_ebb_available_ = true;        // UnitysEbb T1: 1/LR
    int  whispers_die_size_ = 6;                // Whispers: current die size (4/6/8/10/12)
    bool lr_whispers_available_ = true;          // Whispers T1: 1/LR die bonus
    bool lr_whispers_consumed_ = false;          // Whispers: consumed when 4 rolled on d4

    // Blood Magic Tracking
    bool sr_bm_reroll_available_ = true;       // T1: 1/SR reroll any dice on a blood magic cast
    bool lr_bm_immunity_used_ = false;         // T2: 1/LR damage immunity until end of next turn
    int  bm_reservoir_sp_ = 0;                 // T3: stored SP from HP sacrifice (max = VIT)
    bool sr_bm_reservoir_save_available_ = true; // T3: 1/SR spend 1 reservoir SP for auto VIT save
    bool lr_bm_kill_sp_regain_used_ = false;   // T4: 1/LR regain DIV SP on kill with blood magic spell
    bool lr_bm_double_dice_used_ = false;      // T5: 1/LR double dice (pay full cost in HP)

    // Grasp of the Titan Tracking
    bool has_iron_grip_prone_available_ = true;

    // Rest & Recovery Tracking
    bool sr_rest_free_available_ = true;
    bool sr_efficient_recuperation_available_ = true;
    bool lr_tireless_spirit_available_ = true;
    bool lr_unyielding_vitality_available_ = true;
    bool has_recuperation_advantage_ = false;

    // Lineage Trait Availability
    bool sr_bouncian_escape_available_ = true;
    bool sr_ironhide_mind_available_ = true;
    bool sr_verdant_regrowth_available_ = true;
    bool lr_ironhide_plating_available_ = true;
    bool lr_goldscale_sun_favor_available_ = true;
    bool lr_vulpin_echo_available_ = true;
    bool lr_verdant_natures_voice_available_ = true;
    bool has_fire_resistance_ = false;   // Goldscale Sun's Favor passive
    int  felinar_nine_lives_remaining_ = 9;
    bool sr_fae_enchanting_available_ = true;
    int  speechcraft_bonus_rounds_ = 0;  // Fae-Touched shimmer (+1d4 Speechcraft)
    bool lr_myconid_spore_available_ = true;
    bool sr_myconid_fortitude_available_ = true;
    bool has_poison_resistance_ = false; // Myconid / Thornwrought Human
    bool has_physical_resistance_ = false; // Lithari Rooted Form

    // Eternal Library lineage flags
    int  sr_paper_ward_uses_ = 0;
    int  bookborn_origami_rounds_ = 0;
    bool bookborn_origami_active_ = false;
    bool sr_archivist_recall_available_ = true;
    bool panoplian_sentinel_stand_active_ = false;

    // House of Arachana lineage flags
    bool lr_toxic_roots_available_ = true;
    bool lr_witherborn_decay_available_ = true;
    int  witherborn_decay_rounds_ = 0;     // > 0: poison resistance active + +1d4 poison on melee
    bool sr_silken_trap_available_ = true;
    bool sr_lurker_step_available_ = true;
    bool lr_serpentine_venom_weapon_available_ = true;
    int  serpentine_venom_weapon_rounds_ = 0; // > 0: weapon adds +1d4 poison + Poisoned save

    // Wilds of Endero lineage flags
    int  sr_beetlefolk_deflect_uses_ = 0;
    bool lr_pack_howl_available_ = true;
    bool loyal_strike_reaction_available_ = true;
    bool lr_natures_grace_available_ = true;
    bool has_secondary_arms_attack_available_ = true;
    bool tetrasimian_sneak_advantage_ = false;
    bool lr_verdant_curse_available_ = true;

    // Qunorum lineage flags
    bool grimshell_tomb_core_used_ = false;
    bool lr_kindle_flame_available_ = true;
    bool kindle_flame_active_ = false;
    bool lr_alchemical_affinity_available_ = true;
    bool pending_alchemical_affinity_ = false;
    int  kindlekin_hit_count_ = 0;
    int  kindlekin_death_dice_count_ = 0;  // Dice count remaining for post-death Combustive Touch decay
    int  sr_resilient_spirit_uses_ = 2;
    int  lr_versatile_grant_remaining_ = 0;
    bool lr_quill_launch_available_ = true;
    bool sr_quick_reflexes_available_ = true;

    // Metropolitan lineage flags
    bool lr_arcane_surge_available_ = true;
    int  arcane_surge_rounds_ = 0;      // > 0: +2 spell attack active
    bool sr_groblodyte_scrap_available_ = true;
    bool lr_steam_jet_available_ = true;
    bool lr_tether_step_available_ = true;
    int  sr_resonant_voice_uses_ = 0;   // INT/SR uses remaining
    bool lr_market_whisperer_available_ = true;
    bool has_cold_resistance_ = false;  // Kettlekyn Heat Engine

    // Upper Forty lineage flags
    bool lr_arcane_tinker_available_ = true;
    int  sr_gremlins_luck_uses_ = 2;
    bool lr_hex_mark_available_ = true;
    int  hex_mark_rounds_ = 0;
    bool sr_witchblood_available_ = true;
    bool witchblood_active_ = false;    // +2 spell DC for 1 round
    bool lr_commanding_voice_available_ = true;

    // Shadows Beneath lineage flags
    bool lr_quack_alarm_available_ = true;
    bool lr_sable_night_vision_available_ = true;
    bool sr_veilstep_available_ = true;
    bool sr_duskborn_grace_available_ = true;

    // Corrupted Marshes lineage flags
    bool lr_mossy_shroud_available_ = true;
    bool sr_mire_burst_available_ = true;
    bool lr_soothing_aura_available_ = true;
    bool lr_dreamscent_available_ = true;

    // Crypt at the End of the Valley lineage flags
    bool lr_gnawing_grin_available_ = true;
    bool lr_diseaseborn_curse_available_ = true;

    // Spindle York's Schism lineage flags
    int  sr_stones_endurance_uses_ = 0;      // VIT/SR uses
    bool shardkin_crystal_resilience_active_ = false; // -3 max AP, Sneak advantage
    bool lr_harmonic_link_available_ = true;

    // Lower Forty lineage flags
    bool sr_overdrive_core_available_ = true;
    bool has_slashing_resistance_ = false; // Ferrusk Scrap Resilience
    bool ferrusk_scrap_ac_used_ = false;   // +1 AC on first slashing hit per turn
    bool lr_gremlin_tinker_available_ = true;
    bool sr_gremlin_sabotage_available_ = true;
    bool lr_reflect_hex_available_ = true;
    bool reflect_hex_primed_ = false;   // Hexshell: next spell condition reflected
    bool sr_scrap_sense_available_ = true;
    bool sr_iron_stomach_available_ = true;

    // Peaks of Isolation lineage flags
    bool lr_deathless_endurance_available_ = true;  // Tombwalker: drop to 1 HP instead of 0 (1/LR)
    bool sr_frost_burst_available_ = true;           // Frostborn: 1/SR reaction cold burst
    bool sr_frostborn_icewalk_available_ = true;     // Frostborn: 1/SR +2d4 cold to attacks
    bool frostborn_icewalk_active_ = false;
    int  frostborn_icewalk_rounds_ = 0;
    bool lr_frozen_veil_available_ = true;           // Glaceari: 1/LR Dodging aura
    int  frozen_veil_rounds_ = 0;
    bool sr_gravitational_leap_available_ = true;    // Gravemantle: 1/SR double speed + fly
    int  gravitational_leap_rounds_ = 0;

    // Pharaoh's Den lineage flags
    bool has_necrotic_resistance_ = false;           // Jackal Human: Tomb Sense passive
    bool lr_tomb_sense_available_ = true;
    bool lr_rotborn_item_available_ = true;          // Chokeling: 1/LR corrode gear
    bool sr_mindscratch_available_ = true;           // Whisperspawn: 1/SR psychic scratch

    // The Darkness lineage flags
    bool lr_creeping_dark_available_ = true;
    bool creeping_dark_active_ = false;
    int  creeping_dark_rounds_ = 0;

    // Arcane Collapse lineage flags
    bool sr_absorb_magic_available_ = true;          // Blightmire: 1/SR reaction absorb spell
    bool sr_dregspawn_extend_available_ = true;      // Dregspawn: 1/SR reach extension
    bool sr_aberrant_flex_available_ = true;         // Dregspawn: 1/SR escape grapple/restrained
    bool lr_void_aura_available_ = true;             // Nullborn: 1/LR or 6SP anti-magic aura
    int  void_aura_rounds_ = 0;
    bool sr_crystal_slash_available_ = true;         // Shardwraith: 1/SR force AoE

    // Argent Hall lineage flags
    bool argent_silent_ledger_active_ = false;       // Argent Dvarrim: silence aura toggle (-3 max AP)
    bool glacial_wall_active_ = false;               // Frostbound Dvarrim: ice wall toggle (-3 max AP, +3 AC)
    bool unyielding_bulwark_active_ = false;         // Frostbound Dvarrim: all damage resistance
    int  unyielding_bulwark_rounds_ = 0;
    bool stonemind_architects_shield_active_ = false; // Stonemind Dvarrim: +2 AC toggle (-3 max AP)

    // Telekinesis sustained spell state
    bool tk_animate_weapon_active_    = false;  // Animate Weapon: auto-attack at turn start
    int  tk_animate_weapon_sp_committed_ = 0;  // 2 SP per attack/15 ft move tier
    int  tk_animated_shield_ac_bonus_ = 0;     // AC bonus from animated shield (0 = none)
    bool sr_miners_instinct_available_ = true;       // Glaciervein Dvarrim: 1/SR Perception advantage
    bool miners_instinct_active_ = false;            // Glaciervein Dvarrim: tremorsense toggle (-3 max AP)

    // Glass Passage lineage flags
    bool lr_wind_step_available_ = true;             // Galesworn Human: Wind Cloak 1/LR
    int  wind_cloak_rounds_ = 0;                     // Galesworn Human: Wind Cloak duration
    int  lr_pangol_armor_reaction_uses_ = 0;         // Pangol: natural armor reactions (= Speed uses per LR)
    bool pangol_armor_react_active_ = false;         // Pangol: +5 AC reaction active this turn
    bool sr_curl_up_available_ = true;               // Pangol: Curl Up 1/SR
    bool curl_up_active_ = false;                    // Pangol: curled up (speed 0)
    bool sr_gilded_bearing_available_ = true;        // Porcelari: Gilded Bearing 1/SR
    bool sr_chromatic_shift_available_ = true;       // Prismari: Chromatic Shift 1/SR
    int  chromatic_shift_rounds_ = 0;                // Prismari: Chromatic Shift duration
    bool lr_prismatic_reflection_available_ = true;  // Prismari: Prismatic Reflection 1/LR
    int  prismatic_reflection_rounds_ = 0;           // Prismari: Prismatic Reflection duration
    bool has_acid_resistance_ = false;               // Rustspawn: acid resistance
    int  ironrot_acid_stacks_ = 0;                   // Rustspawn: Ironrot accumulation

    // Sacral Separation lineage flags
    bool lr_dust_shroud_available_ = true;           // Dustborn: Dust Shroud 1/LR
    int  dust_shroud_rounds_ = 0;                    // Dustborn: Dust Shroud duration
    bool lr_shatter_pulse_glassborn_available_ = true; // Glassborn: Shatter Pulse 1/LR
    bool sr_prism_veins_available_ = true;           // Glassborn: Prism Veins 1/SR
    bool lr_deaths_whisper_available_ = true;        // Gravetouched: Death's Whisper 1/LR
    bool has_psychic_resistance_ = false;            // Madness-Touched Human: psychic resistance
    int  madness_crit_bonus_ = 0;                    // Madness-Touched Human: expanded crit range
    int  unstable_mutation_disadvantage_remaining_ = 0; // Madness-Touched Human: pending disadvantage checks
    bool has_radiant_resistance_ = false;            // Glassborn / Obsidian Seraph: radiant resistance

    // Infernal Machine lineage flags
    bool candlite_flame_lit_ = true;                 // Candlites: flame currently lit
    bool lr_pain_made_flesh_available_ = true;       // Flenskin: Pain Made Flesh 1/LR
    bool pain_made_flesh_active_ = false;            // Flenskin: invulnerability active
    int  pain_made_flesh_rounds_ = 0;                // Flenskin: Pain Made Flesh duration
    bool lr_infernal_stare_available_ = true;        // Hellforged: Infernal Stare 1/LR
    int  infernal_stare_rounds_ = 0;                 // Hellforged: Infernal Stare duration
    bool sr_infernal_smite_available_ = true;        // Hellforged: Infernal Smite 1/SR
    int  infernal_smite_rounds_ = 0;                 // Hellforged: Infernal Smite buff duration
    int  cracked_resilience_stacks_ = 0;             // Obsidian Seraph: bonus damage stacks

    // Titan's Lament lineage flags
    bool sr_cursed_spark_available_ = true;          // Ashenborn: Cursed Spark 1/SR
    int  cursed_spark_rounds_ = 0;                   // Ashenborn: fire bonus duration
    bool lr_burnt_offering_available_ = true;        // Ashenborn: Burnt Offering 1/LR
    bool lr_desert_walker_available_ = true;         // Sandstrider Human: Desert Walker 1/LR
    int  desert_walker_rounds_ = 0;                  // Sandstrider Human: sand cloud duration
    int  sr_gore_uses_ = 0;                          // Taurin: Gore uses per SR (= VIT)
    bool sr_stubborn_will_available_ = true;         // Taurin: Stubborn Will 1/SR
    bool lr_hibernate_available_ = true;             // Ursari: Hibernate 1/LR

    // The Mortal Arena lineage flags
    bool sr_blazeblood_available_ = true;            // Emberkin: Blazeblood 1/SR
    int  blazeblood_rounds_ = 0;                     // Emberkin: fire bonus duration
    bool lr_soot_sight_available_ = true;            // Emberkin: Soot Sight 1/LR
    int  soot_sight_rounds_ = 0;                     // Emberkin: smoke cloud duration
    bool sr_scaled_resilience_available_ = true;     // Saurian: Scaled Resilience 1/SR reaction
    bool has_lightning_resistance_ = false;          // Stormclad, Obsidian
    bool has_thunder_resistance_ = false;            // Stormclad, Obsidian
    int  sunderborn_death_denied_sp_cost_ = 1;       // Sunderborn: Death Denied cumulative SP cost
    bool sunderborn_frenzy_available_ = false;       // Sunderborn: Blood Frenzy free attack after kill
    bool lr_sunderborn_hibernate_available_ = true;  // Sunderborn: lifeforce hibernation 1/LR

    // Vulcan Valley lineage flags
    bool ashrot_aura_active_ = false;                // Ashrot Human: smoldering aura toggle
    bool lr_smoldering_glare_available_ = true;      // Cindervolk: Smoldering Glare 1/LR
    int  smoldering_glare_rounds_ = 0;               // Cindervolk: glare duration
    bool lr_draconic_awakening_available_ = true;    // Drakari: Draconic Awakening 1/LR (or 4 SP)
    bool draconic_form_active_ = false;              // Drakari: dragon form state
    int  draconic_form_rounds_ = 0;                  // Drakari: dragon form duration
    std::string draconic_element_ = "Fire";          // Drakari: chosen element
    bool sr_fracture_burst_available_ = true;        // Scornshard: Fracture Burst 1/SR reaction
    bool crackling_edge_used_ = false;               // Scornshard: Speed bonus used this turn

    // The Isles lineage flags
    bool abyssari_glow_active_ = false;              // Abyssari: bioluminescence toggle
    bool lr_abyssari_pulse_available_ = true;        // Abyssari: 1/LR pulse
    bool lr_mireling_escape_available_ = true;       // Mireling: 1/LR escape grapple
    bool lr_lunar_radiance_available_ = true;        // Moonkin: 1/LR radiance buff
    int  lunar_radiance_rounds_ = 0;                 // Moonkin: radiance duration
    bool has_cold_immunity_ = false;                 // Tiderunner Human: full cold immunity
    int  lr_ebb_flow_uses_ = 0;                      // Fathomari: Ebb and Flow uses per LR (= speed)

    // The Depths of Denorim lineage flags
    bool sr_hydras_resilience_available_ = true;     // Hydrakari: 1/SR reduce incoming damage
    bool lr_hydra_limb_sacrifice_available_ = true;  // Hydrakari: 1/LR limb sacrifice regen
    bool sr_abyssal_mutation_available_ = true;      // Trenchborn: 1/SR random buff

    // Moroboros lineage flags
    bool cloudling_fly_active_ = false;              // Cloudling: flight mode toggle (-3 max AP)
    bool sr_mist_form_available_ = true;             // Cloudling: 1/SR mist form (Intangible)
    bool mist_form_used_once_ = false;               // Cloudling: free SR use consumed
    int  mist_form_rounds_ = 0;                      // Cloudling: mist form duration
    bool surge_step_active_ = false;                 // Tidewoven: doubled speed this turn
    bool lr_hunters_focus_available_ = true;         // Venari: 1/LR Hunter's Focus
    bool hunters_focus_active_ = false;              // Venari: actively tracking target
    int  hunters_focus_target_id_ = -1;              // Venari: focused target id
    bool lr_weird_resilience_available_ = true;      // Weirkin Human: 1/LR condition reflection
    bool weird_resilience_primed_ = false;           // Weirkin Human: next condition reflected

    // Gloamfen Hollow lineage flags
    bool lr_voluntary_gas_vent_available_ = true;    // Huskdrone: 1/LR gas vent
    bool obedient_aura_active_ = false;              // Bloatfen Whisperer: obedient aura toggle (-3 max AP)
    bool memory_echo_active_ = false;                // Hagborn Crone: memory echo toggle (-3 max AP)
    bool leech_hex_used_this_turn_ = false;          // Hagborn Crone: Leech Hex used this turn
    int  leech_hex_last_target_id_ = -1;             // Hagborn Crone: last leech hex target

    // The Astral Tear lineage flags
    bool lr_veiled_presence_available_ = true;       // Aetherian: 1/LR Sneak advantage (12 rounds)
    int  veiled_presence_rounds_ = 0;                // Aetherian: veiled presence duration
    bool convergent_synthesis_active_ = false;       // Convergents: synthesis active
    int  convergent_synthesis_rounds_ = 0;           // Convergents: synthesis duration
    bool lr_dreamwalk_available_ = true;             // Dreamer: 1/LR dreamwalk
    bool sr_flicker_available_ = true;               // Riftborn Human: 1/SR teleport burst
    bool lr_shadowmeld_available_ = true;            // Shadewretch: 1/LR intangible reaction

    // L.I.T.O. lineage flags
    int  lr_dark_lineage_uses_ = 0;                  // Corrupted Wyrmblood: death pulse uses (= DIV per LR)
    bool sr_sap_healing_available_ = true;           // Hollowroot: 1/SR heal + remove condition
    bool lr_unravel_available_ = true;               // Nihilian: 1/LR unravel debuff
    bool lr_mind_bleed_available_ = true;            // Oblivari Human: 1/LR psychic mind bleed
    bool lr_null_mind_share_available_ = true;       // Oblivari Human: 1/LR extend null mind
    bool lr_amorphous_split_available_ = true;       // Sludgeling: 1/LR split on slashing damage
    int  toxic_seep_rounds_ = 0;                     // Sludgeling: toxic seep aura duration

    // The West End Gullet lineage flags
    bool lr_death_eater_memory_available_ = true;    // Carrionari: 1/LR memory absorption
    int  carrionari_flight_rounds_ = 0;              // Carrionari: flight duration (1 round)
    bool disjointed_beast_form_active_ = false;      // Disjointed Hounds: beast form toggle
    bool shapeshift_beast_form_active_ = false;     // ShapeshiftersPath feat: beast form active
    bool sr_disjointed_leap_available_ = true;       // Disjointed Hounds: 1/SR leap 40 ft
    bool lr_temporal_flicker_available_ = true;      // Lost: 1/LR intangible (12 rounds)
    int  temporal_flicker_rounds_ = 0;               // Lost: intangible duration
    bool lr_silent_scream_available_ = true;         // Gullet Mimes: 1/LR silent scream
    bool sr_reality_slip_available_ = true;          // Parallax Watchers: 1/SR shadow teleport

    // The Cradling Depths lineage flags
    bool sr_resonant_form_available_ = true;         // Echo-Touched: 1/SR spell effect mimic
    bool lr_divine_mimicry_available_ = true;        // Echo-Touched: 1/LR lineage trait mimic
    int  vital_surge_pool_ = 0;                      // Lifeborne: healing pool (4 × level)
    bool lr_abyssal_glow_available_ = true;          // Lifeborne: 1/LR radiant healing glow

    // Terminus Volarus lineage flags
    bool lanternborn_glow_active_ = false;           // Lanternborn: Glow toggle
    bool sr_beacon_available_ = true;                // Luminar Human: Beacon absorption 1/SR
    int  beacon_resistance_rounds_ = 0;              // Luminar Human: all-damage resistance after Beacon

    // The City of Eternal Light lineage flags
    bool sr_light_step_available_ = true;            // Auroran: Light Step teleport 1/SR
    bool lr_dawns_blessing_available_ = true;        // Auroran: Dawn's Blessing blind immunity 1/LR
    int  dawns_blessing_rounds_ = 0;                 // Auroran: blind immunity duration
    bool sr_radiant_ward_available_ = true;          // Lightbound: Radiant Ward 1/SR
    int  radiant_ward_rounds_ = 0;                   // Lightbound: radiant resistance duration
    bool sr_flareburst_available_ = true;            // Lightbound: Flareburst 1/SR
    bool flareburst_primed_ = false;                 // Lightbound: primed for next melee hit
    bool lr_runic_surge_available_ = true;           // Runeborn Human: Runic Surge 1/LR
    bool runic_surge_primed_ = false;                // Runeborn Human: primed for next spell
    bool sr_mystic_pulse_available_ = true;          // Runeborn Human: Mystic Pulse 1/SR
    int  sr_windstep_uses_ = 0;                      // Zephyrkin: Windstep uses (SPD/SR)

    // The Hallowed Sacrament lineage flags
    bool glimmerfolk_glow_active_ = false;           // Glimmerfolk: Luminous glow toggle
    bool lr_drifting_fog_available_ = true;          // Mistborn Human: Drifting Fog 1/LR
    int  drifting_fog_rounds_ = 0;                   // Mistborn Human: fog duration
    bool lr_spore_bloom_available_ = true;           // Mossling: Spore Bloom 1/LR
    bool windswift_active_ = false;                  // Zephyrite: Windswift hover active
    int  windswift_rounds_ = 0;                      // Zephyrite: hover duration

    // The Land of Tomorrow lineage flags
    bool sr_temporal_shift_available_ = true;        // Chronogears: Temporal Shift 1/SR
    bool temporal_shift_primed_ = false;             // Chronogears: primed to halve next hit
    bool lr_arcane_pulse_available_ = true;          // Silverblood: Arcane Pulse 1/LR
    bool lr_runic_flow_auto_available_ = true;       // Silverblood: Runic Flow auto-succeed 1/LR
    bool runic_flow_auto_primed_ = false;            // Silverblood: auto-succeed next Arcane check
    bool lr_sparkforged_arcane_surge_available_ = true; // Sparkforged Human: Arcane Surge 1/LR
    bool sparkforged_arcane_surge_primed_ = false;   // Sparkforged Human: primed for next spell
    bool static_surge_active_ = false;               // Watchling: Static Surge active (0 AP all actions)
    int  static_surge_action_count_ = 0;             // Watchling: actions taken during surge
    int  static_surge_daze_rounds_ = 0;              // Watchling: Daze rounds pending from surge

    // Sublimini Dominus lineage flags
    bool void_cloak_active_ = false;                 // Nullborn Ascetic: Void Cloak toggle (-3 max AP)
    bool warp_resistance_active_ = false;            // Mistborne Hatchling: Warp Resistance toggle (-3 max AP)

    // Beating Heart of The Void lineage flags
    bool anti_magic_cone_active_ = false;            // Bespoker: Anti-Magic Cone toggle (-3 max AP)
    std::string bespoker_last_ray_name_ = "";        // Bespoker: last ray used (can't repeat consecutively)
    bool resonant_sermon_active_ = false;            // Pulsebound Hierophant: Resonant Sermon toggle (-3 max AP)
    bool lr_void_communion_available_ = true;        // Pulsebound Hierophant: Void Communion 1/LR

    // ===== STAT FEAT FLAGS =====
    // ArcaneWellspring secondary effects
    bool aw_deep_reserves_lr_available_ = true;      // T1: once/LR reduce next spell SP cost by Divinity
    bool aw_deep_reserves_armed_ = false;            // T1: armed — next spell SP cost reduced
    bool aw_spell_echo_enc_available_ = true;        // T3: once/enc echo last spell at start of next turn
    bool aw_spell_echo_armed_ = false;               // T3: armed — next spell will be echoed
    std::string aw_spell_echo_spell_name_ = "";      // T3: spell name queued for echo
    bool aw_sp_restore_lr_available_ = true;         // T3 secondary: once/LR regain Divinity SP
    bool aw_infinite_font_lr_available_ = true;      // T5: once/LR — next spell after this one is free SP
    bool aw_infinite_font_armed_ = false;            // T5: armed — next spell costs 0 SP
    int  aw_last_spell_cost_ = 0;                    // T5: SP cost of the spell that armed infinite font
    // IronVitality secondary effects
    bool iv_resilient_frame_triggered_ = false;      // T1: once/enc, HP ≤ half triggers Vit HP bonus
    bool iv_enduring_spirit_lr_available_ = true;    // T3 secondary: once/LR heal = level after ST success
    bool iv_titanic_endurance_lr_available_ = true;  // T5: once/LR drop to 1 HP instead of 0
    // MartialFocus secondary effects
    bool mf_battle_ready_enc_available_ = true;      // T1/T3: once/enc, reduce next action AP cost by 1
    bool mf_battle_ready_armed_ = false;             // T1/T3: armed — next action costs 1 less AP
    bool mf_unstoppable_assault_used_rnd_ = false;   // T5: once/round free 5ft on attack
    // Safeguard chosen stats and secondary flags
    std::set<int> safeguard_chosen_stats_;           // stat indices chosen (0=STR,1=SPD,2=INT,3=VIT,4=DIV)
    bool sg_reroll_lr_available_ = true;             // T1 secondary: once/LR, arm reroll for next ST
    bool sg_reroll_armed_ = false;                   // T1: armed — next ST gets advantage (reroll)
    bool sg_advantage_sr_available_ = true;          // T2 secondary: once/SR, arm advantage for next ST
    bool sg_advantage_armed_ = false;                // T2: armed — next ST gets advantage
    bool sg_auto_succeed_lr_available_ = true;       // T4 secondary: once/LR, arm auto-succeed next ST
    bool sg_auto_succeed_armed_ = false;             // T4: armed — next ST auto-succeeds
    bool sg_heal_sr_available_ = true;               // T5 secondary: once/SR heal after succeeding on ST

    int pending_damage_reduction_ = 0;
    std::string pending_absorb_item_ = "";

    // ===== ASCENDANT FEAT TRACKING =====

    // PsychicMaw
    int  psychic_maw_phase_shift_rounds_ = 0;    // Phase Shift: intangible rounds remaining

    // AbyssalUnleashing
    bool abyssal_true_name_used_today_ = false;  // 1/day true name SP discount

    // AngelicRebirth
    bool angelic_flight_active_ = false;         // Flight: -1 max AP while active
    bool angelic_safeguard_active_ = false;      // Safeguard Aura: -3 max AP while active
    int  angelic_safeguard_rounds_ = 0;          // number of rounds remaining (sustained)

    // CryptbornSovereign
    bool cryptborn_regen_active_ = false;        // passive 1d6 HP/turn at start of turn
    std::string cryptborn_blight_target_id_ = ""; // no-heal target
    int  cryptborn_blight_rounds_ = 0;           // rounds no-heal lasts

    // DraconicApotheosis
    bool draconic_apo_flight_active_ = false;    // Flight: -1 max AP while active
    bool draconic_apo_scales_active_ = false;    // Scales: +2 AC, elemental resistance
    std::string draconic_apo_element_ = "fire";  // chosen element for scales and breath

    // FeyLordsPact
    bool fey_reality_distort_active_ = false;    // Reality Distort: -3 max AP while active
    bool fey_disguise_active_ = false;           // Disguise Flesh active

    // HagMothersCovenant
    bool hag_nightmare_brood_active_ = false;    // Nightmare Brood: -3 max AP while active
    int  hag_dreamspawn_count_ = 0;              // 0-3 dreamspawn alive
    bool hag_soulroot_active_ = false;           // Soulroot Effigy active (1 SP/day maintain)

    // InfernalCoronation
    bool infernal_second_chance_available_ = true; // 1/LR death prevention
    int  infernal_flame_flicker_hp_sacrificed_ = 0; // HP sacrificed for next hit
    bool infernal_flame_flicker_primed_ = false; // armed: next hit deals HPd4 fire

    // KaijuCoreIntegration
    bool kaiju_titanic_applied_ = false;         // permanent stat boost applied

    // LycanthropicCurse
    bool lycanthrope_hybrid_active_ = false;     // Hybrid Form active
    int  lycanthrope_regen_turns_ = 0;           // regen countdown (always on = set each turn)
    int  lycanthrope_blood_howl_rounds_ = 0;     // ally +1d4 damage bonus rounds

    // LichBinding
    bool lich_phylactery_intact_ = false;        // reform on death if true

    // PrimordialElementalFusion
    int  elemental_shifting_hide_stacks_ = 0;    // number of active resistance stacks (-2 AP each)

    // SeraphicFlame
    int  seraphic_flame_flicker_ap_cost_ = 0;   // AP invested in Flame Flicker
    bool seraphic_reflective_veil_available_ = true; // 1/LR
    int  seraphic_reflective_veil_rounds_ = 0;
    bool seraphic_heal_lr_available_ = true;     // 1/LR Healing & Restoration

    // StormboundTitan
    int  stormbound_grow_ap_cost_ = 0;          // AP reduced for Grow (size increase)

    // VampiricAscension
    bool vampire_flight_intangible_active_ = false; // Flight+Intangible: -3 max AP while active
    bool vampire_staked_ = false;               // staked: cannot regen
    int  vampire_regen_timer_ = 0;             // turns until revival (0 = eligible)

    // VoidbornMutation
    int  voidborn_phase_shift_rounds_ = 0;      // Phase Shift: intangible rounds
    bool voidborn_reality_distort_active_ = false; // Reality Distort: -3 max AP
    bool voidborn_immortal_mask_available_ = true; // 1/LR

    // Apex Feat Tracking
    bool lr_arcane_overdrive_available_ = true;
    bool arcane_overdrive_active_ = false;
    int  arcane_overdrive_rounds_ = 0;
    bool lr_boa_available_ = true;           // BloodOfTheAncients
    bool boa_active_ = false;
    int  boa_rounds_ = 0;
    bool boa_damage_ignored_this_round_ = false;
    bool lr_cataclysmic_leap_available_ = true;
    bool lr_divine_reversal_available_ = true;
    bool lr_eclipse_veil_available_ = true;
    bool eclipse_veil_active_ = false;
    int  eclipse_veil_rounds_ = 0;
    bool lr_gravity_shatter_available_ = true;
    bool lr_howl_available_ = true;
    bool lr_iron_tempest_available_ = true;
    bool lr_mythic_regrowth_available_ = true;
    int  mythic_regrowth_regen_turns_ = 0;
    bool lr_phantom_legion_available_ = true;
    bool phantom_legion_active_ = false;
    int  phantom_legion_clones_ = 0;
    bool lr_runebreaker_available_ = true;
    int  runebreaker_active_rounds_ = 0;
    std::string soulbrand_target_id_ = "";
    bool soulbrand_used_this_round_ = false;
    bool lr_soulflare_available_ = true;
    bool lr_stormbound_available_ = true;
    int  stormbound_mantle_rounds_ = 0;
    bool lr_temporal_rift_available_ = true;
    bool temporal_rift_active_ = false;
    bool lr_titans_echo_available_ = true;
    bool lr_voidbrand_available_ = true;
    std::string voidbrand_target_id_ = "";
    int  voidbrand_rounds_ = 0;
    bool voidbrand_primed_ = false;          // armed — next melee hit brands target
    int  worldbreaker_step_movement_this_turn_ = 0; // tiles moved this turn (5ft each)

private:
    std::string name_, unique_id_;
    Lineage lineage_;
    int level_, age_, insanity_level_ = 0;
    Alignment alignment_ = Alignment::Unity;
    Domain domain_affinity_ = Domain::Physical;
    std::string current_region_;
    std::map<std::string, int> faction_reputation_;
    Stats stats_; Skills skills_; StatusManager status_;
    std::vector<Feat> feats_;
    std::vector<SocietalRole> societal_roles_;
    std::set<std::string> learned_spells_;
    std::set<StatType> saving_throw_proficiencies_;
    std::set<SkillType> favored_skills_;
    Inventory inventory_;
    std::unique_ptr<Weapon> equipped_weapon_;
    std::unique_ptr<Armor> equipped_armor_, equipped_shield_;
    std::string equipped_light_source_;
    int temporary_ac_bonus_ = 0, dodge_ac_bonus_ = 0, dodge_attack_bonus_ = 0, unarmored_flow_uses_ = 0;
    bool has_evasion_advantage_ = false;
};

} // namespace rimvale

#endif // RIMVALE_CHARACTER_H
