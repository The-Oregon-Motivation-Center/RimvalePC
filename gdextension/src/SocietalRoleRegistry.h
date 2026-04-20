#ifndef RIMVALE_SOCIETAL_ROLE_REGISTRY_H
#define RIMVALE_SOCIETAL_ROLE_REGISTRY_H

#include <string>
#include <vector>
#include <map>

namespace rimvale {

struct SocietalRole {
    std::string name;
    std::string description;
    std::string primary_benefit;
    std::string secondary_benefit;
};

class SocietalRoleRegistry {
public:
    static SocietalRoleRegistry& instance() {
        static SocietalRoleRegistry registry;
        return registry;
    }

    [[nodiscard]] const std::vector<SocietalRole>& get_all_roles() const {
        return all_roles_;
    }

    [[nodiscard]] const SocietalRole* get_role(const std::string& name) const {
        for (const auto& role : all_roles_) {
            if (role.name == name) return &role;
        }
        return nullptr;
    }

private:
    SocietalRoleRegistry() {
        all_roles_ = {
            {"Archivist", "Keepers of ancient knowledge.", "+1d4 to Arcane and History related checks.", "Once per long rest, recall obscure magical lore without a check."},
            {"Artificer", "Engineers of arcane technology.", "+1d4 to Crafting and Tinkering checks.", "Repair a damaged item, weapon or armor once per short rest."},
            {"Ashkeeper", "Firewalkers and flame-priests.", "+1d4 to Fire Magic and Religion related checks.", "Once per long rest, you may walk through fire or lava without taking damage for 1 minute."},
            {"Baker", "Nourishing both body and spirit.", "+1d4 to Baking and Chemistry checks.", "Once per short rest, bake goods that restore 1d4 + Intellect HP to an ally."},
            {"Beastmaster", "Taming the wild.", "+1d4 to Creature Handling and Survival checks.", "Once per long rest, calm and command a beast for 1 minute."},
            {"Blightmender", "Healers of corruption.", "+1d4 to Medicine and Corruption/disease checks.", "Once per long rest, cleanse a creature of a minor disease or magical ailment."},
            {"Bloodscribe", "Ritualists of blood magic.", "+1d4 to Ritual and Divinity checks.", "Blood rite: regain HP equal to half spell damage dealt for 1 minute (1/LR)."},
            {"Bloodstitcher", "Menders of deep injuries.", "+1d4 to Medicine and Vitality checks.", "Stop a fatal wound from causing death for 1 hour (1/LR)."},
            {"Bonepicker", "Scavengers of battlefields.", "+1d4 to Scavenging and Medical checks.", "Harvest a useful component from a corpse (1/LR)."},
            {"Brewer", "Creators of comfort.", "+1d4 to brewing and Chemistry checks.", "Craft a drink that removes one minor condition (1/LR)."},
            {"Butcher", "Processors of meat.", "+1d4 to Butchery and Anatomy checks.", "Cooking yields double the normal amount of food (1/LR)."},
            {"Cartwright", "Builders of vehicles.", "+1d4 to Crafting and Repair checks for vehicles.", "Repair a damaged vehicle (1/LR)."},
            {"Cavemistress", "Rulers of the underground.", "+1d4 to Stealth and Survival checks in underground environments.", "Summon a danger 0 companion from the Shadows Beneath (1/LR)."},
            {"Cavernborn", "Adapted to darkness and stone.", "+1d4 to Mining and Stealth checks underground.", "Ignore darkness penalties for 1 hour (1/LR)."},
            {"Chronicler", "Recorders of deeds.", "+1d4 to History and Speechcraft checks.", "Recall a forgotten or obscure piece of relevant lore (1/LR)."},
            {"Contract Arbiter", "Resolvers of disputes.", "+1d4 to Persuasion and Intimidation as a neutral party.", "Create a magical oath binding two willing creatures for 24 hours (1/LR)."},
            {"Cook", "Preparers of meals.", "+1d4 to Cooking and Survival checks involving food.", "Prepare a meal that grants allies bonus HP equal to your level (1/LR)."},
            {"Court Mage", "Arcane advisors to nobility.", "+1d4 to Arcane and Speechcraft checks in formal settings.", "Cast a minor spell (4 SP or less) without SP cost (1/LR)."},
            {"Cryptkeeper", "Caretakers of tombs.", "+1d4 to Religion and Undead Lore checks.", "Turn away a minor undead creature for 1 minute (1/LR)."},
            {"Diplomat", "Negotiators and peacekeepers.", "+1d4 to Speechcraft and Insight checks in social encounters.", "Calm hostile creatures within 30 ft for 1 round (1/LR)."},
            {"Engineer", "Builders of infrastructure.", "+1d4 to Tinkering and Structural Analysis related checks.", "Reinforce a structure or disable a trap with advantage (1/SR)."},
            {"Feybound", "Pact-makers with the fey.", "+1d4 to Deception and Nature related checks.", "Cast a minor illusion or charm (4 SP or less) for 0 SP (1/LR)."},
            {"Firebrand", "Rebels and chaos-sowers.", "+1d4 to Intimidation and Chaos-aligned spellcasting checks.", "Cause a fire-based distraction/explosion for group advantage (1/SR)."},
            {"Fisher", "Providers from the waters.", "+1d4 to Fishing and Water Navigation checks.", "Automatically succeed on a minor fishing check (1/SR)."},
            {"Fleshshaper", "Biomancers of tissue.", "+1d4 to Biological Magic and Medical checks.", "Regrow a lost limb or organ over 1 hour (1/LR)."},
            {"Forgehand", "Metalworkers and smiths.", "+1d4 to Smithing and Crafting checks.", "Reinforce gear for +2 dmg/AC for 1 hr and repair half HP (1/LR)."},
            {"Fungal Tender", "Caretakers of mycelial groves.", "+1d4 to Nature and Medical checks involving fungi.", "Create a spore cloud for advantage on sneak checks for 1 round (1/SR)."},
            {"Gardener", "Cultivators of plants.", "+1d4 to Botany and Nature related checks.", "Revive wilted plants or accelerate growth in 5ft cube (1/LR)."},
            {"Gladiator", "Champions of the arena.", "+1d4 to Performance and Melee Attack rolls in front of an audience.", "Cause daze for 2 rounds, DC 10 + Vitality (1/SR)."},
            {"Glimmerchant", "Traders of magical curiosities.", "+1d4 to Appraisal and Speechcraft checks.", "Identify a magical item's function/curse without a check (1/LR)."},
            {"Gravetender", "Caretakers of the dead.", "+1d4 to Religion and Medical checks involving the dead.", "Speak with a spirit or ghost of a corpse for 1 minute (1/LR)."},
            {"Grimscribe", "Chroniclers of death.", "+1d4 to History and Necromancy checks.", "Identify a curse or necromantic effect (1/LR)."},
            {"Gutterborn", "Resourceful city-dwellers.", "+1d4 to Sneak and Streetwise related checks.", "Escape a grapple or restraint automatically (1/LR)."},
            {"Guildmaster", "Influential traders.", "+1d4 to Commerce and Appraisal checks.", "Secure a 20% trade discount or rare market info (1/LR)."},
            {"Healer", "Tenders of the sick.", "+1d4 to Medical and Vitality checks.", "Stabilize a dying creature as a Free Action (1/LR)."},
            {"Hearthwarden", "Protectors of homes.", "+1d4 to Defense and Perception checks around dwellings.", "Set a trap or alarm that alerts you to intruders (1/LR)."},
            {"Hollowblade", "Warriors of the void.", "+1d4 to Melee attacks and spell saves.", "Nullify a spell targeting you (1/LR)."},
            {"Hollowveil Courier", "Silent runners.", "+1d4 to Stealth and Endurance checks.", "Move at double speed for 1 round without provoking (1/SR)."},
            {"Horizon Seeker", "Explorers of the unknown.", "+1d4 to Navigation and Cartography checks.", "Find a shortcut or hidden path (1/LR)."},
            {"Inquisitor", "Seekers of truth.", "+1d4 to Insight and Investigation related checks.", "Detect lies or illusions with advantage (1/SR)."},
            {"Ironmonger", "Metal tool forgers.", "+1d4 to Smithing and Appraisal checks.", "Repair a metal item without tools or restore half HP (1/LR)."},
            {"Ironshaper", "Artistic metal forgers.", "+1d4 to Crafting and Strength checks when working with metal.", "Create a weapon or armor that lasts for a day (1/LR)."},
            {"Leyrunner", "Arcane messengers.", "+1d4 to Arcane and Navigation checks.", "Teleport up to 30 ft as a Free Action (1/LR)."},
            {"Lorekeeper", "Historians of the past.", "+1d4 to History and Arcane checks.", "Identify a magical item's function without a check (1/LR)."},
            {"Mason", "Builders of stone.", "+1d4 to Masonry and Engineering checks.", "Reinforce or weaken a stone structure for 1 hour (1/LR)."},
            {"Mercenary", "Hired battle veterans.", "+1d4 to Weapon Attack rolls when outnumbered.", "Identify military tactics or formations with advantage."},
            {"Miner", "Extractors of resources.", "+1d4 to Mining and Geology checks.", "Identify a mineral or safely extract resources (1/LR)."},
            {"Mistwarden", "Protectors of foggy coasts.", "+1d4 to Stealth and Perception checks in fog/dim light.", "Create a zone of muffled sound and mist for 1 minute (1/LR)."},
            {"Relic Hunter", "Seekers of lost artifacts.", "+1d4 to Investigation and Trap Detection checks.", "Identify magical properties without a check (1/LR)."},
            {"Riverrunner", "Expert boatmen.", "+1d4 to Swimming and Boating checks.", "Automatically succeed on a check to cross hazardous water (1/LR)."},
            {"Runebinder", "Arcane tacticians.", "+1d4 to Spellcasting checks.", "Delay a spell’s activation by 1 round as a reaction (1/LR)."},
            {"Runebreaker", "Disrupters of magic.", "+1d4 to Arcane and Cunning checks involving magical traps.", "Nullify a magical effect instantly for 1 round (1/LR)."},
            {"Runescribe", "Inscribers of power.", "+1d4 to Arcane and Calligraphy-related checks.", "Inscribe a temporary rune for +1 to a saving throw (1/SR)."},
            {"Runeseeker", "Followers of divine echoes.", "+1d4 to Arcane and Survival checks in magical areas.", "Detect a magical anomaly and reduce next spell cost by 2 SP (1/LR)."},
            {"Saboteur", "Experts in disruption.", "+1d4 to Cunning and Trap Disarming checks.", "Disable a mechanical or magical device instantly (1/LR)."},
            {"Scout", "Light-footed observers.", "+1d4 to Perception and Stealth related checks.", "Move at full speed while sneaking without penalty."},
            {"Scrapwright", "Salvagers of junk.", "+1d4 to Tinkering and Improvised Crafting checks.", "Create a one-use gadget (1/LR)."},
            {"Seedkeeper", "Cultivators of rare plants.", "+1d4 to Nature and Medicine checks involving plants.", "Revive or accelerate growth of a plant overnight (1/LR)."},
            {"Seer", "Visionaries of fate.", "+1d4 to Divination and Insight checks.", "Ask a yes/no question and receive a cryptic answer (1/LR)."},
            {"Shadowbroker", "Dealers in secrets.", "+1d4 to Cunning and Speechcraft checks involving secrets.", "Gather local rumors in half the usual time."},
            {"Shadowdancer", "Manipulators of light and dark.", "+1d4 to Stealth and Nimble checks in dim light.", "Blend with shadows to become invisible for 1 minute (1/LR)."},
            {"Skyforged", "Engineers of floating cities.", "+1d4 to Engineering and Arcane checks involving flight.", "Negate fall damage from any height (1/LR)."},
            {"Skywatcher", "Weather sages.", "+1d4 to Weather Prediction and Navigation checks.", "Glide 30 ft once without taking fall damage (1/LR)."},
            {"Smuggler", "Masters of misdirection.", "+1d4 to Stealth and Deception related checks.", "Hide a small object on your person without a check."},
            {"Soulbinder", "Pact-makers with spirits.", "+1d4 to Divinity and Insight checks.", "Spectral sigil: advantage on Insight/Divinity vs target (1/LR)."},
            {"Speaker", "Community leaders.", "+1d4 to Speechcraft and History related checks.", "Inspire allies to reroll a failed saving throw (1/SR)."},
            {"Spellslinger", "Battle-trained mages.", "+1d4 to Spell Attack rolls.", "Reroll a failed spell attack (1/SR)."},
            {"Spellwright", "Arcane scribes.", "+1d4 to Arcane and Calligraphy checks.", "Reduce the SP cost of a spell by 1 (1/SR)."},
            {"Stablehand", "Caretakers of mounts.", "+1d4 to Animal Care and Cleaning checks.", "Calm a frightened mount or beast of burden (1/LR)."},
            {"Starborn Envoy", "Planar diplomats.", "+1d4 to Speechcraft and Arcane checks with extraplanar beings.", "Cast a minor light or telepathy spell for 0 SP (1/LR)."},
            {"Starweaver", "Cosmic mages.", "+1d4 to Arcane and Navigation checks under open sky.", "Reroll a failed Arcane check (1/LR)."},
            {"Stonehand", "Physical laborers.", "+1d4 to Athletics and Endurance checks.", "Complete strenuous task in half time or ignore fatigue for 1 hr (1/LR)."},
            {"Stormrunner", "Couriers of the wilds.", "+1d4 to Speed and Navigation related checks.", "Ignore terrain penalties for 1 hour (1/LR)."},
            {"Stormsinger", "Callers of the storm.", "+1d4 to Conjuring and Thunder-related checks.", "Create a lightning storm in a 20-foot radius for 1 minute (1/LR)."},
            {"Street Performer", "Artistic entertainers.", "+1d4 to Performance and Crowd Control checks.", "Attract a distracting/aiding crowd (1/LR)."},
            {"Sunforged", "Warriors of solar rites.", "+1d4 to Fire Resistance and Smithing checks.", "Emit bright light in a 20 ft radius for 1 minute (1/LR)."},
            {"Tailor", "Menders of clothing.", "+1d4 to crafting and Appraisal checks for clothing.", "Altered clothing grants ally advantage on one social check (1/LR)."},
            {"Tavernkeeper", "Masters of hospitality.", "+1d4 to Speechcraft and Insight checks.", "Grant an ally advantage on a social check (1/LR)."},
            {"Technician", "Masters of arcane circuitry.", "+1d4 to Tinkering and Engineering checks.", "Instantly repair or disable a device without a check (1/SR)."},
            {"Tidebound Navigator", "Seafarers.", "+1d4 to Navigation and Weather Prediction checks.", "Reroll a failed Navigation check (1/LR)."},
            {"Tideforged", "Laborers of the sea.", "+1d4 to Crafting and Survival checks near water.", "Craft a simple tool/weapon from found materials (1/LR)."},
            {"Tidewalker", "Guides of the isles.", "+1d4 to Swim and Navigation checks.", "Hold breath twice as long and ignore underwater difficult terrain."},
            {"Veilforged", "Resilient shadow-shapers.", "+1d4 to Arcane and spell save checks against illusions.", "Pulse of void energy to suppress magical effects (1/LR)."},
            {"Veilweaver", "Walkers between worlds.", "+1d4 to Arcana and Stealth checks involving ethereal.", "Pass through solid walls up to 10 ft thick (3/LR)."},
            {"Voidwatcher", "Planar scouts.", "+1d4 to Insight and Arcane checks involving planar phenomena.", "See into the Ethereal Plane for 1 minute (1/LR)."},
            {"Wanderer", "Nomads of the wilds.", "+1d4 to Survival and Navigation in unfamiliar terrain.", "Always find food and water for yourself and one other."},
            {"Wandering Duelist", "Mercenary drifters.", "+1d4 to Weapon Attack rolls in duels and nimble checks.", "Anticipate move: advantage on attacks for a round (1/LR)."},
            {"Warden", "Guardians of the wilds.", "+1d4 to Survival and Tracking in natural environments.", "Detect nearby threats (beasts or humanoids) within 60 ft (1/LR)."},
            {"Windswept", "Nomads of the highlands.", "+1d4 to Survival and Initiative checks.", "Take a move action without spending AP (1/SR)."},
            {"Witchbinder", "Tethered to forbidden magic.", "+1d4 to Arcane and Intellect checks for forbidden magic.", "Bind an enemy’s spell, rendering it useless for 1 minute (1/LR)."},
            {"Witchfinder", "Hunters of rogue mages.", "+1d4 to Arcane and Divinity checks identifying curses.", "Sense the presence of magic within 30 ft for 1 minute (1/LR)."}
        };
    }

    std::vector<SocietalRole> all_roles_;
};

} // namespace rimvale

#endif // RIMVALE_SOCIETAL_ROLE_REGISTRY_H
