#ifndef RIMVALE_WEAPON_H
#define RIMVALE_WEAPON_H

#include "Item.h"
#include <vector>
#include <string>
#include <memory>

namespace rimvale {

enum class DamageType {
    Bludgeoning, Piercing, Slashing, Force, Fire, Cold, Lightning, Thunder, Acid, Poison, Psychic, Radiant, Necrotic
};

enum class WeaponCategory {
    Simple, Martial
};

class Weapon : public Item {
public:
    Weapon(std::string name, int max_hp, int cost_gp, std::string damage_dice, DamageType damage_type,
           WeaponCategory category, std::vector<std::string> properties, std::string mastery, Rarity rarity = Rarity::Mundane, std::string description = "")
        : Item(std::move(name), max_hp, cost_gp, rarity, std::move(description)), damage_dice_(std::move(damage_dice)),
          damage_type_(damage_type), category_(category), properties_(std::move(properties)), mastery_(std::move(mastery)), is_ruined_(false) {}

    [[nodiscard]] std::unique_ptr<Item> clone() const override {
        return std::make_unique<Weapon>(*this);
    }

    [[nodiscard]] const std::string& get_damage_dice() const { return damage_dice_; }
    [[nodiscard]] DamageType get_damage_type() const { return damage_type_; }
    [[nodiscard]] WeaponCategory get_category() const { return category_; }
    [[nodiscard]] const std::vector<std::string>& get_properties() const { return properties_; }
    [[nodiscard]] const std::string& get_mastery() const { return mastery_; }
    [[nodiscard]] bool is_ruined() const { return is_ruined_; }

    void on_hit() { take_damage(1); }
    void on_critical_failure() {
        take_damage(5);
        if (current_hp_ <= 0) {
            is_ruined_ = true;
        }
    }

    void repair(int amount) {
        Item::repair(amount);
        if (current_hp_ > 0) is_ruined_ = false;
    }

private:
    std::string damage_dice_;
    DamageType damage_type_;
    WeaponCategory category_;
    std::vector<std::string> properties_;
    std::string mastery_;
    bool is_ruined_;
};

} // namespace rimvale

#endif // RIMVALE_WEAPON_H
