#ifndef RIMVALE_INJURIES_H
#define RIMVALE_INJURIES_H

#include <string>
#include <vector>
#include "Status.h"

namespace rimvale {

enum class InjurySeverity {
    Bloodied,
    NearDeath
};

struct Injury {
    int roll_value;
    std::string name;
    std::string effect_description;
    std::string effect_2_description; // For Near Death injuries - temporary effects
    std::string recovery_condition;
    InjurySeverity severity = InjurySeverity::Bloodied;
    int limb_index = 0; // 1: LA, 2: RA, 3: LL, 4: RL for Broken Limb
    int rounds_until_death = -1; // For Near Death Experience
    int rounds_remaining = -1; // For temporary injuries like Rattled or Winded
    int effect_2_rounds = 0; // Rounds for effect_2
    ConditionType effect_2_condition = ConditionType::Shielded; // Placeholder for "No condition"
};

class InjuryTable {
public:
    static Injury get_bloodied_injury(int roll) {
        switch (roll) {
            case 1: return {1, "Shallow Bleed", "Lose 1 HP at the end of each turn until treated.", "", "DC 12 Medicine check or bandage.", InjurySeverity::Bloodied};
            case 2: return {2, "Twisted Joint", "Disadvantage on Exertion and Nimble checks.", "", "Short rest + DC 12 Medicine.", InjurySeverity::Bloodied};
            case 3: return {3, "Bruised Ribs", "Disadvantage on Vitality saves until healed.", "", "Long rest or magical healing.", InjurySeverity::Bloodied};
            case 4: return {4, "Ringing Ears", "Disadvantage on Perception (sound-based).", "", "Short rest or magical healing.", InjurySeverity::Bloodied};
            case 5: return {5, "Weapon Arm Strain", "Disadvantage on attack rolls for 1 hour.", "", "DC 16 Medicine or magical healing.", InjurySeverity::Bloodied};
            case 6: return {6, "Blow to the Head", "Disadvantage on Intellect checks.", "", "Long rest or magical healing.", InjurySeverity::Bloodied};
            case 7: return {7, "Rattled", "Lose your reaction until the end of your next turn.", "", "Auto-recovers.", InjurySeverity::Bloodied, 0, -1, 2};
            case 8: return {8, "Winded", "Can't Dash or Disengage for 1 minute.", "", "Auto-recovers after 10 rounds or rest.", InjurySeverity::Bloodied, 0, -1, 10};
            case 9: return {9, "Limping", "Speed reduced by 10 ft.", "", "DC 12 Medicine or magical healing.", InjurySeverity::Bloodied};
            case 10: return {10, "Spilled Blood", "Enemies gain advantage to track you via scent.", "", "Cleaning (10 min) + DC 13 Medicine or magic.", InjurySeverity::Bloodied};
            case 11: return {11, "Minor Fracture", "-2 to AC until healed.", "", "Long rest or magical healing.", InjurySeverity::Bloodied};
            case 12: default: return {12, "Glancing Blow", "Take 2 additional damage.", "", "N/A", InjurySeverity::Bloodied};
        }
    }

    static Injury get_near_death_injury(int roll, int limb_roll = 0, int death_timer = 0) {
        switch (roll) {
            case 1: {
                std::string limb = "Limb";
                if (limb_roll == 1) limb = "Left Arm";
                else if (limb_roll == 2) limb = "Right Arm";
                else if (limb_roll == 3) limb = "Left Leg";
                else if (limb_roll == 4) limb = "Right Leg";
                return {1, "Broken " + limb, "Limb useless. Disadv on attacks (arm) or Speed 15 ft (leg).", "Stunned", "Magical healing or 1 week recovery.", InjurySeverity::NearDeath, limb_roll, -1, -1, 2, ConditionType::Stunned};
            }
            case 2: return {2, "Internal Bleeding", "Lose 1 HP every 10 minutes.", "Poisoned", "Healing magic or 10 min + DC 15 Medicine with kit.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Poisoned};
            case 3: return {3, "Cracked Skull", "Disadv on all Intellect checks.", "Dazed", "Magical healing, 1 long rest, or 3 short rests.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Dazed};
            case 4: return {4, "Collapsed Lung", "Max HP reduced by 25%. Persistent Disadv on VIT saves, Exertion, Nimble.", "Exhausted", "10 min + DC 15 Medicine or magical healing.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Exhausted};
            case 5: return {5, "Punctured Organ", "Take 2d6 damage if you Dash or take critical hits.", "Slowed", "1 hour rest and medical treatment or magical healing.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Slowed};
            case 6: return {6, "Severed Tendon", "Slowed.", "Fall prone", "Magical healing or splint + long rest.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Prone};
            case 7: return {7, "Disfigured", "Disadv on Speechcraft checks.", "Blinded", "Permanent unless magically restored.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Blinded};
            case 8: return {8, "Concussion", "DC 13 VIT save each round or unconscious.", "Dazed", "1 hour rest.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Dazed};
            case 9: return {9, "Fractured Spine", "Disadv on Speed saves.", "Paralyzed", "Magical healing only.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Paralyzed};
            case 10: return {10, "Torn Muscle", "-2 to STR-based rolls.", "Slowed", "Long rest or magical healing.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Slowed};
            case 11: return {11, "Vision Impaired", "Disadv on ranged attacks & Perception.", "Blinded", "1 day + treatment or magic.", InjurySeverity::NearDeath, 0, -1, -1, 2, ConditionType::Blinded};
            case 12: default: return {12, "Near Death Experience", "Drop to 0 HP in rounds unless stabilized.", "Unconscious", "Healing or Medicine DC 20.", InjurySeverity::NearDeath, 0, death_timer, -1, 2, ConditionType::Unconscious};
        }
    }
};

} // namespace rimvale

#endif // RIMVALE_INJURIES_H
