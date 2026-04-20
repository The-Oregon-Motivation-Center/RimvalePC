#ifndef RIMVALE_DICE_H
#define RIMVALE_DICE_H

#include <random>
#include <algorithm>
#include <string>
#include <regex>

namespace rimvale {

enum class RollType {
    Normal,
    Advantage,
    Disadvantage
};

struct RollResult {
    int die_roll;
    int modifier;
    int total;
    bool is_critical_success;
    bool is_critical_failure;
    std::string details;
};

class Dice {
public:
    Dice() : gen_(rd_()) {}

    int roll(int sides) {
        if (sides <= 0) return 0;
        std::uniform_int_distribution<> dis(1, sides);
        return dis(gen_);
    }

    int roll(int sides, int count) {
        int total = 0;
        for (int i = 0; i < count; ++i) {
            total += roll(sides);
        }
        return total;
    }

    int roll_string(const std::string& formula) {
        std::regex re("(\\d+)d(\\d+)");
        std::smatch match;
        if (std::regex_search(formula, match, re)) {
            int count = std::stoi(match[1]);
            int sides = std::stoi(match[2]);
            return roll(sides, count);
        }
        return roll(8); // Default to d8 if unparseable
    }

    RollResult roll_d20(RollType type, int modifier, int insanity_level = 0) {
        int r1 = roll(20);
        int natural;

        if (type == RollType::Advantage) {
            int r2 = roll(20);
            natural = std::max(r1, r2);
        } else if (type == RollType::Disadvantage) {
            int r2 = roll(20);
            natural = std::min(r1, r2);
        } else {
            natural = r1;
        }

        bool crit_success = (natural == 20);
        int crit_fail_threshold = 1 + (insanity_level * 2);
        bool crit_failure = (natural <= crit_fail_threshold);

        return {natural, modifier, natural + modifier, crit_success, crit_failure, ""};
    }

private:
    std::random_device rd_;
    std::mt19937 gen_;
};

} // namespace rimvale

#endif // RIMVALE_DICE_H
