#ifndef RIMVALE_MILITIA_H
#define RIMVALE_MILITIA_H

#include "Creature.h"
#include <string>
#include <algorithm>

namespace rimvale {

// ── Equipment tier ─────────────────────────────────────────────────────────
enum class EquipmentTier {
    Improvised = 0,  // AC 14, +0 dmg
    Standard   = 1,  // AC 16, +2 dmg
    Elite      = 2,  // AC 18, +5 dmg
    Advanced   = 3   // AC 20, +8 dmg
};

// ── Militia type (d15 or pick) ─────────────────────────────────────────────
enum class MilitiaType {
    Guard            =  0,  // +3 AC, hold-ground specialists
    Raid             =  1,  // +2 attack & damage, offensive skirmishers
    Recon            =  2,  // +2 tracking & stealth checks
    Sacred           =  3,  // Healing costs –2 SP (min 1)
    Arcane           =  4,  // Can cast rituals
    Hunter           =  5,  // +2 attack vs Large+; +5 tracking creatures
    MerchantGuard    =  6,  // Ranged ambushes suffer disadvantage vs them; +3 threat recognition
    Engineer         =  7,  // Deploy half-cover barricades once per combat
    Nomad            =  8,  // Movement +10 ft; ignore difficult terrain
    Seafaring        =  9,  // Advantage on water/boarding/naval checks
    Crusader         = 10,  // When bloodied: +2 attack & damage until routed
    Shadow           = 11,  // Advantage on ambushes; crits on 18–20
    ArcaneReclaimer  = 12,  // +2 Arcane checks; once/combat dispel magical effect (DC 15)
    Storm            = 13,  // Resistance to lightning & thunder damage
    IronLegionnaire  = 14   // +1 AC and +1d4 damage when in formation
};

// ── Militia trait (pick 1; additional traits cost 5 MP each) ──────────────
enum class MilitiaTrait {
    ShieldWall        =  0,  // +2 AC when adjacent to allies
    VolleyFire        =  1,  // Ranged attacks hit multiple targets in a line
    DivineZeal        =  2,  // +1d4 radiant damage vs undead or cursed
    ArcaneDisruption  =  3,  // Suppress magic in 10 ft radius for 1 round
    AmbushTactics     =  4,  // Advantage on initiative and first attack
    BattleChant       =  5,  // Allies within 30 ft gain +1 to morale saves
    SiegeBreakers     =  6,  // +1d8 damage vs fortifications, walls, constructs
    Skirmishers       =  7,  // Movement +10 ft; disengage as free action once/round
    RelentlessPursuit =  8,  // Fleeing enemies provoke opportunity attacks even when disengaging
    Beastmasters      =  9,  // Includes trained animals; +1d6 damage on melee swarms
    IronDiscipline    = 10,  // Immune to fear; morale checks roll with advantage
    GuerillaFighters  = 11,  // No disadvantage in difficult terrain; hide in natural cover as bonus action
    AlchemicalSupport = 12,  // Once/battle per unit: 1d6 fire or poison in 10 ft radius
    BannerOfUnity     = 13,  // While standard-bearer alive: all allies within 60 ft reroll 1 failed save/combat
    BloodOath         = 14,  // Morale failure never causes flee — fight to the death
    VoidTouchedFrenzy = 15,  // +1d6 damage/attack; morale auto-breaks at 50% losses (then attack anything nearby)
    AdvancedTech      = 16   // Access to Arcane weapons/vehicles (Metropolitan/Land of Tomorrow only)
};

// ── Commander role (d4 or assign; None = no commander; costs 1 MP each) ────
// Commander units gain +10 HP and +2 AC
enum class CommanderRole {
    None      = -1,
    Veteran   =  0,  // +1 to all attack rolls
    Tactician =  1,  // +1 to all skill checks
    Priest    =  2,  // +1d4 healing per round to one ally
    Mage      =  3   // Casting spells costs 3 SP less (minimum 1)
};

class Militia : public Creature {
public:
    Militia(const std::string& name, MilitiaType type, int level,
            int member_count,
            EquipmentTier tier       = EquipmentTier::Standard,
            MilitiaTrait  trait      = MilitiaTrait::IronDiscipline,
            CommanderRole commander  = CommanderRole::None)
        : Creature(name, CreatureCategory::Adversary, level),
          militia_type_(type),
          equipment_tier_(tier),
          militia_trait_(trait),
          commander_role_(commander),
          member_count_(member_count),
          max_members_(member_count),
          // Morale = Equipment tier bonus + VIT score (GMG Step 7)
          morale_(static_cast<int>(tier) + 1   // +1 per equipment tier (Improvised=1, Standard=2, Elite=3, Advanced=4)
                 + 0)                           // VIT added post-init in constructor body after stats are set
    {
        // Override abilities with militia-specific set
        abilities_.clear();

        // Universal militia actions
        abilities_.push_back({"Formation Attack", 1, 0,
            "Coordinated strike: (members/3)d6 damage. Disciplined units roll with advantage."});
        abilities_.push_back({"Hold the Line", 2, 0,
            "Unit braces — gains +2 AC until next turn; enemies have disadvantage on attack rolls."});

        // Type-specific abilities
        switch (type) {
            case MilitiaType::Guard:
                abilities_.push_back({"Shield Wall", 2, 0,
                    "Adjacent friendly units gain +2 AC. Militia becomes Restrained until next turn."});
                break;
            case MilitiaType::Raid:
                abilities_.push_back({"Breach", 2, 0,
                    "Charge attack: +4 dmg, knocks target prone on hit."});
                break;
            case MilitiaType::Recon:
                abilities_.push_back({"Ghost March", 1, 0,
                    "Move silently: gain stealth until attacking. +2 to first attack from hiding."});
                break;
            case MilitiaType::Sacred:
                abilities_.push_back({"Consecrated Ground", 1, 2,
                    "Allies in 15 ft heal 1d4 HP at start of their turn for 2 rounds."});
                abilities_.push_back({"Divine Smite", 2, 1,
                    "Next Formation Attack deals +2d6 radiant damage."});
                break;
            case MilitiaType::Arcane:
                abilities_.push_back({"Arcane Volley", 2, 2,
                    "Ranged AoE: 2d8 elemental damage to enemies in 20 ft cone."});
                abilities_.push_back({"Runic Ward", 1, 1,
                    "Grant resistance to one damage type until next turn."});
                break;
            case MilitiaType::Hunter:
                abilities_.push_back({"Marked Quarry", 1, 0,
                    "Mark one target: +2 dmg and can't hide from this unit for 3 rounds."});
                abilities_.push_back({"Volley", 2, 0,
                    "Ranged: (members/2)d6 damage to one target or spread."});
                break;
            case MilitiaType::MerchantGuard:
                abilities_.push_back({"Protective Escort", 1, 0,
                    "Adjacent non-combatants cannot be targeted while unit is conscious."});
                break;
            case MilitiaType::Engineer:
                abilities_.push_back({"Fortify Position", 3, 0,
                    "Erect improvised barrier: +4 AC cover for allies behind it."});
                abilities_.push_back({"Demolish", 2, 0,
                    "Destroy cover or structure section; enemies in area take 2d6 damage."});
                break;
            case MilitiaType::Nomad:
                abilities_.push_back({"Flanking Rush", 2, 0,
                    "Move around enemy formation: attack with advantage, ignore opportunity attacks this turn."});
                break;
            case MilitiaType::Seafaring:
                abilities_.push_back({"Boarding Action", 2, 0,
                    "Grapple enemy unit; both units are restrained until one breaks free."});
                break;
            case MilitiaType::Crusader:
                abilities_.push_back({"Aura of Courage", 0, 1,
                    "Passive: Allies within 20 ft are immune to the Frightened condition."});
                abilities_.push_back({"Holy Strike", 2, 1,
                    "Next attack is +2d6 radiant and ignores resistances."});
                break;
            case MilitiaType::Shadow:
                abilities_.push_back({"Vanish", 1, 0,
                    "Unit becomes hidden; next attack has advantage and deals +1d8 damage."});
                abilities_.push_back({"Eliminate", 3, 0,
                    "Single-target: 3d8 damage; target must save or be Stunned 1 round."});
                break;
            case MilitiaType::ArcaneReclaimer:
                abilities_.push_back({"Arcane Suppression", 2, 1,
                    "+2 to Arcane checks; once/combat dispel one ongoing magical effect (DC 15)."});
                break;
            case MilitiaType::Storm:
                abilities_.push_back({"Lightning Barrage", 2, 2,
                    "30 ft line: 3d6 lightning to all enemies; targets must save or be Slowed."});
                abilities_.push_back({"Storm Resistance", 0, 0,
                    "Passive: Resistance to lightning and thunder damage."});
                break;
            case MilitiaType::IronLegionnaire:
                abilities_.push_back({"Phalanx", 2, 0,
                    "Immovable formation: +1 AC and +1d4 damage; unit cannot be moved or knocked prone."});
                abilities_.push_back({"Legion Crush", 3, 0,
                    "Advance as wall: push all enemies back 10 ft, deal 2d8 bludgeoning."});
                break;
        }

        // Trait-specific abilities (GMG Step 5)
        switch (trait) {
            case MilitiaTrait::ShieldWall:
                abilities_.push_back({"Shield Wall", 0, 0,
                    "Passive: +2 AC when adjacent to allied units."});
                break;
            case MilitiaTrait::VolleyFire:
                abilities_.push_back({"Volley Fire", 2, 0,
                    "Ranged attacks hit all targets in a 30 ft line."});
                break;
            case MilitiaTrait::DivineZeal:
                abilities_.push_back({"Divine Zeal", 0, 0,
                    "Passive: +1d4 radiant damage vs undead or cursed targets."});
                break;
            case MilitiaTrait::ArcaneDisruption:
                abilities_.push_back({"Arcane Disruption", 2, 1,
                    "Suppress all magic in a 10 ft radius for 1 round."});
                break;
            case MilitiaTrait::AmbushTactics:
                abilities_.push_back({"Ambush Tactics", 0, 0,
                    "Passive: Advantage on initiative rolls and the first attack of each encounter."});
                break;
            case MilitiaTrait::BattleChant:
                abilities_.push_back({"Battle Chant", 1, 0,
                    "Allies within 30 ft gain +1 to all morale-based saves for 1 round."});
                break;
            case MilitiaTrait::SiegeBreakers:
                abilities_.push_back({"Siege Breakers", 0, 0,
                    "Passive: +1d8 damage against fortifications, walls, or constructs."});
                break;
            case MilitiaTrait::Skirmishers:
                abilities_.push_back({"Skirmishers", 0, 0,
                    "Passive: Movement +10 ft; disengage as a free action once per round."});
                break;
            case MilitiaTrait::RelentlessPursuit:
                abilities_.push_back({"Relentless Pursuit", 0, 0,
                    "Passive: Fleeing enemies provoke opportunity attacks even when disengaging."});
                break;
            case MilitiaTrait::Beastmasters:
                abilities_.push_back({"Beast Swarm", 2, 0,
                    "Trained animals in the unit attack: +1d6 damage on melee swarms."});
                break;
            case MilitiaTrait::IronDiscipline:
                abilities_.push_back({"Iron Discipline", 0, 0,
                    "Passive: Immune to fear effects; all morale checks roll with advantage."});
                break;
            case MilitiaTrait::GuerillaFighters:
                abilities_.push_back({"Guerilla Fighters", 0, 0,
                    "Passive: No disadvantage in difficult terrain; hide in natural cover as a bonus action."});
                break;
            case MilitiaTrait::AlchemicalSupport:
                abilities_.push_back({"Alchemical Bomb", 2, 0,
                    "Once/battle per unit: 1d6 fire or poison damage in a 10 ft radius."});
                break;
            case MilitiaTrait::BannerOfUnity:
                abilities_.push_back({"Banner of Unity", 0, 0,
                    "While standard-bearer is alive, all allies within 60 ft may reroll 1 failed save per combat."});
                break;
            case MilitiaTrait::BloodOath:
                abilities_.push_back({"Blood Oath", 0, 0,
                    "Passive: Morale failure never causes retreat. Fight to the last member."});
                break;
            case MilitiaTrait::VoidTouchedFrenzy:
                abilities_.push_back({"Void Frenzy", 0, 0,
                    "Passive: +1d6 damage/attack; morale auto-breaks at 50% losses, then attacks anything nearby."});
                break;
            case MilitiaTrait::AdvancedTech:
                abilities_.push_back({"Arcane Weaponry", 2, 0,
                    "Access to Arcane Batons, Arcane Rifles, and Arcane Shields (Metropolitan/Tomorrow only)."});
                break;
        }

        // Commander abilities (GMG Step 6)
        switch (commander) {
            case CommanderRole::Veteran:
                abilities_.push_back({"Veteran's Eye", 0, 0,
                    "Passive: +1 to all attack rolls. Commander has +10 HP and +2 AC."});
                break;
            case CommanderRole::Tactician:
                abilities_.push_back({"Tactical Direction", 0, 0,
                    "Passive: +1 to all skill checks. Commander has +10 HP and +2 AC."});
                break;
            case CommanderRole::Priest:
                abilities_.push_back({"Field Healing", 1, 0,
                    "Heal one ally for 1d4 HP per round. Commander has +10 HP and +2 AC."});
                break;
            case CommanderRole::Mage:
                abilities_.push_back({"Mage's Economy", 0, 0,
                    "Passive: All spells cast by this unit cost 3 SP less (minimum 1). Commander has +10 HP and +2 AC."});
                break;
            default: break;
        }

        // Morale: finish initialization with VIT after Creature constructor set stats_
        // GMG formula: Equipment tier bonus (already set in member init) + VIT score
        morale_ += stats_.vitality;

        // Must reset after all member vars are set
        current_hp_ = get_max_hp();
        current_ap_ = get_max_ap();
        current_sp_ = get_max_sp();
    }

