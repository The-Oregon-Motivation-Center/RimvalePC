#ifndef RIMVALE_BASE_H
#define RIMVALE_BASE_H

#include <string>
#include <vector>
#include <map>

namespace rimvale {

enum class FacilityType {
    Workshop,
    ArcaneLibrary,
    Barracks,
    HealingGarden,
    Armory,
    NavalYard,
    HealingWard,
    MessengerPost,
    SiegeWorkshop,
    DivineShrine,
    BeastKennels
};

struct Facility {
    FacilityType type;
    std::string name;
    std::string description;
    int cost_multiplier = 25;
};

class Base {
public:
    Base(std::string name, int tier)
        : name_(std::move(name)), tier_(tier), supplies_(10), defense_(10), morale_(10), acreage_(1) {
        if (tier_ < 1) tier_ = 1;
        if (tier_ > 5) tier_ = 5;
    }

    [[nodiscard]] const std::string& get_name() const { return name_; }
    [[nodiscard]] int get_tier() const { return tier_; }
    [[nodiscard]] int get_supplies() const { return supplies_; }
    [[nodiscard]] int get_defense() const { return defense_; }
    [[nodiscard]] int get_morale() const { return morale_; }
    [[nodiscard]] int get_acreage() const { return acreage_; }

    void set_supplies(int val) { supplies_ = val; }
    void set_defense(int val) { defense_ = val; }
    void set_morale(int val) { morale_ = val; }
    void set_acreage(int val) { acreage_ = val; }

    [[nodiscard]] int get_max_facilities() const {
        switch (tier_) {
            case 1: return 2;
            case 2: return 4;
            case 3: return 6;
            case 4: return 8;
            case 5: return 10;
            default: return 2;
        }
    }

    [[nodiscard]] int get_max_defenders() const {
        switch (tier_) {
            case 1: return 4;
            case 2: return 10;
            case 3: return 20;
            case 4: return 40;
            case 5: return 100; // 50+
            default: return 4;
        }
    }

    bool add_facility(FacilityType type) {
        if (facilities_.size() >= static_cast<size_t>(get_max_facilities())) return false;

        std::string name;
        std::string desc;
        switch (type) {
            case FacilityType::Workshop: name = "Workshop"; desc = "Crafting & repairing gear; +2 to checks. Half cost."; break;
            case FacilityType::ArcaneLibrary: name = "Arcane Library"; desc = "Research spells/rituals; +2 Arcane/Learnedness."; break;
            case FacilityType::Barracks: name = "Barracks"; desc = "Houses 5 defenders."; break;
            case FacilityType::HealingGarden: name = "Healing Garden"; desc = "Produces herbs for healing/food."; break;
            case FacilityType::Armory: name = "Armory"; desc = "Grants weapons/armor; defenders +2 AC."; break;
            case FacilityType::NavalYard: name = "Naval Yard"; desc = "Aquatic vehicles and units."; break;
            case FacilityType::HealingWard: name = "Healing Ward"; desc = "Regens HP after encounters; remove status."; break;
            case FacilityType::MessengerPost: name = "Messenger Post"; desc = "Rapid communication; call reinforcements."; break;
            case FacilityType::SiegeWorkshop: name = "Siege Workshop"; desc = "Access to siege weapons; +2 breaching."; break;
            case FacilityType::DivineShrine: name = "Divine Shrine"; desc = "Grants one divine blessing per day."; break;
            case FacilityType::BeastKennels: name = "Beast Kennels"; desc = "Access to trained mounts/war beasts."; break;
        }
        facilities_.push_back({type, name, desc, 25});
        return true;
    }

    [[nodiscard]] const std::vector<Facility>& get_facilities() const { return facilities_; }

    [[nodiscard]] int get_defense_modifier() const {
        // Base Perimeter logic
        if (acreage_ <= 2) return 2;
        if (acreage_ <= 5) return 1;
        if (acreage_ <= 10) return 0;
        if (acreage_ <= 20) return -1;
        return -2;
    }

private:
    std::string name_;
    int tier_;
    int supplies_;
    int defense_;
    int morale_;
    int acreage_;
    std::vector<Facility> facilities_;
};

} // namespace rimvale

#endif // RIMVALE_BASE_H
