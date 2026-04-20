#ifndef RIMVALE_COMBAT_MANAGER_H
#define RIMVALE_COMBAT_MANAGER_H

#include "Character.h"
#include "Creature.h"
#include "Dice.h"
#include "Behavior.h"
#include "SpellRegistry.h"
#include <vector>
#include <algorithm>
#include <memory>
#include <map>
#include <string>
#include <random>

namespace rimvale {

enum class ActionType {
    MeleeAttack = 0,
    Dodge = 1,
    Free = 2,
    Rest = 3,
    Reaction_Basic = 4,
    Reaction_Opportunity = 5,
    Reaction_Move = 6,
    Reaction_Defense = 7,
    Reaction_Parry = 8,
    UseItem = 9,
    CastSpell = 10,
    Move = 11,
    RangedAttack = 12,
    UnarmedAttack = 13,
    Interact = 14,
    Reload = 15,
    ActivateSustainedSpell = 16,
    EndSustainedSpell = 17,
    Grapple = 18,
    EscapeGrapple = 19,
    Hide = 20,
    EfficientRecuperation = 21,
    ExtraMove = 22,  // Spend 1 AP to gain a second full movement this turn
    ThrowItem = 23,  // Throw an item at a target for 1d4 bludgeoning damage
    LineageTrait = 50  // Lineage-specific active ability; extra_param = trait name
};

enum class CombatPhase {
    Player,
    Enemy
};

struct SpellMatrix {
    std::string spell_name;
    int duration_rounds; // 0 for instant, -1 for permanent/concentration
    std::string bound_item_name; // Arcane focus
    bool used_free_activation_this_turn;
    bool suppressed;
    std::vector<std::string> affected_entities; // Entities currently under one instance of this spell's effect
};

struct Combatant {
    std::string id;
    std::string name;
    int initiative;
    bool is_player;
    Character* player_ptr = nullptr;
    Creature* creature_ptr = nullptr;

    std::map<ActionType, int> actions_taken_this_round;
    int movement_tiles_remaining = 0;
    bool has_acted = false;
    bool has_used_extra_movement = false; // true after spending 1 AP on an extra move action
    int total_attacks_this_round = 0;

    bool is_friendly_summon = false; // creature acting as player ally (summon/raised undead)

    std::vector<SpellMatrix> active_matrices;

    std::vector<std::string> grappling_ids;
    std::string grappled_by_id;

    [[nodiscard]] int get_current_ap() const {
        if (is_player && player_ptr) return player_ptr->current_hp_ > 0 ? player_ptr->current_ap_ : 0;
        if (creature_ptr) return creature_ptr->get_current_ap();
        return 0;
    }

    [[nodiscard]] int get_max_ap() const {
        if (is_player && player_ptr) return player_ptr->get_max_ap();
        if (creature_ptr) return creature_ptr->get_max_ap();
        return 0;
    }

    [[nodiscard]] int get_current_hp() const {
        if (is_player && player_ptr) return player_ptr->current_hp_;
        if (creature_ptr) return creature_ptr->get_current_hp();
        return 0;
    }

    [[nodiscard]] int get_max_hp() const {
        if (is_player && player_ptr) return player_ptr->get_max_hp();
        if (creature_ptr) return creature_ptr->get_max_hp();
        return 0;
    }

    [[nodiscard]] int get_current_sp() const {
        if (is_player && player_ptr) return player_ptr->current_sp_;
        return 0;
    }

    [[nodiscard]] int get_max_sp() const {
        if (is_player && player_ptr) return player_ptr->get_max_sp();
        return 0;
    }

    [[nodiscard]] int get_movement_speed() const {
        if (is_player && player_ptr) return player_ptr->get_movement_speed();
        if (creature_ptr) return creature_ptr->get_movement_speed();
        return 20;
    }

    void spend_ap(int amount) {
        if (is_player && player_ptr) {
            player_ptr->current_ap_ = std::max(0, player_ptr->current_ap_ - amount);
        } else if (creature_ptr) {
            creature_ptr->spend_ap(amount);
        }
    }

    void spend_sp(int amount) {
        if (is_player && player_ptr) {
            player_ptr->current_sp_ = std::max(0, player_ptr->current_sp_ - amount);
        }
    }