    virtual ~Militia() = default;

    // ── Formulas ──────────────────────────────────────────────────────────────
    // Shared HP pool: 10 × Level + VIT
    [[nodiscard]] int get_max_hp() const override {
        return (10 * level_) + stats_.vitality;
    }
    [[nodiscard]] int get_max_ap() const override { return 10 + stats_.strength; }
    [[nodiscard]] int get_max_sp() const override { return 3 + level_ + stats_.divinity; }

    [[nodiscard]] int get_movement_speed() const override {
        if (status_.has_condition(ConditionType::Restrained) ||
            status_.has_condition(ConditionType::Paralyzed)) return 0;
        int base = 25;
        if (militia_type_ == MilitiaType::Recon || militia_type_ == MilitiaType::Nomad) base = 35;
        if (militia_type_ == MilitiaType::IronLegionnaire) base = 20;
        if (militia_trait_ == MilitiaTrait::Skirmishers) base += 10;
        int spd = std::max(0, base - speed_penalty_);
        return status_.has_condition(ConditionType::Slowed) ? spd / 2 : spd;
    }

    // ── Armor class ───────────────────────────────────────────────────────────
    [[nodiscard]] int get_armor_class() const {
        int ac = 0;
        switch (equipment_tier_) {
            case EquipmentTier::Improvised: ac = 14; break;
            case EquipmentTier::Standard:   ac = 16; break;
            case EquipmentTier::Elite:      ac = 18; break;
            case EquipmentTier::Advanced:   ac = 20; break;
        }
        if (militia_type_ == MilitiaType::Guard)           ac += 3;  // GMG: +3 AC
        if (militia_type_ == MilitiaType::IronLegionnaire) ac += 1;  // GMG: +1 AC in formation
        if (militia_trait_ == MilitiaTrait::ShieldWall)    ac += 2;  // GMG: +2 AC when adjacent to allies
        return ac;
    }

