#ifndef RIMVALE_QUEST_H
#define RIMVALE_QUEST_H

#include <string>
#include <vector>
#include <map>
#include "Dice.h"

namespace rimvale {

struct GeneratedQuest {
    std::string title;
    std::string region;
    std::string type;
    std::string threat;
    std::string objective;
    std::string anomaly;
    std::string complication;
    std::string description;
};

class QuestRegistry {
public:
    static QuestRegistry& instance() {
        static QuestRegistry registry;
        return registry;
    }

    [[nodiscard]] std::vector<GeneratedQuest> get_quests_by_region(const std::string& region) const {
        auto it = region_quests_.find(region);
        return (it != region_quests_.end()) ? it->second : std::vector<GeneratedQuest>();
    }

    [[nodiscard]] std::vector<std::string> get_all_regions() const {
        std::vector<std::string> regions;
        regions.reserve(region_quests_.size());
        for (const auto& pair : region_quests_) regions.push_back(pair.first);
        std::sort(regions.begin(), regions.end());
        return regions;
    }

private:
    QuestRegistry() {
        // --- The Plains ---
        region_quests_["The Plains"] = {
            {"The Whispering Winds", "The Plains", "Investigation", "Sentient Artifact", "Recover the artifact", "Psychic resonance", "Betrayal from within", "Haunting voices lead travelers to danger."},
            {"Seeds of Desolation", "The Plains", "Purification", "Corrupted Fauna", "Stabilize the region", "Elemental surge", "Terrain shifts mid-quest", "Carnivorous plant monsters spread a deadly blight."},
            {"The Wanderer’s Echo", "The Plains", "Containment", "Void Entity", "Seal the anomaly", "Memory erasure", "Target is not what it seems", "A mysterious figure drains life from villages at night."}
        };

        // --- House of Arachana ---
        region_quests_["House of Arachana"] = {
            {"The Weaver's Rebirth", "House of Arachana", "Ritual Disruption", "Divine Guardian", "Destroy the threat", "Gravity distortion", "Reality begins to collapse", "An ancient spider deity awakens beneath the webs."},
            {"The Silk of Fates", "House of Arachana", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Time dilation", "Artifact is cursed", "Fate-altering spiders have escaped containment."},
            {"The Widow’s Lament", "House of Arachana", "Investigation", "Shadowspawn", "Extract vital intel", "Illusion field", "Enemy reinforcements arrive", "A widow lures travelers into a mansion of no return."}
        };

        // --- Kingdom of Qunorum ---
        region_quests_["Kingdom of Qunorum"] = {
            {"The King’s Shadow", "Kingdom of Qunorum", "Containment", "Sentient Artifact", "Recover the artifact", "Memory erasure", "Artifact is cursed", "A cursed sword binds itself to the reigning monarch."},
            {"Forgotten Throne", "Kingdom of Qunorum", "Reality Stabilization", "Reality Distortion", "Stabilize the region", "Time dilation", "Reality begins to collapse", "A phantom court from a bygone dynasty appears."},
            {"Royal Alchemist’s Bane", "Kingdom of Qunorum", "Containment", "Rogue Construct", "Destroy the threat", "Elemental surge", "Enemy reinforcements arrive", "Sentient homunculi seek to overthrow the kingdom."}
        };

        // --- Wilds of Endero ---
        region_quests_["Wilds of Endero"] = {
            {"Beastlord’s Return", "Wilds of Endero", "Purification", "Divine Guardian", "Perform a counter-ritual", "Psychic resonance", "Betrayal from within", "A powerful druid's spirit makes animals aggressive."},
            {"Horns of the Forgotten", "Wilds of Endero", "Containment", "Corrupted Fauna", "Extract vital intel", "Gravity distortion", "Terrain shifts mid-quest", "A herd of dimensional elk appears in the wilds."},
            {"The Howling Moon", "Wilds of Endero", "Investigation", "Magical Catastrophe", "Destroy the threat", "Time dilation", "Time limit imposed", "A strange howl transforms people into were-beasts."}
        };

        // --- The Metropolitan ---
        region_quests_["The Metropolitan"] = {
            {"The Iron Watcher", "The Metropolitan", "Sabotage", "Rogue Construct", "Destroy the threat", "Elemental surge", "Terrain shifts mid-quest", "A powerful security golem has gone rogue."},
            {"The Crimson Writ", "The Metropolitan", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Memory erasure", "Rival faction interference", "A forbidden book of madness surfaces in the black market."},
            {"The Forgotten Alley", "The Metropolitan", "Rescue", "Reality Distortion", "Escort the target safely", "Time dilation", "Reality begins to collapse", "A spatial rift in an alleyway is 'disappearing' citizens."}
        };

        // --- The Shadows Beneath ---
        region_quests_["The Shadows Beneath"] = {
            {"The Whispering Crypt", "The Shadows Beneath", "Purification", "Undead Horde", "Destroy the threat", "Psychic resonance", "Terrain shifts mid-quest", "Dark whispers reanimate dead in the valley."},
            {"The Lich's Dominion", "The Shadows Beneath", "Ritual Disruption", "Divine Guardian", "Perform a counter-ritual", "Memory erasure", "Enemy reinforcements arrive", "Malikai Greymoor expands his necrotic domain."},
            {"The Schism’s Edge", "The Shadows Beneath", "Reality Stabilization", "Void Entity", "Seal the anomaly", "Gravity distortion", "Reality begins to collapse", "A rift to Sublimini Dominus opens at Spindle York."}
        };

        // --- Peaks of Isolation ---
        region_quests_["Peaks of Isolation"] = {
            {"Heart of the Storm", "Peaks of Isolation", "Containment", "Elemental Storm", "Recover the artifact", "Elemental surge", "Time limit imposed", "An eternal storm erupts over the highest peak."},
            {"Echoes of the Lost", "Peaks of Isolation", "Investigation", "Reality Distortion", "Extract vital intel", "Memory erasure", "Target is not what it seems", "Voices of lost companions lead climbers to their doom."},
            {"The Frozen Shade", "Peaks of Isolation", "Ritual Disruption", "Void Entity", "Perform a counter-ritual", "Time dilation", "Enemy reinforcements arrive", "A shadowy spirit freezes everything it touches."}
        };

        // --- The Glass Passage ---
        region_quests_["The Glass Passage"] = {
            {"The Prism of Ages", "The Glass Passage", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Time dilation", "Rival faction interference", "A shattered artifact manipulates time in the dunes."},
            {"The Crystal Bloom", "The Glass Passage", "Purification", "Magical Catastrophe", "Stabilize the region", "Elemental surge", "Terrain shifts mid-quest", "Crystalline flowers turn those who touch them into glass."},
            {"Mirror Realm Echoes", "The Glass Passage", "Reality Stabilization", "Reality Distortion", "Seal the anomaly", "Illusion field", "Reality begins to collapse", "Sentient reflections attempt to swap places with people."}
        };

        // --- Titan’s Lament ---
        region_quests_["Titan’s Lament"] = {
            {"Heart of the Colossus", "Titan’s Lament", "Sabotage", "Rogue Construct", "Destroy the threat", "Gravity distortion", "Terrain shifts mid-quest", "A dormant titan colossus begins to stir."},
            {"The Shattered Giant", "Titan’s Lament", "Purification", "Undead Horde", "Seal the anomaly", "Memory erasure", "Enemy reinforcements arrive", "Skeleton titan bones begin reanimating across the land."},
            {"Tears of the Mountain", "Titan’s Lament", "Investigation", "Elemental Storm", "Extract vital intel", "Elemental surge", "Time limit imposed", "Molten stone erupts from the eyes of a colossal statue."}
        };

        // --- The Isles ---
        region_quests_["The Isles"] = {
            {"The Sunken Crown", "The Isles", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Psychic resonance", "Artifact is cursed", "A sea king's crown compels victims to walk into the ocean."},
            {"The Silver Tide", "The Isles", "Investigation", "Corrupted Fauna", "Extract vital intel", "Illusion field", "Enemy reinforcements arrive", "Hostile silver mist is reshaping the tides."},
            {"The Leviathan's Call", "The Isles", "Containment", "Void Entity", "Seal the anomaly", "Memory erasure", "Reality begins to collapse", "A hypnotic song lures sailors to a slumbering leviathan."}
        };

        // --- Astral Tear ---
        region_quests_["Astral Tear"] = {
            {"The Shattered Sky", "Astral Tear", "Reality Stabilization", "Dimensional tear", "Seal the anomaly", "Gravity distortion", "Reality begins to collapse", "A cosmic rift leaks destructive forces into the city."},
            {"Celestial Choir", "Astral Tear", "Rescue", "Divine Guardian", "Escort the target safely", "Memory erasure", "Enemy reinforcements arrive", "The city's maintaining song has fallen silent."},
            {"Labyrinth of Night", "Astral Tear", "Artifact Recovery", "Void Entity", "Recover the artifact", "Time dilation", "Rival faction interference", "A cult seeks the Heart of the Void in an infinite maze."}
        };

        // --- Terminus Volarus ---
        region_quests_["Terminus Volarus"] = {
            {"The Ascension Key", "Terminus Volarus", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Psychic resonance", "Rival faction interference", "Factions race for the key to the moon base."},
            {"Celestial Beacon", "Terminus Volarus", "Sabotage", "Magical Catastrophe", "Destroy the threat", "Elemental surge", "Time limit imposed", "The heavenly city's engines have malfunctioned."},
            {"The Final Threshold", "Terminus Volarus", "Ritual Disruption", "Divine Guardian", "Perform a counter-ritual", "Gravity distortion", "Reality begins to collapse", "Fanatics build a gateway to the divine realms."}
        };

        // --- Forest of SubEden ---
        region_quests_["Forest of SubEden"] = {
            {"The Eden Seed", "Forest of SubEden", "Containment", "Magical Catastrophe", "Stabilize the region", "Elemental surge", "Terrain shifts mid-quest", "A primordial seed spawns hostile forests that spread uncontrollably through SubEden."},
            {"The Greenkeeper's Oath", "Forest of SubEden", "Purification", "Divine Guardian", "Perform a counter-ritual", "Psychic resonance", "Target is not what it seems", "A corrupted guardian spirit has turned SubEden into a living trap for all who enter."},
            {"Fleshbound Roots", "Forest of SubEden", "Ritual Disruption", "Undead Horde", "Destroy the threat", "Memory erasure", "Enemy reinforcements arrive", "Unnatural roots drain life from everything they touch and animate the dead across the forest."}
        };

        // --- The Upper Forty ---
        region_quests_["The Upper Forty"] = {
            {"The Vanishing City Block", "The Upper Forty", "Rescue", "Reality Distortion", "Escort the target safely", "Gravity distortion", "Reality begins to collapse", "An entire city block vanishes into a pocket dimension, trapping all its residents."},
            {"The Time Stasis Incident", "The Upper Forty", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Time dilation", "Time limit imposed", "A time-stopping artifact freezes all life in a two-mile radius and the effect is expanding."},
            {"The Phantom Bureaucrat", "The Upper Forty", "Investigation", "Shadowspawn", "Extract vital intel", "Illusion field", "Enemy reinforcements arrive", "A ghost signs real contracts that cause buildings across the district to structurally collapse."}
        };

        // --- The Lower Forty ---
        region_quests_["The Lower Forty"] = {
            {"Factory of Shadows", "The Lower Forty", "Containment", "Shadowspawn", "Destroy the threat", "Memory erasure", "Rival faction interference", "A factory produces shadow-creatures instead of machinery; workers are being possessed."},
            {"Industrial Revolution Spirit", "The Lower Forty", "Purification", "Divine Guardian", "Perform a counter-ritual", "Elemental surge", "Time limit imposed", "An ancient industrial spirit causes violent machinery malfunctions threatening district-wide fires."},
            {"The Living Gears", "The Lower Forty", "Containment", "Rogue Construct", "Destroy the threat", "Gravity distortion", "Enemy reinforcements arrive", "Magical gears come to life, multiply, and adapt to every attack in an ever-growing swarm."}
        };

        // --- The Pharaoh's Den ---
        region_quests_["The Pharaoh's Den"] = {
            {"The Eternal Pharaoh", "The Pharaoh's Den", "Purification", "Undead Horde", "Perform a counter-ritual", "Memory erasure", "Enemy reinforcements arrive", "An undead pharaoh awakens and summons undead armies to reclaim his long-lost kingdom."},
            {"The Soulwell", "The Pharaoh's Den", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Psychic resonance", "Artifact is cursed", "A well is draining the souls of all nearby creatures to fuel an expanding necrotic force."},
            {"Cursed Obelisks", "The Pharaoh's Den", "Ritual Disruption", "Undead Horde", "Destroy the threat", "Elemental surge", "Terrain shifts mid-quest", "Ancient obelisks scattered across the region emit necrotic energy, reanimating all the dead."}
        };

        // --- The Darkness ---
        region_quests_["The Darkness"] = {
            {"The Lurking Dark", "The Darkness", "Containment", "Void Entity", "Seal the anomaly", "Memory erasure", "Reality begins to collapse", "An ancient malevolent entity devours all light and magic brought into the caverns."},
            {"The Deep Mind", "The Darkness", "Purification", "Void Entity", "Destroy the threat", "Psychic resonance", "Betrayal from within", "A Brain Eater enslaves all creatures through a hive-mind, assembling a thrall army in the dark."},
            {"The Bleeding Stone", "The Darkness", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Elemental surge", "Terrain shifts mid-quest", "A stone seeping blood transforms every nearby creature into a raging uncontrollable berserker."}
        };

        // --- Sacral Separation ---
        region_quests_["Sacral Separation"] = {
            {"The Sandstorm Eternal", "Sacral Separation", "Containment", "Elemental Storm", "Seal the anomaly", "Elemental surge", "Time limit imposed", "A sentient perpetual sandstorm harbors an ancient entity that is desperate to break free."},
            {"The Glass Pyramid", "Sacral Separation", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Illusion field", "Terrain shifts mid-quest", "A mysterious pyramid rises from the sands, guarded by near-indestructible sand golems."},
            {"The Desert of Echoes", "Sacral Separation", "Investigation", "Reality Distortion", "Extract vital intel", "Memory erasure", "Target is not what it seems", "Voices from past and future echo through the sands, driving all who hear them to madness."}
        };

        // --- Infernal Machine ---
        region_quests_["Infernal Machine"] = {
            {"The Fiendish Forge", "Infernal Machine", "Sabotage", "Rogue Construct", "Destroy the threat", "Elemental surge", "Terrain shifts mid-quest", "A sentient forge produces cursed corruption-spreading weapons at an accelerating rate."},
            {"The Devil's Contract", "Infernal Machine", "Ritual Disruption", "Divine Guardian", "Perform a counter-ritual", "Illusion field", "Rival faction interference", "A powerful devil offers contracts to the desperate, building a magically enslaved army."},
            {"The Clockwork Demon", "Infernal Machine", "Ritual Disruption", "Void Entity", "Destroy the threat", "Gravity distortion", "Reality begins to collapse", "A half-machine, half-demonic entity attempts to merge the mechanical and infernal realms."}
        };

        // --- Vulcan Valley ---
        region_quests_["Vulcan Valley"] = {
            {"The Eruption Engine", "Vulcan Valley", "Sabotage", "Magical Catastrophe", "Destroy the threat", "Elemental surge", "Time limit imposed", "A hidden machine deep underground will trigger a catastrophic volcanic eruption imminently."},
            {"The Firelord's Challenge", "Vulcan Valley", "Trial or Challenge", "Divine Guardian", "Survive the trial", "Time dilation", "Enemy reinforcements arrive", "A fire elemental lord traps all who enter his domain inside an inescapable combat time loop."},
            {"The Molten Heart", "Vulcan Valley", "Artifact Recovery", "Sentient Artifact", "Recover the artifact", "Elemental surge", "Rival faction interference", "A molten heart artifact draws Plane of Fire creatures, threatening a permanent material breach."}
        };

        // --- The Mortal Arena ---
        region_quests_["The Mortal Arena"] = {
            {"The Champion's Return", "The Mortal Arena", "Purification", "Undead Horde", "Destroy the threat", "Memory erasure", "Enemy reinforcements arrive", "A long-dead champion returns, growing more powerful with each victory over the living."},
            {"The Blood Oath Games", "The Mortal Arena", "Ritual Disruption", "Cultists", "Perform a counter-ritual", "Psychic resonance", "Betrayal from within", "A new faction enslaves arena fighters through blood oaths, building a magically controlled army."},
            {"The Eternal Tournament", "The Mortal Arena", "Reality Stabilization", "Reality Distortion", "Seal the anomaly", "Time dilation", "Reality begins to collapse", "A time loop traps combatants in endless battle; opponents retain all prior round knowledge."}
        };

        // --- Depths of Denorim ---
        region_quests_["Depths of Denorim"] = {
            {"The Leviathan's Awakening", "Depths of Denorim", "Containment", "Void Entity", "Seal the anomaly", "Memory erasure", "Reality begins to collapse", "A massive leviathan stirs in the depths, its movements threatening tsunamis and seaquakes."},
            {"The Abyssal Echo", "Depths of Denorim", "Investigation", "Reality Distortion", "Extract vital intel", "Psychic resonance", "Target is not what it seems", "Hypnotic sounds from the abyss lure sailors to death and drive all who hear them to madness."},
            {"Sunken City of Marrowdeep", "Depths of Denorim", "Purification", "Undead Horde", "Destroy the threat", "Elemental surge", "Rival faction interference", "A cursed lost city resurfaces from the deep, spreading an internal drowning curse to all who approach."}
        };

        // --- Moroboros ---
        region_quests_["Moroboros"] = {
            {"The Shifting Island", "Moroboros", "Reality Stabilization", "Sentient Artifact", "Stabilize the region", "Gravity distortion", "Terrain shifts mid-quest", "The Island of the Weir teleports randomly across seas, warping space and time wherever it lands."},
            {"The Clockwork Beast", "Moroboros", "Containment", "Rogue Construct", "Destroy the threat", "Time dilation", "Enemy reinforcements arrive", "A highly intelligent mechanical creature builds copies of itself, adapting to counter every attack."},
            {"The Hall of Mirrors", "Moroboros", "Rescue", "Reality Distortion", "Escort the target safely", "Illusion field", "Reality begins to collapse", "An ancient mirror structure traps souls and replaces living people with malevolent twisted reflections."}
        };

        // --- The Corrupted Marshes ---
        region_quests_["The Corrupted Marshes"] = {
            {"The Lich's Curse", "The Corrupted Marshes", "Purification", "Undead Horde", "Perform a counter-ritual", "Memory erasure", "Rival faction interference", "A lich's curse causes the marshes to fester and decay; the phylactery must be found and destroyed."},
            {"The Blighted Fauna", "The Corrupted Marshes", "Containment", "Corrupted Fauna", "Stabilize the region", "Elemental surge", "Terrain shifts mid-quest", "Corrupted beasts attack indiscriminately; an alpha creature threatens to spread the blight further."},
            {"The Bog of Despair", "The Corrupted Marshes", "Investigation", "Void Entity", "Extract vital intel", "Psychic resonance", "Target is not what it seems", "A deep bog emits despair waves that lure travelers in and drain all will to live."}
        };

        // --- Spindle York's Schism ---
        region_quests_["Spindle York's Schism"] = {
            {"The Forgotten Prisoners", "Spindle York's Schism", "Investigation", "Void Entity", "Extract vital intel", "Gravity distortion", "Reality begins to collapse", "An ancient prison uncovered beneath Spindle York holds sealed entities of terrifying and unknown power."},
            {"The Echoing Tunnels", "Spindle York's Schism", "Containment", "Reality Distortion", "Seal the anomaly", "Memory erasure", "Enemy reinforcements arrive", "Tunnel echoes resurrect creatures and threats from history, pulling them fully into the present."},
            {"The Rift Between", "Spindle York's Schism", "Reality Stabilization", "Dimensional tear", "Seal the anomaly", "Gravity distortion", "Reality begins to collapse", "A dimensional rift floods the schism with invaders that operate by completely alien physics."}
        };

        // --- Crypt at the End of the Valley ---
        region_quests_["Crypt at the End of the Valley"] = {
            {"The Restless Dead", "Crypt at the End of the Valley", "Purification", "Undead Horde", "Destroy the threat", "Memory erasure", "Enemy reinforcements arrive", "A massive graveyard stirs as the dead rise unpredictably in ever-increasing numbers."},
            {"The Tomb of the First King", "Crypt at the End of the Valley", "Ritual Disruption", "Divine Guardian", "Perform a counter-ritual", "Psychic resonance", "Reality begins to collapse", "The first king's tomb glows with unnatural light as an ancient and terrible resurrection begins."},
            {"The Weeping Stones", "Crypt at the End of the Valley", "Investigation", "Reality Distortion", "Extract vital intel", "Illusion field", "Target is not what it seems", "Grave markers weep blood, causing dangerous hallucinations of ancient slaughters in all who see them."}
        };

        // --- Gloamfen Hollow ---
        region_quests_["Gloamfen Hollow"] = {
            {"The Heart That Will Not Die", "Gloamfen Hollow", "Ritual Disruption", "Magical Catastrophe", "Destroy the threat", "Elemental surge", "Terrain shifts mid-quest", "Violent pulses from a dead leviathan's heart rupture bile canals and mutate all surrounding creatures."},
            {"The Bile-Mother's Tongue", "Gloamfen Hollow", "Containment", "Void Entity", "Seal the anomaly", "Psychic resonance", "Betrayal from within", "A semi-sentient rot whispers promises in the fields, luring Gutborn villagers deep into the leviathan corpse."},
            {"The Hollow That Remembers", "Gloamfen Hollow", "Purification", "Reality Distortion", "Perform a counter-ritual", "Memory erasure", "Enemy reinforcements arrive", "Memory-entities from an ancient bone-crypt seek living hosts to completely overwrite their identities."}
        };

        // --- L.I.T.O. ---
        region_quests_["L.I.T.O."] = {
            {"The Reality Mirror", "L.I.T.O.", "Containment", "Reality Distortion", "Seal the anomaly", "Illusion field", "Reality begins to collapse", "A mirror manifests gazers' deepest fears as physical creatures that grow more dangerous over time."},
            {"The Dreamwalker", "L.I.T.O.", "Purification", "Void Entity", "Destroy the threat", "Psychic resonance", "Betrayal from within", "A powerful entity invades minds throughout the region, turning every dream into a lethal physical threat."},
            {"The Thought Parasite", "L.I.T.O.", "Investigation", "Void Entity", "Extract vital intel", "Memory erasure", "Target is not what it seems", "A parasitic creature feeds on thoughts and emotions; victims slowly lose all sense of self."}
        };

        // --- West End Gullet ---
        region_quests_["West End Gullet"] = {
            {"The Faceless Menace", "West End Gullet", "Investigation", "Magical Catastrophe", "Extract vital intel", "Psychic resonance", "Enemy reinforcements arrive", "A plague replaces people's faces with blank skin; the faceless become hostile and near-unkillable."},
            {"The Wrong-Turned City", "West End Gullet", "Reality Stabilization", "Reality Distortion", "Stabilize the region", "Gravity distortion", "Terrain shifts mid-quest", "The city layout shifts into endless looping streets; navigation becomes completely impossible."},
            {"The Dollmaker's Revenge", "West End Gullet", "Purification", "Shadowspawn", "Destroy the threat", "Illusion field", "Target is not what it seems", "A vengeful spirit animates toy dolls that perfectly mimic the living and gradually replace them."}
        };
    }

    std::map<std::string, std::vector<GeneratedQuest>> region_quests_;
};

class QuestGenerator {
public:
    static GeneratedQuest generate_random_quest(Dice& dice) {
        GeneratedQuest quest;
        quest.title = "Generated Foundation Contract";

        std::vector<std::string> regions = {
            "The Plains", "The Metropolitan", "The Shadows Beneath", "Peaks of Isolation",
            "The Glass Passage", "Titan’s Lament", "The Isles", "Astral Tear",
            "Terminus Volarus", "Sublimini Dominus"
        };
        quest.region = regions[dice.roll(10) - 1];

        std::vector<std::string> types = {
            "Containment", "Investigation", "Rescue", "Purification",
            "Artifact Recovery", "Ritual Disruption", "Escort", "Hunt",
            "Diplomacy", "Sabotage", "Reality Stabilization", "Trial or Challenge"
        };
        quest.type = types[dice.roll(12) - 1];

        std::vector<std::string> threats = {
            "Undead Horde", "Elemental Storm", "Rogue Construct", "Cultists",
            "Reality Distortion", "Void Entity", "Corrupted Fauna", "Sentient Artifact",
            "Dimensional tear", "Divine Guardian", "Shadowspawn", "Magical Catastrophe"
        };
        quest.threat = threats[dice.roll(12) - 1];

        std::vector<std::string> objectives = {
            "Seal the anomaly", "Recover the artifact", "Escort the target safely",
            "Survive the trial", "Destroy the threat", "Stabilize the region",
            "Perform a counter-ritual", "Extract vital intel"
        };
        quest.objective = objectives[dice.roll(8) - 1];

        std::vector<std::string> anomalies = {
            "Gravity distortion", "Time dilation", "Memory erasure",
            "Elemental surge", "Illusion field", "Psychic resonance"
        };
        quest.anomaly = anomalies[dice.roll(6) - 1];

        std::vector<std::string> complications = {
            "Rival faction interference", "Betrayal from within", "Artifact is cursed",
            "Terrain shifts mid-quest", "Time limit imposed", "Target is not what it seems",
            "Enemy reinforcements arrive", "Reality begins to collapse"
        };
        quest.complication = complications[dice.roll(8) - 1];

        quest.description = "The Foundation requires urgent assistance with a " + quest.type + " mission involving a " + quest.threat + ".";

        return quest;
    }
};

} // namespace rimvale

#endif // RIMVALE_QUEST_H