    void gain_ap(int amount) {
        if (is_player && player_ptr) {
            player_ptr->current_ap_ = std::min(player_ptr->get_max_ap(), player_ptr->current_ap_ + amount);
        } else if (creature_ptr) {
            creature_ptr->gain_ap(amount);
        }
    }

    void reset_round() {
        actions_taken_this_round.clear();
        has_acted = false;
        has_used_extra_movement = false;
        total_attacks_this_round = 0;
    }

    void start_turn() {
        movement_tiles_remaining = get_movement_speed() / 5;
        has_used_extra_movement = false;
        for (auto& m : active_matrices) m.used_free_activation_this_turn = false;

        if (is_player && player_ptr) {
            player_ptr->start_turn();
        } else if (creature_ptr) {
            creature_ptr->start_turn();
        }
    }
};

class CombatManager {
public:
    static CombatManager& instance() {
        static CombatManager manager;
        return manager;
    }

    void start_combat();
    void clear_combatants();
    void add_player(Character* character, Dice& dice);
    void add_creature(Creature* creature, Dice& dice, const std::string& provided_id = "");
    void sort_initiative();

    [[nodiscard]] Combatant* get_current_combatant();
    bool set_current_combatant_by_id(const std::string& id);
    void next_turn();
    void start_new_round();
    void process_start_of_turn(Combatant& c);
    void end_player_phase();
    void end_player_turn();

    [[nodiscard]] int get_action_cost(ActionType action, const std::string& extra_param = "") const;
    bool perform_action(ActionType action, Dice& dice, const std::string& extra_param = "");
    bool handle_action_logic(ActionType action, Combatant& current, Dice& dice, const std::string& extra_param);

    Combatant* find_combatant_by_id(const std::string& id);
    [[nodiscard]] std::string get_id_by_handle(int64_t handle) const;
    void execute_spell(Combatant& caster, const std::string& spell_name, Combatant* target, Dice& dice, bool is_activation = false, bool skip_attack_roll = false);
    bool execute_attack(Combatant& attacker, Combatant& target, Dice& dice, bool is_unarmed = false, int elevation_mod = 0);

    std::string process_enemy_phase(Dice& dice);

    [[nodiscard]] int get_round() const { return round_count_; }
    [[nodiscard]] const std::vector<Combatant>& get_combatants() const { return combatants_; }
    [[nodiscard]] std::string get_last_action_log() const { return last_action_log_; }
    [[nodiscard]] CombatPhase get_phase() const { return current_phase_; }

    void set_dungeon_mode(bool mode) { dungeon_mode_ = mode; }
    [[nodiscard]] bool is_dungeon_mode() const { return dungeon_mode_; }

    void set_mission_active(bool active) { mission_active_ = active; }
    [[nodiscard]] bool is_mission_active() const { return mission_active_; }

    static bool is_basic_action(ActionType type) {
        switch (type) {
            case ActionType::MeleeAttack:
            case ActionType::RangedAttack:
            case ActionType::UnarmedAttack:
            case ActionType::Dodge:
            case ActionType::UseItem:
            case ActionType::CastSpell:
            case ActionType::Interact:
            case ActionType::Reload:
            case ActionType::Grapple:
            case ActionType::EscapeGrapple:
            case ActionType::Hide:
            case ActionType::ThrowItem:
                return true;
            default:
                return false;
        }
    }

    static bool is_attack_action(ActionType type) {
        return type == ActionType::MeleeAttack || type == ActionType::RangedAttack || type == ActionType::UnarmedAttack || type == ActionType::Grapple || type == ActionType::ThrowItem;
    }

private:
    CombatManager() : current_combatant_index_(0), round_count_(1), current_phase_(CombatPhase::Player), dungeon_mode_(false), mission_active_(false) {}
    std::vector<Combatant> combatants_;
    size_t current_combatant_index_;
    int round_count_;
    std::string last_action_log_;
    CombatPhase current_phase_;
    bool dungeon_mode_;
    bool mission_active_;
};

} // namespace rimvale

#endif // RIMVALE_COMBAT_MANAGER_H
