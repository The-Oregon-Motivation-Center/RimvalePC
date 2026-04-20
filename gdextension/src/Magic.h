#ifndef RIMVALE_MAGIC_H
#define RIMVALE_MAGIC_H

#include <cmath>
#include <algorithm>
#include <vector>
#include <string>
#include <map>
#include "Dice.h"
#include "Character.h"

namespace rimvale {

enum class SpellDuration { Instant, OneMinute, TenMinutes, OneHour, OneDay };
enum class SpellRange { Self, Touch, FifteenFt, ThirtyFt, OneHundredFt, FiveHundredFt, OneThousandFt };
enum class SpellArea { Single, Small, Large, Massive };
enum class SpellType { Attack, Ally, SavingThrow };
enum class DiceSize { D4 = 4, D6 = 6, D8 = 8, D10 = 10, D12 = 12 };

struct SpellParameters {
    int effect_sp = 0;
    SpellDuration duration = SpellDuration::Instant;
    SpellRange range = SpellRange::Self;
    int extra_targets = 0;
    SpellType type = SpellType::Ally;
    int beneficial_cond = 0;
    int harmful_cond = 0;
    SpellArea area = SpellArea::Single;
    Domain domain = Domain::Physical;
    bool is_proficient = false;
};

struct SustainedSpell {
    std::string name;
    SpellParameters params;
    int sp_cost;
    int remaining_duration_rounds;
    bool bound_to_focus;
};

class MagicSystem {
public:
    static int get_base_sp_pool(const Character& caster) {
        int base_stat_points = 6 + (caster.get_level() - 1);
        int base_sp = 3 + base_stat_points + caster.get_level();

        int tier = caster.get_feat_tier(FeatID::ArcaneWellspring);
        if (tier >= 5) {
            base_sp = (3 * caster.get_stats_const().divinity) + caster.get_level() + 3;
        } else if (tier >= 1) {
            base_sp = (2 * caster.get_stats_const().divinity) + caster.get_level() + 3;
        }

        return base_sp;
    }

    static int get_damage_healing_sp(DiceSize die, int count) {
        int base = 0;
        switch (die) {
            case DiceSize::D4: base = 1; break;
            case DiceSize::D6: base = 2; break;
            case DiceSize::D8: base = 3; break;
            case DiceSize::D10: base = 4; break;
            case DiceSize::D12: base = 5; break;
            default: base = 1;
        }
        if (count <= 1) return base;

        int total = base;
        for (int i = 2; i <= count; ++i) {
            total += i;
        }
        return total;
    }

    static int calculate_sp_cost(const SpellParameters& p) {
        int type_val = (p.type == SpellType::SavingThrow) ? 1 : 0;

        int duration_mult = 1;
        switch (p.duration) {
            case SpellDuration::Instant: duration_mult = 0; break;
            case SpellDuration::OneMinute: duration_mult = 2; break;
            case SpellDuration::TenMinutes: duration_mult = 3; break;
            case SpellDuration::OneHour: duration_mult = 5; break;
            case SpellDuration::OneDay: duration_mult = 10; break;
            default: duration_mult = 1;
        }

        int range_val = 0;
        switch (p.range) {
            case SpellRange::Self: case SpellRange::Touch: range_val = 0; break;
            case SpellRange::FifteenFt: range_val = 1; break;
            case SpellRange::ThirtyFt: range_val = 2; break;
            case SpellRange::OneHundredFt: range_val = 3; break;
            case SpellRange::FiveHundredFt: range_val = 6; break;
            case SpellRange::OneThousandFt: range_val = 10; break;
            default: range_val = 0;
        }

        int targets_val = 0;
        if (p.extra_targets > 0) {
            targets_val = (int)(2 * (std::pow(2, p.extra_targets) - 1));
        }

        int area_mult = 1;
        switch (p.area) {
            case SpellArea::Single: area_mult = 1; break;
            case SpellArea::Small: area_mult = 2; break;
            case SpellArea::Large: area_mult = 3; break;
            case SpellArea::Massive: area_mult = 10; break;
            default: area_mult = 1;
        }

        int effect_term = (p.duration == SpellDuration::Instant) ? p.effect_sp : (p.effect_sp * duration_mult);
        int base_sp = type_val + effect_term + range_val + targets_val - p.beneficial_cond + p.harmful_cond;

        if (base_sp <= 0) base_sp = 1;

        int total_cost = base_sp * area_mult;

        int penalty = get_mastery_penalty(total_cost, p.is_proficient);
        return total_cost + penalty;
    }

    static int get_mastery_penalty(int sp_cost, bool is_proficient) {
        if (is_proficient) return 0;
        if (sp_cost <= 4) return 0;
        if (sp_cost <= 7) return 4;
        return 6;
    }

    static int get_alignment_pool_modifier(Alignment caster_alignment, Alignment region_alignment) {
        if (caster_alignment == region_alignment) return 0;
        if (caster_alignment == Alignment::Unity) return (region_alignment == Alignment::Void) ? 2 : -2;
        if (caster_alignment == Alignment::Void) return (region_alignment == Alignment::Chaos) ? 2 : -2;
        if (caster_alignment == Alignment::Chaos) return (region_alignment == Alignment::Unity) ? 2 : -2;
        return 0;
    }

