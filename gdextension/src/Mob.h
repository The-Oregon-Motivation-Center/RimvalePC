#ifndef RIMVALE_MOB_H
#define RIMVALE_MOB_H

#include "Creature.h"
#include <string>
#include <algorithm>

namespace rimvale {

// Emotional state (affects starting behaviour)
enum class MobMood {
    Enraged, Terrified, Jubilant, Desperate, Opportunistic, Frenzied
};

// Emergent traits – roll d12 or pick
enum class MobTrait {
    Firestarters = 0,   // Can ignite objects as group action
    Swarm        = 1,   // Move through obstacles as difficult terrain
    Opportunists = 2,   // +2 to loot/steal actions
    Unstoppable  = 3,   // Ignore the first failed morale check
    QuickLearners= 4,   // +1 attack after each failed attack (max +1/round)
    MobHealers   = 5,   // Heal 1d4 every round as a basic action
    Shadowed     = 6,   // Advantage on stealth at night
    Ironhide     = 7,   // Resistance to non-magical bludgeoning
    Cacophony    = 8,   // Disadvantage on enemy perception & ranged in 300 ft
    RallyingCry  = 9,   // Once/encounter: +2 checks to 30 ft allies
    NimbleFeet   = 10,  // Movement speed +10 ft
    KeenSenses   = 11   // Advantage on perception vs hidden threats
};

// Leader type – roll d10 or pick (–1 = no leader)
enum class MobLeaderType {
    None      = -1,
    Firebrand =  0,  // Once/encounter: +2 attack for one round
    Coward    =  1,  // +2 morale when fleeing, –2 attacks
    Trickster =  2,  // Once/encounter: ignore difficult terrain / bypass barrier
    Brute     =  3,  // +1 dmg per 5 members for one round, –2 AC
    Prophet   =  4,  // Immune to fear effects
    Scavenger =  5,  // Loot/scavenge twice as fast
    Whisperer =  6,  // Near-silence, advantage stealth, –2 AC while sneaking
    Bulwark   =  7,  // +3 AC, –10 ft movement in formation
    Madman    =  8,  // Act twice, roll instinct table at turn end
    Shadow    =  9   // Can hide or disperse instantly
};

class Mob : public Creature {
public:
    Mob(const std::string& name, CreatureCategory category, int level,
        int member_count, int hp_per_member = 1,
        MobTrait trait   = MobTrait::Unstoppable,
        MobLeaderType leader = MobLeaderType::None,
        MobMood mood = MobMood::Enraged)
        : Creature(name, category, level),
          max_members_(member_count),
          member_count_(member_count),
          hp_per_member_(std::max(1, hp_per_member)),
          morale_(10),
          emergent_trait_(trait),
          leader_type_(leader),
          mood_(mood),
          last_morale_threshold_(4)
    {
        abilities_.clear();
        abilities_.push_back({"Mob Attack", 1, 0,
            "Improvised: (members/2)d4 damage. Frenzied adds +1 dmg per 5 members."});
        abilities_.push_back({"Surge", 2, 0,
            "Mob attacks with advantage; attackers have advantage vs mob next round."});
        if (trait == MobTrait::MobHealers)
            abilities_.push_back({"Mob Healing", 1, 0, "Heal 1d4 HP as a basic action."});
        if (trait == MobTrait::RallyingCry)
            abilities_.push_back({"Rallying Cry", 2, 0,
                "Once/encounter: +2 checks for allies in 30 ft for 1 minute."});
        if (leader == MobLeaderType::Firebrand)
            abilities_.push_back({"Firebrand Incite", 2, 0,
                "Once/encounter: mob gains +2 attacks for one round."});
        if (leader == MobLeaderType::Brute)
            abilities_.push_back({"Brute Drive", 2, 0,
                "+1 dmg per 5 members for one round, mob suffers –2 AC."});
        // Call reset after member vars are set so Mob::get_max_hp() is used
        current_hp_  = get_max_hp();
        current_ap_  = get_max_ap();
        current_sp_  = get_max_sp();
    }

    virtual ~Mob() = default;

    // ── Formulas ──────────────────────────────────────────────────────────────
    [[nodiscard]] int get_max_hp() const override {
        return max_members_ * hp_per_member_;
    }
    [[nodiscard]] int get_max_ap() const override { return 10 + stats_.strength; }
    [[nodiscard]] int get_max_sp() const override { return 5 + level_ + stats_.divinity; }

    [[nodiscard]] int get_movement_speed() const override {
        if (status_.has_condition(ConditionType::Restrained) ||
            status_.has_condition(ConditionType::Paralyzed)) return 0;
        int base = 30;
        if (max_members_ <= 20)      base += 5;   // Small mob: +5
        else if (max_members_ >= 51) base -= 5;   // Large mob: –5
        if (emergent_trait_ == MobTrait::NimbleFeet) base += 10;
        int spd = std::max(0, base - speed_penalty_);
        return status_.has_condition(ConditionType::Slowed) ? spd / 2 : spd;
    }

    // ── Damage ────────────────────────────────────────────────────────────────
    void take_damage(int amount, Dice& dice, const std::string& damage_type) override {
        if (emergent_trait_ == MobTrait::Ironhide &&
            (damage_type == "bludgeoning" || damage_type == "physical"))
            amount /= 2;
        current_hp_ = std::max(0, current_hp_ - amount);
        // Recompute living members from remaining HP
        if (hp_per_member_ > 0)
            member_count_ = (current_hp_ + hp_per_member_ - 1) / hp_per_member_;
        is_frenzied_ = (current_hp_ < get_max_hp() / 2);
    }

