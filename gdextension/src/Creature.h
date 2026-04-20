#ifndef RIMVALE_CREATURE_H
#define RIMVALE_CREATURE_H

#include "Stats.h"
#include "Status.h"
#include "Dice.h"
#include "Injuries.h"
#include "Inventory.h"
#include <string>
#include <vector>
#include <algorithm>
#include <unordered_map>
#include <set>

namespace rimvale {

enum class CreatureCategory {
    Animal,
    Villager,
    Adversary,
    Monster,
    ApexMonster,
    Kaiju
};

struct CreatureAbility {
    std::string name;
    int ap_cost;
    int sp_cost;
    std::string description;
};

class Creature {
public:
    Creature(std::string name, CreatureCategory category, int level)
        : name_(std::move(name)), category_(category), level_(level) {

        // Default Stat Allocation based on GMG rules
        int total_points = 0;
        if (category == CreatureCategory::Animal) {
            total_points = (level == 0) ? 2 : (level == 1) ? 4 : (level == 2) ? 6 : 9;
        } else if (category == CreatureCategory::Villager) {
            total_points = (level == 0) ? 4 : (level == 1) ? 6 : (level == 2) ? 8 : 10;
        } else {
            total_points = 5 + level;
        }

        // Tiered distributions based on category
        int p = total_points / 5;
        int r = total_points % 5;
        stats_.strength = p + (r > 0 ? 1 : 0);
        stats_.speed = p + (r > 1 ? 1 : 0);
        stats_.intellect = p + (r > 2 ? 1 : 0);
        stats_.vitality = p + (r > 3 ? 1 : 0);
        stats_.divinity = p;

        // Apply category specific stat weighting
        if (category == CreatureCategory::Animal) {
            stats_.strength += 1; stats_.speed += 1; stats_.intellect = std::max(0, stats_.intellect - 2);
        } else if (category == CreatureCategory::Monster) {
            stats_.vitality += 1; stats_.strength += 1;
        }

        initialize_abilities();
        reset_resources();
    }

    void initialize_abilities() {
        abilities_.clear();
        // Common abilities
        abilities_.push_back({"Bite/Strike", 1, 0, "Basic physical attack."});

        if (category_ == CreatureCategory::Animal) {
            if (level_ >= 2) abilities_.push_back({"Pounce", 2, 0, "Move and attack with advantage if target is hit, they are prone."});
            if (stats_.speed >= 4) abilities_.push_back({"Pack Tactics", 0, 0, "Passive: Advantage on attacks if an ally is nearby."});
        } else if (category_ == CreatureCategory::Villager) {
            abilities_.push_back({"Call for Help", 1, 0, "Summons nearby allies."});
            if (level_ >= 2) abilities_.push_back({"Improvised Weapon", 1, 0, "Deals 1d6 damage."});
        } else if (category_ == CreatureCategory::Monster) {
            if (stats_.strength >= 3) abilities_.push_back({"Multi-attack", 2, 0, "Make two basic attacks."});
            if (stats_.divinity >= 2) abilities_.push_back({"Elemental Spark", 1, 1, "Deals elemental damage."});
            if (level_ >= 3) abilities_.push_back({"Terrifying Roar", 2, 2, "Enemies in 20ft must save vs Fear."});
        }
    }

    virtual ~Creature() = default;

    [[nodiscard]] virtual int get_max_hp() const {
        int base = 0;
        switch (category_) {
            case CreatureCategory::Animal: base = level_ + stats_.vitality; break;
            case CreatureCategory::Villager: base = (2 * level_) + stats_.vitality; break;
            case CreatureCategory::Adversary:
            case CreatureCategory::Monster: base = (3 * level_) + stats_.vitality; break;
            case CreatureCategory::ApexMonster: base = (5 * level_) + stats_.vitality; break;
            case CreatureCategory::Kaiju: base = (10 * level_) + stats_.vitality; break;
        }
        return std::max(3, base + 2); // Minimum buffer
    }

    [[nodiscard]] virtual int get_max_ap() const {
        int base = 0;
        switch (category_) {
            case CreatureCategory::Animal: base = 1 + stats_.strength; break;
            case CreatureCategory::Villager: base = 2 + stats_.strength; break;
            case CreatureCategory::Adversary:
            case CreatureCategory::Monster: base = 3 + stats_.strength; break;
            case CreatureCategory::ApexMonster: base = 10 + stats_.strength; break;
            case CreatureCategory::Kaiju: base = 10 + level_ + stats_.strength; break;
        }
        return std::max(1, base);
    }

    [[nodiscard]] virtual int get_max_sp() const {
        int base = 0;
        switch (category_) {
            case CreatureCategory::Animal: base = 1 + level_ + stats_.divinity; break;
            case CreatureCategory::Villager: base = 2 + level_ + stats_.divinity; break;
            case CreatureCategory::Adversary:
            case CreatureCategory::Monster: base = 3 + level_ + stats_.divinity; break;
            case CreatureCategory::ApexMonster: base = 10 + level_ + stats_.divinity; break;
            case CreatureCategory::Kaiju: base = 10 + level_ + stats_.divinity; break;
        }
        return std::max(0, base);
    }

