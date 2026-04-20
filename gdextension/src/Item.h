#ifndef RIMVALE_ITEM_H
#define RIMVALE_ITEM_H

#include <string>
#include <algorithm>
#include <functional>
#include <utility>
#include <memory>

namespace rimvale {

enum class Rarity {
    Mundane,
    Common,
    Uncommon,
    Rare,
    VeryRare,
    Legendary,
    Apex
};

class Character; // Forward declaration

class Item {
public:
    Item(std::string name, int max_hp, int cost_gp, Rarity rarity = Rarity::Mundane, std::string description = "")
        : name_(std::move(name)), max_hp_(max_hp), current_hp_(max_hp), cost_gp_(cost_gp), rarity_(rarity), description_(std::move(description)) {}

    virtual ~Item() = default;

    [[nodiscard]] virtual std::unique_ptr<Item> clone() const {
        return std::make_unique<Item>(*this);
    }

    [[nodiscard]] const std::string& get_name() const { return name_; }
    [[nodiscard]] int get_max_hp() const { return max_hp_; }
    [[nodiscard]] int get_current_hp() const { return current_hp_; }
    [[nodiscard]] int get_cost_gp() const { return cost_gp_; }
    [[nodiscard]] Rarity get_rarity() const { return rarity_; }
    [[nodiscard]] const std::string& get_description() const { return description_; }
    [[nodiscard]] bool is_broken() const { return current_hp_ <= 0; }
    [[nodiscard]] bool is_magical() const { return rarity_ != Rarity::Mundane; }
    [[nodiscard]] virtual bool is_consumable() const { return false; }

    [[nodiscard]] int get_object_ac() const { return object_ac_; }
    [[nodiscard]] int get_damage_threshold() const { return damage_threshold_; }
    void set_object_properties(int ac, int threshold) { object_ac_ = ac; damage_threshold_ = threshold; }

    void take_damage(int amount) {
        current_hp_ = std::max(0, current_hp_ - amount);
    }

    void take_attack_damage(int amount) {
        if (amount > damage_threshold_) {
            take_damage(amount);
        }
    }

    void repair(int amount) {
        current_hp_ = std::min(max_hp_, current_hp_ + amount);
    }

    void fully_repair() {
        current_hp_ = max_hp_;
    }

    [[nodiscard]] int get_repair_cost_per_hp() const {
        int base_cost = 5; // Example base cost
        return is_magical() ? (base_cost * 2) : base_cost;
    }

    void regenerate_at_dawn() {
        if (!is_magical()) return;
        int regen = 0;
        switch (rarity_) {
            case Rarity::Common: regen = 1; break;
            case Rarity::Uncommon: regen = 2; break;
            case Rarity::Rare: regen = 3; break;
            case Rarity::VeryRare: regen = 4; break;
            case Rarity::Legendary: regen = 5; break;
            case Rarity::Apex: regen = 5; break;
            default: break;
        }
        repair(regen);
    }

    [[nodiscard]] int get_attunement_cost() const {
        if (!is_magical()) return 0;
        switch (rarity_) {
            case Rarity::Common: return 1;
            case Rarity::Uncommon: return 2;
            case Rarity::Rare: return 3;
            case Rarity::VeryRare: return 4;
            case Rarity::Legendary: return 5;
            case Rarity::Apex: return 5;
            default: return 0;
        }
    }

protected:
    std::string name_;
    int max_hp_;
    int current_hp_;
    int cost_gp_;
    Rarity rarity_;
    std::string description_;
    int object_ac_ = 17;
    int damage_threshold_ = 8;
};

class Consumable : public Item {
public:
    using EffectFunc = std::function<std::string(Character*)>;

    Consumable(std::string name, int cost_gp, EffectFunc effect, Rarity rarity = Rarity::Common, std::string description = "")
        : Item(std::move(name), 1, cost_gp, rarity, std::move(description)), effect_(std::move(effect)) {}

    [[nodiscard]] std::unique_ptr<Item> clone() const override {
        return std::make_unique<Consumable>(*this);
    }

    [[nodiscard]] bool is_consumable() const override { return true; }

    std::string use(Character* user) {
        if (effect_) return effect_(user);
        return "No effect.";
    }

private:
    EffectFunc effect_;
};

} // namespace rimvale

#endif // RIMVALE_ITEM_H
