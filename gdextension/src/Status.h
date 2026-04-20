#ifndef RIMVALE_STATUS_H
#define RIMVALE_STATUS_H

#include <string>
#include <vector>
#include <set>
#include <map>
#include <algorithm>

namespace rimvale {

enum class ConditionType {
    Bleed,
    Blinded,
    Calm,
    Charm,
    Confused,
    Dazed,
    Deafened,
    Depleted,
    Diseased,
    Dodging,
    Enraged,
    Exhausted,
    Fear,
    Fever,
    Grappled,
    Hidden,
    Incapacitated,
    Insanity,
    Invisible,
    Invulnerable,
    Paralyzed,
    Petrified,
    Poisoned,
    Prone,
    Resistance,
    Restrained,
    Silent,
    Slowed,
    Squeeze,
    Stunned,
    Unconscious,
    Vulnerable,
    Dying,
    Dead,
    Shielded,
    Flying,
    Stoneskin,
    Intangible,
    HeatedScales,         // Goldscale: +1d4 fire on attacks, retaliation on melee hits (1 turn)
    ArmoredPlating        // Ironhide: +2 AC active, move costs +1 AP
};

enum class HealthStatus {
    Ok,
    Bloodied,
    NearDeath,
    Dying,
    Dead,
    InstantDeath
};

class StatusManager {
public:
    void add_condition(ConditionType condition) {
        if (condition == ConditionType::Bleed) {
            bleed_stacks_++;
        } else {
            conditions_.insert(condition);
        }
    }

    void remove_condition(ConditionType condition) {
        if (condition == ConditionType::Bleed) {
            if (bleed_stacks_ > 0) bleed_stacks_--;
        } else {
            conditions_.erase(condition);
        }
    }

    // Remove one non-permanent condition (used by HealingRestoration T3)
    void remove_one_condition() {
        if (bleed_stacks_ > 0) { bleed_stacks_--; return; }
        if (!conditions_.empty()) {
            // Skip Dying/Dead/Unconscious — those are handled by revivify
            for (auto it = conditions_.begin(); it != conditions_.end(); ++it) {
                if (*it != ConditionType::Dying && *it != ConditionType::Dead && *it != ConditionType::Unconscious) {
                    conditions_.erase(it);
                    return;
                }
            }
        }
    }

    [[nodiscard]] bool has_condition(ConditionType condition) const {
        if (condition == ConditionType::Bleed) return bleed_stacks_ > 0;
        return conditions_.find(condition) != conditions_.end();
    }

    [[nodiscard]] const std::set<ConditionType>& get_conditions() const { return conditions_; }

    [[nodiscard]] int get_bleed_stacks() const { return bleed_stacks_; }
    void set_bleed_stacks(int stacks) { bleed_stacks_ = stacks; }

    [[nodiscard]] int get_exhaustion_level() const { return exhaustion_level_; }
    void set_exhaustion_level(int level) { exhaustion_level_ = level; }

    void reduce_exhaustion(int amount) {
        exhaustion_level_ = std::max(0, exhaustion_level_ - amount);
    }

    [[nodiscard]] HealthStatus calculate_health_status(int current_hp, int max_hp) const {
        if (current_hp <= -2 * max_hp) return HealthStatus::InstantDeath;
        if (current_hp <= 0) return HealthStatus::Dying;
        if (current_hp < (max_hp / 3.0)) return HealthStatus::NearDeath;
        if (current_hp < (2.0 * max_hp) / 3.0) return HealthStatus::Bloodied;
        return HealthStatus::Ok;
    }

