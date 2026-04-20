#ifndef RIMVALE_SPELL_REGISTRY_H
#define RIMVALE_SPELL_REGISTRY_H

#include <string>
#include <vector>
#include <mutex>
#include <algorithm>
#include "Character.h"
#include "Item.h"
#include "Status.h"

namespace rimvale {

enum class SpellRange { Self, Touch, FifteenFt, ThirtyFt, OneHundredFt, FiveHundredFt, OneThousandFt };

// 0=None (single/multi target), 1=10ft cube (2-tile radius), 2=30ft cube (6-tile radius), 3=100ft cube (20-tile radius)
enum class SpellAreaType : int { None = 0, TenFtCube = 1, ThirtyFtCube = 2, HundredFtCube = 3 };

struct Spell {
    std::string name;
    Domain domain;
    int base_sp_cost;
    std::string description;
    SpellRange range;
    bool is_attack;
    int die_count;
    int die_sides;
    bool is_custom = false;
    DamageType damage_type = DamageType::Force;
    bool is_healing = false;
    std::vector<ConditionType> conditions;
    int duration_rounds = 0; // 0 = Instant, >0 = Sustained. 1 round = 6 seconds.
    int max_targets = 1;
    SpellAreaType area_type = SpellAreaType::None;
    bool is_teleport = false; // SP cost calculated dynamically from distance at cast time
};

class SpellRegistry {
public:
    static SpellRegistry& instance() {
        static SpellRegistry registry;
        return registry;
    }

    std::vector<Spell> get_all_spells() const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<Spell> all = spells_;
        all.insert(all.end(), custom_spells_.begin(), custom_spells_.end());
        return all;
    }

    std::vector<Spell> get_spells_by_domain(Domain domain) const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<Spell> result;
        for (const auto& spell : spells_) {
            if (spell.domain == domain) result.push_back(spell);
        }
        for (const auto& spell : custom_spells_) {
            if (spell.domain == domain) result.push_back(spell);
        }
        return result;
    }

    const Spell* find_spell(const std::string& name) const {
        std::lock_guard<std::mutex> lock(mutex_);
        for (const auto& spell : spells_) {
            if (spell.name == name) return &spell;
        }
        for (const auto& spell : custom_spells_) {
            if (spell.name == name) return &spell;
        }
        return nullptr;
    }

    void add_custom_spell(const Spell& spell) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = std::find_if(custom_spells_.begin(), custom_spells_.end(),
            [&](const Spell& s) { return s.name == spell.name; });
        if (it != custom_spells_.end()) {
            *it = spell;
        } else {
            custom_spells_.push_back(spell);
        }
    }

    std::vector<Spell> get_custom_spells() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return custom_spells_;
    }

    void clear_custom_spells() {
        std::lock_guard<std::mutex> lock(mutex_);
        custom_spells_.clear();
    }

    static int get_range_tiles(SpellRange range) {
        switch (range) {
            case SpellRange::Self: return 0;
            case SpellRange::Touch: return 1;
            case SpellRange::FifteenFt: return 3;
            case SpellRange::ThirtyFt: return 6;
            case SpellRange::OneHundredFt: return 20;
            case SpellRange::FiveHundredFt: return 100;
            case SpellRange::OneThousandFt: return 200;
            default: return 1;
        }
    }

    static int get_area_radius_tiles(SpellAreaType area) {
        switch (area) {
            case SpellAreaType::TenFtCube: return 1;
            case SpellAreaType::ThirtyFtCube: return 3;
            case SpellAreaType::HundredFtCube: return 10;
            default: return 0;
        }
    }

