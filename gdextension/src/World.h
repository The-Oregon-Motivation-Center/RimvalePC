#ifndef RIMVALE_WORLD_H
#define RIMVALE_WORLD_H

#include <string>
#include <vector>
#include <map>

namespace rimvale {

struct Terrain {
    std::string name;
    std::vector<std::string> beneficial_conditions;
    std::vector<std::string> harmful_conditions;
};

struct Region {
    std::string name;
    int base_trr = 0; // baseline TRR requirement
    std::string climate_summary;
    std::vector<Terrain> terrains;
};

class WorldRegistry {
public:
    static WorldRegistry& instance() {
        static WorldRegistry registry;
        return registry;
    }

    [[nodiscard]] const Region* get_region(const std::string& name) const {
        auto it = regions_.find(name);
        return (it != regions_.end()) ? &it->second : nullptr;
    }

    [[nodiscard]] std::vector<std::string> get_all_region_names() const {
        std::vector<std::string> names;
        names.reserve(regions_.size());
        for (const auto& pair : regions_) names.push_back(pair.first);
        return names;
    }

private:
    WorldRegistry() {
        // --- The Plains (Unity) ---
        Region plains = {"The Plains", 0, "Temperate, seasonal, mild weather"};
        plains.terrains.push_back({"Rolling Grasslands", {"+2 Perception", "+1 AP regen"}, {"-2 Stealth", "Vulnerable to ranged"}});
        plains.terrains.push_back({"Ancestral Barrows", {"Reroll failed DIV save", "+2 Insight"}, {"-2 VIT saves in necrotic", "Fear risk"}});
        plains.terrains.push_back({"House of Arachana", {"Adv. on hearing Perception"}, {"-2 Speed", "Restrained risk"}});
        plains.terrains.push_back({"Kingdom of Qunorum", {"+1 Speechcraft", "Adv. Intuition social"}, {"Crowds: -1 Initiative", "-2 Sneak"}});
        plains.terrains.push_back({"Wilds of Endero", {"+2 Sneak", "+1 for foraging"}, {"-2 Speed saves", "Disadv. Vitality humidity"}});
        plains.terrains.push_back({"Forest of SubEden", {"+2 Divinity checks", "Adv. vs illusion"}, {"-2 Intellect", "Random initiative"}});
        plains.terrains.push_back({"Eternal Library", {"+2 Arcane/Learnedness", "Recall 1 fact"}, {"Whispers: Disadv. Intellect"}});
        register_region(std::move(plains));

        // --- The Metropolitan (Unity) ---
        Region metro = {"The Metropolitan", 1, "Mild in Upper Forty, polluted and hot in Lower Forty"};
        metro.terrains.push_back({"Upper Forty", {"+2 Acrobatics", "+2 Speechcraft elites"}, {"Surveillance: -2 Stealth"}});
        metro.terrains.push_back({"Lower Forty", {"Resistance to fire", "+2 STR machines"}, {"-2 Perception smoke", "Disease risk"}});
        metro.terrains.push_back({"Rooftop Heights", {"+2 Acrobatics", "Adv. Perception above"}, {"Vulnerable to shove/falling"}});
        metro.terrains.push_back({"Neon Alleyways", {"Adv. Cunning"}, {"Disadv. ranged attacks"}});
        register_region(std::move(metro));

        // --- The Shadows Beneath (Void) ---
        Region shadows = {"The Shadows Beneath", 1, "Cool, damp, necrotic chill, miasmas"};
        shadows.terrains.push_back({"Corrupted Marshes", {"+2 Stealth", "Immune to disease"}, {"Vulnerable to necrotic", "Difficult terrain"}});
        shadows.terrains.push_back({"Spindle York’s Schism", {"+1 Arcane", "+1 save vs fear"}, {"Disadv. Initiative rolls"}});
        shadows.terrains.push_back({"Crypt at the End of Valley", {"Resistance to necrotic", "+1 Religion"}, {"Exhaustion risk at dawn"}});
        register_region(std::move(shadows));

        // --- Peaks of Isolation (Void) ---
        Region peaks = {"Peaks of Isolation", 4, "Bitter cold, blizzards, thin air"};
        peaks.terrains.push_back({"Frozen Spires", {"Resistance to cold", "+1 Survival"}, {"Slippery surfaces", "-1 Initiative"}});
        peaks.terrains.push_back({"Pharaoh’s Den", {"Immune to fear", "+1 save vs necrotic"}, {"-2 Vitality checks", "Vulnerable radiant"}});
        peaks.terrains.push_back({"The Darkness", {"+2 sneak", "Can throw voice"}, {"Echoes: Disadv. Learnedness/Survival"}});
        peaks.terrains.push_back({"Arcane Collapse", {"Cast 1 minor spell for 0 SP", "+2 Arcana"}, {"Overreach surges on 1-3"}});
        peaks.terrains.push_back({"Argent Hall", {"+2 Survival minerals", "Cold resistance"}, {"Halved speed w/o insulation"}});
        register_region(std::move(peaks));

        // --- The Glass Passage (Void) ---
        Region glass = {"The Glass Passage", 4, "Blistering heat, frigid nights, glass storms"};
        glass.terrains.push_back({"Shimmering Dunes", {"+1 Sneak", "Illusions more effective"}, {"Exhaustion in daylight"}});
        glass.terrains.push_back({"Sacral Separation", {"+2 Stealth (silent sands)"}, {"25% Spell failure (verbal)"}});
        glass.terrains.push_back({"Infernal Machine", {"+2 checks vs constructs"}, {"Loud gears: 10% spell failure"}});
        register_region(std::move(glass));

        // --- Titan’s Lament (Chaos) ---
        Region titans = {"Titan’s Lament", 3, "Volcanic, unstable, alternating heat and chill"};
        titans.terrains.push_back({"Mortal Arena", {"+2 Perform", "+1 Attack roll witnessed"}, {"Enemies adv. if hostile crowd"}});
        titans.terrains.push_back({"Vulcan Valley", {"Fire spells +1 damage/die"}, {"Metal heats: 1 fire dmg/round"}});
        register_region(std::move(titans));

        // --- The Isles (Chaos) ---
        Region isles = {"The Isles", 2, "Subtropical, stormy, unpredictable"};
        isles.terrains.push_back({"Depths of Denorim", {"+2 Stealth/Perception underwater"}, {"Crushing pressure", "Cold"}});
        isles.terrains.push_back({"Moroboros", {"Adv. vs Enchantment"}, {"Disadv. navigation", "Disoriented"}});
        isles.terrains.push_back({"Gloamfen Hollow", {"Dash as bonus action sliding"}, {"Poison fumes risk"}});
        register_region(std::move(isles));

        // --- Astral Tear (Chaos) ---
        Region astral = {"Astral Tear", 3, "Frigid, otherworldly, planar winds"};
        astral.terrains.push_back({"L.I.T.O.", {"+2 Intuition", "Adv. vs charm"}, {"-2 Intellect", "Disadv. Divinity saves"}});
        astral.terrains.push_back({"West End Gullet", {"+1 Arcane", "Detect Magic active"}, {"Reality distortion (Confusion)"}});
        astral.terrains.push_back({"Cradling Depths", {"Darkvision +30ft", "See invisible"}, {"Shadow whispers (Psychic risk)"}});
        register_region(std::move(astral));

        // --- Terminus Volarus (Unity) ---
        Region terminus = {"Terminus Volarus", 4, "Frigid base, colder as you ascend"};
        terminus.terrains.push_back({"City of Eternal Light", {"Never need sleep", "+2 VIT saves"}, {"Vulnerable to radiant"}});
        terminus.terrains.push_back({"Land of Tomorrow", {"+2 Learnedness", "Adv. vs radiation"}, {"-2 Performance (detachment)"}});
        terminus.terrains.push_back({"Hallowed Sacrament", {"+1 to all saving throws"}, {"Blinded in darkness", "-2 Stealth if not divine"}});
        register_region(std::move(terminus));

        // --- Sublimini Dominus (Mix) ---
        Region void_realm = {"Sublimini Dominus", 5, "Paradoxical, freezing and burning, void exposure"};
        void_realm.terrains.push_back({"Echo Pools", {"Restoring 1 SP per hour"}, {"Auditory hallucinations (Confusion risk)"}});
        void_realm.terrains.push_back({"Null Zones", {"Immunity to magical detection"}, {"Spellcasting cost x2", "Items inert"}});
        void_realm.terrains.push_back({"Beating Heart of the Void", {"+2 Arcana/DIV involving sound"}, {"Psychic risk verbal spells"}});
        register_region(std::move(void_realm));
    }

    void register_region(Region r) {
        regions_[r.name] = std::move(r);
    }

    std::map<std::string, Region> regions_;
};

} // namespace rimvale

#endif // RIMVALE_WORLD_H
