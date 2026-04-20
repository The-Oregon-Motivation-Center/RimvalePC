#include "Character.h"
#include "LineageRegistry.h"
#include "Feats.h"
#include "ItemRegistry.h"
#include "SocietalRoleRegistry.h"
#include "CharacterRegistry.h"
#include <sstream>

namespace rimvale {

static int safe_stoi(const std::string& str, int default_val = 0) {
    if (str.empty()) return default_val;
    try { return std::stoi(str); } catch (...) { return default_val; }
}

std::string Character::serialize() const {
    std::stringstream ss;
    ss << name_ << "|" << lineage_.name << "|" << level_ << "|" << age_ << "|"
       << static_cast<int>(alignment_) << "|" << static_cast<int>(domain_affinity_) << "|"
       << insanity_level_ << "|" << current_region_ << "|"
       << stats_.serialize() << "|" << skills_.serialize() << "|";

    for (size_t i = 0; i < feats_.size(); ++i) {
        ss << static_cast<int>(feats_[i].id) << "," << feats_[i].tier << (i == feats_.size() - 1 ? "" : ";");
    }
    ss << "|" << xp_ << "|" << stat_points_ << "|" << feat_points_ << "|" << skill_points_ << "|" << gold_ << "|" << unique_id_ << "|";

    // Enhanced injury serialization: roll,severity,limb,timer
    for (size_t i = 0; i < injuries_.size(); ++i) {
        ss << injuries_[i].roll_value << ","
           << static_cast<int>(injuries_[i].severity) << ","
           << injuries_[i].limb_index << ","
           << injuries_[i].rounds_until_death
           << (i == injuries_.size() - 1 ? "" : ";");
    }
    ss << "|";
    size_t count = 0;
    for (const auto& spell : learned_spells_) {
        ss << spell << (count == learned_spells_.size() - 1 ? "" : ";");
        count++;
    }

    ss << "|";
    const auto& items = inventory_.get_items();
    for (size_t i = 0; i < items.size(); ++i) {
        ss << items[i]->get_name() << (i == items.size() - 1 ? "" : ";");
    }
    ss << "|" << (equipped_weapon_ ? equipped_weapon_->get_name() : "None")
       << "|" << (equipped_armor_ ? equipped_armor_->get_name() : "None")
       << "|" << (equipped_shield_ ? equipped_shield_->get_name() : "None");

    ss << "|";
    for (size_t i = 0; i < societal_roles_.size(); ++i) {
        ss << societal_roles_[i].name << (i == societal_roles_.size() - 1 ? "" : ";");
    }

    ss << "|";
    std::vector<SkillType> favored_vec(favored_skills_.begin(), favored_skills_.end());
    for (size_t i = 0; i < favored_vec.size(); ++i) {
        ss << static_cast<int>(favored_vec[i]) << (i == favored_vec.size() - 1 ? "" : ";");
    }

    // New Fields for Assassin's Execution
    ss << "|" << graze_uses_remaining_ << "|" << (has_ruthless_crit_available_ ? "1" : "0") << "|" << advantage_until_tick_;

    // New Fields for Rest & Recovery
    ss << "|" << (sr_rest_free_available_ ? "1" : "0")
       << "|" << (sr_efficient_recuperation_available_ ? "1" : "0")
       << "|" << (lr_tireless_spirit_available_ ? "1" : "0")
       << "|" << (lr_unyielding_vitality_available_ ? "1" : "0")
       << "|" << (has_recuperation_advantage_ ? "1" : "0");

    // Light source (segment 33)
    ss << "|" << (equipped_light_source_.empty() ? "None" : equipped_light_source_);

    return ss.str();
}

std::unique_ptr<Character> Character::deserialize(const std::string& data) {
    if (data.empty()) return nullptr;
    std::stringstream ss(data);
    std::string segment;
    std::vector<std::string> segments;
    while (std::getline(ss, segment, '|')) segments.push_back(segment);
    if (segments.size() < 10) return nullptr;

    auto lin = LineageRegistry::instance().get_lineage(segments[1]);
    Lineage lineage = lin ? *lin : Lineage{segments[1], "Unknown"};

    auto character = std::make_unique<Character>(segments[0], lineage);
    character->set_level(safe_stoi(segments[2], 1));
    character->set_age(safe_stoi(segments[3], 20));
    character->set_alignment(static_cast<Alignment>(safe_stoi(segments[4])));
    character->set_domain(static_cast<Domain>(safe_stoi(segments[5])));
    character->set_insanity_level(safe_stoi(segments[6]));
    character->set_current_region(segments[7]);
    character->get_stats().deserialize(segments[8]);
    character->get_skills().deserialize(segments[9]);

    if (segments.size() > 10 && !segments[10].empty()) {
        std::stringstream feat_ss(segments[10]);
        std::string feat_item;
        while (std::getline(feat_ss, feat_item, ';')) {
            std::stringstream pair_ss(feat_item);
            std::string id_str, tier_str;
            if (std::getline(pair_ss, id_str, ',') && std::getline(pair_ss, tier_str)) {
                auto id = static_cast<FeatID>(safe_stoi(id_str));
                int tier = safe_stoi(tier_str);
                const auto* ft = FeatRegistry::instance().get_feat(id, tier);
                if (ft) character->add_feat(*ft);
                else character->add_feat(Feat(id, tier, "Restored Feat"));
            }
        }
    }

    if (segments.size() > 11) character->xp_ = safe_stoi(segments[11]);
    if (segments.size() > 12) character->stat_points_ = safe_stoi(segments[12]);
    if (segments.size() > 13) character->feat_points_ = safe_stoi(segments[13]);
    if (segments.size() > 14) character->skill_points_ = safe_stoi(segments[14]);
    if (segments.size() > 15) character->gold_ = safe_stoi(segments[15]);
    if (segments.size() > 16) character->unique_id_ = segments[16];

    if (segments.size() > 17 && !segments[17].empty()) {
        std::stringstream injury_ss(segments[17]);
        std::string injury_item;
        while (std::getline(injury_ss, injury_item, ';')) {
            std::stringstream field_ss(injury_item);
            std::string roll_str, sev_str, limb_str, timer_str;
            if (std::getline(field_ss, roll_str, ',') &&
                std::getline(field_ss, sev_str, ',') &&
                std::getline(field_ss, limb_str, ',') &&
                std::getline(field_ss, timer_str)) {

                int roll = safe_stoi(roll_str);
                int sev = safe_stoi(sev_str);
                int limb = safe_stoi(limb_str);
                int timer = safe_stoi(timer_str);

                if (roll > 0) {
                    if (static_cast<InjurySeverity>(sev) == InjurySeverity::NearDeath) {
                        character->injuries_.push_back(InjuryTable::get_near_death_injury(roll, limb, timer));
                    } else {
                        character->injuries_.push_back(InjuryTable::get_bloodied_injury(roll));
                    }
                }
            } else if (!injury_item.empty()) {
                // Fallback for old format
                int roll = safe_stoi(injury_item);
                if (roll > 0) character->injuries_.push_back(InjuryTable::get_bloodied_injury(roll));
            }
        }
    }

    if (segments.size() > 18 && !segments[18].empty()) {
        std::stringstream spell_ss(segments[18]);
        std::string spell_name;
        while (std::getline(spell_ss, spell_name, ';')) if (!spell_name.empty()) character->add_learned_spell(spell_name);
    }

    if (segments.size() > 19 && !segments[19].empty()) {
        std::stringstream item_ss(segments[19]);
        std::string item_name;
        while (std::getline(item_ss, item_name, ';')) {
            if (item_name.empty()) continue;
            auto weapon = ItemRegistry::instance().create_weapon(item_name);
            if (weapon) character->get_inventory().add_item(std::move(weapon));
            else {
                auto armor = ItemRegistry::instance().create_armor(item_name);
                if (armor) character->get_inventory().add_item(std::move(armor));
                else {
                    auto item = ItemRegistry::instance().create_general_item(item_name);
                    if (item) character->get_inventory().add_item(std::move(item));
                }
            }
        }
    }

    if (segments.size() > 20 && segments[20] != "None") character->equip_weapon(ItemRegistry::instance().create_weapon(segments[20]));
    if (segments.size() > 21 && segments[21] != "None") character->equip_armor(ItemRegistry::instance().create_armor(segments[21]));
    if (segments.size() > 22 && segments[22] != "None") character->equip_shield(ItemRegistry::instance().create_armor(segments[22]));

    if (segments.size() > 23 && !segments[23].empty()) {
        std::stringstream role_ss(segments[23]);
        std::string role_name;
        while (std::getline(role_ss, role_name, ';')) {
            const auto* role = SocietalRoleRegistry::instance().get_role(role_name);
            if (role) character->add_societal_role(*role);
        }
    }

    if (segments.size() > 24 && !segments[24].empty()) {
        std::stringstream favored_ss(segments[24]);
        std::string skill_str;
        while (std::getline(favored_ss, skill_str, ';')) {
            character->toggle_favored_skill(static_cast<SkillType>(safe_stoi(skill_str)));
        }
    }

    // Assassin's Execution
    if (segments.size() > 25) character->graze_uses_remaining_ = safe_stoi(segments[25]);
    if (segments.size() > 26) character->has_ruthless_crit_available_ = (segments[26] == "1");
    if (segments.size() > 27) character->advantage_until_tick_ = safe_stoi(segments[27]);

    // Rest & Recovery
    if (segments.size() > 28) character->sr_rest_free_available_ = (segments[28] == "1");
    if (segments.size() > 29) character->sr_efficient_recuperation_available_ = (segments[29] == "1");
    if (segments.size() > 30) character->lr_tireless_spirit_available_ = (segments[30] == "1");
    if (segments.size() > 31) character->lr_unyielding_vitality_available_ = (segments[31] == "1");
    if (segments.size() > 32) character->has_recuperation_advantage_ = (segments[32] == "1");
    if (segments.size() > 33 && segments[33] != "None") character->equipped_light_source_ = segments[33];

    character->reset_resources();
    CharacterRegistry::instance().register_character(character.get());
    return character;
}

} // namespace rimvale
