#ifndef RIMVALE_BEHAVIOR_H
#define RIMVALE_BEHAVIOR_H

#include <string>
#include <vector>
#include <algorithm>
#include "Dice.h"

namespace rimvale {

enum class ActionType;
struct Combatant;

struct BehavioralDrivers {
    int community = 0;
    int validation = 0;
    int resources = 0;

    void clamp() {
        community = std::max(-2, std::min(2, community));
        validation = std::max(-2, std::min(2, validation));
        resources = std::max(-2, std::min(2, resources));
    }
};

class BehaviorEngine {
public:
    static std::string decide_and_act(Combatant& enemy, std::vector<Combatant>& all_combatants, Dice& dice);

    static int calculate_disposition_shift(const BehavioralDrivers& drivers, int comm_mod, int val_mod, int res_mod) {
        return (drivers.community * comm_mod) + (drivers.validation * val_mod) + (drivers.resources * res_mod);
    }
};

}

#endif