    static std::string handle_overreach(Character& caster, Domain domain, int sp_cost, bool one_beyond, bool two_beyond, Dice& dice) {
        if (!one_beyond && !two_beyond) return "Success";
        int dc = two_beyond ? (15 + sp_cost) : (10 + sp_cost);
        RollResult res = caster.roll_skill_check(dice, SkillType::Arcane);
        if (res.total >= dc) return "Success";
        return apply_overreach_effect(caster, domain, dice.roll(10), dice);
    }

private:
    static std::string apply_overreach_effect(Character& c, Domain domain, int roll, Dice& d) {
        switch (domain) {
            case Domain::Biological:
                switch (roll) {
                    case 1: c.current_hp_ -= d.roll(6, 2); return "Backfire: 2d6 poison dmg, Unconscious (1rd), Poisoned (1hr).";
                    case 2: return "Rapid plant growth restrains caster (DC 15 escape).";
                    case 3: { int months = d.roll(10); c.restore_sp(d.roll(4, months)); return "Aged " + std::to_string(months) + " months. Gained " + std::to_string(months) + "d4 SP."; }
                    case 4: return "All healing effects reversed for 1 hour.";
                    case 5: return "Afflicted with random disease (-1 stat until LR).";
                    case 6: return "Hostile animals (Danger 0-3) drawn for 1 hour.";
                    case 7: return "Skin sprouts bark: Disadvantage Speechcraft (1 day).";
                    case 8: { int loss = d.roll(4); c.current_hp_ -= loss; return "Vitality drain: -" + std::to_string(loss) + " Max HP until LR."; }
                    case 9: return "Stunned for 1 minute (wild growth).";
                    case 10: return "Minor mutation (1 week). Cannot speak (1hr).";
                    default: return "Minor Biological fluctuation.";
                }
            case Domain::Chemical:
                switch (roll) {
                    case 1: c.current_hp_ -= d.roll(6, 2); return "Chemical explosion: 2d6 fire dmg, pushed 10ft.";
                    case 2: return "Toxic fumes: Blinded and Poisoned (1hr).";
                    case 3: return "Metal items corrode (2d4 dmg, bypasses DT).";
                    case 4: return "Skin changes color (24hr). Disadvantage Sneak.";
                    case 5: return "Chain reaction: Nearby object/person affected.";
                    case 6: return "Lost taste/smell (1 day). Blind or Deaf (d6).";
                    case 7: return "Sticky residue: Disadvantage Speed checks (1hr).";
                    case 8: { int sp = d.roll(4, 2); c.current_sp_ = std::max(0, c.current_sp_ - sp); return "Energy drain: -" + std::to_string(sp) + " SP + Fog (10 min)."; }
                    case 9: return "Dazed by fumes: Disadvantage all checks (1hr).";
                    case 10: return "Hair/fur/feathers ignite or dissolve.";
                    default: return "Unstable chemical reaction.";
                }
            case Domain::Physical:
                switch (roll) {
                    case 1: c.current_hp_ -= d.roll(6, 2); return "Spell rebound: 2d6 force dmg, pushed 15ft + Prone.";
                    case 2: return "Knocked prone and Stunned (1 min).";
                    case 3: return "Gravity shifts: Half speed (1d4 hrs).";
                    case 4: return "Muscles seize: Half speed, Disadvantage Strength (1hr).";
                    case 5: return "All held items (except clothes/armor) flung 30ft.";
                    case 6: return "Voice lost (1d6 hours).";
                    case 7: return "Minor earthquake: Everyone 30ft prone (1 min).";
                    case 8: return "Bones ache: Disadvantage STR/SPD (24hr).";
                    case 9: { int ap = d.roll(4, 2); c.current_ap_ = std::max(1, c.current_ap_ - ap); return "Vitality drain: -" + std::to_string(ap) + " AP (1hr)."; }
                    case 10: return "Glow faintly (1hr). Disadvantage Stealth.";
                    default: return "Physical feedback loop.";
                }
            case Domain::Spiritual:
                switch (roll) {
                    case 1: return "Random curse (1 hour).";
                    case 2: return "Forgets how to cast (1hr). Sustained spells suppressed.";
                    case 3: return "Shift toward Chaos (1hr). Disadvantage Mind Control/Speechcraft.";
                    case 4: return "Effect reversed or targets random creature.";
                    case 5: return "Teleported 1d10x10 feet (force dmg if in wall).";
                    case 6: return "Speaks in tongues (1hr).";
                    case 7: return "Illusory duplicates: Disadvantage on attacks AND incoming help.";
                    case 8: { int sp = d.roll(4); c.current_sp_ = std::max(0, c.current_sp_ - sp); return "Mind drain: -" + std::to_string(sp) + " SP, Disadvantage Intellect."; }
                    case 9: return "Compelled to speak only truth (1hr).";
                    case 10: return "Phases out: Intangible 1rd every min (1hr). Cannot cast.";
                    default: return "Spiritual dissonance.";
                }
            default: return "Overreach occurred.";
        }
    }
};

class LifeSacrifice {
public:
    struct SacrificeResult {
        int sp_gained = 0;
        int months_aged = 0;
        std::string status;
    };

    static SacrificeResult perform_sacrifice(Character& caster, int dice_count, int dice_sides, int& current_dc, Dice& dice) {
        SacrificeResult res;
        res.sp_gained = dice.roll(dice_sides, dice_count);
        res.months_aged = res.sp_gained;

        RollResult check = caster.roll_stat_check(dice, StatType::Vitality);
        if (check.total < current_dc) {
            res.status = "Failed Vitality check: +1 Exhaustion, +1 Insanity.";
            caster.get_status().add_condition(ConditionType::Exhausted);
            caster.set_insanity_level(caster.get_insanity_level() + 1);
        } else {
            res.status = "Success";
        }

        current_dc += 2;
        caster.current_hp_ = std::max(1, caster.current_hp_ - res.months_aged);
        caster.restore_sp(res.sp_gained);

        return res;
    }
};

} // namespace rimvale

#endif // RIMVALE_MAGIC_H
