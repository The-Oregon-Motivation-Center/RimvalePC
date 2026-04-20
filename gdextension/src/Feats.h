#ifndef RIMVALE_FEATS_H
#define RIMVALE_FEATS_H

#include <string>
#include <vector>
#include <map>
#include <algorithm>

namespace rimvale {

enum class FeatID {
    // Stat Feats
    ArcaneWellspring, IronVitality, MartialFocus, Safeguard,

    // Weapons and Combat Feats
    AssassinsExecution, CrimsonEdge, DuelistsPath, EffectShaper, FurysCall,
    GraspOfTheTitan, ImprovisedWeaponMastery, IronFist, IronHammer, IronThorn,
    LinebreakersAim, MartialProwess, PreciseTactician, RestAndRecovery,
    SwiftStriker, TitanicDamage, TurnTheBlade, TwinFang, UnyieldingDefender, WeaponMastery,

    // Armor Feats
    BalancedBulwark, DeflectiveStance, ElementalWard, EvasiveWard,
    TitanicBastion, TowerShield, WallOfTheBattered, UnarmoredMaster, Warp,

    // Magic Feats
    ArcaneSeal, BloodMagic, CreateDemiplane, GraspOfTheForgotten, MagicExpertise,
    MasterOfCeremonies, Scryer, ShapeshiftersPath, SpellShaper, SoulWeaver, TransmutersPrecision,

    // Alignment Feats
    ChaosPact, ChaosScholar, UnityPact, UnityScholar, VoidPact, VoidScholar,

    // Domain Feats
    BiologicalDomain, ChemicalDomain, PhysicalDomain, SpiritualDomain,

    // Exploration Feats
    AgileExplorer, ExplorersGrit, HealingRestoration, IllusionDeception,
    MindOverChallenge, MinionMaster, StealthSubterfuge, TemporalTouch,

    // Crafting Feats
    AlchemistsSupplies, ArtisansTools, CalligraphersSupplies, CraftingArtifice,
    CulinaryVirtuoso, DisguiseKit, FishingMastery, HerbalismKit, HuntingMastery,
    JewelersTools, MusicalInstrument, NavigatorsTools, PaintersSupplies,
    PoisonersKit, SmithsTools, ThievesTools, TinkersTools, WeatherwiseTailoring,

    // Apex Feats
    ArcaneOverdrive, BloodOfTheAncients, CataclysmicLeap, DivineReversal,
    EclipseVeil, GravityShatter, HowlOfTheForgotten, IronTempest,
    MythicRegrowth, PhantomLegion, RunebreakerSurge, Soulbrand,
    SoulflarePulse, StormboundMantle, TemporalRift, TitansEcho,
    VoidbrandCurse, WorldbreakerStep,

    // Ascendant Feats
    PsychicMaw, AbyssalUnleashing, AngelicRebirth, CryptbornSovereign,
    DraconicApotheosis, FeyLordsPact, HagMothersCovenant, InfernalCoronation,
    KaijuCoreIntegration, LycanthropicCurse, LichBinding, PrimordialElementalFusion,
    SeraphicFlame, StormboundTitan, VampiricAscension, VoidbornMutation,

    // Miscellaneous Feats
    ArcLightSurge, ArcaneResidue, AstralShear, Bender, BladeScripture,
    BreathOfStone, BarkskinRitual, ChaosFlow, CoinreadersWink, Dreamthief,
    EchoedSteps, Emberwake, ErylonsEcho, FlareOfDefiance, FlickerSparky,
    HollowVoice, HollowedInstinct, IllusoryDouble, LockTapLord, LoreweaversMark,
    MirrorsteelGlint, PlanarGraze, RefractionTwist, ResonantPulse, RuneCipher,
    SacredFragmentation, FeatSacrifice, SkywatchersSight, SparkLeech, SplitSecondRead,
    Soulmark, TemporalShift, TetherLink, VeilbreakerVoice, VerdantPulse,
    VeyrasVeil, UnitysEbb, Whispers
};

struct Feat {
    FeatID id;
    int tier; // 1 to 5
    std::string name;
    std::string description;
    std::string category;
    std::string tree_name;

    Feat(FeatID id, int tier, std::string name, std::string description = "", std::string category = "", std::string tree_name = "")
        : id(id), tier(tier), name(std::move(name)), description(std::move(description)), category(std::move(category)), tree_name(std::move(tree_name)) {}
};

class FeatRegistry {
public:
    static FeatRegistry& instance() {
        static FeatRegistry registry;
        return registry;
    }

    [[nodiscard]] std::vector<Feat> get_feats_by_tier(int tier) const {
        std::vector<Feat> result;
        for (const auto& feat : all_feats_) {
            if (feat.tier == tier) result.push_back(feat);
        }
        return result;
    }

    [[nodiscard]] std::vector<Feat> get_feats_by_category(const std::string& category) const {
        std::vector<Feat> result;
        for (const auto& feat : all_feats_) {
            if (feat.category == category) result.push_back(feat);
        }
        return result;
    }

    [[nodiscard]] std::vector<Feat> get_feats_by_tree(const std::string& tree_name) const {
        std::vector<Feat> result;
        for (const auto& feat : all_feats_) {
            if (feat.tree_name == tree_name) result.push_back(feat);
        }
        std::sort(result.begin(), result.end(), [](const Feat& a, const Feat& b) {
            return a.tier < b.tier;
        });
        return result;
    }

    [[nodiscard]] const Feat* get_feat(FeatID id, int tier) const {
        for (const auto& feat : all_feats_) {
            if (feat.id == id && feat.tier == tier) return &feat;
        }
        return nullptr;
    }

    [[nodiscard]] const Feat* find_feat_by_name(const std::string& name) const {
        for (const auto& feat : all_feats_) {
            if (feat.name == name) return &feat;
        }
        return nullptr;
    }

    [[nodiscard]] bool is_next_available_tier(FeatID id, int current_tier, int requested_tier) const {
        if (requested_tier <= current_tier) return false;

        std::vector<int> available_tiers;
        for (const auto& feat : all_feats_) {
            if (feat.id == id) {
                available_tiers.push_back(feat.tier);
            }
        }
        std::sort(available_tiers.begin(), available_tiers.end());

        for (int t : available_tiers) {
            if (t > current_tier) {
                return t == requested_tier;
            }
        }
        return false;
    }

