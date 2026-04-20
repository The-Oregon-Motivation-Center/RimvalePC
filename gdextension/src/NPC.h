#ifndef RIMVALE_NPC_H
#define RIMVALE_NPC_H

#include "Creature.h"
#include "Behavior.h"
#include <string>
#include <vector>
#include <algorithm>

namespace rimvale {

struct DialogueLine {
    std::string text;
    int min_disposition;
    std::string unlock_quest_title;
};

class NPC : public Creature {
public:
    NPC(std::string name, CreatureCategory category, int level)
        : Creature(std::move(name), category, level) {
        disposition_ = 0;
    }

    NPC(const NPC& other) = default;
    NPC(NPC&& other) noexcept = default;
    NPC& operator=(const NPC& other) = default;
    NPC& operator=(NPC&& other) noexcept = default;

    [[nodiscard]] BehavioralDrivers& get_drivers() { return drivers_; }
    [[nodiscard]] int get_disposition() const { return disposition_; }
    void set_disposition(int value) {
        disposition_ = std::max(-2, std::min(2, value));
    }

    void handle_interaction(int community_mod, int validation_mod, int resource_mod) {
        int shift = BehaviorEngine::calculate_disposition_shift(drivers_, community_mod, validation_mod, resource_mod);
        if (shift >= 2) set_disposition(disposition_ + 1);
        else if (shift <= -2) set_disposition(disposition_ - 1);
    }

    [[nodiscard]] std::string get_disposition_text() const {
        if (disposition_ >= 2) return "Very Friendly (Risks life for you)";
        if (disposition_ == 1) return "Friendly (Sticks neck out)";
        if (disposition_ == 0) return "Neutral (Knows you)";
        if (disposition_ == -1) return "Unfriendly (Unwilling to deal)";
        return "Hostile (Actively works against you)";
    }

    void add_dialogue(std::string text, int min_disp, std::string quest = "") {
        dialogue_options_.push_back({std::move(text), min_disp, std::move(quest)});
    }

    [[nodiscard]] std::vector<DialogueLine> get_available_dialogue() const {
        std::vector<DialogueLine> available;
        for (const auto& line : dialogue_options_) {
            if (disposition_ >= line.min_disposition) {
                available.push_back(line);
            }
        }
        return available;
    }

private:
    BehavioralDrivers drivers_;
    int disposition_; // -2 to 2
    std::vector<DialogueLine> dialogue_options_;
};

class Adversary : public NPC {
public:
    Adversary(std::string name, int level)
        : NPC(std::move(name), CreatureCategory::Adversary, level),
          encounter_count_(0) {}

    void on_encounter_survived() {
        encounter_count_++;
        level_up_adversary();
    }

    [[nodiscard]] int get_vengeance_bonus() const {
        return encounter_count_;
    }

    void level_up_adversary() {
        set_level(get_level() + 1);
        reset_resources();
    }

private:
    int encounter_count_;
};

} // namespace rimvale

#endif // RIMVALE_NPC_H