private:
    SpellRegistry() {
        spells_ = {
            // Biological
            {"Healing Touch", Domain::Biological, 6, "Touch a creature and restore 2d8 hit points.", SpellRange::Touch, false, 2, 8, false, DamageType::Radiant, true, {}, 0, 1},
            {"Aura of Restoration", Domain::Biological, 6, "All allies in a 30-foot burst are healed for 1d6 hit points.", SpellRange::Self, false, 1, 6, false, DamageType::Radiant, true, {}, 0, 10},
            {"Chain Mend", Domain::Biological, 8, "Up to three targets within 30 feet are each healed for 1d4 hit points.", SpellRange::ThirtyFt, false, 1, 4, false, DamageType::Radiant, true, {}, 0, 3},
            {"Healing Light", Domain::Biological, 2, "Heals a target's wounds with a touch by 1d6 per action.", SpellRange::Touch, false, 1, 6, false, DamageType::Radiant, true, {}, 10, 1}, // 1 minute = 10 rounds
            {"Claw Swipe", Domain::Biological, 6, "Transform hands into claws, gaining a natural weapon attack.", SpellRange::Touch, true, 1, 8, false, DamageType::Slashing, false, {}, 100, 1}, // 10 minutes = 100 rounds
            {"Undead Squirrel", Domain::Biological, 10, "Animate a little squirrel friend that maybe spits venom.", SpellRange::Touch, false, 0, 0, false, DamageType::Poison, false, {}, 14400, 1}, // 1 day
            {"Perma-Heal", Domain::Biological, 20, "Target regains 1d4 HP at start of turn for the whole day.", SpellRange::Touch, false, 1, 4, false, DamageType::Radiant, true, {}, 14400, 1}, // 1 day
            {"Littlest Healing", Domain::Biological, 2, "Touch a creature to restore 2d4 hit points.", SpellRange::Touch, false, 2, 4, false, DamageType::Radiant, true, {}, 0, 1},
            {"Revivify", Domain::Biological, 10, "Touch a dead creature and restore it to life at 1 HP, removing the Dead and Unconscious conditions.", SpellRange::Touch, false, 0, 0, false, DamageType::Radiant, true, {}, 0, 1},
            {"Teleport", Domain::Physical, 0, "Instantly teleport yourself to a visible location. SP cost scales with distance: 1 SP/10ft, doubling each 10ft.", SpellRange::Self, false, 0, 0, false, DamageType::Force, false, {}, 0, 1, SpellAreaType::None, true},
            {"Teleport Other", Domain::Physical, 0, "Instantly teleport a target to a visible location. Unwilling creatures may make a Divinity save. SP cost scales with distance.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {}, 0, 1, SpellAreaType::None, true},

            // Chemical
            {"Searing Ray", Domain::Chemical, 7, "A ray of fire deals 2d8 damage to a single target at range.", SpellRange::OneHundredFt, true, 2, 8, false, DamageType::Fire, false, {}, 0, 1},
            {"Fireburst", Domain::Chemical, 2, "All creatures in a 30-foot area take 1d6 fire damage.", SpellRange::ThirtyFt, true, 1, 6, false, DamageType::Fire, false, {}, 0, 10},
            {"Fireball", Domain::Chemical, 69, "Deals 5d10 fire damage in a 30ft area.", SpellRange::OneHundredFt, true, 5, 10, false, DamageType::Fire, false, {}, 0, 20},
            {"Flaming Attacks", Domain::Chemical, 15, "Enchant attacks to deal +2d6 fire damage for 10 minutes.", SpellRange::Self, false, 2, 6, false, DamageType::Fire, false, {}, 100, 1}, // 10 minutes
            {"Create Bread", Domain::Chemical, 4, "Catalyze a chemical reaction to create edible sugar-like substance.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {}, 0, 1},
            {"Solid to Liquid", Domain::Chemical, 4, "Change a lock from solid metal to liquid metal for 1 round.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {}, 1, 1},
            {"Fog Generation", Domain::Chemical, 4, "Generate a dense fog in a 10-foot cube within 30 feet.", SpellRange::ThirtyFt, false, 0, 0, false, DamageType::Force, false, {}, 100, 1}, // 10 minutes
            {"Condense Water", Domain::Chemical, 4, "Produce 1 liter of water from surrounding air over 4 minutes.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {}, 0, 1},
            {"Littlest Combustion", Domain::Chemical, 7, "Cause a 5ft cube to violently combust dealing 1d8 force damage.", SpellRange::ThirtyFt, true, 1, 8, false, DamageType::Force, false, {}, 0, 1},

            // Physical
            {"Arcane Force Field", Domain::Physical, 9, "A shimmering barrier reduces damage (+2 AC) for 10 minutes.", SpellRange::Self, false, 0, 0, false, DamageType::Force, false, {ConditionType::Shielded}, 100, 1}, // 10 minutes
            {"Shadow Veil", Domain::Physical, 5, "Become invisible for 10 minutes in darkness.", SpellRange::Self, false, 0, 0, false, DamageType::Psychic, false, {ConditionType::Invisible}, 100, 1}, // 10 minutes
            {"Wings of the Shattered Gods", Domain::Physical, 15, "Sprout ethereal wings and fly for 1 hour.", SpellRange::Self, false, 0, 0, false, DamageType::Force, false, {ConditionType::Flying}, 600, 1}, // 1 hour
            {"Stoneskin", Domain::Physical, 7, "Skin hardens, reducing damage by 2d4 for 10 minutes.", SpellRange::Touch, false, 2, 4, false, DamageType::Bludgeoning, false, {ConditionType::Stoneskin}, 100, 1}, // 10 minutes
            {"Intangibility", Domain::Physical, 4, "Become intangible; resistance to non-magical damage, move through obstacles and creatures as difficult terrain.", SpellRange::Self, false, 0, 0, false, DamageType::Force, false, {ConditionType::Intangible}, 10, 1},
            {"Chain Lightning", Domain::Physical, 11, "Up to three targets within 100 feet each take 1d4 lightning damage.", SpellRange::OneHundredFt, true, 1, 4, false, DamageType::Lightning, false, {}, 0, 3},
            {"Lightning Bolt", Domain::Physical, 12, "Hurts a bolt of lightning at a distant foe (3d4 damage).", SpellRange::OneHundredFt, true, 3, 4, false, DamageType::Lightning, false, {}, 0, 1},
            {"Frost Lance", Domain::Physical, 3, "Hurl a spear of ice dealing 2d4 cold damage.", SpellRange::ThirtyFt, true, 2, 4, false, DamageType::Cold, false, {}, 0, 1},
            // Telekinesis sub-spells
            {"Telekinesis: Move",                Domain::Physical, 0, "Move an object or creature telekinetically. Cost: 1 SP per 250 lbs per 10 ft. Crash: Xd4 force to both.", SpellRange::ThirtyFt, false, 0, 4, false, DamageType::Force, false, {}, 0, 1},
            {"Telekinesis: Hover",               Domain::Physical, 0, "Hover an object or creature vertically. Cost: 1 SP per 500 lbs per 10 ft.", SpellRange::ThirtyFt, false, 0, 4, false, DamageType::Force, false, {}, 0, 1},
            {"Telekinesis: Animate Weapon",      Domain::Physical, 2, "Animate a weapon to auto-attack once per round at your turn start. Each extra 2 SP committed adds another attack and 15 ft move.", SpellRange::ThirtyFt, false, 0, 0, false, DamageType::Force, false, {}, 100, 1},
            {"Telekinesis: Animate Shield",      Domain::Physical, 2, "Animate a standard shield to defend you, granting its AC bonus without equipping it. One animated shield at a time.", SpellRange::Self, false, 0, 0, false, DamageType::Force, false, {}, 100, 1},
            {"Telekinesis: Animate Tower Shield",Domain::Physical, 4, "Animate a tower shield to defend you, granting its AC bonus without equipping it. One animated shield at a time.", SpellRange::Self, false, 0, 0, false, DamageType::Force, false, {}, 100, 1},
            {"Telekinesis: Flight",              Domain::Physical, 4, "Grant a creature a 30 ft flight speed. Cost adjusted by creature size (+/-1 SP per size step from Medium). Flying condition.", SpellRange::ThirtyFt, false, 0, 0, false, DamageType::Force, false, {ConditionType::Flying}, 100, 1},

            // Spiritual
            {"Scrying Eye", Domain::Spiritual, 15, "See and hear a distant well known location or creature for 1 minute.", SpellRange::FiveHundredFt, false, 0, 0, false, DamageType::Psychic, false, {}, 10, 1}, // 1 minute
            {"Mind Link", Domain::Spiritual, 7, "Caster and a willing target communicate telepathically for 10 minutes.", SpellRange::ThirtyFt, false, 0, 0, false, DamageType::Psychic, false, {ConditionType::Charm}, 100, 1}, // 10 minutes
            {"Detect Magic", Domain::Spiritual, 10, "Perceive and identify magic effects within 30 feet for 1 minute.", SpellRange::Self, false, 0, 0, false, DamageType::Psychic, false, {}, 10, 1}, // 1 minute
            {"Unconscious Touch", Domain::Spiritual, 30, "Curse a target to fall unconscious for 10 minutes.", SpellRange::Touch, true, 0, 0, false, DamageType::Psychic, false, {ConditionType::Unconscious}, 100, 1}, // 10 minutes
            {"Mind Shackle", Domain::Spiritual, 13, "Briefly dominate a target's will (1 minute).", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Psychic, false, {ConditionType::Charm}, 10, 1}, // 1 minute
            {"Conjure damage or healing", Domain::Spiritual, 1, "Manifest spiritual energy to harm or heal.", SpellRange::Touch, true, 1, 6, false, DamageType::Force, false, {}, 100, 1}, // Attack-like behavior, 100 rounds

            // Bless spells (Spiritual domain, apply beneficial conditions to allies)
            {"Light", Domain::Spiritual, 2, "Conjure magical light that illuminates a 120-foot radius around the caster for 10 minutes, functioning like a torch.", SpellRange::Self, false, 0, 0, false, DamageType::Radiant, false, {}, 100, 1},

            // Bless spells (Spiritual domain, apply beneficial conditions to allies)
            {"Bless: Dodging", Domain::Spiritual, 2, "Bless an ally; enemies have disadvantage on attacks against them.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {ConditionType::Dodging}, 100, 1},
            {"Bless: Calm", Domain::Spiritual, 3, "Bless a willing target with calm; they cannot take hostile actions (useful for defusing aggression).", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {ConditionType::Calm}, 100, 1},
            {"Bless: Hidden", Domain::Spiritual, 3, "Bless an ally with concealment; creatures cannot perceive them without a high Perception check.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {ConditionType::Hidden}, 100, 1},
            {"Bless: Invisible", Domain::Spiritual, 4, "Bless an ally with true invisibility; they cannot be seen.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {ConditionType::Invisible}, 100, 1},
            {"Bless: Invulnerable", Domain::Spiritual, 11, "Bless an ally with divine invulnerability; they are immune to all damage.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {ConditionType::Invulnerable}, 100, 1},
            {"Bless: Resistant", Domain::Spiritual, 6, "Bless an ally with resistance; they take half damage from one damage type.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {ConditionType::Resistance}, 100, 1},
            {"Bless: Silent", Domain::Spiritual, 4, "Bless an ally with silence; they make no sound.", SpellRange::Touch, false, 0, 0, false, DamageType::Force, false, {ConditionType::Silent}, 100, 1},

            // Curse spells (Spiritual domain, apply harmful conditions to enemies)
            {"Curse: Bleed", Domain::Spiritual, 2, "Curse a target to bleed; they take 1d4 damage per stack at the start of each of their turns. Stacks.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Bleed}, 100, 1},
            {"Curse: Blinded", Domain::Spiritual, 2, "Curse a target with blindness; they cannot see.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Blinded}, 100, 1},
            {"Curse: Charmed", Domain::Spiritual, 2, "Curse a target with charm; they cannot harm you and you have advantage on social checks against them.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Charm}, 100, 1},
            {"Curse: Confused", Domain::Spiritual, 2, "Curse a target with confusion; their actions cost double AP.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Confused}, 100, 1},
            {"Curse: Dazed", Domain::Spiritual, 2, "Curse a target with daze; they can only take one action per turn.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Dazed}, 100, 1},
            {"Curse: Deafened", Domain::Spiritual, 2, "Curse a target with deafness; they cannot hear.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Deafened}, 100, 1},
            {"Curse: Depleted", Domain::Spiritual, 5, "Curse a target with depletion; they do not automatically regain AP at the start of their turn.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Depleted}, 100, 1},
            {"Curse: Enraged", Domain::Spiritual, 1, "Curse a target with enrage; they must focus on you and attacking others costs double AP.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Enraged}, 100, 1},
            {"Curse: Exhausted", Domain::Spiritual, 2, "Curse a target with exhaustion; they suffer penalties to all checks.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Exhausted}, 100, 1},
            {"Curse: Fever", Domain::Spiritual, 4, "Curse a target with fever; they have disadvantage on attack rolls.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Fever}, 100, 1},
            {"Curse: Frightened", Domain::Spiritual, 2, "Curse a target with fear; they cannot approach you and attacks have disadvantage.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Fear}, 100, 1},
            {"Curse: Poisoned", Domain::Spiritual, 3, "Curse a target with poison; they have disadvantage on checks.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Poisoned}, 100, 1},
            {"Curse: Prone", Domain::Spiritual, 2, "Curse a target to fall prone; they are laying down.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Prone}, 100, 1},
            {"Curse: Restrained", Domain::Spiritual, 4, "Curse a target with restraint; they cannot move.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Restrained}, 100, 1},
            {"Curse: Slowed", Domain::Spiritual, 1, "Curse a target with slowness; they move at half speed.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Slowed}, 100, 1},
            {"Curse: Stunned", Domain::Spiritual, 3, "Curse a target with stun; they take double AP to perform any action.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Stunned}, 100, 1},
            {"Curse: Vulnerable", Domain::Spiritual, 10, "Curse a target with vulnerability; they take double damage from a damage type.", SpellRange::ThirtyFt, true, 0, 0, false, DamageType::Force, false, {ConditionType::Vulnerable}, 100, 1}
        };
    }

    std::vector<Spell> spells_;
    std::vector<Spell> custom_spells_;
    mutable std::mutex mutex_;
};

} // namespace rimvale

#endif // RIMVALE_SPELL_REGISTRY_H
