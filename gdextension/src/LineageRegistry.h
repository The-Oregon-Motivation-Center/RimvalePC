#ifndef RIMVALE_LINEAGE_REGISTRY_H
#define RIMVALE_LINEAGE_REGISTRY_H

#include "Character.h"
#include <map>
#include <string>
#include <vector>

namespace rimvale {

class LineageRegistry {
public:
    static LineageRegistry& instance() {
        static LineageRegistry registry;
        return registry;
    }

    [[nodiscard]] const rimvale::Lineage* get_lineage(const std::string& name) const {
        auto it = lineages_.find(name);
        return (it != lineages_.end()) ? &it->second : nullptr;
    }

    [[nodiscard]] std::vector<std::string> get_all_names() const {
        std::vector<std::string> names;
        names.reserve(lineages_.size());
        for (const auto& pair : lineages_) {
            names.push_back(pair.first);
        }
        return names;
    }

private:
    LineageRegistry() {
        // --- The Plains ---
        register_lineage({"Bouncian", "Humanoid (Beast)", 25,
            {"Keen Hearing: Advantage on sound-based Perception and detect invisible within 10ft.",
             "Bounding Escape: Reduce fall damage by Speed x 5. Leap 15ft as a Reaction to avoid attacks (1/SR)."},
            {"Babel", "Burrowtongue"},
            "Small, quick-witted humanoids with long ears and soft fur, known for their agility and keen senses.",
            "Bouncians are a lively and communal people whose culture centers on agility, quick thinking, and a deep appreciation for the cycles of nature, often celebrating with vibrant festivals and games that showcase their speed and wit. In daily life, they gather in close-knit burrows, sharing stories and resources, and tending to their verdant surroundings with a spirit of cooperation and mutual care."});

        register_lineage({"Goldscale", "Humanoid (Reptile)", 20,
            {"Scaled Hide: Base AC 13. Glow when taking fire damage: +1d4 fire to attacks and attackers take 1d4 (DC 10+DIV or drop weapon).",
             "Sun's Favor: Fire resistance. Radiant burst (10ft radius, DC 10+VIT or Blinded, 3 AP)."},
            {"Babel", "Draconic"},
            "Goldscales are reptilian humanoids with gleaming golden scales and slit-pupiled eyes.",
            "Goldscales are renowned for their disciplined, tradition-bound society that values honor, wisdom, and the pursuit of excellence, often gathering in structured communities where leadership and achievement are celebrated. In daily life, they engage in ritualized social gatherings, uphold strict codes of conduct, and take pride in mentoring the young, ensuring that each generation embodies the legacy and dignity of their lineage"});

        register_lineage({"Ironhide", "Humanoid (Construct)", 20,
            {"Armored Plating: Base AC 13. Activate for +2 AC for 1 min, but move actions cost +1 AP (1/LR).",
             "Mechanical Mind: Advantage vs charm. Auto-succeed on an Intellect check to recall info (1/SR)."},
            {"Babel", "Mechan"},
            "Ironhides are construct-like humanoids with metallic skin, jointed limbs, and glowing eyes, built for durability and mental fortitude.",
            "Ironhides are a proud and stoic people whose culture values endurance, craftsmanship, and the preservation of tradition, often gathering in communities where artistry and resilience are celebrated. In daily life, they maintain their ornate forms with meticulous care, uphold communal rituals of repair and remembrance, and support one another through acts of service and shared labor"});

        register_lineage({"Verdant", "Humanoid (Plant)", 20,
            {"Regrowth: Regain level + VIT HP as an action (1/SR).",
             "Nature's Voice: Speak with plants. Bond with a plant for 10 min to share senses within 60ft (1/LR)."},
            {"Babel", "Sylvan"},
            "Verdants are plantfolk with vibrant green skin, leafy hair, and flowers blooming from their bodies, embodying the vitality of nature.",
            "Verdants embody the vitality and resilience of nature, with a culture rooted in harmony, growth, and the celebration of life's interconnectedness, often marked by rituals that honor the changing seasons and the flourishing of plant life. Day to day, they nurture their leafy communities, tending gardens and supporting one another, their lives intertwined with the rhythms of the land and the blossoming of new life."});

        register_lineage({"Vulpin", "Humanoid (Beast)", 20,
            {"Illusory Echo: Create illusory double for 1 min, giving advantage on all checks (1/LR).",
             "Trickster's Dodge: Impose disadvantage on an attack against you or ally within 10ft (1 SP, Reaction)."},
            {"Babel", "Vulpine"},
            "Foxfolk. Clever, red-furred humanoids with bushy tails and quick reflexes.",
            "Vulpin culture is centered on cunning, adaptability, and the value of community bonds, with traditions that celebrate cleverness, storytelling, and the art of outwitting both friend and foe. In daily life, they engage in lively social gatherings, share tales of trickery and adventure, and rely on their quick reflexes and wit to navigate the challenges of the plains"});

        // --- The Forest of SubEden ---
        register_lineage({"Bramblekin", "Humanoid (Plant)", 20,
            {"Thorny Hide: Deal 1d4 piercing when hit by or hitting with melee attack.",
             "Photosynthesis: No food/water needed with 1hr sunlight. Produce 1 ration for ally (1 SP)."},
            {"Babel", "Sylvan"},
            "Bramblekin are plantfolk with bark-like skin, leafy hair, and thorny protrusions, blending seamlessly into forested environments.",
            "Bramblekin culture is deeply rooted in the cycles of the forest, valuing harmony with nature, resilience, and the wisdom of the wild, often gathering for rituals that honor the spirits of the woods and the changing seasons. In daily life, they tend to their groves, share knowledge of herbal lore, and support their community through acts of stewardship and mutual protection"});

        register_lineage({"Elf", "Humanoid", 20,
            {"Innate Magic: +1 SP per level. Life extension ritual (10 years per SP, permanent insanity risks).",
             "Keen Senses: +1d4 to Perception. Add Perception score to initiative rolls."},
            {"Babel", "Elvish"},
            "Elves are slender, graceful, and long-lived, with pointed ears and sharp features, often possessing an ethereal beauty and a deep connection to nature and magic.",
            "Elven culture is steeped in tradition and a profound reverence for magic, art, and the natural world, with communities that value wisdom, beauty, and the pursuit of knowledge. In daily life, elves engage in artistic expression, magical study, and communal rituals that strengthen their bonds with each other and the land they cherish"});

        register_lineage({"Fae-Touched Human", "Humanoid (Fey)", 20,
            {"Fey Step: Teleport instead of moving (Double AP cost).",
             "Enchanting Presence: Advantage vs fey. Shimmer for 1 min to gain +1d4 to Speechcraft (1/SR)."},
            {"Babel", "Sylvan"},
            "Fae-Touched Humans possess slender builds, pointed ears, and skin that glimmers with subtle, otherworldly hues, giving them an ethereal and enchanting presence.",
            "Fae-Touched Human culture is deeply influenced by their fey heritage, valuing beauty, whimsy, and a close connection to the magical forces of nature, often celebrating with enchanted feasts and rituals that honor the mystical world. In daily life, they enjoy nectar, honeyed petals, and enchanted fruits, gather for dreamroot tea, and embrace traditions that foster creativity, charm, and a sense of wonder in their communities"});

        register_lineage({"Felinar", "Humanoid (Beast)", 20,
            {"Cat's Balance: Advantage on Speed, Nimble, and Cunning checks.",
             "Nine Lives: Drop to 9 HP instead of 0 (9/LR)."},
            {"Babel", "Felin"},
            "Felinar are graceful, feline humanoids renowned for their sharp senses and nimble bodies.",
            "Felinar culture values independence, curiosity, and adaptability, with a strong emphasis on personal freedom and the pursuit of individual passions. In daily life, they form loose-knit communities where members support each other’s endeavors, share stories of exploration, and hone their skills through playful competition and mutual respect."});

        register_lineage({"Myconid", "Humanoid (Fungus)", 20,
            {"Spore Cloud: 10ft radius poison cloud (DC 10+VIT or Poisoned 1 min, 1/LR).",
             "Fungal Fortitude: Poison resistance. Heal 2d6 (4d6 if poisoned) as an action (1/SR)."},
            {"Babel", "Sporetalk"},
            "Myconids are fungus-based humanoids whose lives revolve around communal harmony and a deep connection to the cycles of decay and renewal in nature.",
            "Myconid culture is centered on communal harmony, patience, and a deep connection to the cycles of decay and renewal in nature. They live in close-knit colonies, sharing thoughts and emotions through spores, and value collective well-being over individual ambition. Rituals often involve tending to the growth and decomposition of organic matter, reflecting their reverence for the balance of life and death."});

        // --- Kingdom of Qunorum ---
        register_lineage({"Grimshell", "Construct", 20,
            {"Tomb Core: Count first failed death save as success.",
             "Heavy Frame: Reaction to reduce melee damage by 1d4+STR and push attacker 5ft (1 AP + Reaction)."},
            {"Babel", "Mechan"},
            "Enshrouded in rust and sorrow, Grimshells are armored shells that once held noble knights-but now only echo with the memories of fallen honor.",
            "Grimshell culture is defined by perseverance and remembrance. They honor the struggles of the past and find strength in shared adversity, often gathering to recount tales of survival and to support one another through difficult times. Their communities are close-knit, bound by mutual respect and the collective memory of loss and endurance."});

        register_lineage({"Hearthkin", "Construct (Fire/Spiritual)", 20,
            {"Kindle Flame: Ignite magical fire (20ft radius) giving allies +1d4 AP to Rest actions (1/LR, 1hr).",
             "Warm Core: Fire resistance. Allies within 5ft immune to extreme cold."},
            {"Babel", "Ignan"},
            "Hearthkin are humanoids animated from hearthstones or firepits, often found in ancient ruins or sacred groves. They are warm, protective, and deeply communal. ",
            "Hearthkin culture centers on protection, hospitality, and the maintenance of communal bonds. They gather in close-knit groups, tending sacred fires, sharing stories, and offering shelter to travelers. Their traditions emphasize the importance of warmth-both literal and emotional-and the value of safeguarding their homes and communities."});

        register_lineage({"Kindlekin", "Humanoid (Plant)", 20,
            {"Alchemical Affinity: Reduce Chemical spell cost by 4 SP (min 0, 1/Rest).",
             "Combustive Touch: Release explosion when hit (1d4 + 1d4 per subsequent hit). Resets on rest."},
            {"Babel", "Sylvan"},
            "Kindlekin are living embodiments of combustion and transformation, their forms a mesmerizing dance of flickering embers and shifting, tangled shapes.",
            "Kindlekin culture is shaped by the duality of creation and destruction. Favored by alchemists, engineers, and elementalists, they are often sought after for their ability to manipulate reactions, transmute materials, and harness the power of combustion. Yet, this gift is a double-edged sword: Kindlekin are seen as both invaluable and dangerous, their presence in a community a source of both innovation and anxiety. Their society is marked by caution and ritual, with documentation governing the use of their volatile abilities. Their gatherings are somber affairs, filled with stories of both triumph and tragedy, and a deep respect for the forces they embody."});

        register_lineage({"Regal Human", "Humanoid", 20,
            {"Versatile: +1d4 to all skill checks. Can grant this to allies DIV times (Free Action, 1/LR).",
             "Resilient Spirit: Reroll failed saving throw (2/SR)."},
            {"Babel", "Choice (+5 languages)"},
            "Resourceful and diverse, Regal humans are adaptable beings with a wide range of appearances, typically standing between 4 and 7 feet tall, with skin, hair, and eye colors varying greatly.",
            "Regal Human culture emphasizes versatility, governance, and the ability to thrive in a variety of environments. They are often found in positions of leadership or influence, and their societies value tradition, diplomacy, and the pursuit of excellence."});

        register_lineage({"Quillari", "Humanoid", 25,
            {"Quill Defense: Grappler takes 1d6 piercing. Launch yourself in 30ft line dealing 2d6 damage (DC 10+SPD save, 1/LR).",
             "Quick Reflexes: 2x Speed on initiative. Extra Move or Free action before combat (1/SR)."},
            {"Babel", "Prickletongue"},
            "Quillari are small, spiky humanoids with quills covering their backs and arms, quick to react to danger.",
            "Quillari culture values vigilance, adaptability, and community support. They are known for their swift responses to threats and their tendency to look out for one another, often forming tight-knit groups that prioritize mutual protection and resourcefulness."});

        // --- The Wilds of Endero ---
        register_lineage({"Beetlefolk", "Humanoid (Insect)", 20,
            {"Carapace: Base AC 13. Reaction to reduce melee damage by 1d6+VIT (VIT times/SR).",
             "Burrow: Burrow 10ft/round. Tremorsense 15ft while underground."},
            {"Babel", "Terran"},
            "Beetlefolk are sturdy, chitinous humanoids whose societies emphasize resilience, cooperation, and adaptability. They often form tight-knit communities that prioritize mutual protection, shared labor, and collective well-being.",
            "Beetlefolk culture emphasizes resilience, cooperation, and adaptability. Communities are often structured around mutual support and shared labor, with individuals working together to maintain their homes and protect one another. Their societies value industriousness, resourcefulness, and the ability to thrive in diverse environments, drawing strength from their collective efforts and the natural world around them."});

        register_lineage({"Canidar", "Humanoid (Beast)", 20,
            {"Pack Tactics: Advantage if ally within 5ft. Grant allies advantage for 1 min (1/LR).",
             "Loyal Strike: Reaction melee attack when ally within 10ft is hit."},
            {"Babel", "Canish"},
            "Canidar are wolffolk-pack-oriented, lupine humanoids known for their keen senses and unwavering loyalty. Their culture is deeply rooted in pack dynamics, emphasizing cooperation, mutual protection, and the strength of the group over individual ambition.",
            "Canidar culture is deeply rooted in pack dynamics, emphasizing loyalty, cooperation, and mutual protection. They value the strength of the group over individual ambition, often organizing their communities around shared goals and collective well-being. Their traditions celebrate unity, the wisdom of elders, and the importance of working together to overcome challenges."});

        register_lineage({"Cervin", "Humanoid (Beast)", 20,
            {"Fleet of Foot: Ignore nonmagical difficult terrain. Count as Large for Strength checks.",
             "Nature's Grace: Grant 1d4 bonus to checks for DIV allies for 10 min in nature (1/LR)."},
            {"Babel", "Cervine"},
            "Deerfolk. Elegant, antlered humanoid with swift legs and a connection to nature. Very similar to a Centaur but different.",
            "Cervin culture is closely tied to the rhythms of the natural world. They value harmony with their surroundings, agility, and the wisdom of the wild. Communities are often organized around mutual respect for nature, with traditions that honor the cycles of growth and renewal. Cervin are known for their diplomacy, gentle guidance, and the ability to move unseen through their woodland homes."});

        register_lineage({"Lithari", "Construct (Earthbound)", 20,
            {"Stone Memory: Advantage on terrain Survival. Sense creatures within 15ft on stone surfaces.",
             "Rooted Form: Resistance to all non-magical damage."},
            {"Babel", "Terran"},
            "Lithari are sentient standing stones or boulders, etched with ancient runes and slowly shifting over time. They are contemplative, patient, and deeply connected to the land. ",
            "Lithari culture is defined by patience, contemplation, and a profound bond with the land. They value wisdom gained through observation and endurance, often serving as keepers of history and guardians of sacred sites. Lithari communities are slow to change, preferring to deliberate carefully and honor the ancient traditions that have shaped them."});

        register_lineage({"Tetrasimian", "Monstrosity", 20,
            {"Four Arms: Two primary + two secondary (Light weapons only). Extra light weapon attack. Interact with 2 objects/turn.",
             "Adaptive Hide: Base AC 13. Color-shift fur for advantage on Sneak (remain motionless)."},
            {"Babel", "Simian"},
            "Tetrasimians are powerful, four-armed monstrosities known for their agility, adaptability, and cunning. Standing tall and broad-shouldered, their bodies are covered in thick, camouflaging fur that shifts in hue and texture to match their environment. Their two primary arms are strong and dexterous, while their secondary arms, though smaller, are nimble enough to manipulate objects or wield light weapons with ease.",
            "Tetrasimian culture values agility, adaptability, and cleverness. They are known for their resourcefulness and ability to thrive in challenging environments. Communities often emphasize cooperation and the use of their unique physical abilities to overcome obstacles and achieve common goals."});

        register_lineage({"Thornwrought Human", "Humanoid (Plant)", 20,
            {"Barbed Embrace: Deal 1d6 piercing to grappler/grappled creature.",
             "Verdant Curse: Poison resistance. Reaction to shed afflicted part and remove condition (1/LR)."},
            {"Babel", "Sylvan"},
            "Thornwrought are humans infused with twisted vines, bark, and blooming thorns. They are born from cursed groves and carry both beauty and danger in their forms.",
            "Thornwrought culture is shaped by their origins in cursed groves. They often live on the fringes of society, balancing the duality of their beautiful yet perilous nature."});

        // --- The House of Arachana ---
        register_lineage({"Blackroot", "Humanoid (Plant/Corrupted)", 20,
            {"Toxic Roots: 10ft poison gas action (DC 13 VIT, 1/LR).",
             "Witherborn: Advantage on Survival in blighted terrain. Absorb decay to heal 1d6+VIT and +1d4 poison (1/LR)."},
            {"Babel", "Sylvan"},
            "The Blackroot wander from blighted groves with tendrils of decay curling behind them. Their limbs creak like dead wood, and their roots carry pestilence into the soil.",
            "The Blackroot are solitary wanderers, shunned even by the most desperate outcasts. Their presence is heralded by the withering of plants and the stench of decay. Legends say they gather in blighted groves beneath the new moon, performing grim rituals to commune with forgotten spirits and feed on the life force of anything unfortunate enough to cross their path. Their society is bound by a code of silence and suffering, where betrayal is punished by slow, agonizing death, and only the most ruthless survive."});

        register_lineage({"Bloodsilk Human", "Humanoid (Aberrant/Spiderborne)", 20,
            {"Silken Trap: Restrain creature within 15ft for 1 min (1/SR).",
             "Draining Fangs: Deal 1d4 damage to restrained target and regain 1 HP (1 AP, Free Action)."},
            {"Babel", "Webscript"},
            "Silken and graceful, these spider-touched creatures weave pain and beauty into the same thread. Bloodsilk humans shimmer with crimson threads, their movements hypnotic and deadly.",
            "Bloodsilk culture values artistry, allure, and the intertwining of danger with beauty. They are known for weaving pain and elegance together, often expressing themselves through mesmerizing movement and intricate designs. Their society prizes both creativity and cunning, with individuals excelling in subtlety and charm."});

        register_lineage({"Mirevenom", "Humanoid (Beast/Swamp Horror)", 20,
            {"Venomous Blood: Melee attacker or unarmed hit triggers DC VIT save or 1d4 poison damage.",
             "Lurker's Step: Advantage on Sneak in swamp/water. Hide as a Free Action when emerging (1/SR)."},
            {"Babel", "Mirecant"},
            "These swamp-stalkers ooze venom with each breath. Slippery and scaled, Mirevenom are predators of still water and slow death.",
            "Mirevenom culture is shaped by the harsh realities of swamp life. They value cunning, patience, and the ability to strike at the perfect moment. Mirevenom communities are often small and secretive, thriving in the shadows of the wetlands. Their society prizes survival skills, stealth, and the mastery of their venomous abilities, with individuals earning respect through successful hunts and displays of resilience."});

        register_lineage({"Serpentine", "Humanoid (Beast)", 20,
            {"Venomous Bite: 1d4 poison damage. Extract venom for +1d4 poison damage on next weapon attack (1/LR).",
             "Hypnotic Gaze: Daze creature within 10ft (DC 10+DIV, 3 AP)."},
            {"Babel", "Sibilant"},
            "Snakefolk. Sinuous, scale-skinned humanoids with hypnotic eyes and a venomous bite.",
            "Serpentine culture values cunning, patience, and adaptability. They are often associated with secrecy and subtlety, thriving in environments where their skills in stealth and survival are prized. Communities may be tightly knit, with a strong emphasis on tradition and the passing down of ancient knowledge."});

        // --- The Eternal Library ---
        register_lineage({"Bookborn", "Humanoid (Construct)", 20,
            {"Origami: Fold into 2D form to move through 1-inch gaps, gain advantage vs grapple, and glide 30ft (3 AP).",
             "Paper Ward: Reduce damage by Level + INT modifier (INT times/SR)."},
            {"Babel", "Draconic"},
            "Bookborn are ancient tomes brought to life, walking archives of wisdom and memory. Their body is composed of pages that flutter when excited or agitated.",
            "Bookborn culture centers around the preservation, sharing, and pursuit of knowledge. They are renowned for their prodigious memory, scholarly discipline, and subtle magical talents honed by constant exposure to living knowledge. Bookborn often serve as guides, researchers, and mediators between mortals and other knowledge-seeking entities. Their society values learning, wisdom, and the careful stewardship of information."});

        register_lineage({"Archivist", "Humanoid (Human)", 20,
            {"Mnemonic Recall: Auto-succeed on recall/research/decipher check (1/SR).",
             "Polyglot: Study any language for 1hr to read/write. 10 min to speak (with disadvantage on checks)."},
            {"Babel", "Choice (+5 languages)"},
            "Archivists are humans shaped by generations of life within the Eternal Library. They are renowned for their prodigious memory, scholarly discipline, and subtle magical talents honed by constant exposure to living knowledge. Archivists serve as guides, researchers, and mediators between Bookborn and mortal scholars, their minds as organized as the library’s endless shelves.",
            "Archivist culture centers around the preservation, organization, and sharing of knowledge. They are renowned for their prodigious memory, scholarly discipline, and subtle magical talents honed by constant exposure to living knowledge. Archivists serve as guides, researchers, and mediators between Bookborn and mortal scholars, their minds as organized as the library’s endless shelves. Their society values learning, wisdom, and the careful stewardship of information, with respect earned through dedication to scholarship and the safeguarding of lore."});

        register_lineage({"Panoplian", "Humanoid (Construct)", 20,
            {"Living Plate: AC 16 (Heavy armor). Cannot add Speed to AC.",
             "Sentinel's Stand: Anchor yourself when Dodging. Speed 0, but unlimited opportunity attacks even if they disengage."},
            {"Babel", "Dwarvish"},
            "Panoplians are sentient suits of armor animated by forgotten oaths and battle-forged purpose. Their hollow interiors glow faintly with ancient magic.",
            "Panoplian culture is shaped by their origins as living armor, bound by oaths and a sense of duty. They value honor, loyalty, and the fulfillment of promises above all else. Panoplians often serve as guardians, champions, or keepers of ancient sites, and their society is structured around codes of conduct and martial tradition. Respect is earned through acts of valor, steadfastness, and the upholding of ancient vows, with each Panoplian carrying the legacy of battles fought and promises kept."});

        // --- The Metropolitan ---
        register_lineage({"Arcanite Human", "Humanoid", 20,
            {"Arcane Surge: +2 to Spell attack or DC (1/LR).",
             "Magic Sense: Detect magic sense (10ft range)."},
            {"Babel", "Primordial"},
            "Arcanites are humans with glowing runes etched into their skin, pulsing with latent magical energy.",
            "Arcanite Human culture is deeply intertwined with the study and practice of magic. They value knowledge, discipline, and the responsible use of arcane power. Many serve as scholars, mages, or magical artisans, dedicating their lives to mastering the runes that define their existence. Their society respects those who advance magical understanding and who use their abilities to protect and uplift their communities"});

        register_lineage({"Groblodyte", "Humanoid (Gremlin-Kin)", 20,
            {"Scrap Instinct: Tinker's Tools proficiency. Cobble one-use gadget for advantage/SP reduction (1/SR).",
             "Arcane Misfire: Overcharge spells (roll d6: 1-2 Backfire, 3-5 Normal, 6 Amplified)."},
            {"Babel", "Grobbletongue"},
            "Groblodytes are small, volatile tinker-goblins born from arcane misfires and industrial chaos.",
            "Groblodyte culture thrives in entropy. They are scavengers, inventors, and saboteurs who build communities in the ruins of magical disasters and malfunctioning factories. Their society is chaotic but surprisingly cooperative, driven by barter, invention, and mutual mischief. They don’t build cities-they infest them, turning wreckage into wonder."});

        register_lineage({"Kettlekyn", "Humanoid (Construct)", 20,
            {"Steam Jet: 15ft cone exhale 2d6 fire + level (DC 10+VIT save, 1/LR).",
             "Heat Engine: Fire/Cold resistance. Overheat for 1 min: immunity + 1d4 fire to grappled/melee hits (1/LR)."},
            {"Babel", "Gnomish"},
            "Kettlekyn are stout metal-bodied folk powered by arcane steam pressure. They often whistle under stress and emit heat from their core vents.",
            "Kettlekyn culture is shaped by their mechanical nature and the arcane forces that animate them. They value resilience, precision, and the harmonious function of community, much like the interlocking parts of a well-maintained machine. Kettlekyn often serve as engineers, mediators, or guardians, using their resonant voices and sturdy forms to aid others. Their society respects those who maintain balance, solve problems efficiently, and contribute to the collective well-being of their people."});

        register_lineage({"Marionox", "Humanoid (Construct)", 20,
            {"Tether Step: Teleport 30ft as a move action (3 AP).",
             "Wooden Frame: Advantage vs paralyzed, squeezed, grappled, petrified, prone."},
            {"Babel", "Elvish"},
            "Marionox are animated marionette puppets, brought to life by arcane threads and theatrical spirit. They move with uncanny grace and jerked precision, often drifting between silence and spontaneous performance.",
            "Marionox culture is shaped by their origins in performance and magic. They value creativity, expression, and the art of storytelling, often communicating through dramatic gestures or bursts of theatrical display. Marionox serve as entertainers, messengers, or even diplomats, using their unique talents to bridge gaps between communities. Their society respects those who master the art of performance and who use their gifts to inspire, teach, or unite others."});

        register_lineage({"Voxshell", "Construct (Sound)", 20,
            {"Resonant Voice: Project voice 300ft. Impose disadvantage on check by mocking (INT times/SR).",
             "Echo Memory: Perfectly recall and recreate any sound from the last 24 hours."},
            {"Babel", "Voxcant"},
            "Voxshells are animated, humanoid speaker-box constructs made of brass, wood, and arcane resonators. Their voices can boom like thunder or whisper like secrets, and they often serve as orators or diplomats but make horrible spies. ",
            "Voxshell culture is shaped by their arcane construction and affinity for sound and communication. They value clarity, harmony, and the sharing of ideas, often serving as mediators, diplomats, or chroniclers. Voxshell society respects those who foster understanding and unity, and their traditions emphasize the importance of voice, song, and the preservation of stories and histories."});

        // --- The Upper Forty ---
        register_lineage({"Gilded Human", "Humanoid", 20,
            {"Living Plate: Base AC 13.",
             "Market Whisperer: Know fair market value. Auto-find buyer for full price once per long rest."},
            {"Babel", "Gilded Cant"},
            "The Gilded Humans are a people whose bodies are partially encased in living metal-gold, silver, or platinum-that grows in intricate patterns across their skin. This metallic growth is both a mark of status and a natural armor. Gilded are famed for their wealth, business acumen, and mastery of finance and trade. They often serve as bankers, merchants, and patrons of the arts in the Upper Forty.",
            "Gilded Human culture is renowned for its wealth, business acumen, and mastery of finance and trade. Gilded often serve as bankers, merchants, and patrons of the arts, and their society values prosperity, negotiation, and the careful stewardship of resources. Their metallic markings are seen as both a blessing and a symbol of their connection to ancient spellcraft and status within their communities"});

        register_lineage({"Gremlidian", "Humanoid (Fey, Construct)", 20,
            {"Arcane Tinker: Tinker's tools proficiency. Create minor gadget once per long rest.",
             "Gremlin's Luck: Reroll failed skill check (2/SR)."},
            {"Babel", "Gremlish"},
            "Gremlidians are small, wiry humanoids with oversized ears, glowing eyes, and a knack for chaos. They are natural tinkerers and saboteurs, often found in arcane labs. Gremlidians look down upon Gremlins because they are unlucky.",
            "Gremlidian culture revolves around invention, experimentation, and playful disruption. They value ingenuity, adaptability, and the thrill of discovery, often pushing boundaries in both magic and technology. Gremlidians frequently serve as inventors, troubleshooters, or agents of controlled chaos, and their society respects those who can turn disorder into opportunity and who thrive in unpredictable environments."});

        register_lineage({"Hexkin", "Humanoid (Cursed Lineage)", 20,
            {"Hex Mark: Impose disadvantage on saves vs your spells for 1 min (1/LR).",
             "Witchblood: +2 bonus to Spell DC (1/SR)."},
            {"Babel", "Witchscript"},
            "Markings crawl across their skin like script come alive. Hexkin are the cursed children of ancient spellcraft, bearing sigils that warp reality and twist the will.",
            "Hexkin are the cursed children of ancient spellcraft, and their society is shaped by the burden and power of their magical heritage. They are often viewed with a mix of awe and suspicion, and Hexkin communities value knowledge, resilience, and the mastery of their arcane gifts, striving to control the forces that twist their will and reality itself"});

        register_lineage({"Voxilite", "Humanoid", 20,
            {"Golden Tongue: Advantage on influence checks.",
             "Commanding Voice: Issue single-word command (1/LR). Extra uses cost Max HP."},
            {"Babel", "Vox Cant"},
            "Voxilites are charismatic, gold-adorned individuals whose voices carry a subtle, enchanting resonance. Their vocal cords are naturally attuned to persuasive frequencies, making them master negotiators, politicians, and media personalities. Voxilites often serve as the public faces of powerful organizations, swaying public opinion and brokering high-stakes deals.",
            "Voxilite culture values appraisal and trade, as they have a natural talent for determining the value of objects, gems, and art. They are often involved in commerce and negotiation, and their society prizes clarity, precision, and the sharing of knowledge. Voxilites commonly speak Babel and Vox Cant, reflecting their affinity for communication and exchange."});

        // --- The Lower Forty ---
        register_lineage({"Ferrusk", "Humanoid (Construct)", 20,
            {"Overdrive Core: Gain 2d4+VIT AP as basic action (1/SR).",
             "Scrap Resilience: Slashing resistance. Taking slashing damage grants +1 AC for 1 round."},
            {"Babel", "Mechan"},
            "Ferrusks are biomechanical humanoids with rusted plating, exposed gears, and glowing cores. They are remnants of a forgotten age of war and invention.",
            "Ferrusk society is shaped by their unique nature as beings of both flesh and machine. They value endurance, adaptability, and the pursuit of self-improvement, often seeking ways to enhance themselves physically and mentally. Ferrusks are respected for their reliability and strength, and their communities emphasize cooperation, innovation, and the responsible use of technology."});

        register_lineage({"Gremlin", "Humanoid", 20,
            {"Tinker: Create volatile gadget (Flashbang, Arc Spark, or Grease Puff) (1/LR).",
             "Sabotage: Disable device for 1 min (1/SR). Choice of backfire effect."},
            {"Babel", "Gremlin"},
            "Gremlins are small, wiry, and mischievous, with oversized ears and nimble fingers, often found in the underbellies of cities. Gremlins loathe Gremlidians for stealing their luck and the Groblodytes for stealing their gambit..",
            "Gremlin culture revolves around invention, experimentation, and playful disruption. They value ingenuity, adaptability, and the thrill of discovery, often pushing boundaries in both magic and technology. Gremlins frequently serve as inventors, troubleshooters, or agents of controlled chaos, and their society respects those who can turn disorder into opportunity and who thrive in unpredictable environments."});

        register_lineage({"Hexshell", "Construct (Arcane-Cursed)", 20,
            {"Reflect Hex: Reflect condition to caster (DC 10+DIV save, 1/LR).",
             "Cursed Circuitry: +2 to Spell saves when below 2/3 HP."},
            {"Babel", "Hexcode"},
            "Wrought from magic gone wrong, Hexshells are arcane constructs made of cursed runes and cracked plating. Their eyes glow with warnings the gods dare not speak aloud.",
            "Hexshells are shaped by their origins as products of magical mishap, often regarded with fear or suspicion by others. Their society values resilience, caution, and the pursuit of understanding the arcane forces that created them, striving to find purpose and acceptance despite the stigma of their cursed existence."});

        register_lineage({"Ironjaw", "Humanoid", 20,
            {"Magnetic Grip: Advantage to grapple creatures in metal armor. Pull small metal objects from 5ft.",
             "Iron Stomach: Advantage vs ingested poison. Basic magic attack can do poison damage for free."},
            {"Babel", "Orc"},
            "Ironjaws are broad, muscular, and have metallic teeth and jawbones. ",
            "Ironjaw culture is shaped by resilience and strength, with a focus on enduring hardship and overcoming adversity. They value toughness, both physical and mental, and their communities often emphasize mutual support and the ability to withstand challenges together."});

        register_lineage({"Scavenger Human", "Humanoid (Human)", 20,
            {"Scrap Sense: Once per short rest, auto-succeed on search check in ruins/mechanical areas (1/SR).",
             "Toxic Resilience: Advantage vs poisons/disease. Absorb toxin on save for resistance + poison unarmed."},
            {"Babel", "Choice (+1 language)"},
            "Scavengers are humans adapted to life in the labyrinthine depths of the Lower Forty, a region known for its rusted machinery, forgotten relics, and hazardous conditions. These scavengers are resourceful, quick-witted, and tough, having learned to survive by salvaging valuable scraps and avoiding the dangers that lurk in the shadows.",
            "Scavenger Human culture is shaped by survival and ingenuity. Living among the ruins and dangers of the Lower Forty, they value adaptability, cleverness, and the ability to make the most out of limited resources. Their communities are tight-knit, relying on cooperation and shared knowledge to thrive in an environment where every day presents new challenges"});

        // --- The Shadows Beneath ---
        register_lineage({"Corvian", "Humanoid (Beast)", 20,
            {"Mimicry: Imitate voices/sounds. Signal allies silently within 60ft.",
             "Shadow Glide: +20 Speed, Flight, and Invisibility in dim light/darkness for 1 round (3 AP)."},
            {"Babel", "Corvish"},
            "Crowfolk. Slender, black-feathered humanoids with sharp eyes and a knack for secrets.",
            "Corvian culture is deeply intertwined with themes of stealth, illusion, and forbidden knowledge. Often feared or misunderstood by others, Corvians are adept at concealment and value the acquisition and protection of secrets. Their communities tend to be insular, relying on trust and shared information to navigate a world that often views them with suspicion"});

        register_lineage({"Duskling", "Humanoid", 20,
            {"Shadowgrasp: Restrain creature within 10ft (DC 10+INT save, 3 AP).",
             "Nightvision: 30ft darkvision and advantage on Sneak in low light."},
            {"Babel", "Umbral"},
            "Dusklings are small, shadowy figures with dark, muted skin tones and large, reflective eyes, adept at blending into the darkness.",
            "Duskling culture is shaped by their affinity for shadows and concealment. They often value stealth, subtlety, and adaptability, thriving in environments where blending in and moving unseen are essential for survival. "});

        register_lineage({"Duckslings", "Humanoid", 20,
            {"Slippery: Advantage vs grapples when wet. Poison resistance near freshwater.",
             "Quack Alarm: Startling quack gives allies advantage on next initiative/surprise save (1/LR)."},
            {"Babel", "Mirecant"},
            "Duckslings are small, downy-feathered humanoids with rounded beaks and webbed fingers and toes, known for their cheerful nature and affinity for water. They are just barely still able to fly.",
            "Duckslings live in close-knit communities near rivers, lakes, and marshes. Their culture values cooperation, playfulness, and storytelling, with frequent gatherings to celebrate the seasons or assist one another. Hospitality and resourcefulness are central, and they emphasize harmony with nature and caring for kin and environment."});

        register_lineage({"Hollowborn Human", "Humanoid (Undead)", 20,
            {"Undead Resilience: Immune to poison/disease. Advantage vs environmental exhaustion.",
             "Deathless: No food/drink needed. Double stamina for rest."},
            {"Babel", "Necril"},
            "Hollowborn Humans are gaunt, pallid, and often bear visible signs of undeath, such as sunken eyes or faintly glowing marks, yet move with unnatural vitality.",
            "Hollowborn Human culture is shaped by their unique existence between life and undeath. They are often viewed with suspicion or fear by others, but within their own communities, they value endurance, adaptability, and the ability to find purpose despite their condition"});

        register_lineage({"Sable", "Humanoid", 20,
            {"Night Vision: 120ft magical darkvision. Create 10ft cube of darkness within 30ft (1/LR).",
             "Silent Step: Advantage on Sneak when moving at half speed."},
            {"Babel", "Sablespeak"},
            "Born beneath moonless skies and shaped by the rhythm of shadow, the Sables are a people of quiet grace and unspoken strength. Their tall, willowy forms move with an ease that borders on spectral, and their smooth, dark skin seems to drink in light rather than reflect it. The glow of their eyes — soft hues of silver, gold, or violet — is the first and often only sign of their presence in the dark.",
            "Sable culture emphasizes adaptability and subtlety, with a strong value placed on the ability to navigate darkness and remain unnoticed when necessary. Their communities often rely on cooperation and the sharing of knowledge about their environment to survive and thrive."});

        register_lineage({"Twilightkin", "Humanoid (Fey)", 20,
            {"Veilstep: Swap places with ally in dim light/darkness within 30ft (1/SR).",
             "Duskborn Grace: Auto-succeed on Sneak in dim light/darkness for 1 min (1/SR)."},
            {"Babel", "Sylvan"},
            "Twilightkin are dusky-skinned humanoids with eyes that shimmer like starlight and hair that flows like shadow. They are born in the liminal spaces between day and night, and are known for their grace, mystery, and affinity for illusions.",
            "Twilightkin culture is shaped by their affinity for shadows and concealment. They often value subtlety, adaptability, and the ability to navigate both literal and social darkness. Their communities tend to be close-knit, relying on mutual trust and shared secrets to thrive in a world where being unseen can be a vital asset."});

        // --- The Corrupted Marshes ---
        register_lineage({"Bogtender", "Giantkin", 20,
            {"Marshstride: Move through difficult terrain without penalty.",
             "Mossy Shroud: Cover self/ally in moss for Stealth advantage + Cold resistance (1/LR)."},
            {"Babel", "Druidic"},
            "Bogtenders are gentle, moss-covered giants who tend to the rare, uncorrupted patches of the marsh.",
            "Bogtender culture centers around caretaking and preservation. They are devoted to nurturing and protecting the last remnants of unspoiled nature within the marshes, using their strength and wisdom to maintain balance and foster growth in a landscape otherwise marked by corruption and decay."});

        register_lineage({"Mireborn Human", "Humanoid", 20,
            {"Mud Sense: Sense movement through mud/water (10ft). Advantage vs restrained/grappled in mud.",
             "Mire Resilience: Poison resistance. Burst of poison gas on successful save (DC 10+VIT)."},
            {"Babel", "Aquan"},
            "Mireborn are amphibious humans, with mud-caked skin and webbed hands and feet.",
            "Mireborn Human culture is shaped by their marshland homes. They are resourceful and resilient, often relying on their keen senses and adaptability to survive in challenging, waterlogged terrain. Their communities are typically close-knit, with traditions centered around foraging, fishing, and making the most of the marsh’s natural resources."});

        register_lineage({"Myrrhkin", "Humanoid (Spiritual)", 20,
            {"Soothing Aura: Calming scent gives allies advantage vs fear/charm (1/LR).",
             "Dreamscent: 30ft haze of sleep incense (DC 10+DIV INT save, 1/LR, 1 SP per target)."},
            {"Babel", "Incensari"},
            "Myrrhkin presence exudes a tranquil aura, and a touch from a Myrrhkin can ease pain or evoke vivid, dreamlike visions in those nearby.",
            "Myrrhkin are spiritual humanoids steeped in incense, rot, and ritual. In the Corrupted Marshes, they serve not only as healers and visionaries-but as death-guides, plague-priests, and keepers of forgotten pacts. Their ceremonies are laced with narcotic fumes and whispered bargains to unseen forces. Peace, to the Myrrhkin, is not the absence of conflict but the stillness that follows decay. They believe that insight is born from suffering, and that true healing often requires sacrifice-of memory, of flesh, or of soul. Their presence is soothing, but never comforting; it is the calm of a bog that swallows the unwary."});

        register_lineage({"Oozeling", "Humanoid (Ooze)", 20,
            {"Amorphous Form: Squeeze through 6-inch gaps. Immune to squeeze condition.",
             "Corrosive Touch: Unarmed hit or melee hit on you deals 1d4 acid damage to target's armor/weapon."},
            {"Babel", "Choice"},
            "Though often misunderstood as mindless, Oozelings possess strange intelligence and eerie insight into decay and transformation.",
            "Oozeling culture centers around adaptability and fluidity. They value flexibility, both physically and socially, and their communities are often loosely organized, with individuals coming together and drifting apart as needed. Oozelings are known for their resilience and ability to thrive in environments that others might find inhospitable."});

        // --- The Crypt at the End of the Valley ---
        register_lineage({"Blood Spawn", "Humanoid (Bloodborne)", 20,
            {"Bloodletting Blow: Deal +1d4 melee damage and heal for total damage (3 AP).",
             "Bloodsense: Blindsight for bleeding creatures within 15ft. Advantage on attacks."},
            {"Babel", "Old Tongue"},
            "Forged in rituals steeped in blood and sacrifice, Blood Spawn shimmer with vitality that leaks through their skin like a crimson mist. They hunger for death-to feed, to empower. ",
            "Blood Spawn are forged in rituals steeped in blood and sacrifice, and they hunger for death-to feed, to empower. Their society is shaped by this drive, with individuals often seeking strength and purpose through acts of predation or ritual. Blood Spawn communities may be insular and wary, bound together by shared origins and the need to survive in a world that fears their power"});

        register_lineage({"Cryptkin Human", "Humanoid (Necrotic)", 20,
            {"Boneclatter: 15ft fear rattle (DC 10+DIV SPIRIT save, 3 AP).",
             "Diseaseborn: Immune to disease. Advantage vs curses. Apply curse on hit (1/LR)."},
            {"Babel", "Gravechant"},
            "These wretched, hunched scavengers creep through mausoleums and catacombs, feeding on secrets and marrow alike. Cryptkin wear the bones of their enemies as trophies, and sleep where the dead lie still.",
            "Cryptkin culture is shaped by their life among the dead and the shadows. They are adept at stealth and survival, feeding on secrets and marrow alike. Their society values cunning, concealment, and forbidden knowledge, and they are often feared or misunderstood by others due to their close relationship with necrotic energies and the themes of stealth, illusion, and fear that permeate their existence."});

        register_lineage({"Gloomling", "Humanoid", 20,
            {"Umbral Dodge: Turn invisible in darkness for 1 round (3 AP, Free Action).",
             "Shadow Sight: 120ft magical/nonmagical darkvision."},
            {"Babel", "Choice"},
            "Gloomlings are shadowy, with indistinct features and eyes that gleam in the dark.",
            "Gloomlings are shaped by themes of stealth, illusion, fear, concealment, necrotic energy, and forbidden knowledge. They are often feared or misunderstood by other societies, and their communities tend to be secretive and insular. Gloomlings value secrecy, cunning, and the pursuit of hidden truths, often using their abilities to navigate the world unseen and to gather knowledge that others might consider dangerous or taboo."});

        register_lineage({"Skulkin", "Humanoid (Undead/Small)", 20,
            {"Crawlspace: Squeeze through 6-inch gaps. Advantage on Sneak and resistance to bludgeoning area effects.",
             "Gnawing Grin: Curse creature within 30ft to steal its healing and redirect your damage (1/LR)."},
            {"Babel", "Necril"},
            "Skulkin drift through the margins of the living world like gleeful phantoms. They are creatures of twilight places, drawn to silence, secrets, and the hollow spaces left behind by death. Their presence is unsettling, their laughter sharp and dry.",
            "Skulkin are shaped by themes of stealth, illusion, fear, concealment, necrotic energy, and forbidden knowledge. They are often feared or misunderstood by other societies and tend to use their abilities for mischief or to haunt places of death and decay. Their communities are secretive and value cunning, trickery, and the gathering of hidden knowledge."});

        // --- Spindle York’s Schism ---
        register_lineage({"Cragborn Human", "Humanoid", 20,
            {"Stonecunning: Advantage to identify stonework. Detect hidden stone doors within 5ft (1/SR).",
             "Earth’s Embrace: Advantage vs prone. +1 AC and immovability while on stone/earth."},
            {"Babel", "Dwarvish"},
            "Cragborn are squat, thick-skinned folk with jagged features and gravelly voices.",
            "Cragborn culture is shaped by their resilience and resourcefulness, thriving in difficult terrains where others might struggle. Their communities value strength, endurance, and a close connection to the land, often developing unique traditions and customs suited to life among crags and cliffs."});

        register_lineage({"Gravari", "Humanoid", 20,
            {"Stone’s Endurance: Reduce damage by 1d12 + VIT (VIT times/SR).",
             "Stone Sense: Advantage to detect stone traps/doors. Mason's tools proficiency."},
            {"Babel", "Terran"},
            "Gravari are sturdy and broad, with stone-like skin in earthy tones and features reminiscent of carved statues.",
            "Gravari culture is shaped by their resilience and connection to the earth. Their communities often value strength, endurance, and stability, drawing inspiration from their stone-like nature. Gravari are likely to build societies that emphasize tradition, communal support, and a deep respect for the land and its resources"});

        register_lineage({"Graveleaps", "Humanoid (Reptilian)", 20,
            {"Stoneclimb: Climb speed = Walk speed. Advantage on rocky climbs.",
             "Gravebound Leap: Triple jump distance."},
            {"Babel", "Reptilian"},
            "Graveleaps are small, lizard-like humanoids with stony, mottled scales and luminous eyes adapted to the shifting shadows of Spindle York’s Schism. Agile and sure-footed, they are renowned for their ability to leap great distances and cling to sheer canyon walls. Graveleaps are community-oriented, often living in tight-knit burrows along the chasm’s edge. ",
            "Leapers are community-oriented, often living in tight-knit burrows along rocky landscapes. Their society values agility, cooperation, and adaptability, thriving in environments where their unique physical abilities give them an advantage"});

        register_lineage({"Shardkin", "Humanoid", 20,
            {"Crystal Resilience: Bend light for 1 min (+3 AP committed) for Stealth advantage.",
             "Harmonic Link: Form mental link with 3 creatures (1 mile range, 1hr)."},
            {"Babel", "Shardtongue"},
            "Shardkin are humanoids with crystalline skin and angular features, their bodies refracting light and often shimmering with inner color.",
            "Shardkin typically speak Babel and Dwarvish, suggesting a culture influenced by both human and dwarven traditions. Their connection to stonework and crystalline forms may lead to societies that value craftsmanship, artistry, and resilience. The unique nature of their bodies likely shapes their customs and social structures, emphasizing unity, durability, and the beauty found in their crystalline heritage"});

        // --- Peaks of Isolation ---
        register_lineage({"Boreal Human", "Humanoid (Cold/Wind)", 20,
            {"Winter Breath: 15ft cube freezing wind deals 2d4 cold damage (3 AP).",
             "Icewalk: Ignore snow/ice difficult terrain. Advantage vs prone on ice."},
            {"Babel", "Frigian"},
            "Forged in the deep polar winds and ancient glaciers, the Borealborn humans are regal and remote. Their voices are hushed, their eyes reflective like frostglass.",
            "Boreal Human culture is shaped by life in the harsh, frozen regions known as the Peaks of Isolation. Their communities value resilience, cooperation, and resourcefulness, relying on each other to endure the relentless cold. Traditions often center around warmth, storytelling, and the preservation of knowledge and resources through long winters."});

        register_lineage({"Frostborn", "Humanoid", 20,
            {"Cold Resistance: Release frost burst on melee hit (2 AP, DC 10+VIT Speed save).",
             "Icewalk: +2d4 cold damage to attacks for 1 min (1/SR)."},
            {"Babel", "Frigian"},
            "Frostborn have pale blue skin, icy hair, and a chill that follows them.",
            "The Frostborn endure in the harshest, most unforgiving reaches of the world, their society forged by relentless cold and scarcity. Communities are bound by necessity rather than warmth, with survival hinging on strict cooperation and the sharing of limited resources. Tradition and law are upheld with little tolerance for weakness or failure, and outsiders are often met with suspicion. The Frostborn respect the power of winter, viewing the frost and snow as both adversary and judge. Resilience and self-reliance are prized above all, and their customs reflect a stoic acceptance of hardship. Leadership is earned through strength and the ability to guide others through peril, while rituals mark the passing of seasons and the endurance of another year in the frozen dark."});

        register_lineage({"Glaceari", "Humanoid (Ice)", 20,
            {"Frozen Veil: Surround in icy mist for 1 min, attacks have disadvantage (1/LR).",
             "Chillblood: Cold resistance. Commit AP to lower temperature in 10ft radius."},
            {"Babel", "Frigian"},
            "Glaceari are beings of frost and patience, with skin that is translucent like packed snow. Their breath forms constellations in the cold, and they move with the grace and inevitability of winter itself.",
            "Glaceari embody patience and endurance, reflecting the slow, persistent nature of winter. Their culture is likely centered around themes of resilience, contemplation, and harmony with the cold. They may value traditions that honor the cycles of nature and the quiet strength found in stillness and perseverance."});

        register_lineage({"Nimbari", "Humanoid (Elemental/Air)", 20,
            {"Stormcall: 15ft burst dazes creatures (DC 10+SPD Speed save, 3 AP).",
             "Summon Cloud: Hover 10ft above ground and ignore terrain."},
            {"Babel", "Auran"},
            "Their bodies appear ethereal, composed of mist and vapor made solid, and they often hover about a foot above the ground, moving with a lightness that defies gravity.",
            "Nimbari typically speak Babel and Auran, reflecting their connection to the winds and skies. They are resistant to cold damage and are able to summon a cloud to ride, which only they can use. Their society is likely shaped by themes of freedom, movement, and adaptability, with customs and traditions that honor the ever-changing nature of the sky and the importance of flexibility in both thought and action."});

        register_lineage({"Tombwalker", "Humanoid (Undead)", 20,
            {"Gravebind: Absorb 1d4+DIV HP from creature within 30ft (DC 10+DIV VIT save, 3 AP).",
             "Deathless Endurance: Drop to 1 HP instead of 0 once per long rest."},
            {"Babel", "Necril"},
            "Tombwalkers are gaunt, death-touched humanoids wrapped in ancient burial cloth and etched with glowing runes. Their unsettling appearance is further emphasized by their skeletal features and the aura of the grave that clings to them.",
            "Tombwalkers are often found wandering crypts or serving as guardians of forgotten graves, bound by pacts with the dead. Their role as protectors of burial sites and their connection to ancient pacts make them both mysterious and respected-or feared-by others"});

        // --- Pharoah’s Den ---
        register_lineage({"Chokeling", "Humanoid (Fungal/Poison)", 20,
            {"Sporespit: 10ft cube silence spores (DC 10+VIT VIT save, 3 AP).",
             "Rotborn: Poison resistance. Decay small organic objects (1/LR)."},
            {"Babel", "Sporetalk"},
            "Chokelings resemble hunched, fungal silhouettes, their forms cloaked in ragged layers of spongy growths that pulse faintly with each breath. Where a face might be, only a smooth, featureless expanse stretches, broken by clusters of tiny, shifting spores. Their limbs are elongated and jointless, moving with a slow, deliberate grace, and a faint, earthy scent lingers in their wake.",
            "Chokelings possess a unique means of communication, described as having a \"voice like dust.\" This suggests their culture is shaped by their fungal nature and their unusual way of interacting with the world, likely fostering close-knit communities that rely on alternative forms of expression and understanding"});

        register_lineage({"Crimson Veil", "Humanoid (Vampiric)", 20,
            {"Bloodletting Touch: Unarmed hit heals for half damage (3 AP).",
             "Velvet Terror: Advantage on Speechcraft in formal settings. Charm/Frighten nearby creatures."},
            {"Babel", "Vampiric"},
            "Crimson Veil are elegant and venomous, with a vampiric allure. They are socialites who feed off admiration and blood, exuding an air of sophistication and danger.",
            "Crimson Veil are known for their social nature, thriving in environments where they can interact and influence others. Their vampiric tendencies are balanced by their need for social engagement, making them both captivating and potentially perilous members of society"});

        register_lineage({"Jackal Human", "Humanoid (Human)", 20,
            {"Tomb Sense: Necrotic resistance. Detect hidden undead/traps/passages (1/LR).",
             "Desert Cunning: Advantage on arid Survival. Foraging always yields 1 ration."},
            {"Babel", "Necril"},
            "Jackals possess lean, angular physiques with sharp facial features and alert, expressive eyes. Their skin is often sun-bronzed from years beneath harsh desert suns, and their hair ranges from sandy brown to deep black, sometimes streaked with pale hues from wind and sand.",
            "Their culture is defined by the harsh environment they inhabit, focusing on survival amidst constant threats from the undead and the unforgiving desert. This has led to a people who are vigilant, resourceful, and attuned to both the dangers and mysteries of their homeland."});

        register_lineage({"Whisperspawn", "Humanoid (Psionic/Shadow)", 20,
            {"Mindscratch: 2d4 psychic damage + Disadvantage on Intellect check (1/SR).",
             "Voice Like Dust: Telepathy within 30ft (must whisper)."},
            {"Babel", "Whispering"},
            "Whisperspawn appear as slender, shadow-wreathed figures, their outlines blurred as if seen through a veil of mist. Their skin shimmers with a subtle, iridescent sheen, and their hair drifts weightlessly, as though underwater. When they move, the air around them seems to ripple, and their presence is often marked by a fleeting chill or the softest echo of distant voices.",
            "Whisperspawn speak in dreams and listen in the dark, suggesting a culture deeply tied to secrecy, subtlety, and the unseen realms of thought and shadow. Their existence is intertwined with the boundaries between consciousness and darkness, making them enigmatic and mysterious to others."});

        // --- The Darkness ---
        register_lineage({"Gravemantle", "Construct", 20,
            {"Magnetic Grip: Reduce SP cost of metal telekinesis by 2.",
             "Gravitational Leap: Double speed and fly in straight lines for 1 min (1/SR)."},
            {"Babel", "Mechan"},
            "Gravemantles are sentient armor frames forged with wiry cords, their minds sharpened like hidden blades. They possess a distinctly constructed and armored form, setting them apart from typical humanoids.",
            "As Trapborn, Gravemantles are likely shaped by their origins as sentient constructs, possibly serving as guardians or protectors in dangerous environments such as the Darkness. Their culture may emphasize vigilance, duty, and the mastery of traps or defensive tactics, reflecting their unique nature and purpose"});

        register_lineage({"Nightborne Human", "Humanoid (Shadow-Aligned)", 20,
            {"Veilstep: Teleport 20ft in darkness (3 AP).",
             "Creeping Dark: Advantage on Sneak/Insight at night. Shadow-invisibility (1/LR)."},
            {"Babel", "Umbral"},
            "Nightborne Humans are veiled in darkness and born of half-forgotten omens. They drift through shadow and legend, with some saying they are what dreams become when they sour. Their presence is mysterious and shadow-aligned, often evoking an eerie or otherworldly aura.",
            "Nightborne are associated with themes of stealth, illusion, fear, concealment, necrotic energy, and forbidden knowledge. They are often feared or misunderstood by others, and their cultural role tends to revolve around secrecy and the unknown, drawing power from the Absence left by the Shattering and the shadows of forgotten gods"});

        register_lineage({"Snareling", "Humanoid (Trapborn)", 20,
    {"Ambusher’s Gift: Initiative advantage. Draw weapon part of initiative.",
     "Tangle Teeth: Melee hit reduces target speed by 10ft."},
    {"Babel", "Snaretongue"},
    "Snarelings are wiry, sharp-limbed humanoids whose bodies seem built for sudden motion and hidden violence. Their long fingers end in hooked nails, their posture low and coiled like a sprung trap waiting to happen.",
    "Snareling culture revolves around ambush, preparation, and environmental mastery. They construct territories filled with snares, pitfalls, and hidden mechanisms known only to them. Among their people, patience and planning are valued above brute strength, and the greatest honor is crafting a trap so elegant that the victim never realizes it existed"});

                // --- Arcane Collapse ---
        register_lineage({"Blightmire", "Ooze (Corrupted Arcane)", 20,
            {"Toxic Seep: 10ft aura deals 1 poison damage.",
             "Absorb Magic: Reaction to gain Temp HP from spell targeting you (1/SR)."},
            {"Babel", "Mirecant"},
            "Blightmires are living masses of corrupted magical sludge, their bodies rippling with unstable color and half-dissolved shapes. Their forms slosh and reform constantly, as though held together only loosely by the lingering residue of failed spells.",
            "Blightmire culture is shaped by survival in magically poisoned wastelands where arcane disaster has become environment. They gather in foul pools, broken ruins, and zones of magical runoff, developing a grim resilience and a strange familiarity with magical corruption. Their communities value endurance, adaptation, and the ability to siphon strength from the very forces that would destroy others"});        

        register_lineage({"Dregspawn", "Humanoid (Abyssal Mutant)", 20,
            {"Mutant Grasp: +5ft reach. Increase reach by another 5ft (VIT times/SR).",
             "Aberrant Flexibility: Squeeze through 6-inch gaps. End conditions (1/SR)."},
            {"Babel", "Deepgroan"},
            "Dregspawn are chaotic beings with bodies that seem to defy normal anatomy, their limbs bending the wrong way and their features warped by the aftermath of arcane collapse. Each one bears a different pattern of deformity, making them unsettling and unmistakably shaped by magical disaster.",
            "Dregspawn culture is born from rejection, mutation, and survival at the edge of ruined places. Their communities, when they exist, are insular and hardened, built on shared necessity rather than comfort. They value adaptability, toughness, and mutual recognition among the broken, turning their aberrant forms into a mark of endurance rather than shame"});

        register_lineage({"Nullborn", "Humanoid (Voidborn)", 20,
            {"Void Aura: 15ft null-aura (1/LR). 50% spell failure and daze/confuse chance.",
             "Devour Essence: Regain SP equal to DIV when killing a creature."},
            {"Babel", "Nullscript"},
            "Nullborn are shadowy, vaguely humanoid figures with featureless faces and bodies that seem to absorb light. Their presence is marked by a chilling stillness and a distortion in the air around them, as though magic itself recoils from their existence.",
            "Nullborn culture is defined by absence, secrecy, and the slow erosion of all magical certainty. They are solitary more often than communal, but when they gather it is in silent conclaves devoted to studying magical failure and the pull of the Void. Their society is shaped by nihilism, discipline, and the belief that erasure is sometimes the purest form of truth"});

        register_lineage({"Shardwraith", "Undead (Arcane Specter)", 20,
            {"Crystal Slash: 15ft cube razor shards (1/SR, DC 10+DIV SPD save).",
             "Spectral Drift: Move through solid objects for 1d4 force damage."},
            {"Babel", "Shardtongue"},
            "Shardwraiths are gaunt, translucent specters threaded with jagged, glowing crystal shards that hover within and around their forms. Their eyes burn with cold arcane light, and their voices echo like glass breaking in an empty ruin.",
            "Shardwraith culture is built from predation, scavenging, and the remnants of shattered arcane power. They haunt the ruins of the Arcane Collapse in loose and treacherous bands, drawn to relics, magical residue, and places of lingering devastation. Among them, dominance belongs to the strongest or most cunning, and leadership lasts only until someone sharper takes it"});        

                // --- The Glass Passage ---
        register_lineage({"Galesworn Human", "Humanoid", 20,
            {"Wind Step: Jump distance doubled. Once per long rest, 1 min wind cloak (ranged disadvantage).",
             "Gustcaller: For 3 AP, push object 10ft or creature 5ft (DC 10+DIV STR save)."},
            {"Babel", "Auran"},
            "Galesworn Humans are lean, weathered people shaped by constant wind and open sky, their hair and clothing forever seeming to stir with unseen currents. Their movements are light and deliberate, and many carry the restless look of those who have spent their lives crossing vast and unforgiving distances.",
            "Galesworn culture is defined by endurance, mobility, and respect for the forces of the air. Their communities are often semi-nomadic, built around caravans, cliffside shelters, and wind-carved paths through the desert. They prize adaptability, navigation, and self-control, teaching that to survive the Glass Passage one must learn when to stand firm and when to move like the wind itself"});

        register_lineage({"Pangol", "Humanoid (Beast)", 20,
            {"Natural Armor: Base AC 13. Gain +5 AC as reaction when hit (Speed times/LR).",
             "Curl Up: Once per short rest, reaction curl for immunity (speed 0, blind)."},
            {"Babel", "Pangolish"},
            "Pangols are stocky, scale-covered humanoids with powerful claws, heavy tails, and layered armored hides that overlap like living shields. Their posture is cautious and grounded, and when threatened they can fold inward with startling speed into an almost impenetrable defensive form.",
            "Pangol culture values caution, patience, and mutual protection. Their communities are often built into stone hollows, dunes, or fortified burrows where defense is woven into daily life. They teach their young to endure before striking, and their social bonds are strong, with protection of kin and clan treated as the highest duty"});

        register_lineage({"Porcelari", "Humanoid (Construct)", 20,
            {"Shatter Pulse: Release 1d6 force damage in 5ft radius on critical hits.",
             "Gilded Bearing: Advantage on Speechcraft in formal settings. Disadvantage on opponent check."},
            {"Babel", "Celestial"},
            "Porcelari are elegant construct-humanoids fashioned from smooth ceramic bodies traced with gold, silver, or painted enamel. Their movements are poised and delicate, and even in stillness they carry the refined beauty of something crafted to be admired as much as endured.",
            "Porcelari culture is steeped in ceremony, aesthetics, and social precision. They are often found in courts, temples, or enclaves where etiquette and appearance carry tremendous weight. Their people value composure, artistry, and the maintenance of dignity under pressure, believing that beauty and order are forms of strength in a fractured world"});

        register_lineage({"Prismari", "Humanoid", 20,
            {"Chromatic Shift: Once per short rest, blend color for advantage on Sneak.",
             "Prismatic Reflection: Once per long rest, reaction refract light for 1 min resistance."},
            {"Babel", "Prismal"},
            "Prismari are striking humanoids whose skin, eyes, or hair catch and scatter light in shifting bands of color. Their features seem to change subtly depending on the angle of the light, giving them an almost unreal beauty that is difficult to look at the same way twice.",
            "Prismari culture is shaped by light, perception, and the idea that truth is rarely singular. Their communities celebrate artistry, personal expression, and the symbolic meaning of color, often using reflection and refraction in ritual and architecture. They value adaptability and nuance, believing that survival in the Glass Passage depends on understanding how appearances shift without losing sight of what is real"});

        register_lineage({"Rustspawn", "Construct (Corrosion-Infused)", 20,
            {"Corrosive Aura: Melee weapons hitting you take -1 damage and use triple HP.",
             "Ironrot: Resistance to acid. Acid damage empowers next melee attack (+1d4)."},
            {"Babel", "Mechan"},
            "Rustspawn are corroded construct beings whose bodies are built from pitted iron, oxidized plating, and creaking mechanical joints. Their forms bear the scars of long exposure to harsh elements, and flakes of rust often trail from them like dry blood from old wounds.",
            "Rustspawn culture is rooted in endurance, salvage, and the acceptance of decay as part of existence. They are often found among ruins, abandoned engines, and desolate waystations where other peoples see only ruin. Among their kind, damage is not shameful but instructive, and age, wear, and corrosion are treated as marks of hard-earned survival"});

        // --- Sacral Separation ---
        register_lineage({"Dustborn", "Humanoid (Sand/Earth)", 20,
            {"Dust Shroud: Once per long rest, 10 ft swirling sand radius (disadvantage vs you, attack action 2d4).",
             "Dryblood: Resistance to dehydration and heat exhaustion. Forage 1 ration always."},
            {"Babel", "Durespeech"},
            "Dustborn are weathered humanoids whose skin resembles compacted sand, dry clay, or wind-smoothed stone, with eyes that glint like buried minerals beneath the desert sun. Their voices rasp like shifting dunes, and their bodies seem shaped as much by erosion and time as by flesh and blood.",
            "Dustborn culture is defined by endurance, memory, and respect for the dead and the land that buries them. Many serve as guides, mediums, gravekeepers, or wanderers who know how to survive where others would be stripped bare by heat and hunger. Their communities value resilience, restraint, and the carrying forward of stories that would otherwise be lost beneath the sands"});

        register_lineage({"Glassborn", "Humanoid (Elemental)", 20,
            {"Shatter Pulse: Once per long rest, struck by melee releases burst (DC 10+DIV VIT save).",
             "Prism Veins: Resistance to radiant. Flare body for +1d4 saves for allies within 15ft."},
            {"Babel", "Crystaltongue"},
            "Glassborn are translucent humanoids whose bodies resemble living crystal and desert glass, with veins of light running through them like molten color frozen in place. Their forms catch the sun in dazzling ways, and even small movements can send glimmers dancing across the ground around them.",
            "Glassborn culture is shaped by fragility, brilliance, and the harsh beauty of the desert. Their communities often gather around sacred reflective formations, glass fields, or places where heat and magic have fused the land into luminous structures. They value clarity, beauty, and inner strength, believing that even what can shatter may still endure and inspire"});

        register_lineage({"Gravetouched", "Humanoid (Undead-Touched)", 20,
            {"Death’s Whisper: Once per long rest, speak with corpse for 1 minute.",
             "Chill of the Grave: Resistance to necrotic. Move through grave terrain. +1d4 Intuition/Perception near graves."},
            {"Babel", "Necril"},
            "Gravetouched are pallid, solemn humanoids whose features carry the stillness of the grave without fully belonging to death. Their eyes are often unnervingly calm, and the air around them feels cooler, as though they carry the hush of burial places wherever they go.",
            "Gravetouched culture is deeply intertwined with burial rites, ancestral memory, and reverence for those who have passed beyond life. They are often found near tombs, ossuaries, and sacred cemeteries, serving as caretakers, mourners, or interpreters of the dead. Their communities value restraint, remembrance, and the belief that death is not to be feared so much as listened to"});

        register_lineage({"Madness-Touched Human", "Humanoid (Mutated)", 20,
            {"Unstable Mutation: Advantage on any check, then disadvantage on next two. Nat 20 grants monster ability.",
             "Fractured Mind: Resistance to psychic. Take insanity levels to lower critical hit required roll."},
            {"Babel", "Choice (+1 random)"},
            "Madness-Touched Humans bear visible signs of mental and magical fracture, with twitching expressions, mismatched features, or eyes that seem to focus on things no one else can perceive. Their presence is erratic and unsettling, as though part of them is always reacting to a world slightly different from the one around them.",
            "Madness-Touched culture is fragmented, unpredictable, and often formed in the margins of other societies rather than in unified nations of their own. Some gather in strange enclaves where instability is normalized and visionary madness is treated as revelation, while others wander alone, feared by those who do not understand them. Their existence is shaped by survival, mutation, and the dangerous possibility that fractured minds sometimes perceive truths others cannot bear"});

        // --- The Infernal Machine ---
        register_lineage({"Candlites", "Humanoid (Elemental)", 20,
            {"Luminous Soul: Shed 10 ft bright / 10 ft dim light. Extinguish/reignite as free action.",
             "Waxen Form: For 3 AP, teleport 30ft by melting and reforming."},
            {"Babel", "Ignan"},
            "Candlites are soft-glowing humanoids with waxen skin, flame-lit eyes, and bodies that seem half-solid and half-molten when viewed too closely. Their features soften and sharpen with the flicker of their inner fire, making them appear both comforting and deeply unnatural.",
            "Candlite culture centers on light, sacrifice, and the fragile persistence of warmth in terrible places. Their communities often form around shared flames, rituals of renewal, and solemn ceremonies where candles symbolize both life and its inevitable consumption. They value vigilance, devotion, and the belief that even a small light can remain defiant against overwhelming darkness"});

        register_lineage({"Flenskin", "Humanoid (Aberration/Exposed)", 20,
            {"Agonized Form: Attacker within 100 ft take 1 psychic damage.",
             "Pain Made Flesh: Once per long rest, delay all pain/damage/conditions for 1 minute."},
            {"Babel", "Paincant"},
            "Flenskin are horrifying humanoids whose exposed musculature, nerves, and slick raw tissue are somehow sustained without death. Their bodies seem trapped in a state of perpetual agony, every movement taut and unnatural, as though pain itself has taken living form.",
            "Flenskin culture is shaped by suffering, endurance, and the normalization of torment. Their communities, when they exist, are grim and intense, bound together by mutual understanding of pain that few others could survive. They prize resilience above all else, and many among them believe that suffering strips away illusion, leaving only truth, will, and what a being is truly made of"});

        register_lineage({"Hellforged", "Construct (Infernal)", 20,
            {"Infernal Stare: Once per long rest, creature within 5ft take 1d4 fire/turn for 1 minute.",
             "Demonic Alloy: Resistance to fire and cold. Advantage vs environmental heat."},
            {"Babel", "Infernic"},
            "Hellforged are brutal construct beings built from blackened infernal metal, glowing seams, and furnace-like cores that pulse with captured fire. Their forms are heavy and imposing, marked by chains, horns, or angular plating that evokes both machine and demon.",
            "Hellforged culture is defined by hierarchy, industry, and the weaponization of purpose. Many were created for labor, war, or guardianship within infernal systems that grind endlessly onward. Among their own kind, strength, obedience, and durability are deeply valued, though some Hellforged develop a fierce sense of individuality born from surviving the very systems that forged them"});

        register_lineage({"Obsidian Seraph", "Celestial (Corrupted)", 20,
            {"Infernal Smite: Once per short rest, +2d6 fire/radiant for 10 min. Consumes wings.",
             "Cracked Resilience: Resistance fire/radiant/necrotic. Damage taken empowers next attack (+1d4)."},
            {"Babel", "Celestine"},
            "Obsidian Seraphs are fallen celestial beings with dark glasslike wings, fractured halos, and bodies veined with light trapped beneath volcanic black surfaces. Their beauty is still unmistakable, but it is scarred, corrupted, and sharpened into something more terrible than holy.",
            "Obsidian Seraph culture is shaped by ruin, zeal, and the memory of grace twisted by infernal influence. Some see themselves as tragic remnants of something divine, while others embrace their corruption as a harsher and more honest form of power. Their communities, when they exist, are often rigid, dramatic, and driven by ideas of judgment, sacrifice, and transformation through fire"});

        register_lineage({"Scourling Human", "Humanoid (Demonic Spawn)", 20,
            {"Whip Lash: For 3 AP, 15 ft spectral lash pulls creature (DC 10+DIV Speed save).",
             "Fury of the Marked: When below 50% HP, deal extra damage equal to missing HP on melee."},
            {"Babel", "Infernic"},
            "Scourling Humans are marked by infernal lineage through horns, burning eyes, branded flesh, or shadowed veins that pulse when anger rises. Their appearance carries a raw and dangerous intensity, as though violence sits just beneath the skin waiting for permission to surface.",
            "Scourling culture is forged in struggle, aggression, and the constant pressure of living under infernal marks that set them apart from others. Some form brutal, close-knit bands where strength and defiance are celebrated, while others try to master the rage within through discipline or ritual. Across their many communities, one truth endures: Scourlings are taught early that pain can be turned outward and survival often belongs to the one willing to strike hardest"});

                // --- Titan’s Lament ---
        register_lineage({"Ashenborn", "Humanoid (Cursed Flame)", 20,
            {"Cursed Spark: Once per short rest, +1d4 fire damage to attacks for 1 minute.",
             "Burnt Offering: Regain 2 SP when reduced to 0 HP. Death is delayed by 1 round."},
            {"Babel", "Ignan"},
            "Ashenborn are soot-marked humanoids whose skin bears the look of something once burned and never fully extinguished. Faint embers glow in their cracks and scars, and their eyes often burn with a low, cursed fire that never seems to go completely dark.",
            "Ashenborn culture is shaped by endurance, sacrifice, and the belief that suffering can become strength if survived long enough. Their communities often gather in harsh volcanic lands and ruin-scarred strongholds where fire is treated as both burden and inheritance. They value resilience, grim devotion, and the refusal to let ruin be the final word in a life touched by flame"});

        register_lineage({"Sandstrider Human", "Humanoid", 20,
            {"Desert Walker: Ignore sand terrain. Once per long rest, 10 ft sand cloud (disadvantage).",
             "Heat Endurance: Advantage vs heat exhaustion. Twice as long without water."},
            {"Babel", "Terran"},
            "Sandstrider Humans are lean, sun-scarred wanderers with weathered skin, sharp eyes, and a gait shaped by long travel across brutal open lands. Their clothing is often layered for survival, and even at rest they carry the alert stillness of those accustomed to harsh horizons.",
            "Sandstrider culture is built on mobility, survival, and practical wisdom earned beneath relentless suns. Their communities are often caravan-based or spread across isolated desert routes, with traditions centered on navigation, resourcefulness, and shared endurance. They value self-reliance, hospitality among travelers, and the hard-earned knowledge required to cross places that kill the unprepared"});

        register_lineage({"Taurin", "Humanoid (Beast)", 20,
            {"Gore: Vitality times per short rest, 1d6 horn attack as free action.",
             "Stubborn Will: Once per short rest, reroll failed save vs move/prone."},
            {"Babel", "Tauric"},
            "Taurin are broad, horned humanoids with powerful frames, heavy muscles, and the unmistakable presence of creatures built to hold their ground. Their features blend mortal intelligence with the raw force of great bulls, giving them an appearance both noble and formidable.",
            "Taurin culture values strength, resolve, and the dignity of meeting hardship head-on. Their communities often center on clan loyalty, physical contests, and traditions of proving oneself through labor, battle, or service. Among the Taurin, stubbornness is not seen as a flaw but as a virtue, a sign that one will not easily be broken by fear, force, or fate"});

        register_lineage({"Ursari", "Humanoid (Beast)", 20,
            {"Mighty Build: Count as size larger for carry/grapple. Wield heavy weapons in one hand.",
             "Hibernate: Once per long rest, fully heal and gain bonus HP (unconscious 1 min)."},
            {"Babel", "Ursan"},
            "Ursari are massive, bear-like humanoids covered in thick fur, with broad shoulders, heavy limbs, and deep-set eyes that suggest both calm wisdom and terrifying strength. Their presence is imposing even in silence, and when roused they move with overwhelming power.",
            "Ursari culture is rooted in endurance, kinship, and a deep respect for cycles of rest, survival, and violence. Their communities tend to be tight-knit and protective, valuing patience and restraint until action becomes necessary. Among them, great strength is expected to be guided by discipline, and those who protect their people through hardship are held in the highest regard"});

        register_lineage({"Volcant", "Humanoid (Elemental)", 20,
            {"Lava Burst: Reaction deal 1d4 fire to attacker. Spend AP to increase damage.",
             "Molten Core: Resistance fire/cold. Walk across molten surfaces for 1 min."},
            {"Babel", "Ignan"},
            "Volcants are elemental humanoids with skin like dark stone split by glowing seams of magma, their bodies radiating heat and pressure like living vents of the earth. Their movements are heavy and deliberate, carrying the feeling of something geological forced into mortal shape.",
            "Volcant culture is shaped by power, pressure, and the harsh discipline of surviving in lands where fire constantly threatens to consume everything. Their communities are often built near lava flows, volcanic ridges, or heat-scarred caverns where endurance is a daily necessity. They value inner strength, emotional control, and the ability to contain destructive force until the exact moment it must be released"});

        // --- The Mortal Arena ---
        register_lineage({"Emberkin", "Humanoid", 20,
            {"Blazeblood: Resistance fire. Spend AP to raise area temperature. +1d4 fire to melee.",
             "Soot Sight: See through smoke/fog. Once per long rest, 10 ft smoke cloud centered on you."},
            {"Babel", "Ignan"},
            "Emberkin are fiery-featured humanoids with warm-toned skin, glowing eyes, and hair that often resembles smoke, sparks, or banked flame. Their bodies carry a constant sense of heat, and their presence feels like standing too near a forge that never truly cools.",
            "Emberkin culture values passion, intensity, and the ability to thrive under pressure. In the Mortal Arena, they are often drawn to spectacle, challenge, and feats that test both will and body before an audience. Their communities prize courage, bold self-expression, and the belief that a life worth living should burn brightly enough to be remembered"});

        register_lineage({"Saurian", "Humanoid (Reptile)", 20,
            {"Tail Lash: Reaction deal 1d4 bludgeoning and push attacker 5 ft.",
             "Scaled Resilience: Resistance fire/cold. Permanent +1 AC. Reaction reduce damage 1d4+VIT."},
            {"Babel", "Draconic"},
            "Saurians are scaled reptilian humanoids with heavy tails, sharp features, and bodies built for endurance and combat. Their hides range from rough and stony to sleek and plated, and their movements carry a coiled physical confidence that makes them seem dangerous even at rest.",
            "Saurian culture is defined by resilience, martial discipline, and the belief that survival belongs to those who adapt without breaking. Their communities often revolve around strength, hierarchy, and the proving of skill through combat or harsh trials. They value toughness, strategic patience, and the ability to remain dangerous no matter what punishment they endure"});

        register_lineage({"Stormclad", "Humanoid (Lightning/Air)", 20,
            {"Shock Pulse: For 1 SP, 3d6 lightning in 10 ft radius (DC 10+DIV VIT save).",
             "Arc Conductor: Resistance lightning/thunder. Fly at regular speed during storms."},
            {"Babel", "Thundric"},
            "Stormclad are striking humanoids whose hair lifts with static, whose eyes flash like stormlight, and whose skin often bears faint branching patterns like lightning scars. The air around them crackles subtly, and in moments of emotion they seem as though they might split open into weather.",
            "Stormclad culture revolves around force, motion, and the reverence of storms as both danger and revelation. Their communities often gather in high places, open plains, or exposed lands where sky and violence meet without obstruction. They value boldness, momentum, and the ability to channel chaos into action rather than being consumed by it"});

        register_lineage({"Sunderborn Human", "Humanoid (Butcher’s Lineage)", 20,
            {"Blood Frenzy: Enemy to 0 HP grants extra attack with advantage.",
             "Sanguine Immortality: Death Denied (spend SP to heal), Limb Regrowth (2 SP), Hibernation (SP per day)."},
            {"Babel", "Orc"},
            "Sunderborn Humans are brutal-looking people marked by heavy scarring, dense musculature, and an unsettling vitality that makes them seem difficult to kill by ordinary means. Their bodies recover from harm with frightening persistence, and many bear the look of warriors who have survived far beyond what should have ended them.",
            "Sunderborn culture is built around violence, survival, and the belief that flesh is meant to be broken and remade stronger. In the Mortal Arena and beyond, they are often associated with butchery, warfare, and blood-soaked forms of endurance that others find horrifying. Their communities respect ferocity, pain tolerance, and the refusal to die when death has already made its claim"});

        // --- Vulcan Valley ---
        register_lineage({"Ashrot Human", "Humanoid (Burned Wraith)", 20,
            {"Smoldering Aura: Basic action toggle 1 fire damage to adjacent enemies. Boost with SP.",
             "Sootskin: Immune to smoke vision impairment and suffocation from smoke/ash."},
            {"Babel", "Ignan"},
            "Ashrot Humans appear as fire-scarred survivors whose skin is gray with soot, whose features look half-consumed by old burns, and whose bodies carry the eerie stillness of something that should have perished but did not. Faint embers and drifting ash often cling to them as though the fire never truly left.",
            "Ashrot culture is shaped by catastrophe, survival, and an intimate familiarity with destruction. Their communities are often found in fire-ravaged settlements, volcanic fringes, or places others abandoned after disaster. They value grim perseverance, mutual dependence, and the understanding that those who keep living after devastation are changed in ways the untouched can never fully understand"});

        register_lineage({"Cindervolk", "Humanoid", 20,
            {"Ember Touch: Resistance fire. Ignite flammable small objects as free action.",
             "Smoldering Glare: Once per long rest, 10 ft radius sheds light and deals 1d4 fire/turn."},
            {"Babel", "Ignan"},
            "Cindervolk are dark-featured humanoids touched by ember and smoke, their skin often warm-toned or coal-dusted and their eyes carrying a persistent furnace glow. Heat follows them subtly, and even their quietest expressions suggest a flame waiting just beneath the surface.",
            "Cindervolk culture centers on fire as tool, threat, and symbol of identity. Their communities often form around forges, lava-fed settlements, or heat-blasted enclaves where endurance and creation exist side by side. They value self-mastery, industriousness, and the ability to carry destructive power without letting it consume the things worth preserving"});

        register_lineage({"Drakari", "Humanoid (Dragon)", 20,
            {"Draconic Awakening: Once per long rest, partial transform (large size, wings, +1d4/level elemental melee).",
             "Breath Weapon: For 3 AP, 15 ft cone elemental damage (2d6+level, 4d6 if awakened)."},
            {"Babel", "Draconic"},
            "Drakari are dragon-blooded humanoids with scaled skin, predatory eyes, and features that hint at the immense creatures whose essence runs through them. Horns, claws, heavy tails, or vestigial wing structures are common among them, and even in humanoid form they carry the unmistakable majesty and threat of draconic power.",
            "Drakari culture is shaped by legacy, dominance, and the constant tension between mortal life and draconic inheritance. Their communities often emphasize pride, achievement, and the careful cultivation of inner power, with lineage and personal strength both holding great significance. Among the Drakari, awakening one’s deeper nature is seen not merely as a gift, but as a test of whether one is worthy to bear such blood"});

        register_lineage({"Obsidian", "Humanoid", 20,
            {"Shard Skin: Melee bludgeoning damage reflects 1d4 thunder damage to attacker.",
             "Magma Blood: Resistance elemental damage. Heal 1d4 when taking elemental damage."},
            {"Babel", "Ignan"},
            "Obsidians are sleek, dark-bodied humanoids whose skin resembles polished volcanic glass, smooth in some places and edged like broken stone in others. Light catches across them in sharp reflections, and beneath the surface there often seems to be a slow glow, as if heat still lives trapped inside.",
            "Obsidian culture is defined by hardness, beauty, and the dangerous value of controlled force. Their communities often rise in volcanic lands and glass-scarred terrain where elegance and lethality are treated as compatible virtues. They value composure, resilience, and the belief that pressure and heat do not merely destroy, but can refine a being into something sharper and stronger"});

        register_lineage({"Scornshard", "Construct (Shardbound)", 20,
            {"Fracture Burst: Melee weapon hit releases burst (DC 10+VIT Speed save vs blind).",
             "Crackling Edge: Unarmed strikes are slashing and deal +Speed damage once per turn."},
            {"Babel", "Crystaltongue"},
            "Scornshards are jagged construct beings assembled from bound crystal fragments, splintered stone, and sharp-edged magical seams that hold their bodies together. Their forms look unstable and dangerous, as though one violent impact might either shatter them or unleash something worse.",
            "Scornshard culture is built around fracture, anger, and the use of brokenness as strength rather than weakness. Many emerge from violent places where destruction and magical pressure have fused ruin into purpose, and among their own kind, scars and cracks are often worn with pride. They value ferocity, speed, and the conviction that even something shattered can still cut deeper than what was never broken"});

                // --- The Isles ---
        register_lineage({"Abyssari", "Humanoid (Aquatic)", 20,
            {"Bioluminescent Veins: Glow 10 ft. Light pulse reveals invisible/hidden for 1 min.",
             "Pressure Hardened: Resistance cold/crushing. Immune to pressure effects."},
            {"Babel", "Deepcant"},
            "Abyssari are deep-water humanoids with dark, smooth skin traced by bioluminescent veins that pulse softly through their bodies like living constellations. Their eyes are large and reflective, and their movements carry the calm precision of creatures perfectly adapted to the crushing silence of the deep.",
            "Abyssari culture is shaped by the immense pressures and alien beauty of the ocean depths. Their communities are often solemn, disciplined, and built around survival in environments that would destroy most other peoples. They value control, silence, and the ability to endure what others cannot, treating the deep not as a hostile place, but as a proving ground that shapes strength and identity"});

        register_lineage({"Mireling", "Humanoid", 20,
            {"Slippery: Advantage vs grapples/restraints. Once per long rest escape as free action.",
             "Swamp Sense: Hold breath 1 hr. Advantage on Survival in swamp/marsh."},
            {"Babel", "Mirecant"},
            "Mirelings are slick-skinned, marsh-adapted humanoids with webbed digits, damp hair, and features softened by life in wetlands and shallow waters. Their bodies move with an easy fluidity, and their presence often seems as much a part of the swamp as the reeds and mud around them.",
            "Mireling culture is rooted in patience, adaptation, and close familiarity with marshland life. Their communities are often woven into swamps, bogs, and reed-choked waterways where outsiders quickly lose their bearings. They value practical knowledge, environmental awareness, and the quiet resilience needed to thrive in places where the land itself seems reluctant to be crossed"});

        register_lineage({"Moonkin", "Humanoid", 20,
            {"Lunar Blessing: +1d6 radiant in moonlight. Lunar Radiance emits 10 ft light pulse.",
             "Lunar Radiance: Allies gain +1 vs fear/charm while in your light."},
            {"Babel", "Elvish"},
            "Moonkin are pale, luminous humanoids whose features seem touched by silver light, with eyes that gleam like moonlit water and skin that often carries a soft nocturnal glow. Their presence is serene and slightly distant, as if part of them is always listening to something far above the world.",
            "Moonkin culture is shaped by reverence for cycles, quiet guidance, and the symbolism of moonlight as protection in darkness. Their communities often gather in places of open sky, tide, and ritual stillness where the phases of the moon govern both ceremony and daily life. They value calm, intuition, and the belief that gentle light can carry strength where harsh brilliance cannot"});

        register_lineage({"Tiderunner Human", "Humanoid", 20,
            {"Wave Rider: Two move actions in water for cost of 1. Breathe in saltwater.",
             "Saltborn: Immunity to cold. 3 AP exhale cone of freezing brine (2d6 cold + slow)."},
            {"Babel", "Aquan"},
            "Tiderunner Humans are hardy coastal and ocean-going people with salt-toughened skin, powerful limbs, and features shaped by relentless wind, surf, and spray. Their movements are swift and confident in water, and many carry the weathered look of those who trust the sea more than the land.",
            "Tiderunner culture is built around mobility, seafaring, and an intimate relationship with tides, storms, and saltwater survival. Their communities often center on ships, harbors, reefs, and floating settlements where skill in water is essential to both trade and life. They value adaptability, endurance, and the ability to move with dangerous currents rather than wasting strength fighting them"});

        // --- The Depths of Denorim ---
        register_lineage({"Driftwood Woken", "Construct (Water/Nature)", 20,
            {"Ebb and Flow: Move 10 ft without opportunity (Speed times/LR).",
             "Saltsoaked Form: Resistance fire/cold. Breathe in saltwater without issues."},
            {"Babel", "Aquan"},
            "Driftwood Woken are construct beings formed from waterlogged timber, coral growth, kelp binding, and sea-worn fragments of once-lost vessels. Their bodies creak and sway like old ships in the current, yet move with surprising grace through both sea and shore.",
            "Driftwood Woken culture is shaped by salvage, memory, and the strange second life granted to what the sea refuses to surrender. Their communities often gather around wreck sites, reefs, and drowned ruins where fragments of the past are reclaimed into new purpose. They value resilience, transformation, and the belief that even broken things may awaken again with meaning"});

        register_lineage({"Fathomari", "Humanoid", 20,
            {"Amphibious: Breathe air/water. Resistance cold. Put out fires within 15ft.",
             "Deep Sight: See in murky water or magical darkness out to 60 ft."},
            {"Babel", "Aquan"},
            "Fathomari are sleek aquatic humanoids with smooth skin, dark reflective eyes, and graceful bodies built for movement through deep and uncertain waters. Their features carry an elegant austerity, and their gaze often feels as though it has measured distances and darkness most surface dwellers cannot imagine.",
            "Fathomari culture revolves around navigation, restraint, and mastery of environments where visibility and certainty are both limited. Their communities are often found in submerged halls, trench settlements, and deepwater passages where survival depends on coordination and awareness. They value poise, practical wisdom, and the ability to remain calm where lesser minds would panic"});

        register_lineage({"Hydrakari", "Humanoid (Aquatic, Reptile)", 20,
            {"Hydra’s Resilience: Reduce damage 1d6+VIT once/SR. Negate attack by sacrificing limb (1/LR).",
             "Amphibious: Breathe air/water. Resistance cold."},
            {"Babel", "Aquan"},
            "Hydrakari are powerful reptilian aquatic humanoids with scaled hides, predatory features, and regenerative flesh that gives them an unsettling impression of relentless vitality. Their bodies are built for violence and endurance, and even grievous harm rarely seems final for long.",
            "Hydrakari culture values survival, dominance, and the ruthless practicality demanded by dangerous underwater ecosystems. Their communities often form around strength-based hierarchies, territorial defense, and the ability to recover from hardship faster than rival peoples. Among them, resilience is not merely admired, but treated as proof of worth and fitness to endure the crushing realities of the deep"});

        register_lineage({"Kelpheart Human", "Humanoid (Plant, Aquatic)", 20,
            {"Tidebind: For 3 AP, entangle creature within 10 ft (DC 10+STR Strength save).",
             "Ocean’s Embrace: Submerged in saltwater heals 1 HP/turn. Breathe saltwater only."},
            {"Babel", "Aquan"},
            "Kelpheart Humans are sea-grown people whose bodies bear signs of plant and oceanic adaptation, with hair like drifting fronds, skin tinted by green or blue undertones, and subtle textures resembling seaweed or tidal growth. In water they seem especially at home, as though the sea itself is reluctant to let them weaken.",
            "Kelpheart culture is rooted in symbiosis with the ocean and the patient, clinging endurance of marine plant life. Their communities often grow in reefs, tidal gardens, and submerged groves where living structures intertwine with settlement and ritual. They value healing, persistence, and the understanding that strength can come through binding, sheltering, and growing together rather than through force alone"});

        register_lineage({"Trenchborn", "Humanoid (Aberration)", 20,
            {"Abyssal Mutation: Reroll failed mind-save. Reflection effect on success.",
             "Darkwater Adaptation: 60 ft darkvision. Breathe air/water. Advantage on Perception submerged."},
            {"Babel", "Abyssal"},
            "Trenchborn are unsettling humanoids warped by the deepest waters, their bodies marked by alien asymmetry, unnatural eyes, and subtle features that suggest something inhuman has adapted too well to the abyss. Their presence carries a sense of wrongness, as though they have spent too long where thought and pressure both begin to distort.",
            "Trenchborn culture is shaped by mutation, survival, and prolonged contact with the unknowable regions beneath the sea. Their communities are often secretive, isolated, and governed by strange customs that reflect both deep adaptation and aberrant influence. They value awareness, caution, and the willingness to change in order to survive places where stable identity can become a liability"});

        // --- Moroboros ---
        register_lineage({"Cloudling", "Humanoid (Elemental)", 20,
            {"Float: Hover 10 ft off ground (half speed). Fly at full speed for -3 Max AP cost.",
             "Mist Form: Once per short rest, become intangible for 1 minute (1 SP after)."},
            {"Babel", "Auran"},
            "Cloudlings are airy, light-boned humanoids with soft, pale features and bodies that seem half-formed from mist and moving sky. Their steps are rarely quite grounded, and their outlines often blur at the edges like something between a person and weather.",
            "Cloudling culture is shaped by freedom, transience, and the acceptance that nothing remains in one form forever. Their communities are often loose, mobile, and difficult to pin down, gathering in high places, drifting enclaves, or regions where air and atmosphere feel unstable. They value lightness, flexibility, and the ability to change course without losing themselves entirely"});

        register_lineage({"Rotborn Herald", "Humanoid (Plaguehost)", 20,
            {"Festering Aura: Adjacent enemies take -2 to healing received.",
             "Diseasebound: Immune to disease/poison. Unarmed attacks deal +1d4 poison damage."},
            {"Babel", "Plaguecant"},
            "Rotborn Heralds are sickly, decaying humanoids whose flesh carries visible signs of infection, corruption, and unnatural survival amid rot. Their presence is foul and unnerving, with weeping sores, pestilent breath, and the look of bodies that have become carriers of something much older and crueler than simple disease.",
            "Rotborn culture is built around endurance through corruption and the acceptance of plague as both burden and identity. Their communities are often feared enclaves where sickness is not merely survived, but ritualized, studied, and weaponized. They value hardiness, grim devotion, and the belief that those who endure contagion gain an ugly but undeniable form of power"});

        register_lineage({"Tidewoven", "Humanoid (Water)", 20,
            {"Surge Step: For 1 SP, double speed and ignore opportunity attacks until next turn.",
             "Deep lung: Breathe underwater. Advantage on swim checks."},
            {"Babel", "Aquan"},
            "Tidewoven are fluid-featured humanoids whose bodies seem shaped by currents, with smooth skin, flowing movements, and a natural grace that makes even stillness feel temporary. Their hair and garments often drift as though caught in unseen water, and they move with an effortless sense of momentum.",
            "Tidewoven culture is centered on motion, adaptability, and the belief that survival belongs to those who flow rather than break. Their communities often form along coasts, submerged passages, and shifting island routes where life is governed by water and timing. They value grace, responsiveness, and the wisdom of knowing when to yield and when to surge forward with full force"});

        register_lineage({"Venari", "Humanoid (Beast)", 20,
            {"Pack Instinct: Advantage on attack if ally is within 5 ft of target.",
             "Hunter’s Focus: Mark target for 1 hr (+1d4 Perception/Survival, +1d6 damage)."},
            {"Babel", "Venari"},
            "Venari are sharp-featured beastfolk hunters with keen eyes, agile bodies, and predatory instincts honed by generations of pursuit. Their movements are efficient and alert, and even in casual posture they seem ready to track, stalk, or strike.",
            "Venari culture is deeply rooted in the hunt, cooperation, and the disciplined use of instinct in dangerous lands. Their communities often operate in tightly bonded groups where shared purpose and coordinated action are essential to survival. They value focus, loyalty, and the ability to read terrain, prey, and rivals with a precision that turns patience into victory"});

        register_lineage({"Weirkin Human", "Humanoid", 20,
            {"Weird Resilience: Once per long rest, auto-succeed on save vs charm/fear/confuse.",
             "Eerie Insight: Advantage on Intellect checks involving magical or anomalous phenomena."},
            {"Babel", "Abyssal"},
            "Weirkin Humans are ordinary in outline but wrong in detail, with expressions that linger too long, eyes that seem to notice impossible things, and a subtle air of unreality that others struggle to explain. They look like people who have lived too long beside places where the world has forgotten how it is supposed to behave.",
            "Weirkin culture is shaped by close contact with anomalies, altered places, and truths that make ordinary minds recoil. Their communities are often practical and wary, having learned that the strange is not rare in Moroboros but foundational to life there. They value adaptability, perception, and the ability to keep functioning when reality itself becomes unreliable"});

        // --- Gloamfen Hollow ---
        register_lineage({"Bilecrawler", "Beast (Aberrant)", 20,
            {"Corrosive Slime: Ending turn in crawler's space deals 1d4 acid and -1 AC.",
             "Bile Sense: Locate and telepathically communicate with diseased/poisoned within 30 ft."},
            {"None", "Telepathic"},
            "Bilecrawlers are grotesque aberrant beasts slick with acidic mucus, their bodies bloated, many-limbed, and shaped for crawling through rot, bile, and living filth. Their presence is immediately nauseating, and the stench of chemical decay often reaches others long before the creature itself is seen.",
            "Bilecrawler behavior and social structure are shaped by contamination, predation, and proximity to sickness rather than anything resembling conventional civilization. They gather where decay pools thickest, surrounding disease, poison, and biological ruin with disturbing familiarity. To the extent they possess a shared culture at all, it is one of infestation, instinct, and the telepathic spread of hunger through corrupted environments"});

        register_lineage({"Huskdrone", "Undead (Mutated)", 20,
            {"Gas Vent: Explode on death (2d6 poison in 10 ft). Sacrifice HP to trigger manually.",
             "Obedient: Immune to charm/fear/possession. Max AP cost reduction spread to allies."},
            {"Babel", "Broken Babel"},
            "Huskdrones are rotting, mutated undead with swollen bodies, ruptured flesh, and internal sacs of poisonous gas that distort their silhouettes into something both pathetic and dangerous. They move with a grim, mechanical obedience, as though whatever will once lived in them has long since been replaced by function.",
            "Huskdrone existence is defined by servitude, corruption, and the loss of self beneath external control or total biological collapse. When gathered in numbers they form grim processions or clustered hordes directed by stronger intelligences or shared decay-born instincts. Their culture, if it can be called that, is one of obedience, contagion, and the reduction of identity to usefulness in a rotting system"});

        register_lineage({"Bloatfen Whisperer", "Humanoid (Aberrant Caster)", 20,
            {"Rot Voice: For 3 AP, 20 ft burst frightened until next turn (DC 14 Divinity save).",
             "Leech Hex: Once per turn, sap 1d6 HP from creature within 30 ft."},
            {"Babel", "Deepgut"},
            "Bloatfen Whisperers are swollen, marsh-haunted casters whose bodies carry the visible marks of rot, occult infection, and prolonged exposure to poisonous wetlands. Their voices seem to bubble up from somewhere too deep in the throat, carrying a wet and dreadful resonance that unsettles even before its magic takes hold.",
            "Bloatfen Whisperer culture is built around corruption, fear, and the weaponization of decay through word and ritual. Their communities are often hidden within the most diseased and alchemically warped parts of Gloamfen Hollow, where rot is treated as both teacher and power source. They value secrecy, endurance, and the ability to turn weakness, sickness, and revulsion into instruments of control"});

        register_lineage({"Filthlit Spawn", "Ooze (Sentient)", 20,
            {"Memory Echo: While active (-3 Max AP), mimic appearance/voice of creature seen for 1 min.",
             "Toxic Form: Immune poison/acid. Grapplers/touchers take 1d4 poison damage."},
            {"Babel", "Plaguecant (telepath)"},
            "Filthlit Spawn are sentient ooze-beings whose bodies ripple with foul color, drifting faces, and half-formed features stolen from things they have observed. Their forms are unstable and deeply unpleasant to behold, sloshing between personhood and slime with a mimicry that feels more invasive than convincing.",
            "Filthlit Spawn culture is fluid, parasitic, and shaped by memory theft, imitation, and survival in profoundly toxic environments. They often gather in polluted pools, refuse pits, and plague-soaked hollows where stable form matters less than cunning adaptation. They value flexibility, concealment, and the ability to become what is most useful in the moment, even if only for a little while"});

        register_lineage({"Hagborn Crone", "Humanoid (Fey Caster)", 20,
            {"Hex of Withering: For 2 AP, 20 ft burst disadvantage on attacks/checks (DC 10+DIV).",
             "Witch’s Draught: For 3 AP, sap 1d6 HP from creature. Share healing with other crones."},
            {"Babel", "Witchtongue"},
            "Hagborn Crones are eerie, weathered spellcasters whose features blend mortal age with fey malice, often marked by sharp smiles, long fingers, and eyes that seem to carry old bargains inside them. Their presence is unsettlingly deliberate, as if every word and gesture conceals a second intention.",
            "Hagborn culture revolves around covens, secret rites, and the weaving of power through curse, bargain, and shared occult practice. Their communities are often small, insular, and bound together by old loyalty, rivalry, and magical interdependence. They value cunning, inherited knowledge, and the slow accumulation of influence through fear, ritual, and patience"});

        // --- The Astral Tear ---
        register_lineage({"Aetherian", "Humanoid", 20,
            {"Ethereal Step: For 1 SP, become intangible until end of next turn as move action.",
             "Veiled Presence: Once per rest, advantage on Sneak for 1 minute."},
            {"Babel", "Aetheric"},
            "Aetherians are ethereal and slightly translucent, with a ghostly presence and features that seem to blur at the edges, as if not fully part of the material world. Their forms resemble living echoes of starlight, faintly luminous and threaded with swirling cosmic mist.",
            "Aetherian culture is defined by longing and detachment. Often feeling like outsiders, they form quiet, contemplative communities near places where worlds feel close, and are drawn to art, music, and philosophy centered on loss, memory, and meaning. They value subtlety, reflection, and the ability to endure life while never fully feeling anchored to it"});

        register_lineage({"Convergents", "Humanoid (Convergent)", 20,
            {"Adaptive Convergence: Mimic lineage appearance/traits upon contact. Persists until reset.",
             "Convergent Synthesis: For 1 SP/creature, integrate traits of all creatures touched this round."},
            {"Babel", "Choice"},
            "Convergents are an anomaly among lineages, born without inherent form or defining traits. In their natural state, they appear as smooth, mannequin-like humanoids with indistinct features, uniform skin, glassy eyes, and little or no hair, only fully changing through contact with others.",
            "Convergent culture does not exist in a unified sense, because they are cultural mirrors more than origin-bound peoples. Some deliberately limit contact to preserve continuity, while others seek constant interaction and become composites of many influences. They value adaptation, identity through experience, and the unsettling freedom of never being confined to a single inherited shape"});

        register_lineage({"Dreamer", "Humanoid", 20,
            {"Dreamwalk: Once per long rest, interact with creature's dreams (range 100 ft).",
             "Lucid Mind: Immune to magical sleep. Soul wanders 15 ft to stand guard while sleeping."},
            {"Babel", "Sylvan"},
            "Dreamers are ethereal beings with shifting pastel skin, nebula-like eyes, and forms that seem to blur at the edges as though half-remembered even while standing before you. Their presence carries a soft, distant unreality, like something halfway between a mortal and a lingering vision.",
            "Dreamer culture is one of introspection, wandering thought, and gentle melancholy. They are often drawn to reflection, art, sleep rituals, and the exploration of the mind as if it were a landscape of its own. Their communities value imagination, emotional subtlety, and the belief that dreams are not lesser than waking life, but another realm of truth to be carefully navigated"});

        register_lineage({"Riftborn Human", "Humanoid", 20,
            {"Phase Step: For 3 AP, move through 5 ft solid object (take force damage if ending inside).",
             "Flicker: Once per short rest, teleport 15 ft in addition to normal move action."},
            {"Babel", "Planar"},
            "Riftborn Humans are marked by subtle distortions in body and motion, with outlines that seem to jump, blur, or lag a half-second behind where they should be. Their eyes often carry the look of someone who has spent too long near tears in reality and learned to move with instability rather than fear it.",
            "Riftborn culture is shaped by proximity to planar fractures, spatial anomalies, and the constant need to adapt to places where matter and distance behave unpredictably. Their communities are often pragmatic and highly mobile, building habits and traditions around contingency rather than permanence. They value quick thinking, flexibility, and the ability to survive where the world itself has become unreliable"});

        register_lineage({"Shadewretch", "Humanoid (Voidshadow)", 20,
            {"Unseen Hunger: Regain 2 SP upon reducing sentient creature to 0 HP.",
             "Twilight Stalker: Climb in dim light. Silent glide + Shadowmeld reaction (intangible)."},
            {"Babel", "Voidtongue"},
            "Shadewretches are gaunt, shadow-cloaked humanoids whose forms seem thinned by darkness and hunger until they barely appear fully material. Their eyes glint like trapped voidlight, and their movements are unnervingly silent, as though even sound resents revealing where they are.",
            "Shadewretch culture is shaped by predation, concealment, and a grim intimacy with dim places where life and shadow blur together. Their communities are often fragmented, hidden, and built around survival through stealth, ambush, and the careful management of need. They value silence, patience, and the belief that hunger, if mastered, becomes a source of terrible strength"});

        register_lineage({"Umbrawyrm", "Humanoid (Dragon/Shadow)", 20,
            {"Void Step: For 1 SP, teleport up to 30 ft into dim light or darkness.",
             "Shadow Coil: Advantage on Sneak in darkness. 30 ft magical darkvision."},
            {"Babel", "Draconic"},
            "Umbrawyrms are draconic shadow-blooded humanoids with sleek dark scales, sharp features, and eyes that gleam like hidden embers beneath night. Their bodies carry the majesty of dragon lineage, but wrapped in the quiet menace of darkness and concealment.",
            "Umbrawyrm culture combines draconic pride with shadow-bound pragmatism, producing communities that value both personal power and the strategic use of secrecy. They are often found in regions where darkness is not merely absence of light but a presence with weight and meaning. They prize control, precision, and the disciplined use of fear as both shield and weapon"});

        // --- L.I.T.O. ---
        register_lineage({"Corrupted Wyrmblood", "Humanoid (Draconic/Cursed)", 20,
            {"Corrupt Breath: For 3 AP, 15 ft cone 2d4 necrotic + level (DC 10+VIT Vitality save).",
             "Dark Lineage: Resistance to necrotic. Reduce creature to 0 HP deals 1d4 necrotic to another within 5ft."},
            {"Babel", "Draconic"},
            "Corrupted Wyrmblood are draconic humanoids whose lineage has been twisted by curse, rot, or void-tainted influence, leaving their scales darkened, their breath foul with corrupted power, and their features marked by a regal ruin. They look like descendants of greatness dragged through something that wanted to spoil it.",
            "Corrupted Wyrmblood culture is shaped by inheritance, corruption, and the struggle to define oneself under the weight of tainted legacy. Some communities cling to remnants of old draconic pride, while others embrace their altered nature as proof that power survives even through ruin. They value endurance, strength of blood, and the refusal to disappear beneath the stain of what they have become"});

        register_lineage({"Hollowroot", "Humanoid (Plant)", 20,
            {"Rooted: Advantage on saves vs move/prone.",
             "Sap Healing: Once per short rest, heal 1d8+level and remove one condition."},
            {"Babel", "Sylvan"},
            "Hollowroots are plantlike humanoids with bark-textured skin, hollowed interiors, and bodies threaded with living sap and root networks. Though their forms can appear weathered or partially hollow, there is a quiet vitality within them that speaks of stubborn life rather than weakness.",
            "Hollowroot culture is grounded in persistence, renewal, and the slow endurance of living systems that survive by going deep. Their communities often grow around ruined places, dead forests, or void-touched soil where other life has struggled to remain. They value stability, healing, and the belief that even when something is hollowed out, new life may still take root within it"});

        register_lineage({"Nihilian", "Humanoid (Voidborn)", 20,
            {"Entropy Touch: Basic action touch deals 1d4 necrotic and -1d4 to their next attack.",
             "Unravel: Once per long rest, touch deals 1d6 necrotic/turn + prevents healing (DC 10+DIV VIT save)."},
            {"Babel", "Voidtongue"},
            "Nihilians are austere voidborn humanoids whose bodies seem stripped down to stark form and chilling presence, with muted features, darkened eyes, and an aura of slow dissolution that makes others feel less certain of their own solidity. They carry themselves with the calm of beings who have accepted that all things eventually come apart.",
            "Nihilian culture is defined by detachment, entropy, and the contemplation of endings as a natural truth rather than a tragedy. Their communities are often sparse, disciplined, and philosophical, valuing restraint over excess and understanding over comfort. They believe that unraveling is not always destruction, but sometimes the clearing away of illusion, weakness, or false permanence"});

        register_lineage({"Oblivari Human", "Humanoid (Void-Essence)", 20,
            {"Mind Bleed: Once per long rest, failed Intellect save takes 2d6 psychic and forgets allies for 1 min.",
             "Null Mind: Immune to scrying/surveillance. Extend protection to touched ally for 1 hr."},
            {"Babel", "Nullscript"},
            "Oblivari Humans appear strangely muted, with pale skin and distant eyes that seem to look through the world rather than at it. Their presence dulls attention and memory, leaving others uncertain whether they truly saw them at all.",
            "Oblivari culture centers on mental discipline and the control of thought. Their communities practice strict traditions of memory keeping and meditation to resist the creeping pull of the Void within them. Knowledge is treated with caution, and many Oblivari believe forgetting can be just as powerful as remembering"});

        register_lineage({"Sludgeling", "Humanoid (Ooze)", 20,
            {"Amorphous Form: Squeeze through 6-inch gaps. Reaction to split into two identical forms when slashed.",
             "Toxic Seep: For 3 AP, exude 5 ft toxic aura for 1 minute (DC 10+VIT VIT save resists)."},
            {"Babel", "Mirecant"},
            "Sludgelings are viscous humanoid masses of shifting ooze whose forms constantly ripple and reform. Faces emerge briefly from their surface before dissolving again into thick, sluggish fluid.",
            "Sludgeling communities form in damp caverns, marshlands, and alchemical runoff zones where their bodies thrive. Their culture is flexible and pragmatic, valuing survival and adaptation above rigid structure. Identity among them is fluid, and individuals often change roles within their society as easily as their bodies reshape"});

        // --- The West End Gullet ---
        register_lineage({"Carrionari", "Humanoid (Beast, Necrotic)", 20,
            {"Death-Eater’s Memory: Absorb memories from touched corpse (1/LR). Witness last 6s.",
             "Wings of the Forgotten: Glide at foot speed. For 3 AP fly at foot speed for 1 round."},
            {"Babel", "Necril"},
            "Carrionari are gaunt, vulturelike humanoids with ragged wings and hollow eyes that gleam with eerie intelligence. Their sharp features and hooked beaks give them the unsettling look of creatures that thrive where death lingers.",
            "Carrionari culture treats death as a source of knowledge rather than tragedy. Their communities gather near gravefields and battle sites, believing the memories of the dead hold truths lost to the living. Ritual consumption of those memories is considered sacred, allowing the fallen to continue shaping the world through those who remember them"});

        register_lineage({"Disjointed Hounds", "Beast (Warped Predator)", 20,
            {"Shifting Form: Action switch to beast mode (+10 ft speed, 40 ft leap).",
             "Warped Bite: On hit, target must VIT save or disoriented (disadvantage all checks for 1 min)."},
            {"Babel", "Understand-only"},
            "Disjointed Hounds are warped humanoid predators whose limbs bend and reset at impossible angles. Their bodies move with unsettling elasticity, joints snapping back into place as if reality itself struggles to contain them.",
            "Disjointed Hounds exist in loose hunting packs that roam unstable regions of Rimvale where reality has fractured. Their culture is instinct-driven and predatory, valuing strength, speed, and coordinated pursuit. Communication among them is often more gesture and posture than language, forming a brutal but effective social structure built around the hunt"});

        register_lineage({"Lost", "Undead (Temporal Echo)", 20,
            {"Temporal Flicker: Once per long rest, become intangible for 1 minute.",
             "Haunting Wail: For 3 AP, 15 ft dissonant cry (INT check or stunned until next turn)."},
            {"Babel", "Echoes"},
            "The Lost appear as translucent figures whose forms flicker between moments in time. Their bodies seem slightly out of sync with reality, leaving faint afterimages trailing behind their movements.",
            "The Lost are remnants of lives that slipped between moments during catastrophic magical events. Their communities are fragile and melancholic, gathering in quiet ruins or forgotten places where time feels thin. They often spend their existence searching for fragments of their past lives, hoping to anchor themselves once more in the present"});

        register_lineage({"Gullet Mimes", "Humanoid (Cursed Performer)", 20,
            {"Mirror Move: For 3 AP reaction, copy physical action within 30 ft.",
             "Silent Scream: Once per long rest, force target to fail speech/casting for 1 min (DC 10+DIV INT check)."},
            {"Babel", "Gesture"},
            "Gullet Mimes appear as pale performers clad in exaggerated expressions painted across their faces. Their movements are unnaturally precise, every gesture sharp and deliberate as if acting out an unseen script.",
            "Gullet Mime culture is rooted in performance, imitation, and the manipulation of perception. Words are rarely spoken among them; instead, entire conversations unfold through gesture and expression. Within their strange communities, the ability to perfectly mirror another’s actions is seen as both an art form and a mark of deep understanding"});

        register_lineage({"Parallax Watchers", "Aberration (Perceptual Warden)", 20,
            {"Reality Slip: Once per short rest, teleport 30 ft to dim light/shadow.",
             "Unnerving Gaze: For 3 AP, 30 ft range target becomes frightened for 1 min (DC 10+DIV INT check)."},
            {"Babel", "Whispercant"},
            "Parallax Watchers possess elongated forms and eyes that reflect impossible angles, as though viewing the world from several perspectives at once. Their gaze carries a disorienting intensity that makes others feel watched from directions that do not exist.",
            "Parallax Watchers serve as silent wardens of unstable spaces where perception and reality begin to fracture. Their society revolves around observation and containment, carefully monitoring disturbances in the fabric of existence. To them, the world is not a single reality but a shifting set of overlapping possibilities that must be kept from collapsing into chaos"});

        // --- The Cradling Depths ---
        register_lineage({"Echo-Touched", "Humanoid (Echo-Touched)", 20,
            {"Resonant Form: Advantage vs magic. Once per short rest, mutate (4 SP effect) for 10 min.",
             "Divine Mimicry: Once per long rest, mimic one lineage trait from creature within 30 ft."},
            {"Babel", "Choice"},
            "Echo-Touched appear mostly human, yet faint distortions ripple across their form as if they exist slightly out of phase with reality. Their movements sometimes leave brief afterimages, and their voices can carry subtle harmonics of other possibilities.",
            "Echo-Touched culture is shaped by uncertainty and adaptation. Many believe they carry fragments of multiple possible selves, echoes of lives that might have been. Communities of Echo-Touched often encourage experimentation and self-discovery, viewing identity as something fluid rather than fixed"});

        register_lineage({"Lifeborne", "Humanoid (Abyssal)", 20,
            {"Vital Surge: Healing pool = 4 x Level. Basic action touch restores HP.",
             "Abyssal Glow: For 3 AP, 10 ft glow heals allies 1d6+DIV and enemies make DIV save or disadvantage."},
            {"Babel", "Deepcant"},
            "Lifeborne are beings infused with powerful biological vitality, their bodies marked by glowing veins and steady rhythmic pulses beneath the skin. Their presence radiates warmth and life force even in the crushing dark of the abyss.",
            "Lifeborne culture values preservation of life and biological harmony. Their communities often revolve around healing traditions, caretaking roles, and the study of living systems in hostile environments where life must be actively protected to endure. Among them, the ability to restore life is considered a sacred responsibility rather than a mere talent"});

                // --- Terminus Volarus ---
        register_lineage({"Lanternborn", "Humanoid", 20,
            {"Guiding Light: For 3 AP free action, grant ally within 30 ft advantage on save.",
             "Glow: Shed 10 ft bright light. Allies gain +1 AC (but you/they disadvantage on Sneak)."},
            {"Babel", "Celestial"},
            "Lanternborn have softly glowing skin and eyes, and their voices echo faintly like distant chimes heard through twilight. Their subtle radiance is soothing rather than harsh, giving them an otherworldly presence that makes them seem touched by some quiet celestial mystery.",
            "Lanternborn culture is shaped by reverence for the stars, ancestral memory, and the comforting power of inner light. Their communities are often contemplative and close-knit, gathering for storytelling, song, dream-sharing, and rituals of stargazing or lantern-light remembrance. They value wisdom, emotional depth, and the belief that the light within them is both inheritance and responsibility"});

        register_lineage({"Luminar Human", "Humanoid", 20,
            {"Radiant Resistance: Resistance radiant. +1 saves for allies in bright light. Beacon: absorb ally's fear.",
             "Beacon: Allies within 10 ft advantage vs fear. Reaction to take on ally's fear once/SR."},
            {"Babel", "Celestial"},
            "Luminar Humans are bright-featured people whose presence seems strengthened by illumination, with eyes that catch and hold light and expressions that carry an almost reassuring clarity. Many bear a steady, calming presence, as though they were meant to stand visible when others falter.",
            "Luminar culture values courage, protection, and the moral symbolism of standing as a light for others. Their communities often emphasize service, emotional steadiness, and shared strength in the face of fear or despair. They believe that light is not merely illumination, but a duty, and that those who can bear it should help carry others through darkness"});

        register_lineage({"Skysworn", "Humanoid", 20,
            {"Glide: Glide at foot speed. Land within 5ft after 20ft fall gives target disadvantage on attack.",
             "Keen Sight: Advantage Perception (sight). For 3 AP, detect invisible/illusory within 30 ft."},
            {"Babel", "Auran"},
            "Skysworn are lithe, high-featured humanoids with wind-worn faces, sharp eyes, and bodies that seem naturally balanced for height, motion, and open air. They move with the confidence of those accustomed to cliffs, heights, and long distances where a single misstep would mean death for others.",
            "Skysworn culture is shaped by elevation, vigilance, and reverence for the open sky as both challenge and calling. Their communities are often built in high places where broad sightlines and aerial awareness are essential to life. They value precision, perception, and the discipline of learning to trust the air without ever becoming careless in it"});

        register_lineage({"Starborn", "Humanoid", 20,
            {"Radiant Pulse: For 3 AP, 10 ft burst blinds (DC 10+VIT Vitality save).",
             "Cosmic Awareness: Advantage on checks about cosmos or navigation."},
            {"Babel", "Celestial"},
            "Starborn are luminous humanoids whose eyes gleam like distant constellations and whose skin often carries subtle flecks or glimmers like a night sky scattered across mortal flesh. Their presence feels strangely vast, as though part of them belongs more to the heavens than to the ground beneath their feet.",
            "Starborn culture is centered on celestial observation, destiny, and the reading of meaning in patterns beyond the mortal world. Their communities often value navigation, philosophy, and ritual tied to stars, cycles, and the vastness above. They believe that to understand the sky is to better understand one’s place in the world, and that light from great distance still has power when it arrives"});

        // --- The City of Eternal Light ---
        register_lineage({"Auroran", "Humanoid", 20,
            {"Light Step: Ignore natural light terrain. Free action 10 ft teleport to direct sunlight once/SR.",
             "Dawn's Blessing: Advantage vs blind. Once per long rest, immune to blind for 1 minute."},
            {"Babel", "Celestial"},
            "Aurorans are radiant humanoids whose features seem bathed in the first light of dawn, with warm luminous skin, bright eyes, and an ease of movement that makes sunlight feel like part of their natural element. Their presence carries an uplifting clarity, like a horizon just beginning to blaze.",
            "Auroran culture is defined by renewal, optimism, and the sacred symbolism of first light. Their communities often focus on ritual beginnings, healing, and the maintenance of hope in places where illumination never fully fades. They value resilience, clarity of purpose, and the belief that even after the longest darkness, something bright can still arrive"});

        register_lineage({"Lightbound", "Humanoid", 20,
            {"Radiant Ward: Reaction to radiant damage to heal half and gain resistance for 1 min.",
             "Flareburst: Once per short rest, melee hit deals +2d6 fire and blinds until end of next turn."},
            {"Babel", "Celestial"},
            "Lightbound are intense, radiant humanoids whose bodies seem closely fused with blazing power, their skin, eyes, and veins often carrying visible traces of contained brilliance. They appear like mortals bound tightly to something luminous and dangerous, as though light has become part armor and part blood.",
            "Lightbound culture revolves around endurance through brightness, channeling overwhelming force without being consumed by it. Their communities often esteem discipline, conviction, and the capacity to turn raw radiance into protection or righteous violence when needed. They believe light is not always gentle, and that brilliance can blind, burn, and defend with equal legitimacy"});

        register_lineage({"Runeborn Human", "Humanoid (Construct)", 20,
            {"Runic Surge: Once per long rest, add +1d4 to spell attack or save DC.",
             "Mystic Pulse: Once per short rest, runes flare granting allies within 10 ft bonus HP = Intellect."},
            {"Babel", "Runic"},
            "Runeborn Humans are people whose flesh or artificial framework bears carved, inked, or glowing runes that pulse with structured magical force. Their appearance suggests deliberate design rather than accident, with each symbol hinting at identity, function, or inherited arcane purpose.",
            "Runeborn culture is built around inscription, magical order, and the belief that meaning can be fixed into the world through symbols properly understood. Their communities often place great value on knowledge, precision, and the responsible use of codified power. Among them, runes are more than decoration or tool, they are memory, law, inheritance, and living structure"});

        register_lineage({"Zephyrkin", "Humanoid (Elemental)", 20,
            {"Windstep: Speed times/SR move as free action and immune to opportunity.",
             "Skyborn: No fall damage up to 60 ft. Once per short rest, leap/drop from any height, land silent with Sneak advantage."},
            {"Babel", "Auran"},
            "Zephyrkin are light-framed elemental humanoids with airy hair, quick movements, and features that seem sculpted by constant wind. Their steps are almost unnaturally soft, and they carry the impression of creatures who belong more to motion and altitude than to stillness.",
            "Zephyrkin culture values swiftness, grace, and the mastery of movement as both survival and expression. Their communities often thrive in elevated places, open spans, and environments where agility matters more than brute force. They prize timing, fluidity, and the ability to pass through dangerous spaces without leaving more trace than a gust of air"});

        // --- The Hallowed Sacrament ---
        register_lineage({"Glimmerfolk", "Humanoid", 20,
            {"Luminous: Shed 10 ft dim light. Allies gain +1 to attack roles in light.",
             "Dazzle: For 1 SP, force creature within 5 ft to make Vitality save or be blinded."},
            {"Babel", "Lumin"},
            "Glimmerfolk are softly radiant humanoids whose skin and features shimmer with a delicate inner gleam, as if lit by candlelight beneath the surface. Their presence is gentle but difficult to ignore, and even their smallest motions seem to scatter faint traces of light into the air around them.",
            "Glimmerfolk culture is centered on subtle encouragement, shared presence, and the belief that even modest light can strengthen those nearby. Their communities often emphasize harmony, companionship, and rituals of illumination used to inspire courage or mark sacred moments. They value warmth, reliability, and the quiet forms of strength that help others stand more steadily"});

        register_lineage({"Mistborn Human", "Humanoid (Air/Water)", 20,
            {"Vapor Form: For 1 SP move action, become intangible and fly at foot speed.",
             "Drifting Presence: Ignore mist terrain. Disadvantage on ranged attacks vs you in mist. 1/LR create fog."},
            {"Babel", "Auran"},
            "Mistborn Humans are pale, soft-edged figures whose features often seem partially veiled by condensation, vapor, or the faint blur of suspended moisture. Their bodies and movements carry a drifting, elusive quality, as though they were never meant to remain entirely fixed in one place for long.",
            "Mistborn culture is shaped by transience, concealment, and the calm that comes from learning to move through uncertainty rather than resisting it. Their communities often gather in fog-shrouded regions, elevated springs, or places where air and water mingle in shifting forms. They value quiet adaptability, emotional restraint, and the understanding that obscurity can be both refuge and power"});

        register_lineage({"Mossling", "Humanoid (Plant)", 20,
            {"Spore Bloom: Once per long rest, 10 ft calming cloud (Vitality save or dazed 1 min).",
             "Photosynthetic Resilience: Regain 1 HP at start of turn while in natural light."},
            {"Babel", "Sylvan"},
            "Mosslings are small, soft-featured plant humanoids covered in mossy growth, lichen-like textures, and bits of living green that cling to their bodies like a second skin. Their appearance is gentle and organic, giving the impression of beings grown from sacred stone and shaded light rather than born in the ordinary mortal sense.",
            "Mossling culture is rooted in patience, calm, and the quiet persistence of life in sheltered sacred places. Their communities often grow in damp, luminous groves, ruins, and hidden natural sanctuaries where slowness is not weakness but rhythm. They value healing, balance, and the belief that life can remain resilient without ever becoming loud or forceful"});

        register_lineage({"Zephyrite", "Humanoid (Air)", 20,
            {"Windswift: For 1 SP, hover 30 ft off ground for 1 min. +1 AC and advantage on Speed saves.",
             "Gale Sense: Advantage on initiative. Draw/stow weapon as part of initiative roll."},
            {"Babel", "Auran"},
            "Zephyrites are quick, airy humanoids with hair and garments that seem constantly stirred by invisible currents. Their bodies are lean and reactive, and their expressions often carry the sharp alertness of those who are always half a moment ahead of where danger is about to be.",
            "Zephyrite culture emphasizes speed, anticipation, and mastery of reaction rather than brute confrontation. Their communities prize swiftness of mind and body, often training from a young age to act before hesitation can take root. They value readiness, finesse, and the ability to seize the first opening in any challenge before it disappears into the wind"});

        // --- The Land of Tomorrow ---
        register_lineage({"Chronogears", "Construct (Temporal)", 20,
            {"Temporal Shift: Once per short rest as reaction, delay effect of spell/ability on you by 1 round.",
             "Clockwork Precision: Advantage on initiative and cannot be surprised."},
            {"Babel", "Mechan"},
            "Chronogears are intricate temporal constructs built of interlocking metal, arcane gearing, and precision mechanisms that tick with unnatural regularity. Their movements are exact and deliberate, with an eerie sense that they are always measuring the next second before it arrives.",
            "Chronogear culture is defined by order, timing, and the belief that precision is one of the highest forms of power. Their communities often value planning, disciplined maintenance, and the careful manipulation of sequence, cause, and reaction. Among them, to waste time is not merely inefficient, but a kind of spiritual and structural failure"});

        register_lineage({"Silverblood", "Humanoid (Magical)", 20,
            {"Arcane Pulse: Once per long rest, 10 ft pulse dazes creatures (DC 10+DIV Divinity save).",
             "Runic Flow: Advantage on Arcane checks. Once per long rest, auto-succeed one check."},
            {"Babel", "Draconic"},
            "Silverbloods are elegant magically infused humanoids whose veins, eyes, or skin often carry a metallic shimmer like living quicksilver threaded through mortal flesh. Their presence suggests refinement and latent force, as though arcane power moves through them as naturally as blood through a heart.",
            "Silverblood culture is shaped by magical inheritance, cultivated talent, and the expectation that power should be studied rather than wasted. Their communities often place high value on education, arcane refinement, and graceful competence in both ritual and daily life. They believe that magic is not only a gift, but a substance of identity that must be directed with care and intelligence"});

        register_lineage({"Sparkforged Human", "Humanoid (Construct)", 20,
            {"Arcane Surge: Once per long rest, add +2 to spell attack or save DC.",
             "Overload Pulse: When reduced to 0 HP, release 2d6 force damage in 10 ft (boost with SP)."},
            {"Babel", "Mechan"},
            "Sparkforged Humans are construct-enhanced beings powered by volatile arcane energy, with glowing seams, metallic reinforcements, and bodies that seem only partially restrained from becoming living engines of magical discharge. Their presence feels tense and energized, as though force is always building beneath the surface.",
            "Sparkforged culture is built around innovation, risk, and the acceptance that power often comes with instability. Their communities are frequently tied to laboratories, forge-cities, or experimental enclaves where arcane engineering and survival exist side by side. They value ingenuity, nerve, and the willingness to withstand dangerous transformation in pursuit of advancement"});

        register_lineage({"Watchling", "Construct (Awakened Tech)", 20,
            {"Broadcast Eye: Advantage on Perception/Intuition (sight). See invisible silhouettes within 10 ft.",
             "Static Surge: Free action overload for 0 AP actions until next turn, then dazed + self-damage."},
            {"Babel", "Mechan"},
            "Watchlings are awakened technological constructs with lens-like eyes, compact frames, and bodies built for observation, signaling, and rapid information response. Their gaze is unnervingly attentive, and even in stillness they give the impression of constant silent recording and assessment.",
            "Watchling culture revolves around awareness, function, and the efficient handling of information in environments driven by invention and surveillance. Their communities often emphasize utility, coordination, and the value of seeing what others miss before it becomes a problem. They prize vigilance, quick analysis, and the belief that knowledge gathered in time is often more valuable than force used too late"});

        // --- Sublimini Dominus ---
        register_lineage({"Echoform Warden", "Elemental (Echo-Touched)", 30,
            {"Echo Reflection: Spend 3 AP when targeted by spell to suppress it (DC 10+DIV Intellect save).",
             "Memory Tap: For 1 SP, learn a recent memory from touched creature (DC 14 Divinity save resists)."},
            {"Babel", "Echoic"},
            "Echoform Wardens are strange elemental beings whose bodies seem composed of layered afterimages, partial reflections, and repeating silhouettes that never fully settle into one stable form. Their presence feels like a memory trying to stand upright, substantial enough to matter but never entirely fixed in the present.",
            "Echoform Warden culture is shaped by memory, containment, and the duty of preserving meaning in places where reality itself grows uncertain. Their communities often behave like custodians of resonance, guarding impressions, histories, and magical echoes that might otherwise be lost or weaponized. They value perception, restraint, and the careful handling of memory as both burden and sacred record"});

        register_lineage({"Nullborn Ascetic", "Humanoid (Void-Touched)", 30,
            {"Void Cloak: Immune to detection/scrying. Extend to allies (15 ft) for -3 Max AP cost.",
             "Spell Sink: For 3 AP, absorb SP from a spell effect used on you and convert into 1 SP."},
            {"Babel", "Silent Cant"},
            "Nullborn Ascetics are severe, quiet figures marked by emptiness rather than ornament, with muted features, still postures, and an aura that seems to swallow notice and magical attention alike. Their presence is unsettling not because it is loud or monstrous, but because it feels like a deliberate absence where something should be.",
            "Nullborn Ascetic culture is built around discipline, silence, and the mastery of void through denial rather than expression. Their communities often embrace austerity, meditation, and strict forms of self-erasure meant to reduce distraction, excess, and magical vulnerability. They value control, inward focus, and the belief that to become difficult to grasp is a form of profound strength"});

        register_lineage({"Mistborne Hatchling", "Aberration (Proto-Spawn)", 25,
            {"Warp Resistance: Resistance to environmental magical terrain effects. Extend to allies for -3 Max AP.",
             "Surge Pulse: For 1 SP, 10 ft burst slows for 1 min (DC 10+DIV Vitality save)."},
            {"Babel", "Dreamtongue"},
            "Mistborne Hatchlings are aberrant young forms wrapped in vaporous distortion, with bodies that seem only partially finished by reality and features that blur between creature, fog, and malformed possibility. They appear fragile at first glance, but there is something deeply unnatural in the way they persist through warped environments that break ordinary life.",
            "Mistborne Hatchling culture, where it exists, is shaped by adaptation, instability, and early exposure to places where magic and environment have grown inseparable. They are often raised among stranger beings or in enclaves where mutation is expected rather than feared. Their societies value resilience, environmental awareness, and the ability to survive before fully understanding what one is becoming"});

        // --- Beating Heart of The Void ---
        register_lineage({"Bespoker", "Aberration (Void-Tuned Caster)", 40,
            {"Ray Emission: Choose Ray (Paralyze, Fear, Heal, Necrotic, Disintegrate) for 1-3 AP.",
             "Anti-Magic Cone: While active (-3 Max AP), 30 ft cone suppresses spells <= level."},
            {"Babel", "Voidsong"},
            "Bespokers are towering aberrant beings whose bodies ripple with unstable void energy. Their forms appear sculpted from shifting darkness, with eyes that burn like distant singularities.",
            "Bespoker culture revolves around mastery of void resonance and destructive cosmic forces. They view magic not as a tool but as a raw current to be bent and redirected. Their society respects those who can channel the most dangerous energies without losing themselves to the abyss"});

        register_lineage({"Brain Eater", "Aberration (Swarm Predator)", 60,
            {"Neural Liquefaction: Target within 5 ft takes 2d6 psychic + loses 1 SP (DC 10+DIV save).",
             "Skull Drill: If target is stunned/restrained, deal 2d6 damage and regain 2d6 HP."},
            {"Babel", "Pheromones"},
            "Brain Eaters are grotesque aberrations with bulbous cranial bodies and writhing tendrils designed to pierce skulls and consume neural tissue. Their movement is unsettlingly deliberate, driven by a relentless hunger for thought itself.",
            "Brain Eater society is hive-like and predatory, driven by instinct and the consumption of knowledge stored in living minds. Within their swarms, the most intelligent individuals rise to dominance by devouring the memories of rivals, creating a brutal hierarchy built upon stolen intellect"});

        register_lineage({"Pulsebound Hierophant", "Aberration (Void Priest)", 30,
            {"Resonant Sermon: While active (-3 Max AP), allies gain +1 saves/checks and enemies disadvantage on casting.",
             "Void Communion: Once per long rest, 10 min ritual grants nearby allies 1d4+DIV SP + visions."},
            {"Babel", "Voidsong"},
            "Pulsebound Hierophants are tall, robed figures whose bodies pulse with rhythmic waves of void energy. Their eyes glow softly with deep cosmic light, and their voices carry a strange resonance that vibrates through the air.",
            "Pulsebound Hierophants serve as priests of the Void’s living rhythm, interpreting the pulses of cosmic silence as divine instruction. Their communities revolve around ritual, meditation, and the study of existential emptiness, believing that the Void speaks not in words but in patterns of resonance"});

        register_lineage({"Threnody Warden", "Construct (Void Guardian)", 40,
            {"Threnody Slam: 3 AP deals 3d6 force and mutes target for 1 round (DC 10+DIV Divinity save).",
             "Pulse of Silence: 10 ft aura imposes disadvantage on speech-based abilities and blocks verbal spells."},
            {"Babel", "Voidsong"},
            "Threnody Wardens are massive construct guardians forged from dark alloys etched with humming void sigils. Their bodies resonate with a low, mournful vibration that can be felt through the ground before they are seen.",
            "Threnody Warden culture is defined by duty and eternal vigilance. Created to guard sacred void sites and unstable rifts, they view their purpose as sacred and unending. Even when standing motionless for centuries, their silent watch continues, ensuring that certain cosmic forces remain contained"});
    }

    void register_lineage(rimvale::Lineage l) {
        lineages_[l.name] = std::move(l);
    }

    std::map<std::string, rimvale::Lineage> lineages_;
};

} // namespace rimvale

#endif // RIMVALE_LINEAGE_REGISTRY_H
