#ifndef RIMVALE_FACTION_H
#define RIMVALE_FACTION_H

#include <string>
#include <vector>
#include <map>

namespace rimvale {

struct FactionRank {
    std::string title;
    std::string benefit;
};

struct Faction {
    std::string name;
    std::string region;
    std::string influence;
    std::string territory_feature;
    std::vector<FactionRank> ranks;
};

class FactionRegistry {
public:
    static FactionRegistry& instance() {
        static FactionRegistry registry;
        return registry;
    }

    [[nodiscard]] const Faction* get_faction(const std::string& name) const {
        auto it = factions_.find(name);
        return (it != factions_.end()) ? &it->second : nullptr;
    }

    [[nodiscard]] std::vector<std::string> get_all_faction_names() const {
        std::vector<std::string> names;
        names.reserve(factions_.size());
        for (const auto& pair : factions_) names.push_back(pair.first);
        return names;
    }

private:
    FactionRegistry() {
        // --- Arcane Containment Foundation (ACF) ---
        Faction acf = {"Arcane Containment Foundation", "The Metropolitan",
            "Safeguards reality from magical instability. Recovery and suppression specialists.",
            "Magical items cannot trigger Overreach unless pushed."};
        acf.ranks.push_back({"Novice Seeker", "Adv. on Arcane checks to identify anomalies."});
        acf.ranks.push_back({"Containment Agent", "Can cast Arcane Seal once per long rest."});
        acf.ranks.push_back({"Senior Specialist", "May suppress one magical effect within 15 ft."});
        acf.ranks.push_back({"Archmage Director", "Can create a temporary 10ft null zone."});
        register_faction(std::move(acf));

        // --- The Circle of the Verdant Oak ---
        Faction circle = {"The Circle of the Verdant Oak", "Forest of SubEden",
            "Guardians of nature and primal magic. Oversee sacred groves.",
            "Regain +1 HP per hour of rest. Adv. on Nature checks."};
        circle.ranks.push_back({"Initiate of the Grove", "+1d4 to Survival checks."});
        circle.ranks.push_back({"Warden of the Wilds", "Summon plant life to entangle (DC 13 STR)."});
        circle.ranks.push_back({"Druidic Elder", "May speak with plants and beasts at will."});
        circle.ranks.push_back({"High Keeper", "Create a sanctuary grove (30ft) that heals."});
        register_faction(std::move(circle));

        // --- The Order of the Crimson Blade ---
        Faction crimson = {"The Order of the Crimson Blade", "The Mortal Arena",
            "Warrior brotherhood focused on honor through combat.",
            "+1d4 to weapon attacks in duels. Fear resistance."};
        crimson.ranks.push_back({"Initiate of the Blade", "+1 to attack rolls during duels."});
        crimson.ranks.push_back({"Shadowstriker", "Adv. on initiative; +1d4 damage on first attack."});
        crimson.ranks.push_back({"Bloodblade", "+1d6 damage when below half HP."});
        crimson.ranks.push_back({"Crimson Lord", "Grant disadvantage to all attackers for 1 min."});
        register_faction(std::move(crimson));

        // --- The Iron Legion ---
        Faction iron = {"The Iron Legion", "Vulcan Valley",
            "Militarized faction known for war machines and heavy armor.",
            "Armor durability is doubled. Resist env. bludgeoning."};
        iron.ranks.push_back({"Iron Recruit", "+1 to AC when wearing heavy armor."});
        iron.ranks.push_back({"Legionnaire", "Resist non-magical bludgeoning. Carry 2x weight."});
        iron.ranks.push_back({"Iron Captain", "Allies within 10 ft gain +1 to AC."});
        iron.ranks.push_back({"Warbringer", "Deploy a Siege Zone (30 ft radius)."});
        register_faction(std::move(iron));

        // --- The Guild of Shadows ---
        Faction shadows = {"The Guild of Shadows", "The Shadows Beneath",
            "Masters of espionage, illusion, and subterfuge.",
            "Advantage on Sneak checks. Illusion spells cost -1 SP."};
        shadows.ranks.push_back({"Rook", "Hide in dim light as a free action."});
        shadows.ranks.push_back({"Shadowblade", "+1d4 damage when attacking from stealth."});
        shadows.ranks.push_back({"Nightlord", "Teleport between shadows (30 ft)."});
        shadows.ranks.push_back({"Guildmaster", "Create a shadow veil (15 ft) for allies."});
        register_faction(std::move(shadows));

        // --- The Silver Serpents ---
        Faction serpents = {"The Silver Serpents", "The Upper Forty",
            "Mercantile syndicate controlling trade routes and finance.",
            "Reroll one failed Speechcraft/Barter. Rare items 10% cheaper."};
        serpents.ranks.push_back({"Serpent Initiate", "Appraise items instantly."});
        serpents.ranks.push_back({"Silver Agent", "+10% profit when selling items."});
        serpents.ranks.push_back({"Serpent Master", "Call in a trade favor (rare item/info)."});
        serpents.ranks.push_back({"Grandmaster", "Manipulate settlement prices by 20%."});
        register_faction(std::move(serpents));

        // --- Scholars of the Eternal Library ---
        Faction scholars = {"The Scholars of the Eternal Library", "Eternal Library",
            "Keepers of knowledge, theory, and historical truth.",
            "Take 10 on Arcane/Learnedness checks."};
        scholars.ranks.push_back({"Student", "Identify magical items without a roll."});
        scholars.ranks.push_back({"Lorekeeper", "Record a memory into a tome to share later."});
        scholars.ranks.push_back({"Archivist", "Store one spell in a tome (Arcane Seal)."});
        scholars.ranks.push_back({"Grand Sage", "Create a temporary knowledge archive field."});
        register_faction(std::move(scholars));

        // --- The FlameWardens ---
        Faction flamewardens = {"The FlameWardens", "Vulcan Valley",
            "Protectors of elemental fire and sacred flame.",
            "Fire resistance. Ignite objects w/o AP. Fire +1 dmg/die."};
        flamewardens.ranks.push_back({"Ember Recruit", "Light torches without AP or SP."});
        flamewardens.ranks.push_back({"Flame Adept", "Fire spells -2 SP cost (min 1)."});
        flamewardens.ranks.push_back({"Fire Marshal", "Create a fire shield (15 ft radius)."});
        flamewardens.ranks.push_back({"Grand Flamewarden", "Create a Pyre Field (20 ft radius)."});
        register_faction(std::move(flamewardens));

        // --- The Storm Walkers ---
        Faction stormwalkers = {"The Storm Walkers", "The Astral Tear",
            "Nomadic order attuned to astral storms and weather.",
            "Immunity to weather movement penalties. Lightning +1d4 dmg."};
        stormwalkers.ranks.push_back({"Skybound", "Cast Gust once per short rest."});
        stormwalkers.ranks.push_back({"Stormcaller", "Flight (10 ft) during storms."});
        stormwalkers.ranks.push_back({"Tempest Master", "Summon a storm (30 ft) deals 1d6 dmg."});
        stormwalkers.ranks.push_back({"Thunderlord", "Cast Chain Lightning w/o SP cost."});
        register_faction(std::move(stormwalkers));
    }

    void register_faction(Faction f) {
        factions_[f.name] = std::move(f);
    }

    std::map<std::string, Faction> factions_;
};

} // namespace rimvale

#endif // RIMVALE_FACTION_H
