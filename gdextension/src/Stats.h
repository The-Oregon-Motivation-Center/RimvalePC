#ifndef RIMVALE_STATS_H
#define RIMVALE_STATS_H

#include <string>
#include <map>
#include <vector>
#include <sstream>
#include <stdexcept>

namespace rimvale {

enum class StatType {
    Strength,
    Speed,
    Intellect,
    Vitality,
    Divinity
};

struct Stats {
    int strength = 0;
    int speed = 0;
    int intellect = 0;
    int vitality = 0;
    int divinity = 0;

    [[nodiscard]] int get_stat(StatType type) const {
        switch (type) {
            case StatType::Strength: return strength;
            case StatType::Speed: return speed;
            case StatType::Intellect: return intellect;
            case StatType::Vitality: return vitality;
            case StatType::Divinity: return divinity;
            default: return 0;
        }
    }

    void set_stat(StatType type, int value) {
        switch (type) {
            case StatType::Strength: strength = value; break;
            case StatType::Speed: speed = value; break;
            case StatType::Intellect: intellect = value; break;
            case StatType::Vitality: vitality = value; break;
            case StatType::Divinity: divinity = value; break;
        }
    }

    [[nodiscard]] std::string serialize() const {
        std::stringstream ss;
        ss << strength << "," << speed << "," << intellect << "," << vitality << "," << divinity;
        return ss.str();
    }

    void deserialize(const std::string& data) {
        if (data.empty()) return;
        std::stringstream ss(data);
        std::string item;
        auto safe_parse = [](const std::string& s) {
            if (s.empty()) return 0;
            try { return std::stoi(s); } catch (...) { return 0; }
        };
        if (std::getline(ss, item, ',')) strength = safe_parse(item);
        if (std::getline(ss, item, ',')) speed = safe_parse(item);
        if (std::getline(ss, item, ',')) intellect = safe_parse(item);
        if (std::getline(ss, item, ',')) vitality = safe_parse(item);
        if (std::getline(ss, item, ',')) divinity = safe_parse(item);
    }
};

enum class SkillType {
    Arcane, Crafting, CreatureHandling, Cunning, Exertion,
    Intuition, Learnedness, Medical, Nimble, Perception,
    Perform, Sneak, Speechcraft, Survival
};

struct Skills {
    std::map<SkillType, int> points;

    Skills() {
        for (int i = 0; i <= 13; ++i) {
            points[static_cast<SkillType>(i)] = 0;
        }
    }

    [[nodiscard]] int get_skill(SkillType type) const {
        auto it = points.find(type);
        return (it != points.end()) ? it->second : 0;
    }

    void set_skill(SkillType type, int value) {
        points[type] = value;
    }

    [[nodiscard]] std::string serialize() const {
        std::stringstream ss;
        for (int i = 0; i <= 13; ++i) {
            ss << points.at(static_cast<SkillType>(i)) << (i == 13 ? "" : ",");
        }
        return ss.str();
    }

    void deserialize(const std::string& data) {
        if (data.empty()) return;
        std::stringstream ss(data);
        std::string item;
        auto safe_parse = [](const std::string& s) {
            if (s.empty()) return 0;
            try { return std::stoi(s); } catch (...) { return 0; }
        };
        for (int i = 0; i <= 13; ++i) {
            if (std::getline(ss, item, ',')) {
                points[static_cast<SkillType>(i)] = safe_parse(item);
            }
        }
    }
};

} // namespace rimvale

#endif // RIMVALE_STATS_H