    void reset_resources() override {
        current_hp_    = get_max_hp();
        current_ap_    = get_max_ap();
        current_sp_    = get_max_sp();
        member_count_  = max_members_;
        is_frenzied_   = false;
        speed_penalty_ = 0;
        ac_modifier_   = 0;
        dmg_modifier_  = 0;
        surge_active_  = false;
        surge_penalty_ = false;
        used_environment_    = false;
        used_rallying_cry_   = false;
        has_used_firebrand_  = false;
        has_ignored_first_morale_ = false;
        last_morale_threshold_ = 4;  // will check at 75%, 50%, 25%, 0%
    }

    // ── Instinct table ────────────────────────────────────────────────────────
    // GMG: morale check triggers each time mob crosses a 25% HP threshold.
    // Call this after every take_damage(); returns false if a threshold was crossed AND morale failed.
    bool check_morale(int damage_taken, Dice& dice) {
        int max = get_max_hp();
        if (max <= 0) return true;
        // Determine which threshold the mob is now at or below
        int threshold_now = (current_hp_ * 4) / max; // 3=75%, 2=50%, 1=25%, 0=dead
        if (threshold_now >= last_morale_threshold_) return true; // no new threshold crossed
        last_morale_threshold_ = threshold_now;

        int dc   = 10 + damage_taken;
        int roll = dice.roll(20) + morale_;
        if (roll < dc) {
            if (emergent_trait_ == MobTrait::Unstoppable && !has_ignored_first_morale_) {
                has_ignored_first_morale_ = true;
                return true;
            }
            morale_ = std::max(0, morale_ - 1);
            return false;
        }
        return true;
    }

    std::string roll_instinct(Dice& dice) {
        ac_modifier_  = 0;
        dmg_modifier_ = 0;
        switch (dice.roll(6)) {
            case 1: dmg_modifier_= 2; ac_modifier_=-2;
                    return "Frenzy! All attacks +2, AC –2.";
            case 2: return "Scatter! Half the mob flees or hides.";
            case 3: { int h=dice.roll(6);
                    current_hp_=std::min(get_max_hp(),current_hp_+h);
                    member_count_=(current_hp_+hp_per_member_-1)/hp_per_member_;
                    morale_=std::min(15,morale_+1);
                    return "Rally! Mob regains "+std::to_string(h)+" HP and morale."; }
            case 4: return "Grab! Mob attempts to grapple a target.";
            case 5: return "Loot! Mob focuses on valuables.";
            case 6: return "Chant! Nearby spellcasting disrupted.";
        }
        return "";
    }

    std::string roll_frenzied_tactic(Dice& dice) {
        ac_modifier_  = 0;
        dmg_modifier_ = 0;
        switch (dice.roll(4)) {
            case 1: return "Focused Assault! All attacks on one enemy.";
            case 2: return "Wild Swing! Attacks split among nearby targets.";
            case 3: ac_modifier_=2; dmg_modifier_=-2;
                    return "Defensive Huddle! AC +2, damage –2.";
            case 4: return "Mob Madness! Randomly targets friend or foe.";
        }
        return "";
    }

    // ── Combat helpers ────────────────────────────────────────────────────────
    [[nodiscard]] virtual bool is_mob() const { return true; }

    [[nodiscard]] int get_member_count() const { return member_count_; }
    [[nodiscard]] int get_max_members()  const { return max_members_; }
    [[nodiscard]] int get_morale()       const { return morale_; }
    [[nodiscard]] bool is_frenzied()     const { return is_frenzied_; }
    [[nodiscard]] MobTrait      get_trait()       const { return emergent_trait_; }
    [[nodiscard]] MobLeaderType get_leader_type() const { return leader_type_; }
    [[nodiscard]] int get_hp_per_member() const { return hp_per_member_; }

    // Attack dice: (member_count/2)d4 improvised
    [[nodiscard]] int get_attack_die_count() const { return std::max(1, member_count_/2); }
    [[nodiscard]] int get_ac_modifier()  const { return ac_modifier_; }
    [[nodiscard]] int get_dmg_modifier() const {
        int mod = dmg_modifier_;
        if (is_frenzied_) mod += member_count_ / 5; // frenzied bonus
        return mod;
    }

    void set_morale(int m) { morale_ = std::max(0, m); }

    // Encounter state flags
    bool surge_active_       = false;
    bool surge_penalty_      = false;
    bool used_environment_   = false;
    bool used_rallying_cry_  = false;
    bool has_used_firebrand_ = false;

private:
    int  max_members_;
    int  member_count_;
    int  hp_per_member_;
    int  morale_;
    MobTrait      emergent_trait_;
    MobLeaderType leader_type_;
    MobMood       mood_;
    bool is_frenzied_             = false;
    bool has_ignored_first_morale_= false;
    int  ac_modifier_             = 0;
    int  dmg_modifier_            = 0;
    int  last_morale_threshold_   = 4;  // tracks which 25% HP threshold was last crossed (4=full,3=75%,2=50%,1=25%,0=0%)
};

} // namespace rimvale
#endif // RIMVALE_MOB_H
