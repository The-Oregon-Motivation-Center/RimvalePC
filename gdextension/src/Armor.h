#ifndef RIMVALE_ARMOR_H
#define RIMVALE_ARMOR_H

#include "Item.h"
#include <memory>

namespace rimvale {

enum class ArmorCategory {
    Light,
    Medium,
    Heavy,
    Shield,
    TowerShield
};

class Armor : public Item {
public:
    Armor(std::string name, int max_hp, int cost_gp, int ac_bonus, int strength_req,
          bool stealth_disadvantage, ArmorCategory category, Rarity rarity = Rarity::Common, std::string description = "")
        : Item(std::move(name), max_hp, cost_gp, rarity, std::move(description)), ac_bonus_(ac_bonus),
          strength_req_(strength_req), stealth_disadvantage_(stealth_disadvantage), category_(category), is_ruined_(false) {}

    [[nodiscard]] std::unique_ptr<Item> clone() const override {
        return std::make_unique<Armor>(*this);
    }

    [[nodiscard]] int get_ac_bonus() const { return ac_bonus_; }
    [[nodiscard]] int get_strength_req() const { return strength_req_; }
    [[nodiscard]] bool has_stealth_disadvantage() const { return stealth_disadvantage_; }
    [[nodiscard]] ArmorCategory get_category() const { return category_; }
    [[nodiscard]] bool is_ruined() const { return is_ruined_; }

    void on_hit_taken() {
        take_damage(1);
    }

    void on_critical_hit_taken() {
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
    int ac_bonus_;
    int strength_req_;
    bool stealth_disadvantage_;
    ArmorCategory category_;
    bool is_ruined_;
};

} // namespace rimvale

#endif // RIMVALE_ARMOR_H