    // ── Damage bonus ──────────────────────────────────────────────────────────
    [[nodiscard]] int get_damage_bonus() const {
        int bonus = 0;
        switch (equipment_tier_) {
            case EquipmentTier::Improvised: bonus = 0; break;
            case EquipmentTier::Standard:   bonus = 2; break;
            case EquipmentTier::Elite:      bonus = 5; break;
            case EquipmentTier::Advanced:   bonus = 8; break;
        }
        if (militia_type_ == MilitiaType::Raid) bonus += 2;
        return bonus;
    }

    // ── Damage / morale ───────────────────────────────────────────────────────
    void take_damage(int amount, Dice& dice, const std::string& damage_type) override {
        // Immunity / resistance from parent
        if (!damage_type.empty() && is_immune_to(damage_type)) return;
        if (!damage_type.empty() && is_resistant_to(damage_type)) amount /= 2;
        current_hp_ = std::max(0, current_hp_ - amount);

        // Morale check: DC = 10 + damage_beyond_morale_threshold
        int damage_beyond = amount - morale_;
        if (damage_beyond > 0) {
            if (militia_trait_ == MilitiaTrait::IronDiscipline && !has_ignored_first_rout_) {
                has_ignored_first_rout_ = true;
            } else {
                int roll = dice.roll(20) + morale_;
                if (roll < 10 + damage_beyond) {
                    morale_ = std::max(0, morale_ - 1);
                    is_routing_ = (morale_ <= 0);
                }
            }
        }
    }