    [[nodiscard]] virtual int get_movement_speed() const {
        if (status_.has_condition(ConditionType::Restrained) || status_.has_condition(ConditionType::Grappled) || status_.has_condition(ConditionType::Paralyzed) || status_.has_condition(ConditionType::Petrified)) return 0;
        if (category_ == CreatureCategory::Kaiju) {
            // Kaiju move 40 ft per point of Speed
            int spd = std::max(0, 40 * stats_.speed - speed_penalty_);
            return status_.has_condition(ConditionType::Slowed) ? spd / 2 : spd;
        }
        if (status_.has_condition(ConditionType::Slowed)) return std::max(0, (int)((category_ == CreatureCategory::Animal ? 30 : 20) + (10 * stats_.speed) - speed_penalty_)) / 2;
        int base = (category_ == CreatureCategory::Animal) ? 30 : 20;
        return std::max(0, base + (10 * stats_.speed) - speed_penalty_);
    }

    void add_damage_resistance(const std::string& type) { damage_resistances_.insert(type); }
    void add_damage_immunity(const std::string& type) { damage_immunities_.insert(type); }
    [[nodiscard]] bool is_resistant_to(const std::string& type) const { return damage_resistances_.count(type) > 0; }
    [[nodiscard]] bool is_immune_to(const std::string& type) const { return damage_immunities_.count(type) > 0; }
    [[nodiscard]] const std::set<std::string>& get_resistances() const { return damage_resistances_; }
    [[nodiscard]] const std::set<std::string>& get_immunities() const { return damage_immunities_; }

    [[nodiscard]] int get_damage_threshold() const {
        if (category_ == CreatureCategory::ApexMonster || category_ == CreatureCategory::Kaiju) {
            return std::max(5, level_);
        }
        return 0;
    }

    [[nodiscard]] Stats& get_stats() { return stats_; }
    [[nodiscard]] int get_level() const { return level_; }
    void set_level(int level) { level_ = level; }
    [[nodiscard]] CreatureCategory get_category() const { return category_; }
    [[nodiscard]] const std::string& get_name() const { return name_; }

    [[nodiscard]] int get_current_hp() const { return current_hp_; }
    [[nodiscard]] int get_current_ap() const { return current_ap_; }
    [[nodiscard]] int get_current_sp() const { return current_sp_; }

    void set_current_ap(int ap) { current_ap_ = ap; }
    void spend_ap(int amount) { current_ap_ = std::max(0, current_ap_ - amount); }
    void gain_ap(int amount) { current_ap_ = std::min(get_max_ap(), current_ap_ + amount); }

    void set_current_sp(int sp) { current_sp_ = sp; }
    void spend_sp(int amount) { current_sp_ = std::max(0, current_sp_ - amount); }

    virtual void take_damage(int amount, Dice& dice, const std::string& damage_type = "") {
        if (!damage_type.empty() && is_immune_to(damage_type)) return;
        if (!damage_type.empty() && is_resistant_to(damage_type)) amount /= 2;
        int threshold = get_damage_threshold();
        int actual_damage = (amount > threshold) ? (amount - threshold) : 0;
        current_hp_ = std::max(0, current_hp_ - actual_damage);
    }

    void heal(int amount) {
        current_hp_ = std::min(get_max_hp(), current_hp_ + amount);
    }

    virtual void reset_resources() {
        current_hp_ = get_max_hp();
        current_ap_ = get_max_ap();
        current_sp_ = get_max_sp();
        speed_penalty_ = 0;
    }

    void start_turn() {
        if (!status_.has_condition(ConditionType::Depleted)) {
            int regen = std::max(1, stats_.strength);
            current_ap_ = std::min(get_max_ap(), current_ap_ + regen);
        }
        speed_penalty_ = 0;
    }

    [[nodiscard]] const std::vector<CreatureAbility>& get_abilities() const { return abilities_; }
    [[nodiscard]] std::vector<CreatureAbility>& get_abilities_mutable() { return abilities_; }
    [[nodiscard]] Inventory& get_inventory() { return inventory_; }

    void set_feat_tier(const std::string& name, int tier) { feat_tiers_[name] = tier; }
    [[nodiscard]] int get_feat_tier(const std::string& name) const {
        auto it = feat_tiers_.find(name);
        return it != feat_tiers_.end() ? it->second : 0;
    }

    void set_speed_penalty(int penalty) { speed_penalty_ = penalty; }

    [[nodiscard]] StatusManager& get_status() { return status_; }

protected:
    std::string name_;
    CreatureCategory category_;
    int level_;
    int current_hp_ = 0;
    int current_ap_ = 0;
    int current_sp_ = 0;
    Stats stats_;
    StatusManager status_;
    std::vector<CreatureAbility> abilities_;
    Inventory inventory_;
    int speed_penalty_ = 0;
    std::unordered_map<std::string, int> feat_tiers_;
    std::set<std::string> damage_resistances_;
    std::set<std::string> damage_immunities_;
};

} // namespace rimvale

#endif // RIMVALE_CREATURE_H