    [[nodiscard]] const std::vector<Feat>& get_all_feats() const { return all_feats_; }

private:
    FeatRegistry() {
        std::string c_stat = "Stat feats";
        std::string c_combat = "Weapons and Combat feats";
        std::string c_armor = "Armor feats";
        std::string c_magic = "Magic feats";
        std::string c_align = "Alignment feats";
        std::string c_domain = "Domain feats";
        std::string c_ascendant = "Ascendant Feats";
        std::string c_explore = "Exploration feats";
        std::string c_craft = "Crafting feats";
        std::string c_apex = "Apex feats";
        std::string c_misc = "Miscellaneous feats";

        // --- Stat Feats ---
        // Arcane Wellspring (Base: SP = Divinity + Level + 3)
        all_feats_.emplace_back(FeatID::ArcaneWellspring, 1, "Deep Reserves", "Primary: Your SP is now calculated as (2 × Divinity) + (Level) + 3. Secondary: Once per long rest, when you cast a Spell that costs SP, you may reduce the SP cost by your Divinity score (minimum 1).", c_stat, "Arcane Wellspring");
        all_feats_.emplace_back(FeatID::ArcaneWellspring, 3, "Spell Echo", "Primary: When you Spend SP to cast a Spell, you may choose to have the Spell's effect repeat at the start of your next turn as a free action rather than a basic action (once per encounter). Secondary: Once per long rest you can regain a number of SP equal to your Divinity score.", c_stat, "Arcane Wellspring");
        all_feats_.emplace_back(FeatID::ArcaneWellspring, 5, "Infinite Font", "Primary: Your SP is now calculated as (3 × Divinity) + (Level) + 3. Secondary: Once per long rest, when you cast a Spell, you may immediately cast another Spell of equal or lower SP cost without Spending additional SP; additional AP still applies.", c_stat, "Arcane Wellspring");

        // Iron Vitality (Base: HP = 3*Level + Vitality + 3)
        all_feats_.emplace_back(FeatID::IronVitality, 1, "Resilient Frame", "Primary: Your HP is now calculated as (2 × Vitality) + (3 × Level) + 3. Secondary: Once per encounter, when you are reduced to half HP or less, you gain bonus HP equal to your Vitality score.", c_stat, "Iron Vitality");
        all_feats_.emplace_back(FeatID::IronVitality, 3, "Enduring Spirit", "Primary: When you regain HP from any source, increase the amount healed by your Vitality score. Secondary: Once per long rest when you succeed on a saving throw against a condition, you may immediately regain HP equal to your Level.", c_stat, "Iron Vitality");
        all_feats_.emplace_back(FeatID::IronVitality, 5, "Titanic Endurance", "Primary: Your HP is now calculated as (3 × Vitality) + (3 × Level) + 3. Secondary: Once per long rest, when you take damage that would reduce you to 0 HP, you may instead drop to 1 HP if the attack would not kill you outright.", c_stat, "Iron Vitality");

        // Martial Focus (Base: AP = Strength + 3)
        all_feats_.emplace_back(FeatID::MartialFocus, 1, "Battle-Ready", "Primary: Your AP is now calculated as (2 × Strength) + 3. Secondary: Once per encounter, when you Spend AP to use a skill or ability, you may reduce the AP cost by 1 (minimum 1).", c_stat, "Martial Focus");
        all_feats_.emplace_back(FeatID::MartialFocus, 3, "Tactical Surge", "Primary: When you roll initiative, gain bonus AP equal to your Strength score. Secondary: Once per encounter, when you Spend AP to use a skill or ability, you may reduce the AP cost by 1 (minimum 1).", c_stat, "Martial Focus");
        all_feats_.emplace_back(FeatID::MartialFocus, 5, "Unstoppable Assault", "Primary: Your AP is now calculated as (3 × Strength) + 3. Secondary: Once per round on your turn, when you spend AP to make an attack, you may move 5 feet without provoking opportunity attacks.", c_stat, "Martial Focus");

        // Safeguard
        all_feats_.emplace_back(FeatID::Safeguard, 1, "Focused Defense", "Primary: Choose two stats. When making saving throws with these stats, you may use double your stat Score instead of the normal value. Secondary: Once per long rest, reroll a failed saving throw with one of your chosen stats.", c_stat, "Safeguard");
        all_feats_.emplace_back(FeatID::Safeguard, 2, "Hardened Reflexes", "Primary: When making saving throws with your two chosen stats, you may add +2 to the roll in addition to doubling your modifier. Secondary: Once per short rest, gain advantage on a saving throw with one of your chosen stats.", c_stat, "Safeguard");
        all_feats_.emplace_back(FeatID::Safeguard, 3, "Expansive Guard", "Primary: Choose a third stat. You may now use double your stat Score for saving throws with this stat as well as your original two. Secondary: When you succeed on a saving throw with any of your chosen stats, inspire allies within 15ft, granting them +1d4 to their next action.", c_stat, "Safeguard");
        all_feats_.emplace_back(FeatID::Safeguard, 4, "Near-Total Resistance", "Primary: Choose a fourth stat. You may now use double your stat Score for saving throws with this stat as well as your previous choices. Secondary: Once per long rest, automatically succeed on a saving throw with any of your chosen stats.", c_stat, "Safeguard");
        all_feats_.emplace_back(FeatID::Safeguard, 5, "Paragon of Safeguards", "Primary: You now apply the double Score benefit to all stat-based saving throws, regardless of stat. Secondary: Once per short rest, after succeeding on a saving throw, immediately regain HP equal to your level.", c_stat, "Safeguard");

        // --- Weapons and Combat Feats ---
        all_feats_.emplace_back(FeatID::AssassinsExecution, 1, "Lethal Precision", "Primary Effect: When you reduce a creature to 0 HP or below with a melee or ranged attack, you deal an additional dice of weapon damage. Secondary Effect: A number of times equal to your speed score per short rest if you miss with an attack, you deal damage equal to your attack Score (strength or speed score depending on weapon) (Graze effect).", c_combat, "Assassin's Execution");
        all_feats_.emplace_back(FeatID::AssassinsExecution, 2, "Ruthless Finisher", "Primary Effect: When you reduce a creature to 0 HP, if the excess damage (damage dealt beyond 0 HP) is equal to or greater than the creature’s maximum HP, the creature dies instantly. Secondary Effect: Once per short rest, you may automatically critically succeed on attack against a creature that has not yet acted in combat.", c_combat, "Assassin's Execution");
        all_feats_.emplace_back(FeatID::AssassinsExecution, 3, "Death's Hand", "Primary Effect: When you reduce a creature to 0 HP or less without outright killing them, the creature must make a Vitality check (DC = 10 + the excess damage they took below zero). On a failure, the creature dies instantly. On a success, it is left at 0 HP and must make death saving throws as normal. Secondary Effect: When you kill a creature, you gain advantage on attacks for the next minute.", c_combat, "Assassin's Execution");

        all_feats_.emplace_back(FeatID::CrimsonEdge, 2, "Keen Blade", "Primary: Simple slashing damage dice becomes 1d6. Secondary: 1/turn ignore resistance to non-magical slashing.", c_combat, "Crimson Edge");
        all_feats_.emplace_back(FeatID::CrimsonEdge, 3, "Rending Strike", "Primary: Slashing damage dice becomes 1d8. Secondary: 1/turn deal +1 die of damage.", c_combat, "Crimson Edge");
        all_feats_.emplace_back(FeatID::CrimsonEdge, 5, "Severing Blow", "Primary: Slashing damage dice becomes 1d10. Secondary: 1/turn ignore immunity to slashing.", c_combat, "Crimson Edge");

        all_feats_.emplace_back(FeatID::DuelistsPath, 1, "Duelist’s Defiance", "Primary: Parry roll >= attack+5 -> basic attack. Secondary: Parry for adjacent ally while holding shield.", c_combat, "Duelist's Path");
        all_feats_.emplace_back(FeatID::DuelistsPath, 2, "Riposte Master", "Primary: Advantage on next attack after successful Parry. Secondary: Parry ranged weapon attacks.", c_combat, "Duelist's Path");
        all_feats_.emplace_back(FeatID::DuelistsPath, 3, "Wall of Defiance", "Primary: 1/round feint (Free Action) -> +1d4 Parry. Secondary: 1/LR Bastion Form (1 min, Parry for 0 AP).", c_combat, "Duelist's Path");

        all_feats_.emplace_back(FeatID::EffectShaper, 1, "Force of Will", "Primary: Non-spell DC = 10 + 2 x Stat. Secondary: 1/LR force reroll of successful non-spell check.", c_combat, "Effect Shaper");
        all_feats_.emplace_back(FeatID::EffectShaper, 2, "Potent Presence", "Primary: Non-spell DC +2. Secondary: 1/LR pick 2nd target within 5ft if 1st succeeds save.", c_combat, "Effect Shaper");
        all_feats_.emplace_back(FeatID::EffectShaper, 3, "Apex Influence", "Primary: Non-spell DC +1 (total +3). Secondary: 1/LR apply Confused/Dazed/Slowed on failed save.", c_combat, "Effect Shaper");

        all_feats_.emplace_back(FeatID::FurysCall, 1, "Mark of Wrath", "Primary: STR/SR Enrage creature on damage. Secondary: 1/SR Enrage -> -5 AC but resist that creature for 1 min.", c_combat, "Fury's Call");
        all_feats_.emplace_back(FeatID::FurysCall, 2, "Anchor of Fury", "Primary: Enraged within 10ft needs Speed save to move away. Secondary: Resist Enraged enemy's damage.", c_combat, "Fury's Call");
        all_feats_.emplace_back(FeatID::FurysCall, 3, "Warcry Sentinel", "Primary: 1/encounter action Enrage all enemies in 30ft cube. Secondary: +1 AP regen per surrounding Enraged enemy (min 2).", c_combat, "Fury's Call");
        all_feats_.emplace_back(FeatID::FurysCall, 4, "Manifest Fury", "Primary: Enrage on any melee attack. Secondary: Bloodied -> 15ft Vitality save vs Enrage for 2 rounds.", c_combat, "Fury's Call");
        all_feats_.emplace_back(FeatID::FurysCall, 5, "Living Provocation", "Primary: 1/LR <1/3 HP -> Enrage all within 60ft (no save). Secondary: Enraged within 30ft need save to move away.", c_combat, "Fury's Call");

        all_feats_.emplace_back(FeatID::GraspOfTheTitan, 1, "Iron Grip", "Primary Effect: You gain advantage on checks to initiate, maintain or escape a grapple. Secondary Effect: Once per long rest, when a grappled creature attempts to escape and succeeds, you may immediately knock it prone.", c_combat, "Grasp of the Titan");
        all_feats_.emplace_back(FeatID::GraspOfTheTitan, 2, "Crushing Hold", "Primary Effect: When you successfully grapple a creature, you may deal 1d4 bludgeoning damage at the start of each of your turns as a free action while the grapple is maintained. Secondary Effect: You may move at full speed while dragging or carrying a grappled creature.", c_combat, "Grasp of the Titan");
        all_feats_.emplace_back(FeatID::GraspOfTheTitan, 3, "Master of Holds", "Primary Effect: You may grapple two creatures at once, provided they are Medium or smaller and within reach. Secondary Effect: While grappling a creature, it has disadvantage on checks to escape your grasp.", c_combat, "Grasp of the Titan");

        all_feats_.emplace_back(FeatID::ImprovisedWeaponMastery, 1, "Street Scrapper", "Primary: Proficient, add STR/SPD to attack/damage. Secondary: Choose damage type (B/P/S).", c_combat, "Improvised Weapon Mastery");
        all_feats_.emplace_back(FeatID::ImprovisedWeaponMastery, 2, "Opportunist's Edge", "Primary: Damage becomes 1d6. Secondary: 1/turn Reaction use object -> +2 AC (object takes 10 HP).", c_combat, "Improvised Weapon Mastery");
        all_feats_.emplace_back(FeatID::ImprovisedWeaponMastery, 3, "Brutal Ingenuity", "Primary: Damage becomes 1d10, Crit -> destroy weapon for +2d6. Secondary: 1/encounter area explosion throw.", c_combat, "Improvised Weapon Mastery");
        all_feats_.emplace_back(FeatID::ImprovisedWeaponMastery, 4, "Living Arsenal", "Primary: Gain Light/Heavy property on pickup. +1 AP if using 2 different weapons. Secondary: Short Rest modify object (+1 att/dmg).", c_combat, "Improvised Weapon Mastery");
        all_feats_.emplace_back(FeatID::ImprovisedWeaponMastery, 5, "Battlefield Alchemist", "Primary: Magical, splash 1d4 for large/thrown. Secondary: 1/turn hit -> STR/SPD save or disarm.", c_combat, "Improvised Weapon Mastery");

        all_feats_.emplace_back(FeatID::IronFist, 1, "Hardened Knuckles", "Primary: Proficient, 1d6 (B/P/S), add STR+Exertion or SPD+Nimble. Secondary: 1/turn hit -> ignore resistance.", c_combat, "Iron Fist");
        all_feats_.emplace_back(FeatID::IronFist, 2, "Bonebreaker", "Primary: Damage 1d8. Secondary: 1/turn hit -> -10ft movement speed.", c_combat, "Iron Fist");
        all_feats_.emplace_back(FeatID::IronFist, 3, "Shattering Blows", "Primary: Magical 1d10, add 2x STR/SPD. Secondary: 1/turn +1 die OR STR/SPD per LR max damage hit.", c_combat, "Iron Fist");

        all_feats_.emplace_back(FeatID::IronHammer, 2, "Heavy Swing", "Primary: Bludgeoning becomes 1d8 (or 2d8). Secondary: 1/turn hit -> ignore resistance.", c_combat, "Iron Hammer");
        all_feats_.emplace_back(FeatID::IronHammer, 3, "Bonecrusher", "Primary: Bludgeoning becomes 1d10 (or 2d10). Secondary: 1/turn hit -> -10ft movement speed.", c_combat, "Iron Hammer");
        all_feats_.emplace_back(FeatID::IronHammer, 5, "Shattering Blows", "Primary: Bludgeoning becomes 1d12 (or 2d12/4d6). Secondary: 1/turn hit -> ignore immunity.", c_combat, "Iron Hammer");

        all_feats_.emplace_back(FeatID::IronThorn, 2, "Needlepoint Precision", "Primary: Piercing becomes 1d6. Secondary: 1/turn hit -> ignore resistance.", c_combat, "Iron Thorn");
        all_feats_.emplace_back(FeatID::IronThorn, 3, "Deep Wound", "Primary: Piercing becomes 1d8. Secondary: 1/turn hit -> -1 AC until end of next turn.", c_combat, "Iron Thorn");
        all_feats_.emplace_back(FeatID::IronThorn, 5, "Impale", "Primary: Piercing becomes 1d10. Secondary: 1/turn hit -> ignore immunity.", c_combat, "Iron Thorn");

        all_feats_.emplace_back(FeatID::LinebreakersAim, 1, "Tactical Angle", "Primary: Ignore half cover. Secondary: Ignore half cover from full cover if not moved.", c_combat, "Linebreaker's Aim");
        all_feats_.emplace_back(FeatID::LinebreakersAim, 2, "Breach Shot", "Primary: Ricochet shot (-2 att) ignores full cover. Secondary: Hit degrades cover one step.", c_combat, "Linebreaker's Aim");
        all_feats_.emplace_back(FeatID::LinebreakersAim, 3, "No Safe Place", "Primary: Ignore non-magical cover. Secondary: 2/SR Shattershot bursts through 6 inch barrier.", c_combat, "Linebreaker's Aim");

        all_feats_.emplace_back(FeatID::MartialProwess, 1, "Combat Training", "Primary: STR/SR double attack bonus. Secondary: 1/encounter Reaction +1d4 attack or AC.", c_combat, "Martial Prowess");
        all_feats_.emplace_back(FeatID::MartialProwess, 2, "Battlefield Reflexes", "Primary: Adv on initiative. Secondary: Avoid attack -> stacking +1d4 to next attack.", c_combat, "Martial Prowess");
        all_feats_.emplace_back(FeatID::MartialProwess, 3, "Master Duelist", "Primary: +1d4 vs single opponent. Secondary: 1/turn miss deals Stat score damage (glancing blow).", c_combat, "Martial Prowess");

        all_feats_.emplace_back(FeatID::PreciseTactician, 1, "Precise Tactician I", "Primary: Crit on 19-20. Secondary: 1/encounter reroll failed attack.", c_combat, "Precise Tactician");
        all_feats_.emplace_back(FeatID::PreciseTactician, 2, "Precise Tactician II", "Primary: Crit on 18-20. Secondary: Crit -> gain 2 AP.", c_combat, "Precise Tactician");
        all_feats_.emplace_back(FeatID::PreciseTactician, 3, "Precise Tactician III", "Primary: Crit on 17-20. Secondary: Crit -> INT save vs Stunned.", c_combat, "Precise Tactician");
        all_feats_.emplace_back(FeatID::PreciseTactician, 4, "Precise Tactician IV", "Primary: Crit on 16-20. Secondary: Crit -> regain SR feat use OR grant group advantage.", c_combat, "Precise Tactician");
        all_feats_.emplace_back(FeatID::PreciseTactician, 5, "Precise Tactician V", "Primary: Crit on 15-20. Secondary: Crit -> make another attack.", c_combat, "Precise Tactician");

        all_feats_.emplace_back(FeatID::RestAndRecovery, 1, "Restful Recovery", "Primary Effect: When you take a Rest action, you regain an additional +2 Action Points (AP) on top of the normal 1d4 + Strength. Secondary Effect: Once per short rest, you may take a Rest action as a Free Action instead of using your turn.", c_combat, "Rest & Recovery");
        all_feats_.emplace_back(FeatID::RestAndRecovery, 2, "Efficient Recuperation", "Primary Effect: Once per short rest as a free action, you may grant yourself or an ally advantage on a saving throw against being Stunned, Frightened, or Fatigued. Secondary Effect: When you take the rest action, you may also grant half the amount you regain (rounded down) to one ally within 5ft.", c_combat, "Rest & Recovery");
        all_feats_.emplace_back(FeatID::RestAndRecovery, 3, "Tireless Spirit", "Primary Effect: Once per long rest when you take the rest action, you can choose to regain 1d4+2 Spark points in addition to the AP. Secondary Effect: When you take the rest action, you may also remove one minor negative condition (such as Confused or Dazed).", c_combat, "Rest & Recovery");
        all_feats_.emplace_back(FeatID::RestAndRecovery, 4, "Unyielding Vitality", "Primary Effect: Once per long rest when you take the rest action, you may have advantage on rolls until the end of your next turn. Secondary Effect: When you take a Rest action, all allies within 10 ft regain +1d4 + Strength AP in addition to your own recovery.", c_combat, "Rest & Recovery");

        all_feats_.emplace_back(FeatID::SwiftStriker, 1, "Nimble Assault", "Primary: Simple weapon proficiency, add Stat to att/dmg. Secondary: 1/encounter reroll failed attack.", c_combat, "Swift Striker");
        all_feats_.emplace_back(FeatID::SwiftStriker, 2, "Rapid Precision", "Primary: Add 2x Stat to Simple damage. Secondary: Graze effect (deal attack Score on miss).", c_combat, "Swift Striker");
        all_feats_.emplace_back(FeatID::SwiftStriker, 3, "Blinding Flurry", "Primary: SPD/LR max damage hit. Secondary: 1/turn hit -> additional attack with Light simple weapon.", c_combat, "Swift Striker");

        all_feats_.emplace_back(FeatID::TitanicDamage, 1, "Mighty Blow", "Primary: Martial weapon proficiency, add Stat to att/dmg. Secondary: Hit -> push 10ft.", c_combat, "Titanic Damage");
        all_feats_.emplace_back(FeatID::TitanicDamage, 2, "Crushing Impact", "Primary: Add 2x Stat to Martial damage. Secondary: Kill -> make another attack within reach.", c_combat, "Titanic Damage");
        all_feats_.emplace_back(FeatID::TitanicDamage, 3, "Unstoppable Smash", "Primary: STR/LR max damage hit. Secondary: 1/turn ignore disadvantage on attack.", c_combat, "Titanic Damage");

        all_feats_.emplace_back(FeatID::TurnTheBlade, 1, "Turn the Blade", "Primary: SPD/SR Reaction redirect miss to another (save vs 1d4). Secondary: Gain +1 AC until next turn.", c_combat, "Turn the Blade");
        all_feats_.emplace_back(FeatID::TurnTheBlade, 2, "Reversal Flow", "Primary: Redirect deals full/half damage, can protect allies. Secondary: Redirect damage -> gain 1 AP.", c_combat, "Turn the Blade");
        all_feats_.emplace_back(FeatID::TurnTheBlade, 3, "Whirlwind Reprisal", "Primary: 1/SR Reaction redirect miss to two enemies. Secondary: 10ft allies gain +1d4 to defense.", c_combat, "Turn the Blade");

        all_feats_.emplace_back(FeatID::TwinFang, 1, "Dual Grip", "Primary: Dual wield non-light (+1 AP). Secondary: Both hit -> +1d4 damage.", c_combat, "Twin Fang");
        all_feats_.emplace_back(FeatID::TwinFang, 2, "Crosscut", "Primary: No extra AP cost, impose disadvantage. Secondary: Both hit -> 3rd attack (Reaction, 1 AP).", c_combat, "Twin Fang");
        all_feats_.emplace_back(FeatID::TwinFang, 3, "Whirling Blades", "Primary: Surrounded (2+) -> +1 AC and AP regen. Secondary: Parry off-hand Reaction (negate attack).", c_combat, "Twin Fang");
        all_feats_.emplace_back(FeatID::TwinFang, 4, "Titan’s Reach", "Primary: Dual wield Heavy as if Light. Secondary: Both hit -> knock prone (STR save).", c_combat, "Twin Fang");
        all_feats_.emplace_back(FeatID::TwinFang, 5, "Executioner’s Rhythm", "Primary: Kill -> two free attacks against another. Secondary: Follow-up deals +1d6 if target <50% HP.", c_combat, "Twin Fang");

        all_feats_.emplace_back(FeatID::UnyieldingDefender, 1, "Tough as Iron", "Primary: +1 AC. Secondary: 1/LR Free Action shrug off status.", c_combat, "Unyielding Defender");
        all_feats_.emplace_back(FeatID::UnyieldingDefender, 2, "Resilient Stand", "Primary: <1/3 health -> +2 AC. Secondary: Resist at <2/3 health -> group +1d4 bonus.", c_combat, "Unyielding Defender");
        all_feats_.emplace_back(FeatID::UnyieldingDefender, 3, "Indomitable", "Primary: 1/LR reroll failed status save with adv. Secondary: Bloodied -> half cover for 5ft allies.", c_combat, "Unyielding Defender");

        all_feats_.emplace_back(FeatID::WeaponMastery, 1, "Weapon Mastery Initiate", "Primary: Access mastery of 2 proficient weapons. Secondary: Change weapons during long rest.", c_combat, "Weapon Mastery");
        all_feats_.emplace_back(FeatID::WeaponMastery, 2, "Weapon Mastery Adept", "Primary: Use mastery of 4 weapons. Secondary: 1/turn reroll damage 1.", c_combat, "Weapon Mastery");
        all_feats_.emplace_back(FeatID::WeaponMastery, 3, "Weapon Mastery Master", "Primary: Use mastery of 6 weapons. Secondary: 1/SR auto-succeed attack that triggers mastery.", c_combat, "Weapon Mastery");

        // --- Armor Feats ---
        // Tower Shield
        all_feats_.emplace_back(FeatID::TowerShield, 1, "Bulwark Initiate", "Primary: Proficiency with shields. 1/LR when tower shield is set, movement not reduced for 1 min. Secondary: 1/round reduce area effect damage by Vitality score for you or ally behind shield.", c_armor, "Tower Shield");
        all_feats_.emplace_back(FeatID::TowerShield, 2, "Iron Bastion", "Primary: While tower shield is set, you and one ally behind gain resistance to non-magical ranged damage. Secondary: 1/SR grant full cover to you or ally behind set shield against one ranged attack.", c_armor, "Tower Shield");
        all_feats_.emplace_back(FeatID::TowerShield, 3, "Bastion of the Faithful", "Primary: While shield set, up to two allies behind gain full cover; reaction to impose disadvantage on attacks targeting allies. Secondary: When bloodied while shield set, provide half cover to all adjacent allies.", c_armor, "Tower Shield");
        // Wall of the Battered
        all_feats_.emplace_back(FeatID::WallOfTheBattered, 1, "Shield Adept", "Primary: Proficiency with shields; apply one minor shield modification (Spiked/Slotted/Weighted Core). Secondary: 1/SR when ally within 5 ft is targeted, impose disadvantage on the attack roll.", c_armor, "Wall of the Battered");
        all_feats_.emplace_back(FeatID::WallOfTheBattered, 2, "Shield Wall", "Primary: When ally within 5 ft is hit, use Reaction to take the hit instead. Secondary: 1/LR reduce damage from an area spell or effect by half for yourself and one adjacent ally.", c_armor, "Wall of the Battered");
        all_feats_.emplace_back(FeatID::WallOfTheBattered, 3, "Guardian's Interpose", "Primary: When adjacent to shield-wielding ally, both gain +1 AC. Secondary: 1/round when adjacent ally hits a creature you are adjacent to, deal 1d4 bludgeoning as a shield bash.", c_armor, "Wall of the Battered");
        all_feats_.emplace_back(FeatID::WallOfTheBattered, 4, "Iron Sentinel", "Primary: While wielding a shield, gain resistance to non-magical physical damage. Secondary: 1/LR plant shield and become immovable for 1 minute; immune to push, prone, forced movement, and spell effects.", c_armor, "Wall of the Battered");
        all_feats_.emplace_back(FeatID::WallOfTheBattered, 5, "Aegis of the Shattered Gods", "Primary: 1/LR absorb a spell targeting you or ally within 10 ft; regain SP equal to half the spell cost. Secondary: While wielding a shield, you and allies within 10 ft gain bonus to all stat checks equal to Divinity score.", c_armor, "Wall of the Battered");
        // Warp (starts at Tier 2)
        all_feats_.emplace_back(FeatID::Warp, 2, "Warp Initiate", "Primary: On hit, reduce target AC by 1 until end of your turn (stacks). Secondary: If you reduce AC by 2+ using Warp, gain advantage on your next attack against that creature before end of your turn.", c_armor, "Warp");
        all_feats_.emplace_back(FeatID::Warp, 3, "Warp Adept", "Primary: On hit with Warp, reduce armor HP by 1d4 instead of the AC reduction; bypasses durability thresholds. Secondary: If AC reduced by 3+ from Warp in one turn, target suffers -1 to saving throws until start of your next turn.", c_armor, "Warp");
        all_feats_.emplace_back(FeatID::Warp, 4, "Warp Master", "Primary: Warp reduces AC by 2 per hit; if AC reaches 10 or lower, target becomes Vulnerable to next damage source. Secondary: When AC reduced to 10 or lower by Warp, deal additional 1d6 force damage until AC resets.", c_armor, "Warp");

        all_feats_.emplace_back(FeatID::BalancedBulwark, 1, "Medium Armor Training", "Primary: Proficiency with Medium Armor. Secondary: Advantage on checks against being disarmed while wearing Medium Armor.", c_armor, "Balanced Bulwark");
        all_feats_.emplace_back(FeatID::BalancedBulwark, 3, "Steady Defense", "Primary: While wearing Medium Armor, add your full Strength or Speed score (choose when you don the armor) to your AC. Secondary: You may don or doff Medium Armor in half the normal time.", c_armor, "Balanced Bulwark");
        all_feats_.emplace_back(FeatID::BalancedBulwark, 5, "Ironclad Reflex", "Primary: While wearing Medium Armor, once per turn, when a creature misses you with a melee attack, you may make a free basic melee attack against them as a free action. Secondary: If that counterattack hits, the target has disadvantage on its next attack roll before the end of its next turn.", c_armor, "Balanced Bulwark");

        all_feats_.emplace_back(FeatID::DeflectiveStance, 1, "Deflective Stance", "Primary: Gain a +1 bonus to AC when you take the Dodge action. This effect can stack and resets at the start of your next turn. Secondary: When you successfully evade an attack, gain a +1 bonus to your next attack roll. This effect can stack and resets at the start of your next turn.", c_armor, "Deflective Stance");
        all_feats_.emplace_back(FeatID::DeflectiveStance, 2, "Reactive Guard", "Primary: When you are missed by a melee attack, you may make a single melee attack against the attacker as a free action (once per round). Secondary: When you are missed by a melee attack, you may move 5 feet without provoking opportunity attacks from the attacker.", c_armor, "Deflective Stance");
        all_feats_.emplace_back(FeatID::DeflectiveStance, 3, "Counterstrike", "Primary: Once per round, reduce the damage of a physical attack by your Speed score as a reaction. Secondary: Gain advantage on your counterattack if you are using a shield.", c_armor, "Deflective Stance");
        all_feats_.emplace_back(FeatID::DeflectiveStance, 4, "Spell Deflection", "Primary: Once per long rest, when targeted by a single target spell, you may force the caster to reroll their attack or have advantage on the saving throw. Secondary: If the spell misses, you may reflect it at another target within range.", c_armor, "Deflective Stance");

        all_feats_.emplace_back(FeatID::ElementalWard, 1, "Elemental Ward", "Primary: Gain resistance to one elemental damage type (choose: fire, cold, lightning, acid, or poison). Secondary: Once per long rest, reduce elemental damage taken by your Vitality score as a reaction.", c_armor, "Elemental Ward");
        all_feats_.emplace_back(FeatID::ElementalWard, 2, "Elemental Bulwark", "Primary: Gain resistance to two additional elemental damage types of your choice. Secondary: When you take elemental damage, you may use your reaction to return half the damage back to the origin once per short rest.", c_armor, "Elemental Ward");
        all_feats_.emplace_back(FeatID::ElementalWard, 3, "Elemental Aegis", "Primary: Gain advantage on saving throws against effects from your chosen elements. Secondary: When you succeed on a saving throw against elemental damage, gain temporary hit points equal to your Vitality score.", c_armor, "Elemental Ward");
        all_feats_.emplace_back(FeatID::ElementalWard, 4, "Elemental Absorption", "Primary: You are immune to one elemental damage type of your choice; you may change the choice during a long rest once per week. Secondary: You may change one of your chosen resistances after a long rest.", c_armor, "Elemental Ward");

        all_feats_.emplace_back(FeatID::EvasiveWard, 1, "Light Armor Training", "Primary: You gain proficiency with Light Armor. Secondary: While wearing Light Armor, you gain a +2 bonus to initiative rolls.", c_armor, "Evasive Ward");
        all_feats_.emplace_back(FeatID::EvasiveWard, 2, "Nimble Guard", "Primary: While wearing Light Armor, once per long rest, you may automatically succeed on a Speed saving throw. Secondary: Once per short rest, when targeted by an attack, you may move 5 feet as a reaction without provoking opportunity attacks and avoid the attack.", c_armor, "Evasive Ward");
        all_feats_.emplace_back(FeatID::EvasiveWard, 3, "Untouchable", "Primary: While wearing Light Armor, you may add 2x your Speed Score to your AC. Secondary: Once per long rest, when you are hit by an attack, you may force the attacker to reroll and take the lower result as a reaction.", c_armor, "Evasive Ward");

        all_feats_.emplace_back(FeatID::TitanicBastion, 1, "Heavy Armor Training", "Proficiency with Heavy Armor.", c_armor, "Titanic Bastion");
        all_feats_.emplace_back(FeatID::TitanicBastion, 2, "Stalwart Plate", "Add Strength to AC.", c_armor, "Titanic Bastion");
        all_feats_.emplace_back(FeatID::TitanicBastion, 3, "Impenetrable", "Resist non-magical physical damage.", c_armor, "Titanic Bastion");
        all_feats_.emplace_back(FeatID::TitanicBastion, 5, "Immutable", "Immune to non-magical physical damage.", c_armor, "Titanic Bastion");

        all_feats_.emplace_back(FeatID::UnarmoredMaster, 1, "Unarmored Adept", "Primary: AC = (2 x Speed) + 10. Secondary: Add Speed to check (1/SR).", c_armor, "Unarmored Master");
        all_feats_.emplace_back(FeatID::UnarmoredMaster, 2, "Unarmored Flow", "Primary: Reduce damage by XD4 (X=Speed). Secondary: Move half speed on miss.", c_armor, "Unarmored Master");
        all_feats_.emplace_back(FeatID::UnarmoredMaster, 4, "Unarmored Master", "Primary: Resistance to all non-magical damage. Move Speed on miss. Secondary: Adv on next attack/skill check.", c_armor, "Unarmored Master");

        // --- Magic Feats ---
        all_feats_.emplace_back(FeatID::ArcaneSeal, 1, "Spellbinder", "Seal spell to trigger condition.", c_magic, "Arcane Seal");
        all_feats_.emplace_back(FeatID::ArcaneSeal, 2, "Triumvirate Seal", "Maintain 3 bound spells.", c_magic, "Arcane Seal");
        all_feats_.emplace_back(FeatID::ArcaneSeal, 3, "Pentabind Matrix", "Maintain 5 bound spells.", c_magic, "Arcane Seal");

        all_feats_.emplace_back(FeatID::BloodMagic, 1, "Blood Initiate", "Spend 2 HP for 1 SP.", c_magic, "Blood Magic");
        all_feats_.emplace_back(FeatID::BloodMagic, 2, "Blood Adept", "Add VIT to spell rolls.", c_magic, "Blood Magic");
        all_feats_.emplace_back(FeatID::BloodMagic, 3, "Hemocraft Reservoir", "Store SP in sacrifice pool.", c_magic, "Blood Magic");
        all_feats_.emplace_back(FeatID::BloodMagic, 4, "Blood Sage", "Spend HP to reduce SP cost.", c_magic, "Blood Magic");
        all_feats_.emplace_back(FeatID::BloodMagic, 5, "Blood Archon", "Heal twice DIV on kill.", c_magic, "Blood Magic");
        // Create Demiplane
        all_feats_.emplace_back(FeatID::CreateDemiplane, 1, "Dimensional Niche", "Primary: Create a 10x10x10 ft extradimensional space; conjure/dismiss doorway as Basic action; willing creatures enter/exit freely. Secondary: 2/rest conjure or stash one item under 10 lbs from demiplane as a Basic action.", c_magic, "Create Demiplane");
        all_feats_.emplace_back(FeatID::CreateDemiplane, 2, "Personal Demiplane", "Primary: Create a 30x30x30 ft customized demiplane. Secondary: While inside your demiplane, regain +1 HP per hour.", c_magic, "Create Demiplane");
        all_feats_.emplace_back(FeatID::CreateDemiplane, 3, "Anchored Realm", "Primary: Create a 60x60x60 ft stable demiplane with environmental control (gravity, light, air, temperature); one spirit servant for basic tasks. Secondary: +2 HP/hr inside; 1/LR spend 1 minute for short rest benefits.", c_magic, "Create Demiplane");
        // Grasp of the Forgotten
        all_feats_.emplace_back(FeatID::GraspOfTheForgotten, 1, "Grasp of the Forgotten", "Primary: Summon spectral hand within 30 ft (AC 10, HP = Level, hover 20 ft); interact with objects up to 10 lbs; can deliver touch spells. Secondary: Hand may deliver touch-based spells as if you were in that space.", c_magic, "Grasp of the Forgotten");
        all_feats_.emplace_back(FeatID::GraspOfTheForgotten, 2, "Grasp of the Unbound", "Primary: Summon two spectral hands independently; combined carry 30 lbs. Secondary: Hands can interact with magical objects and restrain Small creatures (Speed save DC 10 + Divinity).", c_magic, "Grasp of the Forgotten");
        all_feats_.emplace_back(FeatID::GraspOfTheForgotten, 3, "Grasp of the Forgotten Revenant", "Primary: Hands fuse into Spectral Servant (AC 13, HP = 2x Level, hover 30 ft); takes basic actions 1/round. Secondary: 1/LR empower for 1 min; wield simple weapon, grapple Medium creatures, speak in your voice; AP = Divinity.", c_magic, "Grasp of the Forgotten");
        // Magic Expertise
        all_feats_.emplace_back(FeatID::MagicExpertise, 1, "Arcane Initiate", "Primary: Proficient in magic attacks; add Arcane score to magic attack and damage rolls. Secondary: 1/SR instantly recall minor magical fact or arcane lore relevant to current situation.", c_magic, "Magic Expertise");
        all_feats_.emplace_back(FeatID::MagicExpertise, 2, "Mystic Adept", "Primary: Add double Divinity score to magic attack and damage rolls. Secondary: 1/LR create temporary magical shield granting resistance to one damage type for 1 minute.", c_magic, "Magic Expertise");
        all_feats_.emplace_back(FeatID::MagicExpertise, 3, "Archimage's Mastery", "Primary: 1/turn on magic attack damage, maximize one damage die. Secondary: 1/LR after magic attack hit, teleport up to 15 ft to unoccupied space you can see.", c_magic, "Magic Expertise");
        // Master of Ceremonies
        all_feats_.emplace_back(FeatID::MasterOfCeremonies, 1, "Ritualist", "Primary: Perform magical rituals creating persistent spell effects by committing SP; maintain one ritual effect. Secondary: Advantage on magical interference checks; attackers have disadvantage on checks to disrupt.", c_magic, "Master of Ceremonies");
        all_feats_.emplace_back(FeatID::MasterOfCeremonies, 2, "Arcane Conduit", "Primary: Maintain up to two ritual effects simultaneously. Secondary: With at least one willing assistant, reduce total SP cost by 1 (minimum 1).", c_magic, "Master of Ceremonies");
        all_feats_.emplace_back(FeatID::MasterOfCeremonies, 3, "Meister of Ceremonies", "Primary: Each ritual assistant reduces SP cost by 1 (up to half total). Secondary: Ritual time reduced from 1 hr/SP to 10 min/SP; at sacred sites choose one minor benefit without increased SP cost.", c_magic, "Master of Ceremonies");
        all_feats_.emplace_back(FeatID::MasterOfCeremonies, 4, "Eternal Anchor", "Primary: Bind ritual effect to physical anchor (object/location); persists while anchor is intact, origin is at the anchor. Secondary: Sense when anchored ritual is threatened or tampered with.", c_magic, "Master of Ceremonies");
        all_feats_.emplace_back(FeatID::MasterOfCeremonies, 5, "Ritual Savant", "Primary: 1/LR perform a ritual requiring no SP commitment (max SP = 2x Divinity), lasts until next long rest, takes 10 min. Secondary: When voluntarily ending a ritual, regain 2 SP (up to normal pool max).", c_magic, "Master of Ceremonies");
        // Scryer
        all_feats_.emplace_back(FeatID::Scryer, 1, "Distant Watcher", "Primary: Extend Scrying Eye range to 1 mile without increasing SP cost. Secondary: Advantage on checks to resist magical interference or counter-scrying.", c_magic, "Scryer");
        all_feats_.emplace_back(FeatID::Scryer, 2, "Far-Seer", "Primary: Scry any visited location in same region at Regional range, SP remains 10. Secondary: While scrying, also hear surface thoughts (as Mind Link) at no additional SP cost.", c_magic, "Scryer");
        all_feats_.emplace_back(FeatID::Scryer, 3, "Planar Observer", "Primary: Scry anywhere on the same plane, SP remains 10. Secondary: 1/LR anchor Scrying Eye for up to 24 hours; return to its viewpoint at will during that time.", c_magic, "Scryer");
        // Shapeshifter's Path
        all_feats_.emplace_back(FeatID::ShapeshiftersPath, 1, "Beast Initiate", "Primary: 1/SR shapeshift into small/medium non-magical animal for 1 hr (0 SP base); each SP spent adds a level; restricted to General and animal abilities. Secondary: While shapeshifted, communicate simple ideas to animals of the same type.", c_magic, "Shapeshifter's Path");
        all_feats_.emplace_back(FeatID::ShapeshiftersPath, 2, "Beast Adept", "Primary: Shapeshift 2/SR, up to Large size, up to 2 hours; advantage on tracking/sensing checks using animal senses. Secondary: Advantage on Speechcraft checks to influence animals.", c_magic, "Shapeshifter's Path");
        all_feats_.emplace_back(FeatID::ShapeshiftersPath, 3, "Beast Channeler", "Primary: Shapeshift as free action, up to 4 hours; resistance to non-magical damage; attacks deal magical damage; access magically enhanced animals and general magic abilities. Secondary: 1/SR cast a spell while shapeshifted.", c_magic, "Shapeshifter's Path");
        all_feats_.emplace_back(FeatID::ShapeshiftersPath, 4, "Beast Sage", "Primary: Access magical beast abilities when shapeshifted; shapeshift 3/SR. Secondary: 1/LR shapeshift a willing creature following the same rules as you.", c_magic, "Shapeshifter's Path");
        all_feats_.emplace_back(FeatID::ShapeshiftersPath, 5, "Beast Archon", "Primary: Shapeshift at will, unlimited, into Huge animals. Secondary: Cast spells normally while shapeshifted.", c_magic, "Shapeshifter's Path");
        // Spell Shaper
        all_feats_.emplace_back(FeatID::SpellShaper, 1, "Spellshaper Initiate", "Primary: Spell DC is now 10 + double Divinity score. Secondary: 1/LR force a creature that succeeds a saving throw to reroll and take the lower result.", c_magic, "Spell Shaper");
        all_feats_.emplace_back(FeatID::SpellShaper, 2, "Spellshaper Adept", "Primary: 1/SR add 1d4 to Spell DC or attack rolls of one spell. Secondary: 1/LR when creature succeeds saving throw against your spell, impose disadvantage.", c_magic, "Spell Shaper");
        all_feats_.emplace_back(FeatID::SpellShaper, 3, "Spellshaper Mastery", "Primary: 1/LR when casting a saving throw spell, all affected creatures automatically fail their first save. Secondary: 1/LR on failed save, immediately cast a spell of half the SP cost or lower as part of the same action.", c_magic, "Spell Shaper");
        // Soul Weaver (Tier 4 only)
        all_feats_.emplace_back(FeatID::SoulWeaver, 4, "Soul Weaver", "Primary: Create a soul anchor for a creature (24 hr ritual with personal item); if creature dies, they return to life at the anchor after 1 hour. Secondary: Sense when a soul anchor you created is in danger or triggered.", c_magic, "Soul Weaver");
        // Transmuter's Precision
        all_feats_.emplace_back(FeatID::TransmutersPrecision, 1, "Alchemical Channeler", "Primary: Transmute materials at 20 SP per 1ft3 (halved cost); volume doubles double SP cost. Secondary: 1/LR stabilize a volatile transmutation, preventing magical backlash.", c_magic, "Transmuter's Precision");
        all_feats_.emplace_back(FeatID::TransmutersPrecision, 2, "Elemental Architect", "Primary: Transmute materials at 10 SP per 1ft3; same volume scaling rules. Secondary: 1/SR ignore the +5 SP complexity score for one multi-element transmutation.", c_magic, "Transmuter's Precision");
        all_feats_.emplace_back(FeatID::TransmutersPrecision, 3, "Philosopher's Apex", "Primary: Transmute materials at 5 SP per 1ft3; same doubling rule. Secondary: Retain 75% of original material mass when transmuting (improved from 50%).", c_magic, "Transmuter's Precision");

        // --- Alignment Feats ---
        all_feats_.emplace_back(FeatID::ChaosPact, 1, "Chaos Pact Initiate", "Primary: 1/rest, +1d4 Speechcraft/Nimble when unpredictable. Secondary: 1/LR, sense chaos/unstable magic within 1 mile.", c_align, "Chaos Pact");
        all_feats_.emplace_back(FeatID::ChaosPact, 2, "Chaos’s Boon", "Primary: 1/rest, reroll failed save vs magic. Secondary: 1/rest, partially insubstantial 1 min (move through difficult terrain).", c_align, "Chaos Pact");
        all_feats_.emplace_back(FeatID::ChaosPact, 3, "Chaos Master", "Primary: 1/rest, summon chaos creature (effect SP <= level). Secondary: 1/LR, bargain with Chaos for a miracle.", c_align, "Chaos Pact");

        all_feats_.emplace_back(FeatID::ChaosScholar, 1, "Chaos Initiate", "Primary: identify chaotic effects/artifacts, +1d4 arcane checks. Secondary: 1/LR, recall obscure lore.", c_align, "Chaos Scholar");
        all_feats_.emplace_back(FeatID::ChaosScholar, 2, "Anarchic Researcher", "Primary: 1/LR, remove effect SP cost for Chaos spell (effect SP <= level). Secondary: succeed arcane task -> uncover hidden truth.", c_align, "Chaos Scholar");
        all_feats_.emplace_back(FeatID::ChaosScholar, 3, "Chaos Adept", "Primary: orb of chaos, 5ft radius, -1 spell cost. Secondary: 1/LR, upgrade Chaos spell 1 rank in 2 parameters.", c_align, "Chaos Scholar");

        all_feats_.emplace_back(FeatID::UnityPact, 1, "Unity Pact Initiate", "Primary: 1/rest, +1d4 Speechcraft/Insight in bright light. Secondary: 1/LR, sense celestial/radiant power within 1 mile.", c_align, "Unity Pact");
        all_feats_.emplace_back(FeatID::UnityPact, 2, "Unity‘s Boon", "Primary: 1/LR, dispel blindness. Secondary: 1/rest, radiant burst, disadvantage for attackers.", c_align, "Unity Pact");
        all_feats_.emplace_back(FeatID::UnityPact, 3, "Unity Master", "Primary: 1/rest, summon radiant guardian (effect SP <= level). Secondary: 1/LR, call for miracle.", c_align, "Unity Pact");

        all_feats_.emplace_back(FeatID::UnityScholar, 1, "Unity Scholar Initiate", "Primary: identify holy/celestial artifacts, +1d4 arcane/religion checks. Secondary: 1/LR, recall sacred lore.", c_align, "Unity Scholar");
        all_feats_.emplace_back(FeatID::UnityScholar, 2, "Illuminated Researcher", "Primary: 1/LR, remove effect SP cost for Unity spell (effect SP <= level). Secondary: succeed arcane/religion task -> uncover hidden truth.", c_align, "Unity Scholar");
        all_feats_.emplace_back(FeatID::UnityScholar, 3, "Unity Adept", "Primary: orb of light, 5ft radius, -1 spell cost. Secondary: 1/LR, upgrade Unity spell 1 rank in 2 parameters.", c_align, "Unity Scholar");

        all_feats_.emplace_back(FeatID::VoidPact, 1, "Void Pact Initiate", "Primary: 1/rest, +1d4 Sneak/Deception in darkness. Secondary: 1/LR, sense Void/necrotic power within 1 mile.", c_align, "Void Pact");
        all_feats_.emplace_back(FeatID::VoidPact, 2, "Void’s Boon", "Primary: see in magical darkness. Secondary: 1/rest, intangible 1 round.", c_align, "Void Pact");
        all_feats_.emplace_back(FeatID::VoidPact, 3, "Void Pact Master", "Primary: 1/rest, summon shadowy minion (effect SP <= level). Secondary: 1/LR, bargain with Shadows for a miracle.", c_align, "Void Pact");

        all_feats_.emplace_back(FeatID::VoidScholar, 1, "Void Initiate", "Primary: identify magical effects, +1d4 arcane checks. Secondary: 1/LR, recall obscure lore.", c_align, "Void Scholar");
        all_feats_.emplace_back(FeatID::VoidScholar, 2, "Forbidden Researcher", "Primary: 1/LR, remove effect SP cost for darkness spell (effect SP <= level). Secondary: succeed arcane task -> uncover hidden truth.", c_align, "Void Scholar");
        all_feats_.emplace_back(FeatID::VoidScholar, 3, "Void Adept", "Primary: orb of shadows, 5ft radius, -1 spell cost. Secondary: 1/LR, upgrade darkness spell 1 rank in 2 parameters.", c_align, "Void Scholar");

        // --- Domain Feats ---
        all_feats_.emplace_back(FeatID::BiologicalDomain, 1, "Rooted Initiate", "Primary: Biological domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: Biological spells create 10ft cube of half cover plants/moss.", c_domain, "Biological Domain");
        all_feats_.emplace_back(FeatID::BiologicalDomain, 2, "Verdant Channeler", "Primary: Biological domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: Bio spells grant attack bonus equal to SP spent.", c_domain, "Biological Domain");
        all_feats_.emplace_back(FeatID::BiologicalDomain, 3, "Gaia’s Mastery", "Primary: Biological domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 0). Secondary: 1/LR heal HP (3x DIV) and remove minor condition.", c_domain, "Biological Domain");

        all_feats_.emplace_back(FeatID::ChemicalDomain, 1, "Alchemical Adept", "Primary: Chemical domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: 1/SR create basic solution; reduces difficulty 1 rank (auto-success if minor).", c_domain, "Chemical Domain");
        all_feats_.emplace_back(FeatID::ChemicalDomain, 2, "Fluid Transmuter", "Primary: Chemical domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: 1/SR neutralize toxin as free action OR cast 4 SP chemical spell for free.", c_domain, "Chemical Domain");
        all_feats_.emplace_back(FeatID::ChemicalDomain, 3, "Combustion Savant", "Primary: Chemical domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 0). Secondary: 1/LR trigger reaction to blind/daze/slow in 30ft area (100ft range, Standard DC).", c_domain, "Chemical Domain");

        all_feats_.emplace_back(FeatID::PhysicalDomain, 1, "Ember Manipulator", "Primary: Physical domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: 1/SR free action ignite flame; reduces fire spell cost by 3 SP (max -6 with sources, min 0).", c_domain, "Physical Domain");
        all_feats_.emplace_back(FeatID::PhysicalDomain, 2, "Kinetic Shaper", "Primary: Physical domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: 1/LR action create illusion; disadvantage on attacks against allies for 1 min.", c_domain, "Physical Domain");
        all_feats_.emplace_back(FeatID::PhysicalDomain, 3, "Mirage Architect", "Primary: Physical domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 0). Secondary: Telekinesis/constructs cost 2 less SP (min 0).", c_domain, "Physical Domain");

        all_feats_.emplace_back(FeatID::SpiritualDomain, 1, "Whispering Mind", "Primary: Spiritual domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: DIV/SR send telepathic message with instant response.", c_domain, "Spiritual Domain");
        all_feats_.emplace_back(FeatID::SpiritualDomain, 2, "Ethereal Summoner", "Primary: Spiritual domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: 1/LR action nullify magical effect/barrier for 1 round.", c_domain, "Spiritual Domain");
        all_feats_.emplace_back(FeatID::SpiritualDomain, 3, "Veilbreaker", "Primary: Spiritual domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 0). Secondary: Animate constructs gain hover and intangible for free.", c_domain, "Spiritual Domain");

        // --- Exploration Feats ---
        // Agile Explorer
        all_feats_.emplace_back(FeatID::AgileExplorer, 1, "Surefooted", "Primary: Climb at full movement speed; not vulnerable while climbing. Secondary: 1/LR auto-succeed on a check to avoid falling or being knocked prone.", c_explore, "Agile Explorer");
        all_feats_.emplace_back(FeatID::AgileExplorer, 2, "Climber's Mastery", "Primary: 1/rest ignore difficult terrain effects for 1 minute. Secondary: Auto move across narrow/precarious surfaces while unencumbered.", c_explore, "Agile Explorer");
        all_feats_.emplace_back(FeatID::AgileExplorer, 3, "Water-Walker", "Primary: Move at normal speed across water or other liquids; must take a move action each turn to remain above surface. Secondary: 1/rest bring a contacting ally along; ends when contact ends or after 1 minute.", c_explore, "Agile Explorer");
        // Explorer's Grit
        all_feats_.emplace_back(FeatID::ExplorersGrit, 1, "Trailblazer", "Primary: +1d4 bonus to navigation and survival checks in unknown terrain. Secondary: 1/LR find a safe path or shortcut, reducing travel time or avoiding a natural hazard.", c_explore, "Explorer's Grit");
        all_feats_.emplace_back(FeatID::ExplorersGrit, 2, "Relic Seeker", "Primary: +1d4 bonus to checks to find hidden objects, traps, or secret doors. Secondary: On discovering a hidden feature, gain a temporary bonus to your next exploration-related check.", c_explore, "Explorer's Grit");
        all_feats_.emplace_back(FeatID::ExplorersGrit, 3, "Veteran Pathfinder", "Primary: 1/LR lead a group safely through dangerous environments; allies gain advantage on environmental danger checks for 1 hour. Secondary: 1/LR reroll a failed survival or navigation check.", c_explore, "Explorer's Grit");
        // Healing & Restoration
        all_feats_.emplace_back(FeatID::HealingRestoration, 1, "Field Medic", "Primary: Reduce minor medical challenge by one step; add Divinity score to healing rolls. Secondary: 1/SR as a free action, give a damaged ally resistance to that damage type for 1 minute.", c_explore, "Healing & Restoration");
        all_feats_.emplace_back(FeatID::HealingRestoration, 3, "Restorative Healer", "Primary: Reduce moderate injury treatment challenge by one step; add 2x Divinity score to healing rolls. Secondary: When you heal an ally, also remove one minor negative condition.", c_explore, "Healing & Restoration");
        all_feats_.emplace_back(FeatID::HealingRestoration, 5, "Miracle Worker", "Primary: Reduce major healing challenge by one step; add 3x Divinity score to healing rolls. Secondary: 1/SR perform a powerful restoration (fully heal ally, mend object, or purge curse) at no SP cost.", c_explore, "Healing & Restoration");
        // Stealth & Subterfuge
        all_feats_.emplace_back(FeatID::StealthSubterfuge, 1, "Shadow Walker", "Primary: Reduce social manipulation challenge by one step; 1/rest advantage on Speechcraft checks. Secondary: 1/LR create a distraction or disguise to mislead pursuers.", c_explore, "Stealth & Subterfuge");
        all_feats_.emplace_back(FeatID::StealthSubterfuge, 2, "Faceless Impostor", "Primary: Convince as another person; reduce identity assumption challenge by one step; 1/LR flawlessly mimic voice/mannerisms/handwriting for 1 hour. Secondary: Successful deception while disguised; target is friendly for 10 minutes.", c_explore, "Stealth & Subterfuge");
        all_feats_.emplace_back(FeatID::StealthSubterfuge, 3, "Master of Escape", "Primary: Reduce escape challenge by one step; 1/LR auto-escape physical or magical restraints. Secondary: On successful escape, move up to half speed without provoking opportunity attacks.", c_explore, "Stealth & Subterfuge");
        // Illusion & Deception
        all_feats_.emplace_back(FeatID::IllusionDeception, 1, "Veil Crafter", "Primary: Reduce challenge of creating minor illusions by one step; DC +1 for illusions. Secondary: 1/SR create a fleeting visual or auditory illusion to cover escape or hide an object for 1 minute.", c_explore, "Illusion & Deception");
        all_feats_.emplace_back(FeatID::IllusionDeception, 2, "Trickster's Guile", "Primary: Reduce challenge of complex multi-layered illusions by one step; DC +2 for illusions. Secondary: When you fool an enemy with an illusion, gain advantage on checks against them for 1 minute.", c_explore, "Illusion & Deception");
        all_feats_.emplace_back(FeatID::IllusionDeception, 3, "Master of Mirage", "Primary: Reduce challenge of large-scale or reality-bending illusions by one step; DC +3 for illusions. Secondary: 1/LR create an illusion so convincing it alters the perceptions or emotions of a group.", c_explore, "Illusion & Deception");
        // Mind Over Challenge
        all_feats_.emplace_back(FeatID::MindOverChallenge, 1, "Keen Mind", "Primary: Intellect score times per day, add +1d4 bonus to skill checks. Secondary: 1/SR reroll a failed skill check and take the higher result.", c_explore, "Mind Over Challenge");
        all_feats_.emplace_back(FeatID::MindOverChallenge, 2, "Analytical Precision", "Primary: Add 2x Intellect score to all skill checks instead of 1x. Secondary: 1/rest automatically succeed on a minor skill check (DC 10 or lower) using Intellect.", c_explore, "Mind Over Challenge");
        all_feats_.emplace_back(FeatID::MindOverChallenge, 3, "Master of Insight", "Primary: Add 3x Intellect score to all skill checks. Secondary: 1/LR treat a failed skill check as a natural 20.", c_explore, "Mind Over Challenge");
        // Minion Master
        all_feats_.emplace_back(FeatID::MinionMaster, 1, "Summoner's Call", "Primary: 1/LR summon a basic minion as a Basic action (0 SP, no duration; build SP cannot exceed Level; max one at a time). Secondary: Minion acts on your initiative and obeys simple commands.", c_explore, "Minion Master");
        all_feats_.emplace_back(FeatID::MinionMaster, 2, "Empowered Minion", "Primary: As a reaction within 30 ft, transfer any damage you take to your minion; minion can be medium size. Secondary: If reduced to 0 HP while minion is active, minion takes one action before vanishing.", c_explore, "Minion Master");
        all_feats_.emplace_back(FeatID::MinionMaster, 3, "Minion Swarm", "Primary: Control up to three minions at once. Secondary: 1/LR transfer consciousness into a minion while unconscious; full control within 1 mile of your body.", c_explore, "Minion Master");
        all_feats_.emplace_back(FeatID::MinionMaster, 4, "Legion's Command", "Primary: Control up to four minions; summoned minions gain extra HP equal to your level. Secondary: Minions gain resistance to one damage type of your choice when summoned.", c_explore, "Minion Master");
        // Temporal Touch
        all_feats_.emplace_back(FeatID::TemporalTouch, 1, "Temporal Touch", "Primary: Divinity score times per long rest as a free action, grant ally advantage on next attack or impose disadvantage on enemy's next attack. Secondary: 1/LR create a small environmental change (open lock, create temporary bridge).", c_explore, "Temporal Touch");
        all_feats_.emplace_back(FeatID::TemporalTouch, 2, "Eternal Flame", "Primary: Produce an undying torch (never extinguishes, light 30 ft, heat 10 ft, +2 TRR; only one at a time). Secondary: 1/LR as a Basic action, reveal hidden or invisible objects/creatures within its glow for 1 minute.", c_explore, "Temporal Touch");
        all_feats_.emplace_back(FeatID::TemporalTouch, 3, "Fragmented Mirror", "Primary: Glimpse possible futures; +1d4 to skill checks for the next hour. Secondary: 1/LR ask a specific question about a challenge or path and receive a helpful hint or warning.", c_explore, "Temporal Touch");
        all_feats_.emplace_back(FeatID::TemporalTouch, 4, "Chronal Convergence", "Primary: 1/LR briefly converge timelines; you and up to two allies take a second turn on their next turn. Secondary: You and affected allies gain resistance to time-based magical effects (slow, stun, banishment) until end of next turn.", c_explore, "Temporal Touch");

        // --- Crafting Feats ---
        // Alchemist's Supplies
        all_feats_.emplace_back(FeatID::AlchemistsSupplies, 1, "Apprentice Alchemist", "Primary: Gain proficiency with Alchemist's Supplies; add Vitality score to all checks to identify, mix, or neutralize chemicals and potions. Secondary: 1/LR brew a basic alchemical concoction (minor acid, smoke bomb, or flash powder).", c_craft, "Alchemist's Supplies");
        all_feats_.emplace_back(FeatID::AlchemistsSupplies, 2, "Adept Alchemist", "Primary: Add 2x Vitality score to all Alchemist's Supplies checks. Secondary: 1/LR on a failed alchemy check, succeed instead.", c_craft, "Alchemist's Supplies");
        all_feats_.emplace_back(FeatID::AlchemistsSupplies, 3, "Transmuter Supreme", "Primary: When crafting an alchemical item, reduce required preparation time by half (minimum 1 hour). Secondary: 1/week create a potent elixir granting resistance to one damage type or powerful effect for 24 hours.", c_craft, "Alchemist's Supplies");

        // Artisan's Tools
        all_feats_.emplace_back(FeatID::ArtisansTools, 1, "Master of the Craft", "Primary: 1/LR when using artisan's tools, reroll a failed crafting check and take the higher result (use not consumed unless reroll succeeds). Secondary: 1/LR reduce crafting time and cost for a nonmagical item by 25%.", c_craft, "Artisan's Tools");
        all_feats_.emplace_back(FeatID::ArtisansTools, 2, "Inspired Artisan", "Primary: Add 2x Crafting score to checks with artisan's tools. Secondary: 1/LR restore or reinforce a damaged nonmagical item, granting it temporary HP equal to Crafting score x2 for 1 hour.", c_craft, "Artisan's Tools");
        all_feats_.emplace_back(FeatID::ArtisansTools, 3, "Legendary Maker", "Primary: Craft masterwork nonmagical items granting +1 bonus to a relevant skill or check when used. Secondary: 1/LR create a nonmagical item in half the time and cost, or imbue a crafted item with a minor magical property.", c_craft, "Artisan's Tools");

        // Smith's Tools
        all_feats_.emplace_back(FeatID::SmithsTools, 1, "Apprentice Smith", "Primary: Gain proficiency with Smith's tools; add Strength score to all checks to repair or craft metal items. Secondary: 1/LR repair a broken weapon or piece of armor to functional condition.", c_craft, "Smith's Tools");
        all_feats_.emplace_back(FeatID::SmithsTools, 2, "Journeyman Forger", "Primary: Add 2x Strength score to all Smith's Tools checks. Secondary: 1/LR on a failed smithing crafting check, succeed instead.", c_craft, "Smith's Tools");
        all_feats_.emplace_back(FeatID::SmithsTools, 3, "Master Artificer", "Primary: Reduce required preparation time by half (minimum 1 hour). Secondary: 1/week craft or enhance a weapon or armor to grant it a minor magical property or increased durability.", c_craft, "Smith's Tools");

        // Thieves' Tools
        all_feats_.emplace_back(FeatID::ThievesTools, 1, "Nimble Fingers", "Primary: Gain proficiency with Thieves' tools; add Speed score to all lockpicking and trap disarming checks. Secondary: 1/LR reroll a failed Thieves' Tools check.", c_craft, "Thieves' Tools");
        all_feats_.emplace_back(FeatID::ThievesTools, 2, "Shadow's Touch", "Primary: Add 2x Speed score to all Thieves' Tools checks. Secondary: 1/encounter on a failed check, avoid triggering a trap or alerting guards.", c_craft, "Thieves' Tools");
        all_feats_.emplace_back(FeatID::ThievesTools, 3, "Ghost in the Gears", "Primary: Add 2x Cunning score to all Thieves' Tools checks. Secondary: 1/week automatically succeed on a Thieves' Tools check against a nonmagical lock or trap.", c_craft, "Thieves' Tools");
        // Calligrapher's Supplies
        all_feats_.emplace_back(FeatID::CalligraphersSupplies, 1, "Elegant Scribe", "Primary: Proficiency with Calligrapher's Supplies; add Intellect to calligraphy, forgery, and ancient script checks. Secondary: 1/SR create a scroll in 10 min granting advantage on one social or knowledge check.", c_craft, "Calligrapher's Supplies");
        all_feats_.emplace_back(FeatID::CalligraphersSupplies, 2, "Glyphmaster", "Primary: Add 2x Intellect to all Calligrapher's Supplies checks. Secondary: 1/SR inscribe a Seal of Silence (no sound in 10 ft for 1 hr) or Glyph of Clarity (advantage on Intellect checks within 10 ft for 1 hr) in 10 min.", c_craft, "Calligrapher's Supplies");
        all_feats_.emplace_back(FeatID::CalligraphersSupplies, 3, "Words of Power", "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/LR create a Living Script (sentient scroll that delivers a message, casts a stored spell 4 SP or less, or activates a magical effect; lasts 24 hrs or until task complete).", c_craft, "Calligrapher's Supplies");
        // Crafting & Artifice
        all_feats_.emplace_back(FeatID::CraftingArtifice, 1, "Arcane Tinkerer", "Primary: Craft/modify simple objects (DC 10 or less) in half the time with +2 to crafting checks. Secondary: 1/SR improvise a temporary magical or mechanical tool lasting 10 min or until used.", c_craft, "Crafting & Artifice");
        all_feats_.emplace_back(FeatID::CraftingArtifice, 2, "Reactive Builder", "Primary: Begin crafting moderate and minor projects in the field; time reduced by 25%. Secondary: When encountering a trap, magical lock, or malfunctioning device, make an instant Crafting or Intellect check to disable, bypass, or repair it.", c_craft, "Crafting & Artifice");
        all_feats_.emplace_back(FeatID::CraftingArtifice, 3, "Experimental Power Core", "Primary: Install an energy core into one item (charges up to 3 SP); spend 1 SP to add 1d6 elemental damage, reduce spell cost by 2 SP, or empower a device. Secondary: 1/LR when targeted by a spell, redirect up to 3 SP of energy to the core.", c_craft, "Crafting & Artifice");
        // Culinary Virtuoso
        all_feats_.emplace_back(FeatID::CulinaryVirtuoso, 1, "Culinary Virtuoso", "Primary: Proficiency in cooking utensils; add Learnedness to cooking rolls and +1d4 to culinary checks. Secondary: 1/LR grant bonus AP equal to Intellect score.", c_craft, "Culinary Virtuoso");
        all_feats_.emplace_back(FeatID::CulinaryVirtuoso, 2, "Alchemical Chef", "Primary: Infuse dishes with magical effects (1 action to consume): heal 1d4, +2 AC for 1 min, or +2 to attack rolls for 1 min. Secondary: 1/LR prepare a meal granting an ally resistance to a specific environmental hazard.", c_craft, "Culinary Virtuoso");
        all_feats_.emplace_back(FeatID::CulinaryVirtuoso, 3, "Banquet of Unity", "Primary: During a long rest, prepare a feast; allies who consume it gain +2 max AP until their next long rest. Secondary: After sharing the feast, all participants gain +1d6 to teamwork actions or group checks for 1 hour.", c_craft, "Culinary Virtuoso");
        // Disguise Kit
        all_feats_.emplace_back(FeatID::DisguiseKit, 1, "Quick Change", "Primary: Proficiency with Disguise kit; add Intellect score to disguise and impersonation checks. Secondary: 1/LR create a disguise in half the normal time.", c_craft, "Disguise Kit");
        all_feats_.emplace_back(FeatID::DisguiseKit, 2, "Chameleon", "Primary: Add 2x Intellect score to all Disguise Kit checks. Secondary: 1/encounter on a failed disguise check, avoid immediate detection.", c_craft, "Disguise Kit");
        all_feats_.emplace_back(FeatID::DisguiseKit, 3, "Master of Masquerade", "Primary: Cannot roll below 10 on disguise checks. Secondary: 1/week create a disguise so convincing it fools magical or divine detection for a short period.", c_craft, "Disguise Kit");
        // Fishing Mastery
        all_feats_.emplace_back(FeatID::FishingMastery, 1, "Riverhand", "Primary: Advantage on Survival checks to locate or catch fish; feed 1 person/hour (no check) or 1d4 people (with check). Secondary: Identify if a body of water is safe to fish in with a DC 10 Intuition or Learnedness check.", c_craft, "Fishing Mastery");
        all_feats_.emplace_back(FeatID::FishingMastery, 2, "Angler's Instinct", "Primary: Catch rare or magical fish with DC 15 Survival or Cunning check; reduce crafting costs by 1 SP. Secondary: 1/day reroll a failed fishing-related check and take the higher result.", c_craft, "Fishing Mastery");
        all_feats_.emplace_back(FeatID::FishingMastery, 3, "Master of the Waters", "Primary: Feed up to 10 people with 1 hour of effort; 1/LR harvest 1d6 units of magical/alchemical reagents reducing crafting costs by the roll. Secondary: When consuming a magical fish, gain advantage on region-related Intuition or Learnedness checks for 1 hour.", c_craft, "Fishing Mastery");
        // Herbalism Kit
        all_feats_.emplace_back(FeatID::HerbalismKit, 1, "Novice Herbalist", "Primary: Proficiency with Herbalism kit; add Intellect score to checks to identify or harvest herbs. Secondary: 1/LR brew a basic healing salve restoring 1d6 + Divinity HP.", c_craft, "Herbalism Kit");
        all_feats_.emplace_back(FeatID::HerbalismKit, 2, "Adept Herbalist", "Primary: Add 2x Intellect score to all Herbalism Kit checks. Secondary: 1/LR when a potion brewing check fails, succeed instead.", c_craft, "Herbalism Kit");
        all_feats_.emplace_back(FeatID::HerbalismKit, 3, "Master of Remedies", "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/LR brew a potent elixir granting resistance to poison or disease for 24 hours.", c_craft, "Herbalism Kit");
        // Hunting Mastery
        all_feats_.emplace_back(FeatID::HuntingMastery, 1, "Tracker's Eye", "Primary: Advantage on Survival checks to track beasts; determine size, number, and condition of prey. Secondary: Harvest 1 additional ration from slain beast; meat stays fresh twice as long.", c_craft, "Hunting Mastery");
        all_feats_.emplace_back(FeatID::HuntingMastery, 2, "Apex Pursuer", "Primary: 1/SR after tracking a creature for 10+ min, gain +1d4 to next attack or damage roll against it. Secondary: Harvest rare components (fur, glands, bones) from beasts reducing crafting costs by 1 SP; identify diseased/corrupted creatures (DC 12).", c_craft, "Hunting Mastery");
        all_feats_.emplace_back(FeatID::HuntingMastery, 3, "Master of the Wild Hunt", "Primary: 1/LR designate a quarry; advantage on tracking and +1d6 damage on first successful hit each round for 1 hour. Secondary: 1/LR ritualistic field dressing yields 1d4 units of high-quality material and restores 1d4 bonus AP.", c_craft, "Hunting Mastery");
        // Jeweler's Tools
        all_feats_.emplace_back(FeatID::JewelersTools, 1, "Gemcutter", "Primary: Proficiency with Jeweler's tools; add Intellect to checks to appraise, cut, or set gems. Secondary: 1/LR identify a magical property or flaw in a gemstone; enhance mundane item value by up to 25%.", c_craft, "Jeweler's Tools");
        all_feats_.emplace_back(FeatID::JewelersTools, 2, "Artisan of Sparkle", "Primary: Add 2x Intellect to all Jeweler's Tools checks. Secondary: 1/LR on a failed jewelry crafting or appraisal check, succeed instead without damaging the item.", c_craft, "Jeweler's Tools");
        all_feats_.emplace_back(FeatID::JewelersTools, 3, "Master Jeweler", "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/week craft or enhance jewelry for a one-time-use minor magical effect or double its value.", c_craft, "Jeweler's Tools");
        // Musical Instrument
        all_feats_.emplace_back(FeatID::MusicalInstrument, 1, "Melodic Talent", "Primary: Proficiency with two instruments; add Divinity score to performance and instrument checks. Secondary: 1/LR play for 10 min healing allies within 30 ft for 4d4 + Divinity HP per 1 SP spent.", c_craft, "Musical Instrument");
        all_feats_.emplace_back(FeatID::MusicalInstrument, 2, "Virtuoso", "Primary: Proficiency with 3 more instruments; add 2x Divinity to all proficient instrument checks. Secondary: 1/LR automatically succeed at a perform check.", c_craft, "Musical Instrument");
        all_feats_.emplace_back(FeatID::MusicalInstrument, 3, "Bardic Legend", "Primary: Proficiency with all instruments; add 2x Perform score to all Musical Instrument checks. Secondary: Difficulty of perform checks goes down one rank; minor perform checks automatically succeed.", c_craft, "Musical Instrument");
        // Navigator's Tools
        all_feats_.emplace_back(FeatID::NavigatorsTools, 1, "Wayfinder", "Primary: Proficiency with Navigator's tools; add Intellect to navigation and map-reading checks. Secondary: 1/LR avoid becoming lost or reroute the party to a safer path.", c_craft, "Navigator's Tools");
        all_feats_.emplace_back(FeatID::NavigatorsTools, 2, "Star-Reader", "Primary: Add 2x Intellect to all Navigator's Tools checks. Secondary: On a failed navigation check, still determine general direction or location.", c_craft, "Navigator's Tools");
        all_feats_.emplace_back(FeatID::NavigatorsTools, 3, "Master Cartographer", "Primary: Add 2x Learnedness score to all Navigator's Tools checks. Secondary: 1/week chart a new faster or hidden route granting the party advantage on travel checks for the journey.", c_craft, "Navigator's Tools");
        // Painter's Supplies
        all_feats_.emplace_back(FeatID::PaintersSupplies, 1, "Novice Artist", "Primary: Proficiency with Painter's supplies; add Divinity to checks to create, appraise, or restore artwork. Secondary: As an action, paint a symbol granting an ally advantage on one social or morale check in the next minute.", c_craft, "Painter's Supplies");
        all_feats_.emplace_back(FeatID::PaintersSupplies, 2, "Inspired Creator", "Primary: Add 2x Divinity to all Painter's Supplies checks. Secondary: 1/LR on a failed art check, succeed instead without wasting materials.", c_craft, "Painter's Supplies");
        all_feats_.emplace_back(FeatID::PaintersSupplies, 3, "Master of Illusion", "Primary: Add 3x Divinity to all Painter's Supplies checks. Secondary: 1/week create artwork so lifelike it can distract, inspire, or briefly fool magical detection.", c_craft, "Painter's Supplies");
        // Poisoner's Kit
        all_feats_.emplace_back(FeatID::PoisonersKit, 1, "Novice Toxologist", "Primary: Proficiency with Poisoner's kit; add Vitality to checks to craft, identify, or apply poisons. Secondary: 1/LR create a basic poison: disadvantage on attacks for 1 round, or add 1d4 poison damage to a single weapon.", c_craft, "Poisoner's Kit");
        all_feats_.emplace_back(FeatID::PoisonersKit, 2, "Venom Adept", "Primary: Add 2x Vitality to all Poisoner's Kit checks. Secondary: 1/LR on a failed poison crafting or application check, avoid self-exposure and succeed instead.", c_craft, "Poisoner's Kit");
        all_feats_.emplace_back(FeatID::PoisonersKit, 3, "Master Poisoner", "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/week craft a potent poison that bypasses resistance or immunity for one use.", c_craft, "Poisoner's Kit");
        // Tinker's Tools
        all_feats_.emplace_back(FeatID::TinkersTools, 1, "Clever Fixer", "Primary: Proficiency with Tinker's tools; add Intellect to checks to repair, modify, or improvise small mechanical devices. Secondary: Improvise a tool or device granting you or an ally advantage on a related check.", c_craft, "Tinker's Tools");
        all_feats_.emplace_back(FeatID::TinkersTools, 2, "Resourceful Mechanic", "Primary: Add 2x Intellect to all Tinker's Tools checks. Secondary: 1/LR on a failed repair or invention check, succeed instead.", c_craft, "Tinker's Tools");
        all_feats_.emplace_back(FeatID::TinkersTools, 3, "Master Inventor", "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/LR create or modify an item to grant a unique situational benefit (bypass obstacle, resist hazard, or one-time magical/technological effect).", c_craft, "Tinker's Tools");
        // Weatherwise Tailoring
        all_feats_.emplace_back(FeatID::WeatherwiseTailoring, 1, "Weatherwise Weaver", "Primary: Proficiency with Weaver's Tools; craft/modify clothing for up to +-2 TRR; mend tears without a check. Secondary: Craft basic cloth items in half the normal time; identify temperature rating of clothing with DC 10 check.", c_craft, "Weatherwise Tailoring");
        all_feats_.emplace_back(FeatID::WeatherwiseTailoring, 2, "Climate Tailor", "Primary: Advantage on checks to create durable or decorative items (DC 15); craft up to +3 TRR gear. Secondary: Add minor property (water resistance, hidden pockets) without increasing DC; 1/LR grant ally advantage on Endurance check against environmental effects.", c_craft, "Weatherwise Tailoring");
        all_feats_.emplace_back(FeatID::WeatherwiseTailoring, 3, "Master of the Loom", "Primary: Reduce crafting time by half; craft +4 TRR gear; integrate dual-environment protection into single outfit. Secondary: Allies wearing your gear gain +1 to social Intellect checks; 1/item enchant with minor magical effect (4 SP or less, up to Intellect active items); +1d4 to Endurance checks in extreme environments.", c_craft, "Weatherwise Tailoring");

        // --- Ascendant Feats ---
        all_feats_.emplace_back(FeatID::PsychicMaw, 1, "Psychic Maw", "Requirements: Sacrifice 4 SP and 1 INT permanently; bargain with a psychic parasite; consume a brain. Effects: Void Exposure (3SP: 60ft blast 4d6 psychic, daze/confuse 1 min, heal half damage); Mind Break (3AP: stun 2d6 psychic 30 ft); Phase Shift (2AP: intangible until end of next turn); Maddening Aura (passive: enemies in 10 ft disadvantage on INT saves). Drawback: Vulnerable to radiant; feeding frenzy if sentient creature with INT >4 is within 30 ft.", c_ascendant, "Psychic Maw");
        all_feats_.emplace_back(FeatID::AbyssalUnleashing, 1, "Abyssal Unleashing", "Requirements: Sacrifice 4 SP and 1 INT; expose to corrupted Philosopher's Stone; kill divine-aligned creature. Effects: Frenzied Flurry (1AP: 3 attacks, last +2d6); Tissue Detonation (3AP: sacrifice 6HP, 3d6 force 5ft radius); Terrify the Weak (2AP: frighten lower HP creatures in 30 ft); Sporestorm (3AP: poison and confusion in 20 ft for 1 round); True Name (1/day reduce spell cost by 2 SP). Drawback: Vulnerable to radiant and psychic; disadvantage vs creatures knowing your true name.", c_ascendant, "Abyssal Unleashing");
        all_feats_.emplace_back(FeatID::AngelicRebirth, 1, "Angelic Rebirth", "Requirements: Sacrifice 4 SP and 1 STR; committed to Unity; fast 3 days at sacred place; forgiven enemy; die in service of divine cause. Effects: Immortal (no aging, 1/5 rate); Flight (1 AP reduced max: fly speed = foot speed); Radiant Pulse (3SP: 30ft 4d6 radiant blind 1 round); Healing Pulse (2SP: 3d6 to all allies in 30 ft); Safeguard Aura (3 AP reduced max: allies within 15 ft gain +2 AC). Drawback: Vulnerable to void magic; falling in love with a mortal removes flight and normal aging.", c_ascendant, "Angelic Rebirth");
        all_feats_.emplace_back(FeatID::CryptbornSovereign, 1, "Cryptborn Sovereign", "Requirements: Sacrifice 4 SP and 1 INT; waltz with spirits in haunted graveyard; bargain with a ghost; bind to crypt artifact and die interred for one night. Effects: Tomb's Curse (passive: 30 ft aura enemies -1 all rolls); Blight Touch (2AP: 2d6 necrotic, no healing for 1 round); Death Rattle (passive: on death 1d6+1d6/SP necrotic in 10 ft); Zombification (return to life in 24 hrs, regenerate body parts); Regeneration (passive: 1d6 HP/turn even at 0 HP). Drawback: Vulnerable to radiant; DC 12 INT save to avoid dancing if you see people dancing.", c_ascendant, "Cryptborn Sovereign");
        all_feats_.emplace_back(FeatID::DraconicApotheosis, 1, "Draconic Apotheosis", "Requirements: Sacrifice 5 SP; hoard shiny object 30 days; survive elemental trial; consume dragon heart. Effects: Flight (1 AP reduced max: fly speed = foot speed); Breath Weapon (2SP: 60ft cone 6d6 elemental damage); Draconic Scales (+2 AC, resistance to chosen element); Terrify the Weak (2AP: frighten lower HP creatures in 30 ft). Drawback: Vulnerable to silver beneath ribcage; laughter grounds flight; DC 11 INT save near inaccessible shiny objects.", c_ascendant, "Draconic Apotheosis");
        all_feats_.emplace_back(FeatID::FeyLordsPact, 1, "Fey Lord's Pact", "Requirements: Sacrifice 4 SP and 1 VIT; transform by fey magic for a day; tribute rare item to Fey Sovereign; enter pact. Effects: Disguise Flesh (2SP: mimic creature's form 1 hr); Teleport Swarm (4AP: teleport self + 3 allies within 120 ft); Charm Gaze (2SP: INT save DC 10+Divinity or charmed 1 min); Reality Distort (3 AP reduced max: alter terrain and visuals in 120 ft, INT save DC 10+Divinity). Drawback: Vulnerable to iron and necrotic; must uphold promises.", c_ascendant, "Fey Lord's Pact");
        all_feats_.emplace_back(FeatID::HagMothersCovenant, 1, "Hag Mother's Covenant", "Requirements: Sacrifice 4 SP and 1 VIT; consume sentient heart beneath dying tree; overseen by a Hag Mother or person you care most about. Effects: Dreamweaver's Gift (3SP: grant creature's deepest desire, always carries secret cost); Nightmare Brood (3 AP reduced max: summon 3 Dreamspawn level 1 creatures); Twisted Boon (2SP: offer boon for 24 hrs, marked creatures vulnerable to your spells); Soulroot Effigy (2SP activate, 1SP/day: bind soul fragment to object, perceive/cast through it). Drawback: Vulnerable to radiant; cannot cross salt circles; haggard appearance.", c_ascendant, "Hag Mother's Covenant");
        all_feats_.emplace_back(FeatID::InfernalCoronation, 1, "Infernal Coronation", "Requirements: Sacrifice 4 SP and one soul; intern for Archdevil; graduate Infernal Law School; survive trial of fire and law. Effects: Hellfire (5SP: 4d6 fire+2d6 thunder in 10 ft radius at 120 ft); Demonic Authority (auto-frighten lower Divinity creatures within 10 ft, no save); Second Chances (1/LR: on 0 HP, restore to 3x Vitality and teleport 120 ft); Flame Flicker Smite (free action: sacrifice HP for HPd4 fire on next hit); Devil Tail (manipulate 10 lbs within 5 ft, 1d4 magical slashing tail whip); Infernal Contract (3SP: bind willing/desperate creature to infernal contract). Drawback: Vulnerable to radiant; DC 15 INT save to resist contracts involving fiddles/violins.", c_ascendant, "Infernal Coronation");
        all_feats_.emplace_back(FeatID::KaijuCoreIntegration, 1, "Kaiju Core Integration", "Requirements: Sacrifice 4 SP and 1 SPD; consume Kaiju organ; swear oath to protect/destroy a region; roar from high peak; survive extreme elemental exposure. Effects: Titanic Strength (+2 STR, +2 VIT, +5 AP); Stampede Call (3SP: 60ft cone 6d6 push 30 ft); Gravity Slam (2SP: 3d6 force knock adjacent prone); Molten Skin (passive: melee attackers take 1d6 fire); size becomes Huge. Drawback: Vulnerable to psychic and mind control; DC 15 VIT save to avoid minor rampage if called 'just a big lizard'.", c_ascendant, "Kaiju Core Integration");
        all_feats_.emplace_back(FeatID::LycanthropicCurse, 1, "Lycanthropic Curse", "Requirements: Sacrifice 5 SP; bitten by cursed werebeast; kill and feast on animal during blood moon. Effects: Hybrid Form (Basic action, 1 round transform: +3 STR, +2 SPD, +20 ft move, threshold = Level/2, immune to non-silver/non-magical damage); Rending Bite (normal damage + 1d4 bleed/turn for 3 rounds); Blood Howl (on kill, allies in 30 ft gain +1d4 damage for 1 min); Regeneration (1d6 HP/turn). Drawback: Vulnerable to silver and radiant; DC 10 VIT save if tail touched or complimented in hybrid/beast form.", c_ascendant, "Lycanthropic Curse");
        all_feats_.emplace_back(FeatID::LichBinding, 1, "Lich Binding", "Requirements: Sacrifice 5 SP; dramatic graveyard monologue in thunderstorm; ritual with 1000 SP Philosopher's Stone and soul anchor; ritual in total darkness; die willingly with skeleton chorus. Effects: Undead (immune to poison, disease, aging); Phylactery (reform after death unless destroyed; transfer requires innocent soul); Soul Drain (3SP: 4d6 necrotic, heal half); Spark Steal (4AP: VIT save DC 10+Divinity or absorb 1d4 SP). Drawback: Vulnerable to radiant and divine disruption; sincere apologies cause DC 10 INT save or lose concentration; must absorb 1 innocent soul/year or lose immortality.", c_ascendant, "Lich Binding");
        all_feats_.emplace_back(FeatID::PrimordialElementalFusion, 1, "Primordial Elemental Fusion", "Requirements: Sacrifice 4 SP and 1 INT; travel to 3 elemental domains; stand atop a mountain and consume a living storm. Effects: Elemental Burst (2SP: 15 ft radius chosen element within 30 ft, 4d6); Shifting Hide (2 AP/resistance: resistance to one damage type, multiple instances allowed); Sunfire Pulse (3AP: 15 ft aura 2d6 fire + exhaustion); Frozen Grasp (3AP: 10 ft cone SPD save or frozen Speed=0). Drawback: Vulnerable to non-elemental damage; DC 13 INT save or loudly narrate weather if temperature shifts 10+ degrees.", c_ascendant, "Primordial Elemental Fusion");
        all_feats_.emplace_back(FeatID::SeraphicFlame, 1, "Seraphic Flame", "Requirements: Sacrifice 4 SP and 1 VIT; receive phoenix feather; walk Trial of the Blazing Path; complete Rite of Ascension atop sacred pyre. Effects: Flame Flicker (AP reduced: melee hits +1d4 fire per AP reduced); Explosive Mix (3SP: 10 ft radius 4d6 fire+2d6 thunder, reroll 1s); Reflective Veil (2SP: advantage vs magic 1 min, reflect 1 spell); Healing and Restoration (2SP: heal 3d6 to allies in 30 ft, 1/LR). Drawback: DC 16 DIV save when healing a creature actively cursing divinity or suffer 2d6 radiant backlash.", c_ascendant, "Seraphic Flame");
        all_feats_.emplace_back(FeatID::StormboundTitan, 1, "Stormbound Titan", "Requirements: Sacrifice 4 SP and 1 VIT; compose and perform a storm song; meal from storm-gathered ingredients; survive lightning storm with lightning-forged tattoo. Effects: Grow (active: increase size by 1 per AP reduced from max); Lightning Rod (3SP: 4d6 lightning to all in 10 ft when struck or activated); Arcshock Blink (1SP: teleport 30 ft, 2d6 lightning arcs in path); Stampede Call (3SP: 60 ft cone 6d6 push 30 ft); Gravity Slam (2SP: 3d6 force knock adjacent prone). Drawback: DC 15 VIT save if over 24 hrs without releasing lightning or small objects stick to you.", c_ascendant, "Stormbound Titan");
        all_feats_.emplace_back(FeatID::VampiricAscension, 1, "Vampiric Ascension", "Requirements: Sacrifice 5 SP; bitten by Vampire; allow heartbeat to be silenced; kill creature that begged mercy; consume blood during full moon. Effects: Blood Drain (heal half damage on bite); Intangible + Flight (3 AP reduced max: fly speed = foot speed, intangible); Nightvision (see in magical darkness 300 ft); Charm Gaze (INT save DC 16 or charmed 1 min); Regeneration (return to 1 HP in 24 hrs if not staked). Drawback: Vulnerable to radiant and wooden stakes; cannot approach within 5 ft of consecrated cross; DC 10 INT save when attractive bleeding creature is upwind.", c_ascendant, "Vampiric Ascension");
        all_feats_.emplace_back(FeatID::VoidbornMutation, 1, "Voidborn Mutation", "Requirements: Sacrifice 4 SP, lose 1 INT or VIT permanently; survive divine/arcane fracture; spend a month in total darkness; observe dissolution of something significant. Effects: Phase Shift (1AP: intangible for 1 round); Void Exposure (3SP: 60 ft blast 4d6 psychic, daze and confuse VIT save DC 10+Divinity); Reality Distort (3 AP reduced max: alter terrain and visuals in 30 ft, INT save DC 10+Divinity); Immortal Mask (1/LR: prevent death, restore to full HP when at or below 0 HP). Drawback: Vulnerable to radiant; sincere compliments cause DC 10 INT save or glitch between dimensions.", c_ascendant, "Voidborn Mutation");

        // --- Apex Feats ---
        all_feats_.emplace_back(FeatID::ArcaneOverdrive, 5, "Arcane Overdrive", "Primary: 5 SP to enter Overdrive (3 rounds). 3x AP regen, max melee dmg, push 10ft. Secondary: +2 AC, immune forced movement.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::BloodOfTheAncients, 5, "Blood of the Ancients", "Primary: 2 SP Bonus Action (2 rounds). +2 all saves, ignore first dmg instance each round. Secondary: Temp HP = DIV.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::CataclysmicLeap, 5, "Cataclysmic Leap", "Primary: 4 AP Move Action, leap 100ft. 30ft radius DC 17 Dex save or 4d10 force + prone. Secondary: 20ft difficult terrain.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::DivineReversal, 5, "Divine Reversal", "Primary: 1/LR fail save -> succeed and reflect back. Secondary: Area effect reflected from you.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::EclipseVeil, 5, "Eclipse Veil", "Primary: 2 SP for 120ft darkness (1 min). Secondary: DC 18 Int save or disadvantage att/perception.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::GravityShatter, 5, "Gravity Shatter", "Primary: 2 SP Action collapse space (60ft). 30ft DC 17 Str save or pulled to center and restrained. Secondary: Flying fall 30ft.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::HowlOfTheForgotten, 5, "Howl of the Forgotten", "Primary: 2 SP Action 60ft cry. DC 17 Int save or lose reaction + disadvantage next att. Secondary: Allies +2 morale/fear saves.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::IronTempest, 5, "Iron Tempest", "Primary: 5 AP Action 20ft whirlwind. 6d6 slashing, DC 16 Str save or pushed 15ft. Secondary: Move 30ft no opportunity.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::MythicRegrowth, 5, "Mythic Regrowth", "Primary: 1/LR 0 HP -> 1 HP + regen 50 HP for 2 turns. Secondary: Resistance all dmg until next turn.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::PhantomLegion, 5, "Phantom Legion", "Primary: 5 SP summon 3 clones (1 min). HP=2x DIV, mimic basic att. Secondary: Enemies disadvantage. Clones attack in sync.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::RunebreakerSurge, 5, "Runebreaker Surge", "Primary: 3 SP Bonus Action, next attack ignore resistance + double dmg vs shields/constructs. Secondary: Hit -> 2nd att vs different.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::Soulbrand, 5, "Soulbrand", "Primary: 1/round brand on dmg. No healing/regen for target until next turn. Secondary: Branded disadvantage vs your abilities.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::SoulflarePulse, 5, "Soulflare Pulse", "Primary: 3 SP Action 60ft pulse. DC 18 Div save or blinded/silenced (1 min). Secondary: Allies regain 10 HP, +1 next attack.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::StormboundMantle, 5, "Stormbound Mantle", "Primary: 3 SP Reaction (3 rounds). Ranged attacks disadvantage. Secondary: Melee attackers take 2d6 lightning on hit.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::TemporalRift, 5, "Temporal Rift", "Primary: 2 SP Action immediate additional turn. Secondary: Resistance all dmg until end of bonus turn.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::TitansEcho, 5, "Titan's Echo", "Primary: 5 AP Action roar (300ft). DC 18 Vit save or deafened/frightened/prone. Secondary: Structures take 4d10 thunder.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::VoidbrandCurse, 5, "Voidbrand Curse", "Primary: 2 SP on melee hit, curse 2 rounds. No regen, -2 saves. Secondary: Kill cursed -> regain 10 HP and 1 SP.", c_apex, "Apex");
        all_feats_.emplace_back(FeatID::WorldbreakerStep, 5, "Worldbreaker Step", "Primary: Passive, move > 50ft -> 20ft path difficult terrain, structures 3d10 force. Secondary: 10ft DC 16 Dex or prone + 1d10.", c_apex, "Apex");

        // --- Miscellaneous Feats ---
        all_feats_.emplace_back(FeatID::ArcLightSurge, 1, "Arc-Light Surge", "Primary: 1/LR basic action, discharge electric surge — all creatures within 10 ft make Speed save or take 1d6 lightning and drop metal items; spend 1 SP per additional 1d6. Secondary: Metal objects within 10 ft shed dim light for 1 round, revealing hidden or invisible creatures.", c_misc, "Arc-Light Surge");
        all_feats_.emplace_back(FeatID::ArcaneResidue, 1, "Arcane Residue", "Primary: 1/LR after casting a spell costing 3+ SP, leave a lingering magical zone in a 5 ft space for 1 minute; next creature entering takes 1d6 force damage. Secondary: If an ally moves through the zone, it heals the ally for 1d6 HP instead.", c_misc, "Arcane Residue");
        all_feats_.emplace_back(FeatID::AstralShear, 1, "Astral Shear", "Primary: 1/SR move through up to 15 ft of solid matter as part of a Move action. Secondary: Surface retains a shimmering scar for 1 round; creatures within 5 ft take 1d4 + Divinity psychic damage.", c_misc, "Astral Shear");
        all_feats_.emplace_back(FeatID::Bender, 1, "Bender", "Primary: 1/LR cast a minor spell (1-4 SP) without the SP cost; perform a minor miracle (alter terrain, defy physics). Secondary: Ignore one harmful condition score for that spell.", c_misc, "Bender");
        all_feats_.emplace_back(FeatID::BladeScripture, 1, "Blade Scripture", "Primary: 1/LR as part of an attack action, inscribe a rune on your weapon; for 10 minutes deals +1d6 radiant or necrotic damage (your choice) and you heal 1 HP each time you hit. Secondary: While active, weapon sheds dim light in 10 ft radius; activate or deactivate as a Basic action.", c_misc, "Blade Scripture");
        all_feats_.emplace_back(FeatID::BreathOfStone, 1, "Breath of Stone", "Primary: 1/LR as a Move action, brace your stance; for 1 minute immune to push/pull/prone, +2 AC; if standing on stone gain resistance to all damage. Secondary: While active, enemies that move within 5 ft have speed halved until end of their turn.", c_misc, "Breath of Stone");
        all_feats_.emplace_back(FeatID::BarkskinRitual, 1, "Barkskin Ritual", "Primary: 1/LR as an action, grow bark over skin or armor; for 1 hour gain +2 AC and resistance to slashing damage. Secondary: While active, creatures that grapple you or strike you in melee take 1 piercing damage at the start of their turn.", c_misc, "Barkskin Ritual");
        all_feats_.emplace_back(FeatID::ChaosFlow, 1, "Chaos's Flow", "Primary: 1/SR as a reaction, impose disadvantage on an enemy's check; if target succeeds, ability is not consumed and you can try again until a target fails. Secondary: If the enemy fails, you gain +1d4 to your next roll.", c_misc, "Chaos's Flow");
        all_feats_.emplace_back(FeatID::CoinreadersWink, 1, "Coinreader's Wink", "Primary: 1/LR basic action, study a creature's body language for 10 seconds; gain advantage on next Insight, Deception, or Persuasion check against that creature for 1 hour. Secondary: If you succeed, the target becomes more careless, lowering DC of future social checks against them by 2 for 1 hour.", c_misc, "Coinreader's Wink");
        all_feats_.emplace_back(FeatID::Dreamthief, 1, "Dreamthief", "Primary: 1/LR when you touch a sleeping or unconscious creature, glimpse a fleeting image of their last dream or memory. Secondary: Gain +1d4 to your next Insight or Speechcraft check made against that creature.", c_misc, "Dreamthief");
        all_feats_.emplace_back(FeatID::EchoedSteps, 1, "Echoed Steps", "Primary: 1/SR take a Move action as a free action. Secondary: If this movement ends in cover or concealment, regain 1 AP.", c_misc, "Echoed Steps");
        all_feats_.emplace_back(FeatID::Emberwake, 1, "Emberwake", "Primary: 1/SR as part of one move action, leave a trail of embers; enemies entering or starting in affected spaces take 1d6 fire damage and must succeed Speed save or have disadvantage on attacks until end of next turn. Secondary: Ignite non-magical flammable objects within 5 ft as a free action that round.", c_misc, "Emberwake");
        all_feats_.emplace_back(FeatID::ErylonsEcho, 2, "Erylon's Echo", "Primary: 1/LR for 1 hour, you and all allies gain +1d4 to all skill checks. Secondary: Allies also gain advantage on saving throws against fear during this time.", c_misc, "Erylon's Echo");
        all_feats_.emplace_back(FeatID::FlareOfDefiance, 1, "Flare of Defiance", "Primary: 1/LR when reduced below half HP, shout a defiant challenge as a Free Action; all enemies within 30 ft make Speed save or suffer disadvantage on their next attack and become Enraged for 1 minute. Secondary: If at least one enemy fails, gain +1d4 bonus HP per enemy that failed.", c_misc, "Flare of Defiance");
        all_feats_.emplace_back(FeatID::FlickerSparky, 1, "Flicker Sparky", "Primary: 1/SR when you take damage, immediately teleport up to 10 ft to a visible space and your attacker takes 1d4 lightning damage as you leap away. Secondary: After teleporting, gain resistance to all damage until end of your next turn.", c_misc, "Flicker Sparky");
        all_feats_.emplace_back(FeatID::HollowVoice, 1, "Hollow Voice", "Primary: 1/SR mimic any sound or voice heard in past 24 hours for 10 minutes; creatures must succeed Insight (DC 10 + Speechcraft) to detect ruse. Secondary: If used to distract or mislead, allies gain advantage on their next Sneak or Cunning check against that target.", c_misc, "Hollow Voice");
        all_feats_.emplace_back(FeatID::HollowedInstinct, 1, "Hollowed Instinct", "Primary: 1/SR as a Reaction when targeted by a creature you cannot see, negate advantage against you for 1 minute. Secondary: If the attack still hits, immediately move 10 ft without provoking opportunity attacks.", c_misc, "Hollowed Instinct");
        all_feats_.emplace_back(FeatID::IllusoryDouble, 1, "Illusory Double", "Primary: 1/SR basic action, create a harmless illusory version of yourself for 1 minute or until destroyed (3 hits); if an enemy attack hits you, roll d6 — on 3 or less it hits the illusion instead. Secondary: While illusion is active, enemies within 10 ft of both you have disadvantage on opportunity attacks against you.", c_misc, "Illusory Double");
        all_feats_.emplace_back(FeatID::LockTapLord, 1, "Locktap Lord", "Primary: Gain advantage on Cunning checks to pick locks, disable traps, or detect hidden compartments. Secondary: 1/LR attempt to pick a lock or disable a device without tools, even under magical suppression.", c_misc, "Locktap Lord");
        all_feats_.emplace_back(FeatID::LoreweaversMark, 1, "Loreweaver's Mark", "Primary: 1/LR basic action, etch or whisper a magical glyph onto a surface or creature; sense its general direction while within 100 ft. Secondary: If placed on a willing creature, they gain +1 to their saves.", c_misc, "Loreweaver's Mark");
        all_feats_.emplace_back(FeatID::MirrorsteelGlint, 1, "Mirrorsteel Glint", "Primary: 1/LR reflect a spell targeting only you back at its caster (SP cost <= your level; Arcane check vs DC 10 + spell SP). Secondary: Gain resistance to that spell's damage type until your next turn regardless of outcome.", c_misc, "Mirrorsteel Glint");
        all_feats_.emplace_back(FeatID::PlanarGraze, 1, "Planar Graze", "Primary: 1/SR when you make a melee or ranged attack, on a hit deal +1d8 force damage and push target 15 ft (no save). Secondary: If target hits a solid surface, they take +1d6 psychic damage.", c_misc, "Planar Graze");
        all_feats_.emplace_back(FeatID::RefractionTwist, 1, "Refraction Twist", "Primary: 1/SR as a reaction when targeted by an attack you can see, impose disadvantage on it as light bends around you. Secondary: If the attack still hits, take half damage from it.", c_misc, "Refraction Twist");
        all_feats_.emplace_back(FeatID::ResonantPulse, 1, "Resonant Pulse", "Primary: 1/LR emit a harmonic pulse in a 10 ft radius; allies in the area gain +1d4 to attack rolls, skill checks, or saving throws for 1 minute. Secondary: Regain SP equal to the number of allies that benefit (cannot exceed maximum).", c_misc, "Resonant Pulse");
        all_feats_.emplace_back(FeatID::RuneCipher, 1, "Rune Cipher", "Primary: 1/SR for 1 hour, read any written language — magical or mundane, including runes, ancient glyphs, or magical scripts. Secondary: 1/LR automatically uncover a hidden message, secret, or ward in writing without a check.", c_misc, "Rune Cipher");
        all_feats_.emplace_back(FeatID::SacredFragmentation, 1, "Sacred Fragmentation", "Primary: 1/SR cast a spell at half its normal SP cost (round up). Secondary: This spell cannot be countered or nullified.", c_misc, "Sacred Fragmentation");
        all_feats_.emplace_back(FeatID::FeatSacrifice, 1, "Sacrifice", "Primary: 1/LR free action, give an ally some of your HP; for every 1 HP sacrificed, an ally regains 2 HP. Secondary: The ally also gains +1 to their next saving throw.", c_misc, "Sacrifice");
        all_feats_.emplace_back(FeatID::SkywatchersSight, 1, "Skywatcher's Sight", "Primary: 1/LR declare a creature, location, or object you seek; for 1 hour gain advantage on all Perception and Insight checks related to finding it. Secondary: Roll 1d100 — the higher the number, the clearer the vision of its current state.", c_misc, "Skywatcher's Sight");
        all_feats_.emplace_back(FeatID::SparkLeech, 1, "Spark Leech", "Primary: 1/SR as a reaction when a creature within 10 ft casts a spell, force a Divinity save (DC 10 + Divinity); on failure, steal SP equal to your Divinity score. Secondary: If successful, gain +1 to your next saving throw.", c_misc, "Spark Leech");
        all_feats_.emplace_back(FeatID::SplitSecondRead, 1, "Split Second Read", "Primary: 1/LR free action, instantly learn if a creature is afraid, angry, calm, or hiding something — no check required. Secondary: Gain +1 to AC or saving throws against effects initiated by that creature for the next 10 minutes.", c_misc, "Split Second Read");
        all_feats_.emplace_back(FeatID::Soulmark, 1, "Soulmark", "Primary: 1/LR as an action, mark a creature within 60 ft (Divinity save DC 10 + Intellect); for 1 hour know its direction and distance even out of sight. Secondary: Send simple emotions or sensations to the marked creature during this time.", c_misc, "Soulmark");
        all_feats_.emplace_back(FeatID::TemporalShift, 1, "Temporal Shift", "Primary: 1/LR basic action, spend SP to bless or curse a number of targets equal to SP spent for 1 minute (no save); Bless: +1d4 to checks | Curse: -1d4 to checks. Secondary: Blessed allies gain +5 ft movement; cursed enemies lose 5 ft movement.", c_misc, "Temporal Shift");
        all_feats_.emplace_back(FeatID::TetherLink, 1, "Tether Link", "Primary: 1/LR create a link with a willing ally within 30 ft; as a free action either of you may transfer HP 1-for-1. Secondary: While linked, both gain +1 to Insight checks involving each other and can sense the other's emotional state.", c_misc, "Tether Link");
        all_feats_.emplace_back(FeatID::VeilbreakerVoice, 3, "Veilbreaker Voice", "Primary: 1/LR shout with supernatural force; all magical illusions or disguises within 20 ft are suppressed for 1 minute. Secondary: Allies within range who are Charmed or Frightened have those conditions suppressed for 1 minute.", c_misc, "Veilbreaker Voice");
        all_feats_.emplace_back(FeatID::VerdantPulse, 1, "Verdant Pulse", "Primary: 1/LR basic action, cause plant life in a 10 ft radius to bloom; create difficult terrain, concealment, or edible herbs (sustains 3 people; 1 SP per 2 additional people). Secondary: Allies in the area gain +1 to Vitality saving throws for 1 hour.", c_misc, "Verdant Pulse");
        all_feats_.emplace_back(FeatID::VeyrasVeil, 2, "Veyra's Veil", "Primary: 1/LR over 10 minutes, prepare yourself; for the next hour gain advantage on Sneak and Cunning checks. Secondary: Leave no tracks or scent trail while this effect is active.", c_misc, "Veyra's Veil");
        all_feats_.emplace_back(FeatID::UnitysEbb, 1, "Unity's Ebb", "Primary: 1/LR choose one: (1) Cast a healing spell costing <= level SP without spending SP; (2) Sacrifice SP to regain xd4 SP where x = SP sacrificed (cannot exceed max); (3) Mend a non-magical Large-or-smaller object to full HP. Secondary: (1) Target gains temp resistance to a damage type 1 hr; (2) Equipment magically cleaned, +1 Speechcraft 1 hr; (3) Object becomes unbreakable 10 min.", c_misc, "Unity's Ebb");
        all_feats_.emplace_back(FeatID::Whispers, 1, "Whispers", "Primary: 1/LR as a reaction, gain a bonus of 1d6 on any check; if you roll 1 the die upgrades a size (max 1d12); if you roll max it downgrades a size (min 1d4); ability consumed when you roll a 4 on a 1d4. Secondary: As a reaction to an ally rolling a check, grant them your bonus with the same escalation/de-escalation rules.", c_misc, "Whispers");
    }

    std::vector<Feat> all_feats_;
};

} // namespace rimvale

#endif // RIMVALE_FEATS_H