    static std::string get_condition_name(ConditionType type) {
        switch (type) {
            case ConditionType::Bleed: return "Bleed";
            case ConditionType::Blinded: return "Blinded";
            case ConditionType::Calm: return "Calm";
            case ConditionType::Charm: return "Charm";
            case ConditionType::Confused: return "Confused";
            case ConditionType::Dazed: return "Dazed";
            case ConditionType::Deafened: return "Deafened";
            case ConditionType::Depleted: return "Depleted";
            case ConditionType::Diseased: return "Diseased";
            case ConditionType::Dodging: return "Dodging";
            case ConditionType::Enraged: return "Enraged";
            case ConditionType::Exhausted: return "Exhausted";
            case ConditionType::Fear: return "Fear";
            case ConditionType::Fever: return "Fever";
            case ConditionType::Grappled: return "Grappled";
            case ConditionType::Hidden: return "Hidden";
            case ConditionType::Incapacitated: return "Incapacitated";
            case ConditionType::Insanity: return "Insanity";
            case ConditionType::Invisible: return "Invisible";
            case ConditionType::Invulnerable: return "Invulnerable";
            case ConditionType::Paralyzed: return "Paralyzed";
            case ConditionType::Petrified: return "Petrified";
            case ConditionType::Poisoned: return "Poisoned";
            case ConditionType::Prone: return "Prone";
            case ConditionType::Resistance: return "Resistance";
            case ConditionType::Restrained: return "Restrained";
            case ConditionType::Silent: return "Silent";
            case ConditionType::Slowed: return "Slowed";
            case ConditionType::Squeeze: return "Squeeze";
            case ConditionType::Stunned: return "Stunned";
            case ConditionType::Unconscious: return "Unconscious";
            case ConditionType::Vulnerable: return "Vulnerable";
            case ConditionType::Dying: return "Dying";
            case ConditionType::Dead: return "Dead";
            case ConditionType::Shielded: return "Shielded";
            case ConditionType::Flying: return "Flying";
            case ConditionType::Stoneskin: return "Stoneskin";
            case ConditionType::Intangible: return "Intangible";
            case ConditionType::HeatedScales: return "Heated Scales";
            case ConditionType::ArmoredPlating: return "Armored Plating";
            default: return "Unknown";
        }
    }

    static std::string get_condition_effect(ConditionType type) {
        switch (type) {
            case ConditionType::Bleed: return "Take 1d4 damage per stack at end of turn.";
            case ConditionType::Blinded: return "Cannot see.";
            case ConditionType::Calm: return "Cannot take hostile actions.";
            case ConditionType::Charm: return "Cannot harm charmer; charmer has advantage on social checks.";
            case ConditionType::Confused: return "Actions take double AP.";
            case ConditionType::Dazed: return "Can only take one action on turn.";
            case ConditionType::Deafened: return "Cannot hear.";
            case ConditionType::Depleted: return "No automatic AP regain at start of turn.";
            case ConditionType::Diseased: return "Stat penalties and possibly other conditions.";
            case ConditionType::Dodging: return "Enemies have disadvantage on attacks.";
            case ConditionType::Enraged: return "Attacking non-target takes double AP.";
            case ConditionType::Exhausted: return "Penalty to all checks equal to exhaustion level.";
            case ConditionType::Fear: return "Cannot approach fear source; attacks have disadvantage.";
            case ConditionType::Fever: return "Disadvantage on Attack checks.";
            case ConditionType::Grappled: return "Restrained by a creature.";
            case ConditionType::Hidden: return "Not perceivable without high perception.";
            case ConditionType::Incapacitated: return "Unable to attack or defend.";
            case ConditionType::Insanity: return "Increased critical failure range (+2 per level).";
            case ConditionType::Invisible: return "Cannot be seen.";
            case ConditionType::Invulnerable: return "Immune to damage.";
            case ConditionType::Paralyzed: return "Cannot move; auto-hit by enemies.";
            case ConditionType::Petrified: return "Turned to stone; cannot act.";
            case ConditionType::Poisoned: return "Disadvantage on checks.";
            case ConditionType::Prone: return "Lying down.";
            case ConditionType::Resistance: return "Take half damage from a damage type.";
            case ConditionType::Restrained: return "Cannot move.";
            case ConditionType::Silent: return "Cannot make sounds.";
            case ConditionType::Slowed: return "Move at half speed.";
            case ConditionType::Squeeze: return "Taking 1d4 bludgeoning damage every round.";
            case ConditionType::Stunned: return "Doubles cost of actions.";
            case ConditionType::Unconscious: return "Cannot take actions; auto-hit by enemies.";
            case ConditionType::Vulnerable: return "Take double damage from a damage type.";
            case ConditionType::Dying: return "Character is making death saving throws.";
            case ConditionType::Dead: return "Character is deceased.";
            case ConditionType::Shielded: return "Increased Armor Class from a magical barrier.";
            case ConditionType::Flying: return "Character can move through the air.";
            case ConditionType::Stoneskin: return "Hardened skin reduces incoming physical damage.";
            case ConditionType::Intangible: return "Resistance to non-magical damage; can move through obstacles and creatures as difficult terrain, cannot stop inside them.";
            case ConditionType::HeatedScales: return "+1d4 fire damage on attacks; melee attackers take 1d4 fire retaliation (DC 10+DIV or drop weapon).";
            case ConditionType::ArmoredPlating: return "+2 AC; move actions cost +1 AP.";
            default: return "";
        }
    }

private:
    std::set<ConditionType> conditions_;
    int bleed_stacks_ = 0;
    int exhaustion_level_ = 0;
};

} // namespace rimvale

#endif // RIMVALE_STATUS_H