    void reset_resources() override {
        current_hp_  = get_max_hp();
        current_ap_  = get_max_ap();
        current_sp_  = get_max_sp();
        member_count_ = max_members_;
        // GMG morale formula: Equipment tier bonus + VIT score
        morale_       = (static_cast<int>(equipment_tier_) + 1) + stats_.vitality;
        is_routing_   = false;
        has_ignored_first_rout_ = false;
        speed_penalty_ = 0;
        ac_modifier_   = 0;
        dmg_modifier_  = 0;
    }

    // ── Instinct / rout table ─────────────────────────────────────────────────
    std::string roll_rout_result(Dice& dice) {
        switch (dice.roll(4)) {
            case 1: is_routing_ = true;
                    return "Rout! Unit breaks and flees.";
            case 2: morale_ = std::max(0, morale_ - 1);
                    return "Falter! Unit loses cohesion, –1 morale.";
            case 3: morale_ = std::min(15, morale_ + 1);
                    return "Rally! Unit steels itself, +1 morale.";
            case 4: return "Desperate Stand! Unit attacks with advantage next round.";
        }
        return "";
    }

    // ── Queries ───────────────────────────────────────────────────────────────
    [[nodiscard]] bool is_militia() const { return true; }
    [[nodiscard]] bool is_broken()  const { return is_routing_ || current_hp_ <= 0; }
    [[nodiscard]] int  get_member_count()   const { return member_count_; }
    [[nodiscard]] int  get_max_members()    const { return max_members_; }
    [[nodiscard]] int  get_morale()         const { return morale_; }
    [[nodiscard]] MilitiaType   get_militia_type()  const { return militia_type_; }
    [[nodiscard]] MilitiaTrait  get_militia_trait() const { return militia_trait_; }
    [[nodiscard]] CommanderRole get_commander()     const { return commander_role_; }
    [[nodiscard]] EquipmentTier get_equipment_tier()const { return equipment_tier_; }

    // Attack dice: (member_count/3)d6 coordinated
    [[nodiscard]] int get_attack_die_count() const { return std::max(1, member_count_ / 3); }
    [[nodiscard]] int get_ac_modifier()  const { return ac_modifier_; }
    [[nodiscard]] int get_dmg_modifier() const { return dmg_modifier_; }

    void set_morale(int m) { morale_ = std::max(0, m); }
    void set_equipment_tier(EquipmentTier t) { equipment_tier_ = t; }

    // Encounter state
    bool is_routing_             = false;
    bool has_ignored_first_rout_ = false;
    int  ac_modifier_            = 0;
    int  dmg_modifier_           = 0;

private:
    MilitiaType   militia_type_;
    EquipmentTier equipment_tier_;
    MilitiaTrait  militia_trait_;
    CommanderRole commander_role_;
    int member_count_;
    int max_members_;
    int morale_;
};

} // namespace rimvale
#endif // RIMVALE_MILITIA_H
