## rimvale_fallback_engine.gd
## Pure-GDScript drop-in replacement for RimvaleEngine (C++ DLL).
## Used automatically when the GDExtension DLL fails to load.
## Stores all character data in-memory so summon/collection/team works.

class_name RimvaleFallbackEngine
extends RefCounted

# ── Character storage ─────────────────────────────────────────────────────────
var _chars: Dictionary = {}   # handle(int) -> data(Dictionary)
var _next_handle: int = 1

# ── Combat state ──────────────────────────────────────────────────────────────
var _combat_creatures: Dictionary = {}   # handle → creature dict
var _combat_staged_players:   Array = []
var _combat_staged_creatures: Array = []
var _combat_order:  Array = []           # sorted combatant dicts (active combat)
var _combat_idx:    int   = 0
var _combat_round:  int   = 0
var _combat_log:    String = ""
var _combat_next_creature_id: int = 1

# ── All lineages (from LineageRegistry.h) ────────────────────────────────────
const ALL_LINEAGES: PackedStringArray = [
	"Aetherian","Abyssari","Arcanite Human","Archivist","Ashrot Human",
	"Ashenborn","Auroran","Beetlefolk","Bespoker","Bilecrawler",
	"Blackroot","Blightmire","Blood Spawn","Bloodsilk Human","Bloatfen Whisperer",
	"Bogtender","Bookborn","Boreal Human","Bouncian","Brain Eater","Bramblekin",
	"Candlites","Canidar","Carrionari","Cervin","Chokeling",
	"Chronogears","Cindervolk","Cloudling","Convergents","Corrupted Wyrmblood",
	"Corvian","Cragborn Human","Crimson Veil","Cryptkin Human","Disjointed Hounds",
	"Drakari","Dreamer","Dregspawn","Driftwood Woken","Duckslings",
	"Dustborn","Duskling","Echo-Touched","Echoform Warden","Elf",
	"Emberkin","Fae-Touched Human","Fathomari","Felinar","Ferrusk",
	"Filthlit Spawn","Flenskin","Frostborn","Galesworn Human","Gilded Human",
	"Glaceari","Glassborn","Glimmerfolk","Gloomling","Goldscale",
	"Gravari","Graveleaps","Gravetouched","Gravemantle","Gremlin",
	"Gremlidian","Grimshell","Groblodyte","Gullet Mimes","Hagborn Crone",
	"Hearthkin","Hellforged","Hexkin","Hexshell","Hollowborn Human",
	"Hollowroot","Huskdrone","Hydrakari","Ironhide","Ironjaw",
	"Jackal Human","Kelpheart Human","Kettlekyn","Kindlekin","Lanternborn",
	"Lifeborne","Lightbound","Lithari","Lost","Luminar Human",
	"Madness-Touched Human","Marionox","Mireborn Human","Mireling","Mirevenom","Mistborn Human",
	"Mistborne Hatchling","Moonkin","Mossling","Myconid","Myrrhkin",
	"Nightborne Human","Nihilian","Nimbari","Nullborn","Nullborn Ascetic",
	"Oblivari Human","Obsidian","Obsidian Seraph","Oozeling","Pangol",
	"Panoplian","Parallax Watchers","Porcelari","Prismari","Pulsebound Hierophant",
	"Quillari","Regal Human","Riftborn Human","Rotborn Herald","Runeborn Human",
	"Rustspawn","Sable","Sandstrider Human","Saurian","Scavenger Human",
	"Scornshard","Scourling Human","Serpentine","Shadewretch","Shardkin",
	"Shardwraith","Silverblood","Skulkin","Skysworn","Sludgeling",
	"Snareling","Sparkforged Human","Starborn","Stormclad","Sunderborn Human",
	"Taurin","Tetrasimian","Thornwrought Human","Threnody Warden","Tiderunner Human",
	"Tidewoven","Tombwalker","Trenchborn","Twilightkin","Umbrawyrm",
	"Ursari","Venari","Verdant","Volcant","Voxilite",
	"Voxshell","Vulpin","Watchling","Weirkin Human","Whisperspawn",
	"Zephyrkin","Zephyrite",
]

# ── Lineages ──────────────────────────────────────────────────────────────────
static var _LINEAGE_DETAILS: Dictionary = {
	"Bouncian": ["Humanoid (Beast)", "25ft", "Keen Hearing: Advantage on sound-based Perception and detect invisible within 10ft. | Bounding Escape: Reduce fall damage by Speed x 5. Leap 15ft as a Reaction to avoid attacks (1/SR).", "Babel, Burrowtongue", "Small, quick-witted humanoids with long ears and soft fur, known for their agility and keen senses.", "Bouncians are a lively and communal people whose culture centers on agility, quick thinking, and a deep appreciation for the cycles of nature, often celebrating with vibrant festivals and games that showcase their speed and wit."],
	"Goldscale": ["Humanoid (Reptile)", "20ft", "Scaled Hide: Base AC 13. Glow when taking fire damage: +1d4 fire to attacks and attackers take 1d4. | Sun's Favor: Fire resistance. Radiant burst (10ft radius, DC 10+VIT or Blinded, 3 AP).", "Babel, Draconic", "Goldscales are reptilian humanoids with gleaming golden scales and slit-pupiled eyes.", "Goldscales are renowned for their disciplined, tradition-bound society that values honor, wisdom, and the pursuit of excellence, often gathering in structured communities where leadership and achievement are celebrated."],
	"Ironhide": ["Humanoid (Construct)", "20ft", "Armored Plating: Base AC 13. Activate for +2 AC for 1 min (1/LR). | Mechanical Mind: Advantage vs charm. Auto-succeed on an Intellect check to recall info (1/SR).", "Babel, Mechan", "Ironhides are construct-like humanoids with metallic skin, jointed limbs, and glowing eyes, built for durability and mental fortitude.", "Ironhides are a proud and stoic people whose culture values endurance, craftsmanship, and the preservation of tradition, often gathering in communities where artistry and resilience are celebrated."],
	"Verdant": ["Humanoid (Plant)", "20ft", "Regrowth: Regain level + VIT HP as an action (1/SR). | Nature's Voice: Speak with plants. Bond with a plant for 10 min to share senses within 60ft (1/LR).", "Babel, Sylvan", "Verdants are plantfolk with vibrant green skin, leafy hair, and flowers blooming from their bodies, embodying the vitality of nature.", "Verdants embody the vitality and resilience of nature, with a culture rooted in harmony, growth, and the celebration of life's interconnectedness."],
	"Vulpin": ["Humanoid (Beast)", "20ft", "Illusory Echo: Create illusory double for 1 min, giving advantage on all checks (1/LR). | Trickster's Dodge: Impose disadvantage on an attack against you or ally within 10ft (1 SP, Reaction).", "Babel, Vulpine", "Foxfolk. Clever, red-furred humanoids with bushy tails and quick reflexes.", "Vulpin culture is centered on cunning, adaptability, and the value of community bonds, with traditions that celebrate cleverness, storytelling, and the art of outwitting both friend and foe."],
	"Bramblekin": ["Humanoid (Plant)", "20ft", "Thorny Hide: Deal 1d4 piercing when hit by or hitting with melee attack. | Photosynthesis: No food/water needed with 1hr sunlight. Produce 1 ration for ally (1 SP).", "Babel, Sylvan", "Bramblekin are plantfolk with bark-like skin, leafy hair, and thorny protrusions, blending seamlessly into forested environments.", "Bramblekin culture is deeply rooted in the cycles of the forest, valuing harmony with nature, resilience, and the wisdom of the wild."],
	"Elf": ["Humanoid", "20ft", "Innate Magic: +1 SP per level. Life extension ritual (10 years per SP, permanent insanity risks). | Keen Senses: +1d4 to Perception. Add Perception score to initiative rolls.", "Babel, Elvish", "Elves are slender, graceful, and long-lived, with pointed ears and sharp features, often possessing an ethereal beauty and a deep connection to nature and magic.", "Elven culture is steeped in tradition and a profound reverence for magic, art, and the natural world, with communities that value wisdom, beauty, and the pursuit of knowledge."],
	"Fae-Touched Human": ["Humanoid (Fey)", "20ft", "Fey Step: Teleport instead of moving (Double AP cost). | Enchanting Presence: Advantage vs fey. Shimmer for 1 min to gain +1d4 to Speechcraft (1/SR).", "Babel, Sylvan", "Fae-Touched Humans possess slender builds, pointed ears, and skin that glimmers with subtle, otherworldly hues, giving them an ethereal and enchanting presence.", "Fae-Touched Human culture is deeply influenced by their fey heritage, valuing beauty, whimsy, and a close connection to the magical forces of nature."],
	"Felinar": ["Humanoid (Beast)", "20ft", "Cat's Balance: Advantage on Speed, Nimble, and Cunning checks. | Nine Lives: Drop to 9 HP instead of 0 (9/LR).", "Babel, Felin", "Felinar are graceful, feline humanoids renowned for their sharp senses and nimble bodies.", "Felinar culture values independence, curiosity, and adaptability, with a strong emphasis on personal freedom and the pursuit of individual passions."],
	"Myconid": ["Humanoid (Fungus)", "20ft", "Spore Cloud: 10ft radius poison cloud (DC 10+VIT or Poisoned 1 min, 1/LR). | Fungal Fortitude: Poison resistance. Heal 2d6 (4d6 if poisoned) as an action (1/SR).", "Babel, Sporetalk", "Myconids are fungus-based humanoids whose lives revolve around communal harmony and a deep connection to the cycles of decay and renewal in nature.", "Myconid culture is centered on communal harmony, patience, and a deep connection to the cycles of decay and renewal in nature. They live in close-knit colonies, sharing thoughts and emotions through spores."],
	"Grimshell": ["Construct", "20ft", "Tomb Core: Count first failed death save as success. | Heavy Frame: Reaction to reduce melee damage by 1d4+STR and push attacker 5ft (1 AP + Reaction).", "Babel, Mechan", "Enshrouded in rust and sorrow, Grimshells are armored shells that once held noble knights-but now only echo with the memories of fallen honor.", "Grimshell culture is defined by perseverance and remembrance. They honor the struggles of the past and find strength in shared adversity."],
	"Hearthkin": ["Construct (Fire/Spiritual)", "20ft", "Kindle Flame: Ignite magical fire (20ft radius) giving allies +1d4 AP to Rest actions (1/LR). | Warm Core: Fire resistance. Allies within 5ft immune to extreme cold.", "Babel, Ignan", "Hearthkin are humanoids animated from hearthstones or firepits, often found in ancient ruins or sacred groves. They are warm, protective, and deeply communal.", "Hearthkin culture centers on protection, hospitality, and the maintenance of communal bonds. They gather in close-knit groups, tending sacred fires and offering shelter to travelers."],
	"Kindlekin": ["Humanoid (Plant)", "20ft", "Alchemical Affinity: Reduce Chemical spell cost by 4 SP (min 0, 1/Rest). | Combustive Touch: Release explosion when hit (1d4 + 1d4 per subsequent hit). Resets on rest.", "Babel, Sylvan", "Kindlekin are living embodiments of combustion and transformation, their forms a mesmerizing dance of flickering embers and shifting, tangled shapes.", "Kindlekin culture is shaped by the duality of creation and destruction. Favored by alchemists and engineers, they are sought after for their ability to manipulate reactions and harness combustion."],
	"Regal Human": ["Humanoid", "20ft", "Versatile: +1d4 to all skill checks. Can grant this to allies DIV times (Free Action, 1/LR). | Resilient Spirit: Reroll failed saving throw (2/SR).", "Babel, Choice (+5 languages)", "Resourceful and diverse, Regal humans are adaptable beings with a wide range of appearances.", "Regal Human culture emphasizes versatility, governance, and the ability to thrive in a variety of environments. They value tradition, diplomacy, and the pursuit of excellence."],
	"Quillari": ["Humanoid", "25ft", "Quill Defense: Grappler takes 1d6 piercing. Launch yourself in 30ft line dealing 2d6 damage (1/LR). | Quick Reflexes: 2x Speed on initiative. Extra Move or Free action before combat (1/SR).", "Babel, Prickletongue", "Quillari are small, spiky humanoids with quills covering their backs and arms, quick to react to danger.", "Quillari culture values vigilance, adaptability, and community support. They are known for their swift responses to threats and their tendency to look out for one another."],
	"Beetlefolk": ["Humanoid (Insect)", "20ft", "Carapace: Base AC 13. Reaction to reduce melee damage by 1d6+VIT (VIT times/SR). | Burrow: Burrow 10ft/round. Tremorsense 15ft while underground.", "Babel, Terran", "Beetlefolk are sturdy, chitinous humanoids whose societies emphasize resilience, cooperation, and adaptability.", "Beetlefolk culture emphasizes resilience, cooperation, and adaptability. Communities are structured around mutual support and shared labor."],
	"Canidar": ["Humanoid (Beast)", "20ft", "Pack Tactics: Advantage if ally within 5ft. Grant allies advantage for 1 min (1/LR). | Loyal Strike: Reaction melee attack when ally within 10ft is hit.", "Babel, Canish", "Canidar are wolffolk-pack-oriented, lupine humanoids known for their keen senses and unwavering loyalty.", "Canidar culture is deeply rooted in pack dynamics, emphasizing loyalty, cooperation, and mutual protection. They value the strength of the group over individual ambition."],
	"Cervin": ["Humanoid (Beast)", "20ft", "Fleet of Foot: Ignore nonmagical difficult terrain. Count as Large for Strength checks. | Nature's Grace: Grant 1d4 bonus to checks for DIV allies for 10 min in nature (1/LR).", "Babel, Cervine", "Deerfolk. Elegant, antlered humanoids with swift legs and a connection to nature.", "Cervin culture is closely tied to the rhythms of the natural world. They value harmony with their surroundings, agility, and the wisdom of the wild."],
	"Lithari": ["Construct (Earthbound)", "20ft", "Stone Memory: Advantage on terrain Survival. Sense creatures within 15ft on stone surfaces. | Rooted Form: Resistance to all non-magical damage.", "Babel, Terran", "Lithari are sentient standing stones or boulders, etched with ancient runes and slowly shifting over time. They are contemplative, patient, and deeply connected to the land.", "Lithari culture is defined by patience, contemplation, and a profound bond with the land. They value wisdom gained through observation and endurance."],
	"Tetrasimian": ["Monstrosity", "20ft", "Four Arms: Two primary + two secondary (Light weapons only). Extra light weapon attack. | Adaptive Hide: Base AC 13. Color-shift fur for advantage on Sneak (remain motionless).", "Babel, Simian", "Tetrasimians are powerful, four-armed monstrosities known for their agility, adaptability, and cunning.", "Tetrasimian culture values agility, adaptability, and cleverness. Communities emphasize cooperation and the use of their unique physical abilities to overcome obstacles."],
	"Thornwrought Human": ["Humanoid (Plant)", "20ft", "Barbed Embrace: Deal 1d6 piercing to grappler/grappled creature. | Verdant Curse: Poison resistance. Reaction to shed afflicted part and remove condition (1/LR).", "Babel, Sylvan", "Thornwrought are humans infused with twisted vines, bark, and blooming thorns. Born from cursed groves, they carry both beauty and danger.", "Thornwrought culture is shaped by their origins in cursed groves. They often live on the fringes of society, balancing the duality of their beautiful yet perilous nature."],
	"Blackroot": ["Humanoid (Plant/Corrupted)", "20ft", "Toxic Roots: 10ft poison gas action (DC 13 VIT, 1/LR). | Witherborn: Advantage on Survival in blighted terrain. Absorb decay to heal 1d6+VIT (1/LR).", "Babel, Sylvan", "The Blackroot wander from blighted groves with tendrils of decay curling behind them. Their limbs creak like dead wood, and their roots carry pestilence into the soil.", "The Blackroot are solitary wanderers, shunned even by the most desperate outcasts. Their society is bound by a code of silence and suffering."],
	"Bloodsilk Human": ["Humanoid (Aberrant/Spiderborne)", "20ft", "Silken Trap: Restrain creature within 15ft for 1 min (1/SR). | Draining Fangs: Deal 1d4 damage to restrained target and regain 1 HP (1 AP, Free Action).", "Babel, Webscript", "Silken and graceful, these spider-touched creatures weave pain and beauty into the same thread.", "Bloodsilk culture values artistry, allure, and the intertwining of danger with beauty. Their society prizes both creativity and cunning."],
	"Mirevenom": ["Humanoid (Beast/Swamp Horror)", "20ft", "Venomous Blood: Melee attacker or unarmed hit triggers DC VIT save or 1d4 poison damage. | Lurker's Step: Advantage on Sneak in swamp/water. Hide as a Free Action when emerging (1/SR).", "Babel, Mirecant", "These swamp-stalkers ooze venom with each breath. Slippery and scaled, Mirevenom are predators of still water and slow death.", "Mirevenom culture is shaped by the harsh realities of swamp life. They value cunning, patience, and the ability to strike at the perfect moment."],
	"Serpentine": ["Humanoid (Beast)", "20ft", "Venomous Bite: 1d4 poison damage. Extract venom for +1d4 poison damage on next weapon attack (1/LR). | Hypnotic Gaze: Daze creature within 10ft (DC 10+DIV, 3 AP).", "Babel, Sibilant", "Snakefolk. Sinuous, scale-skinned humanoids with hypnotic eyes and a venomous bite.", "Serpentine culture values cunning, patience, and adaptability. They are often associated with secrecy and subtlety."],
	"Bookborn": ["Humanoid (Construct)", "20ft", "Origami: Fold into 2D form to move through 1-inch gaps and glide 30ft (3 AP). | Paper Ward: Reduce damage by Level + INT modifier (INT times/SR).", "Babel, Draconic", "Bookborn are ancient tomes brought to life, walking archives of wisdom and memory.", "Bookborn culture centers around the preservation, sharing, and pursuit of knowledge. They value learning, wisdom, and the careful stewardship of information."],
	"Archivist": ["Humanoid (Human)", "20ft", "Mnemonic Recall: Auto-succeed on recall/research/decipher check (1/SR). | Polyglot: Study any language for 1hr to read/write. 10 min to speak.", "Babel, Choice (+5 languages)", "Archivists are humans shaped by generations of life within the Eternal Library, renowned for their prodigious memory and scholarly discipline.", "Archivist culture centers around the preservation, organization, and sharing of knowledge. Their society values learning, wisdom, and the careful stewardship of information."],
	"Panoplian": ["Humanoid (Construct)", "20ft", "Living Plate: AC 16 (Heavy armor). Cannot add Speed to AC. | Sentinel's Stand: Anchor yourself when Dodging. Speed 0, but unlimited opportunity attacks.", "Babel, Dwarvish", "Panoplians are sentient suits of armor animated by forgotten oaths and battle-forged purpose.", "Panoplian culture is shaped by their origins as living armor. They value honor, loyalty, and the fulfillment of promises above all else."],
	"Arcanite Human": ["Humanoid", "20ft", "Arcane Surge: +2 to Spell attack or DC (1/LR). | Magic Sense: Detect magic sense (10ft range).", "Babel, Primordial", "Arcanites are humans with glowing runes etched into their skin, pulsing with latent magical energy.", "Arcanite Human culture is deeply intertwined with the study and practice of magic. They value knowledge, discipline, and the responsible use of arcane power."],
	"Groblodyte": ["Humanoid (Gremlin-Kin)", "20ft", "Scrap Instinct: Tinker's Tools proficiency. Cobble one-use gadget for advantage/SP reduction (1/SR). | Arcane Misfire: Overcharge spells (roll d6: 1-2 Backfire, 3-5 Normal, 6 Amplified).", "Babel, Grobbletongue", "Groblodytes are small, volatile tinker-goblins born from arcane misfires and industrial chaos.", "Groblodyte culture thrives in entropy. They are scavengers, inventors, and saboteurs who build communities in the ruins of magical disasters."],
	"Kettlekyn": ["Humanoid (Construct)", "20ft", "Steam Jet: 15ft cone exhale 2d6 fire + level (DC 10+VIT save, 1/LR). | Heat Engine: Fire/Cold resistance. Overheat for 1 min: immunity + 1d4 fire to grappled/melee hits (1/LR).", "Babel, Gnomish", "Kettlekyn are stout metal-bodied folk powered by arcane steam pressure. They often whistle under stress and emit heat from their core vents.", "Kettlekyn culture is shaped by their mechanical nature and the arcane forces that animate them. They value resilience, precision, and harmonious community function."],
	"Marionox": ["Humanoid (Construct)", "20ft", "Tether Step: Teleport 30ft as a move action (3 AP). | Wooden Frame: Advantage vs paralyzed, squeezed, grappled, petrified, prone.", "Babel, Elvish", "Marionox are animated marionette puppets, brought to life by arcane threads and theatrical spirit.", "Marionox culture is shaped by their origins in performance and magic. They value creativity, expression, and the art of storytelling."],
	"Voxshell": ["Construct (Sound)", "20ft", "Resonant Voice: Project voice 300ft. Impose disadvantage on check by mocking (INT times/SR). | Echo Memory: Perfectly recall and recreate any sound from the last 24 hours.", "Babel, Voxcant", "Voxshells are animated, humanoid speaker-box constructs made of brass, wood, and arcane resonators.", "Voxshell culture is shaped by their affinity for sound and communication. They value clarity, harmony, and the sharing of ideas."],
	"Gilded Human": ["Humanoid", "20ft", "Living Plate: Base AC 13. | Market Whisperer: Know fair market value. Auto-find buyer for full price once per long rest.", "Babel, Gilded Cant", "The Gilded Humans are a people whose bodies are partially encased in living metal that grows in intricate patterns across their skin.", "Gilded Human culture is renowned for its wealth, business acumen, and mastery of finance and trade. Their society values prosperity, negotiation, and the careful stewardship of resources."],
	"Gremlidian": ["Humanoid (Fey, Construct)", "20ft", "Arcane Tinker: Tinker's tools proficiency. Create minor gadget once per long rest. | Gremlin's Luck: Reroll failed skill check (2/SR).", "Babel, Gremlish", "Gremlidians are small, wiry humanoids with oversized ears, glowing eyes, and a knack for chaos. Natural tinkerers and saboteurs.", "Gremlidian culture revolves around invention, experimentation, and playful disruption. They value ingenuity, adaptability, and the thrill of discovery."],
	"Hexkin": ["Humanoid (Cursed Lineage)", "20ft", "Hex Mark: Impose disadvantage on saves vs your spells for 1 min (1/LR). | Witchblood: +2 bonus to Spell DC (1/SR).", "Babel, Witchscript", "Markings crawl across their skin like script come alive. Hexkin are the cursed children of ancient spellcraft.", "Hexkin society is shaped by the burden and power of their magical heritage. They value knowledge, resilience, and the mastery of their arcane gifts."],
	"Voxilite": ["Humanoid", "20ft", "Golden Tongue: Advantage on influence checks. | Commanding Voice: Issue single-word command (1/LR). Extra uses cost Max HP.", "Babel, Vox Cant", "Voxilites are charismatic, gold-adorned individuals whose voices carry a subtle, enchanting resonance.", "Voxilite culture values appraisal and trade, with a natural talent for determining the value of objects. They prize clarity, precision, and the sharing of knowledge."],
	"Ferrusk": ["Humanoid (Construct)", "20ft", "Overdrive Core: Gain 2d4+VIT AP as basic action (1/SR). | Scrap Resilience: Slashing resistance. Taking slashing damage grants +1 AC for 1 round.", "Babel, Mechan", "Ferrusks are biomechanical humanoids with rusted plating, exposed gears, and glowing cores. Remnants of a forgotten age of war and invention.", "Ferrusk society values endurance, adaptability, and the pursuit of self-improvement. Communities emphasize cooperation, innovation, and the responsible use of technology."],
	"Gremlin": ["Humanoid", "20ft", "Tinker: Create volatile gadget (Flashbang, Arc Spark, or Grease Puff) (1/LR). | Sabotage: Disable device for 1 min (1/SR). Choice of backfire effect.", "Babel, Gremlin", "Gremlins are small, wiry, and mischievous, with oversized ears and nimble fingers, often found in the underbellies of cities.", "Gremlin culture revolves around invention, experimentation, and playful disruption. They value ingenuity, adaptability, and the thrill of discovery."],
	"Hexshell": ["Construct (Arcane-Cursed)", "20ft", "Reflect Hex: Reflect condition to caster (DC 10+DIV save, 1/LR). | Cursed Circuitry: +2 to Spell saves when below 2/3 HP.", "Babel, Hexcode", "Wrought from magic gone wrong, Hexshells are arcane constructs made of cursed runes and cracked plating.", "Hexshells value resilience, caution, and the pursuit of understanding the arcane forces that created them."],
	"Ironjaw": ["Humanoid", "20ft", "Magnetic Grip: Advantage to grapple creatures in metal armor. Pull small metal objects from 5ft. | Iron Stomach: Advantage vs ingested poison. Basic magic attack can do poison damage for free.", "Babel, Orc", "Ironjaws are broad, muscular, and have metallic teeth and jawbones.", "Ironjaw culture is shaped by resilience and strength. Communities emphasize mutual support and the ability to withstand challenges together."],
	"Scavenger Human": ["Humanoid (Human)", "20ft", "Scrap Sense: Auto-succeed on search check in ruins/mechanical areas (1/SR). | Toxic Resilience: Advantage vs poisons/disease. Absorb toxin on save for resistance.", "Babel, Choice (+1 language)", "Scavengers are humans adapted to life in the labyrinthine depths of the Lower Forty, resourceful, quick-witted, and tough.", "Scavenger Human culture is shaped by survival and ingenuity. They value adaptability, cleverness, and the ability to make the most out of limited resources."],
	"Corvian": ["Humanoid (Beast)", "20ft", "Mimicry: Imitate voices/sounds. Signal allies silently within 60ft. | Shadow Glide: +20 Speed, Flight, and Invisibility in dim light/darkness for 1 round (3 AP).", "Babel, Corvish", "Crowfolk. Slender, black-feathered humanoids with sharp eyes and a knack for secrets.", "Corvian culture is deeply intertwined with themes of stealth, illusion, and forbidden knowledge. Their communities tend to be insular, relying on trust and shared information."],
	"Duskling": ["Humanoid", "20ft", "Shadowgrasp: Restrain creature within 10ft (DC 10+INT save, 3 AP). | Nightvision: 30ft darkvision and advantage on Sneak in low light.", "Babel, Umbral", "Dusklings are small, shadowy figures with dark, muted skin tones and large, reflective eyes, adept at blending into the darkness.", "Duskling culture values stealth, subtlety, and adaptability, thriving in environments where blending in and moving unseen are essential for survival."],
	"Duckslings": ["Humanoid", "20ft", "Slippery: Advantage vs grapples when wet. Poison resistance near freshwater. | Quack Alarm: Startling quack gives allies advantage on next initiative/surprise save (1/LR).", "Babel, Mirecant", "Duckslings are small, downy-feathered humanoids with rounded beaks and webbed fingers, known for their cheerful nature and affinity for water.", "Duckslings live in close-knit communities near rivers, lakes, and marshes. Their culture values cooperation, playfulness, and storytelling."],
	"Hollowborn Human": ["Humanoid (Undead)", "20ft", "Undead Resilience: Immune to poison/disease. Advantage vs environmental exhaustion. | Deathless: No food/drink needed. Double stamina for rest.", "Babel, Necril", "Hollowborn Humans are gaunt, pallid, and often bear visible signs of undeath, yet move with unnatural vitality.", "Hollowborn Human culture values endurance, adaptability, and the ability to find purpose despite their condition between life and undeath."],
	"Sable": ["Humanoid", "20ft", "Night Vision: 120ft magical darkvision. Create 10ft cube of darkness within 30ft (1/LR). | Silent Step: Advantage on Sneak when moving at half speed.", "Babel, Sablespeak", "Born beneath moonless skies and shaped by the rhythm of shadow, the Sables are a people of quiet grace and unspoken strength.", "Sable culture emphasizes adaptability and subtlety, with a strong value placed on the ability to navigate darkness and remain unnoticed when necessary."],
	"Twilightkin": ["Humanoid (Fey)", "20ft", "Veilstep: Swap places with ally in dim light/darkness within 30ft (1/SR). | Duskborn Grace: Auto-succeed on Sneak in dim light/darkness for 1 min (1/SR).", "Babel, Sylvan", "Twilightkin are dusky-skinned humanoids with eyes that shimmer like starlight and hair that flows like shadow.", "Twilightkin culture values subtlety, adaptability, and the ability to navigate both literal and social darkness."],
	"Bogtender": ["Giantkin", "20ft", "Marshstride: Move through difficult terrain without penalty. | Mossy Shroud: Cover self/ally in moss for Stealth advantage + Cold resistance (1/LR).", "Babel, Druidic", "Bogtenders are gentle, moss-covered giants who tend to the rare, uncorrupted patches of the marsh.", "Bogtender culture centers around caretaking and preservation. They are devoted to nurturing and protecting the last remnants of unspoiled nature within the marshes."],
	"Mireborn Human": ["Humanoid", "20ft", "Mud Sense: Sense movement through mud/water (10ft). Advantage vs restrained/grappled in mud. | Mire Resilience: Poison resistance. Burst of poison gas on successful save (DC 10+VIT).", "Babel, Aquan", "Mireborn are amphibious humans, with mud-caked skin and webbed hands and feet.", "Mireborn Human culture is shaped by their marshland homes. They are resourceful and resilient, often relying on their keen senses and adaptability to survive."],
	"Myrrhkin": ["Humanoid (Spiritual)", "20ft", "Soothing Aura: Calming scent gives allies advantage vs fear/charm (1/LR). | Dreamscent: 30ft haze of sleep incense (DC 10+DIV INT save, 1/LR).", "Babel, Incensari", "Myrrhkin presence exudes a tranquil aura, and a touch from a Myrrhkin can ease pain or evoke vivid, dreamlike visions in those nearby.", "Myrrhkin are spiritual humanoids steeped in incense, rot, and ritual. They serve as healers, death-guides, plague-priests, and keepers of forgotten pacts."],
	"Oozeling": ["Humanoid (Ooze)", "20ft", "Amorphous Form: Squeeze through 6-inch gaps. Immune to squeeze condition. | Corrosive Touch: Unarmed hit or melee hit on you deals 1d4 acid damage to target's armor/weapon.", "Babel, Choice", "Though often misunderstood as mindless, Oozelings possess strange intelligence and eerie insight into decay and transformation.", "Oozeling culture centers around adaptability and fluidity. They value flexibility and their communities are loosely organized."],
	"Blood Spawn": ["Humanoid (Bloodborne)", "20ft", "Bloodletting Blow: Deal +1d4 melee damage and heal for total damage (3 AP). | Bloodsense: Blindsight for bleeding creatures within 15ft. Advantage on attacks.", "Babel, Old Tongue", "Forged in rituals steeped in blood and sacrifice, Blood Spawn shimmer with vitality that leaks through their skin like a crimson mist.", "Blood Spawn society is shaped by a drive for strength and power through predation or ritual. Blood Spawn communities may be insular, bound together by shared origins."],
	"Cryptkin Human": ["Humanoid (Necrotic)", "20ft", "Boneclatter: 15ft fear rattle (DC 10+DIV SPIRIT save, 3 AP). | Diseaseborn: Immune to disease. Advantage vs curses. Apply curse on hit (1/LR).", "Babel, Gravechant", "These wretched, hunched scavengers creep through mausoleums and catacombs, feeding on secrets and marrow alike.", "Cryptkin culture values cunning, concealment, and forbidden knowledge. They are often feared due to their close relationship with necrotic energies."],
	"Gloomling": ["Humanoid", "20ft", "Umbral Dodge: Turn invisible in darkness for 1 round (3 AP, Free Action). | Shadow Sight: 120ft magical/nonmagical darkvision.", "Babel, Choice", "Gloomlings are shadowy, with indistinct features and eyes that gleam in the dark.", "Gloomlings are shaped by themes of stealth, illusion, fear, and concealment. Their communities are secretive and insular, valuing cunning and the pursuit of hidden truths."],
	"Skulkin": ["Humanoid (Undead/Small)", "20ft", "Crawlspace: Squeeze through 6-inch gaps. Advantage on Sneak and resistance to bludgeoning area effects. | Gnawing Grin: Curse creature within 30ft to steal its healing and redirect your damage (1/LR).", "Babel, Necril", "Skulkin drift through the margins of the living world like gleeful phantoms, drawn to silence, secrets, and the hollow spaces left behind by death.", "Skulkin communities are secretive and value cunning, trickery, and the gathering of hidden knowledge."],
	"Cragborn Human": ["Humanoid", "20ft", "Stonecunning: Advantage to identify stonework. Detect hidden stone doors within 5ft (1/SR). | Earth's Embrace: Advantage vs prone. +1 AC and immovability while on stone/earth.", "Babel, Dwarvish", "Cragborn are squat, thick-skinned folk with jagged features and gravelly voices.", "Cragborn culture is shaped by resilience and resourcefulness, thriving in difficult terrains. Their communities value strength, endurance, and a close connection to the land."],
	"Gravari": ["Humanoid", "20ft", "Stone's Endurance: Reduce damage by 1d12 + VIT (VIT times/SR). | Stone Sense: Advantage to detect stone traps/doors. Mason's tools proficiency.", "Babel, Terran", "Gravari are sturdy and broad, with stone-like skin in earthy tones and features reminiscent of carved statues.", "Gravari culture values strength, endurance, and stability, drawing inspiration from their stone-like nature. They build societies emphasizing tradition and communal support."],
	"Graveleaps": ["Humanoid (Reptilian)", "20ft", "Stoneclimb: Climb speed = Walk speed. Advantage on rocky climbs. | Gravebound Leap: Triple jump distance.", "Babel, Reptilian", "Graveleaps are small, lizard-like humanoids with stony, mottled scales and luminous eyes, renowned for their ability to leap great distances and cling to sheer canyon walls.", "Leapers are community-oriented, living in tight-knit burrows. Their society values agility, cooperation, and adaptability."],
	"Shardkin": ["Humanoid", "20ft", "Crystal Resilience: Bend light for 1 min (+3 AP committed) for Stealth advantage. | Harmonic Link: Form mental link with 3 creatures (1 mile range, 1hr).", "Babel, Shardtongue", "Shardkin are humanoids with crystalline skin and angular features, their bodies refracting light and often shimmering with inner color.", "Shardkin culture emphasizes unity, durability, and the beauty found in their crystalline heritage."],
	"Boreal Human": ["Humanoid (Cold/Wind)", "20ft", "Winter Breath: 15ft cube freezing wind deals 2d4 cold damage (3 AP). | Icewalk: Ignore snow/ice difficult terrain. Advantage vs prone on ice.", "Babel, Frigian", "Forged in the deep polar winds and ancient glaciers, the Borealborn humans are regal and remote.", "Boreal Human culture values resilience, cooperation, and resourcefulness in harsh frozen regions. Traditions center around warmth, storytelling, and preservation through long winters."],
	"Frostborn": ["Humanoid", "20ft", "Cold Resistance: Release frost burst on melee hit (2 AP, DC 10+VIT Speed save). | Icewalk: +2d4 cold damage to attacks for 1 min (1/SR).", "Babel, Frigian", "Frostborn have pale blue skin, icy hair, and a chill that follows them.", "The Frostborn endure in the harshest reaches of the world. Communities are bound by necessity, with survival hinging on strict cooperation. Resilience and self-reliance are prized above all."],
	"Glaceari": ["Humanoid (Ice)", "20ft", "Frozen Veil: Surround in icy mist for 1 min, attacks have disadvantage (1/LR). | Chillblood: Cold resistance. Commit AP to lower temperature in 10ft radius.", "Babel, Frigian", "Glaceari are beings of frost and patience, with skin that is translucent like packed snow.", "Glaceari embody patience and endurance, reflecting the slow, persistent nature of winter. Their culture centers around resilience, contemplation, and harmony with the cold."],
	"Nimbari": ["Humanoid (Elemental/Air)", "20ft", "Stormcall: 15ft burst dazes creatures (DC 10+SPD Speed save, 3 AP). | Summon Cloud: Hover 10ft above ground and ignore terrain.", "Babel, Auran", "Their bodies appear ethereal, composed of mist and vapor made solid, and they often hover about a foot above the ground.", "Nimbari society is likely shaped by themes of freedom, movement, and adaptability, with customs that honor the ever-changing nature of the sky."],
	"Tombwalker": ["Humanoid (Undead)", "20ft", "Gravebind: Absorb 1d4+DIV HP from creature within 30ft (DC 10+DIV VIT save, 3 AP). | Deathless Endurance: Drop to 1 HP instead of 0 once per long rest.", "Babel, Necril", "Tombwalkers are gaunt, death-touched humanoids wrapped in ancient burial cloth and etched with glowing runes.", "Tombwalkers are often found wandering crypts or serving as guardians of forgotten graves, bound by pacts with the dead."],
	"Chokeling": ["Humanoid (Fungal/Poison)", "20ft", "Sporespit: 10ft cube silence spores (DC 10+VIT VIT save, 3 AP). | Rotborn: Poison resistance. Decay small organic objects (1/LR).", "Babel, Sporetalk", "Chokelings resemble hunched, fungal silhouettes, their forms cloaked in ragged layers of spongy growths that pulse faintly with each breath.", "Chokelings possess a unique means of communication, fostering close-knit communities that rely on alternative forms of expression shaped by their fungal nature."],
	"Crimson Veil": ["Humanoid (Vampiric)", "20ft", "Bloodletting Touch: Unarmed hit heals for half damage (3 AP). | Velvet Terror: Advantage on Speechcraft in formal settings. Charm/Frighten nearby creatures.", "Babel, Vampiric", "Crimson Veil are elegant and venomous, with a vampiric allure. Socialites who feed off admiration and blood.", "Crimson Veil thrive in environments where they can interact and influence others. Their vampiric tendencies are balanced by their need for social engagement."],
	"Jackal Human": ["Humanoid (Human)", "20ft", "Tomb Sense: Necrotic resistance. Detect hidden undead/traps/passages (1/LR). | Desert Cunning: Advantage on arid Survival. Foraging always yields 1 ration.", "Babel, Necril", "Jackals possess lean, angular physiques with sharp facial features and alert, expressive eyes.", "Their culture focuses on survival amidst constant threats from the undead and the unforgiving desert. They are vigilant, resourceful, and attuned to the dangers and mysteries of their homeland."],
	"Whisperspawn": ["Humanoid (Psionic/Shadow)", "20ft", "Mindscratch: 2d4 psychic damage + Disadvantage on Intellect check (1/SR). | Voice Like Dust: Telepathy within 30ft (must whisper).", "Babel, Whispering", "Whisperspawn appear as slender, shadow-wreathed figures, their outlines blurred as if seen through a veil of mist.", "Whisperspawn culture is deeply tied to secrecy, subtlety, and the unseen realms of thought and shadow."],
	"Gravemantle": ["Construct", "20ft", "Magnetic Grip: Reduce SP cost of metal telekinesis by 2. | Gravitational Leap: Double speed and fly in straight lines for 1 min (1/SR).", "Babel, Mechan", "Gravemantles are sentient armor frames forged with wiry cords, their minds sharpened like hidden blades.", "Gravemantles are likely shaped by their origins as sentient constructs, serving as guardians. Their culture emphasizes vigilance, duty, and the mastery of traps or defensive tactics."],
	"Nightborne Human": ["Humanoid (Shadow-Aligned)", "20ft", "Veilstep: Teleport 20ft in darkness (3 AP). | Creeping Dark: Advantage on Sneak/Insight at night. Shadow-invisibility (1/LR).", "Babel, Umbral", "Nightborne Humans are veiled in darkness and born of half-forgotten omens. They drift through shadow and legend.", "Nightborne are associated with themes of stealth, illusion, fear, and concealment. They draw power from the shadows of forgotten gods."],
	"Snareling": ["Humanoid (Trapborn)", "20ft", "Ambusher's Gift: Initiative advantage. Draw weapon part of initiative. | Tangle Teeth: Melee hit reduces target speed by 10ft.", "Babel, Snaretongue", "Snarelings are wiry, sharp-limbed humanoids whose bodies seem built for sudden motion and hidden violence.", "Snareling culture revolves around ambush, preparation, and environmental mastery. Patience and planning are valued above brute strength."],
	"Blightmire": ["Ooze (Corrupted Arcane)", "20ft", "Toxic Seep: 10ft aura deals 1 poison damage. | Absorb Magic: Reaction to gain Temp HP from spell targeting you (1/SR).", "Babel, Mirecant", "Blightmires are living masses of corrupted magical sludge, their bodies rippling with unstable color and half-dissolved shapes.", "Blightmire culture is shaped by survival in magically poisoned wastelands. They value endurance, adaptation, and the ability to siphon strength from the forces that would destroy others."],
	"Dregspawn": ["Humanoid (Abyssal Mutant)", "20ft", "Mutant Grasp: +5ft reach. Increase reach by another 5ft (VIT times/SR). | Aberrant Flexibility: Squeeze through 6-inch gaps. End conditions (1/SR).", "Babel, Deepgroan", "Dregspawn are chaotic beings with bodies that seem to defy normal anatomy, their limbs bending the wrong way.", "Dregspawn culture is born from rejection, mutation, and survival at the edge of ruined places. They value adaptability, toughness, and mutual recognition among the broken."],
	"Nullborn": ["Humanoid (Voidborn)", "20ft", "Void Aura: 15ft null-aura (1/LR). 50% spell failure and daze/confuse chance. | Devour Essence: Regain SP equal to DIV when killing a creature.", "Babel, Nullscript", "Nullborn are shadowy, vaguely humanoid figures with featureless faces and bodies that seem to absorb light.", "Nullborn culture is defined by absence, secrecy, and the slow erosion of magical certainty. They gather in silent conclaves devoted to studying magical failure and the pull of the Void."],
	"Shardwraith": ["Undead (Arcane Specter)", "20ft", "Crystal Slash: 15ft cube razor shards (1/SR, DC 10+DIV SPD save). | Spectral Drift: Move through solid objects for 1d4 force damage.", "Babel, Shardtongue", "Shardwraiths are gaunt, translucent specters threaded with jagged, glowing crystal shards.", "Shardwraith culture is built from predation and scavenging in the ruins of the Arcane Collapse. Dominance belongs to the strongest or most cunning."],
	"Galesworn Human": ["Humanoid", "20ft", "Wind Step: Jump distance doubled. Once per long rest, 1 min wind cloak (ranged disadvantage). | Gustcaller: For 3 AP, push object 10ft or creature 5ft (DC 10+DIV STR save).", "Babel, Auran", "Galesworn Humans are lean, weathered people shaped by constant wind and open sky.", "Galesworn culture is defined by endurance, mobility, and respect for the forces of the air. Their communities are often semi-nomadic, built around caravans and wind-carved paths."],
	"Pangol": ["Humanoid (Beast)", "20ft", "Natural Armor: Base AC 13. Gain +5 AC as reaction when hit (Speed times/LR). | Curl Up: Once per short rest, reaction curl for immunity (speed 0, blind).", "Babel, Pangolish", "Pangols are stocky, scale-covered humanoids with powerful claws and layered armored hides that overlap like living shields.", "Pangol culture values caution, patience, and mutual protection. Communities are often built into stone hollows or fortified burrows."],
	"Porcelari": ["Humanoid (Construct)", "20ft", "Shatter Pulse: Release 1d6 force damage in 5ft radius on critical hits. | Gilded Bearing: Advantage on Speechcraft in formal settings.", "Babel, Celestial", "Porcelari are elegant construct-humanoids fashioned from smooth ceramic bodies traced with gold, silver, or painted enamel.", "Porcelari culture is steeped in ceremony, aesthetics, and social precision. They believe beauty and order are forms of strength in a fractured world."],
	"Prismari": ["Humanoid", "20ft", "Chromatic Shift: Once per short rest, blend color for advantage on Sneak. | Prismatic Reflection: Once per long rest, reaction refract light for 1 min resistance.", "Babel, Prismal", "Prismari are striking humanoids whose skin, eyes, or hair catch and scatter light in shifting bands of color.", "Prismari culture is shaped by light, perception, and the idea that truth is rarely singular. They celebrate artistry, personal expression, and the symbolic meaning of color."],
	"Rustspawn": ["Construct (Corrosion-Infused)", "20ft", "Corrosive Aura: Melee weapons hitting you take -1 damage and use triple HP. | Ironrot: Resistance to acid. Acid damage empowers next melee attack (+1d4).", "Babel, Mechan", "Rustspawn are corroded construct beings whose bodies are built from pitted iron and oxidized plating.", "Rustspawn culture is rooted in endurance, salvage, and the acceptance of decay. Among their kind, damage is treated as a mark of hard-earned survival."],
	"Dustborn": ["Humanoid (Sand/Earth)", "20ft", "Dust Shroud: Once per long rest, 10ft swirling sand radius (disadvantage vs you, attack action 2d4). | Dryblood: Resistance to dehydration and heat exhaustion. Forage 1 ration always.", "Babel, Durespeech", "Dustborn are weathered humanoids whose skin resembles compacted sand, dry clay, or wind-smoothed stone.", "Dustborn culture is defined by endurance, memory, and respect for the dead and the land. Many serve as guides, gravekeepers, or wanderers."],
	"Glassborn": ["Humanoid (Elemental)", "20ft", "Shatter Pulse: Once per long rest, struck by melee releases burst (DC 10+DIV VIT save). | Prism Veins: Resistance to radiant. Flare body for +1d4 saves for allies within 15ft.", "Babel, Crystaltongue", "Glassborn are translucent humanoids whose bodies resemble living crystal and desert glass.", "Glassborn culture is shaped by fragility, brilliance, and the harsh beauty of the desert. They value clarity, beauty, and inner strength."],
	"Gravetouched": ["Humanoid (Undead-Touched)", "20ft", "Death's Whisper: Once per long rest, speak with corpse for 1 minute. | Chill of the Grave: Resistance to necrotic. Move through grave terrain.", "Babel, Necril", "Gravetouched are pallid, solemn humanoids whose features carry the stillness of the grave without fully belonging to death.", "Gravetouched culture is intertwined with burial rites and reverence for those who have passed. They value restraint, remembrance, and the belief that death is to be listened to."],
	"Madness-Touched Human": ["Humanoid (Mutated)", "20ft", "Unstable Mutation: Advantage on any check, then disadvantage on next two. Nat 20 grants monster ability. | Fractured Mind: Resistance to psychic. Take insanity levels to lower critical hit required roll.", "Babel, Choice (+1 random)", "Madness-Touched Humans bear visible signs of mental and magical fracture, with twitching expressions and eyes that focus on things no one else can perceive.", "Madness-Touched culture is fragmented and unpredictable. Some gather in strange enclaves where instability is normalized and visionary madness is treated as revelation."],
	"Candlites": ["Humanoid (Elemental)", "20ft", "Luminous Soul: Shed 10ft bright / 10ft dim light. Extinguish/reignite as free action. | Waxen Form: For 3 AP, teleport 30ft by melting and reforming.", "Babel, Ignan", "Candlites are soft-glowing humanoids with waxen skin, flame-lit eyes, and bodies that seem half-solid and half-molten.", "Candlite culture centers on light, sacrifice, and the fragile persistence of warmth in terrible places. They value vigilance and the belief that even a small light can remain defiant."],
	"Flenskin": ["Humanoid (Aberration/Exposed)", "20ft", "Agonized Form: Attacker within 100ft takes 1 psychic damage. | Pain Made Flesh: Once per long rest, delay all pain/damage/conditions for 1 minute.", "Babel, Paincant", "Flenskin are horrifying humanoids whose exposed musculature and nerves are somehow sustained without death.", "Flenskin culture is shaped by suffering, endurance, and the normalization of torment. They prize resilience above all else."],
	"Hellforged": ["Construct (Infernal)", "20ft", "Infernal Stare: Once per long rest, creature within 5ft take 1d4 fire/turn for 1 minute. | Demonic Alloy: Resistance to fire and cold. Advantage vs environmental heat.", "Babel, Infernic", "Hellforged are brutal construct beings built from blackened infernal metal and furnace-like cores that pulse with captured fire.", "Hellforged culture is defined by hierarchy, industry, and the weaponization of purpose. Strength, obedience, and durability are deeply valued."],
	"Obsidian Seraph": ["Celestial (Corrupted)", "20ft", "Infernal Smite: Once per short rest, +2d6 fire/radiant for 10 min. Consumes wings. | Cracked Resilience: Resistance fire/radiant/necrotic. Damage taken empowers next attack (+1d4).", "Babel, Celestine", "Obsidian Seraphs are fallen celestial beings with dark glasslike wings, fractured halos, and bodies veined with light trapped beneath volcanic black surfaces.", "Obsidian Seraph culture is shaped by ruin, zeal, and the memory of grace twisted by infernal influence. Communities are often rigid and driven by ideas of judgment and transformation."],
	"Scourling Human": ["Humanoid (Demonic Spawn)", "20ft", "Whip Lash: For 3 AP, 15ft spectral lash pulls creature (DC 10+DIV Speed save). | Fury of the Marked: When below 50% HP, deal extra damage equal to missing HP on melee.", "Babel, Infernic", "Scourling Humans are marked by infernal lineage through horns, burning eyes, branded flesh, or shadowed veins.", "Scourling culture is forged in struggle, aggression, and the constant pressure of living under infernal marks. They are taught that pain can be turned outward."],
	"Ashenborn": ["Humanoid (Cursed Flame)", "20ft", "Cursed Spark: Once per short rest, +1d4 fire damage to attacks for 1 minute. | Burnt Offering: Regain 2 SP when reduced to 0 HP. Death is delayed by 1 round.", "Babel, Ignan", "Ashenborn are soot-marked humanoids whose skin bears the look of something once burned and never fully extinguished.", "Ashenborn culture is shaped by endurance, sacrifice, and the belief that suffering can become strength if survived long enough."],
	"Sandstrider Human": ["Humanoid", "20ft", "Desert Walker: Ignore sand terrain. Once per long rest, 10ft sand cloud (disadvantage). | Heat Endurance: Advantage vs heat exhaustion. Twice as long without water.", "Babel, Terran", "Sandstrider Humans are lean, sun-scarred wanderers with weathered skin and sharp eyes.", "Sandstrider culture is built on mobility, survival, and practical wisdom earned beneath relentless suns. They value self-reliance and hospitality among travelers."],
	"Taurin": ["Humanoid (Beast)", "20ft", "Gore: Vitality times per short rest, 1d6 horn attack as free action. | Stubborn Will: Once per short rest, reroll failed save vs move/prone.", "Babel, Tauric", "Taurin are broad, horned humanoids with powerful frames and heavy muscles.", "Taurin culture values strength, resolve, and the dignity of meeting hardship head-on. Stubbornness is not seen as a flaw but as a virtue."],
	"Ursari": ["Humanoid (Beast)", "20ft", "Mighty Build: Count as size larger for carry/grapple. Wield heavy weapons in one hand. | Hibernate: Once per long rest, fully heal and gain bonus HP (unconscious 1 min).", "Babel, Ursan", "Ursari are massive, bear-like humanoids covered in thick fur, with broad shoulders and deep-set eyes.", "Ursari culture is rooted in endurance, kinship, and a deep respect for cycles of rest, survival, and violence. Great strength is expected to be guided by discipline."],
	"Volcant": ["Humanoid (Elemental)", "20ft", "Lava Burst: Reaction deal 1d4 fire to attacker. Spend AP to increase damage. | Molten Core: Resistance fire/cold. Walk across molten surfaces for 1 min.", "Babel, Ignan", "Volcants are elemental humanoids with skin like dark stone split by glowing seams of magma.", "Volcant culture is shaped by power, pressure, and the harsh discipline of surviving in lands where fire constantly threatens. They value inner strength and emotional control."],
	"Emberkin": ["Humanoid", "20ft", "Blazeblood: Resistance fire. Spend AP to raise area temperature. +1d4 fire to melee. | Soot Sight: See through smoke/fog. Once per long rest, 10ft smoke cloud centered on you.", "Babel, Ignan", "Emberkin are fiery-featured humanoids with warm-toned skin, glowing eyes, and hair that often resembles smoke, sparks, or banked flame.", "Emberkin culture values passion, intensity, and the ability to thrive under pressure. They prize courage, bold self-expression, and the belief that a life worth living should burn brightly."],
	"Saurian": ["Humanoid (Reptile)", "20ft", "Tail Lash: Reaction deal 1d4 bludgeoning and push attacker 5ft. | Scaled Resilience: Resistance fire/cold. Permanent +1 AC. Reaction reduce damage 1d4+VIT.", "Babel, Draconic", "Saurians are scaled reptilian humanoids with heavy tails and bodies built for endurance and combat.", "Saurian culture is defined by resilience, martial discipline, and the belief that survival belongs to those who adapt without breaking."],
	"Stormclad": ["Humanoid (Lightning/Air)", "20ft", "Shock Pulse: For 1 SP, 3d6 lightning in 10ft radius (DC 10+DIV VIT save). | Arc Conductor: Resistance lightning/thunder. Fly at regular speed during storms.", "Babel, Thundric", "Stormclad are striking humanoids whose hair lifts with static, whose eyes flash like stormlight, and whose skin bears branching patterns like lightning scars.", "Stormclad culture revolves around force, motion, and the reverence of storms as both danger and revelation. They value boldness, momentum, and channeling chaos into action."],
	"Sunderborn Human": ["Humanoid (Butcher's Lineage)", "20ft", "Blood Frenzy: Enemy to 0 HP grants extra attack with advantage. | Sanguine Immortality: Death Denied (spend SP to heal), Limb Regrowth (2 SP), Hibernation (SP per day).", "Babel, Orc", "Sunderborn Humans are brutal-looking people marked by heavy scarring, dense musculature, and an unsettling vitality.", "Sunderborn culture is built around violence, survival, and the belief that flesh is meant to be broken and remade stronger. They respect ferocity and the refusal to die."],
	"Ashrot Human": ["Humanoid (Burned Wraith)", "20ft", "Smoldering Aura: Basic action toggle 1 fire damage to adjacent enemies. | Sootskin: Immune to smoke vision impairment and suffocation from smoke/ash.", "Babel, Ignan", "Ashrot Humans appear as fire-scarred survivors whose skin is gray with soot and whose features look half-consumed by old burns.", "Ashrot culture is shaped by catastrophe, survival, and intimate familiarity with destruction. They value grim perseverance and mutual dependence."],
	"Cindervolk": ["Humanoid", "20ft", "Ember Touch: Resistance fire. Ignite flammable small objects as free action. | Smoldering Glare: Once per long rest, 10ft radius sheds light and deals 1d4 fire/turn.", "Babel, Ignan", "Cindervolk are dark-featured humanoids touched by ember and smoke, their eyes carrying a persistent furnace glow.", "Cindervolk culture centers on fire as tool, threat, and symbol of identity. They value self-mastery, industriousness, and the ability to carry destructive power without letting it consume what is worth preserving."],
	"Drakari": ["Humanoid (Dragon)", "20ft", "Draconic Awakening: Once per long rest, partial transform (large size, wings, +1d4/level elemental melee). | Breath Weapon: For 3 AP, 15ft cone elemental damage (2d6+level, 4d6 if awakened).", "Babel, Draconic", "Drakari are dragon-blooded humanoids with scaled skin, predatory eyes, and features that hint at the immense creatures whose essence runs through them.", "Drakari culture is shaped by legacy, dominance, and the tension between mortal life and draconic inheritance. Awakening one's deeper nature is seen as a test of worthiness."],
	"Obsidian": ["Humanoid", "20ft", "Shard Skin: Melee bludgeoning damage reflects 1d4 thunder damage to attacker. | Magma Blood: Resistance elemental damage. Heal 1d4 when taking elemental damage.", "Babel, Ignan", "Obsidians are sleek, dark-bodied humanoids whose skin resembles polished volcanic glass.", "Obsidian culture is defined by hardness, beauty, and the dangerous value of controlled force. They believe pressure and heat can refine a being into something sharper and stronger."],
	"Scornshard": ["Construct (Shardbound)", "20ft", "Fracture Burst: Melee weapon hit releases burst (DC 10+VIT Speed save vs blind). | Crackling Edge: Unarmed strikes are slashing and deal +Speed damage once per turn.", "Babel, Crystaltongue", "Scornshards are jagged construct beings assembled from bound crystal fragments and sharp-edged magical seams.", "Scornshard culture is built around fracture, anger, and the use of brokenness as strength. They value ferocity, speed, and the conviction that even something shattered can still cut deep."],
	"Abyssari": ["Humanoid (Aquatic)", "20ft", "Bioluminescent Veins: Glow 10ft. Light pulse reveals invisible/hidden for 1 min. | Pressure Hardened: Resistance cold/crushing. Immune to pressure effects.", "Babel, Deepcant", "Abyssari are deep-water humanoids with dark, smooth skin traced by bioluminescent veins that pulse softly like living constellations.", "Abyssari culture is shaped by the immense pressures of the ocean depths. They value control, silence, and the ability to endure what others cannot."],
	"Mireling": ["Humanoid", "20ft", "Slippery: Advantage vs grapples/restraints. Once per long rest escape as free action. | Swamp Sense: Hold breath 1hr. Advantage on Survival in swamp/marsh.", "Babel, Mirecant", "Mirelings are slick-skinned, marsh-adapted humanoids with webbed digits and features softened by life in wetlands.", "Mireling culture is rooted in patience, adaptation, and close familiarity with marshland life. They value practical knowledge and the quiet resilience needed to thrive in unwelcoming places."],
	"Moonkin": ["Humanoid", "20ft", "Lunar Blessing: +1d6 radiant in moonlight. Lunar Radiance emits 10ft light pulse. | Lunar Radiance: Allies gain +1 vs fear/charm while in your light.", "Babel, Elvish", "Moonkin are pale, luminous humanoids whose features seem touched by silver light, with eyes that gleam like moonlit water.", "Moonkin culture is shaped by reverence for cycles, quiet guidance, and the symbolism of moonlight as protection in darkness. They value calm, intuition, and gentle strength."],
	"Tiderunner Human": ["Humanoid", "20ft", "Wave Rider: Two move actions in water for cost of 1. Breathe in saltwater. | Saltborn: Immunity to cold. 3 AP exhale cone of freezing brine (2d6 cold + slow).", "Babel, Aquan", "Tiderunner Humans are hardy coastal and ocean-going people with salt-toughened skin and powerful limbs.", "Tiderunner culture is built around mobility, seafaring, and an intimate relationship with tides, storms, and saltwater survival."],
	"Driftwood Woken": ["Construct (Water/Nature)", "20ft", "Ebb and Flow: Move 10ft without opportunity (Speed times/LR). | Saltsoaked Form: Resistance fire/cold. Breathe in saltwater without issues.", "Babel, Aquan", "Driftwood Woken are construct beings formed from waterlogged timber, coral growth, kelp binding, and sea-worn fragments.", "Driftwood Woken culture is shaped by salvage, memory, and the strange second life granted to what the sea refuses to surrender. They value resilience and transformation."],
	"Fathomari": ["Humanoid", "20ft", "Amphibious: Breathe air/water. Resistance cold. Put out fires within 15ft. | Deep Sight: See in murky water or magical darkness out to 60ft.", "Babel, Aquan", "Fathomari are sleek aquatic humanoids with smooth skin and graceful bodies built for movement through deep and uncertain waters.", "Fathomari culture revolves around navigation, restraint, and mastery of environments where visibility and certainty are limited."],
	"Hydrakari": ["Humanoid (Aquatic, Reptile)", "20ft", "Hydra's Resilience: Reduce damage 1d6+VIT once/SR. Negate attack by sacrificing limb (1/LR). | Amphibious: Breathe air/water. Resistance cold.", "Babel, Aquan", "Hydrakari are powerful reptilian aquatic humanoids with scaled hides and regenerative flesh.", "Hydrakari culture values survival, dominance, and the ruthless practicality demanded by dangerous underwater ecosystems."],
	"Kelpheart Human": ["Humanoid (Plant, Aquatic)", "20ft", "Tidebind: For 3 AP, entangle creature within 10ft (DC 10+STR Strength save). | Ocean's Embrace: Submerged in saltwater heals 1 HP/turn. Breathe saltwater only.", "Babel, Aquan", "Kelpheart Humans are sea-grown people whose bodies bear signs of plant and oceanic adaptation.", "Kelpheart culture is rooted in symbiosis with the ocean and the patient endurance of marine plant life. They value healing, persistence, and growing together."],
	"Trenchborn": ["Humanoid (Aberration)", "20ft", "Abyssal Mutation: Reroll failed mind-save. Reflection effect on success. | Darkwater Adaptation: 60ft darkvision. Breathe air/water. Advantage on Perception submerged.", "Babel, Abyssal", "Trenchborn are unsettling humanoids warped by the deepest waters, their bodies marked by alien asymmetry and unnatural eyes.", "Trenchborn culture is shaped by mutation, survival, and prolonged contact with the unknowable regions beneath the sea."],
	"Cloudling": ["Humanoid (Elemental)", "20ft", "Float: Hover 10ft off ground (half speed). Fly at full speed for -3 Max AP cost. | Mist Form: Once per short rest, become intangible for 1 minute (1 SP after).", "Babel, Auran", "Cloudlings are airy, light-boned humanoids with soft, pale features and bodies that seem half-formed from mist and moving sky.", "Cloudling culture is shaped by freedom, transience, and the acceptance that nothing remains in one form forever. They value lightness, flexibility, and the ability to change course."],
	"Rotborn Herald": ["Humanoid (Plaguehost)", "20ft", "Festering Aura: Adjacent enemies take -2 to healing received. | Diseasebound: Immune to disease/poison. Unarmed attacks deal +1d4 poison damage.", "Babel, Plaguecant", "Rotborn Heralds are sickly, decaying humanoids whose flesh carries visible signs of infection, corruption, and unnatural survival amid rot.", "Rotborn culture is built around endurance through corruption. They ritualize, study, and weaponize plague, believing endurance of contagion grants an ugly but undeniable form of power."],
	"Tidewoven": ["Humanoid (Water)", "20ft", "Surge Step: For 1 SP, double speed and ignore opportunity attacks until next turn. | Deep lung: Breathe underwater. Advantage on swim checks.", "Babel, Aquan", "Tidewoven are fluid-featured humanoids whose bodies seem shaped by currents, with smooth skin and flowing movements.", "Tidewoven culture is centered on motion, adaptability, and the belief that survival belongs to those who flow rather than break."],
	"Venari": ["Humanoid (Beast)", "20ft", "Pack Instinct: Advantage on attack if ally is within 5ft of target. | Hunter's Focus: Mark target for 1hr (+1d4 Perception/Survival, +1d6 damage).", "Babel, Venari", "Venari are sharp-featured beastfolk hunters with keen eyes, agile bodies, and predatory instincts.", "Venari culture is deeply rooted in the hunt, cooperation, and the disciplined use of instinct in dangerous lands. They value focus, loyalty, and the ability to read terrain and prey."],
	"Weirkin Human": ["Humanoid", "20ft", "Weird Resilience: Once per long rest, auto-succeed on save vs charm/fear/confuse. | Eerie Insight: Advantage on Intellect checks involving magical or anomalous phenomena.", "Babel, Abyssal", "Weirkin Humans are ordinary in outline but wrong in detail, with expressions that linger too long and eyes that seem to notice impossible things.", "Weirkin culture is shaped by close contact with anomalies and altered places. They value adaptability, perception, and the ability to keep functioning when reality becomes unreliable."],
	"Bilecrawler": ["Beast (Aberrant)", "20ft", "Corrosive Slime: Ending turn in crawler's space deals 1d4 acid and -1 AC. | Bile Sense: Locate and telepathically communicate with diseased/poisoned within 30ft.", "None, Telepathic", "Bilecrawlers are grotesque aberrant beasts slick with acidic mucus, their bodies bloated and many-limbed.", "Bilecrawler behavior is shaped by contamination, predation, and proximity to sickness. They gather where decay pools thickest, surrounding disease and biological ruin."],
	"Huskdrone": ["Undead (Mutated)", "20ft", "Gas Vent: Explode on death (2d6 poison in 10ft). Sacrifice HP to trigger manually. | Obedient: Immune to charm/fear/possession. Max AP cost reduction spread to allies.", "Babel, Broken Babel", "Huskdrones are rotting, mutated undead with swollen bodies, ruptured flesh, and internal sacs of poisonous gas.", "Huskdrone existence is defined by servitude, corruption, and the loss of self beneath external control. Their culture, if it can be called that, is one of obedience and contagion."],
	"Bloatfen Whisperer": ["Humanoid (Aberrant Caster)", "20ft", "Rot Voice: For 3 AP, 20ft burst frightened until next turn (DC 14 Divinity save). | Leech Hex: Once per turn, sap 1d6 HP from creature within 30ft.", "Babel, Deepgut", "Bloatfen Whisperers are swollen, marsh-haunted casters whose bodies carry the visible marks of rot and prolonged exposure to poisonous wetlands.", "Bloatfen Whisperer culture is built around corruption, fear, and the weaponization of decay through word and ritual. They value secrecy, endurance, and the ability to turn weakness into instruments of control."],
	"Filthlit Spawn": ["Ooze (Sentient)", "20ft", "Memory Echo: While active (-3 Max AP), mimic appearance/voice of creature seen for 1 min. | Toxic Form: Immune poison/acid. Grapplers/touchers take 1d4 poison damage.", "Babel, Plaguecant (telepath)", "Filthlit Spawn are sentient ooze-beings whose bodies ripple with foul color and half-formed features stolen from things they have observed.", "Filthlit Spawn culture is fluid, parasitic, and shaped by memory theft, imitation, and survival in profoundly toxic environments."],
	"Hagborn Crone": ["Humanoid (Fey Caster)", "20ft", "Hex of Withering: For 2 AP, 20ft burst disadvantage on attacks/checks (DC 10+DIV). | Witch's Draught: For 3 AP, sap 1d6 HP from creature. Share healing with other crones.", "Babel, Witchtongue", "Hagborn Crones are eerie, weathered spellcasters whose features blend mortal age with fey malice.", "Hagborn culture revolves around covens, secret rites, and the weaving of power through curse, bargain, and shared occult practice."],
	"Aetherian": ["Humanoid", "20ft", "Ethereal Step: For 1 SP, become intangible until end of next turn as move action. | Veiled Presence: Once per rest, advantage on Sneak for 1 minute.", "Babel, Aetheric", "Aetherians are ethereal and slightly translucent, with a ghostly presence and features that seem to blur at the edges.", "Aetherian culture is defined by longing and detachment. They form quiet, contemplative communities near places where worlds feel close, drawn to art, music, and philosophy."],
	"Convergents": ["Humanoid (Convergent)", "20ft", "Adaptive Convergence: Mimic lineage appearance/traits upon contact. Persists until reset. | Convergent Synthesis: For 1 SP/creature, integrate traits of all creatures touched this round.", "Babel, Choice", "Convergents are an anomaly among lineages, born without inherent form. In their natural state, they appear as smooth, mannequin-like humanoids with indistinct features.", "Convergent culture does not exist in a unified sense. They are cultural mirrors, either limiting contact to preserve continuity or seeking constant interaction. They value adaptation and identity through experience."],
	"Dreamer": ["Humanoid", "20ft", "Dreamwalk: Once per long rest, interact with creature's dreams (range 100ft). | Lucid Mind: Immune to magical sleep. Soul wanders 15ft to stand guard while sleeping.", "Babel, Sylvan", "Dreamers are ethereal beings with shifting pastel skin, nebula-like eyes, and forms that seem to blur at the edges.", "Dreamer culture is one of introspection, wandering thought, and gentle melancholy. They are drawn to reflection, art, sleep rituals, and the exploration of the mind as a landscape."],
	"Riftborn Human": ["Humanoid", "20ft", "Phase Step: For 3 AP, move through 5ft solid object. | Flicker: Once per short rest, teleport 15ft in addition to normal move action.", "Babel, Planar", "Riftborn Humans are marked by subtle distortions in body and motion, with outlines that seem to jump, blur, or lag a half-second behind where they should be.", "Riftborn culture is shaped by proximity to planar fractures and spatial anomalies. Communities are pragmatic and highly mobile, built around contingency rather than permanence."],
	"Shadewretch": ["Humanoid (Voidshadow)", "20ft", "Unseen Hunger: Regain 2 SP upon reducing sentient creature to 0 HP. | Twilight Stalker: Climb in dim light. Silent glide + Shadowmeld reaction (intangible).", "Babel, Voidtongue", "Shadewretches are gaunt, shadow-cloaked humanoids whose forms seem thinned by darkness and hunger until they barely appear fully material.", "Shadewretch culture is shaped by predation, concealment, and grim intimacy with dim places. They value silence, patience, and mastery of hunger as a source of terrible strength."],
	"Umbrawyrm": ["Humanoid (Dragon/Shadow)", "20ft", "Void Step: For 1 SP, teleport up to 30ft into dim light or darkness. | Shadow Coil: Advantage on Sneak in darkness. 30ft magical darkvision.", "Babel, Draconic", "Umbrawyrms are draconic shadow-blooded humanoids with sleek dark scales, sharp features, and eyes that gleam like hidden embers beneath night.", "Umbrawyrm culture combines draconic pride with shadow-bound pragmatism. They value both personal power and the strategic use of secrecy."],
	"Corrupted Wyrmblood": ["Humanoid (Draconic/Cursed)", "20ft", "Corrupt Breath: For 3 AP, 15ft cone 2d4 necrotic + level (DC 10+VIT Vitality save). | Dark Lineage: Resistance to necrotic. Reduce creature to 0 HP deals 1d4 necrotic to another within 5ft.", "Babel, Draconic", "Corrupted Wyrmblood are draconic humanoids whose lineage has been twisted by curse, rot, or void-tainted influence.", "Corrupted Wyrmblood culture is shaped by inheritance, corruption, and the struggle to define oneself under the weight of tainted legacy."],
	"Hollowroot": ["Humanoid (Plant)", "20ft", "Rooted: Advantage on saves vs move/prone. | Sap Healing: Once per short rest, heal 1d8+level and remove one condition.", "Babel, Sylvan", "Hollowroots are plantlike humanoids with bark-textured skin, hollowed interiors, and bodies threaded with living sap and root networks.", "Hollowroot culture is grounded in persistence, renewal, and the slow endurance of living systems. They value stability, healing, and the belief that even hollowed things may take new root."],
	"Nihilian": ["Humanoid (Voidborn)", "20ft", "Entropy Touch: Basic action touch deals 1d4 necrotic and -1d4 to their next attack. | Unravel: Once per long rest, touch deals 1d6 necrotic/turn + prevents healing (DC 10+DIV VIT save).", "Babel, Voidtongue", "Nihilians are austere voidborn humanoids whose bodies seem stripped down to stark form, with muted features and darkened eyes.", "Nihilian culture is defined by detachment, entropy, and the contemplation of endings as a natural truth. They believe unraveling is sometimes the clearing away of illusion."],
	"Oblivari Human": ["Humanoid (Void-Essence)", "20ft", "Mind Bleed: Once per long rest, failed Intellect save takes 2d6 psychic and forgets allies for 1 min. | Null Mind: Immune to scrying/surveillance. Extend protection to touched ally for 1hr.", "Babel, Nullscript", "Oblivari Humans appear strangely muted, with pale skin and distant eyes that seem to look through the world rather than at it.", "Oblivari culture centers on mental discipline and the control of thought. They practice strict traditions of memory keeping and meditation to resist the creeping pull of the Void."],
	"Sludgeling": ["Humanoid (Ooze)", "20ft", "Amorphous Form: Squeeze through 6-inch gaps. Reaction to split into two identical forms when slashed. | Toxic Seep: For 3 AP, exude 5ft toxic aura for 1 minute (DC 10+VIT VIT save resists).", "Babel, Mirecant", "Sludgelings are viscous humanoid masses of shifting ooze whose forms constantly ripple and reform.", "Sludgeling communities form in damp caverns and alchemical runoff zones. Their culture is flexible and pragmatic, valuing survival and adaptation above rigid structure."],
	"Carrionari": ["Humanoid (Beast, Necrotic)", "20ft", "Death-Eater's Memory: Absorb memories from touched corpse (1/LR). Witness last 6s. | Wings of the Forgotten: Glide at foot speed. For 3 AP fly at foot speed for 1 round.", "Babel, Necril", "Carrionari are gaunt, vulturelike humanoids with ragged wings and hollow eyes that gleam with eerie intelligence.", "Carrionari culture treats death as a source of knowledge rather than tragedy. Ritual consumption of the memories of the dead is considered sacred."],
	"Disjointed Hounds": ["Beast (Warped Predator)", "20ft", "Shifting Form: Action switch to beast mode (+10ft speed, 40ft leap). | Warped Bite: On hit, target must VIT save or disoriented (disadvantage all checks for 1 min).", "Babel, Understand-only", "Disjointed Hounds are warped humanoid predators whose limbs bend and reset at impossible angles.", "Disjointed Hounds exist in loose hunting packs that roam unstable regions. Their culture is instinct-driven and predatory, valuing strength, speed, and coordinated pursuit."],
	"Lost": ["Undead (Temporal Echo)", "20ft", "Temporal Flicker: Once per long rest, become intangible for 1 minute. | Haunting Wail: For 3 AP, 15ft dissonant cry (INT check or stunned until next turn).", "Babel, Echoes", "The Lost appear as translucent figures whose forms flicker between moments in time.", "The Lost are remnants of lives that slipped between moments during catastrophic magical events. They spend their existence searching for fragments of their past lives."],
	"Gullet Mimes": ["Humanoid (Cursed Performer)", "20ft", "Mirror Move: For 3 AP reaction, copy physical action within 30ft. | Silent Scream: Once per long rest, force target to fail speech/casting for 1 min.", "Babel, Gesture", "Gullet Mimes appear as pale performers clad in exaggerated expressions painted across their faces.", "Gullet Mime culture is rooted in performance, imitation, and the manipulation of perception. Words are rarely spoken; instead, entire conversations unfold through gesture."],
	"Parallax Watchers": ["Aberration (Perceptual Warden)", "20ft", "Reality Slip: Once per short rest, teleport 30ft to dim light/shadow. | Unnerving Gaze: For 3 AP, 30ft range target becomes frightened for 1 min.", "Babel, Whispercant", "Parallax Watchers possess elongated forms and eyes that reflect impossible angles, as though viewing the world from several perspectives at once.", "Parallax Watchers serve as silent wardens of unstable spaces. Their society revolves around observation and containment, monitoring disturbances in the fabric of existence."],
	"Echo-Touched": ["Humanoid (Echo-Touched)", "20ft", "Resonant Form: Advantage vs magic. Once per short rest, mutate (4 SP effect) for 10 min. | Divine Mimicry: Once per long rest, mimic one lineage trait from creature within 30ft.", "Babel, Choice", "Echo-Touched appear mostly human, yet faint distortions ripple across their form as if they exist slightly out of phase with reality.", "Echo-Touched culture is shaped by uncertainty and adaptation. Many believe they carry fragments of multiple possible selves, viewing identity as fluid rather than fixed."],
	"Lifeborne": ["Humanoid (Abyssal)", "20ft", "Vital Surge: Healing pool = 4 x Level. Basic action touch restores HP. | Abyssal Glow: For 3 AP, 10ft glow heals allies 1d6+DIV and enemies make DIV save or disadvantage.", "Babel, Deepcant", "Lifeborne are beings infused with powerful biological vitality, their bodies marked by glowing veins and steady rhythmic pulses.", "Lifeborne culture values preservation of life and biological harmony. The ability to restore life is considered a sacred responsibility."],
	"Lanternborn": ["Humanoid", "20ft", "Guiding Light: For 3 AP free action, grant ally within 30ft advantage on save. | Glow: Shed 10ft bright light. Allies gain +1 AC (but you/they disadvantage on Sneak).", "Babel, Celestial", "Lanternborn have softly glowing skin and eyes, and their voices echo faintly like distant chimes heard through twilight.", "Lanternborn culture is shaped by reverence for the stars, ancestral memory, and the comforting power of inner light. They value wisdom, emotional depth, and the belief that inner light is both inheritance and responsibility."],
	"Luminar Human": ["Humanoid", "20ft", "Radiant Resistance: Resistance radiant. +1 saves for allies in bright light. | Beacon: Allies within 10ft advantage vs fear. Reaction to take on ally's fear once/SR.", "Babel, Celestial", "Luminar Humans are bright-featured people whose presence seems strengthened by illumination, carrying an almost reassuring clarity.", "Luminar culture values courage, protection, and the moral symbolism of standing as a light for others. They believe light is a duty, not merely illumination."],
	"Skysworn": ["Humanoid", "20ft", "Glide: Glide at foot speed. Land within 5ft after 20ft fall gives target disadvantage on attack. | Keen Sight: Advantage Perception (sight). For 3 AP, detect invisible/illusory within 30ft.", "Babel, Auran", "Skysworn are lithe, high-featured humanoids with wind-worn faces, sharp eyes, and bodies naturally balanced for height and open air.", "Skysworn culture is shaped by elevation, vigilance, and reverence for the open sky. They value precision, perception, and trusting the air without becoming careless."],
	"Starborn": ["Humanoid", "20ft", "Radiant Pulse: For 3 AP, 10ft burst blinds (DC 10+VIT Vitality save). | Cosmic Awareness: Advantage on checks about cosmos or navigation.", "Babel, Celestial", "Starborn are luminous humanoids whose eyes gleam like distant constellations and whose skin often carries subtle flecks like a night sky.", "Starborn culture is centered on celestial observation, destiny, and the reading of meaning in patterns beyond the mortal world."],
	"Auroran": ["Humanoid", "20ft", "Light Step: Ignore natural light terrain. Free action 10ft teleport to direct sunlight once/SR. | Dawn's Blessing: Advantage vs blind. Once per long rest, immune to blind for 1 minute.", "Babel, Celestial", "Aurorans are radiant humanoids whose features seem bathed in the first light of dawn, with warm luminous skin and bright eyes.", "Auroran culture is defined by renewal, optimism, and the sacred symbolism of first light. They value resilience, clarity of purpose, and the belief that something bright can still arrive after the longest darkness."],
	"Lightbound": ["Humanoid", "20ft", "Radiant Ward: Reaction to radiant damage to heal half and gain resistance for 1 min. | Flareburst: Once per short rest, melee hit deals +2d6 fire and blinds until end of next turn.", "Babel, Celestial", "Lightbound are intense, radiant humanoids whose bodies seem closely fused with blazing power.", "Lightbound culture revolves around endurance through brightness, channeling overwhelming force without being consumed. They believe light is not always gentle; brilliance can blind, burn, and defend."],
	"Runeborn Human": ["Humanoid (Construct)", "20ft", "Runic Surge: Once per long rest, add +1d4 to spell attack or save DC. | Mystic Pulse: Once per short rest, runes flare granting allies within 10ft bonus HP = Intellect.", "Babel, Runic", "Runeborn Humans are people whose flesh or artificial framework bears carved, inked, or glowing runes that pulse with structured magical force.", "Runeborn culture is built around inscription, magical order, and the belief that meaning can be fixed into the world through properly understood symbols. Runes are memory, law, inheritance, and living structure."],
	"Zephyrkin": ["Humanoid (Elemental)", "20ft", "Windstep: Speed times/SR move as free action and immune to opportunity. | Skyborn: No fall damage up to 60ft. Once per short rest, leap/drop from any height, land silent.", "Babel, Auran", "Zephyrkin are light-framed elemental humanoids with airy hair, quick movements, and features sculpted by constant wind.", "Zephyrkin culture values swiftness, grace, and the mastery of movement as both survival and expression. They prize timing, fluidity, and the ability to pass through dangerous spaces."],
	"Glimmerfolk": ["Humanoid", "20ft", "Luminous: Shed 10ft dim light. Allies gain +1 to attack roles in light. | Dazzle: For 1 SP, force creature within 5ft to make Vitality save or be blinded.", "Babel, Lumin", "Glimmerfolk are softly radiant humanoids whose skin and features shimmer with a delicate inner gleam.", "Glimmerfolk culture is centered on subtle encouragement, shared presence, and the belief that even modest light can strengthen those nearby."],
	"Mistborn Human": ["Humanoid (Air/Water)", "20ft", "Vapor Form: For 1 SP move action, become intangible and fly at foot speed. | Drifting Presence: Ignore mist terrain. Disadvantage on ranged attacks vs you in mist. 1/LR create fog.", "Babel, Auran", "Mistborn Humans are pale, soft-edged figures whose features often seem partially veiled by condensation or vapor.", "Mistborn culture is shaped by transience, concealment, and the calm of moving through uncertainty rather than resisting it."],
	"Mossling": ["Humanoid (Plant)", "20ft", "Spore Bloom: Once per long rest, 10ft calming cloud (Vitality save or dazed 1 min). | Photosynthetic Resilience: Regain 1 HP at start of turn while in natural light.", "Babel, Sylvan", "Mosslings are small, soft-featured plant humanoids covered in mossy growth and lichen-like textures.", "Mossling culture is rooted in patience, calm, and the quiet persistence of life in sheltered sacred places. They value healing, balance, and resilience without force."],
	"Zephyrite": ["Humanoid (Air)", "20ft", "Windswift: For 1 SP, hover 30ft off ground for 1 min. +1 AC and advantage on Speed saves. | Gale Sense: Advantage on initiative. Draw/stow weapon as part of initiative roll.", "Babel, Auran", "Zephyrites are quick, airy humanoids with hair and garments that seem constantly stirred by invisible currents.", "Zephyrite culture emphasizes speed, anticipation, and mastery of reaction. They prize swiftness of mind and body, training to act before hesitation can take root."],
	"Chronogears": ["Construct (Temporal)", "20ft", "Temporal Shift: Once per short rest as reaction, delay effect of spell/ability on you by 1 round. | Clockwork Precision: Advantage on initiative and cannot be surprised.", "Babel, Mechan", "Chronogears are intricate temporal constructs built of interlocking metal, arcane gearing, and precision mechanisms that tick with unnatural regularity.", "Chronogear culture is defined by order, timing, and the belief that precision is one of the highest forms of power. To waste time is a spiritual and structural failure."],
	"Silverblood": ["Humanoid (Magical)", "20ft", "Arcane Pulse: Once per long rest, 10ft pulse dazes creatures (DC 10+DIV Divinity save). | Runic Flow: Advantage on Arcane checks. Once per long rest, auto-succeed one check.", "Babel, Draconic", "Silverbloods are elegant magically infused humanoids whose veins, eyes, or skin often carry a metallic shimmer like living quicksilver.", "Silverblood culture is shaped by magical inheritance and cultivated talent. They believe magic is not only a gift but a substance of identity that must be directed with care and intelligence."],
	"Sparkforged Human": ["Humanoid (Construct)", "20ft", "Arcane Surge: Once per long rest, add +2 to spell attack or save DC. | Overload Pulse: When reduced to 0 HP, release 2d6 force damage in 10ft (boost with SP).", "Babel, Mechan", "Sparkforged Humans are construct-enhanced beings powered by volatile arcane energy, with glowing seams and metallic reinforcements.", "Sparkforged culture is built around innovation, risk, and the acceptance that power often comes with instability. They value ingenuity and the willingness to withstand dangerous transformation."],
	"Watchling": ["Construct (Awakened Tech)", "20ft", "Broadcast Eye: Advantage on Perception/Intuition (sight). See invisible silhouettes within 10ft. | Static Surge: Free action overload for 0 AP actions until next turn, then dazed + self-damage.", "Babel, Mechan", "Watchlings are awakened technological constructs with lens-like eyes, compact frames, and bodies built for observation and rapid information response.", "Watchling culture revolves around awareness, function, and the efficient handling of information. They prize vigilance, quick analysis, and the belief that knowledge gathered in time is more valuable than force used too late."],
	"Echoform Warden": ["Elemental (Echo-Touched)", "30ft", "Echo Reflection: Spend 3 AP when targeted by spell to suppress it (DC 10+DIV Intellect save). | Memory Tap: For 1 SP, learn a recent memory from touched creature (DC 14 Divinity save resists).", "Babel, Echoic", "Echoform Wardens are strange elemental beings whose bodies seem composed of layered afterimages, partial reflections, and repeating silhouettes that never fully settle.", "Echoform Warden culture is shaped by memory, containment, and the duty of preserving meaning in places where reality grows uncertain. They value perception, restraint, and careful handling of memory as sacred record."],
	"Nullborn Ascetic": ["Humanoid (Void-Touched)", "30ft", "Void Cloak: Immune to detection/scrying. Extend to allies (15ft) for -3 Max AP cost. | Spell Sink: For 3 AP, absorb SP from a spell effect used on you and convert into 1 SP.", "Babel, Silent Cant", "Nullborn Ascetics are severe, quiet figures marked by emptiness rather than ornament, with muted features and an aura that seems to swallow notice.", "Nullborn Ascetic culture is built around discipline, silence, and the mastery of void through denial. They embrace austerity and strict forms of self-erasure to become difficult to grasp."],
	"Mistborne Hatchling": ["Aberration (Proto-Spawn)", "25ft", "Warp Resistance: Resistance to environmental magical terrain effects. Extend to allies for -3 Max AP. | Surge Pulse: For 1 SP, 10ft burst slows for 1 min (DC 10+DIV Vitality save).", "Babel, Dreamtongue", "Mistborne Hatchlings are aberrant young forms wrapped in vaporous distortion, with bodies that seem only partially finished by reality.", "Mistborne Hatchling culture is shaped by adaptation, instability, and early exposure to places where magic and environment have grown inseparable. They value resilience and environmental awareness."],
	"Bespoker": ["Aberration (Void-Tuned Caster)", "40ft", "Ray Emission: Choose Ray (Paralyze, Fear, Heal, Necrotic, Disintegrate) for 1-3 AP. | Anti-Magic Cone: While active (-3 Max AP), 30ft cone suppresses spells <= level.", "Babel, Voidsong", "Bespokers are towering aberrant beings whose bodies ripple with unstable void energy, their forms sculpted from shifting darkness with eyes that burn like distant singularities.", "Bespoker culture revolves around mastery of void resonance and destructive cosmic forces. They view magic as a raw current to be bent and redirected. Their society respects those who channel the most dangerous energies."],
	"Brain Eater": ["Aberration (Swarm Predator)", "60ft", "Neural Liquefaction: Target within 5ft takes 2d6 psychic + loses 1 SP (DC 10+DIV save). | Skull Drill: If target is stunned/restrained, deal 2d6 damage and regain 2d6 HP.", "Babel, Pheromones", "Brain Eaters are grotesque aberrations with bulbous cranial bodies and writhing tendrils designed to pierce skulls and consume neural tissue.", "Brain Eater society is hive-like and predatory, driven by instinct and the consumption of knowledge stored in living minds."],
	"Pulsebound Hierophant": ["Aberration (Void Priest)", "30ft", "Resonant Sermon: While active (-3 Max AP), allies gain +1 saves/checks and enemies disadvantage on casting. | Void Communion: Once per long rest, 10 min ritual grants nearby allies 1d4+DIV SP + visions.", "Babel, Voidsong", "Pulsebound Hierophants are tall, robed figures whose bodies pulse with rhythmic waves of void energy.", "Pulsebound Hierophants serve as priests of the Void's living rhythm. Their communities revolve around ritual, meditation, and the study of existential emptiness."],
	"Threnody Warden": ["Construct (Void Guardian)", "40ft", "Threnody Slam: 3 AP deals 3d6 force and mutes target for 1 round (DC 10+DIV Divinity save). | Pulse of Silence: 10ft aura imposes disadvantage on speech-based abilities and blocks verbal spells.", "Babel, Voidsong", "Threnody Wardens are massive construct guardians forged from dark alloys etched with humming void sigils.", "Threnody Warden culture is defined by duty and eternal vigilance. Created to guard sacred void sites and unstable rifts, they view their purpose as sacred and unending."],
}

func get_all_lineages() -> PackedStringArray:
	return ALL_LINEAGES

func get_lineage_details(name: String) -> PackedStringArray:
	# Returns: [type, speed, traits_pipe_separated, languages, description, culture]
	var entry: Array = _LINEAGE_DETAILS.get(name, [])
	if entry.is_empty():
		return PackedStringArray(["Humanoid", "20ft", "", "Babel", "A lineage from the world of Rimvale.", ""])
	return PackedStringArray(entry)

# ── Character creation ────────────────────────────────────────────────────────
func create_character(name: String, lineage: String, age: int) -> int:
	var h: int = _next_handle
	_next_handle += 1
	# PHB: natural lifespan = 80 + 2d20 (nat 20 doubles the other die)
	var d1: int = randi_range(1, 20)
	var d2: int = randi_range(1, 20)
	if d1 == 20 and d2 == 20:
		d1 = 40; d2 = 40  # both nat 20 → +80
	elif d1 == 20:
		d2 *= 2
	elif d2 == 20:
		d1 *= 2
	var rolled_max_age: int = 80 + d1 + d2

	_chars[h] = {
		"name":       name,
		"lineage":    lineage,
		"age":        age,
		"max_age":    rolled_max_age,
		"months_sacrificed": 0,
		"life_bound_sp": 0,
		"insanity":   0,
		"sacrifice_dc": 10,
		"id":         "char_%d" % h,
		"level":      1,
		"xp":         0,
		"xp_req":     100,
		"hp":         20, "max_hp":  20,
		"ap":         10, "max_ap":  10,
		"sp":         6,  "max_sp":  6,
		"ac":         10,
		"speed":      6,
		"weapon":     "None",
		"armor":      "None",
		"shield":     "None",
		"light":      "None",
		"stat_pts":   6,
		"feat_pts":   6,
		"skill_pts":  12,
		"gold":       100,
		"injuries":   [],
		"conditions": [],
		"items":      [],
		"attuned":    [],
		"spells":     [],
		"stats":      [1, 1, 1, 1, 1],
		"skills":     [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		"favored_skills": [],
		"feats":      {},
		"safeguard_stats": [],
		"societal_role": "",
		"alignment":  "Unity",
		"domain":     "Physical",
	}
	return h

func destroy_character(handle: int) -> void:
	_chars.erase(handle)

func fuse_characters(target: int, sacrifice: int) -> void:
	if not _chars.has(target) or not _chars.has(sacrifice):
		return
	var t = _chars[target]
	var s = _chars[sacrifice]
	# Boost target: gain some XP and a level if enough
	t["xp"] += s["level"] * 50
	while t["xp"] >= t["xp_req"]:
		t["xp"] -= t["xp_req"]
		t["level"] += 1
		t["xp_req"] = t["level"] * 100
	recalculate_derived_stats(target)
	destroy_character(sacrifice)

# ── Character getters ─────────────────────────────────────────────────────────
## Returns a direct reference to the character dict so callers can mutate stats.
## Returns null if handle is not found.
func get_char_dict(handle: int):
	if _chars.has(handle):
		return _chars[handle]
	return null

func get_character_name(handle: int) -> String:
	return _chars.get(handle, {}).get("name", "Unknown")

func get_character_id(handle: int) -> String:
	return _chars.get(handle, {}).get("id", "")

func get_character_lineage_name(handle: int) -> String:
	return _chars.get(handle, {}).get("lineage", "Unknown")

func get_character_age(handle: int) -> int:
	if not _chars.has(handle): return 0
	var c = _chars[handle]
	var base_age: int = int(c.get("age", 25))
	var years_from_game: int = GameState.game_day / 365
	var years_from_sacrifice: int = int(c.get("months_sacrificed", 0)) / 12
	return base_age + years_from_game + years_from_sacrifice

func get_character_max_age(handle: int) -> int:
	if not _chars.has(handle): return 100
	var c = _chars[handle]
	var base_max: int = int(c.get("max_age", 100))
	var life_ext: int = int(c.get("life_bound_sp", 0)) * 10  # Elf: 10 years per SP
	return base_max + life_ext

func get_character_insanity(handle: int) -> int:
	return _chars.get(handle, {}).get("insanity", 0)

func get_character_level(handle: int) -> int:
	return _chars.get(handle, {}).get("level", 1)

func get_character_xp(handle: int) -> int:
	return _chars.get(handle, {}).get("xp", 0)

func get_character_xp_required(handle: int) -> int:
	return _chars.get(handle, {}).get("xp_req", 100)

func get_character_hp(handle: int) -> int:
	return _chars.get(handle, {}).get("hp", 20)

func get_character_max_hp(handle: int) -> int:
	return _chars.get(handle, {}).get("max_hp", 20)

func get_character_ap(handle: int) -> int:
	return _chars.get(handle, {}).get("ap", 6)

func get_character_max_ap(handle: int) -> int:
	return _chars.get(handle, {}).get("max_ap", 6)

func get_character_sp(handle: int) -> int:
	return _chars.get(handle, {}).get("sp", 3)

func get_character_max_sp(handle: int) -> int:
	return _chars.get(handle, {}).get("max_sp", 3)

func get_character_ac(handle: int) -> int:
	return _chars.get(handle, {}).get("ac", 10)

func get_character_movement_speed(handle: int) -> int:
	return _chars.get(handle, {}).get("speed", 6)

func get_character_stat_points(handle: int) -> int:
	return _chars.get(handle, {}).get("stat_pts", 0)

func get_character_feat_points(handle: int) -> int:
	return _chars.get(handle, {}).get("feat_pts", 0)

func get_character_skill_points(handle: int) -> int:
	return _chars.get(handle, {}).get("skill_pts", 0)

func get_character_stat(handle: int, stat_type: int) -> int:
	if not _chars.has(handle): return 1
	var stats: Array = _chars[handle].get("stats", [1,1,1,1,1])
	if stat_type < 0 or stat_type >= stats.size(): return 1
	return int(stats[stat_type])

func get_character_skill(handle: int, skill_type: int) -> int:
	if not _chars.has(handle): return 0
	var skills: Array = _chars[handle].get("skills", [])
	if skill_type < 0 or skill_type >= skills.size(): return 0
	return int(skills[skill_type])

func get_character_feat_tier(handle: int, feat_name: String) -> int:
	if not _chars.has(handle): return 0
	return int(_chars[handle].get("feats", {}).get(feat_name, 0))

func get_feat_registry_entry(feat_name: String) -> Dictionary:
	return _FEAT_REGISTRY.get(feat_name, {})

func get_character_injuries(handle: int) -> PackedStringArray:
	return PackedStringArray(_chars.get(handle, {}).get("injuries", []))

func get_character_conditions(handle: int) -> PackedStringArray:
	return PackedStringArray(_chars.get(handle, {}).get("conditions", []))

func get_inventory_gold(handle: int) -> int:
	return _chars.get(handle, {}).get("gold", 0)

func get_inventory_items(handle: int) -> PackedStringArray:
	return PackedStringArray(_chars.get(handle, {}).get("items", []))

func get_equipped_weapon(handle: int) -> String:
	return _chars.get(handle, {}).get("weapon", "None")

func get_equipped_armor(handle: int) -> String:
	return _chars.get(handle, {}).get("armor", "None")

func get_equipped_shield(handle: int) -> String:
	return _chars.get(handle, {}).get("shield", "None")

func get_equipped_light_source(handle: int) -> String:
	return "None"

func get_character_societal_role_name(handle: int) -> String:
	if not _chars.has(handle): return ""
	return str(_chars[handle].get("societal_role", ""))

# ── Character setters ─────────────────────────────────────────────────────────
func set_character_name(handle: int, name: String) -> void:
	if _chars.has(handle): _chars[handle]["name"] = name

func add_xp(handle: int, amount: int, level_limit: int) -> void:
	if not _chars.has(handle): return
	var c = _chars[handle]
	c["xp"] += amount
	while c["xp"] >= c["xp_req"] and c["level"] < level_limit:
		c["xp"] -= c["xp_req"]
		c["level"] += 1
		c["xp_req"] = c["level"] * 100
		recalculate_derived_stats(handle)

func add_gold(handle: int, amount: int) -> void:
	if _chars.has(handle): _chars[handle]["gold"] += amount

func character_take_damage(handle: int, amount: int) -> int:
	if not _chars.has(handle): return 0
	var c = _chars[handle]
	_dung_reduce_hp(c, amount)
	return c["hp"]

func character_start_turn(handle: int) -> void:
	pass

func short_rest(handle: int) -> void:
	if not _chars.has(handle): return
	var c = _chars[handle]
	var hp_heal: int = c["max_hp"] / 2
	# Rest & Recovery T1: +25% SR healing, T2: +50%
	var rr_t: int = _feat_tier(handle, "Rest & Recovery")
	if rr_t >= 2: hp_heal = int(hp_heal * 1.5)
	elif rr_t >= 1: hp_heal = int(hp_heal * 1.25)
	c["hp"] = mini(c["max_hp"], c["hp"] + hp_heal)
	c["ap"] = c["max_ap"]
	var sp_gain: int = 1
	if rr_t >= 3: sp_gain += 1
	c["sp"] = mini(c["max_sp"], c["sp"] + sp_gain)
	# Rest & Recovery T4: remove one injury on short rest
	if rr_t >= 4:
		var injuries: Array = c.get("injuries", [])
		if not injuries.is_empty():
			injuries.pop_back()
	# Safeguard: reset SR charges (T2 advantage, T5 HP regen)
	c.erase("_sg_adv_used")
	c.erase("_sg_regen_used")

func long_rest(handle: int) -> void:
	if not _chars.has(handle): return
	var c = _chars[handle]
	c["hp"] = c["max_hp"]
	c["ap"] = c["max_ap"]
	c["sp"] = c["max_sp"]
	# Long rest clears all injuries
	c["injuries"] = []
	# Reset life sacrifice DC and reduce insanity by 1 (from sleep deprivation only)
	reset_sacrifice_dc(handle)
	# Check for age-based insanity
	update_age_insanity(handle)
	# Safeguard: reset all charges (LR resets everything, SR charges included)
	c.erase("_sg_auto_used")
	c.erase("_sg_reroll_used")
	c.erase("_sg_adv_used")
	c.erase("_sg_regen_used")

func rest_party(handles: PackedInt64Array) -> bool:
	for h in handles:
		short_rest(h)
	return true

func spend_character_sp(handle: int, amount: int) -> bool:
	if not _chars.has(handle): return false
	var c = _chars[handle]
	if c["sp"] < amount: return false
	c["sp"] -= amount
	return true

func restore_character_sp(handle: int, amount: int) -> void:
	if not _chars.has(handle): return
	var c = _chars[handle]
	c["sp"] = mini(c["max_sp"], c["sp"] + amount)

# ── Feats / skills ────────────────────────────────────────────────────────────
func can_unlock_feat(handle: int, feat_name: String, tier: int) -> bool:
	if not _chars.has(handle): return false
	var c = _chars[handle]
	if c.get("feat_pts", 0) <= 0: return false
	_ensure_feat_registry()
	var entry: Dictionary = _FEAT_REGISTRY.get(feat_name, {})
	if entry.is_empty(): return false
	var tiers_avail: Array = entry["tiers"].keys()
	tiers_avail.sort()
	var current_tier: int = int(c.get("feats", {}).get(feat_name, 0))
	for t in tiers_avail:
		if t > current_tier:
			return t == tier
	return false

## Recompute HP/AP/SP from the PHB formulas given the current stats + level.
## Stat order: STR=0, SPD=1, INT=2, VIT=3, DIV=4
## Also applies feat passive bonuses (e.g. Iron Vitality, Arcane Wellspring, Martial Focus).
func recalculate_derived_stats(handle: int) -> void:
	if not _chars.has(handle): return
	var c = _chars[handle]
	var stats: Array = c.get("stats", [0,0,0,0,0])
	var lv:  int = int(c.get("level", 1))
	var str_v: int = int(stats[0]) if stats.size() > 0 else 0
	var vit_v: int = int(stats[3]) if stats.size() > 3 else 0
	var div_v: int = int(stats[4]) if stats.size() > 4 else 0
	# PHB: HP = 3 + 3*level + VIT; AP = 3 + STR; SP = 3 + level + DIV
	# PHB age factor: 80-89 → 2HP/lv, 90+ → 1HP/lv. VIT multiplier from feats stays.
	var eff_age: int = get_character_age(handle)
	var hp_per_lv: int = 3
	if eff_age >= 90:   hp_per_lv = 1
	elif eff_age >= 80: hp_per_lv = 2
	var new_hp: int = maxi(1, 3 + hp_per_lv * lv + vit_v)
	var new_ap: int = maxi(1, 3 + str_v)
	var new_sp: int = maxi(1, 3 + lv + div_v)

	# Elf innate magic: +1 SP per level
	var lin: String = str(c.get("lineage", ""))
	if lin == "Elf":
		new_sp += lv
	# Life-bound SP reduction (Elf life extension ritual)
	new_sp = maxi(0, new_sp - int(c.get("life_bound_sp", 0)))

	# ── Feat passive bonuses ──────────────────────────────────────────────
	# Apply the highest-tier unlocked modifier for each stat feat.
	var feats: Dictionary = c.get("feats", {})
	# Iron Vitality: tier1 → HP = 2×VIT+3×Lv+3; tier5 → HP = 3×VIT+3×Lv+3
	# Age penalty applies to the per-level factor; VIT multiplier from feat stays.
	if feats.has("Iron Vitality"):
		var t: int = int(feats["Iron Vitality"])
		if t >= 5:   new_hp = maxi(1, 3 + hp_per_lv * lv + 3 * vit_v)
		elif t >= 1: new_hp = maxi(1, 3 + hp_per_lv * lv + 2 * vit_v)
	# Arcane Wellspring: tier1 → SP = 2×DIV+Lv+3; tier5 → SP = 3×DIV+Lv+3
	if feats.has("Arcane Wellspring"):
		var t: int = int(feats["Arcane Wellspring"])
		if t >= 5:   new_sp = maxi(1, 3 + lv + 3 * div_v)
		elif t >= 1: new_sp = maxi(1, 3 + lv + 2 * div_v)
	# Martial Focus: tier1 → AP = 2×STR+3; tier5 → AP = 3×STR+3
	if feats.has("Martial Focus"):
		var t: int = int(feats["Martial Focus"])
		if t >= 5:   new_ap = maxi(1, 3 + 3 * str_v)
		elif t >= 1: new_ap = maxi(1, 3 + 2 * str_v)
	# feat_ac_bonus now computed in _compute_ac directly
	c["feat_ac_bonus"] = 0

	# ── Magic item passive bonuses (only from attuned items) ─────────────────
	new_hp += _magic_item_bonus(handle, "hp_bonus")
	new_sp += _magic_item_bonus(handle, "sp_bonus")
	new_ap += _magic_item_bonus(handle, "ap_bonus")

	# ── Attunement SP cost — reduces max SP per PHB ──────────────────────────
	new_sp = maxi(0, new_sp - get_attunement_sp_committed(handle))

	# Preserve current HP/SP ratio if character is injured
	var hp_ratio: float = float(int(c.get("hp", new_hp))) / float(maxi(1, int(c.get("max_hp", new_hp))))
	var sp_ratio: float = float(int(c.get("sp", new_sp))) / float(maxi(1, int(c.get("max_sp", new_sp))))
	c["max_hp"] = new_hp
	c["max_ap"] = new_ap
	c["max_sp"] = new_sp
	c["hp"] = maxi(1, int(float(new_hp) * hp_ratio))
	c["ap"] = new_ap  # AP refreshes fully
	c["sp"] = maxi(0, int(float(new_sp) * sp_ratio))
	# PHB: AC formula depends on armor type + Speed stat. Refresh whenever stats change.
	c["ac"] = _compute_ac(handle)

	# ── Recalculate available points from level (matches C++ Character::level_up) ──
	# Total earned = base_at_creation + (level - 1) * per_level_grant
	var total_stat_earned:  int = 6  + (lv - 1) * 1
	var total_feat_earned:  int = 6  + (lv - 1) * 4
	var total_skill_earned: int = 12 + (lv - 1) * 3

	# Calculate how many points have been spent
	# Stats: each stat starts at 1; cost is 1 per point up to 5, 2 per point above 5
	var stat_spent: int = 0
	for sv in stats:
		var v: int = int(sv)
		if v <= 5:
			stat_spent += (v - 1)
		else:
			stat_spent += 4 + (v - 5) * 2  # 4 pts for 1→5, then 2 per above 5

	# Skills: each skill starts at 0; cost is 1 per rank up to 5, 2 per rank above 5
	var skill_spent: int = 0
	var skills: Array = c.get("skills", [])
	for sk in skills:
		var v: int = int(sk)
		if v <= 5:
			skill_spent += v
		else:
			skill_spent += 5 + (v - 5) * 2  # 5 pts for 0→5, then 2 per above 5

	# Feats: each feat tier costs that tier number of feat points
	var feat_spent: int = 0
	for feat_tier in feats.values():
		feat_spent += int(feat_tier)

	c["stat_pts"]  = maxi(0, total_stat_earned  - stat_spent)
	c["feat_pts"]  = maxi(0, total_feat_earned  - feat_spent)
	c["skill_pts"] = maxi(0, total_skill_earned - skill_spent)

## Level up a character: increment level, grant 1 stat point + 3 skill points (PHB),
## then recalculate all derived stats (HP/AP/SP/AC).
func level_up_character(handle: int) -> void:
	if not _chars.has(handle): return
	var c: Dictionary = _chars[handle]
	c["level"]     = int(c.get("level",     1)) + 1
	c["stat_pts"]  = int(c.get("stat_pts",  0)) + 1   # PHB: 1 stat point per level
	c["skill_pts"] = int(c.get("skill_pts", 0)) + 3   # PHB: 3 skill points per level
	recalculate_derived_stats(handle)

func spend_stat_point(handle: int, stat_type: int) -> bool:
	if not _chars.has(handle): return false
	var c = _chars[handle]
	if c.get("stat_pts", 0) <= 0: return false
	if stat_type < 0 or stat_type >= c["stats"].size(): return false
	c["stat_pts"] -= 1
	c["stats"][stat_type] += 1
	# Recalculate derived stats when a stat point is spent
	recalculate_derived_stats(handle)
	return true

func spend_skill_point(handle: int, skill_type: int) -> bool:
	if not _chars.has(handle): return false
	var c = _chars[handle]
	if c.get("skill_pts", 0) <= 0: return false
	if skill_type < 0 or skill_type >= c["skills"].size(): return false
	c["skill_pts"] -= 1
	c["skills"][skill_type] += 1
	return true

func spend_feat_point(handle: int, feat_name: String, tier: int) -> bool:
	if not can_unlock_feat(handle, feat_name, tier): return false
	var c = _chars[handle]
	c["feat_pts"] -= 1
	if not c.has("feats"): c["feats"] = {}
	c["feats"][feat_name] = tier
	return true

func is_proficient_in_saving_throw(handle: int, stat_type: int) -> bool:
	if not _chars.has(handle): return false
	return stat_type in _chars[handle].get("save_proficiencies", [])

func toggle_saving_throw_proficiency(handle: int, stat_type: int) -> void:
	if not _chars.has(handle): return
	var c = _chars[handle]
	if not c.has("save_proficiencies"): c["save_proficiencies"] = []
	if stat_type in c["save_proficiencies"]:
		c["save_proficiencies"].erase(stat_type)
	else:
		c["save_proficiencies"].append(stat_type)

func get_saving_throw_proficiencies(handle: int) -> PackedInt32Array:
	if not _chars.has(handle): return PackedInt32Array()
	return PackedInt32Array(_chars[handle].get("save_proficiencies", []))

func is_favored_skill(handle: int, skill_type: int) -> bool:
	if not _chars.has(handle): return false
	return skill_type in _chars[handle].get("favored_skills", [])

func toggle_favored_skill(handle: int, skill_type: int) -> bool:
	if not _chars.has(handle): return false
	var c = _chars[handle]
	if not c.has("favored_skills"): c["favored_skills"] = []
	if skill_type in c["favored_skills"]:
		c["favored_skills"].erase(skill_type)
		return false
	else:
		c["favored_skills"].append(skill_type)
		return true

func get_feat_action_states(handle: int) -> PackedStringArray:
	return PackedStringArray()

func get_safeguard_chosen_stats(handle: int) -> PackedInt32Array:
	if not _chars.has(handle): return PackedInt32Array()
	var arr = _chars[handle].get("safeguard_stats", [])
	return PackedInt32Array(arr)

func set_safeguard_chosen_stats(handle: int, stats: PackedInt32Array) -> void:
	if not _chars.has(handle): return
	_chars[handle]["safeguard_stats"] = Array(stats)

func get_feat_trees_by_character(handle: int) -> PackedStringArray:
	return PackedStringArray()

func get_learned_spells(handle: int) -> PackedStringArray:
	if not _chars.has(handle): return PackedStringArray()
	var spells: Array = _chars[handle].get("spells", [])
	return PackedStringArray(spells)

func learn_spell(handle: int, spell_name: String) -> void:
	if not _chars.has(handle): return
	var spells: Array = _chars[handle].get("spells", [])
	if spell_name not in spells:
		spells.append(spell_name)
		_chars[handle]["spells"] = spells

func forget_spell(handle: int, spell_name: String) -> void:
	if not _chars.has(handle): return
	var spells: Array = _chars[handle].get("spells", [])
	spells.erase(spell_name)
	_chars[handle]["spells"] = spells

func get_all_character_handles() -> Array:
	return _chars.keys()

# ── Feats / alignment / domain (Fix #3 & #7) ──────────────────────────────────
## Grant a named feat to the character (e.g. "Spell-Shaper", "Domain-Mastery").
func grant_feat(handle: int, feat_name: String) -> void:
	if not _chars.has(handle): return
	var feats: Dictionary = _chars[handle].get("feats", {})
	feats[feat_name] = true
	_chars[handle]["feats"] = feats

func revoke_feat(handle: int, feat_name: String) -> void:
	if not _chars.has(handle): return
	var feats: Dictionary = _chars[handle].get("feats", {})
	feats.erase(feat_name)
	_chars[handle]["feats"] = feats

func has_feat(handle: int, feat_name: String) -> bool:
	if not _chars.has(handle): return false
	return bool(_chars[handle].get("feats", {}).get(feat_name, false))

## Set magic source alignment: "Chaos", "Unity", or "Void".
func set_alignment(handle: int, alignment: String) -> void:
	if not _chars.has(handle): return
	_chars[handle]["alignment"] = alignment

func get_alignment(handle: int) -> String:
	if not _chars.has(handle): return "Unity"
	return str(_chars[handle].get("alignment", "Unity"))

## Set preferred domain: "Biological", "Chemical", "Physical", "Spiritual".
func set_domain(handle: int, domain: String) -> void:
	if not _chars.has(handle): return
	_chars[handle]["domain"] = domain

func get_domain(handle: int) -> String:
	if not _chars.has(handle): return "Physical"
	return str(_chars[handle].get("domain", "Physical"))

## Fix #7: Crafting kits — consumables that grant a bonus die on next cast.
## Kit types: "alchemy" (Chemical +1d6), "apothecary" (Biological +1d4),
## "engineering" (Physical +1d6), "ritualist" (Spiritual +1d4).
func use_crafting_kit(handle: int, kit_type: String) -> bool:
	if not _chars.has(handle): return false
	var c: Dictionary = _chars[handle]
	var inv: Array = c.get("items", [])
	var kit_name: String = "%s kit" % kit_type
	var found_idx: int = -1
	for i in range(inv.size()):
		if str(inv[i]).to_lower() == kit_name:
			found_idx = i
			break
	if found_idx < 0: return false
	inv.remove_at(found_idx)
	c["items"] = inv
	# Store a one-shot bonus flag that the next cast consumes.
	c["pending_kit"] = kit_type
	_chars[handle] = c
	return true

# ── Ritual casting (Fix #7) ───────────────────────────────────────────────────
## Cast a spell as a ritual — 0 SP but takes ~10x the base time.
## Returns the dispatched spell log, or a failure string if not in a dungeon state.
func cast_spell_as_ritual(handle: int, spell_name: String, target_id: String = "",
		cx: int = -1, cy: int = -1) -> String:
	if not _chars.has(handle): return "No such character."
	_ensure_spell_db()
	if not _SPELL_DB.has(spell_name): return "Unknown spell: %s" % spell_name
	# Find the corresponding entity in the dungeon.
	var caster = null
	for e in _dungeon_entities:
		if int(e.get("handle", -1)) == handle:
			caster = e; break
	if caster == null: return "Caster not in dungeon."
	var action := {"matrix_id": spell_name, "ritual": true}
	var result: Dictionary = _dung_dispatch_spell(caster, action, target_id, cx, cy, 0, 0)
	return str(result.get("log", ""))

func roll_skill(handle: int, skill_id: int) -> int:
	return randi_range(1, 20)

func roll_skill_check(handle: int, skill_id: int, stat_id: int) -> PackedStringArray:
	var roll: int = randi_range(1, 20)
	var stat_bonus: int = 0
	var advantage: bool = false
	var quality: String = "Normal"
	if _chars.has(handle):
		var c = _chars[handle]
		var stat_names: Array = ["str","spd","itl","div","vit","chr"]
		if stat_id >= 0 and stat_id < stat_names.size():
			stat_bonus = int(c.get(stat_names[stat_id], 0)) / 4
		# Favored skills grant advantage (roll twice, take higher)
		if is_favored_skill(handle, skill_id):
			var roll2: int = randi_range(1, 20)
			if roll2 > roll: roll = roll2
			advantage = true
		# Save proficiency: apply proficiency bonus (+Level/4 approx)
		if is_proficient_in_saving_throw(handle, stat_id):
			stat_bonus += maxi(1, int(c.get("level", 1)) / 4)
		# Societal role primary skill bonus: +1d4
		stat_bonus += get_role_skill_bonus(handle, skill_id)
		# ── Miscellaneous & crafting feat skill bonuses ──────────────────
		var feats: Dictionary = c.get("feats", {})
		# Locktap Lord: advantage on Cunning (lock/trap) checks
		if feats.has("Locktap Lord") and skill_id == 4:  # Cunning
			var roll2b: int = randi_range(1, 20)
			if roll2b > roll: roll = roll2b
			advantage = true
		# Crafting feats: add stat score to relevant checks
		if feats.has("Alchemist's Supplies"):
			var al_t: int = int(feats["Alchemist's Supplies"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[3]) * (2 if al_t >= 2 else 1)
		if feats.has("Smith's Tools"):
			var sm_t: int = int(feats["Smith's Tools"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[0]) * (2 if sm_t >= 2 else 1)
		if feats.has("Thieves' Tools"):
			var tt_t: int = int(feats["Thieves' Tools"])
			if skill_id == 4:  # Cunning
				stat_bonus += int(c.get("stats", [1,1,1,1,1])[1]) * (2 if tt_t >= 2 else 1)
		if feats.has("Herbalism Kit"):
			var hk_t: int = int(feats["Herbalism Kit"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[2]) * (2 if hk_t >= 2 else 1)
		if feats.has("Tinker's Tools"):
			var tn_t: int = int(feats["Tinker's Tools"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[2]) * (2 if tn_t >= 2 else 1)
		if feats.has("Musical Instrument"):
			var mi_t: int = int(feats["Musical Instrument"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[4]) * (2 if mi_t >= 2 else 1)
		if feats.has("Navigator's Tools"):
			var nv_t: int = int(feats["Navigator's Tools"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[2]) * (2 if nv_t >= 2 else 1)
		if feats.has("Calligrapher's Supplies"):
			var cs_t: int = int(feats["Calligrapher's Supplies"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[2]) * (2 if cs_t >= 2 else 1)
		if feats.has("Painter's Supplies"):
			var ps_t: int = int(feats["Painter's Supplies"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[4]) * (2 if ps_t >= 2 else 1)
		if feats.has("Jeweler's Tools"):
			var jt_t: int = int(feats["Jeweler's Tools"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[2]) * (2 if jt_t >= 2 else 1)
		if feats.has("Disguise Kit"):
			var dk_t: int = int(feats["Disguise Kit"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[2]) * (2 if dk_t >= 2 else 1)
		if feats.has("Poisoner's Kit"):
			var pk_t: int = int(feats["Poisoner's Kit"])
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[3]) * (2 if pk_t >= 2 else 1)
		if feats.has("Fishing Mastery"):
			advantage = true  # Advantage on Survival
		if feats.has("Hunting Mastery"):
			advantage = true  # Advantage on tracking
		# Erylon's Echo buff (from combat activation)
		if feats.has("Erylon's Echo"):
			stat_bonus += randi_range(1, 4)
		# Coinreader's Wink: advantage on Insight/Deception/Persuasion
		if feats.has("Coinreader's Wink") and skill_id in [5, 6, 7]:  # social skills
			var roll2c: int = randi_range(1, 20)
			if roll2c > roll: roll = roll2c
			advantage = true
		# Whispers: +1d6 bonus
		if feats.has("Whispers"):
			stat_bonus += randi_range(1, 6)
		# Crafting & Artifice: +2 to crafting checks
		if feats.has("Crafting & Artifice"):
			stat_bonus += 2
		# Artisan's Tools: reroll failed crafting check
		if feats.has("Artisan's Tools"):
			var at_t: int = int(feats["Artisan's Tools"])
			if at_t >= 2: stat_bonus += int(c.get("stats", [1,1,1,1,1])[2]) * 2
		# Weatherwise Tailoring: proficiency bonus
		if feats.has("Weatherwise Tailoring"):
			stat_bonus += 2
		# Dreamthief: +1d4 to Insight/Speechcraft
		if feats.has("Dreamthief") and skill_id in [5, 6]:
			stat_bonus += randi_range(1, 4)
		# Hollow Voice: mimic bonus to Speechcraft/deception
		if feats.has("Hollow Voice") and skill_id in [5, 6, 7]:
			stat_bonus += int(c.get("stats", [1,1,1,1,1])[2])  # + Speechcraft
		# Rune Cipher: read any language, +bonus to knowledge
		if feats.has("Rune Cipher") and skill_id in [2, 3]:  # Learnedness/Insight
			stat_bonus += 4
		# Skywatcher's Sight: advantage on Perception/Insight for finding
		if feats.has("Skywatcher's Sight") and skill_id in [3, 5]:
			var roll2d: int = randi_range(1, 20)
			if roll2d > roll: roll = roll2d
			advantage = true
		# Split Second Read: +1 to AC/saves against target
		if feats.has("Split Second Read") and skill_id == 5:  # Insight
			stat_bonus += 2  # auto-learn emotional state
		# Veyra's Veil: advantage on Sneak/Cunning
		if feats.has("Veyra's Veil") and skill_id in [1, 4]:  # Sneak/Cunning
			var roll2e: int = randi_range(1, 20)
			if roll2e > roll: roll = roll2e
			advantage = true
		# Loreweaver's Mark: +1 to ally saves
		if feats.has("Loreweaver's Mark"):
			stat_bonus += 1
		# Arcane Residue: bonus from lingering magic
		if feats.has("Arcane Residue"):
			stat_bonus += 1

		# ── Magic item skill bonuses ──────────────────────────────────────────
		stat_bonus += _magic_item_bonus(handle, "skill_bonus")
		# Stealth-specific: Sneak = skill 1
		if skill_id == 1:
			stat_bonus += _magic_item_bonus(handle, "stealth_bonus")
		# Perception-specific: Perception = skill 9
		if skill_id == 9:
			stat_bonus += _magic_item_bonus(handle, "perception_bonus")
	var total: int = roll + stat_bonus
	if total >= 20: quality = "Critical"
	elif total <= 4: quality = "Critical Fail"
	return PackedStringArray([str(total), quality])

# ── Stash (shared party storage) ─────────────────────────────────────────────
## Wrappers that delegate to GameState's stash array.
## Items are plain name strings; uniqueness is NOT enforced (duplicates allowed).
func get_stash_items() -> PackedStringArray:
	return PackedStringArray(GameState.stash)

func add_to_stash(item_name: String) -> void:
	GameState.stash.append(item_name)

func remove_from_stash(item_name: String) -> void:
	GameState.remove_from_stash(item_name)

func stash_item_from_character(handle: int, item_name: String) -> void:
	remove_item_from_inventory(handle, item_name)
	add_to_stash(item_name)

func move_stash_item_to_character(item_name: String, handle: int) -> void:
	remove_from_stash(item_name)
	add_item_to_inventory(handle, item_name)

# ── Lineage traits ─────────────────────────────────────────────────────────────
## The full display-label map for all known trait IDs (mirrors DungeonViewModel).
static var _TRAIT_LABELS: Dictionary = {
	"BoundingEscape":"Bounding Escape (1/SR)", "HeatedScalesToggle":"Heated Scales",
	"SunsFavor":"Sun's Favor (1/LR)", "ArmoredPlating":"Armored Plating (1/LR)",
	"MechanicalMindRecall":"Recall (1/SR)", "Regrowth":"Regrowth (1/SR)",
	"NaturesVoice":"Nature's Voice (1/LR)", "IllusoryEcho":"Illusory Echo (1/LR)",
	"TrickstersDodge":"Trickster's Dodge (1 SP)", "Photosynthesis":"Photosynthesis (1 SP)",
	"FeyStep":"Fey Step", "EnchantingPresence":"Enchanting Presence (1/SR)",
	"SporeCloud":"Spore Cloud (1/LR)", "FungalFortitude":"Fungal Fortitude (1/SR)",
	"Origami":"Origami (3 AP)", "OrigamiMaintain":"Origami: Maintain (1 AP)",
	"MnemonicRecall":"Mnemonic Recall (1/SR)", "SentinelStand":"Sentinel's Stand (1 AP)",
	"ToxicRoots":"Toxic Roots (1/LR)", "WitherbornDecay":"Witherborn Decay (1/LR)",
	"SilkenTrap":"Silken Trap (1/SR)", "DrainingFangs":"Draining Fangs (1 AP)",
	"LurkerStep":"Lurker's Step (1/SR)", "VenomousBite":"Venomous Bite (1 AP)",
	"ExtractVenom":"Extract Venom (1/LR)", "HypnoticGaze":"Hypnotic Gaze (3 AP)",
	"PackHowl":"Pack Howl (1/LR)", "NaturesGrace":"Nature's Grace (1/LR)",
	"AdaptiveHide":"Adaptive Hide", "VerdantCurse":"Verdant Curse (1/LR)",
	"KindleFlame":"Kindle Flame (1/LR)", "AlchemicalAffinity":"Alchemical Affinity (1/LR)",
	"ResilientSpirit":"Resilient Spirit (2/SR)", "VersatileGrant":"Versatile Grant",
	"QuillLaunch":"Quill Launch (1/LR)", "QuickReflexes":"Quick Reflexes (1/SR)",
	"ArcaneSurge":"Arcane Surge (1/LR)", "ScrapInstinct":"Scrap Instinct (1/SR)",
	"SteamJet":"Steam Jet (1/LR, 2 AP)", "TetherStep":"Tether Step (1/LR, 3 AP)",
	"ResonantVoice":"Resonant Voice (INT/SR)", "MarketWhisperer":"Market Whisperer (1/LR)",
	"ArcaneTinker":"Arcane Tinker (1/LR)", "GremlinsLuck":"Gremlin's Luck (2/SR)",
	"HexMark":"Hex Mark (1/LR, 2 AP)", "Witchblood":"Witchblood (1/SR)",
	"CommandingVoice":"Commanding Voice (1/LR, 2 AP)", "OverdriveCore":"Overdrive Core (1/SR)",
	"GremlinTinker":"Tinker (1/LR)", "GremlinSabotage":"Sabotage (1/SR)",
	"ReflectHex":"Reflect Hex (1/LR)", "ScrapSense":"Scrap Sense (1/SR)",
	"IronStomachPoison":"Iron Stomach (1/SR, 2 AP)", "ShadowGlide":"Shadow Glide (3 AP)",
	"Shadowgrasp":"Shadowgrasp (3 AP)", "QuackAlarm":"Quack Alarm (1/LR)",
	"SableNightVision":"Night Vision (1/LR)", "Veilstep":"Veilstep (1/SR)",
	"DuskbornGrace":"Duskborn Grace (1/SR)", "MossyShroud":"Mossy Shroud (1/LR)",
	"MireBurst":"Mire Burst (1/SR)", "SoothingAura":"Soothing Aura (1/LR)",
	"Dreamscent":"Dreamscent (1/LR)", "BloodlettingBlow":"Bloodletting Blow (3 AP)",
	"Boneclatter":"Boneclatter (3 AP)", "DiseasebornCurse":"Diseaseborn Curse (1/LR)",
	"UmbralDodge":"Umbral Dodge (3 AP)", "GnawingGrin":"Gnawing Grin (1/LR)",
	"StonesEndurance":"Stone's Endurance (VIT/SR)", "CrystalResilience":"Crystal Resilience (3 AP)",
	"HarmonicLink":"Harmonic Link (1/LR)", "WinterBreath":"Winter Breath (3 AP)",
	"FrostBurst":"Frost Burst (2 AP, 1/SR)", "FrostbornIcewalk":"Icewalk (1/SR)",
	"FrozenVeil":"Frozen Veil (1/LR)", "StormCall":"Stormcall (3 AP)",
	"GraveBind":"Gravebind (3 AP)", "Sporespit":"Sporespit (3 AP)",
	"RotbornItem":"Rotborn — Corrode Gear (1/LR)", "BloodlettingTouch":"Bloodletting Touch (3 AP)",
	"VelvetTerror":"Velvet Terror (3 SP)", "TombSense":"Tomb Sense (1/LR)",
	"Mindscratch":"Mindscratch (1/SR)", "GravitationalLeap":"Gravitational Leap (1/SR)",
	"NightborneVeilstep":"Veilstep (3 AP)", "CreepingDark":"Creeping Dark (1/LR)",
	"AbsorbMagic":"Absorb Magic (1/SR)", "DregspawnExtend":"Extend Reach (1/SR)",
	"AberrantFlex":"Aberrant Flex (1/SR)", "VoidAura":"Void Aura (1/LR or 6 SP)",
	"CrystalSlash":"Crystal Slash (1/SR)", "SealOfFrost":"Seal of Frost (1 SP)",
	"SilentLedger":"Silent Ledger (3 AP toggle)", "GlacialWall":"Glacial Wall (3 AP toggle)",
	"UnyieldingBulwark":"Unyielding Bulwark (2 SP)", "StoneMoldReshape":"Stoneflow Reshape (2 SP)",
	"ArchitectsShield":"Architect's Shield (3 AP toggle)", "MinersInstinct":"Miner's Instinct (3 AP toggle)",
	"WindCloak":"Wind Cloak (0 AP, 1/LR)", "Gustcaller":"Gustcaller (3 AP)",
	"PangolArmorReact":"Armor Reaction (0 AP)", "CurlUp":"Curl Up (0 AP, 1/SR)",
	"Uncurl":"Uncurl (1 AP)", "GildedBearing":"Gilded Bearing (0 AP, 1/SR)",
	"ChromaticShift":"Chromatic Shift (0 AP, 1/SR)", "PrismaticReflection":"Prismatic Reflection (0 AP, 1/LR)",
	"DustShroud":"Dust Shroud (0 AP, 1/LR)", "DustStrike":"Dust Strike (0 AP)",
	"ShatterPulseGlassborn":"Shatter Pulse (0 AP, 1/LR)", "PrismVeins":"Prism Veins (0 AP, 1/SR)",
	"DeathsWhisper":"Death's Whisper (0 AP, 1/LR)", "UnstableMutation":"Unstable Mutation (0 AP)",
	"FracturedMind":"Fractured Mind (0 AP)", "LuminousToggle":"Toggle Flame (0 AP)",
	"WaxenForm":"Waxen Form (3 AP)", "PainMadeFlesh":"Pain Made Flesh (0 AP, 1/LR)",
	"InfernalStare":"Infernal Stare (0 AP, 1/LR)", "InfernalSmite":"Infernal Smite (0 AP, 1/SR)",
	"WhipLash":"Whip Lash (3 AP)", "CursedSpark":"Cursed Spark (0 AP, 1/SR)",
	"DesertWalker":"Desert Walker (0 AP, 1/LR)", "Gore":"Gore (0 AP, VIT uses/SR)",
	"StubbornWill":"Stubborn Will (0 AP, 1/SR)", "HibernateUrsari":"Hibernate (0 AP, 1/LR)",
	"Blazeblood":"Blazeblood (0 AP, 1/SR)", "SootSight":"Soot Sight (0 AP, 1/LR)",
	"ShockPulse":"Shock Pulse (3 AP, 1 SP)", "SunderbornHibernate":"Lifeforce Hibernate (0 AP, 1/LR)",
	"LimbRegrowth":"Limb Regrowth (0 AP, 2 SP)", "AshrotAuraToggle":"Toggle Aura (0 AP)",
	"AshrotAuraBurst":"Aura Burst (0 AP, 1 SP)", "SmolderingGlare":"Smoldering Glare (0 AP, 1/LR)",
	"DraconicAwakening":"Draconic Awakening (0 AP, 1/LR)", "BreathWeapon":"Breath Weapon (3 AP)",
	"AbyssariGlowToggle":"Toggle Bioluminescence (0 AP)", "AbyssariPulse":"Abyssal Pulse (0 AP, 1/LR)",
	"MirelingEscape":"Slippery Escape (0 AP, 1/LR)", "LunarRadiance":"Lunar Radiance (0 AP, 1/LR)",
	"BrineCone":"Brine Cone (3 AP)", "EbbAndFlow":"Ebb and Flow (0 AP, SPD/LR)",
	"HydrasResilience":"Hydra's Resilience (0 AP, 1/SR)", "LimbSacrifice":"Limb Sacrifice (0 AP, 1/LR)",
	"Tidebind":"Tidebind (3 AP)", "AbyssalMutation":"Abyssal Mutation (0 AP, 1/SR)",
	"CloudlingFly":"Toggle Flight (0 AP)", "MistForm":"Mist Form (0 AP, 1/SR)",
	"SurgeStep":"Surge Step (0 AP)", "HuntersFocus":"Hunter's Focus (0 AP, 1/LR)",
	"WeirdResilience":"Weird Resilience (0 AP, 1/LR)", "RotVoice":"Rot Voice (3 AP)",
	"VoluntaryGasVent":"Gas Vent (0 AP, 1/LR)", "ObedientAuraToggle":"Toggle Obedient Aura (0 AP)",
	"MemoryEchoToggle":"Toggle Memory Echo (0 AP)", "LeechHex":"Leech Hex (0 AP)",
	"WitchsDraught":"Witch's Draught (3 AP)", "HexOfWithering":"Hex of Withering (2 AP)",
	"EtherealStep":"Ethereal Step (0 AP, 1 SP)", "VeiledPresence":"Veiled Presence (0 AP, 1/LR)",
	"ConvergentSynthesis":"Convergent Synthesis (0 AP, 1 SP)", "Dreamwalk":"Dreamwalk (0 AP, 1/LR)",
	"PhaseStep":"Phase Step (3 AP)", "Flicker":"Flicker (0 AP, 1/SR)",
	"Shadowmeld":"Shadowmeld (0 AP, 1/LR)", "VoidStep":"Void Step (0 AP, 1 SP)",
	"CorruptBreath":"Corrupt Breath (3 AP)", "DarkLineagePulse":"Dark Lineage Pulse (0 AP, DIV/LR)",
	"SapHealing":"Sap Healing (0 AP, 1/SR)", "EntropyTouch":"Entropy Touch (0 AP)",
	"Unravel":"Unravel (0 AP, 1/LR)", "MindBleed":"Mind Bleed (0 AP, 1/LR)",
	"NullMindShare":"Null Mind Share (0 AP, 1/LR)", "AmorphousSplit":"Amorphous Split (0 AP, 1/LR)",
	"ToxicSeep":"Toxic Seep (3 AP)", "DeathEaterMemory":"Death-Eater's Memory (0 AP, 1/LR)",
	"WingsOfForgotten":"Wings of the Forgotten (3 AP)", "ShiftingFormToggle":"Toggle Form (0 AP)",
	"DisjointedLeap":"Disjointed Leap (0 AP, 1/SR)", "TemporalFlicker":"Temporal Flicker (0 AP, 1/LR)",
	"HauntingWail":"Haunting Wail (3 AP)", "MirrorMove":"Mirror Move (3 AP)",
	"SilentScream":"Silent Scream (0 AP, 1/LR)", "RealitySlip":"Reality Slip (0 AP, 1/SR)",
	"UnnervinGaze":"Unnerving Gaze (3 AP)", "ResonantFormMimic":"Resonant Form Mimic (0 AP, 1/SR)",
	"DivineMimicry":"Divine Mimicry (0 AP, 1/LR)", "VitalSurge":"Vital Surge (0 AP)",
	"AbyssalGlow":"Abyssal Glow (3 AP, 1/LR)", "LanternbornGlowToggle":"Toggle Lantern Glow (0 AP)",
	"GuidingLight":"Guiding Light (3 AP)", "BeaconAbsorb":"Beacon (0 AP, 1/SR)",
	"KeenSightFocus":"Keen Sight Focus (3 AP)", "RadiantPulse":"Radiant Pulse (3 AP)",
	"LightStepTeleport":"Light Step (0 AP, 1/SR)", "DawnsBlessingActivate":"Dawn's Blessing (0 AP, 1/LR)",
	"RadiantWard":"Radiant Ward (0 AP, 1/SR)", "Flareburst":"Flareburst (0 AP, 1/SR)",
	"RunicSurgePrime":"Runic Surge (0 AP, 1/LR)", "MysticPulse":"Mystic Pulse (0 AP, 1/SR)",
	"Windstep":"Windstep (0 AP, SPD/SR)", "GlimmerfolkGlowToggle":"Toggle Glow (0 AP)",
	"Dazzle":"Dazzle (0 AP, 1 SP)", "VaporFormActivate":"Vapor Form (0 AP, 1 SP)",
	"DriftingFog":"Drifting Fog (0 AP, 1/LR)", "SporeBloom":"Spore Bloom (3 AP, 1/LR)",
	"WindswiftActivate":"Windswift (0 AP, 1 SP)", "TemporalShift":"Temporal Shift (0 AP, 1/SR)",
	"ArcanePulse":"Arcane Pulse (3 AP, 1/LR)", "RunicFlowAuto":"Runic Flow (0 AP, 1/LR)",
	"SparkforgedArcaneSurge":"Arcane Surge (0 AP, 1/LR)", "StaticSurge":"Static Surge (0 AP)",
	"EchoReflection":"Echo Reflection (3 AP)", "MemoryTap":"Memory Tap (0 AP, 1 SP)",
	"VoidCloakToggle":"Toggle Void Cloak (0 AP)", "SpellSink":"Spell Sink (3 AP)",
	"WarpResistanceToggle":"Toggle Warp Resistance (0 AP)", "SurgePulse":"Surge Pulse (3 AP, 1 SP)",
	"ParalyzingRay":"Paralyzing Ray (2 AP)", "FearRay":"Fear Ray (2 AP)",
	"HealingRay":"Healing Ray (2 AP)", "NecroticRay":"Necrotic Ray (1 AP)",
	"DisintegrationRay":"Disintegration Ray (3 AP)", "AntiMagicConeToggle":"Toggle Anti-Magic Cone (0 AP)",
	"NeuralLiquefaction":"Neural Liquefaction (2 AP)", "SkullDrill":"Skull Drill (3 AP)",
	"ResonantSermonToggle":"Toggle Resonant Sermon (0 AP)", "VoidCommunion":"Void Communion (0 AP, 1/LR)",
	"ThrenodySlamAttack":"Threnody Slam (3 AP)",
}

## Per-character, per-encounter trait cooldown tracking.
## key = "handle:traitId" → true if used (on cooldown)
var _trait_cooldowns: Dictionary = {}

## Returns "TraitId:available(bool)" pairs for all traits the character knows.
## For now every character has a small set based on their lineage.
func get_lineage_trait_states(handle: int) -> PackedStringArray:
	if not _chars.has(handle): return PackedStringArray()
	var c: Dictionary = _chars[handle]
	var lineage: String = c.get("lineage", "")
	var traits: Array = _lineage_traits_for(lineage)
	var result: PackedStringArray = PackedStringArray()
	for tid in traits:
		var key: String = "%d:%s" % [handle, tid]
		var used: bool = _trait_cooldowns.get(key, false)
		result.append("%s:%s" % [tid, "false" if used else "true"])
	return result

## Comprehensive lineage → active trait ID list.
## All trait IDs must exist in _TRAIT_LABELS.
func _lineage_traits_for(lineage: String) -> Array:
	match lineage:
		"Aetherian":          return ["EtherealStep", "VeiledPresence"]
		"Abyssari":           return ["AbyssariGlowToggle", "AbyssariPulse"]
		"Arcanite Human":     return ["ArcaneSurge"]
		"Archivist":          return ["MnemonicRecall"]
		"Ashrot Human":       return ["AshrotAuraToggle", "AshrotAuraBurst"]
		"Ashenborn":          return ["CursedSpark"]
		"Auroran":            return ["LightStepTeleport", "DawnsBlessingActivate"]
		"Beetlefolk":         return ["PangolArmorReact", "CurlUp", "Uncurl"]
		"Bespoker":           return ["ParalyzingRay", "FearRay", "HealingRay", "NecroticRay", "DisintegrationRay", "AntiMagicConeToggle"]
		"Bilecrawler":        return ["ToxicSeep"]
		"Blackroot":          return ["ToxicRoots", "WitherbornDecay"]
		"Blightmire":         return ["ToxicSeep", "AbsorbMagic"]
		"Blood Spawn":        return ["BloodlettingBlow"]
		"Bloodsilk Human":    return ["SilkenTrap", "DrainingFangs"]
		"Bloatfen Whisperer": return ["RotVoice", "LeechHex"]
		"Bogtender":          return ["MossyShroud"]
		"Boreal Human":       return ["WinterBreath", "FrostbornIcewalk"]
		"Bouncian":           return ["BoundingEscape"]
		"Bramblekin":         return ["Photosynthesis"]
		"Brain Eater":        return ["NeuralLiquefaction", "SkullDrill"]
		"Candlites":          return ["LuminousToggle", "WaxenForm"]
		"Canidar":            return ["PackHowl"]
		"Carrionari":         return ["DeathEaterMemory", "WingsOfForgotten"]
		"Cervin":             return ["NaturesGrace"]
		"Chokeling":          return ["Sporespit"]
		"Chronogears":        return ["TemporalShift", "OverdriveCore"]
		"Cindervolk":         return ["SmolderingGlare"]
		"Cloudling":          return ["CloudlingFly", "MistForm"]
		"Convergents":        return ["ConvergentSynthesis"]
		"Corvian":            return ["ShadowGlide"]
		"Corrupted Wyrmblood": return ["CorruptBreath", "DarkLineagePulse"]
		"Cragborn Human":     return ["StonesEndurance"]
		"Crimson Veil":       return ["BloodlettingTouch", "VelvetTerror"]
		"Cryptkin Human":     return ["Boneclatter", "DiseasebornCurse"]
		"Disjointed Hounds":  return ["ShiftingFormToggle", "DisjointedLeap"]
		"Drakari":            return ["BreathWeapon", "DraconicAwakening"]
		"Dreamer":            return ["Dreamwalk"]
		"Dregspawn":          return ["DregspawnExtend", "AberrantFlex"]
		"Driftwood Woken":    return ["EbbAndFlow"]
		"Duckslings":         return ["QuackAlarm"]
		"Dustborn":           return ["DustShroud"]
		"Duskling":           return ["Shadowgrasp"]
		"Echo-Touched":       return ["ResonantFormMimic", "DivineMimicry"]
		"Echoform Warden":    return ["EchoReflection", "MemoryTap"]
		"Elf":                return ["ResilientSpirit"]
		"Emberkin":           return ["Blazeblood", "SootSight"]
		"Fae-Touched Human":  return ["FeyStep", "EnchantingPresence"]
		"Felinar":            return ["SilkenTrap", "LurkerStep", "DrainingFangs"]
		"Ferrusk":            return ["OverdriveCore"]
		"Filthlit Spawn":     return ["MemoryEchoToggle", "ToxicSeep"]
		"Flenskin":           return ["PainMadeFlesh"]
		"Frostborn":          return ["WinterBreath", "FrostBurst", "FrostbornIcewalk"]
		"Galesworn Human":    return ["WindCloak", "Gustcaller"]
		"Gilded Human":       return ["MarketWhisperer"]
		"Glaceari":           return ["FrozenVeil"]
		"Glassborn":          return ["ShatterPulseGlassborn", "PrismVeins"]
		"Glimmerfolk":        return ["GlimmerfolkGlowToggle", "Dazzle"]
		"Gloomling":          return ["UmbralDodge"]
		"Goldscale":          return ["SunsFavor", "HeatedScalesToggle"]
		"Gravari":            return ["StonesEndurance"]
		"Graveleaps":         return ["StonesEndurance"]
		"Gravetouched":       return ["DeathsWhisper"]
		"Gravemantle":        return ["GravitationalLeap"]
		"Gremlin","Gremlidian": return ["GremlinTinker", "GremlinSabotage", "GremlinsLuck"]
		"Grimshell":          return ["StonesEndurance"]
		"Groblodyte":         return ["ScrapInstinct"]
		"Gullet Mimes":       return ["MirrorMove", "SilentScream"]
		"Hagborn Crone":      return ["HexOfWithering", "WitchsDraught"]
		"Hearthkin":          return ["KindleFlame"]
		"Hellforged":         return ["InfernalStare"]
		"Hexkin":             return ["HexMark", "Witchblood"]
		"Hexshell":           return ["ReflectHex"]
		"Hollowroot":         return ["SapHealing"]
		"Huskdrone":          return ["VoluntaryGasVent", "ObedientAuraToggle"]
		"Hydrakari":          return ["HydrasResilience", "LimbSacrifice"]
		"Ironhide":           return ["ArmoredPlating", "MechanicalMindRecall"]
		"Ironjaw":            return ["IronStomachPoison"]
		"Jackal Human":       return ["TombSense"]
		"Kelpheart Human":    return ["Tidebind"]
		"Kettlekyn":          return ["SteamJet"]
		"Kindlekin":          return ["AlchemicalAffinity", "CursedSpark"]
		"Lanternborn":        return ["LanternbornGlowToggle", "GuidingLight"]
		"Lifeborne":          return ["VitalSurge", "AbyssalGlow"]
		"Lightbound":         return ["RadiantWard", "Flareburst"]
		"Lithari":            return ["StonesEndurance"]
		"Lost":               return ["TemporalFlicker", "HauntingWail"]
		"Luminar Human":      return ["BeaconAbsorb"]
		"Madness-Touched Human": return ["UnstableMutation", "FracturedMind"]
		"Marionox":           return ["TetherStep"]
		"Mireling":           return ["MirelingEscape"]
		"Mireborn Human":     return ["MireBurst"]
		"Mistborn Human":     return ["VaporFormActivate", "DriftingFog"]
		"Mistborne Hatchling": return ["WarpResistanceToggle", "SurgePulse"]
		"Moonkin":            return ["LunarRadiance"]
		"Mossling":           return ["SporeBloom"]
		"Myconid":            return ["SporeCloud", "FungalFortitude", "Photosynthesis"]
		"Myrrhkin":           return ["SoothingAura", "Dreamscent"]
		"Nightborne Human":   return ["NightborneVeilstep", "CreepingDark"]
		"Nihilian":           return ["EntropyTouch", "Unravel"]
		"Nimbari":            return ["StormCall"]
		"Nullborn":           return ["VoidAura"]
		"Nullborn Ascetic":   return ["VoidCloakToggle", "SpellSink"]
		"Oblivari Human":     return ["MindBleed", "NullMindShare"]
		"Obsidian Seraph":    return ["InfernalSmite"]
		"Oozeling":           return ["AmorphousSplit"]
		"Pangol":             return ["PangolArmorReact", "CurlUp", "Uncurl"]
		"Panoplian":          return ["SentinelStand"]
		"Parallax Watchers":  return ["RealitySlip", "UnnervinGaze"]
		"Porcelari":          return ["GildedBearing"]
		"Prismari":           return ["ChromaticShift", "PrismaticReflection"]
		"Pulsebound Hierophant": return ["ResonantSermonToggle", "VoidCommunion"]
		"Quillari":           return ["QuillLaunch", "QuickReflexes"]
		"Regal Human":        return ["VersatileGrant", "ResilientSpirit"]
		"Riftborn Human":     return ["PhaseStep", "Flicker"]
		"Rotborn Herald":     return ["RotVoice"]
		"Runeborn Human":     return ["RunicSurgePrime", "MysticPulse"]
		"Sable":              return ["SableNightVision", "CreepingDark"]
		"Sandstrider Human":  return ["DesertWalker"]
		"Saurian":            return ["AdaptiveHide", "StonesEndurance"]
		"Scavenger Human":    return ["ScrapSense"]
		"Scourling Human":    return ["WhipLash"]
		"Serpentine":         return ["VenomousBite", "ExtractVenom", "HypnoticGaze"]
		"Shadewretch":        return ["Shadowmeld"]
		"Shardkin":           return ["CrystalResilience", "HarmonicLink"]
		"Shardwraith":        return ["CrystalSlash"]
		"Silverblood":        return ["ArcanePulse", "RunicFlowAuto"]
		"Skulkin":            return ["GnawingGrin"]
		"Skysworn":           return ["KeenSightFocus"]
		"Sludgeling":         return ["AmorphousSplit", "ToxicSeep"]
		"Snareling":          return ["QuickReflexes"]
		"Sparkforged Human":  return ["SparkforgedArcaneSurge"]
		"Starborn":           return ["RadiantPulse"]
		"Stormclad":          return ["ShockPulse"]
		"Sunderborn Human":   return ["SunderbornHibernate", "LimbRegrowth"]
		"Taurin":             return ["Gore", "StubbornWill"]
		"Tetrasimian":        return ["AdaptiveHide"]
		"Threnody Warden":    return ["ThrenodySlamAttack"]
		"Thornwrought Human": return ["VerdantCurse"]
		"Tiderunner Human":   return ["BrineCone"]
		"Tidewoven":          return ["SurgeStep"]
		"Tombwalker":         return ["GraveBind"]
		"Trenchborn":         return ["AbyssalMutation"]
		"Twilightkin":        return ["Veilstep", "DuskbornGrace"]
		"Umbrawyrm":          return ["VoidStep"]
		"Ursari":             return ["HibernateUrsari"]
		"Venari":             return ["HuntersFocus"]
		"Verdant":            return ["Regrowth", "NaturesVoice"]
		"Voxilite":           return ["CommandingVoice"]
		"Voxshell":           return ["ResonantVoice"]
		"Vulpin":             return ["IllusoryEcho", "TrickstersDodge"]
		"Watchling":          return ["StaticSurge"]
		"Weirkin Human":      return ["WeirdResilience"]
		"Whisperspawn":       return ["Mindscratch"]
		"Zephyrkin":          return ["Windstep"]
		"Zephyrite":          return ["WindswiftActivate"]
		_:
			# Generic fallback: Quick Reflexes + Resilient Spirit
			return ["QuickReflexes", "ResilientSpirit"]

## Parse AP cost from trait label string (look for a leading digit before "AP").
func _trait_ap_cost(trait_id: String) -> int:
	var label: String = _TRAIT_LABELS.get(trait_id, "")
	# Pattern: "(N AP" or "(N AP," — extract N
	var re := RegEx.new()
	re.compile(r"\((\d+)\s*AP")
	var m = re.search(label)
	if m != null:
		return int(m.get_string(1))
	return 0   # "0 AP" or free traits

## Returns available trait actions for the entity (only available/off-cooldown ones).
func get_available_lineage_trait_actions(entity_id: String) -> Array:
	var ent = _dung_find(entity_id)
	if ent == null or not bool(ent["is_player"]) or bool(ent["is_dead"]): return []
	var handle: int = int(ent.get("handle", -1))
	if handle < 0 or not _chars.has(handle): return []

	var states: PackedStringArray = get_lineage_trait_states(handle)
	var actions: Array = []
	for raw in states:
		var sep: int = raw.find(":")
		if sep < 0: continue
		var tid: String   = raw.substr(0, sep)
		var avail: bool   = raw.substr(sep + 1) == "true"
		if not avail: continue
		var label: String = _TRAIT_LABELS.get(tid, tid)
		var ap: int       = _trait_ap_cost(tid)
		actions.append(_make_action(
			label, "Lineage", ACT_TRAIT, ap,
			0, false, false, tid, 0, 1, false, 0,
			"Lineage trait: %s" % label))
	return actions

# ── Serialization ─────────────────────────────────────────────────────────────
func serialize_character(handle: int) -> String:
	if not _chars.has(handle): return ""
	return JSON.stringify(_chars[handle])

func deserialize_character(data: String) -> int:
	if data.is_empty(): return -1
	var parsed = JSON.parse_string(data)
	if parsed == null or not parsed is Dictionary: return -1
	var h: int = _next_handle
	_next_handle += 1
	_chars[h] = parsed
	_chars[h]["id"] = "char_%d" % h
	return h

# ── Inventory (stubs) ─────────────────────────────────────────────────────────
func add_item_to_inventory(handle: int, item_name: String) -> void:
	if _chars.has(handle): _chars[handle]["items"].append(item_name)

func remove_item_from_inventory(handle: int, item_name: String) -> void:
	if not _chars.has(handle): return
	# Auto-unattune if the item is leaving the character's possession
	if item_name in _chars[handle].get("attuned", []):
		unattune_item(handle, item_name)
	_chars[handle]["items"].erase(item_name)

## Exact armor names from PHB — used as primary lookup before keyword fallback
const _ARMOR_EXACT: Dictionary = {
	"Padded":          11, "Leather":        11, "Studded Leather": 12,
	"Hide":            12, "Chain Shirt":    13, "Scale Mail":      14,
	"Breastplate":     14, "Half Plate":     15,
	"Ring Mail":       14, "Chain Mail":     16, "Splint":          17,
	"Plate":           18,
	"Standard Shield": 2,  "Tower Shield":   3,
}

## Exact weapon names from PHB
const _WEAPON_EXACT: Array = [
	"Chakram", "Club", "Dagger", "Greatclub", "Handaxe", "Javelin",
	"Light Hammer", "Mace", "Quarterstaff", "Sickle", "Spear", "Shortsword",
	"Dart", "Light Crossbow", "Shortbow", "Sling",
	"Battleaxe", "Flail", "Glaive", "Greataxe", "Greatsword", "Halberd",
	"Katana", "Lance", "Longsword", "Maul", "Morningstar", "Pike",
	"Rapier", "Scimitar", "Trident", "Warhammer", "War Pick", "Whip",
	"Blowgun", "Hand Crossbow", "Heavy Crossbow", "Longbow", "Heavy Sling",
	"Musket", "Pistol",
]

## Exact light source names
const _LIGHT_EXACT: Array = [
	"Torch", "Candle", "Lamp", "Lantern, Bullseye", "Lantern, Hooded",
]

func equip_item(handle: int, item_name: String) -> void:
	if not _chars.has(handle): return
	var c: Dictionary = _chars[handle]
	var w: String = item_name.to_lower()

	# 1. Exact name check for shields (including constructs)
	if item_name == "Standard Shield" or item_name == "Tower Shield" or item_name == "Construct Shield" or item_name == "Construct Tower Shield":
		c["shield"] = item_name
		c["ac"]     = _compute_ac(handle)  # include shield bonus + Speed
		return

	# 2. Exact name check for armor
	if _ARMOR_EXACT.has(item_name) and item_name != "Standard Shield" and item_name != "Tower Shield":
		c["armor"] = item_name
		c["ac"]    = _compute_ac(handle)   # includes Speed modifier
		return

	# 3. Exact name check for weapons
	if item_name in _WEAPON_EXACT:
		c["weapon"]          = item_name
		c["equipped_weapon"] = item_name
		return

	# 4. Exact name check for light sources
	if item_name in _LIGHT_EXACT:
		c["light"] = item_name
		return

	# 5. Keyword fallback for custom/modded items
	if "shield" in w or "buckler" in w:
		c["shield"] = item_name
		c["ac"]     = _compute_ac(handle)
	elif "armor" in w or "mail" in w or "robe" in w or "vest" in w or \
		 "plate" in w or "breastplate" in w or "padded" in w or "splint" in w or \
		 "leather" in w or "hide" in w or "studded" in w:
		c["armor"] = item_name
		c["ac"]    = _compute_ac(handle)
	elif "torch" in w or "lantern" in w or "candle" in w or "lamp" in w:
		c["light"] = item_name
	else:
		c["weapon"]          = item_name
		c["equipped_weapon"] = item_name

## PHB armor AC with Speed modifier.
## Light armor: base + Speed (no cap).
## Medium armor: base + Speed (max 2).
## Heavy armor: flat (no Speed).
func _armor_ac_with_speed(armor: String, spd_v: int) -> int:
	match armor:
		"Padded":          return 11 + spd_v           # Light
		"Leather":         return 11 + spd_v           # Light
		"Studded Leather": return 12 + spd_v           # Light
		"Hide":            return 12 + mini(spd_v, 2)  # Medium
		"Chain Shirt":     return 13 + mini(spd_v, 2)  # Medium
		"Scale Mail":      return 14 + mini(spd_v, 2)  # Medium
		"Breastplate":     return 14 + mini(spd_v, 2)  # Medium
		"Half Plate":      return 15 + mini(spd_v, 2)  # Medium
		"Ring Mail":       return 14                   # Heavy
		"Chain Mail":      return 16                   # Heavy
		"Splint":          return 17                   # Heavy
		"Plate":           return 18                   # Heavy
	# Construct armor: light=11+SPD, medium=14+SPD(max 2), heavy=17
	var a: String = armor.to_lower()
	if "construct light armor" in a:  return 11 + spd_v
	if "construct medium armor" in a: return 14 + mini(spd_v, 2)
	if "construct heavy armor" in a:  return 17
	# Keyword fallback for custom/modded armor
	if "plate" in a and "half" in a:  return 15 + mini(spd_v, 2)
	if "plate" in a:                  return 18
	if "splint" in a:                 return 17
	if "chain mail" in a:             return 16
	if "scale mail" in a:             return 14 + mini(spd_v, 2)
	if "breastplate" in a:            return 14 + mini(spd_v, 2)
	if "chain shirt" in a:            return 13 + mini(spd_v, 2)
	if "ring mail" in a:              return 14
	if "studded" in a:                return 12 + spd_v
	if "hide" in a:                   return 12 + mini(spd_v, 2)
	if "leather" in a:                return 11 + spd_v
	if "padded" in a:                 return 11 + spd_v
	return 10 + spd_v

## Legacy wrapper (no Speed bonus). Use _armor_ac_with_speed() for character sheets.
func _armor_ac(armor: String) -> int:
	return _armor_ac_with_speed(armor, 0)

## Helper: get feat tier for a character handle (0 if not unlocked)
func _feat_tier(handle: int, feat_name: String) -> int:
	if not _chars.has(handle): return 0
	return int(_chars[handle].get("feats", {}).get(feat_name, 0))

## Helper: get feat tier from dungeon entity dict
func _ent_feat_tier(ent: Dictionary, feat_name: String) -> int:
	var h: int = int(ent.get("handle", -1))
	if h < 0: return 0
	return _feat_tier(h, feat_name)

## Helper: check/use a per-rest limited feat charge. Returns true if charge available.
func _ent_use_feat_charge(ent: Dictionary, key: String, max_uses: int) -> bool:
	var used: int = int(ent.get(key, 0))
	if used >= max_uses: return false
	ent[key] = used + 1
	return true

## Helper: check if character is wearing armor
func _is_unarmored(handle: int) -> bool:
	if not _chars.has(handle): return true
	var a: String = _chars[handle].get("armor", "None")
	return a == "None" or a.is_empty()

## Helper: check if character is wearing heavy armor
func _is_heavy_armor(handle: int) -> bool:
	if not _chars.has(handle): return false
	var a: String = _chars[handle].get("armor", "None").to_lower()
	return "plate" in a or "chain mail" in a or "splint" in a or "ring mail" in a

## Helper: check if character has a shield equipped
func _has_shield(handle: int) -> bool:
	if not _chars.has(handle): return false
	var s: String = _chars[handle].get("shield", "None")
	return s != "None" and not s.is_empty()

## Full AC for a character: armor-type formula + Speed + shield + feat bonuses.
func _compute_ac(handle: int) -> int:
	if not _chars.has(handle): return 10
	var c: Dictionary = _chars[handle]
	var s_arr: Array = c.get("stats", [1, 1, 1, 1, 1])
	var spd_v: int = int(s_arr[1]) if s_arr.size() > 1 else 1
	var str_v: int = int(s_arr[0]) if s_arr.size() > 0 else 1
	var vit_v: int = int(s_arr[3]) if s_arr.size() > 3 else 1
	var armor: String  = c.get("armor",  "None")
	var shield: String = c.get("shield", "None")
	var feats: Dictionary = c.get("feats", {})
	var base_ac: int

	var is_unarmed: bool = (armor == "None" or armor.is_empty())
	if is_unarmed:
		# Unarmored Master: T1 AC = 2×Speed + 10; T4 also grants resistance flag
		var um_t: int = int(feats.get("Unarmored Master", 0))
		if um_t >= 1:
			base_ac = 10 + spd_v * 2
		else:
			base_ac = 10 + spd_v
	else:
		base_ac = _armor_ac_with_speed(armor, spd_v)

	# Shield bonus (PHB: Standard +2, Tower +3, Construct variants match)
	if shield == "Standard Shield" or shield == "Construct Shield":
		base_ac += 2
	elif shield == "Tower Shield" or shield == "Construct Tower Shield":
		base_ac += 3

	# Unyielding Defender: +1 AC per tier (max +3) — already in recalc but also here
	var ud_t: int = int(feats.get("Unyielding Defender", 0))
	if ud_t >= 1:
		base_ac += mini(ud_t, 3)

	# Deflective Stance: +1 AC per tier when dodging (applied in combat, not here)
	# But base passive: T1 = +1 dodge_attack_bonus tracked elsewhere

	# Titanic Bastion: T2 adds Strength to AC
	var tb_t: int = int(feats.get("Titanic Bastion", 0))
	if tb_t >= 2 and not is_unarmed:
		base_ac += str_v

	# Balanced Bulwark: T1 +1 AC, T3 +2 AC, T5 +3 AC (medium armor only)
	var bb_t: int = int(feats.get("Balanced Bulwark", 0))
	if bb_t >= 1:
		var a_low: String = armor.to_lower()
		var is_medium: bool = ("chain shirt" in a_low or "scale" in a_low or
			"breastplate" in a_low or "half plate" in a_low or "hide" in a_low)
		if is_medium:
			if bb_t >= 5: base_ac += 3
			elif bb_t >= 3: base_ac += 2
			else: base_ac += 1

	# Tower Shield feat: T1 grants shield proficiency (no speed penalty)
	var ts_t: int = int(feats.get("Tower Shield", 0))
	if ts_t >= 2 and shield != "None" and not shield.is_empty():
		base_ac += 1  # T2: +1 AC with shields

	# Evasive Ward: T1 +1 AC when unarmored or light armor
	var ew_t: int = int(feats.get("Evasive Ward", 0))
	if ew_t >= 1:
		var a_low2: String = armor.to_lower()
		var is_light_or_none: bool = is_unarmed or "leather" in a_low2 or "padded" in a_low2 or "hide" in a_low2 or "studded" in a_low2
		if is_light_or_none:
			base_ac += mini(ew_t, 3)

	# Magic item AC bonuses (Binding Nail +1, Mothwing Brooch +1, etc.)
	base_ac += _magic_item_bonus(handle, "ac")

	# Ironroot Draught temporary AC buff
	base_ac += int(c.get("ironroot_ac_bonus", 0))

	return base_ac

func unequip_item(handle: int, slot: int) -> void:
	if not _chars.has(handle): return
	var c: Dictionary = _chars[handle]
	match slot:
		0: c["weapon"] = "None";  c["equipped_weapon"] = "None"
		1: c["armor"]  = "None";  c["ac"] = _compute_ac(handle)
		2: c["shield"] = "None";  c["ac"] = _compute_ac(handle)
		3: c["light"]  = "None"

func use_consumable(handle: int, item_name: String) -> String:
	if not _chars.has(handle): return "No character."
	var c: Dictionary = _chars[handle]
	var items: Array = c.get("items", [])
	if not item_name in items: return "%s not in inventory." % item_name
	var result: String = _apply_consumable_effect(c, item_name)
	if result == "":
		return "Nothing happened."
	items.erase(item_name)
	return result

## Core consumable effect logic shared between inventory and dungeon combat.
func _apply_consumable_effect(c: Dictionary, item_name: String) -> String:
	var hp: int     = int(c.get("hp", 0))
	var max_hp: int = int(c.get("max_hp", 1))
	var sp: int     = int(c.get("sp", 0))
	var max_sp: int = int(c.get("max_sp", 1))
	var ap: int     = int(c.get("ap", 0))
	var max_ap: int = int(c.get("max_ap", 6))
	var name_: String = str(c.get("name", "???"))

	match item_name:
		"Potion of Healing":
			var heal: int = 10
			c["hp"] = mini(max_hp, hp + heal)
			return "%s drinks a Potion of Healing — restored %d HP (%d/%d)." % [name_, heal, c["hp"], max_hp]
		"Lesser Potion of Healing":
			var heal: int = 5
			c["hp"] = mini(max_hp, hp + heal)
			return "%s drinks a Lesser Potion — restored %d HP (%d/%d)." % [name_, heal, c["hp"], max_hp]
		"Potion of Revive":
			if hp > 0:
				return "%s is not downed — Potion of Revive has no effect." % name_
			c["hp"] = mini(max_hp, 5)
			c["is_dead"] = false
			return "%s is revived with 5 HP!" % name_
		"Ether Flask":
			var gain: int = 5
			c["sp"] = mini(max_sp, sp + gain)
			return "%s sips an Ether Flask — restored %d SP (%d/%d)." % [name_, gain, c["sp"], max_sp]
		"Adrenaline Shot":
			var gain: int = 3
			c["ap"] = mini(max_ap, ap + gain)
			return "%s injects an Adrenaline Shot — restored %d AP (%d/%d)." % [name_, gain, c["ap"], max_ap]
		"Ironroot Draught":
			# Temporary AC bonus stored as a buff; +2 AC for next combat
			c["ironroot_ac_bonus"] = 2
			return "%s drinks an Ironroot Draught — skin hardens (+2 AC until next rest)." % name_
		"Holy Water (flask)":
			# Throwable — deals 2d6 radiant to undead in combat; out of combat just a message
			return "%s blesses the area with Holy Water." % name_
		"Alchemist's Fire (flask)":
			return "%s readies Alchemist's Fire (use in combat for 1d4 fire/turn)." % name_
		"Acid (vial)":
			return "%s readies a vial of Acid (use in combat for 2d6 acid)." % name_
		"Poison, Basic (vial)":
			# Coat weapon with poison
			c["weapon_poison_charges"] = 3
			return "%s coats their weapon with poison (+1d4 poison for 3 hits)." % name_
		"Healer's Kit":
			# Stabilize a downed ally — out of combat, just heal 1 HP
			if hp <= 0:
				c["hp"] = 1
				c["is_dead"] = false
				return "%s is stabilized with a Healer's Kit (1 HP)." % name_
			return "%s has the Healer's Kit ready." % name_

	# Generic potion fallback for any custom "Potion" items
	if "Potion" in item_name or "potion" in item_name:
		var heal: int = randi_range(4, 10) + 2
		c["hp"] = mini(max_hp, hp + heal)
		return "%s drinks %s — restored %d HP." % [name_, item_name, heal]

	return ""

func get_item_details(handle: int, item_name: String) -> PackedStringArray:
	# Character-owned items currently use the registry baseline (no per-instance state)
	return _format_item_details(item_name)

func _format_item_details(item_name: String) -> PackedStringArray:
	# UI layout: [rarity, cur_hp, max_hp, cost, item_type, mech_fields..., description]
	if not _ITEM_REGISTRY.has(item_name):
		return PackedStringArray(["Mundane", "0", "0", "0", "General", "Unknown item."])
	var d = _ITEM_REGISTRY[item_name]
	var raw_type: String = str(d[0])
	var price: int = int(d[1])
	var desc: String = str(d[2])

	var rarity: String = "Mundane"
	var ui_type: String = "General"
	var cur_hp: int = 0
	var max_hp: int = 0
	var extra: Array = []

	match raw_type:
		"Weapon":
			ui_type = "Weapon"
			max_hp = 50
			cur_hp = 50
			# Parse damage dice and type from description if possible
			var dmg_dice: String = _parse_damage_dice(desc)
			var dmg_type: String = _parse_damage_type(desc)
			var props: String = _parse_weapon_properties(desc)
			extra = [dmg_dice, dmg_type, props]
		"Armor":
			if item_name.find("Shield") >= 0:
				ui_type = "Shield"
				max_hp = 60
				cur_hp = 60
			else:
				ui_type = "Armor"
				max_hp = 100
				cur_hp = 100
			var ac_info: String = _parse_ac_info(desc)
			var weight_class: String = _parse_armor_weight_class(desc)
			extra = [ac_info, weight_class]
		"Magic":
			ui_type = "General"
			rarity = _parse_magic_rarity(item_name)
			max_hp = 20
			cur_hp = 20
		"Consumable":
			ui_type = "Consumable"
		"Misc":
			ui_type = "General"
		_:
			ui_type = "General"

	var out: Array = [rarity, str(cur_hp), str(max_hp), str(price), ui_type]
	for e in extra:
		out.append(str(e))
	out.append(desc)
	return PackedStringArray(out)

func _parse_damage_dice(desc: String) -> String:
	# Look for patterns like "1d6", "2d6", "1d8/1d10"
	var regex := RegEx.new()
	regex.compile("(\\d+d\\d+(?:/\\d+d\\d+)?)")
	var m = regex.search(desc)
	return m.get_string() if m != null else "1d4"

func _parse_damage_type(desc: String) -> String:
	for t in ["Piercing", "Slashing", "Bludgeoning", "Fire", "Cold", "Acid",
			  "Lightning", "Radiant", "Necrotic", "Psychic", "Force", "Poison", "Thunder"]:
		if desc.find(t) >= 0:
			return t
	return "Bludgeoning"

func _parse_weapon_properties(desc: String) -> String:
	var props: PackedStringArray = PackedStringArray()
	for p in ["Finesse", "Light", "Heavy", "Reach", "Thrown", "Two-Handed", "Versatile", "Range"]:
		if desc.find(p) >= 0:
			props.append(p)
	if props.is_empty():
		return "Standard"
	return ", ".join(props)

func _parse_ac_info(desc: String) -> String:
	var regex := RegEx.new()
	regex.compile("(AC \\d+|\\+\\d+ AC)")
	var m = regex.search(desc)
	return m.get_string() if m != null else "AC 10"

func _parse_armor_weight_class(desc: String) -> String:
	if desc.find("Heavy") >= 0: return "Heavy"
	if desc.find("Medium") >= 0: return "Medium"
	if desc.find("Light") >= 0: return "Light"
	return "Light"

func _parse_magic_rarity(item_name: String) -> String:
	# Derive magic rarity. Default to Common for the small baseline items.
	if item_name.find("Legendary") >= 0: return "Legendary"
	if item_name.find("Very Rare") >= 0: return "Very Rare"
	if item_name.find("Rare") >= 0: return "Rare"
	if item_name.find("Uncommon") >= 0: return "Uncommon"
	return "Common"

## Item registry data  [type, price, description]
const _ITEM_REGISTRY: Dictionary = {
	# --- Magic / Common items ---
	"Amberglow Pendant":       ["Magic", 50,  "A pendant that emits a warm, soothing light. +2 HP, +10 ft light radius."],
	"Amulet of Comfort +1":    ["Magic", 50,  "An amulet that regulates the wearer's temperature. +1 Fire Resist, +1 Cold Resist."],
	"Aether-Touched Lens":     ["Magic", 50,  "A glass lens that reveals faint magical signatures. Detect Magic, +1 Perception."],
	"Anvilstone":              ["Magic", 50,  "A small stone that sharpens blades effortlessly. +1 Damage."],
	"Arcane Stitching Kit":    ["Magic", 50,  "Self-threading needles that repair fabric with light. +2 HP restored on rest."],
	"Ashcloak Thread":         ["Magic", 50,  "Thread that makes garments resistant to minor burns. +2 Fire Resist."],
	"Babelstone Charm":        ["Magic", 50,  "A charm that helps understand basic phrases in common dialects. +1 to all Skill checks."],
	"Binding Nail":            ["Magic", 50,  "A nail that, once hammered, cannot be removed except by its owner. +1 AC."],
	"Candle of Clarity":       ["Magic", 50,  "A candle whose smoke sharpens the mind. +2 SP, +1 Perception."],
	"Candle of Echoes":        ["Magic", 50,  "A candle that plays back the last sound it heard when lit. +2 Perception."],
	"Cleansing Stone":         ["Magic", 50,  "A smooth stone that removes dirt and grime on contact. +1 Poison Resist."],
	"Cradleleaf Poultice":     ["Magic", 50,  "A medicinal leaf that speeds up natural recovery. +4 HP restored on rest."],
	"Dagger of the Last Word": ["Magic", 50,  "A dagger that always hits a target below 5 HP. Auto-hit vs targets under 5 HP, +1 Hit."],
	"Dowsing Rod":             ["Magic", 50,  "A forked stick that twitches when near fresh water. +2 Perception."],
	"Dustveil Cloak":          ["Magic", 50,  "A cloak that blends into dusty environments. +2 Stealth."],
	"Echoing Rift Stone":      ["Magic", 50,  "A stone that records and replays 5 seconds of sound. +1 Perception."],
	"Flickerflame Matchbox":   ["Magic", 50,  "A box that creates a tiny, harmless magical flame. +5 ft light radius."],
	"Forager's Pouch":         ["Magic", 50,  "A pouch that increases the quality of found food. +3 HP restored on rest."],
	"Glass of Truth":          ["Magic", 50,  "A monocle that reveals if a liquid is poisonous. Detect Poison, +1 Perception."],
	"Glass of Revelation":     ["Magic", 50,  "A lens that reveals hidden runes and magical auras. Detect Magic."],
	"Glowroot Bandage":        ["Magic", 50,  "A bandage that glows faintly, providing light while healing. +2 Healing, +5 ft light radius."],
	"Mender's Thread":         ["Magic", 50,  "Magical thread that mends small tears in clothing instantly. +1 HP restored on rest."],
	"Messenger Feather":       ["Magic", 50,  "A feather that delivers written notes to a nearby person. +1 to all Skill checks."],
	"Mothwing Brooch":         ["Magic", 50,  "A brooch that slows fall speed. Slow Fall, +1 AC."],
	"Needle of Silence":       ["Magic", 50,  "A needle used to sew lips shut magically (temporary). +3 Stealth."],
	"Pebble of Echoes":        ["Magic", 50,  "A stone that repeats the user's whisper after a delay. +1 Perception."],
	"Scribe's Quill":          ["Magic", 50,  "A quill that never runs out of ink. +1 SP."],
	"Shadow Sovereign's Coin": ["Magic", 50,  "A coin that always lands on the side the owner chooses. +2 to all Skill checks."],
	"Scent Masker":            ["Magic", 50,  "A small vial that neutralizes the wearer's scent. +2 Stealth, Scent Mask."],
	"Silent Bell":             ["Magic", 50,  "A bell that makes no sound except in the user's mind. +1 Stealth, +1 Perception."],
	"Smoke Puff":              ["Magic", 50,  "A small ball that creates a 5ft cloud of obscuring smoke. +1 Stealth."],
	"Traveler's Chalice":      ["Magic", 50,  "A cup that purifies any water poured into it. +2 Poison Resist, +1 HP restored on rest."],
	# --- Consumables ---
	"Potion of Healing":       ["Consumable", 50,  "Restores 10 hit points."],
	"Lesser Potion of Healing":["Consumable", 25,  "Restores 5 hit points."],
	"Potion of Revive":        ["Consumable", 150, "Revives an agent at 0 HP to 5 HP."],
	"Ether Flask":             ["Consumable", 60,  "Restores 5 Soul Points."],
	"Adrenaline Shot":         ["Consumable", 40,  "Restores 3 Action Points."],
	"Ironroot Draught":        ["Consumable", 100, "Hardens the skin. +2 AC for the current combat encounter."],
	# --- Simple Melee Weapons ---
	"Chakram":      ["Weapon", 5,  "A circular throwing blade used by scouts. 1d6 Slashing. Light, Finesse, Thrown (30/90)."],
	"Club":         ["Weapon", 1,  "A simple wooden cudgel. 1d4 Bludgeoning. Light, Finesse."],
	"Dagger":       ["Weapon", 2,  "A standard tactical knife. 1d4 Piercing. Finesse, Light, Thrown (20/60)."],
	"Greatclub":    ["Weapon", 1,  "A massive wooden log. 1d8 Bludgeoning. Two-Handed."],
	"Handaxe":      ["Weapon", 5,  "A small, balanced axe. 1d6 Slashing. Light, Thrown (20/60), Finesse."],
	"Javelin":      ["Weapon", 1,  "A light spear for throwing. 1d6 Piercing. Thrown (30/120), Finesse."],
	"Light Hammer": ["Weapon", 2,  "A small hammer repurposed for combat. 1d4 Bludgeoning. Light, Thrown (20/60), Finesse."],
	"Mace":         ["Weapon", 5,  "A heavy iron-headed club. 1d6 Bludgeoning. Finesse."],
	"Quarterstaff": ["Weapon", 1,  "A long wooden staff. 1d6/1d8 Bludgeoning. Versatile (1d8), Finesse."],
	"Sickle":       ["Weapon", 1,  "A curved farm tool. 1d4 Slashing. Light, Finesse."],
	"Spear":        ["Weapon", 1,  "A wooden pole with a sharp metal point. 1d6/1d8 Piercing. Thrown (20/60), Versatile (1d8)."],
	"Shortsword":   ["Weapon", 10, "A versatile short-range blade. 1d6 Piercing. Finesse, Light."],
	# --- Simple Ranged Weapons ---
	"Dart":           ["Weapon", 1,  "Small throwing spikes. 1d4 Piercing. Finesse, Thrown (20/60)."],
	"Light Crossbow": ["Weapon", 25, "A compact mechanical bow. 1d8 Piercing. Range (80/320), Two-Handed."],
	"Shortbow":       ["Weapon", 25, "A small, lightweight bow. 1d6 Piercing. Range (80/320), Two-Handed."],
	"Sling":          ["Weapon", 1,  "A leather strap for throwing stones. 1d4 Bludgeoning. Range (30/120)."],
	# --- Martial Melee Weapons ---
	"Battleaxe":  ["Weapon", 10, "A heavy axe for warfare. 1d8/1d10 Slashing. Versatile (1d10)."],
	"Flail":      ["Weapon", 10, "A spiked ball on a chain. 1d8 Bludgeoning."],
	"Glaive":     ["Weapon", 20, "A polearm with a large blade. 2d6 Slashing. Heavy, Reach, Two-Handed."],
	"Greataxe":   ["Weapon", 30, "A massive two-handed axe. 1d12 Slashing. Heavy, Two-Handed."],
	"Greatsword": ["Weapon", 50, "A massive two-handed sword. 2d6 Slashing. Heavy, Two-Handed."],
	"Halberd":    ["Weapon", 20, "A polearm combining an axe and spear. 1d10 Slashing. Heavy, Reach, Two-Handed."],
	"Katana":     ["Weapon", 15, "A curved, single-edged blade. 1d8/1d10 Slashing. Versatile (1d10)."],
	"Lance":      ["Weapon", 10, "A long cavalry spear. 1d12 Piercing. Heavy, Reach, Two-Handed."],
	"Longsword":  ["Weapon", 15, "A classic military blade. 1d8/1d10 Slashing. Versatile (1d10)."],
	"Maul":       ["Weapon", 10, "A massive two-handed hammer. 2d6 Bludgeoning. Heavy, Two-Handed."],
	"Morningstar":["Weapon", 15, "A spiked mace. 1d8/1d10 Piercing. Versatile (1d10)."],
	"Pike":       ["Weapon", 5,  "A very long spear for formations. 1d10 Piercing. Heavy, Reach, Two-Handed."],
	"Rapier":     ["Weapon", 25, "A thin, elegant dueling blade. 1d8 Piercing. Finesse."],
	"Scimitar":   ["Weapon", 25, "A curved blade for quick slashes. 1d6 Slashing. Finesse, Light."],
	"Trident":    ["Weapon", 5,  "A three-pronged spear. 1d8/1d10 Piercing. Thrown (20/60), Versatile (1d10), Finesse."],
	"Warhammer":  ["Weapon", 15, "A heavy hammer for crushing armor. 1d8/1d10 Bludgeoning. Versatile (1d10)."],
	"War Pick":   ["Weapon", 5,  "A sharp, armor-piercing pick. 1d8/1d10 Piercing. Versatile (1d10)."],
	"Whip":       ["Weapon", 2,  "A long, flexible lash. 1d4 Slashing. Finesse, Reach."],
	# --- Martial Ranged Weapons ---
	"Blowgun":        ["Weapon", 10,  "A tube for firing small darts. 1d4 Piercing. Range (25/100)."],
	"Hand Crossbow":  ["Weapon", 75,  "A one-handed mechanical bow. 1d6 Piercing. Range (30/120), Light."],
	"Heavy Crossbow": ["Weapon", 50,  "A powerful mechanical bow. 1d10 Piercing. Range (100/400), Heavy, Two-Handed."],
	"Longbow":        ["Weapon", 50,  "A tall bow with exceptional range. 1d8 Piercing. Range (150/600), Heavy, Two-Handed."],
	"Heavy Sling":    ["Weapon", 10,  "A military-grade sling. 1d10 Bludgeoning. Range (100/400)."],
	"Musket":         ["Weapon", 500, "A black powder longarm. 1d12 Piercing. Range (40/120), Two-Handed."],
	"Pistol":         ["Weapon", 250, "A black powder handgun. 1d10 Piercing. Range (30/90)."],
	# --- Armor ---
	"Padded":          ["Armor", 5,    "Quilted layers of cloth. AC 11. Light."],
	"Leather":         ["Armor", 10,   "Tough, cured animal hide. AC 11. Light."],
	"Studded Leather": ["Armor", 45,   "Leather reinforced with metal studs. AC 12. Light."],
	"Hide":            ["Armor", 10,   "Rough, thick animal skins. AC 12. Medium."],
	"Chain Shirt":     ["Armor", 50,   "A shirt of interlocking metal rings. AC 13. Medium."],
	"Scale Mail":      ["Armor", 50,   "Metal scales on leather backing. AC 14. Medium."],
	"Breastplate":     ["Armor", 400,  "A fitted metal plate for the torso. AC 14. Medium."],
	"Half Plate":      ["Armor", 750,  "Plate armor covering most of the body. AC 15. Medium."],
	"Ring Mail":       ["Armor", 30,   "Leather with heavy rings sewn into it. AC 14. Heavy."],
	"Chain Mail":      ["Armor", 75,   "A full suit of interlocking metal rings. AC 16. Heavy."],
	"Splint":          ["Armor", 200,  "Metal strips on leather with chainmail joints. AC 17. Heavy."],
	"Plate":           ["Armor", 1500, "Complete suit of articulated metal plates. AC 18. Heavy."],
	"Standard Shield": ["Armor", 10,   "A reliable wooden or metal shield. +2 AC."],
	"Tower Shield":    ["Armor", 100,  "A massive shield covering the entire body. +3 AC."],
	# --- Mundane Gear (adventuring) ---
	"Backpack":            ["Misc", 2,    "A leather pack with straps, holds 30 lb."],
	"Barrel":              ["Misc", 2,    "A wooden barrel, holds 40 gallons of liquid."],
	"Basket":              ["Misc", 1,    "A wicker basket, holds 2 cubic feet or 40 lb."],
	"Chest":               ["Misc", 5,    "A sturdy wooden chest, holds 12 cubic feet or 300 lb."],
	"Flask":               ["Misc", 1,    "A glass or metal flask holding 1 pint of liquid."],
	"Jug":                 ["Misc", 1,    "A ceramic jug that holds 1 gallon of liquid."],
	"Pot, Iron":           ["Misc", 2,    "A large iron cooking pot."],
	"Pouch":               ["Misc", 1,    "A small leather pouch that holds 6 lb."],
	"Sack":                ["Misc", 1,    "A cloth sack that holds 30 lb or 1 cubic foot."],
	"Map or Scroll Case":  ["Misc", 1,    "A leather tube for storing maps or scrolls."],
	"Waterskin":           ["Misc", 1,    "A leather pouch that holds 4 pints of liquid."],
	"Candle":              ["Misc", 1,    "A tallow candle, dim light in 5-foot radius for 1 hour."],
	"Lamp":                ["Misc", 1,    "A clay lamp, bright light in 15-foot radius."],
	"Lantern, Bullseye":   ["Misc", 10,   "Casts bright light in a 60-foot cone."],
	"Lantern, Hooded":     ["Misc", 5,    "Sheds bright light in a 30-foot radius; hood reduces light."],
	"Oil Flask":           ["Misc", 1,    "A flask of lamp oil. Can ignite a 5-foot square."],
	"Tinderbox":           ["Misc", 1,    "Flint, fire steel, and tinder for starting fires."],
	"Torch":               ["Misc", 1,    "Bright light in 20-foot radius for 1 hour."],
	"Climber's Kit":       ["Misc", 25,   "Pitons, boot tips, gloves, and harness. Advantage on climbing."],
	"Crowbar":             ["Misc", 2,    "Grants advantage on Strength checks for forcing doors."],
	"Grappling Hook":      ["Misc", 2,    "An iron hook for scaling walls or anchoring lines."],
	"Hammer":              ["Misc", 1,    "A standard carpenter's hammer."],
	"Hammer, Sledge":      ["Misc", 2,    "A heavy two-handed hammer for breaking through walls."],
	"Ladder (10 ft)":      ["Misc", 1,    "A 10-foot wooden ladder."],
	"Piton":               ["Misc", 1,    "A metal spike hammered into rock or wood as an anchor."],
	"Pole (10 ft)":        ["Misc", 1,    "A 10-foot wooden pole for probing pits and traps."],
	"Rope, Hempen (50 ft)":["Misc", 1,    "50 feet of hemp rope. DC 17 Strength to burst."],
	"Rope, Silk (50 ft)":  ["Misc", 10,   "50 feet of strong, lightweight silk rope."],
	"Shovel":              ["Misc", 2,    "An iron-headed digging shovel."],
	"String (10 ft)":      ["Misc", 1,    "A 10-foot length of thin but strong string."],
	"Ball Bearings (bag)": ["Misc", 1,    "1000 steel ball bearings. DC 10 Dex save or fall prone."],
	"Block and Tackle":    ["Misc", 1,    "Pulleys and rope; lifts objects up to 4x normal capacity."],
	"Caltrops (bag)":      ["Misc", 1,    "20 iron caltrops. 1 piercing damage, speed halved."],
	"Chain (10 ft)":       ["Misc", 5,    "10 feet of heavy iron chain. 10 HP, AC 19."],
	"Fishing Tackle":      ["Misc", 1,    "Hooks, line, floats, and lures."],
	"Hourglass":           ["Misc", 25,   "A glass hourglass tracking up to 1 hour."],
	"Lock":                ["Misc", 10,   "An iron lock. Picking requires DC 15 thieves' tools."],
	"Magnifying Glass":    ["Misc", 100,  "Advantage on Perception checks involving fine detail."],
	"Manacles":            ["Misc", 2,    "Iron manacles. Breaking free requires DC 20 Strength."],
	"Mirror, Steel":       ["Misc", 5,    "A small polished steel hand mirror."],
	"Net":                 ["Misc", 1,    "A weighted net (10 ft diameter) that restrains creatures."],
	"Pick, Miner's":       ["Misc", 2,    "An iron pick for breaking up earth and rock."],
	"Spyglass":            ["Misc", 100,  "A brass telescope. Objects viewed magnified 2x."],
	"Whetstone":           ["Misc", 1,    "A small stone for sharpening bladed weapons."],
	"Rations (1 day)":     ["Misc", 1,    "Hard biscuits, dried fruit, and jerked meat for one day."],
	"Book":                ["Misc", 25,   "A bound book with 100 pages."],
	"Bottle, Glass":       ["Misc", 2,    "A glass bottle with a stopper, holds 1.5 pints."],
	"Chalk (1 piece)":     ["Misc", 1,    "A piece of white chalk for marking surfaces."],
	"Ink (1 oz)":          ["Misc", 10,   "A small bottle of black writing ink."],
	"Ink Pen":             ["Misc", 1,    "A feather quill or reed pen for writing."],
	"Paper (sheet)":       ["Misc", 1,    "A single sheet of fine writing paper."],
	"Parchment (sheet)":   ["Misc", 1,    "A sheet of treated animal skin for writing."],
	"Sealing Wax":         ["Misc", 1,    "A stick of wax for sealing letters."],
	"Signet Ring":         ["Misc", 5,    "A ring bearing a personal seal for marking wax."],
	"Bedroll":             ["Misc", 1,    "A roll of blankets and padding for sleeping outdoors."],
	"Blanket":             ["Misc", 1,    "A wool blanket providing warmth while resting."],
	"Clothes, Common":     ["Misc", 1,    "Simple, sturdy everyday clothing."],
	"Clothes, Costume":    ["Misc", 5,    "An elaborate costume outfit for performances or disguises."],
	"Clothes, Fine":       ["Misc", 15,   "Elegant garments fit for nobles and formal occasions."],
	"Clothes, Traveler's": ["Misc", 2,    "Durable, comfortable clothes for long journeys."],
	"Perfume (vial)":      ["Misc", 5,    "A small vial of pleasant-smelling fragrance."],
	"Signal Whistle":      ["Misc", 1,    "A small metal whistle audible up to 600 feet away."],
	"Soap":                ["Misc", 1,    "A bar of lye soap."],
	"Component Pouch":     ["Misc", 25,   "A leather pouch for storing spell components."],
	"Holy Symbol":         ["Misc", 5,    "An emblem of a deity — amulet, reliquary, or embossed shield."],
	"Holy Water (flask)":  ["Misc", 25,   "Blessed water. Deals 2d6 radiant damage to undead."],
	"Hunting Trap":        ["Misc", 5,    "A serrated trap. DC 13 Str to escape."],
	"Poison, Basic (vial)":["Misc", 100,  "Contact poison. Coated weapon deals extra 1d4 poison."],
	"Spellbook":           ["Misc", 50,   "A leather-bound book with 100 pages for recording spells."],
	"Vial":                ["Misc", 1,    "A small glass vial holding up to 4 ounces."],
	"Alchemist's Fire (flask)":["Misc", 50, "Sticky incendiary. Burns for 1d4 fire per turn."],
	"Acid (vial)":         ["Misc", 25,   "Corrosive acid. Deals 2d6 acid damage on hit."],
	"Healer's Kit":        ["Misc", 5,    "Bandages and herbs. Stabilizes at 0 HP (10 uses)."],
	"Disguise Kit":        ["Misc", 25,   "Cosmetics and props for creating disguises."],
	"Abacus":              ["Misc", 2,    "A wooden counting frame used for calculations."],
}

# ── Magic Item Effects Registry ──────────────────────────────────────────────
# Each magic item grants passive bonuses while in inventory.
# Keys: ac, hp_bonus, sp_bonus, ap_bonus, hit_bonus, dmg_bonus, heal_bonus,
#        stealth_bonus, perception_bonus, fire_resist, cold_resist, poison_resist,
#        skill_bonus (flat to all skill checks), rest_heal, auto_hit_below_5,
#        fall_slow, detect_magic, detect_poison, scent_mask, light_radius
const _MAGIC_ITEM_EFFECTS: Dictionary = {
	"Amberglow Pendant":       {"light_radius": 10, "hp_bonus": 2},
	"Amulet of Comfort +1":   {"cold_resist": 1, "fire_resist": 1},
	"Aether-Touched Lens":     {"detect_magic": true, "perception_bonus": 1},
	"Anvilstone":              {"dmg_bonus": 1},
	"Arcane Stitching Kit":    {"rest_heal": 2},
	"Ashcloak Thread":         {"fire_resist": 2},
	"Babelstone Charm":        {"skill_bonus": 1},
	"Binding Nail":            {"ac": 1},
	"Candle of Clarity":       {"sp_bonus": 2, "perception_bonus": 1},
	"Candle of Echoes":        {"perception_bonus": 2},
	"Cleansing Stone":         {"poison_resist": 1},
	"Cradleleaf Poultice":     {"rest_heal": 4},
	"Dagger of the Last Word": {"auto_hit_below_5": true, "hit_bonus": 1},
	"Dowsing Rod":             {"perception_bonus": 2},
	"Dustveil Cloak":          {"stealth_bonus": 2},
	"Echoing Rift Stone":      {"perception_bonus": 1},
	"Flickerflame Matchbox":   {"light_radius": 5},
	"Forager's Pouch":         {"rest_heal": 3},
	"Glass of Truth":          {"detect_poison": true, "perception_bonus": 1},
	"Glass of Revelation":     {"detect_magic": true},
	"Glowroot Bandage":        {"heal_bonus": 2, "light_radius": 5},
	"Mender's Thread":         {"rest_heal": 1},
	"Messenger Feather":       {"skill_bonus": 1},
	"Mothwing Brooch":         {"fall_slow": true, "ac": 1},
	"Needle of Silence":       {"stealth_bonus": 3},
	"Pebble of Echoes":        {"perception_bonus": 1},
	"Scribe's Quill":          {"sp_bonus": 1},
	"Shadow Sovereign's Coin": {"skill_bonus": 2},
	"Scent Masker":            {"stealth_bonus": 2, "scent_mask": true},
	"Silent Bell":             {"stealth_bonus": 1, "perception_bonus": 1},
	"Smoke Puff":              {"stealth_bonus": 1},
	"Traveler's Chalice":      {"poison_resist": 2, "rest_heal": 1},
}

## Sum all passive bonuses from ATTUNED magic items in a character's inventory.
func _magic_item_bonus(handle: int, stat_key: String) -> int:
	if not _chars.has(handle): return 0
	var attuned: Array = _chars[handle].get("attuned", [])
	var total: int = 0
	for item_name in attuned:
		if _MAGIC_ITEM_EFFECTS.has(item_name):
			total += int(_MAGIC_ITEM_EFFECTS[item_name].get(stat_key, 0))
	return total

## Check if character has an ATTUNED magic item with a boolean flag.
func _magic_item_has_flag(handle: int, flag: String) -> bool:
	if not _chars.has(handle): return false
	var attuned: Array = _chars[handle].get("attuned", [])
	for item_name in attuned:
		if _MAGIC_ITEM_EFFECTS.has(item_name):
			if bool(_MAGIC_ITEM_EFFECTS[item_name].get(flag, false)):
				return true
	return false

## Attunement cost by rarity (PHB: Common 1, Uncommon 2, Rare 3, Very Rare 4, Legendary 5).
## The cost permanently reduces max SP while attuned.
func _attunement_cost_for_item(item_name: String) -> int:
	var details: PackedStringArray = get_registry_item_details(item_name)
	if details.size() < 1: return 0
	var rarity: String = str(details[0])
	match rarity:
		"Common":    return 1
		"Uncommon":  return 2
		"Rare":      return 3
		"Very Rare": return 4
		"Legendary": return 5
		"Apex":      return 5
	return 0

## Returns true if a character is attuned to a specific item.
func is_attuned(handle: int, item_name: String) -> bool:
	if not _chars.has(handle): return false
	return item_name in _chars[handle].get("attuned", [])

## Total SP committed to attunement for a character.
func get_attunement_sp_committed(handle: int) -> int:
	if not _chars.has(handle): return 0
	var total: int = 0
	for item_name in _chars[handle].get("attuned", []):
		total += _attunement_cost_for_item(item_name)
	return total

## Attune a magic item. Returns "" on success or an error message string.
func attune_item(handle: int, item_name: String) -> String:
	if not _chars.has(handle): return "Character not found."
	var c = _chars[handle]
	if item_name not in c.get("items", []):
		return "Item not in inventory."
	if item_name in c.get("attuned", []):
		return "Already attuned."
	if not _MAGIC_ITEM_EFFECTS.has(item_name):
		return "This item has no magical properties to attune."
	var cost: int = _attunement_cost_for_item(item_name)
	if cost <= 0:
		return "This item cannot be attuned."
	# PHB: attunement reduces max SP — check the character can afford it.
	# current max_sp already has existing attunement costs subtracted, so we just
	# check if the remaining SP can cover this new item's cost.
	var current_max_sp: int = int(c.get("max_sp", 0))
	if cost > current_max_sp:
		return "Not enough max SP. Need %d, but only %d available." % [cost, current_max_sp]
	c["attuned"].append(item_name)
	recalculate_derived_stats(handle)
	return ""

## End attunement to a magic item. Restores max SP.
func unattune_item(handle: int, item_name: String) -> String:
	if not _chars.has(handle): return "Character not found."
	var c = _chars[handle]
	if item_name not in c.get("attuned", []):
		return "Not attuned to this item."
	c["attuned"].erase(item_name)
	recalculate_derived_stats(handle)
	return ""

## Unattune ALL items for a character (used on death or full reset).
func unattune_all(handle: int) -> void:
	if not _chars.has(handle): return
	_chars[handle]["attuned"] = []
	recalculate_derived_stats(handle)

# ── Lifespan & Life Sacrifice ────────────────────────────────────────────────

## PHB life sacrifice table: trade months/years of life for SP.
## tier 0: 1d4 months → 1d4 SP | tier 1: 2d4 months → 2d4 SP
## tier 2: 1d4 years → 1d4×12 SP (converted to months internally)
## Returns a dict: {"sp_gained": int, "months_lost": int, "vit_failed": bool, "msg": String}
func sacrifice_life_for_sp(handle: int, tier: int = 0) -> Dictionary:
	if not _chars.has(handle):
		return {"sp_gained": 0, "months_lost": 0, "vit_failed": false, "msg": "Character not found."}
	var c = _chars[handle]
	var vit_v: int = int(c.get("stats", [0,0,0,0,0])[3]) if c.get("stats", []).size() > 3 else 0

	# Roll sacrifice amount
	var months: int = 0
	var sp_gain: int = 0
	match tier:
		0:  # 1d4 months → 1d4 SP
			months = randi_range(1, 4)
			sp_gain = randi_range(1, 4)
		1:  # 2d4 months → 2d4 SP
			months = randi_range(1, 4) + randi_range(1, 4)
			sp_gain = randi_range(1, 4) + randi_range(1, 4)
		2:  # 1d4 years → 1d4*12 SP
			var years_roll: int = randi_range(1, 4)
			months = years_roll * 12
			sp_gain = years_roll * 12

	# VIT check: DC starts at 10, +2 per sacrifice since last long rest
	var dc: int = int(c.get("sacrifice_dc", 10))
	var vit_roll: int = randi_range(1, 20) + vit_v
	var vit_failed: bool = vit_roll < dc

	# Apply sacrifice
	c["months_sacrificed"] = int(c.get("months_sacrificed", 0)) + months
	c["sacrifice_dc"] = dc + 2  # escalating DC

	# Psychic damage: 1 per month sacrificed, minimum 1 HP remaining
	var psychic_dmg: int = months
	c["hp"] = maxi(1, int(c["hp"]) - psychic_dmg)

	# Restore SP (capped at max)
	c["sp"] = mini(int(c["max_sp"]), int(c["sp"]) + sp_gain)

	var msg: String = "Sacrificed %d months of life for %d SP." % [months, sp_gain]

	if vit_failed:
		# Failed VIT check: +1 exhaustion and +1 insanity
		c["insanity"] = int(c.get("insanity", 0)) + 1
		# Add exhaustion as an injury
		var injuries: Array = c.get("injuries", [])
		injuries.append("Exhaustion (life sacrifice)")
		c["injuries"] = injuries
		msg += " VIT check failed — gained 1 insanity and 1 exhaustion."

	# Recalculate stats since effective age changed (HP penalty may apply)
	recalculate_derived_stats(handle)
	return {"sp_gained": sp_gain, "months_lost": months, "vit_failed": vit_failed, "msg": msg}

## Reset sacrifice DC back to 10 (called on long rest).
func reset_sacrifice_dc(handle: int) -> void:
	if _chars.has(handle):
		_chars[handle]["sacrifice_dc"] = 10

## Elf life extension: permanently bind SP to add 10 years to max_age per SP.
## Returns "" on success or an error string.
func bind_sp_for_life_extension(handle: int, sp_amount: int) -> String:
	if not _chars.has(handle): return "Character not found."
	var c = _chars[handle]
	if str(c.get("lineage", "")) != "Elf":
		return "Only Elves can perform the life extension ritual."
	if sp_amount <= 0:
		return "Must bind at least 1 SP."
	# Check if character's max SP (after all reductions) can absorb this
	var current_max: int = int(c.get("max_sp", 0))
	if sp_amount > current_max:
		return "Not enough max SP. Need %d, only %d available." % [sp_amount, current_max]
	c["life_bound_sp"] = int(c.get("life_bound_sp", 0)) + sp_amount
	recalculate_derived_stats(handle)
	return ""

## Compute insanity from old age: +1 per 100 years past age 100.
## Call this when time advances to check if permanent insanity should increase.
func update_age_insanity(handle: int) -> void:
	if not _chars.has(handle): return
	var eff_age: int = get_character_age(handle)
	if eff_age <= 100: return
	var age_insanity: int = (eff_age - 100) / 100  # +1 per century past 100
	var c = _chars[handle]
	var current: int = int(c.get("insanity", 0))
	if age_insanity > current:
		c["insanity"] = age_insanity

## Check if a character has died of old age.
func check_natural_death(handle: int) -> bool:
	if not _chars.has(handle): return false
	return get_character_age(handle) >= get_character_max_age(handle)

static var _MAGIC_ITEM_NAMES: PackedStringArray = PackedStringArray([
	"Amberglow Pendant", "Amulet of Comfort +1", "Aether-Touched Lens", "Anvilstone",
	"Arcane Stitching Kit", "Ashcloak Thread", "Babelstone Charm", "Binding Nail",
	"Candle of Clarity", "Candle of Echoes", "Cleansing Stone", "Cradleleaf Poultice",
	"Dagger of the Last Word", "Dowsing Rod", "Dustveil Cloak", "Echoing Rift Stone",
	"Flickerflame Matchbox", "Forager's Pouch", "Glass of Truth", "Glass of Revelation",
	"Glowroot Bandage", "Mender's Thread", "Messenger Feather", "Mothwing Brooch",
	"Needle of Silence", "Pebble of Echoes", "Scribe's Quill", "Shadow Sovereign's Coin",
	"Scent Masker", "Silent Bell", "Smoke Puff", "Traveler's Chalice"
])

static var _MUNDANE_ITEM_NAMES: PackedStringArray = PackedStringArray([
	# Weapons (simple melee)
	"Chakram", "Club", "Dagger", "Greatclub", "Handaxe", "Javelin", "Light Hammer",
	"Mace", "Quarterstaff", "Sickle", "Spear", "Shortsword",
	# Weapons (simple ranged)
	"Dart", "Light Crossbow", "Shortbow", "Sling",
	# Weapons (martial melee)
	"Battleaxe", "Flail", "Glaive", "Greataxe", "Greatsword", "Halberd", "Katana",
	"Lance", "Longsword", "Maul", "Morningstar", "Pike", "Rapier", "Scimitar",
	"Trident", "Warhammer", "War Pick", "Whip",
	# Weapons (martial ranged)
	"Blowgun", "Hand Crossbow", "Heavy Crossbow", "Longbow", "Heavy Sling", "Musket", "Pistol",
	# Armor
	"Padded", "Leather", "Studded Leather", "Hide", "Chain Shirt", "Scale Mail",
	"Breastplate", "Half Plate", "Ring Mail", "Chain Mail", "Splint", "Plate",
	"Standard Shield", "Tower Shield",
	# Consumables
	"Potion of Healing", "Lesser Potion of Healing", "Potion of Revive",
	"Ether Flask", "Adrenaline Shot", "Ironroot Draught",
	# Misc gear (selection most relevant to adventuring)
	"Backpack", "Rope, Hempen (50 ft)", "Rope, Silk (50 ft)", "Torch", "Lantern, Hooded",
	"Tinderbox", "Healer's Kit", "Climber's Kit", "Grappling Hook", "Crowbar",
	"Fishing Tackle", "Hunting Trap", "Holy Water (flask)", "Alchemist's Fire (flask)",
	"Acid (vial)", "Poison, Basic (vial)", "Spyglass", "Magnifying Glass", "Spellbook",
	"Component Pouch", "Disguise Kit", "Waterskin", "Rations (1 day)"
])

func get_registry_item_details(item_name: String) -> PackedStringArray:
	return _format_item_details(item_name)

func get_all_registry_weapons() -> PackedStringArray:
	var out: Array = []
	for k in _ITEM_REGISTRY:
		if _ITEM_REGISTRY[k][0] == "Weapon":
			out.append(k)
	return PackedStringArray(out)

func get_all_registry_armor() -> PackedStringArray:
	var out: Array = []
	for k in _ITEM_REGISTRY:
		if _ITEM_REGISTRY[k][0] == "Armor":
			out.append(k)
	return PackedStringArray(out)

func get_all_registry_general_items() -> PackedStringArray:
	var out: Array = []
	for k in _ITEM_REGISTRY:
		var t = _ITEM_REGISTRY[k][0]
		if t == "Misc" or t == "Consumable":
			out.append(k)
	return PackedStringArray(out)

func get_all_registry_magic_items() -> PackedStringArray:
	return _MAGIC_ITEM_NAMES

func get_all_registry_mundane_items() -> PackedStringArray:
	return _MUNDANE_ITEM_NAMES

# ── Societal roles (stubs) ────────────────────────────────────────────────────
func get_all_societal_roles() -> PackedStringArray:
	_ensure_societal_roles()
	var names: Array = []
	for r in _SOCIETAL_ROLES:
		names.append(r[0])
	return PackedStringArray(names)

func get_societal_role_details(name: String) -> PackedStringArray:
	_ensure_societal_roles()
	for r in _SOCIETAL_ROLES:
		if r[0] == name:
			return PackedStringArray([r[1], r[2], r[3]])
	return PackedStringArray()

func add_societal_role(handle: int, name: String) -> void:
	set_societal_role(handle, name)

func set_societal_role(handle: int, name: String) -> void:
	if _chars.has(handle): _chars[handle]["societal_role"] = name

# ── Societal Role Registry ────────────────────────────────────────────────────
## Each entry: [name, primary_benefit, secondary_benefit, description]
static var _SOCIETAL_ROLES: Array = []

func _ensure_societal_roles() -> void:
	if not _SOCIETAL_ROLES.is_empty():
		return
	_SOCIETAL_ROLES = [
		["Archivist", "+1d4 to Arcane and History checks.", "Once/LR recall obscure magical lore without a check.", "Keepers of ancient knowledge."],
		["Artificer", "+1d4 to Crafting and Tinkering checks.", "Repair a damaged item once per short rest.", "Engineers of arcane technology."],
		["Ashkeeper", "+1d4 to Fire Magic and Religion checks.", "Once/LR walk through fire without damage for 1 minute.", "Firewalkers and flame-priests."],
		["Baker", "+1d4 to Baking and Chemistry checks.", "Once/SR bake goods that restore 1d4+Intellect HP to an ally.", "Nourishing both body and spirit."],
		["Beastmaster", "+1d4 to Creature Handling and Survival checks.", "Once/LR calm and command a beast for 1 minute.", "Taming the wild."],
		["Blightmender", "+1d4 to Medicine and Corruption checks.", "Once/LR cleanse a creature of a minor disease or ailment.", "Healers of corruption."],
		["Bloodscribe", "+1d4 to Ritual and Divinity checks.", "Blood rite: regain HP equal to half spell damage dealt for 1 minute (1/LR).", "Ritualists of blood magic."],
		["Bloodstitcher", "+1d4 to Medicine and Vitality checks.", "Stop a fatal wound from causing death for 1 hour (1/LR).", "Menders of deep injuries."],
		["Bonepicker", "+1d4 to Scavenging and Medical checks.", "Harvest a useful component from a corpse (1/LR).", "Scavengers of battlefields."],
		["Brewer", "+1d4 to Brewing and Chemistry checks.", "Craft a drink that removes one minor condition (1/LR).", "Creators of comfort."],
		["Butcher", "+1d4 to Butchery and Anatomy checks.", "Cooking yields double normal food amount (1/LR).", "Processors of meat."],
		["Cartwright", "+1d4 to Crafting and Repair checks for vehicles.", "Repair a damaged vehicle (1/LR).", "Builders of vehicles."],
		["Cavemistress", "+1d4 to Stealth and Survival checks underground.", "Summon a danger-0 companion from the Shadows Beneath (1/LR).", "Rulers of the underground."],
		["Cavernborn", "+1d4 to Mining and Stealth checks underground.", "Ignore darkness penalties for 1 hour (1/LR).", "Adapted to darkness and stone."],
		["Chronicler", "+1d4 to History and Speechcraft checks.", "Recall a forgotten or obscure piece of relevant lore (1/LR).", "Recorders of deeds."],
		["Contract Arbiter", "+1d4 to Persuasion and Intimidation as a neutral party.", "Create a magical oath binding two willing creatures for 24 hours (1/LR).", "Resolvers of disputes."],
		["Cook", "+1d4 to Cooking and Survival checks involving food.", "Prepare a meal granting allies bonus HP equal to your level (1/LR).", "Preparers of meals."],
		["Court Mage", "+1d4 to Arcane and Speechcraft in formal settings.", "Cast a minor spell (\u22644 SP) without SP cost (1/LR).", "Arcane advisors to nobility."],
		["Cryptkeeper", "+1d4 to Religion and Undead Lore checks.", "Turn away a minor undead creature for 1 minute (1/LR).", "Caretakers of tombs."],
		["Diplomat", "+1d4 to Speechcraft and Insight in social encounters.", "Calm hostile creatures within 30 ft for 1 round (1/LR).", "Negotiators and peacekeepers."],
		["Engineer", "+1d4 to Tinkering and Structural Analysis checks.", "Reinforce a structure or disable a trap with advantage (1/SR).", "Builders of infrastructure."],
		["Feybound", "+1d4 to Deception and Nature checks.", "Cast a minor illusion or charm (\u22644 SP) for 0 SP (1/LR).", "Pact-makers with the fey."],
		["Firebrand", "+1d4 to Intimidation and Chaos-aligned spellcasting.", "Cause a fire-based distraction/explosion for group advantage (1/SR).", "Rebels and chaos-sowers."],
		["Fisher", "+1d4 to Fishing and Water Navigation checks.", "Automatically succeed on a minor fishing check (1/SR).", "Providers from the waters."],
		["Fleshshaper", "+1d4 to Biological Magic and Medical checks.", "Regrow a lost limb or organ over 1 hour (1/LR).", "Biomancers of tissue."],
		["Forgehand", "+1d4 to Smithing and Crafting checks.", "Reinforce gear for +2 dmg/AC for 1 hr and repair half HP (1/LR).", "Metalworkers and smiths."],
		["Fungal Tender", "+1d4 to Nature and Medical checks involving fungi.", "Create a spore cloud for advantage on sneak checks for 1 round (1/SR).", "Caretakers of mycelial groves."],
		["Gardener", "+1d4 to Botany and Nature checks.", "Revive wilted plants or accelerate growth in 5 ft cube (1/LR).", "Cultivators of plants."],
		["Gladiator", "+1d4 to Performance and Melee Attacks in front of an audience.", "Cause daze for 2 rounds, DC 10+Vitality (1/SR).", "Champions of the arena."],
		["Glimmerchant", "+1d4 to Appraisal and Speechcraft checks.", "Identify a magical item's function/curse without a check (1/LR).", "Traders of magical curiosities."],
		["Gravetender", "+1d4 to Religion and Medical checks involving the dead.", "Speak with a spirit or ghost of a corpse for 1 minute (1/LR).", "Caretakers of the dead."],
		["Grimscribe", "+1d4 to History and Necromancy checks.", "Identify a curse or necromantic effect (1/LR).", "Chroniclers of death."],
		["Gutterborn", "+1d4 to Sneak and Streetwise checks.", "Escape a grapple or restraint automatically (1/LR).", "Resourceful city-dwellers."],
		["Guildmaster", "+1d4 to Commerce and Appraisal checks.", "Secure a 20% trade discount or rare market info (1/LR).", "Influential traders."],
		["Healer", "+1d4 to Medical and Vitality checks.", "Stabilize a dying creature as a Free Action (1/LR).", "Tenders of the sick."],
		["Hearthwarden", "+1d4 to Defense and Perception checks around dwellings.", "Set a trap or alarm that alerts you to intruders (1/LR).", "Protectors of homes."],
		["Hollowblade", "+1d4 to Melee attacks and spell saves.", "Nullify a spell targeting you (1/LR).", "Warriors of the void."],
		["Hollowveil Courier", "+1d4 to Stealth and Endurance checks.", "Move at double speed for 1 round without provoking (1/SR).", "Silent runners."],
		["Horizon Seeker", "+1d4 to Navigation and Cartography checks.", "Find a shortcut or hidden path (1/LR).", "Explorers of the unknown."],
		["Inquisitor", "+1d4 to Insight and Investigation checks.", "Detect lies or illusions with advantage (1/SR).", "Seekers of truth."],
		["Ironmonger", "+1d4 to Smithing and Appraisal checks.", "Repair a metal item without tools or restore half HP (1/LR).", "Metal tool forgers."],
		["Ironshaper", "+1d4 to Crafting and Strength checks working with metal.", "Create a temporary weapon or armor lasting one day (1/LR).", "Artistic metal forgers."],
		["Leyrunner", "+1d4 to Arcane and Navigation checks.", "Teleport up to 30 ft as a Free Action (1/LR).", "Arcane messengers."],
		["Lorekeeper", "+1d4 to History and Arcane checks.", "Identify a magical item's function without a check (1/LR).", "Historians of the past."],
		["Mason", "+1d4 to Masonry and Engineering checks.", "Reinforce or weaken a stone structure for 1 hour (1/LR).", "Builders of stone."],
		["Mercenary", "+1d4 to Weapon Attack rolls when outnumbered.", "Identify military tactics or formations with advantage.", "Hired battle veterans."],
		["Miner", "+1d4 to Mining and Geology checks.", "Identify a mineral or safely extract resources (1/LR).", "Extractors of resources."],
		["Mistwarden", "+1d4 to Stealth and Perception in fog or dim light.", "Create a zone of muffled sound and mist for 1 minute (1/LR).", "Protectors of foggy coasts."],
		["Relic Hunter", "+1d4 to Investigation and Trap Detection checks.", "Identify magical properties without a check (1/LR).", "Seekers of lost artifacts."],
		["Riverrunner", "+1d4 to Swimming and Boating checks.", "Automatically succeed on a check to cross hazardous water (1/LR).", "Expert boatmen."],
		["Runebinder", "+1d4 to Spellcasting checks.", "Delay a spell's activation by 1 round as a reaction (1/LR).", "Arcane tacticians."],
		["Runebreaker", "+1d4 to Arcane and Cunning checks involving magical traps.", "Nullify a magical effect instantly for 1 round (1/LR).", "Disrupters of magic."],
		["Runescribe", "+1d4 to Arcane and Calligraphy-related checks.", "Inscribe a temporary rune for +1 to a saving throw (1/SR).", "Inscribers of power."],
		["Runeseeker", "+1d4 to Arcane and Survival in magical areas.", "Detect a magical anomaly and reduce next spell cost by 2 SP (1/LR).", "Followers of divine echoes."],
		["Saboteur", "+1d4 to Cunning and Trap Disarming checks.", "Disable a mechanical or magical device instantly (1/LR).", "Experts in disruption."],
		["Scout", "+1d4 to Perception and Stealth checks.", "Move at full speed while sneaking without penalty.", "Light-footed observers."],
		["Scrapwright", "+1d4 to Tinkering and Improvised Crafting checks.", "Create a one-use gadget (1/LR).", "Salvagers of junk."],
		["Seedkeeper", "+1d4 to Nature and Medicine checks involving plants.", "Revive or accelerate growth of a plant overnight (1/LR).", "Cultivators of rare plants."],
		["Seer", "+1d4 to Divination and Insight checks.", "Ask a yes/no question and receive a cryptic answer (1/LR).", "Visionaries of fate."],
		["Shadowbroker", "+1d4 to Cunning and Speechcraft checks involving secrets.", "Gather local rumors in half the usual time.", "Dealers in secrets."],
		["Shadowdancer", "+1d4 to Stealth and Nimble checks in dim light.", "Become invisible for 1 minute in shadows (1/LR).", "Manipulators of light and dark."],
		["Skyforged", "+1d4 to Engineering and Arcane checks involving flight.", "Negate fall damage from any height (1/LR).", "Engineers of floating cities."],
		["Skywatcher", "+1d4 to Weather Prediction and Navigation checks.", "Glide 30 ft once without taking fall damage (1/LR).", "Weather sages."],
		["Smuggler", "+1d4 to Stealth and Deception checks.", "Hide a small object on your person without a check.", "Masters of misdirection."],
		["Soulbinder", "+1d4 to Divinity and Insight checks.", "Spectral sigil: advantage on Insight/Divinity vs target (1/LR).", "Pact-makers with spirits."],
		["Speaker", "+1d4 to Speechcraft and History checks.", "Inspire allies to reroll a failed saving throw (1/SR).", "Community leaders."],
		["Spellslinger", "+1d4 to Spell Attack rolls.", "Reroll a failed spell attack (1/SR).", "Battle-trained mages."],
		["Spellwright", "+1d4 to Arcane and Calligraphy checks.", "Reduce the SP cost of a spell by 1 (1/SR).", "Arcane scribes."],
		["Stablehand", "+1d4 to Animal Care and Cleaning checks.", "Calm a frightened mount or beast of burden (1/LR).", "Caretakers of mounts."],
		["Starborn Envoy", "+1d4 to Speechcraft and Arcane checks with extraplanar beings.", "Cast a minor light or telepathy spell for 0 SP (1/LR).", "Planar diplomats."],
		["Starweaver", "+1d4 to Arcane and Navigation checks under open sky.", "Reroll a failed Arcane check (1/LR).", "Cosmic mages."],
		["Stonehand", "+1d4 to Athletics and Endurance checks.", "Complete strenuous task in half time or ignore fatigue for 1 hour (1/LR).", "Physical laborers."],
		["Stormrunner", "+1d4 to Speed and Navigation checks.", "Ignore terrain penalties for 1 hour (1/LR).", "Couriers of the wilds."],
		["Stormsinger", "+1d4 to Conjuring and Thunder-related checks.", "Create a lightning storm in a 20 ft radius for 1 minute (1/LR).", "Callers of the storm."],
		["Street Performer", "+1d4 to Performance and Crowd Control checks.", "Attract a distracting or aiding crowd (1/LR).", "Artistic entertainers."],
		["Sunforged", "+1d4 to Fire Resistance and Smithing checks.", "Emit bright light in a 20 ft radius for 1 minute (1/LR).", "Warriors of solar rites."],
		["Tailor", "+1d4 to Crafting and Appraisal checks for clothing.", "Altered clothing grants ally advantage on one social check (1/LR).", "Menders of clothing."],
		["Tavernkeeper", "+1d4 to Speechcraft and Insight checks.", "Grant an ally advantage on a social check (1/LR).", "Masters of hospitality."],
		["Technician", "+1d4 to Tinkering and Engineering checks.", "Instantly repair or disable a device without a check (1/SR).", "Masters of arcane circuitry."],
		["Tidebound Navigator", "+1d4 to Navigation and Weather Prediction checks.", "Reroll a failed Navigation check (1/LR).", "Seafarers."],
		["Tideforged", "+1d4 to Crafting and Survival near water.", "Craft a simple tool or weapon from found materials (1/LR).", "Laborers of the sea."],
		["Tidewalker", "+1d4 to Swim and Navigation checks.", "Hold breath twice as long and ignore underwater difficult terrain.", "Guides of the isles."],
		["Veilforged", "+1d4 to Arcane and spell save checks against illusions.", "Pulse of void energy to suppress magical effects (1/LR).", "Resilient shadow-shapers."],
		["Veilweaver", "+1d4 to Arcane and Stealth checks involving the ethereal.", "Pass through solid walls up to 10 ft thick (3/LR).", "Walkers between worlds."],
		["Voidwatcher", "+1d4 to Insight and Arcane checks involving planar phenomena.", "See into the Ethereal Plane for 1 minute (1/LR).", "Planar scouts."],
		["Wanderer", "+1d4 to Survival and Navigation in unfamiliar terrain.", "Always find food and water for yourself and one other.", "Nomads of the wilds."],
		["Wandering Duelist", "+1d4 to Weapon Attacks in duels and nimble checks.", "Anticipate move: advantage on attacks for a round (1/LR).", "Mercenary drifters."],
		["Warden", "+1d4 to Survival and Tracking in natural environments.", "Detect nearby threats within 60 ft (1/LR).", "Guardians of the wilds."],
		["Windswept", "+1d4 to Survival and Initiative checks.", "Take a move action without spending AP (1/SR).", "Nomads of the highlands."],
		["Witchbinder", "+1d4 to Arcane and Intellect checks for forbidden magic.", "Bind an enemy's spell, rendering it useless for 1 minute (1/LR).", "Tethered to forbidden magic."],
		["Witchfinder", "+1d4 to Arcane and Divinity checks identifying curses.", "Sense the presence of magic within 30 ft for 1 minute (1/LR).", "Hunters of rogue mages."],
	]

# ── Societal-role → skill tags (overhaul Fix) ─────────────────────────────────
## Maps each role to its PRIMARY two skills (indices into Rimvale skill table:
## 0=Arcane, 1=Crafting, 2=CreatureHandling, 3=Cunning, 4=Exertion,
## 5=Intuition, 6=Learnedness, 7=Medical, 8=Nimble, 9=Perception,
## 10=Perform, 11=Sneak, 12=Speechcraft, 13=Survival).
## Rimvale has no dedicated "Religion" skill — ritual/priest roles map their
## divine insight to Intuition (5). Character rolls on these two skills get
## +1d4 while the role is active.
static var _ROLE_SKILLS: Dictionary = {}

func _ensure_role_skills() -> void:
	if not _ROLE_SKILLS.is_empty(): return
	_ROLE_SKILLS = {
		"Archivist":          [0, 6],   # Arcane + Learnedness
		"Artificer":          [1, 6],   # Crafting + Learnedness
		"Ashkeeper":          [0, 5],   # Arcane + Intuition (ritual insight)
		"Baker":              [1, 1],
		"Beastmaster":        [2, 13],
		"Blightmender":       [7, 1],
		"Bloodscribe":        [1, 0],   # Crafting + Arcane (blood-magic scribe)
		"Bloodstitcher":      [7, 5],
		"Bonepicker":         [9, 7],
		"Brewer":             [1, 1],
		"Butcher":            [1, 4],
		"Cartwright":         [1, 1],
		"Cavemistress":       [3, 13],
		"Cavernborn":         [4, 13],
		"Chronicler":         [6, 12],
		"Contract Arbiter":   [12, 5],
		"Cook":               [1, 13],
		"Court Mage":         [0, 12],
		"Cryptkeeper":        [5, 6],   # Intuition + Learnedness
		"Diplomat":           [12, 5],
		"Engineer":           [1, 6],
		"Feybound":           [3, 13],
		"Firebrand":          [12, 0],
		"Fisher":             [13, 8],
		"Fleshshaper":        [0, 7],
		"Forgehand":          [1, 4],
		"Fungal Tender":      [13, 7],
		"Gardener":           [13, 5],
		"Gladiator":          [10, 4],
		"Glimmerchant":       [3, 12],
		"Gravetender":        [5, 7],   # Intuition + Medical
		"Grimscribe":         [6, 0],
		"Gutterborn":         [8, 3],
		"Guildmaster":        [12, 3],
		"Healer":             [7, 5],
		"Hearthwarden":       [9, 13],
		"Hollowblade":        [4, 0],
		"Hollowveil Courier": [8, 4],
		"Horizon Seeker":     [13, 9],
		"Inquisitor":         [5, 9],
		"Ironmonger":         [1, 3],
		"Ironshaper":         [1, 4],
		"Leyrunner":          [0, 13],
		"Lorekeeper":         [6, 0],
		"Mason":              [1, 1],
		"Mercenary":          [4, 9],
		"Miner":              [4, 9],
		"Mistwarden":         [8, 9],
		"Relic Hunter":       [3, 9],
		"Riverrunner":        [8, 13],
		"Runebinder":         [0, 6],
		"Runebreaker":        [0, 3],
		"Runescribe":         [0, 1],
		"Runeseeker":         [0, 13],
		"Saboteur":           [3, 1],
		"Scout":              [8, 9],
		"Scrapwright":        [1, 3],
		"Seedkeeper":         [13, 7],
		"Seer":               [5, 9],   # Intuition + Perception
		"Shadowbroker":       [3, 12],
		"Shadowdancer":       [8, 10],
		"Skyforged":          [1, 0],
		"Skywatcher":         [9, 13],
		"Smuggler":           [8, 3],
		"Soulbinder":         [0, 5],   # Arcane + Intuition
		"Speaker":            [12, 6],
		"Spellslinger":       [0, 8],
		"Spellwright":        [0, 1],
		"Stablehand":         [2, 1],
		"Starborn Envoy":     [0, 12],
		"Starweaver":         [0, 13],
		"Stonehand":          [4, 4],
		"Stormrunner":        [8, 13],
		"Stormsinger":        [0, 10],
		"Street Performer":   [10, 12],
		"Sunforged":          [1, 4],   # Crafting + Exertion (solar-forge smith)
		"Tailor":             [1, 12],
		"Tavernkeeper":       [12, 5],
		"Technician":         [1, 6],
		"Tidebound Navigator":[13, 9],
		"Tideforged":         [1, 13],
		"Tidewalker":         [8, 13],
		"Veilforged":         [0, 8],
		"Veilweaver":         [0, 8],
		"Voidwatcher":        [5, 0],
		"Wanderer":           [13, 9],
		"Wandering Duelist":  [4, 8],
		"Warden":             [13, 9],
		"Windswept":          [13, 9],
		"Witchbinder":        [0, 6],
		"Witchfinder":        [0, 9],   # Arcane + Perception
	}

## Returns [primary_skill_idx, secondary_skill_idx] or [-1, -1] if unknown.
func get_role_skills(role_name: String) -> PackedInt32Array:
	_ensure_role_skills()
	if _ROLE_SKILLS.has(role_name):
		var arr: Array = _ROLE_SKILLS[role_name]
		return PackedInt32Array([int(arr[0]), int(arr[1])])
	return PackedInt32Array([-1, -1])

## Returns the +1d4 bonus for the given character's role on the given skill,
## or 0 if the skill is not one of the role's primary skills.
func get_role_skill_bonus(handle: int, skill_idx: int) -> int:
	if not _chars.has(handle): return 0
	var role: String = str(_chars[handle].get("societal_role", ""))
	if role == "": return 0
	var skills: PackedInt32Array = get_role_skills(role)
	if skills[0] == skill_idx or skills[1] == skill_idx:
		return randi_range(1, 4)
	return 0

# ── Lineage-region registry (overhaul Fix) ────────────────────────────────────
## Maps each canonical region to its native lineages.  Used by character
## creation to present region-appropriate lineages and for narrative flavoring.
static var _LINEAGE_REGIONS: Dictionary = {}

func _ensure_lineage_regions() -> void:
	if not _LINEAGE_REGIONS.is_empty(): return
	_LINEAGE_REGIONS = {
		"The Plains": [
			"Bouncian","Goldscale","Ironhide","Verdant","Vulpin",
			"Regal Human","Quillari","Felinar","Canidar","Cervin",
		],
		"Forest of SubEden": [
			"Bramblekin","Elf","Fae-Touched Human","Thornwrought Human",
			"Twilightkin","Verdant","Cervin","Myconid","Hearthkin",
		],
		"Kingdom of Qunorum": [
			"Regal Human","Gilded Human","Panoplian","Arcanite Human",
			"Voxilite","Archivist",
		],
		"Wilds of Endero": [
			"Cervin","Beetlefolk","Tetrasimian","Warden","Canidar",
			"Ursari","Taurin","Quillari",
		],
		"House of Arachana": [
			"Bloodsilk Human","Serpentine","Shadewretch","Whisperspawn",
		],
		"Eternal Library": [
			"Archivist","Bookborn","Regal Human","Lorekeeper",
		],
		"Metropolitan": [
			"Regal Human","Gilded Human","Voxilite","Gremlin","Gremlidian",
			"Gutterborn","Guildmaster",
		],
		"Upper Forty": [
			"Regal Human","Gilded Human","Voxilite","Starborn","Lightbound",
		],
		"Lower Forty": [
			"Scavenger Human","Gremlin","Gremlidian","Groblodyte","Gutterborn",
			"Rustspawn","Ferrusk","Scrapwright",
		],
		"Shadows Beneath": [
			"Sable","Duskling","Gloomling","Skulkin","Corvian",
			"Cavernborn","Umbrawyrm","Shadewretch",
		],
		"Corrupted Marshes": [
			"Blackroot","Mirevenom","Mireling","Mireborn Human","Bloatfen Whisperer",
			"Bogtender","Duckslings","Bilecrawler",
		],
		"Crypt at End of Valley": [
			"Cryptkin Human","Hollowborn Human","Skulkin","Gravetouched","Gravemantle",
			"Tombwalker","Myrrhkin",
		],
		"Spindle York's Schism": [
			"Hexkin","Hexshell","Hagborn Crone","Marionox","Chronogears",
			"Voxshell","Echo-Touched",
		],
		"Peaks of Isolation": [
			"Cragborn Human","Gravari","Lithari","Boreal Human","Windswept",
			"Ursari",
		],
		"Pharaoh's Den": [
			"Sandstrider Human","Serpentine","Gravari","Goldscale","Sunforged",
		],
		"The Darkness": [
			"Sable","Nightborne Human","Umbrawyrm","Duskling","Shadewretch",
			"Gloomling",
		],
		"Arcane Collapse": [
			"Arcanite Human","Madness-Touched Human","Hexkin","Parallax Watchers",
			"Riftborn Human","Weirkin Human",
		],
		"Argent Hall": [
			"Silverblood","Lightbound","Luminar Human","Auroran","Panoplian",
		],
		"Glass Passage": [
			"Glassborn","Prismari","Shardkin","Shardwraith","Porcelari",
		],
		"Sacral Separation": [
			"Lightbound","Luminar Human","Obsidian Seraph","Threnody Warden",
			"Pulsebound Hierophant",
		],
		"Infernal Machine": [
			"Hellforged","Cindervolk","Kettlekyn","Ferrusk","Ironjaw",
			"Kindlekin","Emberkin",
		],
		"Titan's Lament": [
			"Ursari","Taurin","Gravari","Stormclad","Sunderborn Human",
		],
		"Mortal Arena": [
			"Mercenary","Regal Human","Ironjaw","Bouncian","Stormclad",
			"Gladiator","Wandering Duelist",
		],
		"Vulcan Valley": [
			"Cindervolk","Emberkin","Volcant","Hellforged","Kettlekyn",
			"Sunforged",
		],
		"The Isles": [
			"Tiderunner Human","Tidewoven","Kelpheart Human","Fathomari",
			"Hydrakari","Trenchborn","Saurian",
		],
		"Depths of Denorim": [
			"Fathomari","Trenchborn","Hydrakari","Drakari","Kelpheart Human",
		],
		"Moroboros": [
			"Snareling","Scornshard","Chokeling","Flenskin","Filthlit Spawn",
		],
		"Gloamfen Hollow": [
			"Mireling","Bogtender","Bloatfen Whisperer","Mossling","Hollowroot",
		],
		"Astral Tear": [
			"Starborn","Starweaver","Parallax Watchers","Cloudling","Skysworn",
		],
		"L.I.T.O.": [
			"Voxshell","Voxilite","Marionox","Chronogears","Echoform Warden",
		],
		"West End Gullet": [
			"Gullet Mimes","Gremlin","Gremlidian","Groblodyte","Scavenger Human",
		],
		"Cradling Depths": [
			"Oozeling","Sludgeling","Dregspawn","Hollowroot","Blightmire",
		],
		"Terminus Volarus": [
			"Skysworn","Zephyrkin","Zephyrite","Cloudling","Nimbari",
		],
		"City of Eternal Light": [
			"Luminar Human","Lightbound","Auroran","Lanternborn","Candlites",
		],
		"Hallowed Sacrament": [
			"Lightbound","Obsidian Seraph","Convergents","Pulsebound Hierophant",
			"Soulbinder",
		],
		"Land of Tomorrow": [
			"Chronogears","Dreamer","Echo-Touched","Parallax Watchers",
			"Lifeborne",
		],
		"Sublimini Dominus": [
			"Abyssari","Nullborn","Nullborn Ascetic","Oblivari Human","Nihilian",
		],
		"Beating Heart of The Void": [
			"Bespoker","Brain Eater","Pulsebound Hierophant","Threnody Warden",
			"Mistborne Hatchling","Huskdrone","Voidwatcher",
		],
	}

## Returns all canonical Rimvale regions (for UI filtering).
func get_all_lineage_regions() -> PackedStringArray:
	_ensure_lineage_regions()
	var keys: Array = _LINEAGE_REGIONS.keys()
	return PackedStringArray(keys)

## Returns the lineages native to a given region.
func get_lineages_for_region(region: String) -> PackedStringArray:
	_ensure_lineage_regions()
	if _LINEAGE_REGIONS.has(region):
		return PackedStringArray(_LINEAGE_REGIONS[region])
	return PackedStringArray()

## Returns the first region that lists this lineage (for reverse lookups).
func get_lineage_home_region(lineage: String) -> String:
	_ensure_lineage_regions()
	for region in _LINEAGE_REGIONS.keys():
		if lineage in _LINEAGE_REGIONS[region]:
			return str(region)
	return ""

# ── Feat catalog ──────────────────────────────────────────────────────────────
## Feat registry: feat_name -> {cat: String, tiers: {tier_int: desc_string}}
## feat_name is the tree/family name (also used as display name in level_up.gd).
static var _FEAT_REGISTRY: Dictionary = {}
static var _FEAT_TIERS_MAP: Dictionary = {}  # tier -> [feat_name, ...]

func _ensure_feat_registry() -> void:
	if not _FEAT_REGISTRY.is_empty():
		return
	var cs: String = "Stat feats"
	var cc: String = "Weapons and Combat feats"
	var ca: String = "Armor feats"
	var cm: String = "Magic feats"
	var cal: String = "Alignment feats"
	var cd: String = "Domain feats"
	var ce: String = "Exploration feats"
	var ccr: String = "Crafting feats"
	var cap: String = "Apex feats"
	var casc: String = "Ascendant Feats"
	var cmi: String = "Miscellaneous feats"
	_FEAT_REGISTRY = {
		# ── Stat Feats ──
		"Arcane Wellspring": {"cat": cs, "tiers": {
			1: "Your SP is (2×Divinity)+Level+3. Once/LR reduce a spell's SP cost by Divinity.",
			3: "Spell echo: after spending SP, repeat spell effect at start of next turn (1/encounter). Once/LR regain SP equal to Divinity.",
			5: "Your SP is (3×Divinity)+Level+3. Once/LR cast a 2nd spell of equal or lower cost for free."}},
		"Iron Vitality": {"cat": cs, "tiers": {
			1: "Your HP is (2×Vitality)+(3×Level)+3. Once/encounter at ≤50% HP, gain bonus HP equal to Vitality.",
			3: "When healed, increase amount by Vitality. Once/LR succeed on saving throw → regain HP equal to Level.",
			5: "Your HP is (3×Vitality)+(3×Level)+3. Once/LR when damage would reduce you to 0, drop to 1 HP instead."}},
		"Martial Focus": {"cat": cs, "tiers": {
			1: "Your AP is (2×Strength)+3. Once/encounter reduce an AP cost by 1 when using a skill or ability.",
			3: "On initiative, gain bonus AP equal to Strength. Once/encounter reduce an AP cost by 1.",
			5: "Your AP is (3×Strength)+3. Once/round when attacking, move 5 ft without provoking opportunity attacks."}},
		"Safeguard": {"cat": cs, "tiers": {
			1: "Choose 2 stats. Use double stat score for saving throws with those stats. Once/LR reroll a failed saving throw.",
			2: "+2 to saving throws with chosen stats in addition to doubling. Once/SR advantage on a saving throw with chosen stats.",
			3: "Choose a 3rd stat for double-score saving throws. Success on saving throw grants nearby allies +1d4 to next action.",
			4: "Choose a 4th stat for double-score saving throws. Once/LR auto-succeed on a saving throw with any chosen stat.",
			5: "Apply double-score benefit to ALL stat-based saving throws. Once/SR after saving throw success, regain HP equal to Level."}},
		# ── Combat Feats ──
		"Assassin's Execution": {"cat": cc, "tiers": {
			1: "Reducing a creature to 0 HP deals an extra weapon damage die. Misses deal damage equal to attack stat (graze).",
			2: "If excess damage on kill ≥ creature max HP, the creature dies instantly. Once/SR auto-crit a creature that hasn't acted.",
			3: "Creature reduced to 0 HP must pass Vitality check (DC 10+excess) or die. Killing grants advantage on attacks for 1 minute."}},
		"Crimson Edge": {"cat": cc, "tiers": {
			2: "Simple slashing damage becomes 1d6. Once/turn ignore resistance to non-magical slashing.",
			3: "Slashing becomes 1d8. Once/turn deal +1 damage die.",
			5: "Slashing becomes 1d10. Once/turn ignore immunity to slashing."}},
		"Duelist's Path": {"cat": cc, "tiers": {
			1: "Parry roll ≥ attack+5 → basic counterattack. May parry for adjacent ally while holding shield.",
			2: "Advantage on next attack after successful parry. May parry ranged weapon attacks.",
			3: "Once/round feint as Free Action → +1d4 to parry. Once/LR Bastion Form (parry for 0 AP, 1 min)."}},
		"Fury's Call": {"cat": cc, "tiers": {
			1: "STR/SR: Enrage a creature on damage. Once/SR Enrage → −5 AC but resistance to that creature for 1 min.",
			2: "Enraged creature within 10 ft must save to move away. Resist Enraged enemy's damage.",
			3: "Once/encounter: action to Enrage all enemies in 30 ft cube. +1 AP regen per surrounding Enraged enemy (min 2).",
			4: "Enrage on any melee attack. Bloodied → 15 ft Vitality save vs Enrage for 2 rounds.",
			5: "Once/LR at <⅓ HP: Enrage all within 60 ft (no save). Enraged within 30 ft need save to move away."}},
		"Grasp of the Titan": {"cat": cc, "tiers": {
			1: "Advantage on grapple checks. Once/LR if grappled creature escapes, immediately knock it prone.",
			2: "While grappling, deal 1d4 bludgeoning at start of turn as Free Action. Move at full speed while dragging a grapple.",
			3: "Grapple two creatures at once (Medium or smaller). While grappling, creature has disadvantage on escape checks."}},
		"Iron Fist": {"cat": cc, "tiers": {
			1: "Unarmed 1d6, add STR+Exertion or SPD+Nimble. Once/turn ignore resistance.",
			2: "Unarmed 1d8. Once/turn hit → −10 ft movement speed.",
			3: "Magical 1d10, add 2× STR/SPD. Once/turn +1 die OR max damage once per long rest."}},
		"Iron Hammer": {"cat": cc, "tiers": {
			2: "Bludgeoning becomes 1d8 (2d8 two-handed). Once/turn ignore resistance.",
			3: "Bludgeoning becomes 1d10 (2d10). Once/turn hit → −10 ft movement speed.",
			5: "Bludgeoning becomes 1d12 (2d12/4d6). Once/turn ignore immunity."}},
		"Iron Thorn": {"cat": cc, "tiers": {
			2: "Piercing becomes 1d6. Once/turn ignore resistance.",
			3: "Piercing becomes 1d8. Once/turn hit → −1 AC until end of target's next turn.",
			5: "Piercing becomes 1d10. Once/turn ignore immunity."}},
		"Linebreaker's Aim": {"cat": cc, "tiers": {
			1: "Ignore half cover on ranged attacks.",
			2: "Ricochet shot (−2 attack) ignores full cover. Hit degrades cover one step.",
			3: "Ignore all non-magical cover. Once/SR Shattershot bursts through a 6-inch barrier."}},
		"Martial Prowess": {"cat": cc, "tiers": {
			1: "STR/SR: double attack bonus. Once/encounter reaction for +1d4 to attack or AC.",
			2: "Advantage on initiative. Avoid attack → stacking +1d4 to next attack.",
			3: "+1d4 vs single opponent. Miss deals stat score as damage (glancing blow)."}},
		"Precise Tactician": {"cat": cc, "tiers": {
			1: "Critical hits on 19–20. Once/encounter reroll a failed attack.",
			2: "Critical hits on 18–20. Crit → gain 2 AP.",
			3: "Critical hits on 17–20. Crit → INT save vs Stunned.",
			4: "Critical hits on 16–20. Crit → regain SR feat use OR grant group advantage.",
			5: "Critical hits on 15–20. Crit → make another attack."}},
		"Rest & Recovery": {"cat": cc, "tiers": {
			1: "Resting recovers +2 AP. Once/SR take Rest action as Free Action.",
			2: "Once/SR grant yourself or ally advantage vs Stunned/Frightened/Fatigued. Share half your rest AP with an adjacent ally.",
			3: "Once/LR when resting, regain 1d4+2 SP as well. Rest action can remove one minor condition.",
			4: "Once/LR rest grants advantage on rolls until end of next turn. Allies within 10 ft also regain rest AP."}},
		"Swift Striker": {"cat": cc, "tiers": {
			1: "Simple weapon proficiency, add stat to attack/damage. Once/encounter reroll failed attack.",
			2: "Add 2× stat to simple weapon damage. Graze effect on miss.",
			3: "Once/LR max damage hit. Once/turn hit → additional attack with Light simple weapon."}},
		"Titanic Damage": {"cat": cc, "tiers": {
			1: "Martial weapon proficiency, add stat to attack/damage. Hit → push 10 ft.",
			2: "Add 2× stat to martial damage. Kill → make another attack within reach.",
			3: "Once/LR max damage hit. Once/turn ignore disadvantage on attack."}},
		"Turn the Blade": {"cat": cc, "tiers": {
			1: "SPD/SR reaction: redirect a miss to another target (save vs 1d4). Gain +1 AC until next turn.",
			2: "Redirect deals full/half damage; can protect allies. Redirect → gain 1 AP.",
			3: "Once/SR reaction: redirect a miss to two enemies. Allies within 10 ft gain +1d4 to defense."}},
		"Twin Fang": {"cat": cc, "tiers": {
			1: "Dual wield non-light weapons (+1 AP). Both hit → +1d4 damage.",
			2: "No extra AP cost for dual wield; impose disadvantage. Both hit → 3rd attack (Reaction, 1 AP).",
			3: "Surrounded (2+) → +1 AC and AP regen. Parry off-hand reaction (negate attack).",
			4: "Dual wield Heavy weapons as if Light. Both hit → knock prone (STR save).",
			5: "Kill → two free attacks against another. Follow-up deals +1d6 if target <50% HP."}},
		"Unyielding Defender": {"cat": cc, "tiers": {
			1: "+1 AC. Once/LR Free Action shrug off a status.",
			2: "<⅓ HP → +2 AC. Resist at <⅔ HP → group +1d4 bonus.",
			3: "Once/LR reroll failed status save with advantage. Bloodied → half cover for allies within 5 ft."}},
		"Weapon Mastery": {"cat": cc, "tiers": {
			1: "Access mastery of 2 proficient weapons. Change chosen weapons on long rest.",
			2: "Use mastery of 4 weapons. Once/turn reroll a damage die of 1.",
			3: "Use mastery of 6 weapons. Once/SR auto-succeed an attack that triggers mastery."}},
		"Effect Shaper": {"cat": cc, "tiers": {
			1: "Non-spell DC = 10 + 2×stat. Once/LR force reroll of a successful non-spell check.",
			2: "Non-spell DC +2. Once/LR pick 2nd target within 5 ft if 1st succeeds save.",
			3: "Non-spell DC +1 (total +3). Once/LR apply Confused/Dazed/Slowed on failed save."}},
		"Improvised Weapon Mastery": {"cat": cc, "tiers": {
			1: "Proficient with improvised weapons; add stat; choose damage type (B/P/S).",
			2: "Damage becomes 1d6. Once/turn reaction: use object → +2 AC.",
			3: "Damage becomes 1d10. Crit → destroy weapon for +2d6. Once/encounter area explosion throw.",
			4: "Gain Light/Heavy property on pickup. +1 AP using 2 different weapons.",
			5: "Magical; splash 1d4 for large/thrown. Once/turn hit → STR/SPD save or disarm."}},
		# ── Armor Feats ──
		"Balanced Bulwark": {"cat": ca, "tiers": {
			1: "Proficiency with Medium Armor. Advantage on checks vs disarm while wearing it.",
			3: "While wearing Medium Armor, add full Strength or Speed score to AC.",
			5: "Once/turn when creature misses you in melee, make a free basic counterattack."}},
		"Deflective Stance": {"cat": ca, "tiers": {
			1: "+1 AC when dodging (stacks). +1 to next attack when evading.",
			2: "Once/round when missed in melee: free attack against attacker. Move 5 ft away without opportunity attack.",
			3: "Once/round reduce physical attack damage by Speed as reaction. Advantage on counterattack if using a shield.",
			4: "Once/LR when targeted by a single-target spell: force reroll or gain advantage on save."}},
		"Elemental Ward": {"cat": ca, "tiers": {
			1: "Resistance to one chosen elemental damage type. Once/LR reduce elemental damage taken by Vitality.",
			2: "Resistance to two additional elemental types. Once/SR return half damage to origin.",
			3: "Advantage on saving throws vs chosen elements. Succeed on save → temp HP equal to Vitality.",
			4: "Immunity to one chosen elemental type (changeable on long rest)."}},
		"Evasive Ward": {"cat": ca, "tiers": {
			1: "Proficiency with Light Armor. +2 to initiative while wearing it.",
			2: "Once/LR auto-succeed a Speed saving throw. Once/SR move 5 ft and avoid an attack as reaction.",
			3: "While in Light Armor, add 2× Speed score to AC. Once/LR force an attacker to reroll."}},
		"Titanic Bastion": {"cat": ca, "tiers": {
			1: "Proficiency with Heavy Armor.",
			2: "Add Strength score to AC while in Heavy Armor.",
			3: "Resistance to non-magical physical damage in Heavy Armor.",
			5: "Immunity to non-magical physical damage in Heavy Armor."}},
		"Tower Shield": {"cat": ca, "tiers": {
			1: "Shield proficiency; movement not reduced while shield is set (1/LR). Once/round reduce area effect damage by Vitality.",
			2: "While shield is set, resistance to non-magical ranged damage for you and one ally behind.",
			3: "Up to two allies behind shield gain full cover; reaction to impose disadvantage on attacks targeting allies."}},
		"Unarmored Master": {"cat": ca, "tiers": {
			1: "AC = (2×Speed)+10. Add Speed to a check (1/SR).",
			2: "Reduce damage by Xd4 (X=Speed). Move at half speed on a miss.",
			4: "Resistance to all non-magical damage. Move Speed score ft on a miss. Advantage on next check."}},
		"Wall of the Battered": {"cat": ca, "tiers": {
			1: "Shield proficiency plus one minor modification. Once/SR impose disadvantage on attack targeting ally within 5 ft.",
			2: "When ally within 5 ft is hit, use reaction to take the hit instead. Once/LR halve area spell damage for you and one ally.",
			3: "Adjacent shield-wielding ally: both gain +1 AC. Once/round adjacent ally hit → 1d4 shield bash.",
			4: "Shield: resistance to non-magical physical damage. Once/LR plant shield to become immovable for 1 minute.",
			5: "Once/LR absorb a spell targeting you or ally within 10 ft; regain half the SP cost. Allies within 10 ft gain Divinity bonus to all stat checks."}},
		"Warp": {"cat": ca, "tiers": {
			2: "On hit, reduce target AC by 1 until end of your turn (stacks). AC reduced by 2+ → advantage on next attack.",
			3: "On hit, reduce armor HP by 1d4. AC reduced by 3+ → target −1 to saving throws.",
			4: "On hit, reduce AC by 2; AC ≤10 → target is Vulnerable to next damage. AC ≤10 → deal +1d6 force damage until AC resets."}},
		# ── Magic Feats ──
		"Arcane Seal": {"cat": cm, "tiers": {
			1: "Seal a spell to trigger when a condition is met.",
			2: "Maintain up to 3 bound spells simultaneously.",
			3: "Maintain up to 5 bound spells simultaneously."}},
		"Blood Magic": {"cat": cm, "tiers": {
			1: "Spend 2 HP to gain 1 SP.",
			2: "Add Vitality score to spell rolls.",
			3: "Store SP in sacrifice pool.",
			4: "Spend HP to reduce spell SP cost.",
			5: "Heal twice Divinity on each kill."}},
		"Create Demiplane": {"cat": cm, "tiers": {
			1: "Create a 10×10×10 ft extradimensional space; stash/retrieve items ≤10 lbs (2/rest).",
			2: "Create a 30×30×30 ft customized demiplane. Regain +1 HP/hr inside.",
			3: "Create a 60×60×60 ft stable demiplane with environmental control; one spirit servant. +2 HP/hr inside."}},
		"Grasp of the Forgotten": {"cat": cm, "tiers": {
			1: "Summon spectral hand (AC 10, HP = Level) within 30 ft; delivers touch spells.",
			2: "Summon two independent hands; can restrain Small creatures.",
			3: "Hands fuse into Spectral Servant (AC 13, HP = 2×Level); takes actions, wields weapons, grapples."}},
		"Magic Expertise": {"cat": cm, "tiers": {
			1: "Proficient in magic attacks; add Arcane score to magic attack and damage. Once/SR recall arcane lore.",
			2: "Add double Divinity to magic attack and damage. Once/LR create temporary magical damage-resistance shield.",
			3: "Once/turn maximize one damage die on magic attack. Once/LR after hit, teleport up to 15 ft."}},
		"Master of Ceremonies": {"cat": cm, "tiers": {
			1: "Perform magical rituals by committing SP; maintain one ritual effect.",
			2: "Maintain two ritual effects. Reduce SP cost by 1 with a willing assistant.",
			3: "Each assistant reduces SP cost; ritual time 10 min/SP. Sacred site bonus.",
			4: "Bind ritual to physical anchor; persists while anchor is intact.",
			5: "Once/LR free ritual (max SP = 2×Divinity, 10 min). Ending a ritual voluntarily regains 2 SP."}},
		"Scryer": {"cat": cm, "tiers": {
			1: "Extend Scrying Eye range to 1 mile without extra SP cost.",
			2: "Scry any visited location in same region. While scrying, hear surface thoughts.",
			3: "Scry anywhere on the same plane. Once/LR anchor Scrying Eye for 24 hours."}},
		"Shapeshifter's Path": {"cat": cm, "tiers": {
			1: "Beast Initiate: Once/SR shapeshift into small/medium non-magical animal (0 stats) for 1 hour at 0 SP. Spend SP to add levels and assign stats/abilities (General + Animal). Revert as free action; if creature HP hits 0, revert and excess damage carries over. Communicate simple ideas to same-type animals.",
			2: "Beast Adept: Shapeshift 2/SR, up to Large size, 2 hours. Advantage on tracking/sensing using animal senses. Advantage on Speechcraft checks to influence animals.",
			3: "Beast Channeler: Shapeshift as free action, up to 4 hours. Magically enhanced animals unlocked. Resistance to non-magical damage; attacks deal magical damage. General magic abilities available for creature creation. Once/SR cast a spell while shapeshifted.",
			4: "Beast Sage: Access magical beast abilities; shapeshift 3/SR. Once/LR shapeshift a willing creature using your rules.",
			5: "Beast Archon: Shapeshift at will (no limit, no duration cap), up to Huge animals. Cast spells normally while shapeshifted."}},
		"Soul Weaver": {"cat": cm, "tiers": {
			4: "Create a soul anchor (24 hr ritual); if anchored creature dies, it returns at the anchor after 1 hour."}},
		"Spell Shaper": {"cat": cm, "tiers": {
			1: "Spell DC = 10 + 2×Divinity. Once/LR force a creature to reroll a successful save.",
			2: "Once/SR add 1d4 to spell DC or attack. Once/LR impose disadvantage on a successful save.",
			3: "Once/LR all creatures auto-fail their first save against your spell. Once/LR cast a half-cost spell as bonus."}},
		"Transmuter's Precision": {"cat": cm, "tiers": {
			1: "Transmute materials at 20 SP/ft³ (halved). Once/LR stabilize volatile transmutation.",
			2: "Transmute at 10 SP/ft³. Once/SR ignore +5 SP complexity cost.",
			3: "Transmute at 5 SP/ft³. Retain 75% of original material mass."}},
		# ── Alignment Feats ──
		"Chaos Initiate": {"cat": cal, "tiers": {
			1: "Identify chaotic effects/artifacts; +1d4 to arcane checks. Once/LR recall obscure lore.",
			2: "Once/LR remove effect SP cost for a Chaos spell (SP ≤ level). Arcane success → hidden truth.",
			3: "Orb of chaos (5 ft radius, −1 spell cost). Once/LR upgrade a Chaos spell by 1 rank in 2 parameters."}},
		"Chaos Pact Initiate": {"cat": cal, "tiers": {
			1: "Once/rest +1d4 to Speechcraft/Nimble in unpredictable situations. Once/LR sense chaos/unstable magic within 1 mile.",
			2: "Once/rest reroll failed save vs magic. Once/rest move through difficult terrain as insubstantial for 1 minute.",
			3: "Once/rest summon a chaos creature (effect SP ≤ level). Once/LR bargain with Chaos for a miracle."}},
		"Unity Scholar Initiate": {"cat": cal, "tiers": {
			1: "Identify holy/celestial artifacts; +1d4 to arcane/religion checks. Once/LR recall sacred lore.",
			2: "Once/LR remove effect SP cost for a Unity spell (SP ≤ level). Arcane/religion success → hidden truth.",
			3: "Orb of light (5 ft radius, −1 spell cost). Once/LR upgrade a Unity spell by 1 rank in 2 parameters."}},
		"Unity Pact Initiate": {"cat": cal, "tiers": {
			1: "Once/rest +1d4 to Speechcraft/Insight in bright light. Once/LR sense celestial/radiant power within 1 mile.",
			2: "Once/LR dispel blindness. Once/rest radiant burst; attackers have disadvantage.",
			3: "Once/rest summon a radiant guardian (effect SP ≤ level). Once/LR call for a miracle."}},
		"Void Initiate": {"cat": cal, "tiers": {
			1: "Identify magical effects; +1d4 to arcane checks. Once/LR recall obscure lore.",
			2: "Once/LR remove effect SP cost for a darkness spell (SP ≤ level). Arcane success → hidden truth.",
			3: "Orb of shadows (5 ft radius, −1 spell cost). Once/LR upgrade a darkness spell by 1 rank in 2 parameters."}},
		"Void Pact Initiate": {"cat": cal, "tiers": {
			1: "Once/rest +1d4 to Sneak/Deception in darkness. Once/LR sense Void/necrotic power within 1 mile.",
			2: "See in magical darkness. Once/rest become intangible for 1 round.",
			3: "Once/rest summon a shadowy minion (effect SP ≤ level). Once/LR bargain with Shadows for a miracle."}},
		# ── Domain Feats ──
		"Rooted Initiate": {"cat": cd, "domain": "Biological", "tier_names": {1: "Rooted Initiate", 2: "Verdant Channeler", 3: "Gaia's Mastery"}, "tiers": {
			1: "Primary: Biological domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: When you cast a Biological spell, cause small plants or moss to grow in a 10 ft cube, providing half cover until end of your next turn.",
			2: "Primary: Biological domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: When you cast a Biological spell, grant yourself a bonus to your next attack equal to the SP spent.",
			3: "Primary: Biological domain SP penalty eliminated (Minor: 0, Mod: 0, Maj: 0). Secondary: Once/LR call upon the earth to heal HP equal to 3x Divinity score and remove a minor condition (poisoned, fatigued, etc.)."}},
		"Alchemical Adept": {"cat": cd, "domain": "Chemical", "tier_names": {1: "Alchemical Adept", 2: "Fluid Transmuter", 3: "Combustion Savant"}, "tiers": {
			1: "Primary: Chemical domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: Once/SR create a basic alchemical solution (10 min). Reduces difficulty by 1 rank; auto-success if minor.",
			2: "Primary: Chemical domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: Once/SR neutralize a non-magical poison/toxin (up to 1ft³) as a free action, or cast a Chemical spell of 4 SP or less for free.",
			3: "Primary: Chemical domain SP penalty eliminated (Minor: 0, Mod: 0, Maj: 0). Secondary: Once/LR trigger a controlled chemical reaction to blind, daze, or slow enemies in a 30 ft area within 100 ft. Standard spell DC. No SP required."}},
		"Ember Manipulator": {"cat": cd, "domain": "Physical", "tier_names": {1: "Ember Manipulator", 2: "Kinetic Shaper", 3: "Mirage Architect"}, "tiers": {
			1: "Primary: Physical domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: Once/SR as a free action, ignite a small flame, reducing fire spell cost by 3 SP (max -6 with sources, min 0).",
			2: "Primary: Physical domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: Once/LR as an action, create an illusion that conceals you and allies (disadvantage on attacks against you for 1 minute).",
			3: "Primary: Physical domain SP penalty eliminated (Minor: 0, Mod: 0, Maj: 0). Secondary: When you use telekinesis or create an inanimate construct, it costs 2 less SP (min 0)."}},
		"Whispering Mind": {"cat": cd, "domain": "Spiritual", "tier_names": {1: "Whispering Mind", 2: "Ethereal Summoner", 3: "Veilbreaker"}, "tiers": {
			1: "Primary: Spiritual domain SP penalty reduced (Minor: 0, Mod: 2, Maj: 4). Secondary: Divinity score times per SR, send a brief telepathic message to an ally within sight. Target can respond immediately.",
			2: "Primary: Spiritual domain SP penalty reduced (Minor: 0, Mod: 0, Maj: 2). Secondary: Once/LR as an action, nullify a magical effect or barrier in your vicinity for 1 round.",
			3: "Primary: Spiritual domain SP penalty eliminated (Minor: 0, Mod: 0, Maj: 0). Secondary: When you summon or create an animate construct, it gains hover and intangible without adding to SP cost."}},
		# ── Exploration Feats ──
		"Agile Explorer": {"cat": ce, "tiers": {
			1: "Climb at full speed; not vulnerable while climbing. Once/LR auto-succeed on a fall/prone check.",
			2: "Once/rest ignore difficult terrain for 1 minute. Auto-move across narrow surfaces while unencumbered.",
			3: "Move at normal speed across water or liquids. Once/rest bring a contacting ally along."}},
		"Explorer's Grit": {"cat": ce, "tiers": {
			1: "+1d4 to navigation/survival checks in unknown terrain. Once/LR find a safe path or shortcut.",
			2: "+1d4 to find hidden objects, traps, or secret doors. Discovering hidden feature gives bonus to next exploration check.",
			3: "Once/LR lead a group safely; allies gain advantage on environmental danger checks for 1 hour."}},
		"Healing & Restoration": {"cat": ce, "tiers": {
			1: "Reduce minor medical challenge by one step; add Divinity to healing rolls. Once/SR give ally resistance to damage type.",
			3: "Reduce moderate injury challenge; add 2× Divinity to healing. Healing also removes one minor condition.",
			5: "Reduce major healing challenge; add 3× Divinity. Once/SR fully heal, mend object, or purge curse at no SP cost."}},
		"Illusion & Deception": {"cat": ce, "tiers": {
			1: "Reduce minor illusion challenge; illusion DC +1. Once/SR create fleeting illusion (1 min).",
			2: "Reduce complex illusion challenge; DC +2. Fooling enemy with illusion → advantage on checks vs them for 1 min.",
			3: "Reduce large-scale illusion challenge; DC +3. Once/LR alter perceptions of a group."}},
		"Mind Over Challenge": {"cat": ce, "tiers": {
			1: "Intellect×/day: +1d4 to skill checks. Once/SR reroll a failed skill check.",
			2: "Add 2× Intellect to all skill checks. Once/rest auto-succeed on DC ≤10 Intellect skill check.",
			3: "Add 3× Intellect to all skill checks. Once/LR treat a failed skill check as a natural 20."}},
		"Minion Master": {"cat": ce, "tiers": {
			1: "Once/LR summon a basic minion (0 SP, no duration, creature level ≤ your level, max 1). Acts on your initiative, obeys simple commands, always looks uncanny.",
			2: "Reaction: transfer damage to your minion (within 30 ft). Minion can be Medium. If you drop to 0 HP with a minion alive, it takes one action before vanishing.",
			3: "Control up to 3 minions at once. Once/LR fall unconscious and transfer your consciousness into a minion (1 mile range).",
			4: "Control up to 4 minions. Summoned minions gain bonus HP equal to your level. Minions gain resistance to one damage type of your choice."}},
		"Stealth & Subterfuge": {"cat": ce, "tiers": {
			1: "Reduce social manipulation challenge; once/rest advantage on Speechcraft. Once/LR create distraction/disguise to mislead pursuers.",
			2: "Convince as another person; once/LR mimic voice/mannerisms for 1 hour. Successful deception → target is friendly for 10 min.",
			3: "Reduce escape challenge; once/LR auto-escape physical or magical restraints."}},
		"Temporal Touch": {"cat": ce, "tiers": {
			1: "Haste or Slow a creature for 1d4 rounds (1/SR). Once/LR slow an area.",
			2: "Temporal sense: know if something has a timer or time limit. Once/LR accelerate or delay an effect by 1 round.",
			3: "Once/LR undo the effects of the last 6 seconds in a 5 ft radius (Rift effect)."}},
		# ── Miscellaneous ──
		"Arc Light Surge": {"cat": cmi, "tiers": {
			1: "Once/SR deal 1d6 lightning damage to adjacent creatures when hit by electricity.",
			3: "Arc leaps to one additional target."}},
		"Bender": {"cat": cmi, "tiers": {
			2: "Once/encounter choose to bend the outcome of one d20 roll ±2.",
			4: "Once/SR bend the outcome ±5."}},
		"Chaos Flow": {"cat": cmi, "tiers": {
			1: "Once/LR cast a random spell of up to 4 SP for free.",
			3: "Once/LR cast a random spell of up to 8 SP for free."}},
		"Flare of Defiance": {"cat": cmi, "tiers": {
			1: "Once/encounter at 0 HP, release a burst: all adjacent creatures take 1d6 damage.",
			3: "Burst becomes 2d6 and pushes enemies 10 ft."}},
		"Sacred Fragmentation": {"cat": cmi, "tiers": {
			1: "Spells that miss deal half damage.",
			3: "Spells that miss deal half damage and apply one minor condition."}},
		"Soulmark": {"cat": cmi, "tiers": {
			1: "Mark a creature; once marked, you always know its direction and approximate distance.",
			3: "Marked creature takes +1d4 damage from your attacks."}},
		"Whispers": {"cat": cmi, "tiers": {
			1: "Once/LR hear a secret truth about a creature or location you can see.",
			3: "Once/LR instill a suggestion in a creature's mind (Intellect save)."}},
		# ── C++ parity: 78 additional feat trees ──
		"Abyssal Unleashing": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 INT; expose to corrupted Philosopher's Stone; kill divine-aligned creature. Effects: Frenzied Flurry (1AP: 3 attacks, last +2d6); Tissue Detonation (3AP: sacrifice 6HP, 3d6 force 5ft radius); Terrify the Weak (2AP: frighten lower HP creatures in 30 ft); Sporestorm (3AP: poison and confusion in 20 ft for 1 round); True Name (1/day reduce spell cost by 2 SP). Drawback: Vulnerable to radiant and psychic; disadvantage vs creatures knowing your true name."}},
		"Alchemist's Supplies": {"cat": ccr, "tiers": {
			1: "Primary: Gain proficiency with Alchemist's Supplies; add Vitality score to all checks to identify, mix, or neutralize chemicals and potions. Secondary: 1/LR brew a basic alchemical concoction (minor acid, smoke bomb, or flash powder).",
			2: "Primary: Add 2x Vitality score to all Alchemist's Supplies checks. Secondary: 1/LR on a failed alchemy check, succeed instead.",
			3: "Primary: When crafting an alchemical item, reduce required preparation time by half (minimum 1 hour). Secondary: 1/week create a potent elixir granting resistance to one damage type or powerful effect for 24 hours."}},
		"Angelic Rebirth": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 STR; committed to Unity; fast 3 days at sacred place; forgiven enemy; die in service of divine cause. Effects: Immortal (no aging, 1/5 rate); Flight (1 AP reduced max: fly speed = foot speed); Radiant Pulse (3SP: 30ft 4d6 radiant blind 1 round); Healing Pulse (2SP: 3d6 to all allies in 30 ft); Safeguard Aura (3 AP reduced max: allies within 15 ft gain +2 AC). Drawback: Vulnerable to void magic; falling in love with a mortal removes flight and normal aging."}},
		"Apex": {"cat": cap, "tiers": {
			5: "Primary: Passive, move > 50ft -> 20ft path difficult terrain, structures 3d10 force. Secondary: 10ft DC 16 Dex or prone + 1d10."}},
		"Arc-Light Surge": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR basic action, discharge electric surge — all creatures within 10 ft make Speed save or take 1d6 lightning and drop metal items; spend 1 SP per additional 1d6. Secondary: Metal objects within 10 ft shed dim light for 1 round, revealing hidden or invisible creatures."}},
		"Arcane Residue": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR after casting a spell costing 3+ SP, leave a lingering magical zone in a 5 ft space for 1 minute; next creature entering takes 1d6 force damage. Secondary: If an ally moves through the zone, it heals the ally for 1d6 HP instead."}},
		"Artisan's Tools": {"cat": ccr, "tiers": {
			1: "Primary: 1/LR when using artisan's tools, reroll a failed crafting check and take the higher result (use not consumed unless reroll succeeds). Secondary: 1/LR reduce crafting time and cost for a nonmagical item by 25%.",
			2: "Primary: Add 2x Crafting score to checks with artisan's tools. Secondary: 1/LR restore or reinforce a damaged nonmagical item, granting it temporary HP equal to Crafting score x2 for 1 hour.",
			3: "Primary: Craft masterwork nonmagical items granting +1 bonus to a relevant skill or check when used. Secondary: 1/LR create a nonmagical item in half the time and cost, or imbue a crafted item with a minor magical property."}},
		"Astral Shear": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR move through up to 15 ft of solid matter as part of a Move action. Secondary: Surface retains a shimmering scar for 1 round; creatures within 5 ft take 1d4 + Divinity psychic damage."}},
		"Barkskin Ritual": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR as an action, grow bark over skin or armor; for 1 hour gain +2 AC and resistance to slashing damage. Secondary: While active, creatures that grapple you or strike you in melee take 1 piercing damage at the start of their turn."}},
		"Blade Scripture": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR as part of an attack action, inscribe a rune on your weapon; for 10 minutes deals +1d6 radiant or necrotic damage (your choice) and you heal 1 HP each time you hit. Secondary: While active, weapon sheds dim light in 10 ft radius; activate or deactivate as a Basic action."}},
		"Breath of Stone": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR as a Move action, brace your stance; for 1 minute immune to push/pull/prone, +2 AC; if standing on stone gain resistance to all damage. Secondary: While active, enemies that move within 5 ft have speed halved until end of their turn."}},
		"Calligrapher's Supplies": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Calligrapher's Supplies; add Intellect to calligraphy, forgery, and ancient script checks. Secondary: 1/SR create a scroll in 10 min granting advantage on one social or knowledge check.",
			2: "Primary: Add 2x Intellect to all Calligrapher's Supplies checks. Secondary: 1/SR inscribe a Seal of Silence (no sound in 10 ft for 1 hr) or Glyph of Clarity (advantage on Intellect checks within 10 ft for 1 hr) in 10 min.",
			3: "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/LR create a Living Script (sentient scroll that delivers a message, casts a stored spell 4 SP or less, or activates a magical effect; lasts 24 hrs or until task complete)."}},
		"Chaos Pact": {"cat": cal, "tiers": {
			1: "Primary: 1/rest, +1d4 Speechcraft/Nimble when unpredictable. Secondary: 1/LR, sense chaos/unstable magic within 1 mile.",
			2: "Primary: 1/rest, reroll failed save vs magic. Secondary: 1/rest, partially insubstantial 1 min (move through difficult terrain).",
			3: "Primary: 1/rest, summon chaos creature (effect SP <= level). Secondary: 1/LR, bargain with Chaos for a miracle."}},
		"Chaos Scholar": {"cat": cal, "tiers": {
			1: "Primary: identify chaotic effects/artifacts, +1d4 arcane checks. Secondary: 1/LR, recall obscure lore.",
			2: "Primary: 1/LR, remove effect SP cost for Chaos spell (effect SP <= level). Secondary: succeed arcane task -> uncover hidden truth.",
			3: "Primary: orb of chaos, 5ft radius, -1 spell cost. Secondary: 1/LR, upgrade Chaos spell 1 rank in 2 parameters."}},
		"Chaos's Flow": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR as a reaction, impose disadvantage on an enemy's check; if target succeeds, ability is not consumed and you can try again until a target fails. Secondary: If the enemy fails, you gain +1d4 to your next roll."}},
		"Coinreader's Wink": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR basic action, study a creature's body language for 10 seconds; gain advantage on next Insight, Deception, or Persuasion check against that creature for 1 hour. Secondary: If you succeed, the target becomes more careless, lowering DC of future social checks against them by 2 for 1 hour."}},
		"Crafting & Artifice": {"cat": ccr, "tiers": {
			1: "Primary: Craft/modify simple objects (DC 10 or less) in half the time with +2 to crafting checks. Secondary: 1/SR improvise a temporary magical or mechanical tool lasting 10 min or until used.",
			2: "Primary: Begin crafting moderate and minor projects in the field; time reduced by 25%. Secondary: When encountering a trap, magical lock, or malfunctioning device, make an instant Crafting or Intellect check to disable, bypass, or repair it.",
			3: "Primary: Install an energy core into one item (charges up to 3 SP); spend 1 SP to add 1d6 elemental damage, reduce spell cost by 2 SP, or empower a device. Secondary: 1/LR when targeted by a spell, redirect up to 3 SP of energy to the core."}},
		"Cryptborn Sovereign": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 INT; waltz with spirits in haunted graveyard; bargain with a ghost; bind to crypt artifact and die interred for one night. Effects: Tomb's Curse (passive: 30 ft aura enemies -1 all rolls); Blight Touch (2AP: 2d6 necrotic, no healing for 1 round); Death Rattle (passive: on death 1d6+1d6/SP necrotic in 10 ft); Zombification (return to life in 24 hrs, regenerate body parts); Regeneration (passive: 1d6 HP/turn even at 0 HP). Drawback: Vulnerable to radiant; DC 12 INT save to avoid dancing if you see people dancing."}},
		"Culinary Virtuoso": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency in cooking utensils; add Learnedness to cooking rolls and +1d4 to culinary checks. Secondary: 1/LR grant bonus AP equal to Intellect score.",
			2: "Primary: Infuse dishes with magical effects (1 action to consume): heal 1d4, +2 AC for 1 min, or +2 to attack rolls for 1 min. Secondary: 1/LR prepare a meal granting an ally resistance to a specific environmental hazard.",
			3: "Primary: During a long rest, prepare a feast; allies who consume it gain +2 max AP until their next long rest. Secondary: After sharing the feast, all participants gain +1d6 to teamwork actions or group checks for 1 hour."}},
		"Disguise Kit": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Disguise kit; add Intellect score to disguise and impersonation checks. Secondary: 1/LR create a disguise in half the normal time.",
			2: "Primary: Add 2x Intellect score to all Disguise Kit checks. Secondary: 1/encounter on a failed disguise check, avoid immediate detection.",
			3: "Primary: Cannot roll below 10 on disguise checks. Secondary: 1/week create a disguise so convincing it fools magical or divine detection for a short period."}},
		"Draconic Apotheosis": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 5 SP; hoard shiny object 30 days; survive elemental trial; consume dragon heart. Effects: Flight (1 AP reduced max: fly speed = foot speed); Breath Weapon (2SP: 60ft cone 6d6 elemental damage); Draconic Scales (+2 AC, resistance to chosen element); Terrify the Weak (2AP: frighten lower HP creatures in 30 ft). Drawback: Vulnerable to silver beneath ribcage; laughter grounds flight; DC 11 INT save near inaccessible shiny objects."}},
		"Dreamthief": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR when you touch a sleeping or unconscious creature, glimpse a fleeting image of their last dream or memory. Secondary: Gain +1d4 to your next Insight or Speechcraft check made against that creature."}},
		"Echoed Steps": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR take a Move action as a free action. Secondary: If this movement ends in cover or concealment, regain 1 AP."}},
		"Emberwake": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR as part of one move action, leave a trail of embers; enemies entering or starting in affected spaces take 1d6 fire damage and must succeed Speed save or have disadvantage on attacks until end of next turn. Secondary: Ignite non-magical flammable objects within 5 ft as a free action that round."}},
		"Erylon's Echo": {"cat": cmi, "tiers": {
			2: "Primary: 1/LR for 1 hour, you and all allies gain +1d4 to all skill checks. Secondary: Allies also gain advantage on saving throws against fear during this time."}},
		"Fey Lord's Pact": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 VIT; transform by fey magic for a day; tribute rare item to Fey Sovereign; enter pact. Effects: Disguise Flesh (2SP: mimic creature's form 1 hr); Teleport Swarm (4AP: teleport self + 3 allies within 120 ft); Charm Gaze (2SP: INT save DC 10+Divinity or charmed 1 min); Reality Distort (3 AP reduced max: alter terrain and visuals in 120 ft, INT save DC 10+Divinity). Drawback: Vulnerable to iron and necrotic; must uphold promises."}},
		"Fishing Mastery": {"cat": ccr, "tiers": {
			1: "Primary: Advantage on Survival checks to locate or catch fish; feed 1 person/hour (no check) or 1d4 people (with check). Secondary: Identify if a body of water is safe to fish in with a DC 10 Intuition or Learnedness check.",
			2: "Primary: Catch rare or magical fish with DC 15 Survival or Cunning check; reduce crafting costs by 1 SP. Secondary: 1/day reroll a failed fishing-related check and take the higher result.",
			3: "Primary: Feed up to 10 people with 1 hour of effort; 1/LR harvest 1d6 units of magical/alchemical reagents reducing crafting costs by the roll. Secondary: When consuming a magical fish, gain advantage on region-related Intuition or Learnedness checks for 1 hour."}},
		"Flicker Sparky": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR when you take damage, immediately teleport up to 10 ft to a visible space and your attacker takes 1d4 lightning damage as you leap away. Secondary: After teleporting, gain resistance to all damage until end of your next turn."}},
		"Hag Mother's Covenant": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 VIT; consume sentient heart beneath dying tree; overseen by a Hag Mother or person you care most about. Effects: Dreamweaver's Gift (3SP: grant creature's deepest desire, always carries secret cost); Nightmare Brood (3 AP reduced max: summon 3 Dreamspawn level 1 creatures); Twisted Boon (2SP: offer boon for 24 hrs, marked creatures vulnerable to your spells); Soulroot Effigy (2SP activate, 1SP/day: bind soul fragment to object, perceive/cast through it). Drawback: Vulnerable to radiant; cannot cross salt circles; haggard appearance."}},
		"Herbalism Kit": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Herbalism kit; add Intellect score to checks to identify or harvest herbs. Secondary: 1/LR brew a basic healing salve restoring 1d6 + Divinity HP.",
			2: "Primary: Add 2x Intellect score to all Herbalism Kit checks. Secondary: 1/LR when a potion brewing check fails, succeed instead.",
			3: "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/LR brew a potent elixir granting resistance to poison or disease for 24 hours."}},
		"Hollow Voice": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR mimic any sound or voice heard in past 24 hours for 10 minutes; creatures must succeed Insight (DC 10 + Speechcraft) to detect ruse. Secondary: If used to distract or mislead, allies gain advantage on their next Sneak or Cunning check against that target."}},
		"Hollowed Instinct": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR as a Reaction when targeted by a creature you cannot see, negate advantage against you for 1 minute. Secondary: If the attack still hits, immediately move 10 ft without provoking opportunity attacks."}},
		"Hunting Mastery": {"cat": ccr, "tiers": {
			1: "Primary: Advantage on Survival checks to track beasts; determine size, number, and condition of prey. Secondary: Harvest 1 additional ration from slain beast; meat stays fresh twice as long.",
			2: "Primary: 1/SR after tracking a creature for 10+ min, gain +1d4 to next attack or damage roll against it. Secondary: Harvest rare components (fur, glands, bones) from beasts reducing crafting costs by 1 SP; identify diseased/corrupted creatures (DC 12).",
			3: "Primary: 1/LR designate a quarry; advantage on tracking and +1d6 damage on first successful hit each round for 1 hour. Secondary: 1/LR ritualistic field dressing yields 1d4 units of high-quality material and restores 1d4 bonus AP."}},
		"Illusory Double": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR basic action, create a harmless illusory version of yourself for 1 minute or until destroyed (3 hits); if an enemy attack hits you, roll d6 — on 3 or less it hits the illusion instead. Secondary: While illusion is active, enemies within 10 ft of both you have disadvantage on opportunity attacks against you."}},
		"Infernal Coronation": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and one soul; intern for Archdevil; graduate Infernal Law School; survive trial of fire and law. Effects: Hellfire (5SP: 4d6 fire+2d6 thunder in 10 ft radius at 120 ft); Demonic Authority (auto-frighten lower Divinity creatures within 10 ft, no save); Second Chances (1/LR: on 0 HP, restore to 3x Vitality and teleport 120 ft); Flame Flicker Smite (free action: sacrifice HP for HPd4 fire on next hit); Devil Tail (manipulate 10 lbs within 5 ft, 1d4 magical slashing tail whip); Infernal Contract (3SP: bind willing/desperate creature to infernal contract). Drawback: Vulnerable to radiant; DC 15 INT save to resist contracts involving fiddles/violins."}},
		"Jeweler's Tools": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Jeweler's tools; add Intellect to checks to appraise, cut, or set gems. Secondary: 1/LR identify a magical property or flaw in a gemstone; enhance mundane item value by up to 25%.",
			2: "Primary: Add 2x Intellect to all Jeweler's Tools checks. Secondary: 1/LR on a failed jewelry crafting or appraisal check, succeed instead without damaging the item.",
			3: "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/week craft or enhance jewelry for a one-time-use minor magical effect or double its value."}},
		"Kaiju Core Integration": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 SPD; consume Kaiju organ; swear oath to protect/destroy a region; roar from high peak; survive extreme elemental exposure. Effects: Titanic Strength (+2 STR, +2 VIT, +5 AP); Stampede Call (3SP: 60ft cone 6d6 push 30 ft); Gravity Slam (2SP: 3d6 force knock adjacent prone); Molten Skin (passive: melee attackers take 1d6 fire); size becomes Huge. Drawback: Vulnerable to psychic and mind control; DC 15 VIT save to avoid minor rampage if called 'just a big lizard'."}},
		"Lich Binding": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 5 SP; dramatic graveyard monologue in thunderstorm; ritual with 1000 SP Philosopher's Stone and soul anchor; ritual in total darkness; die willingly with skeleton chorus. Effects: Undead (immune to poison, disease, aging); Phylactery (reform after death unless destroyed; transfer requires innocent soul); Soul Drain (3SP: 4d6 necrotic, heal half); Spark Steal (4AP: VIT save DC 10+Divinity or absorb 1d4 SP). Drawback: Vulnerable to radiant and divine disruption; sincere apologies cause DC 10 INT save or lose concentration; must absorb 1 innocent soul/year or lose immortality."}},
		"Locktap Lord": {"cat": cmi, "tiers": {
			1: "Primary: Gain advantage on Cunning checks to pick locks, disable traps, or detect hidden compartments. Secondary: 1/LR attempt to pick a lock or disable a device without tools, even under magical suppression."}},
		"Loreweaver's Mark": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR basic action, etch or whisper a magical glyph onto a surface or creature; sense its general direction while within 100 ft. Secondary: If placed on a willing creature, they gain +1 to their saves."}},
		"Lycanthropic Curse": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 5 SP; bitten by cursed werebeast; kill and feast on animal during blood moon. Effects: Hybrid Form (Basic action, 1 round transform: +3 STR, +2 SPD, +20 ft move, threshold = Level/2, immune to non-silver/non-magical damage); Rending Bite (normal damage + 1d4 bleed/turn for 3 rounds); Blood Howl (on kill, allies in 30 ft gain +1d4 damage for 1 min); Regeneration (1d6 HP/turn). Drawback: Vulnerable to silver and radiant; DC 10 VIT save if tail touched or complimented in hybrid/beast form."}},
		"Mirrorsteel Glint": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR reflect a spell targeting only you back at its caster (SP cost <= your level; Arcane check vs DC 10 + spell SP). Secondary: Gain resistance to that spell's damage type until your next turn regardless of outcome."}},
		"Musical Instrument": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with two instruments; add Divinity score to performance and instrument checks. Secondary: 1/LR play for 10 min healing allies within 30 ft for 4d4 + Divinity HP per 1 SP spent.",
			2: "Primary: Proficiency with 3 more instruments; add 2x Divinity to all proficient instrument checks. Secondary: 1/LR automatically succeed at a perform check.",
			3: "Primary: Proficiency with all instruments; add 2x Perform score to all Musical Instrument checks. Secondary: Difficulty of perform checks goes down one rank; minor perform checks automatically succeed."}},
		"Navigator's Tools": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Navigator's tools; add Intellect to navigation and map-reading checks. Secondary: 1/LR avoid becoming lost or reroute the party to a safer path.",
			2: "Primary: Add 2x Intellect to all Navigator's Tools checks. Secondary: On a failed navigation check, still determine general direction or location.",
			3: "Primary: Add 2x Learnedness score to all Navigator's Tools checks. Secondary: 1/week chart a new faster or hidden route granting the party advantage on travel checks for the journey."}},
		"Painter's Supplies": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Painter's supplies; add Divinity to checks to create, appraise, or restore artwork. Secondary: As an action, paint a symbol granting an ally advantage on one social or morale check in the next minute.",
			2: "Primary: Add 2x Divinity to all Painter's Supplies checks. Secondary: 1/LR on a failed art check, succeed instead without wasting materials.",
			3: "Primary: Add 3x Divinity to all Painter's Supplies checks. Secondary: 1/week create artwork so lifelike it can distract, inspire, or briefly fool magical detection."}},
		"Planar Graze": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR when you make a melee or ranged attack, on a hit deal +1d8 force damage and push target 15 ft (no save). Secondary: If target hits a solid surface, they take +1d6 psychic damage."}},
		"Poisoner's Kit": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Poisoner's kit; add Vitality to checks to craft, identify, or apply poisons. Secondary: 1/LR create a basic poison: disadvantage on attacks for 1 round, or add 1d4 poison damage to a single weapon.",
			2: "Primary: Add 2x Vitality to all Poisoner's Kit checks. Secondary: 1/LR on a failed poison crafting or application check, avoid self-exposure and succeed instead.",
			3: "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/week craft a potent poison that bypasses resistance or immunity for one use."}},
		"Primordial Elemental Fusion": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 INT; travel to 3 elemental domains; stand atop a mountain and consume a living storm. Effects: Elemental Burst (2SP: 15 ft radius chosen element within 30 ft, 4d6); Shifting Hide (2 AP/resistance: resistance to one damage type, multiple instances allowed); Sunfire Pulse (3AP: 15 ft aura 2d6 fire + exhaustion); Frozen Grasp (3AP: 10 ft cone SPD save or frozen Speed=0). Drawback: Vulnerable to non-elemental damage; DC 13 INT save or loudly narrate weather if temperature shifts 10+ degrees."}},
		"Psychic Maw": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 INT permanently; bargain with a psychic parasite; consume a brain. Effects: Void Exposure (3SP: 60ft blast 4d6 psychic, daze/confuse 1 min, heal half damage); Mind Break (3AP: stun 2d6 psychic 30 ft); Phase Shift (2AP: intangible until end of next turn); Maddening Aura (passive: enemies in 10 ft disadvantage on INT saves). Drawback: Vulnerable to radiant; feeding frenzy if sentient creature with INT >4 is within 30 ft."}},
		"Refraction Twist": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR as a reaction when targeted by an attack you can see, impose disadvantage on it as light bends around you. Secondary: If the attack still hits, take half damage from it."}},
		"Resonant Pulse": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR emit a harmonic pulse in a 10 ft radius; allies in the area gain +1d4 to attack rolls, skill checks, or saving throws for 1 minute. Secondary: Regain SP equal to the number of allies that benefit (cannot exceed maximum)."}},
		"Rune Cipher": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR for 1 hour, read any written language — magical or mundane, including runes, ancient glyphs, or magical scripts. Secondary: 1/LR automatically uncover a hidden message, secret, or ward in writing without a check."}},
		"Sacrifice": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR free action, give an ally some of your HP; for every 1 HP sacrificed, an ally regains 2 HP. Secondary: The ally also gains +1 to their next saving throw."}},
		"Seraphic Flame": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 VIT; receive phoenix feather; walk Trial of the Blazing Path; complete Rite of Ascension atop sacred pyre. Effects: Flame Flicker (AP reduced: melee hits +1d4 fire per AP reduced); Explosive Mix (3SP: 10 ft radius 4d6 fire+2d6 thunder, reroll 1s); Reflective Veil (2SP: advantage vs magic 1 min, reflect 1 spell); Healing and Restoration (2SP: heal 3d6 to allies in 30 ft, 1/LR). Drawback: DC 16 DIV save when healing a creature actively cursing divinity or suffer 2d6 radiant backlash."}},
		"Skywatcher's Sight": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR declare a creature, location, or object you seek; for 1 hour gain advantage on all Perception and Insight checks related to finding it. Secondary: Roll 1d100 — the higher the number, the clearer the vision of its current state."}},
		"Smith's Tools": {"cat": ccr, "tiers": {
			1: "Primary: Gain proficiency with Smith's tools; add Strength score to all checks to repair or craft metal items. Secondary: 1/LR repair a broken weapon or piece of armor to functional condition.",
			2: "Primary: Add 2x Strength score to all Smith's Tools checks. Secondary: 1/LR on a failed smithing crafting check, succeed instead.",
			3: "Primary: Reduce required preparation time by half (minimum 1 hour). Secondary: 1/week craft or enhance a weapon or armor to grant it a minor magical property or increased durability."}},
		"Spark Leech": {"cat": cmi, "tiers": {
			1: "Primary: 1/SR as a reaction when a creature within 10 ft casts a spell, force a Divinity save (DC 10 + Divinity); on failure, steal SP equal to your Divinity score. Secondary: If successful, gain +1 to your next saving throw."}},
		"Split Second Read": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR free action, instantly learn if a creature is afraid, angry, calm, or hiding something — no check required. Secondary: Gain +1 to AC or saving throws against effects initiated by that creature for the next 10 minutes."}},
		"Stormbound Titan": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP and 1 VIT; compose and perform a storm song; meal from storm-gathered ingredients; survive lightning storm with lightning-forged tattoo. Effects: Grow (active: increase size by 1 per AP reduced from max); Lightning Rod (3SP: 4d6 lightning to all in 10 ft when struck or activated); Arcshock Blink (1SP: teleport 30 ft, 2d6 lightning arcs in path); Stampede Call (3SP: 60 ft cone 6d6 push 30 ft); Gravity Slam (2SP: 3d6 force knock adjacent prone). Drawback: DC 15 VIT save if over 24 hrs without releasing lightning or small objects stick to you."}},
		"Temporal Shift": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR basic action, spend SP to bless or curse a number of targets equal to SP spent for 1 minute (no save); Bless: +1d4 to checks | Curse: -1d4 to checks. Secondary: Blessed allies gain +5 ft movement; cursed enemies lose 5 ft movement."}},
		"Tether Link": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR create a link with a willing ally within 30 ft; as a free action either of you may transfer HP 1-for-1. Secondary: While linked, both gain +1 to Insight checks involving each other and can sense the other's emotional state."}},
		"Thieves' Tools": {"cat": ccr, "tiers": {
			1: "Primary: Gain proficiency with Thieves' tools; add Speed score to all lockpicking and trap disarming checks. Secondary: 1/LR reroll a failed Thieves' Tools check.",
			2: "Primary: Add 2x Speed score to all Thieves' Tools checks. Secondary: 1/encounter on a failed check, avoid triggering a trap or alerting guards.",
			3: "Primary: Add 2x Cunning score to all Thieves' Tools checks. Secondary: 1/week automatically succeed on a Thieves' Tools check against a nonmagical lock or trap."}},
		"Tinker's Tools": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Tinker's tools; add Intellect to checks to repair, modify, or improvise small mechanical devices. Secondary: Improvise a tool or device granting you or an ally advantage on a related check.",
			2: "Primary: Add 2x Intellect to all Tinker's Tools checks. Secondary: 1/LR on a failed repair or invention check, succeed instead.",
			3: "Primary: Reduce required preparation time by half (min 1 hour). Secondary: 1/LR create or modify an item to grant a unique situational benefit (bypass obstacle, resist hazard, or one-time magical/technological effect)."}},
		"Unity Pact": {"cat": cal, "tiers": {
			1: "Primary: 1/rest, +1d4 Speechcraft/Insight in bright light. Secondary: 1/LR, sense celestial/radiant power within 1 mile.",
			2: "Primary: 1/LR, dispel blindness. Secondary: 1/rest, radiant burst, disadvantage for attackers.",
			3: "Primary: 1/rest, summon radiant guardian (effect SP <= level). Secondary: 1/LR, call for miracle."}},
		"Unity Scholar": {"cat": cal, "tiers": {
			1: "Primary: identify holy/celestial artifacts, +1d4 arcane/religion checks. Secondary: 1/LR, recall sacred lore.",
			2: "Primary: 1/LR, remove effect SP cost for Unity spell (effect SP <= level). Secondary: succeed arcane/religion task -> uncover hidden truth.",
			3: "Primary: orb of light, 5ft radius, -1 spell cost. Secondary: 1/LR, upgrade Unity spell 1 rank in 2 parameters."}},
		"Unity's Ebb": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR choose one: (1) Cast a healing spell costing <= level SP without spending SP; (2) Sacrifice SP to regain xd4 SP where x = SP sacrificed (cannot exceed max); (3) Mend a non-magical Large-or-smaller object to full HP. Secondary: (1) Target gains temp resistance to a damage type 1 hr; (2) Equipment magically cleaned, +1 Speechcraft 1 hr; (3) Object becomes unbreakable 10 min."}},
		"Vampiric Ascension": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 5 SP; bitten by Vampire; allow heartbeat to be silenced; kill creature that begged mercy; consume blood during full moon. Effects: Blood Drain (heal half damage on bite); Intangible + Flight (3 AP reduced max: fly speed = foot speed, intangible); Nightvision (see in magical darkness 300 ft); Charm Gaze (INT save DC 16 or charmed 1 min); Regeneration (return to 1 HP in 24 hrs if not staked). Drawback: Vulnerable to radiant and wooden stakes; cannot approach within 5 ft of consecrated cross; DC 10 INT save when attractive bleeding creature is upwind."}},
		"Veilbreaker Voice": {"cat": cmi, "tiers": {
			3: "Primary: 1/LR shout with supernatural force; all magical illusions or disguises within 20 ft are suppressed for 1 minute. Secondary: Allies within range who are Charmed or Frightened have those conditions suppressed for 1 minute."}},
		"Verdant Pulse": {"cat": cmi, "tiers": {
			1: "Primary: 1/LR basic action, cause plant life in a 10 ft radius to bloom; create difficult terrain, concealment, or edible herbs (sustains 3 people; 1 SP per 2 additional people). Secondary: Allies in the area gain +1 to Vitality saving throws for 1 hour."}},
		"Veyra's Veil": {"cat": cmi, "tiers": {
			2: "Primary: 1/LR over 10 minutes, prepare yourself; for the next hour gain advantage on Sneak and Cunning checks. Secondary: Leave no tracks or scent trail while this effect is active."}},
		"Void Pact": {"cat": cal, "tiers": {
			1: "Primary: 1/rest, +1d4 Sneak/Deception in darkness. Secondary: 1/LR, sense Void/necrotic power within 1 mile.",
			2: "Primary: see in magical darkness. Secondary: 1/rest, intangible 1 round.",
			3: "Primary: 1/rest, summon shadowy minion (effect SP <= level). Secondary: 1/LR, bargain with Shadows for a miracle."}},
		"Void Scholar": {"cat": cal, "tiers": {
			1: "Primary: identify magical effects, +1d4 arcane checks. Secondary: 1/LR, recall obscure lore.",
			2: "Primary: 1/LR, remove effect SP cost for darkness spell (effect SP <= level). Secondary: succeed arcane task -> uncover hidden truth.",
			3: "Primary: orb of shadows, 5ft radius, -1 spell cost. Secondary: 1/LR, upgrade darkness spell 1 rank in 2 parameters."}},
		"Voidborn Mutation": {"cat": casc, "tiers": {
			1: "Requirements: Sacrifice 4 SP, lose 1 INT or VIT permanently; survive divine/arcane fracture; spend a month in total darkness; observe dissolution of something significant. Effects: Phase Shift (1AP: intangible for 1 round); Void Exposure (3SP: 60 ft blast 4d6 psychic, daze and confuse VIT save DC 10+Divinity); Reality Distort (3 AP reduced max: alter terrain and visuals in 30 ft, INT save DC 10+Divinity); Immortal Mask (1/LR: prevent death, restore to full HP when at or below 0 HP). Drawback: Vulnerable to radiant; sincere compliments cause DC 10 INT save or glitch between dimensions."}},
		"Weatherwise Tailoring": {"cat": ccr, "tiers": {
			1: "Primary: Proficiency with Weaver's Tools; craft/modify clothing for up to +-2 TRR; mend tears without a check. Secondary: Craft basic cloth items in half the normal time; identify temperature rating of clothing with DC 10 check.",
			2: "Primary: Advantage on checks to create durable or decorative items (DC 15); craft up to +3 TRR gear. Secondary: Add minor property (water resistance, hidden pockets) without increasing DC; 1/LR grant ally advantage on Endurance check against environmental effects.",
			3: "Primary: Reduce crafting time by half; craft +4 TRR gear; integrate dual-environment protection into single outfit. Secondary: Allies wearing your gear gain +1 to social Intellect checks; 1/item enchant with minor magical effect (4 SP or less, up to Intellect active items); +1d4 to Endurance checks in extreme environments."}},
	}
	# Build the tier → [feat_name] lookup
	for feat_name_key in _FEAT_REGISTRY:
		var entry_val: Dictionary = _FEAT_REGISTRY[feat_name_key]
		for t_key in entry_val["tiers"]:
			if not _FEAT_TIERS_MAP.has(t_key):
				_FEAT_TIERS_MAP[t_key] = []
			if feat_name_key not in _FEAT_TIERS_MAP[t_key]:
				_FEAT_TIERS_MAP[t_key].append(feat_name_key)

func get_all_feat_categories() -> PackedStringArray:
	_ensure_feat_registry()
	var cats: Array = []
	for entry_val in _FEAT_REGISTRY.values():
		var c: String = str(entry_val.get("cat", ""))
		if c not in cats:
			cats.append(c)
	cats.sort()
	return PackedStringArray(cats)

func get_feat_trees_by_category(category: String) -> PackedStringArray:
	_ensure_feat_registry()
	var result: Array = []
	for feat_name_k in _FEAT_REGISTRY:
		if str(_FEAT_REGISTRY[feat_name_k].get("cat", "")) == category:
			result.append(feat_name_k)
	return PackedStringArray(result)

## Returns tier labels for each defined tier within the named feat tree.
## e.g. get_feats_by_tree("Arcane Wellspring") → ["Tier 1", "Tier 3", "Tier 5"]
func get_feats_by_tree(tree_name: String) -> PackedStringArray:
	_ensure_feat_registry()
	var entry: Dictionary = _FEAT_REGISTRY.get(tree_name, {})
	if entry.is_empty(): return PackedStringArray()
	var tiers: Dictionary = entry.get("tiers", {})
	var labels: Array = []
	var sorted_tiers: Array = tiers.keys()
	sorted_tiers.sort()
	for t in sorted_tiers:
		labels.append("Tier %d" % int(t))
	return PackedStringArray(labels)

func get_feats_by_category(category: String) -> PackedStringArray:
	return get_feat_trees_by_category(category)

func get_feats_by_tier(tier: int) -> PackedStringArray:
	_ensure_feat_registry()
	var feats_at_tier: Array = _FEAT_TIERS_MAP.get(tier, [])
	feats_at_tier = feats_at_tier.duplicate()
	feats_at_tier.sort()
	return PackedStringArray(feats_at_tier)

func get_feat_details(feat_name: String, tier: int) -> PackedStringArray:
	_ensure_feat_registry()
	var entry: Dictionary = _FEAT_REGISTRY.get(feat_name, {})
	var desc: String = str(entry.get("tiers", {}).get(tier, ""))
	var cat: String = str(entry.get("cat", "Miscellaneous feats"))
	return PackedStringArray([desc, cat, feat_name])

func get_feat_description(feat_name: String, tier: int) -> String:
	_ensure_feat_registry()
	var entry: Dictionary = _FEAT_REGISTRY.get(feat_name, {})
	return str(entry.get("tiers", {}).get(tier, ""))

# ── World / quests ────────────────────────────────────────────────────────────
## Region registry: { name -> {climate, trr, terrains: [ {name, benefits, risks} ] } }
const _REGIONS: Dictionary = {
	"The Plains": {
		"climate": "Temperate, seasonal, mild weather",
		"trr": 0,
		"terrains": [
			{"name":"Rolling Grasslands",   "benefits":["+2 Perception","+1 AP regen"],      "risks":["-2 Stealth","Vulnerable to ranged"]},
			{"name":"Ancestral Barrows",    "benefits":["Reroll failed DIV save","+2 Insight"], "risks":["-2 VIT saves in necrotic","Fear risk"]},
			{"name":"House of Arachana",    "benefits":["Adv. on hearing Perception"],        "risks":["-2 Speed","Restrained risk"]},
			{"name":"Kingdom of Qunorum",   "benefits":["+1 Speechcraft","Adv. Intuition social"], "risks":["Crowds: -1 Initiative","-2 Sneak"]},
			{"name":"Wilds of Endero",      "benefits":["+2 Sneak","+1 for foraging"],        "risks":["-2 Speed saves","Disadv. Vitality humidity"]},
			{"name":"Forest of SubEden",    "benefits":["+2 Divinity checks","Adv. vs illusion"], "risks":["-2 Intellect","Random initiative"]},
			{"name":"Eternal Library",      "benefits":["+2 Arcane/Learnedness","Recall 1 fact"], "risks":["Whispers: Disadv. Intellect"]},
		]
	},
	"The Metropolitan": {
		"climate": "Mild in Upper Forty, polluted and hot in Lower Forty",
		"trr": 1,
		"terrains": [
			{"name":"Upper Forty",    "benefits":["+2 Acrobatics","+2 Speechcraft elites"],  "risks":["Surveillance: -2 Stealth"]},
			{"name":"Lower Forty",    "benefits":["Resistance to fire","+2 STR machines"],   "risks":["-2 Perception smoke","Disease risk"]},
			{"name":"Rooftop Heights","benefits":["+2 Acrobatics","Adv. Perception above"],  "risks":["Vulnerable to shove/falling"]},
			{"name":"Neon Alleyways", "benefits":["Adv. Cunning"],                           "risks":["Disadv. ranged attacks"]},
		]
	},
	"The Shadows Beneath": {
		"climate": "Cool, damp, necrotic chill, miasmas",
		"trr": 1,
		"terrains": [
			{"name":"Corrupted Marshes",       "benefits":["+2 Stealth","Immune to disease"],     "risks":["Vulnerable to necrotic","Difficult terrain"]},
			{"name":"Spindle York's Schism",   "benefits":["+1 Arcane","+1 save vs fear"],        "risks":["Disadv. Initiative rolls"]},
			{"name":"Crypt at the End of Valley","benefits":["Resistance to necrotic","+1 Religion"],"risks":["Exhaustion risk at dawn"]},
		]
	},
	"Peaks of Isolation": {
		"climate": "Bitter cold, blizzards, thin air",
		"trr": 4,
		"terrains": [
			{"name":"Frozen Spires",   "benefits":["Resistance to cold","+1 Survival"],    "risks":["Slippery surfaces","-1 Initiative"]},
			{"name":"Pharaoh's Den",   "benefits":["Immune to fear","+1 save vs necrotic"],"risks":["-2 Vitality checks","Vulnerable radiant"]},
			{"name":"The Darkness",    "benefits":["+2 Sneak","Can throw voice"],           "risks":["Echoes: Disadv. Learnedness/Survival"]},
			{"name":"Arcane Collapse", "benefits":["Cast 1 minor spell for 0 SP","+2 Arcana"],"risks":["Overreach surges on 1-3"]},
			{"name":"Argent Hall",     "benefits":["+2 Survival minerals","Cold resistance"],"risks":["Halved speed w/o insulation"]},
		]
	},
	"The Glass Passage": {
		"climate": "Blistering heat, frigid nights, glass storms",
		"trr": 4,
		"terrains": [
			{"name":"Shimmering Dunes",  "benefits":["+1 Sneak","Illusions more effective"],"risks":["Exhaustion in daylight"]},
			{"name":"Sacral Separation", "benefits":["+2 Stealth (silent sands)"],         "risks":["25% Spell failure (verbal)"]},
			{"name":"Infernal Machine",  "benefits":["+2 checks vs constructs"],            "risks":["Loud gears: 10% spell failure"]},
		]
	},
	"Titan's Lament": {
		"climate": "Volcanic, unstable, alternating heat and chill",
		"trr": 3,
		"terrains": [
			{"name":"Mortal Arena", "benefits":["+2 Perform","+1 Attack roll witnessed"],"risks":["Enemies adv. if hostile crowd"]},
			{"name":"Vulcan Valley","benefits":["Fire spells +1 damage/die"],            "risks":["Metal heats: 1 fire dmg/round"]},
		]
	},
	"The Isles": {
		"climate": "Subtropical, stormy, unpredictable",
		"trr": 2,
		"terrains": [
			{"name":"Depths of Denorim","benefits":["+2 Stealth/Perception underwater"],"risks":["Crushing pressure","Cold"]},
			{"name":"Moroboros",         "benefits":["Adv. vs Enchantment"],            "risks":["Disadv. navigation","Disoriented"]},
			{"name":"Gloamfen Hollow",   "benefits":["Dash as bonus action sliding"],   "risks":["Poison fumes risk"]},
		]
	},
	"Astral Tear": {
		"climate": "Frigid, otherworldly, planar winds",
		"trr": 3,
		"terrains": [
			{"name":"L.I.T.O.",          "benefits":["+2 Intuition","Adv. vs charm"],         "risks":["-2 Intellect","Disadv. Divinity saves"]},
			{"name":"West End Gullet",   "benefits":["+1 Arcane","Detect Magic active"],       "risks":["Reality distortion (Confusion)"]},
			{"name":"Cradling Depths",   "benefits":["Darkvision +30ft","See invisible"],      "risks":["Shadow whispers (Psychic risk)"]},
		]
	},
	"Terminus Volarus": {
		"climate": "Frigid base, colder as you ascend",
		"trr": 4,
		"terrains": [
			{"name":"City of Eternal Light","benefits":["Never need sleep","+2 VIT saves"],        "risks":["Vulnerable to radiant"]},
			{"name":"Land of Tomorrow",     "benefits":["+2 Learnedness","Adv. vs radiation"],     "risks":["-2 Performance (detachment)"]},
			{"name":"Hallowed Sacrament",   "benefits":["+1 to all saving throws"],               "risks":["Blinded in darkness","-2 Stealth if not divine"]},
		]
	},
	"Sublimini Dominus": {
		"climate": "Paradoxical, freezing and burning, void exposure",
		"trr": 5,
		"terrains": [
			{"name":"Echo Pools",               "benefits":["Restoring 1 SP per hour"],             "risks":["Auditory hallucinations (Confusion risk)"]},
			{"name":"Null Zones",               "benefits":["Immunity to magical detection"],        "risks":["Spellcasting cost x2","Items inert"]},
			{"name":"Beating Heart of the Void","benefits":["+2 Arcana/DIV involving sound"],       "risks":["Psychic risk verbal spells"]},
		]
	},
}

func get_all_regions() -> PackedStringArray:
	return PackedStringArray(_REGIONS.keys())

func get_region_details(region_name: String) -> PackedStringArray:
	if not _REGIONS.has(region_name): return PackedStringArray()
	var r: Dictionary = _REGIONS[region_name]
	return PackedStringArray([
		"Climate: " + str(r["climate"]),
		"TRR Requirement: %d" % int(r["trr"]),
		"Terrains: %d" % int((r["terrains"] as Array).size()),
	])

func get_region_terrains(region_name: String) -> PackedStringArray:
	if not _REGIONS.has(region_name): return PackedStringArray()
	var terrains: Array = _REGIONS[region_name]["terrains"]
	var names: Array = []
	for t in terrains:
		names.append(t["name"])
	return PackedStringArray(names)

func get_terrain_details(region_name: String, terrain_name: String) -> Array:
	if not _REGIONS.has(region_name): return []
	for t in _REGIONS[region_name]["terrains"]:
		if t["name"] == terrain_name:
			return [terrain_name, t["benefits"], t["risks"]]
	return []

func get_quests_by_region(region_name: String) -> Array:
	return []

func get_quest_regions() -> PackedStringArray:
	return get_all_regions()

## Generate a fully-populated quest for the given region.
## Returns PackedStringArray:
##   [title, region, type, description, skill1, skill2, skill3,
##    difficulty(str), reward_gold(str), reward_xp(str), anomaly, complication]
func generate_quest(region: String = "") -> PackedStringArray:
	# Pick a region if none supplied
	var r: String = region
	if r.is_empty():
		var all_regions: PackedStringArray = get_all_regions()
		if all_regions.is_empty():
			r = "The Plains"
		else:
			r = str(all_regions[randi() % all_regions.size()])

	# Short name for sentence construction (first word)
	var short_r: String = r.split(" ")[0]

	const TEMPLATES: Array = [
		["Investigate", "Exploration",
			"Strange activity has been reported near %s. Scout the area and uncover the source.",
			["Perception", "Survival", "Cunning"]],
		["Clear Bandits from", "Combat",
			"Outlaws have fortified themselves near %s. Drive them out and secure the road.",
			["Exertion", "Perception", "Intimidation"]],
		["Escort the Caravan through", "Escort",
			"A merchant convoy needs protection travelling the dangers of %s.",
			["Perception", "Speechcraft", "Exertion"]],
		["Collect Reagents in", "Gathering",
			"The alchemist requires rare reagents found only in %s. Retrieve them safely.",
			["Survival", "Medical", "Creature Handling"]],
		["Broker Peace in", "Diplomacy",
			"Rival factions are clashing in %s. Negotiate a truce before the situation erupts.",
			["Speechcraft", "Cunning", "Learnedness"]],
		["Hunt the Beast of", "Combat",
			"A creature has been preying on settlements near %s. Track it down and end the threat.",
			["Exertion", "Perception", "Survival"]],
		["Recover the Relic from", "Exploration",
			"An ancient artifact lies buried beneath %s. Retrieve it before rival factions do.",
			["Learnedness", "Cunning", "Perception"]],
		["Rescue Prisoners in", "Rescue",
			"Captives are held by hostile forces in %s. Infiltrate and bring them home.",
			["Sneak", "Exertion", "Perception"]],
		["Sabotage the Supply Line in", "Stealth",
			"An enemy faction is moving supplies through %s. Disrupt the operation quietly.",
			["Sneak", "Cunning", "Exertion"]],
		["Establish Contact in", "Diplomacy",
			"A potential ally operates somewhere in %s. Find them and make a deal.",
			["Speechcraft", "Perception", "Learnedness"]],
		["Fortify the Outpost near", "Construction",
			"A forward outpost near %s needs reinforcing before the next attack.",
			["Exertion", "Crafting", "Learnedness"]],
		["Purge the Corruption in", "Spiritual",
			"An unnatural blight is spreading through %s. Cleanse it at the source.",
			["Medical", "Arcane", "Survival"]],
	]

	const ANOMALIES: Array = [
		"The area is unusually quiet — no wildlife, no sounds.",
		"A recent tremor has shifted the terrain.",
		"Fog clings to the ground even in daylight.",
		"Signs of a prior expedition litter the path.",
		"A faction symbol is burned into every door.",
		"The locals refuse to speak about recent events.",
		"Strange lights were seen here the night before.",
		"An eerie calm follows every noise you make.",
		"The stars seem wrong here at night.",
		"Fresh tracks suggest you're not the only ones here.",
	]

	const COMPLICATIONS: Array = [
		"A rival crew has the same objective.",
		"One party member has a personal history with someone here.",
		"The contact who gave you this job may be compromised.",
		"The reward has been quietly doubled — someone really wants this done.",
		"A time limit is now in play.",
		"The target is better protected than the briefing suggested.",
		"Locals are hostile to outsiders — no easy allies.",
		"The objective has moved since the briefing.",
		"Collateral damage will have political consequences.",
		"There is a witness who must not see your faces.",
	]

	var tpl: Array = TEMPLATES[randi() % TEMPLATES.size()]
	var title: String = str(tpl[0]) + " " + r
	var qtype: String = str(tpl[1])
	var desc: String  = str(tpl[2]) % short_r
	var skills: Array = tpl[3] as Array
	var diff: int = randi() % 3 + 1
	var gold: int = 30 + diff * 20 + randi() % 20
	var xp: int   = 20 + diff * 15 + randi() % 15
	var anomaly: String     = str(ANOMALIES[randi() % ANOMALIES.size()])
	var complication: String = str(COMPLICATIONS[randi() % COMPLICATIONS.size()])

	return PackedStringArray([
		title, r, qtype, desc,
		str(skills[0]), str(skills[1]), str(skills[2]),
		str(diff), str(gold), str(xp),
		anomaly, complication
	])

## Roll a skill challenge for an entity.
## Returns PackedStringArray: [passed(0/1), roll(str), modifier(str), dc(str), detail_text]
func execute_skill_challenge(entity_handle: int, skill_name: String, dc: int, stat_override: int = -1) -> PackedStringArray:
	const SKILL_NAMES: Array = [
		"Arcane","Crafting","Creature Handling","Cunning","Exertion",
		"Intuition","Learnedness","Medical","Nimble","Perception",
		"Perform","Sneak","Speechcraft","Survival"
	]
	# Governing stat index for each skill:
	# DIV=4: Arcane, Intuition, Perform, Speechcraft
	# INT=2: Crafting, Learnedness, Medical
	# STR=0: Creature Handling, Exertion
	# SPD=1: Cunning, Nimble, Sneak
	# VIT=3: Perception, Survival
	const SKILL_STAT: PackedInt32Array = [
		4, 2, 0, 1, 0,   # Arcane(DIV), Crafting(INT), CreatureHandling(STR), Cunning(SPD), Exertion(STR)
		4, 2, 2, 1, 3,   # Intuition(DIV), Learnedness(INT), Medical(INT), Nimble(SPD), Perception(VIT)
		4, 1, 4, 3        # Perform(DIV), Sneak(SPD), Speechcraft(DIV), Survival(VIT)
	]
	var skill_idx: int = SKILL_NAMES.find(skill_name)
	var modifier: int  = 0
	var roller_name: String = "Unknown"
	if entity_handle >= 0 and _chars.has(entity_handle):
		if skill_idx >= 0:
			modifier = get_character_skill(entity_handle, skill_idx)
			# Add the governing stat value
			var c: Dictionary = _chars[entity_handle]
			var stats: Array = c.get("stats", [1, 1, 1, 1, 1])
			var stat_idx: int = stat_override if stat_override >= 0 else SKILL_STAT[skill_idx]
			modifier += int(stats[stat_idx])
		roller_name = str(get_character_name(entity_handle))

	var d20: int   = randi() % 20 + 1
	var total: int = d20 + modifier
	var passed: bool = total >= dc
	var detail: String
	if d20 == 20:
		detail = "%s rolled a natural 20! (%d + %d = %d vs DC %d)" % [roller_name, d20, modifier, total, dc]
	elif d20 == 1:
		detail = "%s fumbled! Rolled a 1 (%d + %d = %d vs DC %d)" % [roller_name, d20, modifier, total, dc]
	else:
		var result_word: String = "Success" if passed else "Failed"
		detail = "%s: %d + %d = %d vs DC %d — %s" % [roller_name, d20, modifier, total, dc, result_word]

	return PackedStringArray([
		"1" if passed else "0",
		str(total),
		str(modifier),
		str(dc),
		detail
	])

## Returns craftable items as array of PackedStringArrays: [name, materials, duration_seconds]
func get_craftable_items() -> Array:
	return [
		PackedStringArray(["Iron Sword",      "Iron Ingot x2, Leather Strip",   "120"]),
		PackedStringArray(["Iron Shield",      "Iron Ingot x3, Wood Plank",       "90"]),
		PackedStringArray(["Leather Armor",    "Leather Hide x4, Thread",         "90"]),
		PackedStringArray(["Chain Mail",       "Iron Ingot x5, Steel Ring x10",   "180"]),
		PackedStringArray(["Hunting Bow",      "Wood Plank x2, Sinew x3",         "60"]),
		PackedStringArray(["Healing Potion",   "Bloodmoss x2, Vial",              "30"]),
		PackedStringArray(["Antitoxin",        "Silverweed, Vial",                "25"]),
		PackedStringArray(["Mana Draught",     "Arcane Dust x3, Vial",            "45"]),
		PackedStringArray(["Smoke Bomb",       "Charcoal, Sulfur, Cloth",         "20"]),
		PackedStringArray(["Climbing Tools",   "Iron Hook x2, Rope",              "40"]),
		PackedStringArray(["Field Kit",        "Bandage x3, Needle, Thread",      "15"]),
		PackedStringArray(["Torchpack",        "Wood Handle, Oil-soaked Cloth x3","10"]),
		PackedStringArray(["Shortbow",         "Wood Plank, Sinew",               "45"]),
		PackedStringArray(["Lockpicks",        "Iron Wire x3",                    "30"]),
		PackedStringArray(["Throwing Knives",  "Iron Shard x4",                   "25"]),
		PackedStringArray(["Whetstone",        "Flint, Leather Strip",            "10"]),
		PackedStringArray(["Rope (30ft)",      "Fiber Bundle x5",                 "15"]),
		PackedStringArray(["Lantern",          "Glass Bulb, Iron Frame, Oil",     "35"]),
	]

# ── Factions (stubs) ──────────────────────────────────────────────────────────
func get_all_factions() -> PackedStringArray:
	return PackedStringArray()

func get_faction_details(faction_name: String) -> PackedStringArray:
	return PackedStringArray()

func get_faction_ranks(faction_name: String) -> PackedStringArray:
	return PackedStringArray()

# ── NPCs (stubs) ──────────────────────────────────────────────────────────────
func get_all_registered_npcs() -> PackedStringArray:
	return PackedStringArray()

func spawn_registered_npc(name: String) -> int:
	return -1

func set_npc_drivers(handle: int, community: int, validation: int, resources: int) -> void:
	pass

func get_npc_disposition(handle: int) -> int:
	return 50

func get_npc_disposition_text(handle: int) -> String:
	return "Neutral"

func interact_with_npc(handle: int, c: int, v: int, r: int) -> void:
	pass

func spawn_adversary(name: String, level: int) -> int:
	return -1

func get_adversary_vengeance_bonus(handle: int) -> int:
	return 0

func adversary_survive_encounter(handle: int) -> void:
	pass

# ── Creature Categories (PHB/GMG) ─────────────────────────────────────────────
const CAT_ANIMAL:    int = 0
const CAT_VILLAGER:  int = 1
const CAT_ADVERSARY: int = 2
const CAT_MONSTER:   int = 3
const CAT_APEX:      int = 4
const CAT_KAIJU:     int = 5

# ── Creature name pools by category ──────────────────────────────────────────
const CREATURE_NAMES_ANIMAL: Array = [
	"Wolf","Bear","Boar","Python","Hawk","Panther","Dire Wolf","Giant Spider",
	"Wyvern","Basilisk","Rat Swarm","Viper","Giant Scorpion","Cave Bat",
	"Timber Wolf","Mountain Lion","Giant Beetle","War Hound",
]
const CREATURE_NAMES_VILLAGER: Array = [
	"Bandit","Thug","Guard","Cultist","Mercenary","Assassin","Knight",
	"Priest","Hedge Mage","Captain","Highwayman","Poacher","Smuggler",
	"Corrupt Official","Militia Deserter","Tavern Brawler","Pirate","Scout",
]
const CREATURE_NAMES_MONSTER: Array = [
	"Goblin Raider","Skeleton","Zombie","Imp","Crawler","Stinger","Ogre",
	"Wraith","Gorgon","Troll","Orc Warrior","Dark Elf","Ghoul","Shade",
	"Hobgoblin","Gnoll","Harpy","Minotaur","Chimera","Manticore",
]

# ── Creature weapon pools by category ────────────────────────────────────────
const CREATURE_WEAPONS_ANIMAL: Array = ["Bite","Claw","Talons","Fangs","Horns","Stinger","Constrict"]
const CREATURE_WEAPONS_VILLAGER: Array = [
	"Short Sword","Dagger","Spear","Handaxe","Club","Crossbow","Longbow",
	"Mace","Rapier","Shortsword","Longsword",
]
const CREATURE_WEAPONS_MONSTER: Array = [
	"Rusty Sword","Crude Axe","Bone Club","Jagged Dagger","Wicked Spear",
	"Spiked Mace","Dark Blade","Cursed Staff","Poison Fang","Shadow Claw",
]

# ── GMG Creature Stat Formulas ────────────────────────────────────────────────

## Returns total stat points for a creature of given category and level (GMG table).
static func _creature_stat_points(category: int, level: int) -> int:
	match category:
		0:  # Animal
			if level <= 0: return 2
			if level == 1: return 4
			if level == 2: return 6
			return 9
		1:  # Villager
			if level <= 0: return 4
			if level == 1: return 6
			if level == 2: return 8
			return 10
		_:  # Adversary, Monster, Apex, Kaiju
			return 5 + level

## Distributes stat points across STR, SPD, INT, VIT, DIV with category weighting.
## Returns [STR, SPD, INT, VIT, DIV].
static func _creature_distribute_stats(total_pts: int, category: int) -> Array:
	var p: int = total_pts / 5
	var r: int = total_pts % 5
	var str_v: int = p + (1 if r > 0 else 0)
	var spd_v: int = p + (1 if r > 1 else 0)
	var int_v: int = p + (1 if r > 2 else 0)
	var vit_v: int = p + (1 if r > 3 else 0)
	var div_v: int = p
	# Category-specific adjustments
	match category:
		0:  # Animal: +1 STR, +1 SPD, -2 INT (min 0)
			str_v += 1; spd_v += 1; int_v = maxi(0, int_v - 2)
		3, 4, 5:  # Monster/Apex/Kaiju: +1 VIT, +1 STR
			vit_v += 1; str_v += 1
	return [str_v, spd_v, int_v, vit_v, div_v]

## GMG max HP formula by creature category.
static func _creature_max_hp(category: int, level: int, vit: int) -> int:
	match category:
		0: return maxi(1, level + vit + 2)             # Animal
		1: return maxi(1, 2 * level + vit + 2)         # Villager
		2: return maxi(1, 3 * level + vit + 2)         # Adversary
		3: return maxi(1, 3 * level + vit + 2)         # Monster
		4: return maxi(1, 5 * level + vit + 2)         # ApexMonster
		5: return maxi(1, 10 * level + vit + 2)        # Kaiju
	return maxi(1, 3 * level + vit + 2)

## GMG max AP formula by creature category.
static func _creature_max_ap(category: int, level: int, str_v: int) -> int:
	match category:
		0: return maxi(1, 1 + str_v)                   # Animal
		1: return maxi(1, 2 + str_v)                    # Villager
		2: return maxi(1, 3 + str_v)                    # Adversary
		3: return maxi(1, 3 + str_v)                    # Monster
		4: return maxi(1, 10 + str_v)                   # ApexMonster
		5: return maxi(1, 10 + level + str_v)           # Kaiju
	return maxi(1, 3 + str_v)

## GMG max SP formula by creature category.
static func _creature_max_sp(category: int, level: int, div: int) -> int:
	match category:
		0: return maxi(0, 1 + level + div)              # Animal
		1: return maxi(0, 2 + level + div)              # Villager
		2: return maxi(0, 3 + level + div)              # Adversary
		3: return maxi(0, 3 + level + div)              # Monster
		4: return maxi(0, 10 + level + div)             # ApexMonster
		5: return maxi(0, 10 + level + div)             # Kaiju
	return maxi(0, 3 + level + div)

## Movement speed in tiles. Animals are faster (base 3 + SPD), others 2 + SPD.
static func _creature_speed_tiles(category: int, spd: int) -> int:
	if category == 0:  # Animal
		return maxi(1, 3 + spd)
	return maxi(1, 2 + spd)

## AC formula: base 10 + SPD + level scaling. Apex/Kaiju get bonus.
static func _creature_calc_ac(category: int, level: int, spd: int) -> int:
	var base_ac: int = 10 + spd
	match category:
		0: base_ac += level / 3         # Animal: natural armor scales slowly
		1: base_ac += level / 4         # Villager: poor armor
		2: base_ac += level / 2         # Adversary: decent gear
		3: base_ac += level / 2 + 1     # Monster: natural armor + level
		4: base_ac += level / 2 + 3     # Apex: heavy natural armor
		5: base_ac += level / 2 + 5     # Kaiju: massive armor
	return base_ac

## Damage threshold (Apex/Kaiju only). Damage below this value is ignored.
static func _creature_damage_threshold(category: int, level: int) -> int:
	if category == 4 or category == 5:
		return maxi(5, level)
	return 0

# ── Creature Ability Database (GMG) ──────────────────────────────────────────
# Each ability: {"name", "ap_cost", "sp_cost", "dice":[count,sides], "range",
#                "conds":[], "desc", "cooldown":"none"/"1/turn"/"1/encounter"/"1/rest"}

## Returns default abilities for a creature of given category and level.
static func _creature_default_abilities(category: int, level: int, stats: Array) -> Array:
	var str_v: int = int(stats[0])
	var spd_v: int = int(stats[1])
	var int_v: int = int(stats[2])
	var vit_v: int = int(stats[3])
	var div_v: int = int(stats[4])
	var abilities: Array = []
	match category:
		0:  # Animal
			abilities.append({"name":"Bite","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":[],"desc":"Basic bite attack.","cd":"none"})
			if level >= 2:
				abilities.append({"name":"Pounce","ap":2,"sp":0,"dice":[1,8],"range":1,"conds":["prone"],"desc":"Leap and strike, knocking prone on hit.","cd":"1/turn"})
			if spd_v >= 4:
				abilities.append({"name":"Pack Tactics","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Advantage on attacks if ally is adjacent to target.","cd":"passive"})
			if level >= 5:
				abilities.append({"name":"Savage Rend","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":["bleeding"],"desc":"Tear into prey causing bleeding.","cd":"1/encounter"})
		1:  # Villager
			abilities.append({"name":"Strike","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":[],"desc":"Basic weapon attack.","cd":"none"})
			abilities.append({"name":"Call for Help","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Alert nearby allies, granting them advantage on next attack.","cd":"1/encounter"})
			if level >= 2:
				abilities.append({"name":"Improvised Weapon","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":[],"desc":"Grab nearby object and swing.","cd":"none"})
			if level >= 4:
				abilities.append({"name":"Dirty Fighting","ap":1,"sp":0,"dice":[1,4],"range":1,"conds":["blinded"],"desc":"Throw dirt or strike below the belt.","cd":"1/turn"})
		2, 3:  # Adversary / Monster
			abilities.append({"name":"Strike","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":[],"desc":"Melee weapon attack.","cd":"none"})
			if str_v >= 3:
				abilities.append({"name":"Multi-attack","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":[],"desc":"Two rapid strikes.","cd":"none"})
			if div_v >= 2:
				abilities.append({"name":"Elemental Spark","ap":1,"sp":1,"dice":[1,8],"range":4,"conds":[],"desc":"Hurl a bolt of elemental energy.","cd":"none"})
			if level >= 3:
				abilities.append({"name":"Terrifying Roar","ap":2,"sp":2,"dice":[0,0],"range":0,"conds":["frightened"],"desc":"20ft cone — all creatures must save or become frightened.","cd":"1/encounter"})
			if level >= 5:
				abilities.append({"name":"Power Strike","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":[],"desc":"Devastating heavy blow.","cd":"1/turn"})
			if level >= 7 and div_v >= 3:
				abilities.append({"name":"Dark Bolt","ap":1,"sp":2,"dice":[2,8],"range":6,"conds":[],"desc":"Necrotic bolt of dark energy.","cd":"none"})
			if level >= 10:
				abilities.append({"name":"Whirlwind","ap":3,"sp":0,"dice":[2,6],"range":1,"conds":[],"desc":"Attack all adjacent enemies.","cd":"1/encounter"})
		4:  # Apex
			abilities.append({"name":"Multi-attack","ap":2,"sp":0,"dice":[2,10],"range":1,"conds":[],"desc":"Multiple devastating strikes.","cd":"none"})
			abilities.append({"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Auto-succeed a failed saving throw.","cd":"special"})
			abilities.append({"name":"Frightful Presence","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":["frightened"],"desc":"30ft aura — enemies must save or be frightened.","cd":"1/encounter"})
			if level >= 12:
				abilities.append({"name":"Devastating Slam","ap":3,"sp":0,"dice":[3,10],"range":1,"conds":["prone","stunned"],"desc":"Earth-shattering blow.","cd":"1/turn"})
			if div_v >= 4:
				abilities.append({"name":"Arcane Barrage","ap":2,"sp":3,"dice":[3,8],"range":8,"conds":[],"desc":"Volley of arcane projectiles.","cd":"none"})
		5:  # Kaiju
			abilities.append({"name":"Titanic Strike","ap":2,"sp":0,"dice":[4,10],"range":2,"conds":["prone"],"desc":"Massive physical attack.","cd":"none"})
			abilities.append({"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Auto-succeed a failed saving throw.","cd":"special"})
			abilities.append({"name":"Earthquake","ap":3,"sp":0,"dice":[2,8],"range":0,"conds":["prone"],"desc":"All creatures within 30ft must save or take damage and fall prone.","cd":"1/encounter"})
			abilities.append({"name":"Terrifying Presence","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":["frightened"],"desc":"Passive 60ft aura of fear.","cd":"passive"})
			if div_v >= 5:
				abilities.append({"name":"Breath Weapon","ap":3,"sp":4,"dice":[6,8],"range":10,"conds":[],"desc":"60ft cone of devastating elemental energy.","cd":"1/encounter"})
	return abilities

# ── GMG Monster Ability Database ─────────────────────────────────────────────
# Comprehensive monster abilities organized by level tier and type.
# These are appended based on creature name/type during spawning.

const GMG_MONSTER_ABILITIES: Dictionary = {
	# ── Level 1-3: Basic Threats ──
	"Goblin Raider": [
		{"name":"Nimble Escape","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Disengage or Hide as a free action.","cd":"1/turn"},
		{"name":"Sneak Attack","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":[],"desc":"+1d6 damage when ally is adjacent to target.","cd":"1/turn"},
	],
	"Skeleton": [
		{"name":"Bone Reassembly","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"On death, 25% chance to reassemble at 1 HP next round.","cd":"1/encounter"},
		{"name":"Undead Fortitude","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Immune to poison, exhaustion, and frightened.","cd":"passive"},
	],
	"Zombie": [
		{"name":"Undead Fortitude","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"When reduced to 0 HP, VIT save DC 5+damage: drop to 1 HP instead.","cd":"1/encounter"},
		{"name":"Infectious Bite","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":["poisoned"],"desc":"Bite that inflicts poisoned condition.","cd":"none"},
		{"name":"Slam","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":[],"desc":"Heavy bludgeoning attack.","cd":"none"},
	],
	"Imp": [
		{"name":"Invisibility","ap":1,"sp":1,"dice":[0,0],"range":0,"conds":["invisible"],"desc":"Turn invisible until attacking or taking damage.","cd":"1/encounter"},
		{"name":"Sting","ap":1,"sp":0,"dice":[1,4],"range":1,"conds":["poisoned"],"desc":"Venomous sting.","cd":"none"},
		{"name":"Fire Spit","ap":1,"sp":1,"dice":[1,6],"range":4,"conds":[],"desc":"Spit a gob of hellfire.","cd":"none"},
	],
	"Rat Swarm": [
		{"name":"Swarm Attack","ap":1,"sp":0,"dice":[2,4],"range":1,"conds":["bleeding"],"desc":"Overwhelm with dozens of bites.","cd":"none"},
		{"name":"Disease Carrier","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Creatures bitten must save or contract filth fever.","cd":"passive"},
	],
	"Bandit": [
		{"name":"Cheap Shot","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":["dazed"],"desc":"Sucker punch that dazes.","cd":"1/turn"},
		{"name":"Flee","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Disengage and move full speed away.","cd":"1/encounter"},
	],
	"Crawler": [
		{"name":"Acid Spit","ap":1,"sp":0,"dice":[1,6],"range":3,"conds":["vulnerable"],"desc":"Corrosive ranged attack that weakens armor.","cd":"none"},
		{"name":"Burrow","ap":2,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Dig underground, becoming untargetable until next turn.","cd":"1/encounter"},
	],
	# ── Level 4-6: Moderate Threats ──
	"Orc Warrior": [
		{"name":"Aggressive Charge","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Move up to speed toward enemy as a free action.","cd":"1/turn"},
		{"name":"Brutal Critical","ap":0,"sp":0,"dice":[1,8],"range":0,"conds":[],"desc":"On critical hit, add extra weapon die of damage.","cd":"passive"},
		{"name":"Relentless","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"When reduced to 0 HP, drop to 1 HP instead (1/rest).","cd":"1/encounter"},
	],
	"Dark Elf": [
		{"name":"Faerie Fire","ap":1,"sp":2,"dice":[0,0],"range":6,"conds":["glowing"],"desc":"Outline target in light — attacks against have advantage.","cd":"1/encounter"},
		{"name":"Darkness","ap":1,"sp":2,"dice":[0,0],"range":4,"conds":["blinded"],"desc":"Create sphere of magical darkness.","cd":"1/encounter"},
		{"name":"Poison Blade","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":["poisoned"],"desc":"Envenomed weapon strike.","cd":"none"},
		{"name":"Superior Darkvision","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"See 120ft in darkness.","cd":"passive"},
	],
	"Troll": [
		{"name":"Regeneration","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Regain 1d6 HP at start of turn unless damaged by fire or acid.","cd":"passive"},
		{"name":"Rend","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":["bleeding"],"desc":"Tear with both claws.","cd":"none"},
		{"name":"Loathsome Limbs","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Severed limbs continue attacking independently for 1 round.","cd":"passive"},
	],
	"Ogre": [
		{"name":"Sweeping Club","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":["prone"],"desc":"Wide swing hitting all adjacent enemies.","cd":"1/turn"},
		{"name":"Rock Throw","ap":2,"sp":0,"dice":[2,6],"range":6,"conds":[],"desc":"Hurl a boulder at distant target.","cd":"none"},
		{"name":"Thick Skull","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Advantage on saves vs being stunned or dazed.","cd":"passive"},
	],
	"Gnoll": [
		{"name":"Rampage","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"After reducing a creature to 0 HP, move half speed and bite as free action.","cd":"1/turn"},
		{"name":"Incite Fury","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"All gnoll allies within 30ft gain +1d4 to next attack.","cd":"1/encounter"},
	],
	"Harpy": [
		{"name":"Luring Song","ap":1,"sp":1,"dice":[0,0],"range":8,"conds":["charmed"],"desc":"INT save or charmed, moving toward harpy.","cd":"1/encounter"},
		{"name":"Talons","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":[],"desc":"Raking claw attack.","cd":"none"},
		{"name":"Flyby","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Does not provoke opportunity attacks when flying out of reach.","cd":"passive"},
	],
	# ── Level 7-10: Serious Threats ──
	"Wraith": [
		{"name":"Life Drain","ap":1,"sp":0,"dice":[2,6],"range":1,"conds":[],"desc":"Necrotic touch that reduces target's max HP by damage dealt.","cd":"none"},
		{"name":"Incorporeal Movement","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Move through solid objects and creatures.","cd":"passive"},
		{"name":"Sunlight Sensitivity","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Disadvantage on attacks and perception in sunlight.","cd":"passive"},
		{"name":"Create Specter","ap":3,"sp":3,"dice":[0,0],"range":1,"conds":[],"desc":"Raise a slain humanoid as a specter under wraith's control.","cd":"1/encounter"},
	],
	"Gorgon": [
		{"name":"Petrifying Breath","ap":3,"sp":3,"dice":[0,0],"range":4,"conds":["restrained"],"desc":"30ft cone — VIT save or begin turning to stone (restrained, then petrified).","cd":"1/encounter"},
		{"name":"Trampling Charge","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":["prone"],"desc":"Rush and trample, knocking prone.","cd":"1/turn"},
		{"name":"Metal Hide","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Resistance to non-magical physical damage.","cd":"passive"},
	],
	"Minotaur": [
		{"name":"Gore","ap":1,"sp":0,"dice":[2,8],"range":1,"conds":[],"desc":"Devastating horn strike.","cd":"none"},
		{"name":"Charge","ap":2,"sp":0,"dice":[2,10],"range":1,"conds":["prone"],"desc":"Rush 20ft and gore — prone on hit.","cd":"1/turn"},
		{"name":"Labyrinthine Recall","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Perfect recall of paths traveled. Cannot be lost.","cd":"passive"},
		{"name":"Reckless","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Can choose to attack with advantage, granting advantage to attackers.","cd":"1/turn"},
	],
	"Chimera": [
		{"name":"Lion Bite","ap":1,"sp":0,"dice":[2,6],"range":1,"conds":[],"desc":"Lion head bites.","cd":"none"},
		{"name":"Ram Horns","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":["prone"],"desc":"Goat head rams.","cd":"none"},
		{"name":"Fire Breath","ap":2,"sp":2,"dice":[3,8],"range":4,"conds":[],"desc":"Dragon head breathes a 15ft cone of fire.","cd":"1/encounter"},
		{"name":"Triple Threat","ap":3,"sp":0,"dice":[0,0],"range":1,"conds":[],"desc":"All three heads attack simultaneously.","cd":"1/turn"},
	],
	"Manticore": [
		{"name":"Tail Spikes","ap":1,"sp":0,"dice":[1,8],"range":6,"conds":[],"desc":"Fling tail spikes at range.","cd":"none"},
		{"name":"Claw","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":[],"desc":"Rending claw attack.","cd":"none"},
		{"name":"Flyby","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Does not provoke opportunity attacks when flying.","cd":"passive"},
		{"name":"Spike Volley","ap":3,"sp":0,"dice":[3,8],"range":6,"conds":[],"desc":"Launch a barrage of tail spikes at multiple targets.","cd":"1/encounter"},
	],
	"Stinger": [
		{"name":"Venomous Sting","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":["poisoned"],"desc":"Inject powerful venom.","cd":"none"},
		{"name":"Paralyzing Venom","ap":2,"sp":1,"dice":[1,6],"range":1,"conds":["paralyzed"],"desc":"Concentrated venom that paralyzes (VIT save).","cd":"1/encounter"},
		{"name":"Chitin Armor","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Natural armor grants +2 AC.","cd":"passive"},
	],
	# ── Level 11-15: Elite Threats ──
	"Hobgoblin": [
		{"name":"Martial Advantage","ap":0,"sp":0,"dice":[2,6],"range":0,"conds":[],"desc":"+2d6 damage when ally is within 5ft of target (1/turn).","cd":"1/turn"},
		{"name":"Formation Tactics","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"All hobgoblin allies within 30ft gain +2 AC until next turn.","cd":"1/encounter"},
		{"name":"Disciplined Strike","ap":1,"sp":0,"dice":[1,10],"range":1,"conds":[],"desc":"Precise, calculated weapon attack.","cd":"none"},
	],
	"Ghoul": [
		{"name":"Paralyzing Touch","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":["paralyzed"],"desc":"VIT save or paralyzed for 1 round.","cd":"none"},
		{"name":"Devour","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":[],"desc":"Bite paralyzed target for bonus damage and heal half.","cd":"1/turn"},
		{"name":"Stench","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":["poisoned"],"desc":"Adjacent creatures must save at turn start or be poisoned.","cd":"passive"},
	],
	"Shade": [
		{"name":"Shadow Step","ap":1,"sp":1,"dice":[0,0],"range":6,"conds":[],"desc":"Teleport between shadows within 60ft.","cd":"1/turn"},
		{"name":"Life Siphon","ap":1,"sp":0,"dice":[2,6],"range":1,"conds":[],"desc":"Necrotic strike that heals shade for half damage dealt.","cd":"none"},
		{"name":"Shadow Cloak","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"In dim light or darkness, attacks against shade have disadvantage.","cd":"passive"},
		{"name":"Dread Gaze","ap":1,"sp":1,"dice":[0,0],"range":4,"conds":["frightened"],"desc":"INT save or frightened for 1 round.","cd":"1/encounter"},
	],
	# ── Level 16-20: Deadly Threats ──
	"Giant Spider": [
		{"name":"Web","ap":2,"sp":0,"dice":[0,0],"range":4,"conds":["restrained"],"desc":"SPD save or restrained by sticky webbing.","cd":"1/turn"},
		{"name":"Venomous Bite","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":["poisoned"],"desc":"Inject neurotoxin.","cd":"none"},
		{"name":"Web Sense","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Know exact location of any creature touching web.","cd":"passive"},
		{"name":"Spider Climb","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Climb any surface, including ceilings.","cd":"passive"},
	],
	"Cave Bat": [
		{"name":"Screech","ap":1,"sp":0,"dice":[1,4],"range":4,"conds":["deafened"],"desc":"Sonic blast that deafens.","cd":"1/turn"},
		{"name":"Blood Drain","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":[],"desc":"Attach and drain blood, healing bat for amount drained.","cd":"none"},
		{"name":"Echolocation","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Blindsight 60ft. Cannot be blinded.","cd":"passive"},
	],
	"Viper": [
		{"name":"Lightning Strike","ap":1,"sp":0,"dice":[1,4],"range":1,"conds":["poisoned"],"desc":"Extremely fast venomous bite.","cd":"none"},
		{"name":"Coil & Strike","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":["poisoned"],"desc":"Wind up for a devastating double-damage strike.","cd":"1/turn"},
	],
	"Wolf": [
		{"name":"Pack Tactics","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Advantage on attack if ally adjacent to target.","cd":"passive"},
		{"name":"Trip","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":["prone"],"desc":"Bite and drag down — STR save or prone.","cd":"1/turn"},
	],
	"Bear": [
		{"name":"Bear Hug","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":["grappled"],"desc":"Grab and crush — STR save or grappled.","cd":"1/turn"},
		{"name":"Maul","ap":1,"sp":0,"dice":[2,8],"range":1,"conds":[],"desc":"Powerful claw swipe.","cd":"none"},
	],
	"Boar": [
		{"name":"Charge","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":["prone"],"desc":"Rush and gore — prone on hit.","cd":"1/turn"},
		{"name":"Relentless","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"First time reduced to 0 HP, drop to 1 instead.","cd":"1/encounter"},
	],
	"Panther": [
		{"name":"Pounce","ap":2,"sp":0,"dice":[1,8],"range":1,"conds":["prone"],"desc":"Leap and knock prone.","cd":"1/turn"},
		{"name":"Stealth Hunter","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Advantage on stealth. First attack from hidden deals double damage.","cd":"passive"},
	],
	"Dire Wolf": [
		{"name":"Pack Tactics","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Advantage on attack if ally adjacent to target.","cd":"passive"},
		{"name":"Savage Bite","ap":1,"sp":0,"dice":[2,6],"range":1,"conds":["prone"],"desc":"Powerful jaws — STR save or prone.","cd":"none"},
	],
	"Wyvern": [
		{"name":"Stinger Tail","ap":1,"sp":0,"dice":[2,6],"range":1,"conds":["poisoned"],"desc":"Venomous tail strike.","cd":"none"},
		{"name":"Flyby","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Does not provoke opportunity attacks when flying.","cd":"passive"},
		{"name":"Dive Attack","ap":2,"sp":0,"dice":[3,6],"range":1,"conds":["prone"],"desc":"Dive from height for massive damage.","cd":"1/turn"},
	],
	"Basilisk": [
		{"name":"Petrifying Gaze","ap":1,"sp":2,"dice":[0,0],"range":4,"conds":["restrained"],"desc":"VIT save or begin turning to stone.","cd":"1/turn"},
		{"name":"Venomous Bite","ap":1,"sp":0,"dice":[2,6],"range":1,"conds":["poisoned"],"desc":"Toxic bite.","cd":"none"},
	],
	# ── Generic fallbacks ──
	"Mercenary": [
		{"name":"Tactical Strike","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":[],"desc":"Trained weapon attack.","cd":"none"},
		{"name":"Shield Bash","ap":1,"sp":0,"dice":[1,4],"range":1,"conds":["stunned"],"desc":"Slam with shield — stuns briefly.","cd":"1/encounter"},
	],
	"Cultist": [
		{"name":"Dark Prayer","ap":1,"sp":1,"dice":[1,6],"range":4,"conds":[],"desc":"Necrotic bolt from dark patron.","cd":"none"},
		{"name":"Fanatical Devotion","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Advantage on saves vs frightened and charmed.","cd":"passive"},
		{"name":"Blood Sacrifice","ap":2,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"Lose 1d6 HP to grant ally +2d6 on next attack.","cd":"1/encounter"},
	],
	"Guard": [
		{"name":"Shield Wall","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":[],"desc":"+2 AC until next turn, adjacent ally also gains +1 AC.","cd":"1/turn"},
		{"name":"Arrest","ap":2,"sp":0,"dice":[1,6],"range":1,"conds":["grappled"],"desc":"Attempt to grab and restrain — STR save.","cd":"1/encounter"},
	],
	"Thug": [
		{"name":"Brutal Strike","ap":1,"sp":0,"dice":[1,8],"range":1,"conds":[],"desc":"Heavy melee attack.","cd":"none"},
		{"name":"Intimidate","ap":1,"sp":0,"dice":[0,0],"range":3,"conds":["frightened"],"desc":"INT save or frightened for 1 round.","cd":"1/encounter"},
	],
}

# ── Hand-Crafted Apex Stat Blocks (from GMG) ─────────────────────────────────
# Each entry: {level, stats:[STR,SPD,INT,VIT,DIV], ac, immunities, resistances, abilities}
const APEX_STAT_BLOCKS: Dictionary = {
	"Varnok": {"level":11,"stats":[6,4,2,6,3],"ac":14,
		"immunities":["charm","fear","non-magical physical"],"resistances":["cold","poison"],
		"abilities":[
			{"name":"Multiattack","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":[],"cd":"none"},
			{"name":"Regeneration","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
			{"name":"Soulbrand","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":["cursed"],"cd":"1/turn"},
			{"name":"Moonshadow Pounce","ap":3,"sp":0,"dice":[3,8],"range":6,"conds":[],"cd":"1/turn"},
			{"name":"Alpha's Command","ap":0,"sp":2,"dice":[0,0],"range":10,"conds":["frightened"],"cd":"1/encounter"},
		]},
	"Lady Nyssara": {"level":12,"stats":[4,3,6,5,6],"ac":15,
		"immunities":["charm","sleep","necrotic"],"resistances":["slashing","psychic"],
		"abilities":[
			{"name":"Multiattack","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":[],"cd":"none"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
			{"name":"Eclipse Veil","ap":0,"sp":2,"dice":[0,0],"range":20,"conds":["blinded"],"cd":"1/encounter"},
			{"name":"Bloodborne Dominion","ap":3,"sp":0,"dice":[0,0],"range":6,"conds":["charmed"],"cd":"1/encounter"},
			{"name":"Sanguine Reversal","ap":0,"sp":2,"dice":[2,6],"range":0,"conds":[],"cd":"1/turn"},
			{"name":"Regeneration","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Malgrin": {"level":13,"stats":[2,2,10,4,7],"ac":13,
		"immunities":["necrotic","psychic","charm","sleep"],"resistances":["cold","non-magical physical"],
		"abilities":[
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
			{"name":"Teleport","ap":1,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"1/turn"},
			{"name":"Gravity Shatter","ap":0,"sp":2,"dice":[3,6],"range":10,"conds":["grappled"],"cd":"1/turn"},
			{"name":"Temporal Rift","ap":0,"sp":2,"dice":[0,0],"range":0,"conds":[],"cd":"1/encounter"},
			{"name":"Soulfracture Glyph","ap":2,"sp":0,"dice":[2,8],"range":6,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Temporal Collapse","ap":0,"sp":6,"dice":[0,0],"range":10,"conds":["stunned"],"cd":"1/encounter"},
		]},
	"Sithra": {"level":1,"stats":[1,2,1,1,1],"ac":11,
		"immunities":["disease"],"resistances":["poison"],
		"abilities":[
			{"name":"Venom Pulse","ap":3,"sp":0,"dice":[1,6],"range":2,"conds":["poisoned"],"cd":"1/turn"},
			{"name":"Slitherstep","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Korrak": {"level":3,"stats":[2,2,1,2,1],"ac":12,
		"immunities":["charm"],"resistances":["necrotic","poison"],
		"abilities":[
			{"name":"Packbound Howl","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"1/encounter"},
			{"name":"Boneburst Leap","ap":2,"sp":0,"dice":[1,6],"range":6,"conds":[],"cd":"1/turn"},
			{"name":"Carrion Feast","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Veltraxis": {"level":5,"stats":[4,3,2,3,2],"ac":13,
		"immunities":["fear"],"resistances":["fire","slashing"],
		"abilities":[
			{"name":"Infernal Riposte","ap":1,"sp":0,"dice":[1,6],"range":1,"conds":[],"cd":"1/turn"},
			{"name":"Blazing Dash","ap":0,"sp":0,"dice":[1,4],"range":12,"conds":[],"cd":"1/encounter"},
			{"name":"Ash Veil","ap":2,"sp":0,"dice":[0,0],"range":2,"conds":["blinded"],"cd":"1/encounter"},
		]},
	"Xal'Thuun": {"level":20,"stats":[6,6,10,8,10],"ac":16,
		"immunities":["charm","sleep","fear","necrotic"],"resistances":["psychic","magical"],
		"abilities":[
			{"name":"Dream Consumption","ap":0,"sp":0,"dice":[3,8],"range":10,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Astral Bloom","ap":0,"sp":5,"dice":[4,10],"range":10,"conds":["stunned"],"cd":"1/encounter"},
			{"name":"Mind Fracture","ap":0,"sp":0,"dice":[0,0],"range":10,"conds":["confused"],"cd":"1/encounter"},
			{"name":"Reality Unraveled","ap":0,"sp":10,"dice":[10,10],"range":6,"conds":[],"cd":"1/encounter"},
		]},
	"High Null Sereth": {"level":15,"stats":[1,2,8,4,10],"ac":14,
		"immunities":["psychic","charm","sleep"],"resistances":["necrotic","force"],
		"abilities":[
			{"name":"Null Silence","ap":3,"sp":0,"dice":[0,0],"range":10,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Null Field","ap":0,"sp":6,"dice":[0,0],"range":6,"conds":[],"cd":"1/encounter"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
		]},
	"Veyra's Echo": {"level":15,"stats":[0,3,6,3,9],"ac":13,
		"immunities":["charm","psychic"],"resistances":["radiant","force"],
		"abilities":[
			{"name":"Echo Step","ap":0,"sp":2,"dice":[0,0],"range":0,"conds":[],"cd":"1/turn"},
			{"name":"Fate Redirect","ap":0,"sp":3,"dice":[0,0],"range":10,"conds":[],"cd":"1/turn"},
			{"name":"Prophet's Lament","ap":0,"sp":5,"dice":[0,0],"range":10,"conds":["dazed"],"cd":"1/encounter"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
		]},
	"Korrin of the Forgotten Flame": {"level":15,"stats":[2,3,9,5,8],"ac":13,
		"immunities":["fire","charm"],"resistances":["psychic","cold"],
		"abilities":[
			{"name":"Memory Burn","ap":0,"sp":3,"dice":[2,8],"range":10,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Forgotten Flame","ap":3,"sp":0,"dice":[3,6],"range":6,"conds":["burning"],"cd":"none"},
			{"name":"Pyre of the Past","ap":0,"sp":6,"dice":[4,8],"range":4,"conds":["stunned"],"cd":"1/encounter"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
		]},
	"The Culled": {"level":10,"stats":[3,4,5,4,5],"ac":13,
		"immunities":["charm","fear","psychic"],"resistances":["necrotic","poison"],
		"abilities":[
			{"name":"Mass Surge","ap":3,"sp":0,"dice":[2,6],"range":3,"conds":["prone"],"cd":"1/turn"},
			{"name":"Collective Scream","ap":0,"sp":4,"dice":[0,0],"range":10,"conds":["frightened"],"cd":"1/encounter"},
			{"name":"Swarm Resilience","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Zorin Blackscale": {"level":8,"stats":[2,1,2,5,3],"ac":21,
		"immunities":["charm"],"resistances":["slashing","bludgeoning"],
		"abilities":[
			{"name":"Obsidian Slam","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":["prone"],"cd":"1/turn"},
			{"name":"Retaliation","ap":0,"sp":0,"dice":[1,8],"range":1,"conds":[],"cd":"1/turn"},
			{"name":"Iron Warden","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Thalia Darksong": {"level":5,"stats":[1,3,3,1,2],"ac":12,
		"immunities":[],"resistances":["psychic"],
		"abilities":[
			{"name":"Discordant Verse","ap":0,"sp":2,"dice":[1,6],"range":10,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Shadow Refrain","ap":0,"sp":2,"dice":[0,0],"range":3,"conds":[],"cd":"1/encounter"},
		]},
	"Gorrim Ironfist": {"level":5,"stats":[3,1,2,3,1],"ac":13,
		"immunities":["fear"],"resistances":[],
		"abilities":[
			{"name":"Reckless Charge","ap":2,"sp":0,"dice":[2,6],"range":4,"conds":[],"cd":"1/turn"},
			{"name":"Battering Blow","ap":3,"sp":0,"dice":[2,8],"range":1,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Iron Resolve","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Seraphina Windwalker": {"level":5,"stats":[1,2,2,2,3],"ac":12,
		"immunities":[],"resistances":["thunder"],
		"abilities":[
			{"name":"Wind Slash","ap":2,"sp":0,"dice":[1,6],"range":6,"conds":[],"cd":"none"},
			{"name":"Tailwind Burst","ap":0,"sp":2,"dice":[0,0],"range":6,"conds":[],"cd":"1/encounter"},
			{"name":"Gust Step","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Rurik Stormbringer": {"level":5,"stats":[2,2,2,2,2],"ac":12,
		"immunities":[],"resistances":["lightning","thunder"],
		"abilities":[
			{"name":"Chain Lightning","ap":0,"sp":3,"dice":[1,8],"range":6,"conds":[],"cd":"1/turn"},
			{"name":"Thunderclap","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Storm Surge","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Lyra Moonshadow": {"level":5,"stats":[0,2,4,2,2],"ac":11,
		"immunities":["charm"],"resistances":["psychic"],
		"abilities":[
			{"name":"Mirror Image","ap":0,"sp":2,"dice":[0,0],"range":0,"conds":[],"cd":"1/encounter"},
			{"name":"Moonveil","ap":0,"sp":3,"dice":[0,0],"range":10,"conds":["confused"],"cd":"1/encounter"},
		]},
	"Ilyra": {"level":5,"stats":[0,3,3,2,2],"ac":12,
		"immunities":[],"resistances":["psychic"],
		"abilities":[
			{"name":"Twin Strike","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":[],"cd":"1/turn"},
			{"name":"Mirrored Defense","ap":0,"sp":0,"dice":[0,0],"range":1,"conds":[],"cd":"1/turn"},
		]},
	"Kael": {"level":5,"stats":[0,3,3,2,2],"ac":12,
		"immunities":[],"resistances":["psychic"],
		"abilities":[
			{"name":"Twin Strike","ap":2,"sp":0,"dice":[2,6],"range":1,"conds":[],"cd":"1/turn"},
			{"name":"Oath Bond","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
		]},
	"Morthis the Binder": {"level":5,"stats":[3,1,2,3,2],"ac":13,
		"immunities":[],"resistances":["slashing"],
		"abilities":[
			{"name":"Chain Snare","ap":2,"sp":0,"dice":[0,0],"range":10,"conds":["grappled"],"cd":"1/turn"},
			{"name":"Binding Circle","ap":0,"sp":3,"dice":[0,0],"range":2,"conds":["grappled"],"cd":"1/encounter"},
			{"name":"Drag Down","ap":0,"sp":0,"dice":[1,8],"range":1,"conds":[],"cd":"1/turn"},
		]},
	"Kaelen the Hollow": {"level":5,"stats":[1,3,2,2,3],"ac":12,
		"immunities":[],"resistances":["necrotic"],
		"abilities":[
			{"name":"Vitality Drain","ap":2,"sp":0,"dice":[1,6],"range":1,"conds":[],"cd":"none"},
			{"name":"Shadow Fade","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"1/encounter"},
			{"name":"Hollow Touch","ap":3,"sp":0,"dice":[2,6],"range":1,"conds":["exhaustion"],"cd":"1/turn"},
		]},
	"Nirael of the Glass Veil": {"level":5,"stats":[0,2,4,1,3],"ac":11,
		"immunities":["sleep"],"resistances":["psychic"],
		"abilities":[
			{"name":"Glass Suggestion","ap":0,"sp":2,"dice":[0,0],"range":10,"conds":["charmed"],"cd":"1/encounter"},
			{"name":"Memory Shard","ap":2,"sp":0,"dice":[1,6],"range":6,"conds":["dazed"],"cd":"1/turn"},
			{"name":"Veil of Confusion","ap":0,"sp":3,"dice":[0,0],"range":4,"conds":["confused"],"cd":"1/encounter"},
		]},
}

# ── Hand-Crafted Kaiju Stat Blocks (from GMG) ────────────────────────────────
const KAIJU_STAT_BLOCKS: Dictionary = {
	"Pyroclast": {"level":12,"stats":[8,3,2,8,5],"ac":13,
		"immunities":["fire"],"resistances":["thunder","non-magical physical","ranged","cold","acid"],
		"abilities":[
			{"name":"Magma Breath","ap":4,"sp":0,"dice":[6,6],"range":6,"conds":["burning"],"cd":"1/turn"},
			{"name":"Molten Hide","ap":0,"sp":0,"dice":[1,6],"range":0,"conds":[],"cd":"passive"},
			{"name":"Earthquake","ap":2,"sp":0,"dice":[2,6],"range":6,"conds":["prone"],"cd":"1/turn"},
			{"name":"Regeneration","ap":0,"sp":0,"dice":[2,6],"range":0,"conds":[],"cd":"passive"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
			{"name":"Leap","ap":3,"sp":0,"dice":[3,6],"range":20,"conds":["prone"],"cd":"1/turn"},
			{"name":"Enhanced Explosive Mix","ap":0,"sp":4,"dice":[6,6],"range":6,"conds":["burning"],"cd":"1/encounter"},
		]},
	"Grondar": {"level":13,"stats":[9,6,4,7,3],"ac":16,
		"immunities":["fear","charm"],"resistances":["non-magical physical","bludgeoning","thunder"],
		"abilities":[
			{"name":"Multiattack","ap":2,"sp":0,"dice":[3,10],"range":1,"conds":[],"cd":"none"},
			{"name":"Regeneration","ap":0,"sp":0,"dice":[2,6],"range":0,"conds":[],"cd":"passive"},
			{"name":"Thunderous Roar","ap":3,"sp":2,"dice":[4,8],"range":6,"conds":["stunned"],"cd":"1/encounter"},
			{"name":"Crushing Grip","ap":2,"sp":0,"dice":[2,8],"range":1,"conds":["grappled"],"cd":"1/turn"},
			{"name":"Boulder Throw","ap":2,"sp":0,"dice":[4,10],"range":12,"conds":[],"cd":"1/turn"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
			{"name":"Leap","ap":3,"sp":0,"dice":[3,6],"range":20,"conds":["prone"],"cd":"1/turn"},
		]},
	"Thal'Zuur": {"level":14,"stats":[7,4,6,9,8],"ac":14,
		"immunities":["poison","psychic","charm","fear","disease"],"resistances":["cold","acid","magical"],
		"abilities":[
			{"name":"Tentacle Barrage","ap":3,"sp":0,"dice":[3,8],"range":3,"conds":["poisoned"],"cd":"1/turn"},
			{"name":"Abyssal Howl","ap":3,"sp":2,"dice":[4,6],"range":6,"conds":["frightened"],"cd":"1/encounter"},
			{"name":"Digestive Bloom","ap":2,"sp":2,"dice":[3,6],"range":4,"conds":["poisoned"],"cd":"1/turn"},
			{"name":"Rot Pulse","ap":0,"sp":5,"dice":[6,8],"range":10,"conds":["poisoned"],"cd":"1/encounter"},
			{"name":"Regeneration","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
		]},
	"Ny'Zorrak": {"level":15,"stats":[6,5,10,8,10],"ac":15,
		"immunities":["psychic","poison","charm"],"resistances":["magical","cold","radiant"],
		"abilities":[
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
			{"name":"Regeneration","ap":0,"sp":0,"dice":[2,6],"range":0,"conds":[],"cd":"passive"},
			{"name":"Multiattack","ap":2,"sp":0,"dice":[3,8],"range":3,"conds":[],"cd":"none"},
			{"name":"Mind Rend","ap":3,"sp":2,"dice":[4,8],"range":6,"conds":["confused"],"cd":"1/turn"},
			{"name":"Reality Warp","ap":2,"sp":3,"dice":[0,0],"range":6,"conds":["confused"],"cd":"1/encounter"},
			{"name":"Void Pulse","ap":0,"sp":4,"dice":[0,0],"range":10,"conds":[],"cd":"1/encounter"},
			{"name":"Starfall","ap":4,"sp":3,"dice":[6,10],"range":10,"conds":[],"cd":"1/encounter"},
		]},
	"Mirecoast Sleeper": {"level":14,"stats":[10,3,2,10,4],"ac":12,
		"immunities":["non-magical physical","cold","psychic","prone","stun","fear","charm"],
		"resistances":["thunder","acid"],
		"abilities":[
			{"name":"Tidal Collapse","ap":10,"sp":0,"dice":[8,6],"range":30,"conds":[],"cd":"1/encounter"},
			{"name":"Abyssal Pulse","ap":12,"sp":0,"dice":[6,6],"range":40,"conds":[],"cd":"1/encounter"},
			{"name":"Leviathan Hide","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
			{"name":"Tidal Regeneration","ap":0,"sp":0,"dice":[2,6],"range":0,"conds":[],"cd":"passive"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
		]},
	"Aegis Ultima": {"level":13,"stats":[7,4,6,8,6],"ac":25,
		"immunities":["force","paralysis","charm"],"resistances":["non-magical physical","piercing","slashing","thunder","radiant"],
		"abilities":[
			{"name":"Multiattack","ap":2,"sp":0,"dice":[3,8],"range":1,"conds":[],"cd":"none"},
			{"name":"Arcane Baton Strike","ap":2,"sp":0,"dice":[6,6],"range":1,"conds":["paralysis"],"cd":"1/turn"},
			{"name":"Arcane Cannon","ap":2,"sp":0,"dice":[8,10],"range":30,"conds":[],"cd":"1/turn"},
			{"name":"Disruption Blast","ap":3,"sp":0,"dice":[4,8],"range":20,"conds":["stunned"],"cd":"1/encounter"},
			{"name":"Force Field","ap":2,"sp":0,"dice":[0,0],"range":6,"conds":[],"cd":"1/turn"},
			{"name":"Regeneration","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"passive"},
			{"name":"Legendary Resistance","ap":0,"sp":0,"dice":[0,0],"range":0,"conds":[],"cd":"special"},
		]},
}

# ── Creature Management (Category-Aware) ─────────────────────────────────────

func spawn_creature(cname: String, category: int, level: int) -> int:
	var h: int = _combat_next_creature_id
	_combat_next_creature_id += 1
	var lv: int = maxi(1, level)
	var cat: int = clampi(category, 0, 5)
	var total_pts: int = _creature_stat_points(cat, lv)
	var stats: Array = _creature_distribute_stats(total_pts, cat)
	var str_v: int = int(stats[0])
	var spd_v: int = int(stats[1])
	var vit_v: int = int(stats[3])
	var div_v: int = int(stats[4])
	var hp: int    = _creature_max_hp(cat, lv, vit_v)
	var ap_max: int = _creature_max_ap(cat, lv, str_v)
	var sp_max: int = _creature_max_sp(cat, lv, div_v)
	var ac: int    = _creature_calc_ac(cat, lv, spd_v)
	var spd: int   = _creature_speed_tiles(cat, spd_v)
	var threshold: int = _creature_damage_threshold(cat, lv)
	var abilities: Array = _creature_default_abilities(cat, lv, stats)
	# Check for hand-crafted Apex/Kaiju stat blocks — override formula-based stats
	var cr_immunities: Array = []
	var cr_resistances: Array = []
	var has_handcrafted: bool = false
	var _hc_block: Dictionary = {}
	if APEX_STAT_BLOCKS.has(cname):
		has_handcrafted = true
		_hc_block = APEX_STAT_BLOCKS[cname]
		lv = int(_hc_block["level"])
		stats = _hc_block["stats"].duplicate()
		str_v = int(stats[0]); spd_v = int(stats[1]); vit_v = int(stats[3]); div_v = int(stats[4])
		ac = int(_hc_block["ac"])
		hp = _creature_max_hp(CAT_APEX, lv, vit_v)
		ap_max = _creature_max_ap(CAT_APEX, lv, str_v)
		sp_max = _creature_max_sp(CAT_APEX, lv, div_v)
		spd = _creature_speed_tiles(CAT_APEX, spd_v)
		threshold = _creature_damage_threshold(CAT_APEX, lv)
		abilities = _hc_block["abilities"].duplicate(true)
		cr_immunities = _hc_block.get("immunities", []).duplicate()
		cr_resistances = _hc_block.get("resistances", []).duplicate()
		cat = CAT_APEX
	elif KAIJU_STAT_BLOCKS.has(cname):
		has_handcrafted = true
		_hc_block = KAIJU_STAT_BLOCKS[cname]
		lv = int(_hc_block["level"])
		stats = _hc_block["stats"].duplicate()
		str_v = int(stats[0]); spd_v = int(stats[1]); vit_v = int(stats[3]); div_v = int(stats[4])
		ac = int(_hc_block["ac"])
		hp = _creature_max_hp(CAT_KAIJU, lv, vit_v)
		ap_max = _creature_max_ap(CAT_KAIJU, lv, str_v)
		sp_max = _creature_max_sp(CAT_KAIJU, lv, div_v)
		spd = _creature_speed_tiles(CAT_KAIJU, spd_v)
		threshold = _creature_damage_threshold(CAT_KAIJU, lv)
		abilities = _hc_block["abilities"].duplicate(true)
		cr_immunities = _hc_block.get("immunities", []).duplicate()
		cr_resistances = _hc_block.get("resistances", []).duplicate()
		cat = CAT_KAIJU

	# Append GMG-specific abilities if the creature name matches (non-handcrafted only)
	if not has_handcrafted and GMG_MONSTER_ABILITIES.has(cname):
		for ab in GMG_MONSTER_ABILITIES[cname]:
			abilities.append(ab)
	_combat_creatures[h] = {
		"id":          "creature_%d" % h,
		"name":        cname,
		"handle":      h,
		"category":    cat,
		"level":       lv,
		"stats":       stats,
		"hp":          hp,
		"max_hp":      hp,
		"ap":          ap_max,
		"max_ap":      ap_max,
		"sp":          sp_max,
		"max_sp":      sp_max,
		"ac":          ac,
		"atk_bonus":   str_v + lv / 3,
		"dmg_die":     6 if cat <= 1 else (8 if cat <= 3 else 10),
		"dmg_bonus":   lv / 3,
		"speed":       spd,
		"threshold":   threshold,
		"is_dead":     false,
		"abilities":   abilities,
		"ability_cooldowns": {},  # tracks "1/encounter" etc uses
		"immunities":  cr_immunities,
		"resistances": cr_resistances,
		"inventory":   _generate_creature_loot(lv),
		"looted":      false,
		"legendary_uses": (vit_v if cat >= 4 else 0),  # legendary resistance uses per SR
		"morale":      4,        # for mobs: 4=full, 0=routed
	}
	return h

func set_creature_stats(handle: int, str_: int, spd: int, intel: int, vit: int, div: int) -> void:
	if _combat_creatures.has(handle):
		var cr: Dictionary = _combat_creatures[handle]
		cr["stats"] = [str_, spd, intel, vit, div]
		cr["speed"] = _creature_speed_tiles(int(cr.get("category", 3)), spd)
		cr["max_hp"] = _creature_max_hp(int(cr["category"]), int(cr["level"]), vit)
		cr["hp"] = mini(int(cr["hp"]), cr["max_hp"])
		cr["max_ap"] = _creature_max_ap(int(cr["category"]), int(cr["level"]), str_)
		cr["max_sp"] = _creature_max_sp(int(cr["category"]), int(cr["level"]), div)
		cr["ac"] = _creature_calc_ac(int(cr["category"]), int(cr["level"]), spd)

func set_creature_feat(handle: int, feat_name: String, tier: int) -> void:
	if _combat_creatures.has(handle):
		if not _combat_creatures[handle].has("feats"):
			_combat_creatures[handle]["feats"] = {}
		_combat_creatures[handle]["feats"][feat_name] = tier

func get_creature_name(handle: int) -> String:
	if not _combat_creatures.has(handle): return "Unknown"
	return str(_combat_creatures[handle]["name"])

func get_creature_id(handle: int) -> String:
	if not _combat_creatures.has(handle): return ""
	return str(_combat_creatures[handle]["id"])

func get_creature_hp(handle: int) -> int:
	if not _combat_creatures.has(handle): return 0
	return int(_combat_creatures[handle]["hp"])

func get_creature_max_hp(handle: int) -> int:
	if not _combat_creatures.has(handle): return 0
	return int(_combat_creatures[handle]["max_hp"])

func get_creature_ap(handle: int) -> int:
	if not _combat_creatures.has(handle): return 0
	return int(_combat_creatures[handle]["ap"])

func get_creature_max_ap(handle: int) -> int:
	if not _combat_creatures.has(handle): return 0
	return int(_combat_creatures[handle]["max_ap"])

func get_creature_movement_speed(handle: int) -> int:
	if not _combat_creatures.has(handle): return 6
	return int(_combat_creatures[handle].get("speed", 6))

func get_creature_threshold(handle: int) -> int:
	if not _combat_creatures.has(handle): return 0
	return int(_combat_creatures[handle].get("threshold", 0))

func get_creature_ac(handle: int) -> int:
	if not _combat_creatures.has(handle): return 10
	return int(_combat_creatures[handle]["ac"])

func get_creature_conditions(handle: int) -> PackedStringArray:
	return PackedStringArray()

# ── Encounter Budget Builder (GMG) ────────────────────────────────────────────
# difficulty: 0=Easy, 1=Medium, 2=Hard, 3=Deadly
# Returns Array of {name, category, level} dicts for each enemy to spawn.

func _build_encounter(party_level: int, difficulty: int) -> Array:
	var budget_mult: Array = [0.75, 1.0, 1.5, 2.0]
	var extra_adds: Array  = [1, 2, 2, 3]
	var diff: int = clampi(difficulty, 0, 3)
	var budget: int = maxi(1, int(float(party_level) * budget_mult[diff]))
	var result: Array = []

	# Spend budget on creatures (max level 5 per creature, or party_level, whichever is lower)
	while budget > 0:
		var max_lv: int = mini(budget, mini(party_level, 5))
		var cr_lv: int  = randi_range(1, maxi(1, max_lv))
		var cr_cat: int = _pick_creature_category(party_level)
		var cr_name: String = _pick_creature_name(cr_cat, cr_lv)
		result.append({"name": cr_name, "category": cr_cat, "level": cr_lv})
		budget -= cr_lv

	# Always add extra level 1 creatures (chaff)
	for _j in range(extra_adds[diff]):
		var chaff_cat: int = _pick_creature_category(party_level)
		var chaff_name: String = _pick_creature_name(chaff_cat, 1)
		result.append({"name": chaff_name, "category": chaff_cat, "level": 1})

	# Cap total enemies at 12 (map space constraint)
	if result.size() > 12:
		result.resize(12)
	return result

## Pick creature category based on party level (GMG distribution tables).
func _pick_creature_category(party_level: int) -> int:
	var roll: int = randi_range(1, 100)
	if party_level <= 3:
		if roll <= 70: return CAT_ANIMAL
		if roll <= 90: return CAT_VILLAGER
		return CAT_MONSTER
	elif party_level <= 6:
		if roll <= 30: return CAT_ANIMAL
		if roll <= 60: return CAT_VILLAGER
		return CAT_MONSTER
	elif party_level <= 10:
		if roll <= 10: return CAT_ANIMAL
		if roll <= 30: return CAT_VILLAGER
		return CAT_MONSTER
	elif party_level <= 15:
		if roll <= 10: return CAT_VILLAGER
		if roll <= 90: return CAT_MONSTER
		return CAT_APEX
	else:
		if roll <= 60: return CAT_MONSTER
		if roll <= 90: return CAT_APEX
		return CAT_KAIJU

## Pick a creature name from the category pool.
## For Apex/Kaiju, picks from hand-crafted stat block names so they get unique abilities.
func _pick_creature_name(category: int, _level: int) -> String:
	match category:
		0: return CREATURE_NAMES_ANIMAL[randi() % CREATURE_NAMES_ANIMAL.size()]
		1: return CREATURE_NAMES_VILLAGER[randi() % CREATURE_NAMES_VILLAGER.size()]
		4:  # CAT_APEX — pick from hand-crafted Apex stat blocks
			var apex_names: Array = APEX_STAT_BLOCKS.keys()
			return str(apex_names[randi() % apex_names.size()])
		5:  # CAT_KAIJU — pick from hand-crafted Kaiju stat blocks
			var kaiju_names: Array = KAIJU_STAT_BLOCKS.keys()
			return str(kaiju_names[randi() % kaiju_names.size()])
		_: return CREATURE_NAMES_MONSTER[randi() % CREATURE_NAMES_MONSTER.size()]

# ── Summon Framework ─────────────────────────────────────────────────────────
# Spawns a friendly creature into the active dungeon near the caster.

func _dung_spawn_summon(caster_id: String, creature_name: String, creature_level: int,
		duration_rounds: int, category: int) -> Dictionary:
	var caster = _dung_find(caster_id)
	if caster == null: return {}
	# Search expanding ring for empty floor tile
	var spawn_x: int = -1
	var spawn_y: int = -1
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius: continue
				var nx: int = int(caster["x"]) + dx
				var ny: int = int(caster["y"]) + dy
				if _dung_tile(nx, ny) == TILE_FLOOR and not _dung_occupied(nx, ny):
					spawn_x = nx; spawn_y = ny
					break
			if spawn_x >= 0: break
		if spawn_x >= 0: break
	if spawn_x < 0: return {}  # no valid tile found

	var lv: int = maxi(1, creature_level)
	var cat: int = clampi(category, 0, 5)
	var total_pts: int = _creature_stat_points(cat, lv)
	var stats: Array = _creature_distribute_stats(total_pts, cat)
	var s_str: int = int(stats[0])
	var s_spd: int = int(stats[1])
	var s_vit: int = int(stats[3])
	var s_div: int = int(stats[4])
	var shp: int    = _creature_max_hp(cat, lv, s_vit)
	var sap: int    = _creature_max_ap(cat, lv, s_str)
	var ssp: int    = _creature_max_sp(cat, lv, s_div)
	var sac: int    = _creature_calc_ac(cat, lv, s_spd)
	var sspd: int   = _creature_speed_tiles(cat, s_spd)
	var abilities: Array = _creature_default_abilities(cat, lv, stats)
	if GMG_MONSTER_ABILITIES.has(creature_name):
		for ab in GMG_MONSTER_ABILITIES[creature_name]:
			abilities.append(ab)
	var s_weapon: String = "Bite" if cat == CAT_ANIMAL else "Shadow Claw"
	var summon_id: String = "summon_%d_%d" % [randi() % 9999, _dungeon_entities.size()]
	var ent: Dictionary = {
		"id":           summon_id,
		"name":         creature_name,
		"handle":       -1,
		"lineage_name": "Summon",
		"x": spawn_x, "y": spawn_y, "z": 0,
		"is_player":   true,
		"is_friendly": true,
		"is_dead":     false,
		"is_flying":   false,
		"is_summon":   true,
		"summon_caster_id": caster_id,
		"summon_rounds_left": duration_rounds,  # -1 = permanent until killed
		"hp":    shp,  "max_hp": shp,
		"ap":    sap,  "max_ap": sap,
		"sp":    ssp,  "max_sp": ssp,
		"ac":    sac,
		"speed": sspd,
		"ap_spent":  0,
		"actions_taken": 0,
		"move_used": 0,
		"hit_bonus_buff": 0,
		"hit_penalty":    0,
		"equipped_weapon": s_weapon,
		"equipped_armor":  "None",
		"equipped_shield": "None",
		"equipped_light":  "None",
		"conditions":    [],
		"abilities":     abilities,
		"ability_cooldowns": {},
		"stats":         stats,
		"category":      cat,
		"creature_level": lv,
	}
	_dungeon_entities.append(ent)
	# Add to player queue so the player can control this summon
	if _dungeon_is_player_phase:
		_dungeon_player_queue.append(summon_id)
	return ent

## Cast Summon Creature spell — creates a custom construct from player-specified build.
## build dict keys: "stats" (Array[5]), "feats" (Dictionary name→tier), "abilities" (Array[String]),
##                  "creature_name" (String), "total_sp" (int — SP spent on build)
func _dung_cast_summon_creature(caster: Dictionary, spell_name: String, build: Dictionary, ap_cost: int) -> Dictionary:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return _dung_fail("No character data.")
	var caster_level: int = int(_chars[ch].get("level", 1))
	var caster_feats: Dictionary = _chars[ch].get("feats", {})

	# Calculate total SP cost: 2 base + 1 per stat point + feat tier costs + ability costs
	var custom_stats: Array = build.get("stats", [0,0,0,0,0])
	var custom_feats: Dictionary = build.get("feats", {})
	var custom_abilities: Array = build.get("abilities", [])
	var creature_name: String = build.get("creature_name", "Construct")

	var stat_total: int = 0
	for st in custom_stats: stat_total += int(st)
	var feat_cost: int = 0
	for fn in custom_feats:
		feat_cost += int(custom_feats[fn])  # tier of each feat = SP cost
	var ability_cost: int = 0
	for ab_name in custom_abilities:
		ability_cost += _summon_ability_sp_cost(ab_name)

	var spell_data: Dictionary = _SPELL_DB.get(spell_name, {})
	var base_sp: int = int(spell_data.get("sc", 2))  # default 2 SP base
	if spell_name == "Animate Undead" and base_sp < 3: base_sp = 3
	var total_sp: int = base_sp + stat_total + feat_cost + ability_cost

	# Check caster has enough SP
	if int(caster["sp"]) < total_sp:
		return _dung_fail("Not enough SP! Need %d (%d base + %d stats + %d feats + %d abilities), have %d." % [
			total_sp, base_sp, stat_total, feat_cost, ability_cost, int(caster["sp"])])

	# Validate feat tiers: can only give feats from tiers the caster has access to
	var caster_max_tier: int = 1
	for feat_name in caster_feats:
		caster_max_tier = maxi(caster_max_tier, int(caster_feats[feat_name]))
	for fn in custom_feats:
		if int(custom_feats[fn]) > caster_max_tier:
			return _dung_fail("Cannot give Tier %d feat '%s' — your highest tier is %d." % [
				int(custom_feats[fn]), fn, caster_max_tier])

	# Validate ability tiers
	for ab_name in custom_abilities:
		var ab_tier: int = _summon_ability_tier(ab_name)
		if ab_tier > caster_max_tier:
			return _dung_fail("Ability '%s' (Tier %d) exceeds your max tier %d." % [ab_name, ab_tier, caster_max_tier])

	# Deduct SP and AP
	caster["ap_spent"] += ap_cost
	caster["sp"] = maxi(0, int(caster["sp"]) - total_sp)
	if ch >= 0 and _chars.has(ch): _chars[ch]["sp"] = caster["sp"]

	# Create the summon entity using the custom stats
	var s_str: int = int(custom_stats[0])
	var s_spd: int = int(custom_stats[1])
	var s_int: int = int(custom_stats[2])
	var s_vit: int = int(custom_stats[3])
	var s_div: int = int(custom_stats[4])

	# Calculate derived stats from the raw stat points
	var s_hp: int  = maxi(1, 1 + s_vit * 2 + stat_total)  # HP scales with VIT and total investment
	var s_ap: int  = maxi(2, 2 + s_str)
	var s_sp: int  = maxi(0, s_div * 2)
	var s_ac: int  = 10 + s_spd
	var s_speed: int = maxi(2, 2 + s_spd)
	var dur: int = int(spell_data.get("dur", 100))  # default 100 rounds
	if dur <= 0: dur = 100  # fallback for instant-duration summons

	# Find spawn tile near caster
	var spawn_x: int = -1; var spawn_y: int = -1
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius: continue
				var nx: int = int(caster["x"]) + dx
				var ny: int = int(caster["y"]) + dy
				if _dung_tile(nx, ny) == TILE_FLOOR and not _dung_occupied(nx, ny):
					spawn_x = nx; spawn_y = ny
					break
			if spawn_x >= 0: break
		if spawn_x >= 0: break
	if spawn_x < 0: return _dung_fail("No space to summon creature.")

	# Build abilities list
	var abilities: Array = []
	# Default melee attack
	abilities.append({"name":"Strike","ap":1,"sp":0,"dice":[1,6],"range":1,"special":"","cooldown":"",
		"desc":"Basic melee attack."})
	# Add custom abilities from monster table
	for ab_name in custom_abilities:
		var ab: Dictionary = _get_monster_ability(ab_name)
		if not ab.is_empty():
			abilities.append(ab)

	var summon_id: String = "summon_%d_%d" % [randi() % 9999, _dungeon_entities.size()]
	var ent: Dictionary = {
		"id":           summon_id,
		"name":         creature_name,
		"handle":       -1,
		"lineage_name": "Summon",
		"x": spawn_x, "y": spawn_y, "z": 0,
		"is_player":   true,
		"is_friendly": true,
		"is_dead":     false,
		"is_flying":   false,
		"is_summon":   true,
		"summon_caster_id": str(caster["id"]),
		"summon_rounds_left": dur,
		"hp":    s_hp,  "max_hp": s_hp,
		"ap":    s_ap,  "max_ap": s_ap,
		"sp":    s_sp,  "max_sp": s_sp,
		"ac":    s_ac,
		"speed": s_speed,
		"ap_spent":  0,
		"actions_taken": 0,
		"move_used": 0,
		"hit_bonus_buff": 0,
		"hit_penalty":    0,
		"equipped_weapon": "Strike",
		"equipped_armor":  "None",
		"equipped_shield": "None",
		"equipped_light":  "None",
		"conditions":    [],
		"abilities":     abilities,
		"ability_cooldowns": {},
		"stats":         custom_stats.duplicate(),
		"category":      CAT_MONSTER,
		"creature_level": maxi(1, stat_total / 3),
		"summon_feats":  custom_feats.duplicate(),  # store for reference
	}
	_dungeon_entities.append(ent)
	# Add to player queue so the player can control this summon
	if _dungeon_is_player_phase:
		_dungeon_player_queue.append(summon_id)

	return _dung_ok("%s summons %s at (%d, %d)! [%d SP spent, %d rounds]" % [
		caster["name"], creature_name, spawn_x, spawn_y, total_sp, dur], ap_cost, total_sp)

## Cast Create Construct spell — creates inanimate constructs (equipment or structures).
## build dict keys: "mode" ("equipment"|"structure"),
##   Equipment: "weapon_idx" (0-3), "armor_idx" (0-3), "shield_idx" (0-2), "trr" (0-10)
##   Structure: "struct_tier" (1-5)
func _dung_cast_create_construct(caster: Dictionary, spell_name: String, build: Dictionary, ap_cost: int) -> Dictionary:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return _dung_fail("No character data.")

	var spell_data: Dictionary = _SPELL_DB.get(spell_name, {})
	var base_sp: int = int(spell_data.get("sc", 2))
	var dur: int = int(spell_data.get("dur", 100))
	if dur <= 0: dur = 100

	var mode: String = str(build.get("mode", "equipment"))
	var construct_sp: int = 0
	var log_parts: Array = []

	if mode == "structure":
		var tier: int = int(build.get("struct_tier", 1))
		construct_sp = int(pow(2.0, float(tier)))
		var total_sp: int = base_sp + construct_sp
		if int(caster["sp"]) < total_sp:
			return _dung_fail("Not enough SP! Need %d, have %d." % [total_sp, int(caster["sp"])])

		# Deduct SP and AP
		caster["ap_spent"] += ap_cost
		caster["sp"] = maxi(0, int(caster["sp"]) - total_sp)
		if ch >= 0 and _chars.has(ch): _chars[ch]["sp"] = caster["sp"]

		# Compute construct stats
		var c_hp: int = construct_sp * 3
		var c_ac: int = 10 + mini(construct_sp, 10)
		var c_dt: int = mini(construct_sp, 10)
		var tile_size: int = tier  # 1 tile per 5ft increment

		# Find spawn tile near caster
		var spawn_x: int = -1; var spawn_y: int = -1
		for radius in range(1, 6):
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if abs(dx) != radius and abs(dy) != radius: continue
					var nx: int = int(caster["x"]) + dx
					var ny: int = int(caster["y"]) + dy
					if _dung_tile(nx, ny) == TILE_FLOOR and not _dung_occupied(nx, ny):
						spawn_x = nx; spawn_y = ny
						break
				if spawn_x >= 0: break
			if spawn_x >= 0: break
		if spawn_x < 0: return _dung_fail("No space to place construct.")

		# Place as destructible entity (immobile, non-player, non-enemy)
		var struct_id: String = "construct_%d_%d" % [randi() % 9999, _dungeon_entities.size()]
		var struct_ent: Dictionary = {
			"id": struct_id,
			"name": "Construct Wall",
			"handle": -1,
			"lineage_name": "Construct",
			"x": spawn_x, "y": spawn_y, "z": 0,
			"is_player": false,
			"is_friendly": true,
			"is_dead": false,
			"is_flying": false,
			"is_summon": true,
			"is_construct": true,
			"construct_caster_id": str(caster["id"]),
			"construct_spell": spell_name,
			"summon_caster_id": str(caster["id"]),
			"summon_rounds_left": dur,
			"hp": c_hp, "max_hp": c_hp,
			"ap": 0, "max_ap": 0,
			"sp": 0, "max_sp": 0,
			"ac": c_ac,
			"threshold": c_dt,
			"speed": 0,
			"ap_spent": 0,
			"move_used": 0,
			"equipped_weapon": "None",
			"equipped_armor": "None",
			"equipped_shield": "None",
			"equipped_light": "None",
			"conditions": [],
			"abilities": [],
			"ability_cooldowns": {},
			"stats": [0, 0, 0, 0, 0],
			"category": CAT_MONSTER,
			"creature_level": 0,
			"tile_size": tile_size,
		}
		_dungeon_entities.append(struct_ent)

		# Track for dismiss/recall
		var constructs: Array = caster.get("_active_constructs", [])
		constructs.append({"id": struct_id, "type": "structure", "spell": spell_name, "dur": dur})
		caster["_active_constructs"] = constructs

		return _dung_ok("%s creates a Construct Wall at (%d,%d)! [%d SP, HP %d, AC %d, DT %d, %d rounds]" % [
			caster["name"], spawn_x, spawn_y, total_sp, c_hp, c_ac, c_dt, dur], ap_cost, total_sp)

	# ── Equipment mode ──
	var w_idx: int = int(build.get("weapon_idx", 0))
	var a_idx: int = int(build.get("armor_idx", 0))
	var s_idx: int = int(build.get("shield_idx", 0))
	var trr: int = int(build.get("trr", 0))

	var w_cost: int = [0, 2, 3, 4][clampi(w_idx, 0, 3)]
	var a_cost: int = [0, 2, 3, 4][clampi(a_idx, 0, 3)]
	var s_cost: int = [0, 1, 2][clampi(s_idx, 0, 2)]
	var trr_cost: int = trr
	var equip_raw: int = w_cost + a_cost + s_cost + trr_cost

	# Count items for set discount
	var item_count: int = 0
	if w_idx > 0: item_count += 1
	if a_idx > 0: item_count += 1
	if s_idx > 0: item_count += 1
	var discount: int = mini(item_count, 3) if item_count >= 2 else 0
	var equip_sp: int = maxi(1, equip_raw - discount)
	var total_sp: int = base_sp + equip_sp

	if int(caster["sp"]) < total_sp:
		return _dung_fail("Not enough SP! Need %d, have %d." % [total_sp, int(caster["sp"])])

	if equip_raw == 0:
		return _dung_fail("Select at least one piece of equipment to construct.")

	# Deduct SP and AP
	caster["ap_spent"] += ap_cost
	caster["sp"] = maxi(0, int(caster["sp"]) - total_sp)
	if ch >= 0 and _chars.has(ch): _chars[ch]["sp"] = caster["sp"]

	# Construct shared stats
	var c_hp: int = equip_sp * 3
	var c_ac: int = 10 + mini(equip_sp, 10)
	var c_dt: int = mini(equip_sp, 10)

	# Build construct metadata to track for dismiss/reform
	var construct_id: String = "cset_%d_%d" % [randi() % 9999, ch]
	var construct_meta: Dictionary = {
		"id": construct_id,
		"type": "equipment",
		"spell": spell_name,
		"dur_left": dur,
		"hp": c_hp, "max_hp": c_hp,
		"ac": c_ac, "dt": c_dt,
		"items": [],
		"dismissed": false,
		"destroyed": false,
	}

	# Add items to inventory and auto-equip
	var weapon_names: Array = ["", "Construct Light Weapon", "Construct Martial Weapon", "Construct Heavy Weapon"]
	var armor_names: Array = ["", "Construct Light Armor", "Construct Medium Armor", "Construct Heavy Armor"]
	var shield_names: Array = ["", "Construct Shield", "Construct Tower Shield"]

	if w_idx > 0:
		var w_name: String = weapon_names[w_idx]
		add_item_to_inventory(ch, w_name)
		equip_item(ch, w_name)
		construct_meta["items"].append(w_name)
		log_parts.append(w_name)
	if a_idx > 0:
		var a_name: String = armor_names[a_idx]
		add_item_to_inventory(ch, a_name)
		equip_item(ch, a_name)
		construct_meta["items"].append(a_name)
		log_parts.append(a_name)
	if s_idx > 0:
		var s_name: String = shield_names[s_idx]
		add_item_to_inventory(ch, s_name)
		equip_item(ch, s_name)
		construct_meta["items"].append(s_name)
		log_parts.append(s_name)
	if trr > 0:
		# TRR is stored as a character flag rather than an item
		var existing_trr: int = int(_chars[ch].get("construct_trr", 0))
		_chars[ch]["construct_trr"] = existing_trr + trr
		construct_meta["trr"] = trr
		log_parts.append("TRR +%d" % trr)

	# Sync equipment to dungeon entity
	for ent in _dungeon_entities:
		if int(ent.get("handle", -1)) == ch and bool(ent["is_player"]):
			ent["equipped_weapon"] = _chars[ch].get("weapon", ent.get("equipped_weapon", "Unarmed"))
			ent["equipped_armor"]  = _chars[ch].get("armor", ent.get("equipped_armor", "None"))
			ent["equipped_shield"] = _chars[ch].get("shield", ent.get("equipped_shield", "None"))
			ent["ac"] = _compute_ac(ch)
			break

	# Track construct set on caster
	var constructs: Array = caster.get("_active_constructs", [])
	constructs.append(construct_meta)
	caster["_active_constructs"] = constructs

	var disc_note: String = " (set discount -%d)" % discount if discount > 0 else ""
	return _dung_ok("%s constructs %s%s! [%d SP, HP %d AC %d DT %d, %d rounds]" % [
		caster["name"], ", ".join(log_parts), disc_note, total_sp, c_hp, c_ac, c_dt, dur], ap_cost, total_sp)

## Dismiss a construct to pocket dimension (free action).
func _dung_dismiss_construct(ent: Dictionary, construct_id: String) -> Dictionary:
	var constructs: Array = ent.get("_active_constructs", [])
	for ci in range(constructs.size()):
		var cm: Dictionary = constructs[ci]
		if str(cm.get("id", "")) == construct_id:
			cm["dismissed"] = true
			if str(cm.get("type", "")) == "structure":
				# Remove structure entity from map
				var struct_ent = _dung_find(construct_id)
				if struct_ent != null:
					struct_ent["is_dead"] = true
					struct_ent["hp"] = 0
			else:
				# Remove equipment items from inventory
				var ch: int = int(ent.get("handle", -1))
				if ch >= 0 and _chars.has(ch):
					for item_name in cm.get("items", []):
						remove_item_from_inventory(ch, item_name)
					# Remove TRR if applicable
					if cm.has("trr"):
						_chars[ch]["construct_trr"] = maxi(0, int(_chars[ch].get("construct_trr", 0)) - int(cm["trr"]))
					# Sync equipment
					for dent in _dungeon_entities:
						if int(dent.get("handle", -1)) == ch and bool(dent["is_player"]):
							dent["equipped_weapon"] = _chars[ch].get("weapon", "Unarmed")
							dent["equipped_armor"] = _chars[ch].get("armor", "None")
							dent["equipped_shield"] = _chars[ch].get("shield", "None")
							dent["ac"] = _compute_ac(ch)
							break
			constructs[ci] = cm
			ent["_active_constructs"] = constructs
			return _dung_ok("%s dismisses construct to pocket dimension." % ent["name"], 0, 0)
	return _dung_fail("Construct not found.")

## Recall a construct from pocket dimension (costs AP).
func _dung_recall_construct(ent: Dictionary, construct_id: String) -> Dictionary:
	var constructs: Array = ent.get("_active_constructs", [])
	for ci in range(constructs.size()):
		var cm: Dictionary = constructs[ci]
		if str(cm.get("id", "")) == construct_id and bool(cm.get("dismissed", false)):
			cm["dismissed"] = false
			if str(cm.get("type", "")) == "structure":
				# Re-spawn structure entity near caster
				var spawn_x: int = -1; var spawn_y: int = -1
				for radius in range(1, 6):
					for dx in range(-radius, radius + 1):
						for dy in range(-radius, radius + 1):
							if abs(dx) != radius and abs(dy) != radius: continue
							var nx: int = int(ent["x"]) + dx
							var ny: int = int(ent["y"]) + dy
							if _dung_tile(nx, ny) == TILE_FLOOR and not _dung_occupied(nx, ny):
								spawn_x = nx; spawn_y = ny
								break
						if spawn_x >= 0: break
					if spawn_x >= 0: break
				if spawn_x < 0: return _dung_fail("No space to recall structure.")
				# Revive or create structure entity
				var struct_ent = _dung_find(construct_id)
				if struct_ent != null:
					struct_ent["is_dead"] = false
					struct_ent["hp"] = int(cm.get("max_hp", cm.get("hp", 6)))
					struct_ent["x"] = spawn_x
					struct_ent["y"] = spawn_y
				else:
					# Create new entity
					var c_hp: int = int(cm.get("max_hp", cm.get("hp", 6)))
					var s_ent: Dictionary = {
						"id": construct_id, "name": "Construct Wall", "handle": -1,
						"lineage_name": "Construct", "x": spawn_x, "y": spawn_y, "z": 0,
						"is_player": false, "is_friendly": true, "is_dead": false,
						"is_flying": false, "is_summon": true, "is_construct": true,
						"construct_caster_id": str(ent["id"]),
						"summon_caster_id": str(ent["id"]),
						"summon_rounds_left": int(cm.get("dur", 100)),
						"hp": c_hp, "max_hp": c_hp,
						"ap": 0, "max_ap": 0, "sp": 0, "max_sp": 0,
						"ac": int(cm.get("ac", 10)), "threshold": int(cm.get("dt", 0)),
						"speed": 0, "ap_spent": 0, "move_used": 0,
						"equipped_weapon": "None", "equipped_armor": "None",
						"equipped_shield": "None", "equipped_light": "None",
						"conditions": [], "abilities": [], "ability_cooldowns": {},
						"stats": [0,0,0,0,0], "category": CAT_MONSTER, "creature_level": 0,
					}
					_dungeon_entities.append(s_ent)
			else:
				# Re-add equipment items to inventory and equip
				var ch: int = int(ent.get("handle", -1))
				if ch >= 0 and _chars.has(ch):
					for item_name in cm.get("items", []):
						add_item_to_inventory(ch, item_name)
						equip_item(ch, item_name)
					if cm.has("trr"):
						_chars[ch]["construct_trr"] = int(_chars[ch].get("construct_trr", 0)) + int(cm["trr"])
					for dent in _dungeon_entities:
						if int(dent.get("handle", -1)) == ch and bool(dent["is_player"]):
							dent["equipped_weapon"] = _chars[ch].get("weapon", "Unarmed")
							dent["equipped_armor"] = _chars[ch].get("armor", "None")
							dent["equipped_shield"] = _chars[ch].get("shield", "None")
							dent["ac"] = _compute_ac(ch)
							break
			constructs[ci] = cm
			ent["_active_constructs"] = constructs
			return _dung_ok("%s recalls construct from pocket dimension!" % ent["name"], 1, 0)
	return _dung_fail("Construct not found or not dismissed.")

## Reform a destroyed construct while spell is still active (costs AP).
func _dung_reform_construct(ent: Dictionary, construct_id: String) -> Dictionary:
	var constructs: Array = ent.get("_active_constructs", [])
	for ci in range(constructs.size()):
		var cm: Dictionary = constructs[ci]
		if str(cm.get("id", "")) == construct_id and bool(cm.get("destroyed", false)):
			cm["destroyed"] = false
			cm["dismissed"] = false
			cm["hp"] = int(cm.get("max_hp", 6))
			if str(cm.get("type", "")) == "structure":
				# Find spawn tile and place fresh structure
				var spawn_x: int = -1; var spawn_y: int = -1
				for radius in range(1, 6):
					for dx in range(-radius, radius + 1):
						for dy in range(-radius, radius + 1):
							if abs(dx) != radius and abs(dy) != radius: continue
							var nx: int = int(ent["x"]) + dx
							var ny: int = int(ent["y"]) + dy
							if _dung_tile(nx, ny) == TILE_FLOOR and not _dung_occupied(nx, ny):
								spawn_x = nx; spawn_y = ny
								break
						if spawn_x >= 0: break
					if spawn_x >= 0: break
				if spawn_x < 0: return _dung_fail("No space to reform structure.")
				var struct_ent = _dung_find(construct_id)
				if struct_ent != null:
					struct_ent["is_dead"] = false
					struct_ent["hp"] = int(cm["max_hp"])
					struct_ent["x"] = spawn_x; struct_ent["y"] = spawn_y
			else:
				# Re-add equipment
				var ch: int = int(ent.get("handle", -1))
				if ch >= 0 and _chars.has(ch):
					for item_name in cm.get("items", []):
						add_item_to_inventory(ch, item_name)
						equip_item(ch, item_name)
					if cm.has("trr"):
						_chars[ch]["construct_trr"] = int(_chars[ch].get("construct_trr", 0)) + int(cm["trr"])
					for dent in _dungeon_entities:
						if int(dent.get("handle", -1)) == ch and bool(dent["is_player"]):
							dent["equipped_weapon"] = _chars[ch].get("weapon", "Unarmed")
							dent["equipped_armor"] = _chars[ch].get("armor", "None")
							dent["equipped_shield"] = _chars[ch].get("shield", "None")
							dent["ac"] = _compute_ac(ch)
							break
			constructs[ci] = cm
			ent["_active_constructs"] = constructs
			return _dung_ok("%s reforms the construct!" % ent["name"], 1, 0)
	return _dung_fail("Construct not found or not destroyed.")

## Look up a monster ability's SP cost for summon creature builder.
func _summon_ability_sp_cost(ability_name: String) -> int:
	for creature_name in GMG_MONSTER_ABILITIES:
		for ab in GMG_MONSTER_ABILITIES[creature_name]:
			if str(ab.get("name", "")) == ability_name:
				return maxi(1, int(ab.get("sp", 0)) + int(ab.get("ap", 1)))
	return 1  # default 1 SP if not found

## Look up a monster ability's tier (based on dice/power level) for tier restriction.
func _summon_ability_tier(ability_name: String) -> int:
	for creature_name in GMG_MONSTER_ABILITIES:
		for ab in GMG_MONSTER_ABILITIES[creature_name]:
			if str(ab.get("name", "")) == ability_name:
				var dice: Array = ab.get("dice", [1, 6])
				var total_dice: int = int(dice[0]) * int(dice[1])
				if total_dice >= 30: return 4
				if total_dice >= 16: return 3
				if total_dice >= 8: return 2
				return 1
	return 1

## Get a monster ability dict by name from the GMG table.
func _get_monster_ability(ability_name: String) -> Dictionary:
	for creature_name in GMG_MONSTER_ABILITIES:
		for ab in GMG_MONSTER_ABILITIES[creature_name]:
			if str(ab.get("name", "")) == ability_name:
				return ab.duplicate()
	return {}

## Returns all available monster abilities (for the creature builder UI).
func get_summon_ability_catalog() -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for creature_name in GMG_MONSTER_ABILITIES:
		for ab in GMG_MONSTER_ABILITIES[creature_name]:
			var nm: String = str(ab.get("name", ""))
			if nm != "" and not seen.has(nm):
				seen[nm] = true
				var entry: Dictionary = ab.duplicate()
				entry["_sp_cost"] = _summon_ability_sp_cost(nm)
				entry["_tier"]    = _summon_ability_tier(nm)
				result.append(entry)
	result.sort_custom(func(a, b): return int(a["_tier"]) < int(b["_tier"]))
	return result

## Tick summon durations — called at end of each round. Removes expired summons.
func _dung_tick_summons() -> Array:
	var expired_logs: Array = []
	for ent in _dungeon_entities:
		if not bool(ent.get("is_summon", false)): continue
		if bool(ent.get("is_dead", false)):
			# If an inhabited minion dies, return consciousness to caster
			if bool(ent.get("_mm_inhabited", false)):
				var orig_id: String = str(ent.get("_mm_original_caster_id", ""))
				var owner = _dung_find(orig_id)
				if owner != null:
					owner["conditions"].erase("unconscious")
					owner["_mm_consciousness_active"] = false
					expired_logs.append("%s's consciousness returns as %s is destroyed!" % [owner["name"], ent["name"]])
				ent["_mm_inhabited"] = false
				ent["is_player"] = false
			continue
		var rounds_left: int = int(ent.get("summon_rounds_left", -1))
		if rounds_left < 0: continue  # permanent summon
		rounds_left -= 1
		ent["summon_rounds_left"] = rounds_left
		if rounds_left <= 0:
			# If inhabited, return consciousness first
			if bool(ent.get("_mm_inhabited", false)):
				var orig_id: String = str(ent.get("_mm_original_caster_id", ""))
				var owner = _dung_find(orig_id)
				if owner != null:
					owner["conditions"].erase("unconscious")
					owner["_mm_consciousness_active"] = false
					expired_logs.append("%s's consciousness returns as %s fades!" % [owner["name"], ent["name"]])
				ent["_mm_inhabited"] = false
				ent["is_player"] = false
			ent["is_dead"] = true
			ent["conditions"].clear()
			expired_logs.append("%s fades away (summon expired)." % ent["name"])
	# ── Tick construct equipment durations ──
	for ent in _dungeon_entities:
		if bool(ent.get("is_dead", true)): continue
		var constructs: Array = ent.get("_active_constructs", [])
		if constructs.is_empty(): continue
		var to_remove: Array = []
		for ci in range(constructs.size()):
			var cm: Dictionary = constructs[ci]
			if str(cm.get("type", "")) != "equipment": continue
			if bool(cm.get("dismissed", false)) or bool(cm.get("destroyed", false)): continue
			var dur_left: int = int(cm.get("dur_left", 100)) - 1
			cm["dur_left"] = dur_left
			constructs[ci] = cm
			if dur_left <= 0:
				to_remove.append(ci)
				# Remove items from inventory
				var ch: int = int(ent.get("handle", -1))
				if ch >= 0 and _chars.has(ch):
					for item_name in cm.get("items", []):
						remove_item_from_inventory(ch, item_name)
					if cm.has("trr"):
						_chars[ch]["construct_trr"] = maxi(0, int(_chars[ch].get("construct_trr", 0)) - int(cm["trr"]))
				expired_logs.append("%s's construct equipment fades away." % ent["name"])
		# Remove expired constructs (reverse order to keep indices valid)
		for ri in range(to_remove.size() - 1, -1, -1):
			constructs.remove_at(to_remove[ri])
		ent["_active_constructs"] = constructs
	return expired_logs

## Activate a summon feat for a caster in the dungeon.
## feat_type: "minion_master", "chaos_pact", "unity_pact", "void_pact", "grasp_forgotten"
func dung_activate_summon_feat(caster_id: String, feat_type: String) -> Dictionary:
	var caster = _dung_find(caster_id)
	if caster == null: return _dung_fail("Caster not found.")
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return _dung_fail("No character data.")
	var feats: Dictionary = _chars[ch].get("feats", {})
	var caster_lv: int = int(_chars[ch].get("level", 1))
	var div_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[4])
	var feat_tier: int = 0
	var summon_ent: Dictionary = {}
	var summon_logs: Array = []
	match feat_type:
		"minion_master":
			if not feats.has("Minion Master"): return _dung_fail("Missing Minion Master feat.")
			feat_tier = int(feats["Minion Master"])
			if bool(caster.get("minion_master_used", false)):
				return _dung_fail("Minion Master already used this rest.")
			# Max minions: T1-2 = 1, T3 = 3, T4 = 4
			var max_minions: int = 1
			if feat_tier >= 4: max_minions = 4
			elif feat_tier >= 3: max_minions = 3
			# Count existing minions belonging to this caster
			var existing_count: int = 0
			for e in _dungeon_entities:
				if bool(e.get("is_summon", false)) and not bool(e.get("is_dead", false)):
					if str(e.get("summon_caster_id", "")) == caster_id and str(e.get("summon_feat", "")) == "minion_master":
						existing_count += 1
			if existing_count >= max_minions:
				return _dung_fail("Already at maximum minions (%d)." % max_minions)
			caster["minion_master_used"] = true
			var summon_name: String = "Arcane Minion"
			# Creature level = character level (SP that "would have been spent" ≤ level)
			var creature_lv: int = caster_lv
			summon_ent = _dung_spawn_summon(caster_id, summon_name, creature_lv, -1, CAT_MONSTER)
			if summon_ent.is_empty(): return _dung_fail("No space for summon.")
			summon_ent["summon_feat"] = "minion_master"
			# T2+: minion can be Medium (default from spawn is fine)
			if feat_tier >= 2:
				summon_ent["minion_transfer_dmg"] = true  # flag for damage transfer reaction
			# T4: bonus HP equal to caster's level + damage resistance
			if feat_tier >= 4:
				summon_ent["max_hp"] = int(summon_ent["max_hp"]) + caster_lv
				summon_ent["hp"] = int(summon_ent["hp"]) + caster_lv
				# Resistance choice stored on caster (set via UI or defaults to "physical")
				var resist_type: String = str(caster.get("minion_resist_choice", "physical"))
				if not summon_ent.has("resistances"): summon_ent["resistances"] = []
				summon_ent["resistances"].append(resist_type)
			summon_logs.append("Summoned %s (Lv%d) at (%d, %d)." % [summon_name, creature_lv, summon_ent["x"], summon_ent["y"]])
			return _dung_ok("\n".join(summon_logs), 1, 0)
		"minion_consciousness":
			# T3: Fall unconscious, transfer consciousness into first living minion
			if not feats.has("Minion Master"): return _dung_fail("Missing Minion Master feat.")
			if int(feats["Minion Master"]) < 3: return _dung_fail("Requires Minion Master Tier 3.")
			if bool(caster.get("_mm_consciousness_used", false)):
				return _dung_fail("Consciousness transfer already used this rest.")
			# Find a living minion
			var target_minion = null
			for mm_ent in _dungeon_entities:
				if not bool(mm_ent.get("is_summon", false)): continue
				if bool(mm_ent.get("is_dead", false)): continue
				if str(mm_ent.get("summon_caster_id", "")) != caster_id: continue
				if str(mm_ent.get("summon_feat", "")) != "minion_master": continue
				target_minion = mm_ent
				break
			if target_minion == null: return _dung_fail("No living minion to inhabit.")
			# Caster falls unconscious
			_dung_add_condition(caster, "unconscious")
			caster["_mm_consciousness_active"] = true
			caster["_mm_consciousness_used"] = true
			# Minion becomes player-controlled (acts on player phase with full control)
			target_minion["is_player"] = true
			target_minion["handle"] = int(caster.get("handle", -1))  # shares character sheet for feats
			target_minion["_mm_inhabited"] = true
			target_minion["_mm_original_caster_id"] = caster_id
			return _dung_ok("%s falls unconscious and inhabits %s!" % [caster["name"], target_minion["name"]], 0, 0)
		"chaos_pact":
			if not feats.has("Chaos Pact Initiate") and not feats.has("Chaos Pact"):
				return _dung_fail("Missing Chaos Pact feat.")
			if bool(caster.get("chaos_pact_used", false)):
				return _dung_fail("Chaos Pact summon already used this rest.")
			caster["chaos_pact_used"] = true
			summon_ent = _dung_spawn_summon(caster_id, "Chaos Creature", caster_lv, caster_lv, CAT_MONSTER)
			if summon_ent.is_empty(): return _dung_fail("No space for summon.")
			return _dung_ok("Summoned Chaos Creature at (%d, %d) for %d rounds." % [summon_ent["x"], summon_ent["y"], caster_lv], 1, 0)
		"unity_pact":
			if not feats.has("Unity Pact Initiate") and not feats.has("Unity Pact"):
				return _dung_fail("Missing Unity Pact feat.")
			if bool(caster.get("unity_pact_used", false)):
				return _dung_fail("Unity Pact summon already used this rest.")
			caster["unity_pact_used"] = true
			summon_ent = _dung_spawn_summon(caster_id, "Radiant Guardian", caster_lv, caster_lv, CAT_MONSTER)
			if summon_ent.is_empty(): return _dung_fail("No space for summon.")
			return _dung_ok("Summoned Radiant Guardian at (%d, %d) for %d rounds." % [summon_ent["x"], summon_ent["y"], caster_lv], 1, 0)
		"void_pact":
			if not feats.has("Void Pact Initiate") and not feats.has("Void Pact"):
				return _dung_fail("Missing Void Pact feat.")
			if bool(caster.get("void_pact_used", false)):
				return _dung_fail("Void Pact summon already used this rest.")
			caster["void_pact_used"] = true
			summon_ent = _dung_spawn_summon(caster_id, "Shadow Minion", caster_lv, caster_lv, CAT_MONSTER)
			if summon_ent.is_empty(): return _dung_fail("No space for summon.")
			return _dung_ok("Summoned Shadow Minion at (%d, %d) for %d rounds." % [summon_ent["x"], summon_ent["y"], caster_lv], 1, 0)
		"grasp_forgotten":
			if not feats.has("Grasp of the Forgotten"):
				return _dung_fail("Missing Grasp of the Forgotten feat.")
			feat_tier = int(feats["Grasp of the Forgotten"])
			var hand_name: String = "Spectral Hand" if feat_tier < 3 else "Spectral Servant"
			var hand_hp: int = caster_lv if feat_tier < 3 else 2 * caster_lv
			var hand_ac: int = 10 if feat_tier < 3 else 13
			var hand_count: int = 1 if feat_tier < 2 else 2
			if feat_tier >= 3: hand_count = 1  # servant replaces hands
			for _k in range(hand_count):
				summon_ent = _dung_spawn_summon(caster_id, hand_name, 1, -1, CAT_MONSTER)
				if not summon_ent.is_empty():
					summon_ent["max_hp"] = hand_hp; summon_ent["hp"] = hand_hp; summon_ent["ac"] = hand_ac
					summon_logs.append("Summoned %s at (%d, %d)." % [hand_name, summon_ent["x"], summon_ent["y"]])
			if summon_logs.is_empty(): return _dung_fail("No space for summon.")
			return _dung_ok("\n".join(summon_logs), 1, 0)
		# ── Apex Feats (powerful combat activations) ────────────────────────
		"arcane_overdrive":
			if not feats.has("Arcane Overdrive"): return _dung_fail("Missing Arcane Overdrive.")
			if bool(caster.get("arcane_overdrive_used", false)): return _dung_fail("Already used this rest.")
			caster["arcane_overdrive_used"] = true
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + div_score
			return _dung_ok("%s activates Arcane Overdrive! (+%d to all attacks this combat)" % [caster["name"], div_score], 2, 0)
		"iron_tempest":
			if not feats.has("Iron Tempest"): return _dung_fail("Missing Iron Tempest.")
			if bool(caster.get("iron_tempest_used", false)): return _dung_fail("Already used this rest.")
			caster["iron_tempest_used"] = true
			var str_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[0])
			var adj: Array = get_adjacent_enemies(caster_id)
			var total_dmg: int = 0
			for enemy in adj:
				var dmg: int = randi_range(1, 10) + str_score * 2
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
				total_dmg += dmg
			return _dung_ok("%s unleashes Iron Tempest! Hit %d enemies for %d total damage!" % [caster["name"], adj.size(), total_dmg], 3, 0)
		"cataclysmic_leap":
			if not feats.has("Cataclysmic Leap"): return _dung_fail("Missing Cataclysmic Leap.")
			if bool(caster.get("cataclysmic_leap_used", false)): return _dung_fail("Already used this rest.")
			caster["cataclysmic_leap_used"] = true
			var str_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[0])
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				var dmg: int = randi_range(1, 8) + str_score
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
				else: _dung_add_condition(enemy, "prone")
			return _dung_ok("%s performs Cataclysmic Leap! %d enemies hit and knocked prone!" % [caster["name"], adj.size()], 2, 0)
		"gravity_shatter":
			if not feats.has("Gravity Shatter"): return _dung_fail("Missing Gravity Shatter.")
			if bool(caster.get("gravity_shatter_used", false)): return _dung_fail("Already used this rest.")
			caster["gravity_shatter_used"] = true
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				var dmg: int = randi_range(2, 12) + div_score
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
				else: _dung_add_condition(enemy, "stunned")
			return _dung_ok("%s shatters gravity! %d enemies hit and stunned!" % [caster["name"], adj.size()], 3, 0)
		"howl_of_the_forgotten":
			if not feats.has("Howl Of The Forgotten"): return _dung_fail("Missing Howl of the Forgotten.")
			if bool(caster.get("howl_used", false)): return _dung_fail("Already used this rest.")
			caster["howl_used"] = true
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				_dung_add_condition(enemy, "frightened")
				var dmg: int = randi_range(1, 6) + div_score
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
			return _dung_ok("%s howls! %d enemies frightened!" % [caster["name"], adj.size()], 2, 0)
		"phantom_legion":
			if not feats.has("Phantom Legion"): return _dung_fail("Missing Phantom Legion.")
			if bool(caster.get("phantom_legion_used", false)): return _dung_fail("Already used this rest.")
			caster["phantom_legion_used"] = true
			for _k in range(3):
				var s = _dung_spawn_summon(caster_id, "Phantom", caster_lv, caster_lv, CAT_MONSTER)
				if not s.is_empty(): summon_logs.append("Summoned Phantom at (%d,%d)." % [s["x"], s["y"]])
			if summon_logs.is_empty(): return _dung_fail("No space for summons.")
			return _dung_ok("\n".join(summon_logs), 3, 0)
		"soulflare_pulse":
			if not feats.has("Soulflare Pulse"): return _dung_fail("Missing Soulflare Pulse.")
			if bool(caster.get("soulflare_used", false)): return _dung_fail("Already used this rest.")
			caster["soulflare_used"] = true
			var heal: int = div_score * 3
			caster["hp"] = mini(int(caster["max_hp"]), int(caster["hp"]) + heal)
			if ch >= 0 and _chars.has(ch): _chars[ch]["hp"] = caster["hp"]
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				var dmg: int = heal / 2
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
			return _dung_ok("%s pulses soulflare! Healed %d HP, damaged %d enemies!" % [caster["name"], heal, adj.size()], 2, 0)
		"stormbound_mantle":
			if not feats.has("Stormbound Mantle"): return _dung_fail("Missing Stormbound Mantle.")
			if bool(caster.get("stormbound_used", false)): return _dung_fail("Already used this rest.")
			caster["stormbound_used"] = true
			caster["ac"] = int(caster["ac"]) + 4
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + 3
			return _dung_ok("%s dons the Stormbound Mantle! +4 AC, +3 to hit for this combat!" % caster["name"], 2, 0)
		"temporal_rift":
			if not feats.has("Temporal Rift"): return _dung_fail("Missing Temporal Rift.")
			if bool(caster.get("temporal_rift_used", false)): return _dung_fail("Already used this rest.")
			caster["temporal_rift_used"] = true
			caster["ap_spent"] = 0  # full AP reset
			return _dung_ok("%s tears a Temporal Rift! All AP restored!" % caster["name"], 0, 0)
		"divine_reversal":
			if not feats.has("Divine Reversal"): return _dung_fail("Missing Divine Reversal.")
			if bool(caster.get("divine_reversal_used", false)): return _dung_fail("Already used this rest.")
			caster["divine_reversal_used"] = true
			caster["hp"] = int(caster["max_hp"])
			caster["sp"] = int(caster["max_sp"])
			if ch >= 0 and _chars.has(ch):
				_chars[ch]["hp"] = caster["hp"]; _chars[ch]["sp"] = caster["sp"]
			caster["conditions"].clear()
			return _dung_ok("%s invokes Divine Reversal! Fully restored!" % caster["name"], 3, 0)
		"eclipse_veil":
			if not feats.has("Eclipse Veil"): return _dung_fail("Missing Eclipse Veil.")
			if bool(caster.get("eclipse_veil_used", false)): return _dung_fail("Already used this rest.")
			caster["eclipse_veil_used"] = true
			_dung_add_condition(caster, "hidden")
			caster["ac"] = int(caster["ac"]) + 5
			return _dung_ok("%s vanishes into the Eclipse Veil! Hidden + 5 AC!" % caster["name"], 2, 0)
		"mythic_regrowth":
			if not feats.has("Mythic Regrowth"): return _dung_fail("Missing Mythic Regrowth.")
			if bool(caster.get("mythic_regrowth_used", false)): return _dung_fail("Already used this rest.")
			caster["mythic_regrowth_used"] = true
			caster["regen_per_turn"] = div_score + caster_lv
			return _dung_ok("%s activates Mythic Regrowth! Regenerating %d HP/turn!" % [caster["name"], div_score + caster_lv], 2, 0)
		"runebreaker_surge":
			if not feats.has("Runebreaker Surge"): return _dung_fail("Missing Runebreaker Surge.")
			if bool(caster.get("runebreaker_used", false)): return _dung_fail("Already used this rest.")
			caster["runebreaker_used"] = true
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				enemy["conditions"].clear()
				enemy["ac"] = maxi(5, int(enemy["ac"]) - 5)
				var dmg: int = randi_range(1, 8) + div_score
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true
			return _dung_ok("%s surges with Runebreaker! %d enemies stripped of defenses!" % [caster["name"], adj.size()], 3, 0)
		"soulbrand":
			if not feats.has("Soulbrand"): return _dung_fail("Missing Soulbrand.")
			if bool(caster.get("soulbrand_used", false)): return _dung_fail("Already used this rest.")
			caster["soulbrand_used"] = true
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + caster_lv
			return _dung_ok("%s brands their soul! +%d to attacks for this combat!" % [caster["name"], caster_lv], 2, 0)
		"titans_echo":
			if not feats.has("Titans Echo"): return _dung_fail("Missing Titan's Echo.")
			if bool(caster.get("titans_echo_used", false)): return _dung_fail("Already used this rest.")
			caster["titans_echo_used"] = true
			caster["max_hp"] = int(caster["max_hp"]) * 2
			caster["hp"] = int(caster["max_hp"])
			if ch >= 0 and _chars.has(ch): _chars[ch]["hp"] = caster["hp"]
			return _dung_ok("%s channels the Titan's Echo! HP doubled and fully healed!" % caster["name"], 3, 0)
		"voidbrand_curse":
			if not feats.has("Voidbrand Curse"): return _dung_fail("Missing Voidbrand Curse.")
			if bool(caster.get("voidbrand_used", false)): return _dung_fail("Already used this rest.")
			caster["voidbrand_used"] = true
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				_dung_add_condition(enemy, "cursed")
				enemy["ac"] = maxi(5, int(enemy["ac"]) - 3)
				var dmg: int = randi_range(1, 10) + div_score
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
			return _dung_ok("%s brands enemies with void! %d cursed!" % [caster["name"], adj.size()], 2, 0)
		"worldbreaker_step":
			if not feats.has("Worldbreaker Step"): return _dung_fail("Missing Worldbreaker Step.")
			if bool(caster.get("worldbreaker_used", false)): return _dung_fail("Already used this rest.")
			caster["worldbreaker_used"] = true
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				var dmg: int = randi_range(3, 18) + int(_chars[ch].get("stats", [1,1,1,1,1])[0]) * 2
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
				else: _dung_add_condition(enemy, "prone")
			return _dung_ok("%s shatters the ground! %d enemies devastated!" % [caster["name"], adj.size()], 3, 0)
		"blood_of_the_ancients":
			if not feats.has("Blood Of The Ancients"): return _dung_fail("Missing Blood of the Ancients.")
			if bool(caster.get("blood_ancients_used", false)): return _dung_fail("Already used this rest.")
			caster["blood_ancients_used"] = true
			caster["ac"] = int(caster["ac"]) + 3
			caster["regen_per_turn"] = caster_lv
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + 2
			return _dung_ok("%s awakens the Blood of the Ancients! +3 AC, regen, +2 attacks!" % caster["name"], 2, 0)

		# ── Ascendant Feats (transformations) ────────────────────────────
		"draconic_apotheosis":
			if not feats.has("Draconic Apotheosis"): return _dung_fail("Missing Draconic Apotheosis.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["ac"] = int(caster["ac"]) + 5
			caster["max_hp"] = int(float(caster["max_hp"]) * 1.5)
			caster["hp"] = caster["max_hp"]
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + caster_lv / 2
			return _dung_ok("%s undergoes Draconic Apotheosis! +5 AC, 50%% more HP, enhanced attacks!" % caster["name"], 3, 0)
		"vampiric_ascension":
			if not feats.has("Vampiric Ascension"): return _dung_fail("Missing Vampiric Ascension.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["lifesteal_pct"] = 50  # heal 50% of damage dealt
			caster["ac"] = int(caster["ac"]) + 3
			return _dung_ok("%s ascends as Vampire! +3 AC, 50%% lifesteal on attacks!" % caster["name"], 3, 0)
		"lich_binding":
			if not feats.has("Lich Binding"): return _dung_fail("Missing Lich Binding.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["sp"] = int(caster["max_sp"]) * 2
			caster["max_sp"] = int(caster["max_sp"]) * 2
			caster["regen_per_turn"] = div_score
			return _dung_ok("%s binds as a Lich! SP doubled, regen %d/turn!" % [caster["name"], div_score], 3, 0)
		"infernal_coronation":
			if not feats.has("Infernal Coronation"): return _dung_fail("Missing Infernal Coronation.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["ac"] = int(caster["ac"]) + 4
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + 4
			caster["max_hp"] = int(float(caster["max_hp"]) * 1.3)
			caster["hp"] = caster["max_hp"]
			return _dung_ok("%s claims the Infernal Crown! +4 AC, +4 attack, 30%% more HP!" % caster["name"], 3, 0)
		"angelic_rebirth":
			if not feats.has("Angelic Rebirth"): return _dung_fail("Missing Angelic Rebirth.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["hp"] = int(caster["max_hp"])
			caster["sp"] = int(caster["max_sp"])
			caster["regen_per_turn"] = caster_lv + div_score
			caster["ac"] = int(caster["ac"]) + 3
			return _dung_ok("%s undergoes Angelic Rebirth! Fully healed, regen %d/turn, +3 AC!" % [caster["name"], caster_lv + div_score], 3, 0)
		"seraphic_flame":
			if not feats.has("Seraphic Flame"): return _dung_fail("Missing Seraphic Flame.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				_dung_add_condition(enemy, "burning")
				var dmg: int = randi_range(2, 12) + div_score * 2
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
			caster["regen_per_turn"] = div_score
			return _dung_ok("%s erupts in Seraphic Flame! %d enemies burned, regen %d/turn!" % [caster["name"], adj.size(), div_score], 3, 0)
		"fey_lords_pact":
			if not feats.has("Fey Lord's Pact"): return _dung_fail("Missing Fey Lord's Pact.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			_dung_add_condition(caster, "hidden")
			caster["ac"] = int(caster["ac"]) + 6
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + div_score
			return _dung_ok("%s invokes the Fey Lord's Pact! Hidden, +6 AC, +%d attacks!" % [caster["name"], div_score], 3, 0)
		"primordial_elemental_fusion":
			if not feats.has("Primordial Elemental Fusion"): return _dung_fail("Missing Primordial Elemental Fusion.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["ac"] = int(caster["ac"]) + 5
			caster["max_hp"] = int(caster["max_hp"]) + caster_lv * 5
			caster["hp"] = caster["max_hp"]
			return _dung_ok("%s fuses with primordial elements! +5 AC, +%d max HP!" % [caster["name"], caster_lv * 5], 3, 0)
		"stormbound_titan":
			if not feats.has("Stormbound Titan"): return _dung_fail("Missing Stormbound Titan.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["max_hp"] = int(caster["max_hp"]) * 2
			caster["hp"] = caster["max_hp"]
			caster["ac"] = int(caster["ac"]) + 4
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + 5
			return _dung_ok("%s becomes a Stormbound Titan! HP doubled, +4 AC, +5 attacks!" % caster["name"], 3, 0)
		"psychic_maw":
			if not feats.has("Psychic Maw"): return _dung_fail("Missing Psychic Maw.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				_dung_add_condition(enemy, "stunned")
				var dmg: int = randi_range(2, 12) + int(_chars[ch].get("stats", [1,1,1,1,1])[2]) * 3
				_dung_reduce_hp(enemy, dmg)
				if int(enemy["hp"]) <= 0: enemy["is_dead"] = true; enemy["conditions"].clear()
			return _dung_ok("%s opens the Psychic Maw! %d enemies stunned and mind-crushed!" % [caster["name"], adj.size()], 3, 0)
		"kaiju_core_integration":
			if not feats.has("Kaiju Core Integration"): return _dung_fail("Missing Kaiju Core Integration.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["max_hp"] = int(caster["max_hp"]) * 3
			caster["hp"] = caster["max_hp"]
			caster["ac"] = int(caster["ac"]) + 6
			caster["threshold"] = 5
			return _dung_ok("%s integrates the Kaiju Core! HP tripled, +6 AC, damage threshold 5!" % caster["name"], 3, 0)
		"cryptborn_sovereign":
			if not feats.has("Cryptborn Sovereign"): return _dung_fail("Missing Cryptborn Sovereign.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["lifesteal_pct"] = 30
			caster["regen_per_turn"] = caster_lv
			caster["ac"] = int(caster["ac"]) + 4
			for _k in range(2):
				var s = _dung_spawn_summon(caster_id, "Undead Servant", caster_lv, caster_lv, CAT_MONSTER)
				if not s.is_empty(): summon_logs.append("Raised Undead Servant at (%d,%d)." % [s["x"], s["y"]])
			var log_text: String = "%s becomes a Cryptborn Sovereign! +4 AC, lifesteal, regen!" % caster["name"]
			if not summon_logs.is_empty(): log_text += "\n" + "\n".join(summon_logs)
			return _dung_ok(log_text, 3, 0)
		"hag_mothers_covenant":
			if not feats.has("Hag Mother's Covenant"): return _dung_fail("Missing Hag Mother's Covenant.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["sp"] = int(caster["max_sp"]) * 3
			caster["max_sp"] = int(caster["max_sp"]) * 3
			caster["ac"] = int(caster["ac"]) + 3
			return _dung_ok("%s invokes the Hag Mother's Covenant! SP tripled, +3 AC!" % caster["name"], 3, 0)
		"abyssal_unleashing":
			if not feats.has("Abyssal Unleashing"): return _dung_fail("Missing Abyssal Unleashing.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["max_hp"] = int(float(caster["max_hp"]) * 1.5)
			caster["hp"] = caster["max_hp"]
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + caster_lv
			var adj: Array = get_adjacent_enemies(caster_id)
			for enemy in adj:
				_dung_add_condition(enemy, "frightened")
			return _dung_ok("%s unleashes abyssal power! 50%% more HP, +%d attacks, enemies frightened!" % [caster["name"], caster_lv], 3, 0)
		"voidborn_mutation":
			if not feats.has("Voidborn Mutation"): return _dung_fail("Missing Voidborn Mutation.")
			if bool(caster.get("ascendant_used", false)): return _dung_fail("Already ascended this rest.")
			caster["ascendant_used"] = true
			caster["ac"] = int(caster["ac"]) + 5
			caster["regen_per_turn"] = div_score * 2
			caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + div_score
			return _dung_ok("%s undergoes Voidborn Mutation! +5 AC, regen %d/turn, +%d attacks!" % [caster["name"], div_score * 2, div_score], 3, 0)

		# ── Miscellaneous feat activations ─────────────────────────────────────
		"arc_light_surge":
			if not feats.has("Arc-Light Surge") and not feats.has("Arc Light Surge"):
				return _dung_fail("Missing Arc-Light Surge.")
			if _ent_use_feat_charge(caster, "_arc_light_used", 1):
				var arc_dmg: int = _roll_dice(1, 6)
				var arc_count: int = 0
				for adj in _dungeon_entities:
					if bool(adj.get("is_dead", false)): continue
					if adj.get("id", "") == caster_id: continue
					if absi(int(adj["x"]) - int(caster["x"])) <= 1 and absi(int(adj["y"]) - int(caster["y"])) <= 1:
						if not bool(adj.get("is_player", false)):
							_dung_reduce_hp(adj, arc_dmg)
							if adj["hp"] == 0: adj["is_dead"] = true; adj["conditions"].clear()
							arc_count += 1
				return _dung_ok("%s discharges Arc-Light Surge! %d lightning to %d creatures!" % [caster["name"], arc_dmg, arc_count], 1, 0)
			return _dung_fail("Arc-Light Surge already used this rest.")
		"blade_scripture":
			if not feats.has("Blade Scripture"): return _dung_fail("Missing Blade Scripture.")
			if bool(caster.get("blade_scripture_active", false)):
				return _dung_fail("Blade Scripture already active.")
			if _ent_use_feat_charge(caster, "_blade_scripture_used", 1):
				caster["blade_scripture_active"] = true
				return _dung_ok("%s inscribes a rune — weapon deals +1d6 radiant and heals 1 HP per hit!" % caster["name"], 1, 0)
			return _dung_fail("Blade Scripture already used this rest.")
		"barkskin_ritual":
			if not feats.has("Barkskin Ritual"): return _dung_fail("Missing Barkskin Ritual.")
			if bool(caster.get("barkskin_active", false)):
				return _dung_fail("Barkskin already active.")
			if _ent_use_feat_charge(caster, "_barkskin_used", 1):
				caster["barkskin_active"] = true
				caster["ac"] = int(caster["ac"]) + 2
				return _dung_ok("%s grows bark armor! +2 AC, melee attackers take 1 damage!" % caster["name"], 1, 0)
			return _dung_fail("Barkskin Ritual already used this rest.")
		"breath_of_stone":
			if not feats.has("Breath of Stone"): return _dung_fail("Missing Breath of Stone.")
			if bool(caster.get("breath_stone_active", false)):
				return _dung_fail("Breath of Stone already active.")
			if _ent_use_feat_charge(caster, "_breath_stone_used", 1):
				caster["breath_stone_active"] = true
				caster["ac"] = int(caster["ac"]) + 2
				# Immune to push/pull/prone while active
				return _dung_ok("%s braces stance! +2 AC, immune to push/pull/prone!" % caster["name"], 1, 0)
			return _dung_fail("Breath of Stone already used this rest.")
		"chaos_flow":
			if not feats.has("Chaos Flow") and not feats.has("Chaos's Flow"):
				return _dung_fail("Missing Chaos Flow.")
			if _ent_use_feat_charge(caster, "_chaos_flow_used", 1):
				# Cast a random free spell
				var sp_max: int = 4
				if int(feats.get("Chaos Flow", feats.get("Chaos's Flow", 0))) >= 3: sp_max = 8
				var rand_dmg: int = _roll_dice(2, 6) + div_score
				var adj_enemies: Array = []
				for adj in _dungeon_entities:
					if bool(adj.get("is_dead", false)): continue
					if not bool(adj.get("is_player", false)):
						adj_enemies.append(adj)
				if adj_enemies.size() > 0:
					var rand_tgt = adj_enemies[randi() % adj_enemies.size()]
					_dung_reduce_hp(rand_tgt, rand_dmg)
					if rand_tgt["hp"] == 0: rand_tgt["is_dead"] = true; rand_tgt["conditions"].clear()
					return _dung_ok("%s channels Chaos Flow! Random spell hits %s for %d damage!" % [caster["name"], rand_tgt["name"], rand_dmg], 1, 0)
				return _dung_ok("%s channels Chaos Flow but no targets found!" % caster["name"], 1, 0)
			return _dung_fail("Chaos Flow already used this rest.")
		"emberwake":
			if not feats.has("Emberwake"): return _dung_fail("Missing Emberwake.")
			if _ent_use_feat_charge(caster, "_emberwake_used", 1):
				# Mark tiles around caster as ember trail
				var ember_count: int = 0
				for adj in _dungeon_entities:
					if bool(adj.get("is_dead", false)): continue
					if bool(adj.get("is_player", false)): continue
					if absi(int(adj["x"]) - int(caster["x"])) <= 1 and absi(int(adj["y"]) - int(caster["y"])) <= 1:
						var emb_dmg: int = _roll_dice(1, 6)
						_dung_reduce_hp(adj, emb_dmg)
						if adj["hp"] == 0: adj["is_dead"] = true; adj["conditions"].clear()
						ember_count += 1
				return _dung_ok("%s leaves a trail of embers! %d enemies burned!" % [caster["name"], ember_count], 1, 0)
			return _dung_fail("Emberwake already used this rest.")
		"flicker_sparky":
			if not feats.has("Flicker Sparky"): return _dung_fail("Missing Flicker Sparky.")
			if _ent_use_feat_charge(caster, "_flicker_used", 1):
				# Teleport up to 2 tiles away and deal 1d4 lightning to last attacker
				var best_tile: Vector2i = Vector2i(int(caster["x"]), int(caster["y"]))
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						var tx: int = int(caster["x"]) + dx
						var ty: int = int(caster["y"]) + dy
						if tx >= 0 and ty >= 0 and tx < MAP_SIZE and ty < MAP_SIZE and _dung_tile(tx, ty) == TILE_FLOOR:
							var occupied: bool = false
							for ent in _dungeon_entities:
								if not bool(ent.get("is_dead", false)) and int(ent["x"]) == tx and int(ent["y"]) == ty:
									occupied = true; break
							if not occupied:
								best_tile = Vector2i(tx, ty); break
				caster["x"] = best_tile.x; caster["y"] = best_tile.y
				caster["damage_resist_1turn"] = true
				return _dung_ok("%s flickers away! Teleported and gains damage resistance!" % caster["name"], 0, 0)
			return _dung_fail("Flicker Sparky already used this rest.")
		"illusory_double":
			if not feats.has("Illusory Double"): return _dung_fail("Missing Illusory Double.")
			if bool(caster.get("illusory_double_active", false)):
				return _dung_fail("Illusory Double already active.")
			if _ent_use_feat_charge(caster, "_illusion_used", 1):
				caster["illusory_double_active"] = true
				caster["illusory_double_hp"] = 3
				return _dung_ok("%s creates an Illusory Double! 50%% chance attacks hit illusion (3 hits)!" % caster["name"], 1, 0)
			return _dung_fail("Illusory Double already used this rest.")
		"mirrorsteel_glint":
			if not feats.has("Mirrorsteel Glint"): return _dung_fail("Missing Mirrorsteel Glint.")
			if _ent_use_feat_charge(caster, "_mirrorsteel_used", 1):
				caster["mirrorsteel_active"] = true
				return _dung_ok("%s polishes mirrorsteel — will reflect the next spell!" % caster["name"], 1, 0)
			return _dung_fail("Mirrorsteel Glint already used this rest.")
		"refraction_twist":
			if not feats.has("Refraction Twist"): return _dung_fail("Missing Refraction Twist.")
			if _ent_use_feat_charge(caster, "_refraction_used", 1):
				caster["refraction_twist_ready"] = true
				return _dung_ok("%s bends light — next attack has disadvantage, half damage if it still hits!" % caster["name"], 0, 0)
			return _dung_fail("Refraction Twist already used this rest.")
		"resonant_pulse":
			if not feats.has("Resonant Pulse"): return _dung_fail("Missing Resonant Pulse.")
			if _ent_use_feat_charge(caster, "_resonant_used", 1):
				var ally_count: int = 0
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)): continue
					if absi(int(ent["x"]) - int(caster["x"])) <= 2 and absi(int(ent["y"]) - int(caster["y"])) <= 2:
						ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + _roll_dice(1, 4)
						ally_count += 1
				# Regain SP equal to allies buffed
				caster["sp"] = mini(int(caster.get("max_sp", 99)), int(caster.get("sp", 0)) + ally_count)
				return _dung_ok("%s emits a Resonant Pulse! %d allies boosted, +%d SP!" % [caster["name"], ally_count, ally_count], 1, 0)
			return _dung_fail("Resonant Pulse already used this rest.")
		"sacrifice":
			if not feats.has("Sacrifice"): return _dung_fail("Missing Sacrifice.")
			if _ent_use_feat_charge(caster, "_sacrifice_used", 1):
				# Find lowest HP ally
				var best_ally = null
				var lowest_hp: int = 999999
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)): continue
					if ent.get("id", "") == caster_id: continue
					if int(ent["hp"]) < lowest_hp:
						lowest_hp = int(ent["hp"]); best_ally = ent
				if best_ally == null: return _dung_fail("No ally to sacrifice HP to.")
				var sac_hp: int = mini(int(caster["hp"]) / 4, int(best_ally["max_hp"]) - int(best_ally["hp"]))
				sac_hp = maxi(1, sac_hp)
				caster["hp"] = maxi(1, int(caster["hp"]) - sac_hp)
				best_ally["hp"] = mini(int(best_ally["max_hp"]), int(best_ally["hp"]) + sac_hp * 2)
				var ally_h: int = best_ally.get("handle", -1)
				if ally_h >= 0 and _chars.has(ally_h): _chars[ally_h]["hp"] = best_ally["hp"]
				var ch2: int = caster.get("handle", -1)
				if ch2 >= 0 and _chars.has(ch2): _chars[ch2]["hp"] = caster["hp"]
				return _dung_ok("%s sacrifices %d HP — %s heals %d HP!" % [caster["name"], sac_hp, best_ally["name"], sac_hp * 2], 0, 0)
			return _dung_fail("Sacrifice already used this rest.")
		"soulmark":
			if not feats.has("Soulmark"): return _dung_fail("Missing Soulmark.")
			# Mark nearest enemy
			var nearest_enemy = null
			var nearest_dist: float = 999.0
			for ent in _dungeon_entities:
				if bool(ent.get("is_dead", false)): continue
				if bool(ent.get("is_player", false)): continue
				var dx: float = float(int(ent["x"]) - int(caster["x"]))
				var dy: float = float(int(ent["y"]) - int(caster["y"]))
				var dist: float = sqrt(dx * dx + dy * dy)
				if dist < nearest_dist:
					nearest_dist = dist; nearest_enemy = ent
			if nearest_enemy == null: return _dung_fail("No enemy to mark.")
			nearest_enemy["soulmark_by"] = caster_id
			return _dung_ok("%s marks %s with a Soulmark! +1d4 damage against it!" % [caster["name"], nearest_enemy["name"]], 0, 0)
		"spark_leech":
			if not feats.has("Spark Leech"): return _dung_fail("Missing Spark Leech.")
			if _ent_use_feat_charge(caster, "_spark_leech_used", 1):
				var sp_steal: int = div_score
				caster["sp"] = mini(int(caster.get("max_sp", 99)), int(caster.get("sp", 0)) + sp_steal)
				return _dung_ok("%s leeches arcane energy! +%d SP!" % [caster["name"], sp_steal], 0, 0)
			return _dung_fail("Spark Leech already used this rest.")
		"temporal_shift":
			if not feats.has("Temporal Shift"): return _dung_fail("Missing Temporal Shift.")
			if _ent_use_feat_charge(caster, "_temporal_shift_used", 1):
				# Bless all allies with +1d4 to checks
				var buffed: int = 0
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if bool(ent.get("is_player", false)):
						ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + _roll_dice(1, 4)
						ent["speed"] = int(ent.get("speed", 4)) + 1
						buffed += 1
				# Curse all enemies
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)):
						ent["hit_penalty"] = int(ent.get("hit_penalty", 0)) + _roll_dice(1, 4)
						ent["speed"] = maxi(1, int(ent.get("speed", 4)) - 1)
				return _dung_ok("%s shifts time! %d allies blessed, enemies cursed!" % [caster["name"], buffed], 1, 0)
			return _dung_fail("Temporal Shift already used this rest.")
		"tether_link":
			if not feats.has("Tether Link"): return _dung_fail("Missing Tether Link.")
			# Link to nearest ally for HP transfer
			var link_ally = null
			var link_dist: float = 999.0
			for ent in _dungeon_entities:
				if bool(ent.get("is_dead", false)): continue
				if not bool(ent.get("is_player", false)): continue
				if ent.get("id", "") == caster_id: continue
				var dx2: float = float(int(ent["x"]) - int(caster["x"]))
				var dy2: float = float(int(ent["y"]) - int(caster["y"]))
				var d2: float = sqrt(dx2 * dx2 + dy2 * dy2)
				if d2 < link_dist: link_dist = d2; link_ally = ent
			if link_ally == null: return _dung_fail("No ally to tether.")
			caster["tether_link_to"] = link_ally.get("id", "")
			link_ally["tether_link_to"] = caster_id
			return _dung_ok("%s tethers to %s! Can transfer HP freely!" % [caster["name"], link_ally["name"]], 0, 0)
		"verdant_pulse":
			if not feats.has("Verdant Pulse"): return _dung_fail("Missing Verdant Pulse.")
			if _ent_use_feat_charge(caster, "_verdant_pulse_used", 1):
				# Heal allies in range and create difficult terrain
				var healed: int = 0
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)): continue
					if absi(int(ent["x"]) - int(caster["x"])) <= 2 and absi(int(ent["y"]) - int(caster["y"])) <= 2:
						var heal_amt: int = _roll_dice(1, 6)
						ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal_amt)
						var eh: int = ent.get("handle", -1)
						if eh >= 0 and _chars.has(eh): _chars[eh]["hp"] = ent["hp"]
						healed += 1
				return _dung_ok("%s pulses verdant energy! %d allies healed and area becomes difficult terrain!" % [caster["name"], healed], 1, 0)
			return _dung_fail("Verdant Pulse already used this rest.")
		"veilbreaker_voice":
			if not feats.has("Veilbreaker Voice"): return _dung_fail("Missing Veilbreaker Voice.")
			if _ent_use_feat_charge(caster, "_veilbreaker_used", 1):
				# Remove charmed/frightened from allies in range
				var cleansed: int = 0
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)): continue
					if absi(int(ent["x"]) - int(caster["x"])) <= 4 and absi(int(ent["y"]) - int(caster["y"])) <= 4:
						for cond_name in ["charmed", "frightened", "confused"]:
							if _dung_has_condition(ent, cond_name):
								ent["conditions"].erase(cond_name)
								cleansed += 1
				return _dung_ok("%s shouts with supernatural force! %d conditions removed from allies!" % [caster["name"], cleansed], 1, 0)
			return _dung_fail("Veilbreaker Voice already used this rest.")
		"unitys_ebb":
			if not feats.has("Unity's Ebb"): return _dung_fail("Missing Unity's Ebb.")
			if _ent_use_feat_charge(caster, "_unitys_ebb_used", 1):
				# Free healing spell: heal all allies for 2d6
				var healed_count: int = 0
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)): continue
					var heal: int = _roll_dice(2, 6) + div_score
					ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal)
					var eh2: int = ent.get("handle", -1)
					if eh2 >= 0 and _chars.has(eh2): _chars[eh2]["hp"] = ent["hp"]
					healed_count += 1
				return _dung_ok("%s channels Unity's Ebb! %d allies healed for 2d6+%d each!" % [caster["name"], healed_count, div_score], 1, 0)
			return _dung_fail("Unity's Ebb already used this rest.")
		"erylons_echo":
			if not feats.has("Erylon's Echo"): return _dung_fail("Missing Erylon's Echo.")
			if _ent_use_feat_charge(caster, "_erylons_echo_used", 1):
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if bool(ent.get("is_player", false)):
						ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + _roll_dice(1, 4)
				return _dung_ok("%s invokes Erylon's Echo! All allies gain +1d4 to checks!" % caster["name"], 1, 0)
			return _dung_fail("Erylon's Echo already used this rest.")
		"astral_shear":
			if not feats.has("Astral Shear"): return _dung_fail("Missing Astral Shear.")
			if _ent_use_feat_charge(caster, "_astral_shear_used", 1):
				# Deal 1d4+DIV psychic to adjacent enemies
				var shear_dmg: int = _roll_dice(1, 4) + div_score
				var sheared: int = 0
				for adj in _dungeon_entities:
					if bool(adj.get("is_dead", false)): continue
					if bool(adj.get("is_player", false)): continue
					if absi(int(adj["x"]) - int(caster["x"])) <= 1 and absi(int(adj["y"]) - int(caster["y"])) <= 1:
						_dung_reduce_hp(adj, shear_dmg)
						if adj["hp"] == 0: adj["is_dead"] = true; adj["conditions"].clear()
						sheared += 1
				return _dung_ok("%s phases through matter! %d psychic damage to %d enemies!" % [caster["name"], shear_dmg, sheared], 1, 0)
			return _dung_fail("Astral Shear already used this rest.")
		"bender":
			if not feats.has("Bender"): return _dung_fail("Missing Bender.")
			var bend_tier: int = int(feats.get("Bender", 0))
			if _ent_use_feat_charge(caster, "_bender_used", 1):
				var bend_amt: int = 2 if bend_tier < 4 else 5
				caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + bend_amt
				return _dung_ok("%s bends fate! +%d to next roll!" % [caster["name"], bend_amt], 0, 0)
			return _dung_fail("Bender already used this encounter.")
		"echoed_steps":
			if not feats.has("Echoed Steps"): return _dung_fail("Missing Echoed Steps.")
			if _ent_use_feat_charge(caster, "_echoed_steps_used", 1):
				caster["ap_spent"] = maxi(0, int(caster.get("ap_spent", 0)) - 2)
				return _dung_ok("%s takes echoed steps! Free move action and +1 AP!" % caster["name"], 0, 0)
			return _dung_fail("Echoed Steps already used this rest.")
		"sacred_fragmentation":
			# Passive — implemented in spell miss handling
			return _dung_fail("Sacred Fragmentation is a passive feat (spells that miss deal half damage).")
		"arcane_residue":
			if not feats.has("Arcane Residue"): return _dung_fail("Missing Arcane Residue.")
			if _ent_use_feat_charge(caster, "_arcane_residue_used", 1):
				# Leave a zone that damages enemies or heals allies
				caster["arcane_residue_active"] = true
				var ar_dmg: int = _roll_dice(1, 6)
				for adj in _dungeon_entities:
					if bool(adj.get("is_dead", false)): continue
					if absi(int(adj["x"]) - int(caster["x"])) <= 1 and absi(int(adj["y"]) - int(caster["y"])) <= 1:
						if not bool(adj.get("is_player", false)):
							_dung_reduce_hp(adj, ar_dmg)
							if adj["hp"] == 0: adj["is_dead"] = true; adj["conditions"].clear()
						elif adj.get("id", "") != caster_id:
							adj["hp"] = mini(int(adj["max_hp"]), int(adj["hp"]) + ar_dmg)
				return _dung_ok("%s leaves an arcane residue zone! 1d6 to enemies, heals allies!" % caster["name"], 1, 0)
			return _dung_fail("Arcane Residue already used this rest.")
		"loreweaver_mark":
			if not feats.has("Loreweaver's Mark"): return _dung_fail("Missing Loreweaver's Mark.")
			# Grant +1 saves to nearest ally
			var mark_ally = null
			for ent in _dungeon_entities:
				if bool(ent.get("is_dead", false)): continue
				if not bool(ent.get("is_player", false)): continue
				if ent.get("id", "") != caster_id:
					mark_ally = ent; break
			if mark_ally == null: return _dung_fail("No ally to mark.")
			mark_ally["ac"] = int(mark_ally["ac"]) + 1
			return _dung_ok("%s etches a Loreweaver's Mark on %s! +1 to saves!" % [caster["name"], mark_ally["name"]], 0, 0)
		"hollowed_instinct":
			# Passive — implemented in attack resolution
			return _dung_fail("Hollowed Instinct is a passive feat (negates stealth advantage).")
		"flare_of_defiance":
			# Passive — triggers automatically at 0 HP
			return _dung_fail("Flare of Defiance triggers automatically at 0 HP.")
		# ── Crafting feat activations (skill check bonuses) ────────────────────
		"alchemists_supplies":
			if not feats.has("Alchemist's Supplies"): return _dung_fail("Missing Alchemist's Supplies.")
			if _ent_use_feat_charge(caster, "_alchemy_used", 1):
				# Brew a healing potion
				var potion_heal: int = _roll_dice(2, 6) + int(caster.get("stats", [1,1,1,1,1])[3])
				caster["hp"] = mini(int(caster["max_hp"]), int(caster["hp"]) + potion_heal)
				var ch3: int = caster.get("handle", -1)
				if ch3 >= 0 and _chars.has(ch3): _chars[ch3]["hp"] = caster["hp"]
				return _dung_ok("%s brews an alchemical concoction! Heals %d HP!" % [caster["name"], potion_heal], 1, 0)
			return _dung_fail("Alchemist's Supplies already used this rest.")
		"herbalism_kit":
			if not feats.has("Herbalism Kit"): return _dung_fail("Missing Herbalism Kit.")
			if _ent_use_feat_charge(caster, "_herbalism_used", 1):
				var herb_heal: int = _roll_dice(1, 6) + div_score
				# Heal nearest wounded ally
				var wounded_ally = null
				var worst_hp_pct: float = 1.0
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)): continue
					var pct: float = float(int(ent["hp"])) / float(maxi(1, int(ent["max_hp"])))
					if pct < worst_hp_pct: worst_hp_pct = pct; wounded_ally = ent
				if wounded_ally == null: wounded_ally = caster
				wounded_ally["hp"] = mini(int(wounded_ally["max_hp"]), int(wounded_ally["hp"]) + herb_heal)
				var wh: int = wounded_ally.get("handle", -1)
				if wh >= 0 and _chars.has(wh): _chars[wh]["hp"] = wounded_ally["hp"]
				return _dung_ok("%s applies herbal salve to %s! +%d HP!" % [caster["name"], wounded_ally["name"], herb_heal], 1, 0)
			return _dung_fail("Herbalism Kit already used this rest.")
		"poisoners_kit":
			if not feats.has("Poisoner's Kit"): return _dung_fail("Missing Poisoner's Kit.")
			if _ent_use_feat_charge(caster, "_poisoner_used", 1):
				caster["poison_weapon_active"] = true
				return _dung_ok("%s coats weapon with poison! Next hit adds 1d4 poison and disadvantage!" % caster["name"], 1, 0)
			return _dung_fail("Poisoner's Kit already used this rest.")
		"smiths_tools":
			if not feats.has("Smith's Tools"): return _dung_fail("Missing Smith's Tools.")
			if _ent_use_feat_charge(caster, "_smiths_used", 1):
				caster["ac"] = int(caster["ac"]) + 1
				caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + 1
				return _dung_ok("%s repairs and sharpens equipment! +1 AC and +1 attack!" % caster["name"], 1, 0)
			return _dung_fail("Smith's Tools already used this rest.")
		"culinary_virtuoso":
			if not feats.has("Culinary Virtuoso"): return _dung_fail("Missing Culinary Virtuoso.")
			if _ent_use_feat_charge(caster, "_culinary_used", 1):
				var cv_tier: int = int(feats.get("Culinary Virtuoso", 0))
				# Heal and buff all allies
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if bool(ent.get("is_player", false)):
						if cv_tier >= 2:
							ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + _roll_dice(1, 4))
							ent["ac"] = int(ent["ac"]) + 2
						if cv_tier >= 3:
							ent["max_ap"] = int(ent.get("max_ap", 6)) + 2
				return _dung_ok("%s prepares a nourishing meal! Allies healed and buffed!" % caster["name"], 2, 0)
			return _dung_fail("Culinary Virtuoso already used this rest.")
		"thieves_tools":
			if not feats.has("Thieves' Tools"): return _dung_fail("Missing Thieves' Tools.")
			# Passive bonus — grant advantage on trap/lock checks
			caster["thieves_tools_active"] = true
			return _dung_ok("%s readies Thieves' Tools — advantage on locks and traps!" % caster["name"], 0, 0)
		"musical_instrument":
			if not feats.has("Musical Instrument"): return _dung_fail("Missing Musical Instrument.")
			if _ent_use_feat_charge(caster, "_music_used", 1):
				var music_heal: int = _roll_dice(4, 4) + div_score
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if not bool(ent.get("is_player", false)): continue
					if absi(int(ent["x"]) - int(caster["x"])) <= 6 and absi(int(ent["y"]) - int(caster["y"])) <= 6:
						ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + music_heal)
						var mh: int = ent.get("handle", -1)
						if mh >= 0 and _chars.has(mh): _chars[mh]["hp"] = ent["hp"]
				return _dung_ok("%s plays a healing melody! Allies healed for %d HP!" % [caster["name"], music_heal], 1, 1)
			return _dung_fail("Musical Instrument healing already used this rest.")
		"fishing_mastery":
			if not feats.has("Fishing Mastery"): return _dung_fail("Missing Fishing Mastery.")
			if _ent_use_feat_charge(caster, "_fishing_used", 1):
				# Harvest reagents: restore some SP
				var reagents: int = _roll_dice(1, 6)
				caster["sp"] = mini(int(caster.get("max_sp", 99)), int(caster.get("sp", 0)) + reagents)
				return _dung_ok("%s harvests magical reagents! +%d SP from alchemical ingredients!" % [caster["name"], reagents], 1, 0)
			return _dung_fail("Fishing Mastery already used this rest.")
		"hunting_mastery":
			if not feats.has("Hunting Mastery"): return _dung_fail("Missing Hunting Mastery.")
			if _ent_use_feat_charge(caster, "_hunting_used", 1):
				# Designate quarry: +1d6 damage on first hit per round
				var nearest_foe = null
				var foe_dist: float = 999.0
				for ent in _dungeon_entities:
					if bool(ent.get("is_dead", false)): continue
					if bool(ent.get("is_player", false)): continue
					var ddx: float = float(int(ent["x"]) - int(caster["x"]))
					var ddy: float = float(int(ent["y"]) - int(caster["y"]))
					var dd: float = sqrt(ddx * ddx + ddy * ddy)
					if dd < foe_dist: foe_dist = dd; nearest_foe = ent
				if nearest_foe == null: return _dung_fail("No quarry to designate.")
				nearest_foe["quarry_by"] = caster_id
				caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + _roll_dice(1, 6)
				return _dung_ok("%s designates %s as quarry! +1d6 damage on first hit!" % [caster["name"], nearest_foe["name"]], 1, 0)
			return _dung_fail("Hunting Mastery already used this rest.")
		"artisans_tools":
			if not feats.has("Artisan's Tools"): return _dung_fail("Missing Artisan's Tools.")
			if _ent_use_feat_charge(caster, "_artisans_used", 1):
				# Reinforce equipment: temp HP
				var temp_hp: int = int(_chars[ch].get("stats", [1,1,1,1,1])[2]) * 2
				caster["hp"] = mini(int(caster["max_hp"]) + temp_hp, int(caster["hp"]) + temp_hp)
				return _dung_ok("%s reinforces equipment! +%d temporary HP!" % [caster["name"], temp_hp], 1, 0)
			return _dung_fail("Artisan's Tools already used this rest.")
		"weatherwise_tailoring":
			if not feats.has("Weatherwise Tailoring"): return _dung_fail("Missing Weatherwise Tailoring.")
			# Passive: grant environmental resistance
			caster["ac"] = int(caster["ac"]) + 1
			return _dung_ok("%s adjusts climate-tuned gear! +1 AC from tailored protection!" % caster["name"], 0, 0)
		"crafting_artifice":
			if not feats.has("Crafting & Artifice"): return _dung_fail("Missing Crafting & Artifice.")
			if _ent_use_feat_charge(caster, "_artifice_used", 1):
				var ca_tier: int = int(feats.get("Crafting & Artifice", 0))
				if ca_tier >= 3:
					# Install energy core: +1d6 elemental damage for encounter
					caster["energy_core_active"] = true
					return _dung_ok("%s installs an energy core! +1d6 elemental damage on attacks!" % caster["name"], 1, 0)
				else:
					# Improvise a tool
					caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + 2
					return _dung_ok("%s improvises a tactical tool! +2 to next check!" % caster["name"], 1, 0)
			return _dung_fail("Crafting & Artifice already used this rest.")

	return _dung_fail("Unknown feat activation: %s" % feat_type)

# ── Shapeshifting System ─────────────────────────────────────────────────────

## Animal form database: {form_name: {str, spd, vit, size, attacks, special}}
const ANIMAL_FORMS: Dictionary = {
	# Small forms (Tier 1+)
	"Rat":     {"str":1,"spd":3,"vit":1,"size":"Small","weapon":"Bite","dice":[1,4],"special":""},
	"Cat":     {"str":1,"spd":4,"vit":1,"size":"Small","weapon":"Claw","dice":[1,4],"special":"stealth_advantage"},
	"Hawk":    {"str":2,"spd":5,"vit":1,"size":"Small","weapon":"Talons","dice":[1,4],"special":"flying"},
	"Viper":   {"str":1,"spd":4,"vit":1,"size":"Small","weapon":"Fangs","dice":[1,4],"special":"poisoned"},
	# Medium forms (Tier 1+)
	"Wolf":    {"str":3,"spd":4,"vit":3,"size":"Medium","weapon":"Bite","dice":[1,6],"special":"pack_tactics"},
	"Boar":    {"str":4,"spd":2,"vit":4,"size":"Medium","weapon":"Tusks","dice":[1,8],"special":"charge"},
	"Panther": {"str":3,"spd":5,"vit":2,"size":"Medium","weapon":"Claw","dice":[1,6],"special":"pounce"},
	# Large forms (Tier 2+)
	"Bear":      {"str":6,"spd":2,"vit":6,"size":"Large","weapon":"Claw","dice":[2,6],"special":"bear_hug"},
	"Python":    {"str":5,"spd":3,"vit":5,"size":"Large","weapon":"Constrict","dice":[1,8],"special":"grapple"},
	"Dire Wolf": {"str":5,"spd":4,"vit":4,"size":"Large","weapon":"Bite","dice":[2,6],"special":"pack_tactics"},
	"War Horse": {"str":5,"spd":5,"vit":4,"size":"Large","weapon":"Hooves","dice":[2,6],"special":"charge"},
	# Huge forms (Tier 5 only)
	"Giant Eagle":  {"str":7,"spd":6,"vit":5,"size":"Huge","weapon":"Talons","dice":[2,8],"special":"flying"},
	"Mammoth":      {"str":9,"spd":2,"vit":8,"size":"Huge","weapon":"Trample","dice":[3,8],"special":"trample"},
	"Giant Serpent": {"str":8,"spd":4,"vit":7,"size":"Huge","weapon":"Constrict","dice":[2,10],"special":"grapple"},
}

## Returns available forms for a given Shapeshifter's Path tier.
func _shapeshift_available_forms(tier: int) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for form_name in ANIMAL_FORMS:
		var form: Dictionary = ANIMAL_FORMS[form_name]
		var sz: String = str(form["size"])
		match tier:
			1:
				if sz == "Small" or sz == "Medium": result.append(form_name)
			2, 3, 4:
				if sz == "Small" or sz == "Medium" or sz == "Large": result.append(form_name)
			5:
				result.append(form_name)  # all sizes including Huge
	return result

## Apply shapeshifting to a dungeon entity. Stores originals for revert.
## sp_spent: SP the player invests to add levels/stats to the animal form.
## At 0 SP the animal has 0 for all stats; each SP adds a creature level
## (up to character level) with stats assigned per creature-creator rules.
func dung_apply_shapeshift(entity_id: String, form_name: String, sp_spent: int = 0) -> Dictionary:
	var ent = _dung_find(entity_id)
	if ent == null: return _dung_fail("Entity not found.")
	if not ANIMAL_FORMS.has(form_name): return _dung_fail("Unknown form: %s" % form_name)
	var ch: int = int(ent.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return _dung_fail("No character data.")
	var feats: Dictionary = _chars[ch].get("feats", {})
	if not feats.has("Shapeshifter's Path"): return _dung_fail("Missing Shapeshifter's Path feat.")
	var tier: int = int(feats["Shapeshifter's Path"])
	# Check uses remaining (Tier 5 = unlimited, Tier 3 uses free action but still limited)
	var uses_max: Array = [1, 2, 99, 3, 99]  # per SR by tier (99 = unlimited at T3/T5)
	var uses_left: int = int(ent.get("shapeshift_uses", uses_max[clampi(tier - 1, 0, 4)]))
	if tier != 5 and uses_left <= 0:
		return _dung_fail("No shapeshift uses remaining this rest.")
	# Check form size is allowed for tier
	var form: Dictionary = ANIMAL_FORMS[form_name]
	var sz: String = str(form["size"])
	if sz == "Large" and tier < 2: return _dung_fail("Large forms require Tier 2+.")
	if sz == "Huge" and tier < 5: return _dung_fail("Huge forms require Tier 5.")
	# Store originals if not already shifted
	if not bool(ent.get("shapeshifted", false)):
		ent["original_stats"] = _chars[ch].get("stats", [1,1,1,1,1]).duplicate()
		ent["original_hp"] = int(ent["hp"])
		ent["original_max_hp"] = int(ent["max_hp"])
		ent["original_weapon"] = str(ent["equipped_weapon"])
		ent["original_speed"] = int(ent["speed"])
		ent["original_ac"] = int(ent["ac"])
	# ── Calculate animal stats ──
	# Base form has 0 for all stats. SP spent adds creature levels (1 SP = 1 level)
	# up to the character's level, with stats from the form template scaled by level ratio.
	var char_level: int = int(_chars[ch].get("level", 1))
	var creature_level: int = clampi(sp_spent, 0, char_level)
	var level_ratio: float = float(creature_level) / float(maxi(char_level, 1))
	var form_str: int = int(roundf(float(form["str"]) * level_ratio))
	var form_spd: int = int(roundf(float(form["spd"]) * level_ratio))
	var form_vit: int = int(roundf(float(form["vit"]) * level_ratio))
	var orig_stats: Array = ent["original_stats"]
	var new_stats: Array = [form_str, form_spd, int(orig_stats[2]), form_vit, int(orig_stats[4])]
	_chars[ch]["stats"] = new_stats
	# Recalculate HP using Animal category formula
	var new_max_hp: int = _creature_max_hp(CAT_ANIMAL, creature_level, form_vit)
	if creature_level == 0: new_max_hp = maxi(1, form_vit + 1)  # minimum 1 HP at 0 SP
	ent["max_hp"] = new_max_hp
	ent["hp"] = new_max_hp  # full HP on shift
	ent["equipped_weapon"] = str(form["weapon"])
	ent["speed"] = _creature_speed_tiles(CAT_ANIMAL, form_spd) if creature_level > 0 else 4
	ent["ac"] = 10 + form_spd + char_level / 4
	ent["shapeshifted"] = true
	ent["shapeshift_form"] = form_name
	ent["shapeshift_creature_level"] = creature_level
	# Duration by tier: T1=60 rounds (1hr), T2=120 (2hr), T3=240 (4hr), T4=240 (4hr), T5=9999 (unlimited)
	var duration_rounds: Array = [60, 120, 240, 240, 9999]
	ent["shapeshift_rounds"] = duration_rounds[clampi(tier - 1, 0, 4)]
	# Tier 3+: resistance to non-magical damage and attacks deal magical damage
	if tier >= 3:
		ent["shapeshift_resist_phys"] = true
		ent["shapeshift_magic_attacks"] = true
	# Spellcasting while shifted: T3 = once/SR, T5 = unlimited
	if tier >= 5:
		ent["shapeshift_can_cast"] = true
	elif tier >= 3:
		ent["shapeshift_cast_uses"] = 1  # once per SR
		ent["shapeshift_can_cast"] = true
	else:
		ent["shapeshift_can_cast"] = false
	# Tier 3+: magically enhanced animals (general magic abilities available)
	if tier >= 3: ent["shapeshift_magic_enhanced"] = true
	# Tier 4+: magical beast abilities
	if tier >= 4: ent["shapeshift_magical_beast"] = true
	# Deduct uses (Tier 5 = unlimited, no deduction)
	if tier < 5:
		ent["shapeshift_uses"] = uses_left - 1
	# Flying if form has it
	if str(form.get("special", "")) == "flying":
		ent["is_flying"] = true
	# Deduct SP if any were spent (base shapeshift effect costs 0 SP at tier 1)
	if sp_spent > 0:
		var cur_sp: int = int(ent.get("sp", 0))
		ent["sp"] = maxi(0, cur_sp - sp_spent)
	return _dung_ok("%s shapeshifts into a %s%s!" % [
		ent["name"], form_name,
		" (Lv%d)" % creature_level if creature_level > 0 else ""], 1, 0)

## Revert shapeshifting — restore original stats.
## If excess_damage > 0 (creature HP went to 0), the overflow applies to normal HP.
func dung_revert_shapeshift(entity_id: String, excess_damage: int = 0) -> Dictionary:
	var ent = _dung_find(entity_id)
	if ent == null: return _dung_fail("Entity not found.")
	if not bool(ent.get("shapeshifted", false)): return _dung_fail("Not shapeshifted.")
	var ch: int = int(ent.get("handle", -1))
	if ch >= 0 and _chars.has(ch):
		_chars[ch]["stats"] = ent.get("original_stats", [1,1,1,1,1])
	ent["max_hp"] = int(ent.get("original_max_hp", ent["max_hp"]))
	# Restore original HP, then apply any excess damage that carried over
	var restored_hp: int = int(ent.get("original_hp", ent["max_hp"]))
	if excess_damage > 0:
		restored_hp = maxi(0, restored_hp - excess_damage)
	ent["hp"] = mini(restored_hp, int(ent["max_hp"]))
	ent["equipped_weapon"] = str(ent.get("original_weapon", "None"))
	ent["speed"] = int(ent.get("original_speed", 4))
	ent["ac"] = int(ent.get("original_ac", 10))
	ent["shapeshifted"] = false
	ent["shapeshift_form"] = ""
	ent["is_flying"] = false
	ent.erase("shapeshift_resist_phys")
	ent.erase("shapeshift_magic_attacks")
	ent.erase("shapeshift_can_cast")
	ent.erase("shapeshift_cast_uses")
	ent.erase("shapeshift_magic_enhanced")
	ent.erase("shapeshift_magical_beast")
	ent.erase("shapeshift_creature_level")
	var msg: String = "%s reverts to normal form." % ent["name"]
	if excess_damage > 0:
		msg += " (%d excess damage carried over!)" % excess_damage
	if int(ent["hp"]) <= 0:
		ent["is_dead"] = true
		msg += " %s has fallen!" % ent["name"]
	return _dung_ok(msg, 0, 0)

## Tick shapeshift durations — called each round. Auto-reverts when expired.
func _dung_tick_shapeshifts() -> Array:
	var revert_logs: Array = []
	for ent in _dungeon_entities:
		if not bool(ent.get("shapeshifted", false)): continue
		if bool(ent.get("is_dead", false)): continue
		var rounds: int = int(ent.get("shapeshift_rounds", 0))
		rounds -= 1
		ent["shapeshift_rounds"] = rounds
		if rounds <= 0:
			dung_revert_shapeshift(str(ent["id"]))
			revert_logs.append("%s's shapeshift expires." % ent["name"])
	return revert_logs

## Check if a shapeshifted entity hit 0 HP — if so, auto-revert with excess damage.
## Call this after any HP reduction on an entity. Returns a log string or "".
func _shapeshift_check_revert(ent: Dictionary) -> String:
	if not bool(ent.get("shapeshifted", false)): return ""
	if int(ent.get("hp", 1)) > 0: return ""
	# Creature HP hit 0 — calculate excess damage and revert
	var excess: int = absi(int(ent.get("hp", 0)))  # hp is 0 or negative before maxi clamp
	ent["hp"] = 0  # normalize
	var result: Dictionary = dung_revert_shapeshift(str(ent["id"]), excess)
	# After revert, if normal HP > 0, entity is NOT dead (undo any is_dead set by callers)
	if int(ent.get("hp", 0)) > 0:
		ent["is_dead"] = false
	return str(result.get("message", ""))

## Central HP reduction helper — handles shapeshift revert with excess damage.
## Call instead of `ent["hp"] = maxi(0, int(ent["hp"]) - dmg)`.
## Returns a log string if shapeshift reverted, or "" otherwise.
func _dung_reduce_hp(ent: Dictionary, dmg: int) -> String:
	ent["hp"] = int(ent["hp"]) - dmg
	# Check shapeshift revert (needs potentially-negative HP for excess calc)
	var ss_msg: String = _shapeshift_check_revert(ent)
	# Clamp to 0 for non-shapeshifted entities or if revert didn't restore HP
	if int(ent["hp"]) < 0:
		ent["hp"] = 0
	# If this is a construct structure entity that just hit 0 HP, mark as destroyed
	if int(ent["hp"]) == 0 and bool(ent.get("is_construct", false)):
		_dung_mark_construct_destroyed(ent)
	return ss_msg

## Mark a construct as destroyed in its caster's _active_constructs list.
func _dung_mark_construct_destroyed(construct_ent: Dictionary) -> void:
	var caster_id: String = str(construct_ent.get("construct_caster_id", ""))
	if caster_id == "": return
	var caster = _dung_find(caster_id)
	if caster == null: return
	var constructs: Array = caster.get("_active_constructs", [])
	for ci in range(constructs.size()):
		if str(constructs[ci].get("id", "")) == str(construct_ent.get("id", "")):
			constructs[ci]["destroyed"] = true
			caster["_active_constructs"] = constructs
			return

# ── Mob Morale System (GMG) ──────────────────────────────────────────────────

## Check mob morale when damage is taken. Called from damage resolution.
## Morale thresholds: check at each 25% HP mark crossed.
func _mob_morale_check(ent: Dictionary, damage_taken: int) -> String:
	var morale: int = int(ent.get("morale", 4))
	if morale <= 0: return ""  # already routed
	var hp_pct: float = float(int(ent["hp"])) / float(maxi(1, int(ent["max_hp"])))
	# Determine which threshold we should be at
	var target_morale: int = 4
	if hp_pct <= 0.0:   target_morale = 0
	elif hp_pct <= 0.25: target_morale = 1
	elif hp_pct <= 0.50: target_morale = 2
	elif hp_pct <= 0.75: target_morale = 3
	if target_morale >= morale: return ""  # no new threshold crossed
	# Morale check: DC = 10 + damage_taken, Roll = d20 + morale modifier
	var dc: int = 10 + damage_taken
	var morale_mod: int = int(ent.get("morale_bonus", 0))
	var roll: int = randi_range(1, 20) + morale_mod
	if roll < dc:
		ent["morale"] = morale - 1
		if int(ent["morale"]) <= 0:
			return "%s's morale breaks — ROUTED!" % ent["name"]
		return "%s's morale drops to %d (failed check DC %d)." % [ent["name"], ent["morale"], dc]
	return ""  # passed check

## Roll on the mob instinct table (d6) when morale is critical.
func _mob_instinct_roll(ent: Dictionary) -> String:
	var roll: int = randi_range(1, 6)
	match roll:
		1:
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
			return "FRENZY — +2 damage, -2 AC."
		2:
			return "SCATTER — half the group flees and hides."
		3:
			var heal: int = randi_range(1, 6)
			ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal)
			ent["morale"] = mini(4, int(ent["morale"]) + 1)
			return "RALLY — regained %d HP, morale +1." % heal
		4:
			return "GRAB — attempting to grapple nearest target."
		5:
			return "LOOT — focusing on valuables, ignoring combat."
		6:
			return "CHANT — disrupting nearby spellcasting."
	return ""

# ── Creature Ability Execution in Combat ─────────────────────────────────────

## Execute a creature ability during the enemy AI phase.
## Returns {success, log, ap_spent, sp_spent} like other combat actions.
func _dung_execute_creature_ability(ent: Dictionary, ability: Dictionary,
		target: Dictionary) -> Dictionary:
	var ab_name: String = str(ability["name"])
	var ap_cost: int = int(ability["ap"])
	var sp_cost: int = int(ability["sp"])
	var dice: Array = ability.get("dice", [0, 0])
	var conds_list: Array = ability.get("conds", [])
	var ab_range: int = int(ability.get("range", 1))
	var cd: String = str(ability.get("cd", "none"))

	# Check cooldown
	var cooldowns: Dictionary = ent.get("ability_cooldowns", {})
	if cd == "1/turn" and bool(cooldowns.get(ab_name + "_turn", false)):
		return _dung_fail("%s already used this turn." % ab_name)
	if cd == "1/encounter" and bool(cooldowns.get(ab_name + "_enc", false)):
		return _dung_fail("%s already used this encounter." % ab_name)
	if cd == "passive":
		return _dung_fail("Passive abilities are not activated.")

	# Check AP/SP
	if int(ent["ap_spent"]) + ap_cost > int(ent.get("max_ap", 10)):
		return _dung_fail("Not enough AP for %s." % ab_name)
	if sp_cost > 0 and int(ent.get("sp", 0)) < sp_cost:
		return _dung_fail("Not enough SP for %s." % ab_name)

	# Deduct costs
	ent["ap_spent"] += ap_cost
	if sp_cost > 0: ent["sp"] = maxi(0, int(ent["sp"]) - sp_cost)

	# Set cooldown
	if cd == "1/turn": cooldowns[ab_name + "_turn"] = true
	if cd == "1/encounter": cooldowns[ab_name + "_enc"] = true
	ent["ability_cooldowns"] = cooldowns

	var parts: Array = []

	# Deal damage
	if int(dice[0]) > 0 and int(dice[1]) > 0:
		var dmg: int = _roll_dice(int(dice[0]), int(dice[1]))
		# Check target's damage threshold
		var threshold: int = int(target.get("threshold", 0))
		if threshold > 0 and dmg < threshold:
			parts.append("damage below threshold (%d < %d)" % [dmg, threshold])
		else:
			_dung_reduce_hp(target, dmg)
			if int(target["hp"]) == 0:
				target["is_dead"] = true
				target["conditions"].clear()
			var th: int = int(target.get("handle", -1))
			if th >= 0 and _chars.has(th): _chars[th]["hp"] = target["hp"]
			var dead_tag: String = " [DEFEATED]" if bool(target["is_dead"]) else ""
			parts.append("dealt %d dmg%s" % [dmg, dead_tag])

	# Apply conditions
	for cond in conds_list:
		if not bool(target.get("is_dead", false)):
			_dung_add_condition(target, str(cond))
			parts.append(str(cond))

	# Healing abilities (self-heal)
	if "heal" in ab_name.to_lower() or "regenerat" in ab_name.to_lower():
		if int(dice[0]) > 0:
			var heal_amt: int = _roll_dice(int(dice[0]), int(dice[1]))
			ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal_amt)
			parts.append("healed %d HP" % heal_amt)

	var effect_str: String = ", ".join(parts) if not parts.is_empty() else "activated"
	return _dung_ok("%s uses %s on %s — %s." % [ent["name"], ab_name, target["name"], effect_str],
		ap_cost, sp_cost)

func creature_take_damage(handle: int, amount: int) -> int:
	if not _combat_creatures.has(handle): return 0
	var cr = _combat_creatures[handle]
	_dung_reduce_hp(cr, amount)
	if int(cr["hp"]) == 0:
		cr["is_dead"] = true
	return int(cr["hp"])

func destroy_creature(handle: int) -> void:
	_combat_creatures.erase(handle)

func get_creature_inventory_items(handle: int) -> PackedStringArray:
	if not _combat_creatures.has(handle): return PackedStringArray()
	return PackedStringArray(_combat_creatures[handle].get("inventory", []))

func loot_creature(creature_handle: int, player_handle: int) -> bool:
	if not _combat_creatures.has(creature_handle): return false
	var inv: Array = _combat_creatures[creature_handle].get("inventory", [])
	if inv.is_empty(): return false
	# Transfer items to GameState stash
	for item_name in inv:
		if str(item_name).contains("Gold"):
			# Parse "Gold Coin xN" → add gold
			var parts: PackedStringArray = str(item_name).split("x")
			if parts.size() >= 2:
				var amount: int = int(parts[1].strip_edges())
				if amount > 0:
					GameState.gold += amount
		else:
			GameState.stash.append(str(item_name))
	_combat_creatures[creature_handle]["inventory"] = []
	return true

# Generate creature loot based on level — called when creating a creature.
# Tiered pools: Common (Lv1+), Uncommon (Lv3+), Rare (Lv5+), Epic (Lv8+), Legendary (Lv12+)
static func _generate_creature_loot(level: int) -> Array:
	# ── Common: consumables, basic supplies (all from _ITEM_REGISTRY) ─────────
	const LOOT_COMMON: Array = [
		"Lesser Potion of Healing", "Rations (1 day)", "Candle", "Torch",
		"Waterskin", "Rope, Hempen (50 ft)", "Flask", "Tinderbox",
		"Oil Flask", "Chalk (1 piece)", "Soap", "Pouch", "Sack",
		"Ball Bearings (bag)", "Caltrops (bag)", "Fishing Tackle",
	]
	# ── Uncommon: basic weapons, light armor, useful consumables ──────────────
	const LOOT_UNCOMMON: Array = [
		"Dagger", "Shortsword", "Handaxe", "Spear", "Club", "Mace",
		"Shortbow", "Sling", "Light Crossbow", "Dart",
		"Padded", "Leather", "Hide", "Standard Shield",
		"Potion of Healing", "Ether Flask", "Adrenaline Shot",
		"Healer's Kit", "Crowbar", "Grappling Hook",
		"Poison, Basic (vial)", "Acid (vial)",
	]
	# ── Rare: martial weapons, medium armor, potions ──────────────────────────
	const LOOT_RARE: Array = [
		"Longsword", "Battleaxe", "Warhammer", "Greatsword", "Rapier",
		"Katana", "Flail", "Morningstar", "Trident", "Pike",
		"Chain Mail", "Scale Mail", "Breastplate", "Half Plate",
		"Studded Leather", "Chain Shirt", "Tower Shield",
		"Heavy Crossbow", "Longbow", "Hand Crossbow",
		"Potion of Revive", "Ironroot Draught",
		"Holy Water (flask)", "Alchemist's Fire (flask)",
		"Spyglass", "Disguise Kit", "Magnifying Glass",
	]
	# ── Epic: magic items with real mechanical effects ────────────────────────
	const LOOT_EPIC: Array = [
		"Amberglow Pendant", "Amulet of Comfort +1", "Aether-Touched Lens",
		"Anvilstone", "Ashcloak Thread", "Babelstone Charm", "Binding Nail",
		"Candle of Clarity", "Cradleleaf Poultice", "Dagger of the Last Word",
		"Dustveil Cloak", "Forager's Pouch", "Glass of Truth",
		"Glowroot Bandage", "Mothwing Brooch", "Needle of Silence",
		"Shadow Sovereign's Coin", "Scent Masker", "Silent Bell",
		"Smoke Puff", "Traveler's Chalice",
		"Splint", "Plate", "Glaive", "Halberd", "Maul",
		"Musket", "Pistol",
	]
	# ── Legendary: rarest magic items ─────────────────────────────────────────
	const LOOT_LEGENDARY: Array = [
		"Candle of Echoes", "Cleansing Stone", "Dowsing Rod",
		"Echoing Rift Stone", "Glass of Revelation", "Mender's Thread",
		"Messenger Feather", "Pebble of Echoes", "Scribe's Quill",
		"Arcane Stitching Kit", "Flickerflame Matchbox",
	]

	var drops: Array = []
	# Number of drops scales slightly with level
	var num_drops: int = 1 + (randi() % 2)          # 1–2 base
	if level >= 8:  num_drops += 1                   # 2–3
	if level >= 14: num_drops += 1                   # 3–4

	# Always include gold; amount scales with level
	var gold_amount: int = randi_range(1, 4) * level
	drops.append("Gold Coin x%d" % gold_amount)

	for _i in range(num_drops):
		var roll: int = randi() % 100
		var pool: Array
		if level >= 16:
			if roll < 10:    pool = LOOT_LEGENDARY
			elif roll < 35:  pool = LOOT_EPIC
			elif roll < 65:  pool = LOOT_RARE
			elif roll < 85:  pool = LOOT_UNCOMMON
			else:            pool = LOOT_COMMON
		elif level >= 12:
			if roll < 5:     pool = LOOT_LEGENDARY
			elif roll < 25:  pool = LOOT_EPIC
			elif roll < 60:  pool = LOOT_RARE
			elif roll < 85:  pool = LOOT_UNCOMMON
			else:            pool = LOOT_COMMON
		elif level >= 8:
			if roll < 15:    pool = LOOT_EPIC
			elif roll < 50:  pool = LOOT_RARE
			elif roll < 80:  pool = LOOT_UNCOMMON
			else:            pool = LOOT_COMMON
		elif level >= 5:
			if roll < 5:     pool = LOOT_EPIC
			elif roll < 30:  pool = LOOT_RARE
			elif roll < 70:  pool = LOOT_UNCOMMON
			else:            pool = LOOT_COMMON
		elif level >= 3:
			if roll < 10:    pool = LOOT_RARE
			elif roll < 45:  pool = LOOT_UNCOMMON
			else:            pool = LOOT_COMMON
		else:
			if roll < 20:    pool = LOOT_UNCOMMON
			else:            pool = LOOT_COMMON
		drops.append(pool[randi() % pool.size()])

	return drops

## Get the loot inventory of a dungeon entity by its string ID (e.g. "enemy_0").
func get_dungeon_entity_loot(entity_id: String) -> PackedStringArray:
	for i in range(_dungeon_entities.size()):
		var ent: Dictionary = _dungeon_entities[i]
		if str(ent.get("id", "")) == entity_id:
			return PackedStringArray(ent.get("inventory", []))
	return PackedStringArray()

## Transfer loot from a dungeon entity to GameState stash. Returns true on success.
func loot_dungeon_entity(entity_id: String, _player_handle: int) -> bool:
	for i in range(_dungeon_entities.size()):
		var ent: Dictionary = _dungeon_entities[i]
		if str(ent.get("id", "")) == entity_id:
			if bool(ent.get("looted", false)):
				return false  # already looted
			var inv: Array = ent.get("inventory", [])
			for item_name in inv:
				if str(item_name).contains("Gold"):
					var parts: PackedStringArray = str(item_name).split("x")
					if parts.size() >= 2:
						var amount: int = int(parts[1].strip_edges())
						if amount > 0:
							GameState.gold += amount
				else:
					GameState.stash.append(str(item_name))
			_dungeon_entities[i]["inventory"] = []
			_dungeon_entities[i]["looted"] = true
			return true
	return false

# ── Combat manager ────────────────────────────────────────────────────────────

func add_player_to_combat(handle: int) -> void:
	if handle not in _combat_staged_players:
		_combat_staged_players.append(handle)

func add_creature_to_combat(handle: int) -> void:
	if handle not in _combat_staged_creatures:
		_combat_staged_creatures.append(handle)

func start_combat() -> void:
	_combat_order.clear()
	_combat_idx   = 0
	_combat_round = 1
	_combat_log   = ""

	# Build player combatants
	for ph in _combat_staged_players:
		if not _chars.has(ph): continue
		var c: Dictionary = _chars[ph]
		var spd: int = int(c.get("speed", 6))
		var init: int = randi() % 20 + 1 + spd / 2
		var equipped_wpn: String = str(c.get("equipped_weapon", ""))
		var dmg_die: int = 6
		var dmg_bonus: int = 1
		if equipped_wpn.contains("sword") or equipped_wpn.contains("Sword"):
			dmg_die = 8; dmg_bonus = 2
		elif equipped_wpn.contains("bow") or equipped_wpn.contains("Bow"):
			dmg_die = 6; dmg_bonus = 1
		_combat_order.append({
			"id":        "player_%d" % ph,
			"name":      str(c["name"]),
			"handle":    ph,
			"is_player": true,
			"hp":        int(c["hp"]),
			"max_hp":    int(c["max_hp"]),
			"ap":        int(c.get("max_ap", 4)),
			"max_ap":    int(c.get("max_ap", 4)),
			"ac":        int(c.get("ac", 12)),
			"atk_bonus": 3,
			"dmg_die":   dmg_die,
			"dmg_bonus": dmg_bonus,
			"initiative":init,
			"is_dead":   bool(int(c["hp"]) <= 0),
		})

	# Build creature combatants
	for ch in _combat_staged_creatures:
		if not _combat_creatures.has(ch): continue
		var cr: Dictionary = _combat_creatures[ch]
		var init: int = randi() % 20 + 1
		var combatant: Dictionary = cr.duplicate()
		combatant["is_player"] = false
		combatant["initiative"] = init
		combatant["is_dead"] = bool(int(cr["hp"]) <= 0)
		_combat_order.append(combatant)

	# Sort by initiative descending
	_combat_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["initiative"]) > int(b["initiative"]))

	_combat_staged_players.clear()
	_combat_staged_creatures.clear()

## Find combatant dict in _combat_order by string ID.
func _cbt_find(cid: String) -> Dictionary:
	for cb in _combat_order:
		if str(cb["id"]) == cid:
			return cb
	return {}

## Apply damage to a combatant and sync back to source store.
func _cbt_damage(target: Dictionary, dmg: int) -> void:
	_dung_reduce_hp(target, dmg)
	if int(target["hp"]) == 0:
		target["is_dead"] = true
	var h: int = int(target["handle"])
	if bool(target["is_player"]) and _chars.has(h):
		_chars[h]["hp"] = target["hp"]
	elif _combat_creatures.has(h):
		_combat_creatures[h]["hp"] = target["hp"]
		_combat_creatures[h]["is_dead"] = bool(target["is_dead"])

func perform_action(action: int, extra_param: String) -> bool:
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size():
		_combat_log = ""
		return false
	var attacker: Dictionary = _combat_order[_combat_idx]
	_combat_log = ""
	match action:
		0, 12:  # ACTION_MELEE / ACTION_RANGED
			var target: Dictionary = _cbt_find(extra_param)
			if target.is_empty():
				_combat_log = "%s swings at the air!" % attacker["name"]
				return false
			var roll: int = randi() % 20 + 1
			var hit: int = roll + int(attacker.get("atk_bonus", 2))
			var ac: int  = int(target.get("ac", 10))
			if hit >= ac or roll == 20:  # hit or critical
				var dmg: int = randi() % int(attacker.get("dmg_die", 6)) + 1 + int(attacker.get("dmg_bonus", 0))
				if roll == 20:  # critical doubles the die
					dmg += randi() % int(attacker.get("dmg_die", 6)) + 1
				_cbt_damage(target, dmg)
				_combat_log = "%s hits %s for %d damage! (rolled %d, AC %d)" % [
					attacker["name"], target["name"], dmg, roll, ac]
				if bool(target.get("is_dead", false)):
					_combat_log += " — %s is defeated!" % target["name"]
			else:
				_combat_log = "%s misses %s. (rolled %d, needed %d)" % [
					attacker["name"], target["name"], roll, ac - int(attacker.get("atk_bonus", 2))]
			attacker["ap"] = maxi(0, int(attacker["ap"]) - 2)
			return true
		1:  # ACTION_DODGE
			_combat_log = "%s takes a defensive stance (+2 AC until next turn)." % attacker["name"]
			attacker["ac"] = int(attacker.get("ac", 10)) + 2
			attacker["ap"] = maxi(0, int(attacker["ap"]) - 1)
			return true
		3:  # ACTION_REST
			var heal: int = randi() % 4 + 1
			attacker["hp"] = mini(int(attacker["max_hp"]), int(attacker["hp"]) + heal)
			var h: int = int(attacker["handle"])
			if bool(attacker["is_player"]) and _chars.has(h):
				_chars[h]["hp"] = attacker["hp"]
			_combat_log = "%s rests and recovers %d HP." % [attacker["name"], heal]
			attacker["ap"] = maxi(0, int(attacker["ap"]) - 1)
			return true
		10:  # ACTION_SPELL
			_combat_log = "%s attempts to cast %s." % [attacker["name"], extra_param]
			attacker["ap"] = maxi(0, int(attacker["ap"]) - 2)
			return true
	_combat_log = "%s does nothing." % attacker["name"]
	return false

func end_player_phase() -> void:
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size(): return
	_combat_order[_combat_idx]["ap"] = 0

func next_turn() -> void:
	if _combat_order.is_empty(): return
	# Restore AP for whoever just went
	var prev: Dictionary = _combat_order[_combat_idx]
	prev["ap"] = int(prev["max_ap"])
	# Advance, skipping the dead
	var tried: int = 0
	_combat_idx = (_combat_idx + 1) % _combat_order.size()
	while bool(_combat_order[_combat_idx].get("is_dead", false)) and tried < _combat_order.size():
		_combat_idx = (_combat_idx + 1) % _combat_order.size()
		tried += 1
	# New round when we wrap to index 0
	if _combat_idx == 0:
		_combat_round += 1

func set_current_combatant_by_id(id: String) -> bool:
	for i in range(_combat_order.size()):
		if str(_combat_order[i]["id"]) == id:
			_combat_idx = i
			return true
	return false

func get_current_combatant_name() -> String:
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size(): return ""
	return str(_combat_order[_combat_idx]["name"])

func get_current_combatant_id() -> String:
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size(): return ""
	return str(_combat_order[_combat_idx]["id"])

func get_current_combatant_is_player() -> bool:
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size(): return false
	return bool(_combat_order[_combat_idx]["is_player"])

func get_current_combatant_ap() -> int:
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size(): return 0
	return int(_combat_order[_combat_idx]["ap"])

func get_current_combatant_hp() -> int:
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size(): return 0
	return int(_combat_order[_combat_idx]["hp"])

func get_combat_round() -> int:
	return _combat_round

func get_action_cost(action: int, extra_param: String) -> int:
	match action:
		0, 12: return 2  # Melee / Ranged
		1:     return 1  # Dodge
		3:     return 1  # Rest
		10:    return 2  # Spell
	return 1

## Process enemy turn: move towards nearest player and attack.
func process_enemy_phase() -> String:
	_combat_log = ""
	if _combat_order.is_empty() or _combat_idx >= _combat_order.size():
		return ""
	var enemy: Dictionary = _combat_order[_combat_idx]
	if bool(enemy.get("is_player", false)) or bool(enemy.get("is_dead", false)):
		return ""
	# Find nearest living player (positional data not tracked, so pick first)
	var target: Dictionary = {}
	for cb in _combat_order:
		if bool(cb.get("is_player", false)) and not bool(cb.get("is_dead", false)):
			target = cb
			break
	if target.is_empty():
		_combat_log = "%s finds no targets." % enemy["name"]
		return _combat_log
	# Enemy AI: if low HP (< 25%) consider healing, otherwise attack
	var hp_pct: float = float(int(enemy["hp"])) / float(maxi(1, int(enemy["max_hp"])))
	if hp_pct < 0.25 and randi() % 3 == 0:
		# Chance to rest
		perform_action(3, "")
	else:
		# Attack the player
		perform_action(0, str(target["id"]))
	return _combat_log

func get_last_action_log() -> String:
	return _combat_log

func get_initiative_order() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for cb in _combat_order:
		var tag: String = " ✦" if not bool(cb.get("is_dead", false)) else " ✗"
		result.append("%s (HP:%d)%s" % [cb["name"], int(cb["hp"]), tag])
	return result

## collect_loot is implemented below near the dungeon loot section.

func set_mission_active(active: bool) -> void:
	pass

## Returns the spell names of all sustained matrices the entity is maintaining.
func get_active_matrices(combatant_id: String) -> PackedStringArray:
	if not _dungeon_matrices.has(combatant_id): return PackedStringArray()
	var result: PackedStringArray = PackedStringArray()
	for mtx in _dungeon_matrices[combatant_id]:
		result.append(str(mtx["name"]))
	return result

## Returns full matrix dicts for a caster (for UI display).
func get_active_matrix_dicts(combatant_id: String) -> Array:
	if not _dungeon_matrices.has(combatant_id): return []
	return _dungeon_matrices[combatant_id].duplicate(true)

## Register a new sustained spell as a matrix on the caster.
## If the same spell is already active, refreshes its duration.
## PHB: max sustained matrices = 1 + DIV/2 (minimum 1). Oldest is dropped if exceeded.
## Each matrix tracks affected_entities for multi-target removal on expiry.
func _dung_register_matrix(
		caster_id: String, spell_name: String, rounds: int,
		focus_id: String, is_attack: bool, conds: Array) -> void:
	if not _dungeon_matrices.has(caster_id):
		_dungeon_matrices[caster_id] = []
	var matrices: Array = _dungeon_matrices[caster_id]
	# Refresh if already active — update duration and add new focus to affected list
	for mtx in matrices:
		if mtx["name"] == spell_name:
			mtx["rounds"]     = rounds
			mtx["suppressed"] = false
			if focus_id != "" and focus_id not in mtx.get("affected_entities", []):
				mtx["affected_entities"].append(focus_id)
			return
	# Enforce max matrices: 1 + DIV/2 (min 1)
	var max_matrices: int = 1
	var caster_ent = _dung_find(caster_id)
	if caster_ent != null:
		var ch: int = int(caster_ent.get("handle", -1))
		if ch >= 0 and _chars.has(ch):
			var div_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[4])
			max_matrices = maxi(1, 1 + div_score / 2)
	# If at capacity, remove the oldest matrix (FIFO) and strip its conditions
	while matrices.size() >= max_matrices:
		var oldest: Dictionary = matrices[0]
		matrices.remove_at(0)
		for eid in oldest.get("affected_entities", []):
			var focus = _dung_find(str(eid))
			if focus != null:
				for cond in oldest.get("conds", []):
					_dung_remove_condition(focus, str(cond))
	matrices.append({
		"name":              spell_name,
		"rounds":            rounds,
		"focus_id":          focus_id,
		"suppressed":        false,
		"is_attack":         is_attack,
		"conds":             conds.duplicate(),
		"affected_entities": [focus_id] if focus_id != "" else [],
		"free_activation":   true,   # PHB: first activation per turn is free
	})

## Tick down one round on all active matrices for this caster.
## Expired matrices are removed and their conditions stripped from ALL affected entities.
## Fix #6: If caster is Incapacitated/Stunned/Unconscious/Paralyzed, matrices are
## suppressed — their durations do NOT count down and their conditions are lifted
## from their focus target until the caster recovers.
## Phase 2: Reset free_activation flag each turn for sustained spell free use.
func _dung_tick_matrices(entity_id: String) -> void:
	if not _dungeon_matrices.has(entity_id): return
	# First, refresh suppression flags based on caster state.
	var caster_ent = _dung_find(entity_id)
	if caster_ent != null:
		_matrix_update_suppression(caster_ent)
	var matrices: Array = _dungeon_matrices[entity_id]
	var expired: Array  = []
	for mtx in matrices:
		# Reset free activation each turn (PHB: one free sustained use per turn)
		mtx["free_activation"] = true
		if bool(mtx["suppressed"]): continue
		mtx["rounds"] -= 1
		if int(mtx["rounds"]) <= 0:
			expired.append(mtx)
	for mtx in expired:
		matrices.erase(mtx)
		# Strip conditions from ALL affected entities, not just focus_id
		for eid in mtx.get("affected_entities", []):
			var affected = _dung_find(str(eid))
			if affected != null:
				for cond in mtx.get("conds", []):
					_dung_remove_condition(affected, str(cond))
		# Fallback: also check focus_id directly in case it's not in affected_entities
		var focus = _dung_find(str(mtx.get("focus_id", "")))
		if focus != null:
			for cond in mtx.get("conds", []):
				_dung_remove_condition(focus, str(cond))
	if matrices.is_empty():
		_dungeon_matrices.erase(entity_id)

## Immediately end a named matrix for this caster and strip conditions from all affected.
func _dung_end_matrix(caster_id: String, spell_name: String) -> void:
	if not _dungeon_matrices.has(caster_id): return
	var matrices: Array = _dungeon_matrices[caster_id]
	for i in range(matrices.size()):
		if str(matrices[i]["name"]) == spell_name:
			# Strip conditions from all affected entities
			for eid in matrices[i].get("affected_entities", []):
				var affected = _dung_find(str(eid))
				if affected != null:
					for cond in matrices[i].get("conds", []):
						_dung_remove_condition(affected, str(cond))
			# Fallback: focus_id
			var focus = _dung_find(str(matrices[i].get("focus_id", "")))
			if focus != null:
				for cond in matrices[i].get("conds", []):
					_dung_remove_condition(focus, str(cond))
			matrices.remove_at(i)
			if matrices.is_empty():
				_dungeon_matrices.erase(caster_id)
			return

## PHB Phase 2: Check if a sustained spell can be activated for free this turn.
## Returns true and consumes the free activation. Returns false if already used.
func _matrix_try_free_activation(caster_id: String, spell_name: String) -> bool:
	if not _dungeon_matrices.has(caster_id): return false
	for mtx in _dungeon_matrices[caster_id]:
		if mtx["name"] == spell_name and bool(mtx.get("free_activation", false)):
			mtx["free_activation"] = false
			return true
	return false

## PHB Phase 2: Bind an arcane focus item to a matrix. Focus can be suppressed
## (which suppresses the matrix) or destroyed (which ends the matrix).
func _matrix_bind_focus(caster_id: String, spell_name: String, focus_item: String) -> void:
	if not _dungeon_matrices.has(caster_id): return
	for mtx in _dungeon_matrices[caster_id]:
		if mtx["name"] == spell_name:
			mtx["focus_item"] = focus_item
			return

## PHB Phase 2: Get the focus item bound to a matrix, or "" if none.
func _matrix_get_focus(caster_id: String, spell_name: String) -> String:
	if not _dungeon_matrices.has(caster_id): return ""
	for mtx in _dungeon_matrices[caster_id]:
		if mtx["name"] == spell_name:
			return str(mtx.get("focus_item", ""))
	return ""

func get_all_spells() -> Array:
	_ensure_spell_db()
	var result: Array = []
	for sp_name in _SPELL_DB:
		var s: Dictionary = _SPELL_DB[sp_name]
		result.append([sp_name, s["dom"], str(s["sc"]), s["desc"],
			str(s["rt"]), str(s["atk"])])
	return result

func get_spells_by_domain(domain: int) -> Array:
	_ensure_spell_db()
	# Domain int: 0=Biological, 1=Chemical, 2=Physical, 3=Spiritual
	const DOM_NAMES: Array = ["Biological","Chemical","Physical","Spiritual"]
	var dom_name: String = DOM_NAMES[clampi(domain, 0, 3)]
	var result: Array = []
	for sp_name in _SPELL_DB:
		var s: Dictionary = _SPELL_DB[sp_name]
		if s["dom"] == dom_name:
			result.append([sp_name, s["dom"], str(s["sc"]), s["desc"],
				str(s["rt"]), str(s["atk"])])
	return result

func add_custom_spell(spell_name: String, domain: int, cost: int, description: String,
		range_: int, is_attack: bool, die_count: int, die_sides: int,
		damage_type: int, is_healing: bool, duration_rounds: int,
		max_targets: int, area_type: int, conditions_csv: String,
		is_teleport: bool, is_combustion: bool = false,
		caster_handle: int = -1, tp_range: int = 0,
		is_summon: bool = false, is_construct: bool = false) -> void:
	_ensure_spell_db()   # guarantee built-in spells exist before adding custom ones
	# Domain indices match the canonical 4-domain system used across all callers:
	# 0=Biological, 1=Chemical, 2=Physical, 3=Spiritual
	var domain_names: Array = ["Biological","Chemical","Physical","Spiritual"]
	var dom_str: String = domain_names[clampi(domain, 0, domain_names.size() - 1)]
	# Expanded to match all 13 PHB damage types so conditions can be triggered.
	var dmg_names: Array = ["bludgeoning","piercing","slashing","force","fire","cold",
		"lightning","acid","poison","psychic","radiant","necrotic","thunder"]
	var dmg_str: String = dmg_names[clampi(damage_type, 0, dmg_names.size() - 1)]
	# Teleport spells: if tp_range > 0 the SP cost is pre-paid (ritual) so store cost.
	# If tp_range == 0 (ad-hoc teleport), use dynamic distance pricing (sc=0).
	var final_cost: int = cost if (not is_teleport or tp_range > 0) else 0
	# Parse conditions CSV into Array to match built-in spell format ("conds")
	var conds_arr: Array = []
	if conditions_csv != "":
		for c in conditions_csv.split(","):
			var trimmed: String = c.strip_edges()
			if trimmed != "":
				conds_arr.append(trimmed)
	_SPELL_DB[spell_name] = {
		"dom":  dom_str,
		"sc":   final_cost,
		"desc": description,
		"rt":   range_,
		"atk":  is_attack,
		"dc":   die_count,
		"ds":   die_sides,
		"dt":   dmg_str,
		"heal": is_healing,
		"dur":  duration_rounds,
		"mt":   max_targets,
		"area": area_type,
		"conds": conds_arr,
		"tp":   is_teleport,
		"tp_range": tp_range,
		"combustion": is_combustion,
		"summon": is_summon,
		"construct": is_construct,
		"custom": true,
	}
	# Teach the spell to the appropriate character(s)
	if caster_handle >= 0 and caster_handle in _chars:
		# Only teach the specific caster
		var c: Dictionary = _chars[caster_handle]
		var spells: Array = c.get("spells", [])
		if spell_name not in spells:
			spells.append(spell_name)
			c["spells"] = spells
		# Sync to dungeon entity if mid-combat
		for ent in _dungeon_entities:
			if int(ent.get("handle", -1)) == caster_handle and bool(ent["is_player"]):
				var known: Array = Array(ent.get("known_spells", PackedStringArray()))
				if not spell_name in known:
					known.append(spell_name)
					ent["known_spells"] = PackedStringArray(known)
	elif caster_handle == -2:
		# Explicit "teach nobody" — just register in _SPELL_DB
		pass
	else:
		# Legacy / dungeon spell crafter: teach all living characters
		for h in _chars:
			var c: Dictionary = _chars[h]
			var spells: Array = c.get("spells", [])
			if spell_name not in spells:
				spells.append(spell_name)
				c["spells"] = spells
		for ent in _dungeon_entities:
			if bool(ent["is_player"]) and not bool(ent["is_dead"]):
				var known: Array = Array(ent.get("known_spells", PackedStringArray()))
				if not spell_name in known:
					known.append(spell_name)
					ent["known_spells"] = PackedStringArray(known)

func get_custom_spells() -> Array:
	var result: Array = []
	for sp_name in _SPELL_DB:
		var s: Dictionary = _SPELL_DB[sp_name]
		if s.get("custom", false):
			result.append([sp_name, s.get("dom", 0), str(s.get("sc", 2)), s.get("desc", ""),
				str(s.get("rt", 0)), str(s.get("atk", false))])
	return result

# ── Terrain registry ──────────────────────────────────────────────────────────
## Compact terrain registry: region_name → Array of [subregion_name, style_id]
static var _TERRAIN_REGISTRY: Dictionary = {}

func _ensure_terrain_registry() -> void:
	if not _TERRAIN_REGISTRY.is_empty(): return
	_TERRAIN_REGISTRY = {
		"Underground": [
			["Cave System", 0], ["Crystal Cavern", 6], ["Magma Tunnel", 4],
			["Flooded Cave", 5], ["Ancient Tomb", 7], ["Collapsed Mine", 0],
			["Mushroom Grotto", 2], ["Underdark Passage", 7],
		],
		"Forest": [
			["Temperate Forest", 2], ["Jungle Canopy", 2], ["Haunted Woods", 7],
			["Sacred Grove", 2], ["Burning Forest", 4], ["Bog", 5],
			["Druid Glade", 2], ["Frozen Tundra", 1],
		],
		"Wilderness": [
			["Open Plain", 1], ["Rocky Hillside", 1], ["Ravine", 0],
			["Desert Dunes", 1], ["Tundra Wastes", 1], ["Crater Field", 4],
			["Marshland", 5], ["Badlands", 4],
		],
		"Urban": [
			["City Streets", 3], ["Sewer Network", 7], ["Rooftops", 3],
			["Abandoned Warehouse", 3], ["Market Square", 3], ["Alley Network", 3],
			["City Gate", 3], ["Catacombs", 7],
		],
		"Coastal": [
			["Cliffside", 1], ["Beach", 1], ["Tidepools", 5],
			["Sunken Ruins", 5], ["Coral Reef", 5], ["Harbor Dock", 3],
			["Sea Cave", 5], ["Whirlpool Arena", 5],
		],
		"Planar": [
			["Arcane Nexus", 6], ["Shadow Realm", 7], ["Astral Sea", 6],
			["Infernal Wastes", 4], ["Celestial Spire", 6], ["Void Rift", 7],
			["Feywild Glade", 2], ["Elemental Chaos", 4],
		],
		"Volcanic": [
			["Lava Field", 4], ["Caldera Rim", 4], ["Ash Wastes", 4],
			["Obsidian Flats", 4], ["Magma Chamber", 4], ["Sulfur Vents", 4],
			["Cinder Cone", 4], ["Pyroclastic Flow", 4],
		],
		"Aquatic": [
			["Shallow Reef", 5], ["Deep Abyss", 5], ["River Delta", 5],
			["Frozen Lake", 5], ["Waterfall Basin", 5], ["Underground Lake", 5],
			["Flooded Temple", 5], ["Briny Trench", 5],
		],
	}

func get_terrain_regions() -> PackedStringArray:
	_ensure_terrain_registry()
	return PackedStringArray(_TERRAIN_REGISTRY.keys())

func get_terrain_subregions(region: String) -> Array:
	_ensure_terrain_registry()
	if _TERRAIN_REGISTRY.has(region):
		return _TERRAIN_REGISTRY[region]
	return []

func restart_with_terrain(style_id: int, terrain_name: String) -> void:
	_dungeon_terrain_style = clampi(style_id, 0, 7)
	_dungeon_terrain_name = terrain_name
	## Regenerate dungeon with new terrain, preserving same party
	start_dungeon(GameState.get_active_handles(), _dungeon_enemy_level, -1, clampi(style_id, 0, 7))
	_dungeon_terrain_style = clampi(style_id, 0, 7)
	_dungeon_terrain_name = terrain_name
	## Re-spawn allies so they don't overwrite enemy entities
	if GameState.recruited_allies.size() > 0:
		spawn_allies(GameState.recruited_allies)

# ── Flying system ─────────────────────────────────────────────────────────────
const DUNGEON_CEILING: int = 13   # matches mobile ceilingHeight

func dungeon_toggle_fly(entity_id: String) -> Dictionary:
	var ent = _dung_find(entity_id)
	if ent == null or bool(ent["is_dead"]):
		return _dung_fail("No valid entity.")
	var currently_flying: bool = _dung_has_condition(ent, "flying")
	if currently_flying:
		_dung_remove_condition(ent, "flying")
		ent["z"] = 1   # land at ground level
		var fog_idx: int = int(ent["y"]) * MAP_SIZE + int(ent["x"])
		if _dungeon_elevation.size() > fog_idx:
			ent["z"] = int(_dungeon_elevation[fog_idx])
		return _dung_ok("%s lands." % ent["name"], 1, 0)
	else:
		_dung_add_condition(ent, "flying")
		ent["z"] = 2   # rise to high ground equivalent
		return _dung_ok("%s takes flight! (z=2)" % ent["name"], 1, 0)

func dungeon_set_entity_z(entity_id: String, delta: int) -> Dictionary:
	var ent = _dung_find(entity_id)
	if ent == null or bool(ent["is_dead"]):
		return _dung_fail("No valid entity.")
	if not _dung_has_condition(ent, "flying"):
		return _dung_fail("%s is not flying." % ent["name"])
	var cur_z: int = int(ent.get("z", 1))
	var new_z: int = clampi(cur_z + delta, 0, DUNGEON_CEILING)
	ent["z"] = new_z
	var dir: String = "ascends" if delta > 0 else "descends"
	return _dung_ok("%s %s to altitude %d." % [ent["name"], dir, new_z], 0, 0)

## Flying entities skip obstacle tile blocking during movement
func _dung_can_enter_tile(ent: Dictionary, x: int, y: int) -> bool:
	var t: int = _dung_tile(x, y)
	if t == TILE_VOID: return false
	if _dung_has_condition(ent, "flying"):
		return t != TILE_VOID   ## fly over walls and obstacles
	return t == TILE_FLOOR

# ── Dungeon state ─────────────────────────────────────────────────────────────
var _dungeon_active: bool = false
var _dungeon_map: PackedInt32Array        # 625 ints: 0=void, 1=floor, 2=wall, 3=obstacle
var _dungeon_entities: Array = []         # Array of Dictionaries (full entity data)
var _dungeon_is_player_phase: bool = true
var _dungeon_round: int = 1
var _dungeon_enemy_level: int = 1
var _dungeon_loot: Array = []             # item strings earned
var _dungeon_player_queue: Array = []     # ordered list of player entity IDs for this round
var _dungeon_queue_idx: int = 0           # which player in queue is currently acting
var _dungeon_type: int = 0               # 0=standard,1=kaiju,2=apex,3=militia,4=mob
var _dungeon_encounter_name: String = ""
## Sustained spell tracker: entity_id -> Array of matrix dicts
## Each matrix dict: {name, rounds, focus_id, suppressed, is_attack, conds}
var _dungeon_matrices: Dictionary = {}   # caster_id -> Array[Dictionary]

# ── Fog of war + Elevation ────────────────────────────────────────────────────
## Per-tile elevation: 0=pit/low, 1=ground(normal), 2=high-ground/platform
var _dungeon_elevation: PackedInt32Array
## Per-tile fog state: 0=never seen, 1=seen/remembered, 2=currently visible
var _dungeon_fog: PackedByteArray

const BASE_VISION_RADIUS: int = 12

# ── Terrain style ─────────────────────────────────────────────────────────────
## terrainStyleId: 0=Cave 1=Open 2=Dense(Forest) 3=Urban 4=Volcanic 5=Aquatic 6=Arcane 7=Necromantic
var _dungeon_terrain_style: int = 0
var _dungeon_terrain_name:  String = ""

## Per-style colour palettes for the renderer.
## Each entry: {name, floor, floor_alt, wall, obstacle, accent} — [r,g,b]
## Plus biome metadata: prop_set, light_color, light_energy, fog_color, fog_density,
##   ceiling_style ("beams"|"stalactites"|"canopy"|"open"|"vaulted"|"none"),
##   wall_style ("brick"|"rock"|"wood"|"ice"|"coral"|"bone"|"crystal"|"sand"|"metal")
static var TERRAIN_PALETTES: Dictionary = {
	0:  { "name": "Cave",                "floor": [0.28, 0.25, 0.22], "floor_alt": [0.25, 0.22, 0.19],
		  "wall": [0.14, 0.12, 0.10], "obstacle": [0.20, 0.17, 0.14], "accent": [0.55, 0.45, 0.30],
		  "prop_set": "cave", "light_color": [1.0, 0.65, 0.25], "light_energy": 2.8,
		  "fog_color": [0.08, 0.06, 0.04], "fog_density": 0.3, "ceiling_style": "stalactites", "wall_style": "rock" },
	1:  { "name": "Grassland",           "floor": [0.22, 0.32, 0.12], "floor_alt": [0.18, 0.28, 0.10],
		  "wall": [0.12, 0.16, 0.08], "obstacle": [0.25, 0.20, 0.13], "accent": [0.60, 0.72, 0.30],
		  "prop_set": "grassland", "light_color": [1.0, 0.95, 0.80], "light_energy": 3.5,
		  "fog_color": [0.20, 0.25, 0.15], "fog_density": 0.1, "ceiling_style": "open", "wall_style": "rock" },
	2:  { "name": "Dense Forest",        "floor": [0.08, 0.22, 0.06], "floor_alt": [0.06, 0.18, 0.05],
		  "wall": [0.04, 0.09, 0.04], "obstacle": [0.12, 0.28, 0.09], "accent": [0.30, 0.62, 0.18],
		  "prop_set": "forest", "light_color": [0.70, 0.90, 0.50], "light_energy": 2.2,
		  "fog_color": [0.06, 0.12, 0.04], "fog_density": 0.4, "ceiling_style": "canopy", "wall_style": "wood" },
	3:  { "name": "City Ruins",          "floor": [0.18, 0.17, 0.15], "floor_alt": [0.16, 0.15, 0.13],
		  "wall": [0.09, 0.09, 0.08], "obstacle": [0.22, 0.20, 0.18], "accent": [0.60, 0.55, 0.40],
		  "prop_set": "urban", "light_color": [0.95, 0.85, 0.65], "light_energy": 2.5,
		  "fog_color": [0.10, 0.09, 0.07], "fog_density": 0.15, "ceiling_style": "vaulted", "wall_style": "brick" },
	4:  { "name": "Volcanic Rift",       "floor": [0.22, 0.08, 0.03], "floor_alt": [0.19, 0.07, 0.02],
		  "wall": [0.10, 0.04, 0.01], "obstacle": [0.30, 0.12, 0.04], "accent": [0.90, 0.40, 0.05],
		  "prop_set": "volcanic", "light_color": [1.0, 0.40, 0.08], "light_energy": 3.8,
		  "fog_color": [0.18, 0.06, 0.02], "fog_density": 0.45, "ceiling_style": "stalactites", "wall_style": "rock" },
	5:  { "name": "Sunken Grotto",       "floor": [0.05, 0.14, 0.24], "floor_alt": [0.04, 0.12, 0.20],
		  "wall": [0.02, 0.06, 0.12], "obstacle": [0.06, 0.16, 0.25], "accent": [0.20, 0.65, 0.80],
		  "prop_set": "aquatic", "light_color": [0.30, 0.70, 0.90], "light_energy": 2.0,
		  "fog_color": [0.03, 0.08, 0.15], "fog_density": 0.5, "ceiling_style": "stalactites", "wall_style": "coral" },
	6:  { "name": "Arcane Sanctum",      "floor": [0.12, 0.06, 0.20], "floor_alt": [0.10, 0.05, 0.17],
		  "wall": [0.05, 0.03, 0.10], "obstacle": [0.18, 0.08, 0.28], "accent": [0.75, 0.35, 0.95],
		  "prop_set": "arcane", "light_color": [0.70, 0.40, 1.0], "light_energy": 2.6,
		  "fog_color": [0.08, 0.04, 0.14], "fog_density": 0.35, "ceiling_style": "vaulted", "wall_style": "crystal" },
	7:  { "name": "Necropolis",          "floor": [0.10, 0.12, 0.07], "floor_alt": [0.08, 0.10, 0.06],
		  "wall": [0.04, 0.06, 0.03], "obstacle": [0.14, 0.16, 0.08], "accent": [0.40, 0.85, 0.35],
		  "prop_set": "necro", "light_color": [0.35, 0.90, 0.30], "light_energy": 2.2,
		  "fog_color": [0.04, 0.06, 0.02], "fog_density": 0.5, "ceiling_style": "none", "wall_style": "bone" },
	8:  { "name": "Frozen Cavern",       "floor": [0.55, 0.68, 0.82], "floor_alt": [0.50, 0.62, 0.78],
		  "wall": [0.35, 0.45, 0.58], "obstacle": [0.40, 0.52, 0.65], "accent": [0.60, 0.82, 0.95],
		  "prop_set": "ice", "light_color": [0.60, 0.80, 1.0], "light_energy": 2.8,
		  "fog_color": [0.20, 0.28, 0.38], "fog_density": 0.35, "ceiling_style": "stalactites", "wall_style": "ice" },
	9:  { "name": "Swamp Bog",           "floor": [0.12, 0.18, 0.08], "floor_alt": [0.10, 0.15, 0.06],
		  "wall": [0.06, 0.10, 0.04], "obstacle": [0.14, 0.20, 0.08], "accent": [0.35, 0.55, 0.18],
		  "prop_set": "swamp", "light_color": [0.55, 0.75, 0.30], "light_energy": 1.8,
		  "fog_color": [0.08, 0.12, 0.05], "fog_density": 0.6, "ceiling_style": "canopy", "wall_style": "wood" },
	10: { "name": "Desert Temple",       "floor": [0.55, 0.45, 0.30], "floor_alt": [0.50, 0.42, 0.28],
		  "wall": [0.40, 0.32, 0.20], "obstacle": [0.48, 0.38, 0.25], "accent": [0.75, 0.60, 0.25],
		  "prop_set": "desert", "light_color": [1.0, 0.90, 0.60], "light_energy": 3.8,
		  "fog_color": [0.30, 0.25, 0.15], "fog_density": 0.2, "ceiling_style": "vaulted", "wall_style": "sand" },
	11: { "name": "Mushroom Hollow",     "floor": [0.15, 0.12, 0.20], "floor_alt": [0.12, 0.10, 0.18],
		  "wall": [0.08, 0.06, 0.12], "obstacle": [0.18, 0.14, 0.25], "accent": [0.60, 0.30, 0.80],
		  "prop_set": "mushroom", "light_color": [0.50, 0.30, 0.85], "light_energy": 2.0,
		  "fog_color": [0.10, 0.06, 0.15], "fog_density": 0.45, "ceiling_style": "stalactites", "wall_style": "rock" },
	12: { "name": "Crystal Mines",       "floor": [0.18, 0.20, 0.28], "floor_alt": [0.15, 0.17, 0.25],
		  "wall": [0.10, 0.12, 0.18], "obstacle": [0.20, 0.22, 0.32], "accent": [0.45, 0.60, 0.95],
		  "prop_set": "crystal", "light_color": [0.50, 0.65, 1.0], "light_energy": 3.0,
		  "fog_color": [0.08, 0.10, 0.18], "fog_density": 0.25, "ceiling_style": "stalactites", "wall_style": "crystal" },
	13: { "name": "Infernal Pit",        "floor": [0.15, 0.05, 0.05], "floor_alt": [0.12, 0.04, 0.04],
		  "wall": [0.08, 0.02, 0.02], "obstacle": [0.20, 0.06, 0.06], "accent": [0.95, 0.25, 0.08],
		  "prop_set": "infernal", "light_color": [1.0, 0.25, 0.05], "light_energy": 3.5,
		  "fog_color": [0.15, 0.03, 0.02], "fog_density": 0.55, "ceiling_style": "none", "wall_style": "rock" },
	14: { "name": "Clockwork Forge",     "floor": [0.20, 0.18, 0.15], "floor_alt": [0.18, 0.16, 0.14],
		  "wall": [0.12, 0.10, 0.08], "obstacle": [0.28, 0.22, 0.16], "accent": [0.70, 0.50, 0.20],
		  "prop_set": "forge", "light_color": [1.0, 0.70, 0.30], "light_energy": 3.2,
		  "fog_color": [0.12, 0.08, 0.04], "fog_density": 0.2, "ceiling_style": "beams", "wall_style": "metal" },
	15: { "name": "Elven Ruins",         "floor": [0.25, 0.30, 0.22], "floor_alt": [0.22, 0.27, 0.20],
		  "wall": [0.15, 0.18, 0.12], "obstacle": [0.20, 0.25, 0.18], "accent": [0.50, 0.72, 0.45],
		  "prop_set": "elven", "light_color": [0.80, 0.95, 0.70], "light_energy": 2.8,
		  "fog_color": [0.12, 0.16, 0.10], "fog_density": 0.2, "ceiling_style": "canopy", "wall_style": "wood" },
	16: { "name": "Sewer Depths",        "floor": [0.14, 0.12, 0.10], "floor_alt": [0.12, 0.10, 0.08],
		  "wall": [0.08, 0.07, 0.06], "obstacle": [0.16, 0.14, 0.12], "accent": [0.40, 0.50, 0.30],
		  "prop_set": "sewer", "light_color": [0.60, 0.70, 0.45], "light_energy": 1.6,
		  "fog_color": [0.06, 0.06, 0.04], "fog_density": 0.55, "ceiling_style": "vaulted", "wall_style": "brick" },
	17: { "name": "Sky Citadel",         "floor": [0.72, 0.75, 0.82], "floor_alt": [0.68, 0.72, 0.80],
		  "wall": [0.55, 0.58, 0.65], "obstacle": [0.60, 0.62, 0.70], "accent": [0.80, 0.85, 1.0],
		  "prop_set": "sky", "light_color": [0.90, 0.95, 1.0], "light_energy": 4.0,
		  "fog_color": [0.50, 0.55, 0.65], "fog_density": 0.15, "ceiling_style": "open", "wall_style": "brick" },
	18: { "name": "Abyssal Void",        "floor": [0.06, 0.04, 0.10], "floor_alt": [0.05, 0.03, 0.08],
		  "wall": [0.03, 0.02, 0.06], "obstacle": [0.08, 0.05, 0.14], "accent": [0.40, 0.15, 0.70],
		  "prop_set": "void", "light_color": [0.45, 0.20, 0.80], "light_energy": 1.8,
		  "fog_color": [0.04, 0.02, 0.08], "fog_density": 0.65, "ceiling_style": "none", "wall_style": "crystal" },
	19: { "name": "Haunted Manor",       "floor": [0.20, 0.16, 0.14], "floor_alt": [0.18, 0.14, 0.12],
		  "wall": [0.12, 0.10, 0.08], "obstacle": [0.22, 0.18, 0.15], "accent": [0.55, 0.40, 0.30],
		  "prop_set": "manor", "light_color": [0.80, 0.60, 0.40], "light_energy": 1.5,
		  "fog_color": [0.08, 0.06, 0.05], "fog_density": 0.5, "ceiling_style": "beams", "wall_style": "wood" },
	20: { "name": "Coral Reef",          "floor": [0.10, 0.25, 0.30], "floor_alt": [0.08, 0.22, 0.28],
		  "wall": [0.06, 0.15, 0.20], "obstacle": [0.12, 0.28, 0.32], "accent": [0.30, 0.70, 0.65],
		  "prop_set": "coral", "light_color": [0.25, 0.65, 0.75], "light_energy": 2.2,
		  "fog_color": [0.05, 0.12, 0.18], "fog_density": 0.5, "ceiling_style": "none", "wall_style": "coral" },
	21: { "name": "Dwarven Stronghold",  "floor": [0.25, 0.20, 0.16], "floor_alt": [0.22, 0.18, 0.14],
		  "wall": [0.15, 0.12, 0.10], "obstacle": [0.28, 0.22, 0.18], "accent": [0.65, 0.45, 0.20],
		  "prop_set": "dwarven", "light_color": [1.0, 0.70, 0.35], "light_energy": 3.2,
		  "fog_color": [0.10, 0.07, 0.04], "fog_density": 0.15, "ceiling_style": "vaulted", "wall_style": "brick" },
	22: { "name": "Blood Sanctum",       "floor": [0.18, 0.05, 0.05], "floor_alt": [0.15, 0.04, 0.04],
		  "wall": [0.10, 0.03, 0.03], "obstacle": [0.22, 0.08, 0.06], "accent": [0.80, 0.15, 0.15],
		  "prop_set": "blood", "light_color": [0.90, 0.20, 0.15], "light_energy": 2.4,
		  "fog_color": [0.12, 0.03, 0.03], "fog_density": 0.4, "ceiling_style": "vaulted", "wall_style": "bone" },
	23: { "name": "Overgrown Ruin",      "floor": [0.15, 0.25, 0.12], "floor_alt": [0.12, 0.22, 0.10],
		  "wall": [0.08, 0.14, 0.06], "obstacle": [0.16, 0.26, 0.10], "accent": [0.40, 0.65, 0.25],
		  "prop_set": "overgrown", "light_color": [0.75, 0.90, 0.55], "light_energy": 2.5,
		  "fog_color": [0.08, 0.14, 0.06], "fog_density": 0.35, "ceiling_style": "canopy", "wall_style": "brick" },
}

func get_terrain_palette() -> Dictionary:
	var sid: int = _dungeon_terrain_style
	if TERRAIN_PALETTES.has(sid):
		return TERRAIN_PALETTES[sid]
	return TERRAIN_PALETTES[0]

func get_dungeon_terrain_name() -> String:
	return _dungeon_terrain_name

const TILE_VOID: int     = 0
const TILE_FLOOR: int    = 1
const TILE_WALL: int     = 2
const TILE_OBSTACLE: int = 3
const MAP_SIZE: int      = 25

# ── Action IDs (mirror mobile ActionType enum) ────────────────────────────────
const ACT_MELEE:        int = 0
const ACT_DODGE:        int = 1
const ACT_REST:         int = 3
const ACT_USE_ITEM:     int = 9
const ACT_CAST_SPELL:   int = 10
const ACT_RANGED:       int = 12
const ACT_UNARMED:      int = 13
const ACT_INTERACT:     int = 14
const ACT_RELOAD:       int = 15
const ACT_ACTIVATE_MTX: int = 16
const ACT_END_MTX:      int = 17
const ACT_GRAPPLE:      int = 18
const ACT_ESC_GRAPPLE:  int = 19
const ACT_HIDE:         int = 20
const ACT_EXTRA_MOVE:   int = 22
const ACT_TRAIT:        int = 50
const ACT_FLY_TOGGLE:       int = 60
const ACT_FLY_LAND:         int = 61
const ACT_FLY_ASCEND:       int = 62
const ACT_FLY_DESCEND:      int = 63
const ACT_SHAPESHIFT:       int = 70
const ACT_REVERT_SHAPESHIFT:int = 71
const ACT_SUMMON_FEAT:      int = 72
const ACT_DISMISS_CONSTRUCT:int = 73
const ACT_RECALL_CONSTRUCT: int = 74
const ACT_REFORM_CONSTRUCT: int = 75

# ── Spell database (mirrors SpellRegistry.h) ──────────────────────────────────
# Fields: sc=sp_cost, dom=domain, rt=range_tiles, atk=is_attack,
#         dc=die_count, ds=die_sides, heal=is_healing, conds=conditions[],
#         dur=duration_rounds, mt=max_targets, area=area_type(0-3), tp=is_teleport
static var _SPELL_DB: Dictionary = {}
static var _spell_db_ready: bool = false

static func _ensure_spell_db() -> void:
	if _spell_db_ready: return
	_spell_db_ready = true
	_SPELL_DB = {
		# ── Biological ──
		"Healing Touch":      {"sc":6,  "dom":"Biological","rt":1,  "atk":false,"dc":2,"ds":8, "heal":true, "conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Touch a creature and restore 2d8 hit points."},
		"Aura of Restoration":{"sc":6,  "dom":"Biological","rt":0,  "atk":false,"dc":1,"ds":6, "heal":true, "conds":[],            "dur":0,    "mt":10,"area":2,"tp":false,"desc":"All allies in a 30-foot burst are healed for 1d6 hit points."},
		"Chain Mend":         {"sc":8,  "dom":"Biological","rt":6,  "atk":false,"dc":1,"ds":4, "heal":true, "conds":[],            "dur":0,    "mt":3, "area":0,"tp":false,"desc":"Up to three targets within 30 feet are each healed for 1d4."},
		"Healing Light":      {"sc":2,  "dom":"Biological","rt":1,  "atk":false,"dc":1,"ds":6, "heal":true, "conds":[],            "dur":10,   "mt":1, "area":0,"tp":false,"desc":"Heals a target by 1d6 per action for 10 rounds."},
		"Claw Swipe":         {"sc":6,  "dom":"Biological","rt":1,  "atk":true, "dc":1,"ds":8, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"dt":"slashing","desc":"Transform hands into claws; natural weapon attack."},
		"Undead Squirrel":    {"sc":10, "dom":"Biological","rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":14400,"mt":1, "area":0,"tp":false,"desc":"Animate a venomous undead squirrel companion."},
		"Perma-Heal":         {"sc":20, "dom":"Biological","rt":1,  "atk":false,"dc":1,"ds":4, "heal":true, "conds":[],            "dur":14400,"mt":1, "area":0,"tp":false,"desc":"Target regains 1d4 HP at start of turn for the whole day."},
		"Littlest Healing":   {"sc":2,  "dom":"Biological","rt":1,  "atk":false,"dc":2,"ds":4, "heal":true, "conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Touch a creature to restore 2d4 hit points."},
		"Revivify":           {"sc":10, "dom":"Biological","rt":1,  "atk":false,"dc":0,"ds":0, "heal":true, "conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Touch a dead creature; restore it to life at 1 HP."},
		# ── Chemical ──
		"Searing Ray":        {"sc":7,  "dom":"Chemical",  "rt":20, "atk":true, "dc":2,"ds":8, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"dt":"fire","desc":"A ray of fire deals 2d8 damage to a single target."},
		"Fireburst":          {"sc":2,  "dom":"Chemical",  "rt":6,  "atk":true, "dc":1,"ds":6, "heal":false,"conds":[],            "dur":0,    "mt":10,"area":2,"tp":false,"dt":"fire","desc":"All creatures in a 30-foot area take 1d6 fire damage."},
		"Fireball":           {"sc":69, "dom":"Chemical",  "rt":20, "atk":true, "dc":5,"ds":10,"heal":false,"conds":[],            "dur":0,    "mt":20,"area":2,"tp":false,"dt":"fire","desc":"Deals 5d10 fire damage in a 30ft area."},
		"Flaming Attacks":    {"sc":15, "dom":"Chemical",  "rt":0,  "atk":false,"dc":2,"ds":6, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"dt":"fire","desc":"Enchant attacks to deal +2d6 fire damage for 10 minutes."},
		"Create Bread":       {"sc":4,  "dom":"Chemical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Catalyze a reaction to create an edible substance."},
		"Solid to Liquid":    {"sc":4,  "dom":"Chemical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":1,    "mt":1, "area":0,"tp":false,"desc":"Change a lock to liquid metal for 1 round."},
		"Fog Generation":     {"sc":4,  "dom":"Chemical",  "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":1,"tp":false,"desc":"Generate a dense fog in a 10-foot cube within 30 feet."},
		"Condense Water":     {"sc":4,  "dom":"Chemical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Produce 1 liter of water from surrounding air."},
		"Littlest Combustion":{"sc":7,  "dom":"Chemical",  "rt":6,  "atk":true, "dc":1,"ds":8, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":1,"tp":false,"dt":"force","desc":"Cause a 5ft cube to violently combust (1d8 force)."},
		# ── Physical ──
		"Arcane Force Field": {"sc":9,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["shielded"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Shimmering barrier: +2 AC for 10 minutes."},
		"Shadow Veil":        {"sc":5,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["invisible"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Become invisible for 10 minutes in darkness."},
		"Wings of the Shattered Gods":{"sc":15,"dom":"Physical","rt":0,"atk":false,"dc":0,"ds":0,"heal":false,"conds":["flying"],  "dur":600,  "mt":1, "area":0,"tp":false,"desc":"Sprout ethereal wings and fly for 1 hour."},
		"Stoneskin":          {"sc":7,  "dom":"Physical",  "rt":1,  "atk":false,"dc":2,"ds":4, "heal":false,"conds":["stoneskin"],"dur":100,  "mt":1, "area":0,"tp":false,"desc":"Skin hardens, reducing damage for 10 minutes."},
		"Intangibility":      {"sc":4,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["intangible"],"dur":10,  "mt":1, "area":0,"tp":false,"desc":"Become intangible; resistance to non-magical damage."},
		"Chain Lightning":    {"sc":11, "dom":"Physical",  "rt":20, "atk":true, "dc":1,"ds":4, "heal":false,"conds":[],            "dur":0,    "mt":3, "area":0,"tp":false,"dt":"lightning","desc":"Up to three targets each take 1d4 lightning damage."},
		"Lightning Bolt":     {"sc":12, "dom":"Physical",  "rt":20, "atk":true, "dc":3,"ds":4, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"dt":"lightning","desc":"Hurls a bolt of lightning at a foe (3d4 damage)."},
		"Frost Lance":        {"sc":3,  "dom":"Physical",  "rt":6,  "atk":true, "dc":2,"ds":4, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"dt":"cold","desc":"Hurl a spear of ice dealing 2d4 cold damage."},
		"Teleport":           {"sc":0,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":true, "desc":"Teleport yourself to a visible tile. SP cost scales with distance."},
		"Teleport Other":     {"sc":0,  "dom":"Physical",  "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":true, "desc":"Teleport a target to a visible tile. SP scales with distance."},
		"Telekinesis: Move":  {"sc":0,  "dom":"Physical",  "rt":6,  "atk":false,"dc":0,"ds":4, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Move an object or creature telekinetically."},
		"Telekinesis: Hover": {"sc":0,  "dom":"Physical",  "rt":6,  "atk":false,"dc":0,"ds":4, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Hover an object or creature vertically."},
		"Telekinesis: Animate Weapon":     {"sc":2, "dom":"Physical","rt":6, "atk":false,"dc":0,"ds":0,"heal":false,"conds":[],"dur":100,"mt":1,"area":0,"tp":false,"desc":"Animate a weapon to auto-attack once per round."},
		"Telekinesis: Animate Shield":     {"sc":2, "dom":"Physical","rt":0, "atk":false,"dc":0,"ds":0,"heal":false,"conds":[],"dur":100,"mt":1,"area":0,"tp":false,"desc":"Animate a standard shield to defend you."},
		"Telekinesis: Animate Tower Shield":{"sc":4,"dom":"Physical","rt":0, "atk":false,"dc":0,"ds":0,"heal":false,"conds":[],"dur":100,"mt":1,"area":0,"tp":false,"desc":"Animate a tower shield to defend you."},
		"Telekinesis: Flight":{"sc":4,  "dom":"Physical",  "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["flying"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Grant a creature a 30 ft flight speed."},
		# ── Spiritual ──
		"Scrying Eye":        {"sc":15, "dom":"Spiritual", "rt":100,"atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":10,   "mt":1, "area":0,"tp":false,"desc":"See and hear a distant location for 1 minute."},
		"Mind Link":          {"sc":7,  "dom":"Spiritual", "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["charmed"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Caster and a willing target communicate telepathically."},
		"Detect Magic":       {"sc":10, "dom":"Spiritual", "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":10,   "mt":1, "area":0,"tp":false,"desc":"Perceive and identify magic effects within 30 feet."},
		"Unconscious Touch":  {"sc":30, "dom":"Spiritual", "rt":1,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["unconscious"],"dur":100, "mt":1, "area":0,"tp":false,"desc":"Curse a target to fall unconscious for 10 minutes."},
		"Mind Shackle":       {"sc":13, "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["charmed"],   "dur":10,   "mt":1, "area":0,"tp":false,"desc":"Briefly dominate a target's will (1 minute)."},
		"Conjure damage or healing":{"sc":1,"dom":"Spiritual","rt":1,"atk":true,"dc":1,"ds":6,"heal":false,"conds":[],             "dur":100,  "mt":1, "area":0,"tp":false,"dt":"radiant","desc":"Manifest spiritual energy to harm or heal."},
		"Light":              {"sc":2,  "dom":"Spiritual", "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Conjure magical light illuminating 120ft for 10 minutes."},
		"Bless: Dodging":     {"sc":2,  "dom":"Spiritual", "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["dodging"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Bless an ally; enemies have disadvantage attacking them."},
		"Bless: Calm":        {"sc":3,  "dom":"Spiritual", "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["calm"],      "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Bless a willing target with calm."},
		"Bless: Hidden":      {"sc":3,  "dom":"Spiritual", "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["hidden"],    "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Bless an ally with concealment."},
		"Bless: Invisible":   {"sc":4,  "dom":"Spiritual", "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["invisible"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Bless an ally with true invisibility."},
		"Bless: Invulnerable":{"sc":11, "dom":"Spiritual", "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["invulnerable"],"dur":100,"mt":1, "area":0,"tp":false,"desc":"Bless an ally with divine invulnerability."},
		"Bless: Resistant":   {"sc":6,  "dom":"Spiritual", "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["resistant"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Bless an ally with resistance to damage."},
		"Bless: Silent":      {"sc":4,  "dom":"Spiritual", "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["silent"],    "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Bless an ally with silence."},
		"Curse: Bleed":       {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["bleeding"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target to bleed; 1d4 damage per turn. Stacks."},
		"Curse: Blinded":     {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["blinded"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with blindness."},
		"Curse: Charmed":     {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["charmed"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with charm."},
		"Curse: Confused":    {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["confused"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with confusion; double AP costs."},
		"Curse: Dazed":       {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["dazed"],     "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with daze; one action per turn."},
		"Curse: Deafened":    {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["deafened"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with deafness."},
		"Curse: Depleted":    {"sc":5,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["depleted"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target; they don't regain AP automatically."},
		"Curse: Enraged":     {"sc":1,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["enraged"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with enrage; must focus on you."},
		"Curse: Exhausted":   {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["exhausted"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with exhaustion."},
		"Curse: Fever":       {"sc":4,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["fever"],     "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with fever; disadvantage on attacks."},
		"Curse: Frightened":  {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["frightened"],"dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with fear."},
		"Curse: Poisoned":    {"sc":3,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["poisoned"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with poison."},
		"Curse: Prone":       {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["prone"],     "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target to fall prone."},
		"Curse: Restrained":  {"sc":4,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["restrained"],"dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with restraint; they cannot move."},
		"Curse: Slowed":      {"sc":1,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["slowed"],    "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with slowness; half speed."},
		"Curse: Stunned":     {"sc":3,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["stunned"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with stun; double AP to act."},
		"Curse: Vulnerable":  {"sc":10, "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["vulnerable"],"dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with vulnerability; double damage."},
		# ── Missing PHB Biological spells ──
		"Augment Trait":      {"sc":1,  "dom":"Biological","rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["augmented"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Increase or decrease a stat by +1 per SP spent."},
		"Enhanced Senses":    {"sc":2,  "dom":"Biological","rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["enhanced_senses"],"dur":100,"mt":1,"area":0,"tp":false,"desc":"Advantage on perception checks; 4 SP for blindsight."},
		"Health Regeneration":{"sc":5,  "dom":"Biological","rt":1,  "atk":false,"dc":2,"ds":6, "heal":true, "conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Target regenerates 2d6 HP per turn for 10 minutes."},
		"Memory Edit":        {"sc":4,  "dom":"Biological","rt":1,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["charmed"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Alter, erase, or implant a short memory in a creature."},
		"Mind Control":       {"sc":13, "dom":"Biological","rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["charmed"],   "dur":10,   "mt":1, "area":0,"tp":false,"desc":"Control a creature's actions for 1 minute."},
		"Mutate: Claws":      {"sc":6,  "dom":"Biological","rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["mutated"],   "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Grow claws; gain natural weapon (1d6 slashing)."},
		"Mutate: Wings":      {"sc":8,  "dom":"Biological","rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["flying"],    "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Grow wings; gain a fly speed equal to walking speed."},
		"Mutate: Gills":      {"sc":4,  "dom":"Biological","rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Breathe underwater for 10 minutes."},
		"Shapeshift":         {"sc":4,  "dom":"Biological","rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["shapeshifted"],"dur":100,"mt":1, "area":0,"tp":false,"desc":"Modify willing creature's form: size, limbs, or appearance."},
		"Terrain Manipulation":{"sc":1, "dom":"Biological","rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":1,"tp":false,"desc":"Grow plants/roots in a 5ft cube: cover, difficult terrain, or barriers."},
		"Animate Undead":     {"sc":3,  "dom":"Biological","rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":14400,"mt":1, "area":0,"tp":false,"desc":"Animate a corpse as an undead minion for 1 day."},
		"Weather Resistance": {"sc":1,  "dom":"Biological","rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":600,  "mt":1, "area":0,"tp":false,"desc":"Decrease temperature effect on a creature; +/-1 TRR per SP."},
		# ── Missing PHB Chemical spells ──
		"Alter Chemical Structure":{"sc":4,"dom":"Chemical","rt":1, "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Catalyze a reaction or change chemical structures in a 1ft cube."},
		"Combustion":         {"sc":4,  "dom":"Chemical",  "rt":1,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":1,"tp":false,"dt":"force","combustion":true,"desc":"Cause a 5ft cube to combust. Damage = half total SP on the scaling table."},
		"Damage Object":      {"sc":1,  "dom":"Chemical",  "rt":1,  "atk":false,"dc":1,"ds":4, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Deal 1 HP per SP to a non-magical object (bypasses threshold)."},
		"Mend Object":        {"sc":2,  "dom":"Chemical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Repair 1 HP per 2 SP on an object or weapon."},
		"Remove Grime":       {"sc":1,  "dom":"Chemical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":10,   "mt":1, "area":0,"tp":false,"desc":"Clean a willing creature or object; takes 1 minute."},
		"State Change":       {"sc":4,  "dom":"Chemical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":1,    "mt":1, "area":0,"tp":false,"desc":"Shift matter between solid/liquid/gas/plasma in a 1ft cube."},
		"Transmutation":      {"sc":40, "dom":"Chemical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Alter atomic structure of a 1ft cube; half material consumed."},
		# ── Missing PHB Physical spells ──
		"Accuracy Boost":     {"sc":1,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["accurate"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Increase attack bonus by +1 per SP (scaling cost: +1=1, +2=3, +3=5)."},
		"Ambient Temperature":{"sc":1,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":1,"tp":false,"desc":"Change temperature by 1°F per SP in an area."},
		"Create Construct":   {"sc":2,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"construct":true,"desc":"Create inanimate construct: walls, weapons, armor, shields, or clothing. Builder opens at cast time."},
		"Construct Weapon":   {"sc":2,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Create a light weapon of force (2 SP light, 3 martial, 4 heavy)."},
		"Construct Armor":    {"sc":2,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["shielded"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Create force armor (2 light, 3 medium, 4 heavy)."},
		"Damage Output Increase":{"sc":1,"dom":"Physical", "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["empowered"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Increase damage by +1 per SP (scaling: +1=1, +2=3, +3=5)."},
		"Damage Reduction":   {"sc":6,  "dom":"Physical",  "rt":0,  "atk":false,"dc":2,"ds":6, "heal":false,"conds":["stoneskin"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Reduce damage taken by 2d6 per instance for 10 minutes."},
		"Create Illusion":    {"sc":2,  "dom":"Physical",  "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Create a visual illusion of a medium creature or object."},
		"Dispel Illusion":    {"sc":3,  "dom":"Physical",  "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Make an invisible or hidden thing visible."},
		"Create Light":       {"sc":2,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":1,"tp":false,"desc":"Illuminate a 5ft cube with magical light; cancels lesser darkness."},
		"Create Darkness":    {"sc":2,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":1,"tp":false,"desc":"Fill a 5ft cube with magical darkness; cancels lesser light."},
		"Shield":             {"sc":1,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["shielded"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Increase AC by +1 per SP (scaling: +1=1, +2=3, +3=5)."},
		"Time Reroll":        {"sc":2,  "dom":"Physical",  "rt":0,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Reroll a failed check as a reaction (2 SP)."},
		"Time Haste":         {"sc":5,  "dom":"Physical",  "rt":1,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":["hasted"],    "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Reduce action costs by 1 (min 0) for 10 minutes."},
		"Time Freeze":        {"sc":10, "dom":"Physical",  "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["frozen_time"],"dur":100, "mt":1, "area":0,"tp":false,"desc":"Freeze a target in time; immune to damage, cannot act."},
		# ── Missing PHB Spiritual spells ──
		"Suppress Magic":     {"sc":3,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":[],            "dur":0,    "mt":1, "area":0,"tp":false,"desc":"Counteract or suppress a magical effect (2 SP + half target SP)."},
		"Summon Creature":    {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"summon":true,"desc":"Summon a creature; 1 SP per stat point. Builder opens at cast time."},
		"Telepathy":          {"sc":7,  "dom":"Spiritual", "rt":6,  "atk":false,"dc":0,"ds":0, "heal":false,"conds":[],            "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Communicate telepathically with a willing target for 10 min."},
		"Curse: Incapacitated":{"sc":7, "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["incapacitated"],"dur":100,"mt":1,"area":0,"tp":false,"desc":"Target is unable to attack or defend."},
		"Curse: Paralyzed":   {"sc":6,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["paralyzed"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Target cannot move; attacks auto-hit."},
		"Curse: Petrified":   {"sc":8,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["petrified"], "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Target is turned to stone and cannot act."},
		"Curse: Grappled":    {"sc":2,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["grappled"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Magically restrain a target."},
		"Curse: Silent":      {"sc":3,  "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["silent"],    "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse a target with silence; cannot speak or cast verbal spells."},
		"Curse: Squeeze":     {"sc":10, "dom":"Spiritual", "rt":6,  "atk":true, "dc":0,"ds":0, "heal":false,"conds":["squeezed"],  "dur":100,  "mt":1, "area":0,"tp":false,"desc":"Curse target with crushing force; 1d4 bludgeoning per turn."},
	}

# ═══════════════════════════════════════════════════════════════════════════════
# DUNGEON API
# ═══════════════════════════════════════════════════════════════════════════════

# ── DungeonAction factory ─────────────────────────────────────────────────────
## Returns a DungeonAction dictionary with all required fields.
## action_id values match ACT_* constants above.
func _make_action(
		p_name: String, p_type: String, p_action_id: int, p_ap_cost: int,
		p_sp_cost: int = 0, p_is_attack: bool = false, p_is_ranged: bool = false,
		p_matrix_id: String = "", p_area_type: int = 0, p_max_targets: int = 1,
		p_is_teleport: bool = false, p_range_idx: int = 1,
		p_description: String = "") -> Dictionary:
	return {
		"name":        p_name,
		"type":        p_type,       # "Weapon","Spell","Ability","Item","Matrix","Trait"
		"action_id":   p_action_id,
		"ap_cost":     p_ap_cost,
		"sp_cost":     p_sp_cost,
		"is_attack":   p_is_attack,
		"is_ranged":   p_is_ranged,
		"matrix_id":   p_matrix_id,  # spell/trait/feat identifier string
		"area_type":   p_area_type,  # 0=single,1=cone,2=line,3=circle
		"max_targets": p_max_targets,
		"is_teleport": p_is_teleport,
		"range_idx":   p_range_idx,  # 0=self,1=melee,2=short,3=long
		"description": p_description,
	}

# ── Dungeon init ──────────────────────────────────────────────────────────────
func start_dungeon(player_handles, enemy_level: int,
		specific_enemy_handle: int, terrain_style: int) -> void:
	_dungeon_active       = true
	_dungeon_round        = 1
	_dungeon_enemy_level  = maxi(1, enemy_level)
	_dungeon_is_player_phase = true
	_dungeon_type         = 0
	_dungeon_encounter_name = "Standard Encounter"
	_dungeon_terrain_style  = clampi(terrain_style, 0, 7)
	_dungeon_terrain_name   = TERRAIN_PALETTES.get(_dungeon_terrain_style, TERRAIN_PALETTES[0]).get("name", "Unknown")
	_dungeon_loot.clear()
	_dungeon_entities.clear()
	_dungeon_player_queue.clear()
	_dungeon_matrices.clear()
	_trait_cooldowns.clear()
	_dungeon_ammo.clear()
	_dungeon_queue_idx = 0

	_dungeon_elevation = PackedInt32Array()
	_dungeon_elevation.resize(MAP_SIZE * MAP_SIZE)
	_dungeon_elevation.fill(1)

	_dungeon_fog = PackedByteArray()
	_dungeon_fog.resize(MAP_SIZE * MAP_SIZE)
	_dungeon_fog.fill(0)

	_dungeon_map = _gen_dungeon_map()  # also populates _dungeon_elevation

	# ── Place players (start room, top-left) ──────────────────────────────────
	var p_spawns: Array = [[3,3],[4,3],[3,4],[4,4],[5,3],[3,5]]
	# Collect already-occupied tiles to avoid stacking
	var _occupied_tiles: Dictionary = {}
	var pi: int = 0
	for h in player_handles:
		if not _chars.has(h): continue
		var c: Dictionary = _chars[h]
		var pos: Array = p_spawns[pi % p_spawns.size()]
		pi += 1
		# Ensure spawn tile is a walkable floor and not already occupied
		pos = _find_nearest_floor(pos[0], pos[1], _occupied_tiles)
		_occupied_tiles[Vector2i(pos[0], pos[1])] = true
		var eid: String = "player_%d" % h
		_dungeon_entities.append({
			# Identity
			"id":             eid,
			"name":           c["name"],
			"handle":         h,
			"lineage_name":   c["lineage"],
			# Position
			"x": pos[0], "y": pos[1], "z": 0,
			# Team flags
			"is_player":   true,
			"is_friendly": true,
			"is_dead":     false,
			"is_flying":   false,
			# Stats
			"hp":     c["hp"],         "max_hp":  c["max_hp"],
			"ap":     c["max_ap"],     "max_ap":  c["max_ap"],
			"sp":     c["sp"],         "max_sp":  c["max_sp"],
			"ac":     int(c["ac"]) + int(c.get("feat_ac_bonus", 0)),
			"speed":  c.get("speed", 6),
			# Turn tracking (reset each round)
			"ap_spent":    0,   # total AP spent this turn
			"actions_taken": 0, # escalating cost: Nth action costs N AP
			"move_used":   0,   # tiles moved this turn (capped by speed)
			"hit_bonus_buff": 0,  # cleared each dungeon; set by trait activations
			"hit_penalty":   int(c.get("hit_penalty", 0)),
			# Equipment (mirrors character sheet)
			"equipped_weapon": c.get("weapon", "None"),
			"equipped_armor":  c.get("armor",  "None"),
			"equipped_shield": c.get("shield", "None"),
			"equipped_light":  c.get("light",  "None"),
			# Active status conditions
			"conditions": [],   # e.g. ["grappled","dodging","hidden","flying"]
		})
		_dungeon_player_queue.append(eid)

	# ── Place enemies via encounter budget system (GMG) ──────────────────────
	# Build a list of all walkable floor tiles for random enemy placement
	var _floor_tiles: Array = []
	for fy in range(MAP_SIZE):
		for fx in range(MAP_SIZE):
			if _dungeon_map[fy * MAP_SIZE + fx] == 0:  # 0 = floor
				_floor_tiles.append([fx, fy])
	var encounter: Array = _build_encounter(_dungeon_enemy_level, 1)  # 1=Medium
	for i in range(encounter.size()):
		var cr: Dictionary = encounter[i]
		# Pick a random floor tile anywhere on the map (including near players)
		var epos: Array = [12, 12]  # fallback center
		if not _floor_tiles.is_empty():
			var pick_idx: int = randi() % _floor_tiles.size()
			epos = _floor_tiles[pick_idx]
		epos = _find_nearest_floor(epos[0], epos[1], _occupied_tiles)
		_occupied_tiles[Vector2i(epos[0], epos[1])] = true
		var cat: int = int(cr["category"])
		var lv: int  = int(cr["level"])
		var total_pts: int = _creature_stat_points(cat, lv)
		var cr_stats: Array = _creature_distribute_stats(total_pts, cat)
		var cr_str: int = int(cr_stats[0])
		var cr_spd: int = int(cr_stats[1])
		var cr_vit: int = int(cr_stats[3])
		var cr_div: int = int(cr_stats[4])
		var ehp: int     = _creature_max_hp(cat, lv, cr_vit)
		var e_ap_max: int = _creature_max_ap(cat, lv, cr_str)
		var e_sp_max: int = _creature_max_sp(cat, lv, cr_div)
		var e_ac: int    = _creature_calc_ac(cat, lv, cr_spd)
		var e_spd: int   = _creature_speed_tiles(cat, cr_spd)
		var e_threshold: int = _creature_damage_threshold(cat, lv)
		var e_abilities: Array = _creature_default_abilities(cat, lv, cr_stats)
		var e_name: String = str(cr["name"])
		if GMG_MONSTER_ABILITIES.has(e_name):
			for ab in GMG_MONSTER_ABILITIES[e_name]:
				e_abilities.append(ab)
		var e_weapon: String = "Rusty Sword"
		match cat:
			0: e_weapon = CREATURE_WEAPONS_ANIMAL[randi() % CREATURE_WEAPONS_ANIMAL.size()]
			1: e_weapon = CREATURE_WEAPONS_VILLAGER[randi() % CREATURE_WEAPONS_VILLAGER.size()]
			_: e_weapon = CREATURE_WEAPONS_MONSTER[randi() % CREATURE_WEAPONS_MONSTER.size()]
		_dungeon_entities.append({
			"id":           "enemy_%d" % i,
			"name":         e_name,
			"handle":       -1,
			"lineage_name": e_name,  # Use creature name for portrait matching
			"x": epos[0], "y": epos[1], "z": 0,
			"is_player":   false,
			"is_friendly": false,
			"is_dead":     false,
			"is_flying":   false,
			"hp":    ehp,    "max_hp": ehp,
			"ap":    e_ap_max, "max_ap": e_ap_max,
			"sp":    e_sp_max, "max_sp": e_sp_max,
			"ac":    e_ac,
			"speed": e_spd,
			"ap_spent":  0,
			"actions_taken": 0,
			"move_used": 0,
			"equipped_weapon": e_weapon,
			"equipped_armor":  "None",
			"equipped_shield": "None",
			"equipped_light":  "None",
			"conditions":    [],
			"abilities":     e_abilities,
			"ability_cooldowns": {},
			"threshold":     e_threshold,
			"stats":         cr_stats,
			"category":      cat,
			"creature_level": lv,
			"immunities":    [],
			"resistances":   [],
			"legendary_uses": (cr_vit if cat >= 4 else 0),
			"morale":        4,
			"inventory":     _generate_creature_loot(lv),
			"looted":        false,
		})

	# Initial fog reveal from player starting positions
	_update_fog()

## Spawn recruited allies into the active dungeon as friendly entities.
## Called after start_dungeon / start_kaiju_dungeon / etc.
## allies: Array of ally dicts from GameState.recruited_allies
func spawn_allies(allies: Array) -> void:
	if not _dungeon_active: return
	# Find open spawn positions near player start (top-left cluster)
	var ally_spawns: Array = [
		[4,2],[5,2],[4,3],[5,3],[3,2],[6,2],[4,4],[5,4],[3,3],[6,3],
		[3,4],[6,4],[2,2],[7,2],[2,3],[7,3],
	]
	# Build occupied set from existing entities
	var ally_occ: Dictionary = {}
	for ent in _dungeon_entities:
		ally_occ[Vector2i(int(ent["x"]), int(ent["y"]))] = true
	for i in range(allies.size()):
		var ally: Dictionary = allies[i]
		var pos: Array = ally_spawns[i % ally_spawns.size()]
		# Ensure spawn is on a walkable floor and not occupied
		pos = _find_nearest_floor(pos[0], pos[1], ally_occ)
		ally_occ[Vector2i(pos[0], pos[1])] = true
		var eid: String = "ally_%d" % i
		var ally_hp: int   = int(ally.get("hp", 30))
		var ally_maxhp: int = int(ally.get("max_hp", ally_hp))
		var ally_ac: int   = int(ally.get("ac", 14))
		var ally_speed: int = int(ally.get("speed", 5))
		var ally_level: int = int(ally.get("level", 1))
		var ally_type: String = str(ally.get("type", "militia"))
		var ally_name: String = str(ally.get("name", "Allied %s" % ally_type.capitalize()))
		# Determine lineage appearance (kaijus get special lineage; militia/mob get generic)
		var lineage_vis: String = "Ironhide" if ally_type == "kaiju" else "Ferrusk"
		var weapon_vis: String  = "Iron Sword" if ally_type != "mob" else "None"
		var armor_vis: String   = "Plate Armor" if ally_type == "kaiju" else ("Chain Mail" if ally_type == "militia" else "None")
		var ally_stats: Array = [
			int(ally.get("str", 3)),
			int(ally.get("spd", 3)),
			int(ally.get("int", 1)),
			int(ally.get("vit", 3)),
			int(ally.get("div", 1)),
		]
		var ally_max_ap: int = int(ally.get("max_ap", 8))
		_dungeon_entities.append({
			"id":           eid,
			"name":         ally_name,
			"handle":       -1,
			"lineage_name": lineage_vis,
			"x": pos[0], "y": pos[1], "z": 0,
			"is_player":   true,    # allies are player-controlled
			"is_friendly": true,
			"is_dead":     false,
			"is_flying":   false,
			"hp":    ally_hp,   "max_hp": ally_maxhp,
			"ap":    ally_max_ap, "max_ap": ally_max_ap,
			"sp":    ally_level * 2, "max_sp": ally_level * 2,
			"ac":    ally_ac,
			"speed": ally_speed,
			"ap_spent":  0,
			"actions_taken": 0,
			"move_used": 0,
			"hit_bonus_buff": int(ally.get("dmg_bonus", 0)),
			"hit_penalty":    0,
			"equipped_weapon": weapon_vis,
			"equipped_armor":  armor_vis,
			"equipped_shield": "None",
			"equipped_light":  "None",
			"conditions": [],
			"ally_type":  ally_type,
			"members":    int(ally.get("members", 1)),
			"trait":      str(ally.get("trait", "")),
			"stats":      ally_stats,
			"abilities":  Array(ally.get("abilities", [])),
			"ability_cooldowns": {},
		})
		_dungeon_player_queue.append(eid)

func end_dungeon() -> void:
	_dungeon_active = false
	_dungeon_entities.clear()
	_dungeon_player_queue.clear()

# ── Dungeon state queries ─────────────────────────────────────────────────────
func get_dungeon_map() -> PackedInt32Array:
	return _dungeon_map

func get_dungeon_elevation_map() -> PackedInt32Array:
	return _dungeon_elevation

## Legacy alias kept for any existing callers.
func get_dungeon_elevation() -> PackedInt32Array:
	return _dungeon_elevation

## Returns fog-of-war state: 0=unseen, 1=remembered, 2=visible.
func get_dungeon_fog() -> PackedByteArray:
	return _dungeon_fog

## Recompute fog from all living players' line-of-sight.
## Called after start_dungeon, after any player move, and at round start.
func _update_fog() -> void:
	# Step 1: demote all currently-visible tiles to "remembered" (1).
	for i in range(_dungeon_fog.size()):
		if _dungeon_fog[i] == 2:
			_dungeon_fog[i] = 1

	# Step 2: compute visible set from each living player.
	for ent in _dungeon_entities:
		if not bool(ent["is_player"]) or bool(ent["is_dead"]): continue
		var cx: int = int(ent["x"])
		var cy: int = int(ent["y"])
		var ez: int = int(ent.get("z", 1))
		var radius: float = float(BASE_VISION_RADIUS)

		# ── Light source modifier ──────────────────────────────────────────────
		# Radii are in "tiles" where 1 tile ≈ 5 ft.  Mobile parity values:
		#   Torch    18 ft → 3.6 tiles extra   (+4 over base)
		#   Lantern  24 ft → 4.8 tiles extra   (+6 over base)
		#   Candle   12 ft → 2.4 tiles extra   (+1 over base)
		# Characters without a light source in a dungeon get no bonus.
		var light_item: String = str(ent.get("equipped_light", "None")).to_lower()
		if "lantern" in light_item:
			radius += 6.0
		elif "torch" in light_item:
			radius += 4.0
		elif "candle" in light_item:
			radius += 1.0

		# Elevation adjustments
		if ez == 2:
			radius = radius * 1.5
		elif ez == 0:
			radius = maxf(1.0, radius * 0.5)
		var irad: int = int(radius)
		var visible_set: Array = _compute_visible_tiles(cx, cy, irad)
		for idx in visible_set:
			_dungeon_fog[idx] = 2

## Compute the set of tile indices visible from (cx, cy) with given radius.
## Uses a simple ray-cast: for each tile within the square, trace a Bresenham
## line from the viewer; if any blocking tile (wall/void/obstacle) is hit
## before reaching the target, the target is obscured.
func _compute_visible_tiles(cx: int, cy: int, radius: int) -> Array:
	var result: Array = []
	var r2: float = float(radius * radius)
	for ty in range(cy - radius, cy + radius + 1):
		for tx in range(cx - radius, cx + radius + 1):
			if tx < 0 or tx >= MAP_SIZE or ty < 0 or ty >= MAP_SIZE: continue
			# Circular radius check (Euclidean)
			var dx: float = float(tx - cx)
			var dy: float = float(ty - cy)
			if dx * dx + dy * dy > r2: continue
			# Bresenham LOS from (cx,cy) to (tx,ty)
			if _los_clear(cx, cy, tx, ty):
				result.append(ty * MAP_SIZE + tx)
	return result

## Returns true if there is an unobstructed line of sight from (x0,y0) to (x1,y1).
## Uses Bresenham's line algorithm; walls and void tiles block vision.
func _los_clear(x0: int, y0: int, x1: int, y1: int) -> bool:
	# Viewer's own tile is always visible
	if x0 == x1 and y0 == y1: return true
	var sx: int = 1 if x1 >= x0 else -1
	var sy: int = 1 if y1 >= y0 else -1
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var x: int = x0
	var y: int = y0
	var err: int = dx - dy
	var steps: int = 0
	var max_steps: int = dx + dy + 2
	while steps < max_steps:
		steps += 1
		if x == x1 and y == y1: return true
		var tile: int = _dung_tile(x, y)
		# Intermediate tiles: block if wall/void (the origin tile itself is transparent)
		if (x != x0 or y != y0) and (tile == TILE_VOID or tile == TILE_WALL):
			return false
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return true

func get_dungeon_entities() -> Array:
	var result: Array = _dungeon_entities.duplicate(true)
	for ent in result:
		ent["matrices"] = get_active_matrix_dicts(str(ent["id"]))
		# Inject per-entity fog visibility (2 = currently visible)
		var ex: int = int(ent["x"])
		var ey: int = int(ent["y"])
		var fog_idx: int = ey * MAP_SIZE + ex
		ent["fog_visible"] = (_dungeon_fog.size() > fog_idx) and (_dungeon_fog[fog_idx] == 2)
		# Sync entity z to terrain elevation at its tile
		if _dungeon_elevation.size() > fog_idx:
			ent["z"] = int(_dungeon_elevation[fog_idx])
	return result

func is_dungeon_player_phase() -> bool:
	return _dungeon_is_player_phase

func get_dungeon_round() -> int:
	return _dungeon_round

func get_dungeon_type() -> int:
	return _dungeon_type

func get_dungeon_encounter_name() -> String:
	return _dungeon_encounter_name

## Check whether the dungeon is over.
## Returns "ongoing", "victory" (all enemies dead), or "defeat" (all players dead).
## Allies (is_friendly=true, is_player=false) count as friendly — their death
## does not cause defeat, and they are excluded from enemy counts.
func check_dungeon_outcome() -> String:
	if not _dungeon_active: return "ongoing"
	var alive_enemies: int = 0
	var alive_players: int = 0
	for ent in _dungeon_entities:
		if bool(ent["is_dead"]): continue
		if bool(ent["is_player"]):
			alive_players += 1
		elif bool(ent.get("is_friendly", false)):
			pass  # allies don't count as enemies
		else:
			alive_enemies += 1
	if alive_enemies == 0:
		return "victory"
	if alive_players == 0:
		return "defeat"
	return "ongoing"

## Returns outcome data dict on victory: {xp, gold, items}.
## Safe to call on defeat too (returns zeroes).
func get_dungeon_outcome_data() -> Dictionary:
	var xp: int    = 15 + _dungeon_round * 2
	var gold: int  = randi_range(5, 20) * _dungeon_enemy_level
	var items: PackedStringArray = PackedStringArray([
		"Health Potion",
		"Gold Coin x%d" % gold,
	])
	# Collect loot via existing system (which awards XP too)
	var live_player: int = -1
	for ent in _dungeon_entities:
		if bool(ent["is_player"]):
			live_player = int(ent.get("handle", -1))
			break
	if live_player >= 0:
		items = collect_loot(live_player)
	return {"xp": xp, "gold": gold, "items": items}

## Returns the entity ID of whichever player unit is currently acting,
## or "" if it is not the player phase.
func get_current_player_entity_id() -> String:
	if not _dungeon_is_player_phase: return ""
	if _dungeon_player_queue.is_empty(): return ""
	if _dungeon_queue_idx >= _dungeon_player_queue.size(): return ""
	return _dungeon_player_queue[_dungeon_queue_idx]

# ── Action queries ────────────────────────────────────────────────────────────

## Returns available weapon actions for the given entity.
## All non-free actions use escalating cost: Nth action = N AP.
func get_available_weapon_actions(entity_id: String) -> Array:
	var ent = _dung_find(entity_id)
	if ent == null or not ent["is_player"] or ent["is_dead"]: return []
	var next_cost: int = int(ent.get("actions_taken", 0)) + 1
	var actions: Array = []

	# Unarmed Strike — escalating AP cost, melee
	actions.append(_make_action(
		"Unarmed Strike", "Weapon", ACT_UNARMED, next_cost,
		0, true, false, "", 0, 1, false, 1,
		"Strike with fists. 1d4 damage. (%d AP)" % next_cost))

	# Equipped weapon attack — if weapon equipped
	var weapon: String = ent["equipped_weapon"]
	if weapon != "None" and weapon != "":
		var is_ranged: bool = _weapon_is_ranged(weapon)
		var act_id: int = ACT_RANGED if is_ranged else ACT_MELEE
		var rng: int = 3 if is_ranged else 1
		actions.append(_make_action(
			weapon, "Weapon", act_id, next_cost,
			0, true, is_ranged, "", 0, 1, false, rng,
			"Attack with equipped %s. (%d AP)" % [weapon, next_cost]))

	# Grapple — escalating AP cost, requires adjacent target
	actions.append(_make_action(
		"Grapple", "Weapon", ACT_GRAPPLE, next_cost,
		0, true, false, "", 0, 1, false, 1,
		"Attempt to restrain an adjacent enemy. (%d AP)" % next_cost))

	return actions

## Returns available ability actions for the given entity.
## All non-free actions use escalating cost: Nth action = N AP.
func get_available_ability_actions(entity_id: String) -> Array:
	var ent = _dung_find(entity_id)
	if ent == null or not ent["is_player"] or ent["is_dead"]: return []
	var next_cost: int = int(ent.get("actions_taken", 0)) + 1
	var actions: Array = []

	# Dodge — escalating AP cost, grants +3 AC until next turn
	actions.append(_make_action(
		"Dodge", "Ability", ACT_DODGE, next_cost,
		0, false, false, "", 0, 1, false, 0,
		"Focus on defence. Gain +3 AC until your next turn. (%d AP)" % next_cost))

	# Rest — escalating AP cost, recovers HP & SP
	actions.append(_make_action(
		"Rest", "Ability", ACT_REST, next_cost,
		0, false, false, "", 0, 1, false, 0,
		"Rest to recover. Restore some HP and SP. (%d AP)" % next_cost))

	# Hide — escalating AP cost, become hidden from enemies
	actions.append(_make_action(
		"Hide", "Ability", ACT_HIDE, next_cost,
		0, false, false, "", 0, 1, false, 0,
		"Attempt to hide. Enemies lose sight of you. (%d AP)" % next_cost))

	# Interact — escalating AP cost, generic environmental interaction
	actions.append(_make_action(
		"Interact", "Ability", ACT_INTERACT, next_cost,
		0, false, false, "", 0, 1, false, 0,
		"Interact with an object or feature. (%d AP)" % next_cost))

	# Escape Grapple — only shown when grappled
	if _dung_has_condition(ent, "grappled"):
		actions.append(_make_action(
			"Escape Grapple", "Ability", ACT_ESC_GRAPPLE, next_cost,
			0, false, false, "", 0, 1, false, 0,
			"Attempt to break free from a grapple. (%d AP)" % next_cost))

	# Reload — only if equipped ranged weapon
	if _weapon_is_ranged(ent["equipped_weapon"]):
		actions.append(_make_action(
			"Reload", "Ability", ACT_RELOAD, next_cost,
			0, false, false, "", 0, 1, false, 0,
			"Reload your ranged weapon. (%d AP)" % next_cost))

	# Extra Move — escalating AP cost, grants additional movement
	actions.append(_make_action(
		"Extra Move", "Ability", ACT_EXTRA_MOVE, next_cost,
		0, false, false, "", 0, 1, false, 0,
		"Gain additional movement this turn. (%d AP)" % next_cost))

	# Flying — toggle flight (1 AP), Ascend/Descend when airborne
	var is_flying: bool = _dung_has_condition(ent, "flying")
	if is_flying:
		actions.append(_make_action(
			"Land", "Ability", ACT_FLY_LAND, 1,
			0, false, false, "", 0, 1, false, 0,
			"Descend and land on the ground. Ends flying condition."))
		actions.append(_make_action(
			"⬆ Ascend", "Ability", ACT_FLY_ASCEND, 0,
			0, false, false, "", 0, 1, false, 0,
			"Rise higher (free action). Maximum altitude %d." % DUNGEON_CEILING))
		actions.append(_make_action(
			"⬇ Descend", "Ability", ACT_FLY_DESCEND, 0,
			0, false, false, "", 0, 1, false, 0,
			"Drop lower (free action). Minimum altitude 0."))
	else:
		actions.append(_make_action(
			"🕊 Take Flight", "Ability", ACT_FLY_TOGGLE, 1,
			0, false, false, "", 0, 1, false, 0,
			"Spend 1 AP to take flight. Flying units can pass over obstacles and walls."))

	# Shapeshifting — Shapeshifter's Path feat
	var handle: int = int(ent.get("handle", -1))
	if handle >= 0 and _chars.has(handle):
		var ss_tier: int = int(_chars[handle].get("feats", {}).get("Shapeshifter's Path", 0))
		if ss_tier >= 1:
			if bool(ent.get("shapeshifted", false)):
				# Already shapeshifted — offer Revert (free action)
				var form_nm: String = str(ent.get("shapeshift_form", "creature"))
				actions.append(_make_action(
					"↩ Revert Form", "Ability", ACT_REVERT_SHAPESHIFT, 0,
					0, false, false, "", 0, 1, false, 0,
					"Revert from %s back to your normal form. (Free action)" % form_nm))
			else:
				# Can shapeshift — check uses remaining this SR
				var max_uses: Array = [1, 2, 99, 3, 99]
				var uses_left: int = int(ent.get("shapeshift_uses", max_uses[clampi(ss_tier - 1, 0, 4)]))
				if uses_left > 0:
					var use_str: String = "∞" if uses_left >= 99 else str(uses_left)
					actions.append(_make_action(
						"🐺 Shapeshift", "Ability", ACT_SHAPESHIFT, next_cost,
						0, false, false, "", 0, 1, false, 0,
						"Transform into a beast form. Uses left: %s (%d AP)" % [use_str, next_cost]))

	# Minion Master — Summoner's Call
	if handle >= 0 and _chars.has(handle):
		var mm_tier: int = int(_chars[handle].get("feats", {}).get("Minion Master", 0))
		if mm_tier >= 1:
			var mm_used: bool = bool(ent.get("minion_master_used", false))
			# Count existing minions
			var mm_max: int = 1
			if mm_tier >= 4: mm_max = 4
			elif mm_tier >= 3: mm_max = 3
			var mm_count: int = 0
			for mm_e in _dungeon_entities:
				if bool(mm_e.get("is_summon", false)) and not bool(mm_e.get("is_dead", false)):
					if str(mm_e.get("summon_caster_id", "")) == entity_id and str(mm_e.get("summon_feat", "")) == "minion_master":
						mm_count += 1
			if not mm_used and mm_count < mm_max:
				actions.append(_make_action(
					"👤 Summon Minion", "Ability", ACT_SUMMON_FEAT, next_cost,
					0, false, false, "minion_master", 0, 1, false, 0,
					"Summon an Arcane Minion (Lv%d, %d/%d active). Once per long rest. (%d AP)" % [
						int(_chars[handle].get("level", 1)), mm_count, mm_max, next_cost]))
			# T3: Consciousness transfer (once/LR) — fall unconscious, control a minion directly
			if mm_tier >= 3 and mm_count > 0 and not bool(ent.get("_mm_consciousness_used", false)):
				if not bool(ent.get("_mm_consciousness_active", false)):
					actions.append(_make_action(
						"🧠 Enter Minion", "Ability", ACT_SUMMON_FEAT, 0,
						0, false, false, "minion_consciousness", 0, 1, false, 0,
						"Fall unconscious and transfer consciousness to a minion. Once per long rest."))

	# ── Construct management actions ──
	var active_constructs: Array = ent.get("_active_constructs", [])
	if not active_constructs.is_empty():
		for ci in range(active_constructs.size()):
			var cm: Dictionary = active_constructs[ci]
			var cm_type: String = str(cm.get("type", "equipment"))
			var cm_dismissed: bool = bool(cm.get("dismissed", false))
			var cm_destroyed: bool = bool(cm.get("destroyed", false))
			var cm_id: String = str(cm.get("id", ""))
			if not cm_dismissed and not cm_destroyed:
				# Dismiss to pocket dimension (free action)
				var dismiss_name: String = "Dismiss %s" % ("Structure" if cm_type == "structure" else "Equipment Set")
				actions.append(_make_action(
					dismiss_name, "Ability", ACT_DISMISS_CONSTRUCT, 0,
					0, false, false, cm_id, 0, 1, false, 0,
					"Send construct to pocket dimension. Can recall as an action."))
			if cm_dismissed and not cm_destroyed:
				# Recall from pocket dimension (1 AP action)
				var recall_name: String = "Recall %s" % ("Structure" if cm_type == "structure" else "Equipment Set")
				actions.append(_make_action(
					recall_name, "Ability", ACT_RECALL_CONSTRUCT, next_cost,
					0, false, false, cm_id, 0, 1, false, 0,
					"Recall construct from pocket dimension. Must be on same plane."))
			if cm_destroyed:
				# Reform destroyed construct (1 AP action, as long as spell is active)
				var reform_name: String = "Reform %s" % ("Structure" if cm_type == "structure" else "Equipment Set")
				actions.append(_make_action(
					reform_name, "Ability", ACT_REFORM_CONSTRUCT, next_cost,
					0, false, false, cm_id, 0, 1, false, 0,
					"Reform destroyed construct while spell is still active."))

	return actions

## Returns spell actions for the entity based on their learned spells.
func get_available_spell_actions(entity_id: String) -> Array:
	_ensure_spell_db()
	var ent = _dung_find(entity_id)
	if ent == null or ent["is_dead"]: return []
	var handle: int = ent.get("handle", -1)
	if handle < 0 or not _chars.has(handle): return []

	var learned: Array = _chars[handle].get("spells", [])
	if learned.is_empty(): return []

	var next_cost: int = int(ent.get("actions_taken", 0)) + 1
	var sp_left: int = int(ent.get("sp", 0))
	var actions: Array = []

	for spell_name in learned:
		if not _SPELL_DB.has(spell_name): continue
		var s: Dictionary = _SPELL_DB[spell_name]
		var sc: int = int(s["sc"])
		# Teleport SP cost is 0 (dynamic) — always show it
		var can_cast: bool = (sc == 0 or sp_left >= sc)
		if not can_cast: continue

		# Convert area_type int to range_idx for UI:
		# rt=0→range_idx=0(self), rt=1→1(touch), rt≤6→2(short), rt>6→3(long)
		var rt: int = int(s["rt"])
		var range_idx: int
		if rt == 0:   range_idx = 0
		elif rt <= 1: range_idx = 1
		elif rt <= 6: range_idx = 2
		else:         range_idx = 3

		var act: Dictionary = _make_action(
			spell_name, "Spell", ACT_CAST_SPELL,
			next_cost,                # escalating AP cost
			sc,                       # SP cost
			bool(s["atk"]),           # is_attack
			false,                    # is_ranged
			spell_name,               # matrix_id stores spell name for lookup
			int(s["area"]),           # area_type
			int(s["mt"]),             # max_targets
			bool(s["tp"]),            # is_teleport
			range_idx,
			str(s["desc"]) + " (%d AP)" % next_cost
		)
		act["tp_range"] = int(s.get("tp_range", 0))
		actions.append(act)

	return actions

## Returns one action per active matrix: End (free, 0 AP) or Resume (1 AP if suppressed).
func get_available_matrix_actions(entity_id: String) -> Array:
	if not _dungeon_matrices.has(entity_id): return []
	var actions: Array = []
	for mtx in _dungeon_matrices[entity_id]:
		var rnd: int     = int(mtx["rounds"])
		var sname: String = str(mtx["name"])
		if bool(mtx["suppressed"]):
			actions.append(_make_action(
				"▶ %s (%dr)" % [sname, rnd], "Matrix",
				ACT_ACTIVATE_MTX, 1, 0,
				false, false, sname, 0, 1, false, 0,
				"Resume the sustained spell '%s'." % sname))
		else:
			actions.append(_make_action(
				"■ End: %s (%dr)" % [sname, rnd], "Matrix",
				ACT_END_MTX, 0, 0,
				false, false, sname, 0, 1, false, 0,
				"End '%s', removing its effects. (Free action)" % sname))
	return actions

func _dung_dispatch_activate_matrix(ent: Dictionary, spell_name: String, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	if not _dungeon_matrices.has(ent["id"]):
		return _dung_fail("No active matrix named '%s'." % spell_name)
	for mtx in _dungeon_matrices[ent["id"]]:
		if str(mtx["name"]) == spell_name:
			if not bool(mtx["suppressed"]):
				return _dung_fail("'%s' is already active." % spell_name)
			mtx["suppressed"] = false
			return _dung_ok("%s resumes %s." % [ent["name"], spell_name], ap_cost, 0)
	return _dung_fail("Matrix '%s' not found." % spell_name)

func _dung_dispatch_end_matrix(ent: Dictionary, spell_name: String, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	_dung_end_matrix(str(ent["id"]), spell_name)
	return _dung_ok("%s ends %s." % [ent["name"], spell_name], ap_cost, 0)

## Stub — item actions populated in Segment 7.
func get_available_item_actions(entity_id: String) -> Array:
	var ent = _dung_find(entity_id)
	if ent == null: return []
	var handle: int = ent["handle"]
	if handle < 0: return []
	var char_data = _chars.get(handle, {})
	var items: Array = char_data.get("items", [])
	var actions: Array = []
	for item in items:
		actions.append(_make_action(
			"Use: %s" % item, "Item", ACT_USE_ITEM, 2,
			0, false, false, item, 0, 1, false, 0,
			"Use %s from your inventory." % item))
	return actions

## Dispatch a lineage trait activation: marks cooldown, applies generic effect.
func _dung_dispatch_trait(ent: Dictionary, trait_id: String, ap_cost: int) -> Dictionary:
	var handle: int = int(ent.get("handle", -1))
	var key: String = "%d:%s" % [handle, trait_id]
	_trait_cooldowns[key] = true
	ent["ap_spent"] += ap_cost
	var label: String = _TRAIT_LABELS.get(trait_id, trait_id)
	var effect_note: String = ""

	# Helper: get level and stat values from linked character sheet
	var lv: int = int(ent.get("level", 1))
	var ch_stats: Array = [1,1,1,1,1]
	var ch_skills: Array = [0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	if handle >= 0 and _chars.has(handle):
		ch_stats  = _chars[handle].get("stats",  ch_stats)
		ch_skills = _chars[handle].get("skills", ch_skills)
	var str_v: int = int(ch_stats[0]);  var spd_v: int = int(ch_stats[1])
	var int_v: int = int(ch_stats[2]);  var vit_v: int = int(ch_stats[3])
	var div_v: int = int(ch_stats[4])

	match trait_id:
		# ── Healing / recovery ────────────────────────────────────────────
		"Regrowth", "SapHealing":
			var heal: int = lv + vit_v + randi_range(1, 8)
			ent["hp"] = mini(int(ent["hp"]) + heal, int(ent["max_hp"]))
			if trait_id == "SapHealing":
				var conds: Array = ent.get("conditions", [])
				if not conds.is_empty(): conds.pop_back()
			effect_note = " (+%d HP)" % heal
		"FungalFortitude":
			var heal: int = randi_range(2, 6) + vit_v
			ent["hp"] = mini(int(ent["hp"]) + heal, int(ent["max_hp"]))
			effect_note = " (+%d HP, poison resistant)" % heal
		"VitalSurge":
			var heal: int = randi_range(1, 4) * 4 + div_v
			ent["hp"] = mini(int(ent["hp"]) + heal, int(ent["max_hp"]))
			effect_note = " (+%d HP)" % heal
		"HibernateUrsari", "SunderbornHibernate":
			ent["hp"] = int(ent["max_hp"])
			effect_note = " (fully healed)"
		"BloodlettingBlow", "BloodlettingTouch":
			var adj: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj.is_empty():
				var tgt: Dictionary = adj[0]
				var dmg: int = randi_range(1, 4) * (3 if trait_id == "BloodlettingTouch" else 1) + randi_range(1, 8)
				_dung_reduce_hp(tgt, dmg)
				if tgt["hp"] == 0: tgt["is_dead"] = true
				var steal: int = dmg / 2
				ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + steal)
				effect_note = " (dealt %d, healed %d from %s)" % [dmg, steal, tgt["name"]]
			else: effect_note = " (no target in range)"
		"GraveBind", "Gravebind":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 6)
			if not nearby.is_empty():
				var tgt: Dictionary = nearby[0]
				var drain: int = randi_range(1, 4) + div_v
				_dung_reduce_hp(tgt, drain)
				if tgt["hp"] == 0: tgt["is_dead"] = true
				ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + drain)
				effect_note = " (drained %d HP from %s)" % [drain, tgt["name"]]
			else: effect_note = " (no target in range)"
		"HydrasResilience", "StonesEndurance":
			var absorb: int = randi_range(1, 12) + vit_v
			_dung_add_condition(ent, "shielded")
			effect_note = " (absorbs ~%d dmg this round)" % absorb
		"LimbSacrifice":
			_dung_add_condition(ent, "resistant")
			effect_note = " [resistant — sacrificed limb]"
		"WitherbornDecay":
			var heal: int = randi_range(1, 6) + vit_v
			ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal)
			effect_note = " (+%d HP from decay)" % heal
		"Photosynthesis":
			var heal: int = 1 + lv
			ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal)
			effect_note = " (+%d HP from sunlight)" % heal
		"AbyssalGlow":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for e in nearby: _dung_add_condition(e, "blinded")
			effect_note = " (blinded %d enemies + allies heal 1d6)" % nearby.size()

		# ── AoE & targeted offense ─────────────────────────────────────────
		"SporeCloud", "Sporespit", "ToxicRoots", "ToxicSeep":
			var radius: int = 3 if trait_id == "SporeCloud" else 1
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), radius)
			for t in targets:
				var pdmg: int = randi_range(1, 4)
				_dung_reduce_hp(t, pdmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "poisoned")
			effect_note = " (poison: %d targets hit)" % targets.size() if not targets.is_empty() else " (no targets)"
		"BreathWeapon", "CorruptBreath", "BrineCone", "WinterBreath", "SteamJet":
			var cone: Array = get_adjacent_enemies(str(ent["id"]))
			var extra: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for e in extra:
				if e not in cone: cone.append(e)
			var dmg_base: int = randi_range(2, 6) + lv
			for t in cone:
				_dung_reduce_hp(t, dmg_base)
				if t["hp"] == 0: t["is_dead"] = true
				if trait_id in ["BrineCone", "WinterBreath", "SteamJet"]:
					_dung_add_condition(t, "slowed")
			effect_note = " (breath %d dmg to %d targets)" % [dmg_base, cone.size()] if not cone.is_empty() else " (no targets)"
		"ShockPulse", "StormCall":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			var dmg: int = randi_range(3, 6)
			for t in targets:
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "dazed")
			effect_note = " (lightning: %d to %d targets, dazed)" % [dmg, targets.size()] if not targets.is_empty() else " (no targets)"
		"RadiantPulse", "Flareburst", "SunsFavor":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets: _dung_add_condition(t, "blinded")
			effect_note = " (radiant: blinded %d targets)" % targets.size() if not targets.is_empty() else " (no targets)"
		"Boneclatter", "RotVoice", "HauntingWail", "InfernalStare":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			for t in targets: _dung_add_condition(t, "frightened")
			effect_note = " (fear: %d targets)" % targets.size() if not targets.is_empty() else " (no targets)"
		"FrostBurst":
			var targets: Array = get_adjacent_enemies(str(ent["id"]))
			for t in targets:
				var fd: int = randi_range(2, 4)
				_dung_reduce_hp(t, fd)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "slowed")
			effect_note = " (frost: %d targets slowed)" % targets.size() if not targets.is_empty() else " (no targets)"
		"NeuralLiquefaction":
			var adj: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj.is_empty():
				var t: Dictionary = adj[0]
				var dmg: int = randi_range(2, 6) + randi_range(2, 6)
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				t["sp"] = maxi(0, int(t.get("sp", 0)) - 1)
				effect_note = " (%s: %d psychic, -1 SP)" % [t["name"], dmg]
			else: effect_note = " (no adjacent target)"
		"SkullDrill":
			var adj: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj.is_empty():
				var t: Dictionary = adj[0]
				if _dung_has_condition(t, "stunned") or _dung_has_condition(t, "restrained"):
					var dmg: int = randi_range(2, 6) + randi_range(2, 6)
					_dung_reduce_hp(t, dmg)
					if t["hp"] == 0: t["is_dead"] = true
					ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + dmg)
					effect_note = " (drilled %s: %d dmg, healed %d)" % [t["name"], dmg, dmg]
				else:
					effect_note = " (target must be stunned/restrained)"
			else: effect_note = " (no adjacent target)"
		"ThrenodySlamAttack":
			var adj: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj.is_empty():
				var t: Dictionary = adj[0]
				var dmg: int = randi_range(3, 6) * 3
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "dazed")
				effect_note = " (slam: %d to %s, dazed)" % [dmg, t["name"]]
			else: effect_note = " (no adjacent target)"
		"DustShroud":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets: _dung_add_condition(t, "blinded")
			effect_note = " (dust: blinded %d targets)" % targets.size() if not targets.is_empty() else " (no targets)"
		"WhipLash":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			if not nearby.is_empty():
				_dung_add_condition(nearby[0], "slowed")
				effect_note = " (%s slowed/pulled)" % nearby[0]["name"]
			else: effect_note = " (no target)"
		"VoidAura":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			for t in targets: _dung_add_condition(t, "confused")
			effect_note = " (void: %d targets confused)" % targets.size() if not targets.is_empty() else " (no targets)"
		"SurgePulse":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets: _dung_add_condition(t, "slowed")
			effect_note = " (surge: %d targets slowed)" % targets.size() if not targets.is_empty() else " (no targets)"
		"SporeBloom", "Dreamscent", "MossyShroud", "SoothingAura":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets: _dung_add_condition(t, "dazed")
			effect_note = " (calming cloud: %d targets dazed)" % targets.size() if not targets.is_empty() else " (no targets)"

		# ── Single-target debuffs ──────────────────────────────────────────
		"SilkenTrap", "Shadowgrasp", "Tidebind":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			if not nearby.is_empty():
				_dung_add_condition(nearby[0], "restrained")
				effect_note = " (%s restrained)" % nearby[0]["name"]
			else: effect_note = " (no target)"
		"HypnoticGaze":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			if not nearby.is_empty():
				_dung_add_condition(nearby[0], "dazed")
				effect_note = " (%s dazed)" % nearby[0]["name"]
			else: effect_note = " (no target)"
		"HexMark", "VelvetTerror", "Witchblood":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 4)
			if not nearby.is_empty():
				_dung_add_condition(nearby[0], "frightened")
				effect_note = " (%s frightened)" % nearby[0]["name"]
			else: effect_note = " (no target)"
		"EntropyTouch", "Mindscratch", "LeechHex", "DrainingFangs", "VenomousBite":
			var adj: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj.is_empty():
				var t: Dictionary = adj[0]
				var dmg: int = randi_range(1, 4)
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				if trait_id == "VenomousBite": _dung_add_condition(t, "poisoned")
				if trait_id in ["LeechHex", "DrainingFangs"]:
					ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + 1)
				effect_note = " (%s: %d dmg)" % [t["name"], dmg]
			else: effect_note = " (no adjacent target)"
		"Unravel":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			if not nearby.is_empty():
				_dung_add_condition(nearby[0], "vulnerable")
				effect_note = " (%s vulnerable, no healing)" % nearby[0]["name"]
			else: effect_note = " (no target)"
		"CrystalSlash":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			if not targets.is_empty():
				for t in targets: _dung_add_condition(t, "blinded")
				effect_note = " (shards: blinded %d targets)" % targets.size()
			else: effect_note = " (no targets)"
		"HexOfWithering", "WitchsDraught":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 4)
			if not nearby.is_empty():
				var t: Dictionary = nearby[0]
				var dmg: int = randi_range(1, 6)
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "exhausted")
				effect_note = " (%s: %d dmg + exhausted)" % [t["name"], dmg]
			else: effect_note = " (no target)"

		# ── Self-buff / condition application ─────────────────────────────
		"EtherealStep", "MistForm", "MemoryEchoToggle":
			_dung_add_condition(ent, "intangible")
			effect_note = " [intangible]"
		"VaporFormActivate":
			_dung_add_condition(ent, "intangible")
			_dung_add_condition(ent, "flying")
			effect_note = " [intangible + flying]"
		"VeiledPresence", "CreepingDark", "Shadowmeld", "LurkerStep":
			_dung_add_condition(ent, "hidden")
			effect_note = " [hidden]"
		"Veilstep", "NightborneVeilstep", "UmbralDodge", "ChromaticShift", "DuskbornGrace", "AdaptiveHide":
			_dung_add_condition(ent, "dodging")
			effect_note = " [dodging]"
		"CloudlingFly", "WingsOfForgotten", "ShadowGlide", "GravitationalLeap":
			_dung_add_condition(ent, "flying")
			effect_note = " [flying]"
		"IllusoryEcho":
			_dung_add_condition(ent, "dodging")
			_dung_add_condition(ent, "shielded")
			effect_note = " [dodging + shielded — illusory double]"
		"ArmoredPlating", "PangolArmorReact", "FrozenVeil":
			_dung_add_condition(ent, "shielded")
			effect_note = " [shielded +2 AC this round]"
		"CurlUp":
			_dung_add_condition(ent, "resistant")
			_dung_add_condition(ent, "shielded")
			ent["speed"] = 0
			effect_note = " [curled: resistant + shielded, speed 0]"
		"Uncurl":
			_dung_remove_condition(ent, "resistant")
			_dung_remove_condition(ent, "shielded")
			effect_note = " [uncurled, movement restored]"
		"InfernalSmite", "CursedSpark", "Blazeblood", "RunicSurgePrime", "SparkforgedArcaneSurge", "ArcaneSurge", "HexMark":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
			effect_note = " [+2 attack for 1 min]"
		"DraconicAwakening":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
			_dung_add_condition(ent, "flying")
			effect_note = " [awakened: +2 atk, flying, large form]"
		"OverdriveCore":
			ent["ap_spent"] = maxi(0, int(ent["ap_spent"]) - (randi_range(2, 4) + vit_v))
			effect_note = " [overdrive: regained AP]"
		"FeyStep", "TetherStep", "Flicker", "PhaseStep", "VoidStep", "LightStepTeleport", "WaxenForm", "EbbAndFlow", "SurgeStep":
			_dung_add_condition(ent, "dodging")
			effect_note = " [stepped — dodging next attack]"
		"ResilientSpirit", "GremlinsLuck", "WeirdResilience", "QuickReflexes", "StubbornWill", "AbyssalMutation", "ResonantFormMimic":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
			effect_note = " [+2 to next roll]"
		"PackHowl", "QuackAlarm", "NaturesGrace", "GuidingLight", "SoothingAura", "KindleFlame", "BeaconAbsorb", "LunarRadiance":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 1
			effect_note = " [ally aura: +1 to group]"
		"SentinelStand":
			ent["speed"] = 0
			_dung_add_condition(ent, "shielded")
			effect_note = " [sentinel: speed 0, shielded, unlimited opportunity attacks]"
		"WindCloak", "DriftingFog":
			_dung_add_condition(ent, "dodging")
			effect_note = " [wind cloak — ranged disadvantage vs you]"
		"MirelingEscape", "AberrantFlex":
			_dung_remove_condition(ent, "restrained")
			_dung_remove_condition(ent, "grappled")
			effect_note = " [escaped restrain/grapple]"
		"HauntingWail", "SilentScream":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			for t in targets: _dung_add_condition(t, "dazed")
			effect_note = " (dazed %d targets)" % targets.size() if not targets.is_empty() else " (no targets)"
		"Windstep", "WindswiftActivate":
			_dung_add_condition(ent, "dodging")
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 1
			effect_note = " [windstep: dodging + +1 attack]"
		"StaticSurge":
			var targets: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets: _dung_add_condition(t, "dazed")
			effect_note = " (static: dazed %d nearby + 0 AP actions next)" % targets.size()
		"Dazzle":
			var adj: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj.is_empty():
				_dung_add_condition(adj[0], "blinded")
				effect_note = " (%s blinded)" % adj[0]["name"]
			else: effect_note = " (no adjacent target)"
		"ShatterPulseGlassborn":
			var adj: Array = get_adjacent_enemies(str(ent["id"]))
			for t in adj:
				var dmg: int = randi_range(1, 6)
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
			effect_note = " (shatter: %d adjacent hit)" % adj.size() if not adj.is_empty() else " (no targets)"
		"VersatileGrant":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
			effect_note = " [+1d4 bonus granted to self and allies]"
		"PainMadeFlesh":
			_dung_add_condition(ent, "resistant")
			effect_note = " [pain delayed — damage/conditions deferred 1 min]"
		"AmorphousSplit":
			_dung_add_condition(ent, "dodging")
			_dung_remove_condition(ent, "restrained")
			effect_note = " [split form: dodging, freed from restrain]"
		"ReflectHex", "AbsorbMagic", "SpellSink":
			_dung_add_condition(ent, "resistant")
			effect_note = " [spell resistance active — reflects/absorbs next spell]"
		"EchoReflection":
			_dung_add_condition(ent, "shielded")
			effect_note = " [echo shield — may suppress next spell targeting you]"
		"TemporalFlicker", "TemporalShift":
			_dung_add_condition(ent, "dodging")
			effect_note = " [temporal shift — next attack effect delayed]"
		"DivineMimicry", "ConvergentSynthesis":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
			effect_note = " [mimic trait absorbed, +2 to next roll]"
		"VoidCloakToggle", "WarpResistanceToggle":
			_dung_add_condition(ent, "hidden")
			effect_note = " [cloaked — harder to detect/target]"
		"Gustcaller":
			var nearby: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			if not nearby.is_empty():
				_dung_add_condition(nearby[0], "prone")
				effect_note = " (%s pushed prone)" % nearby[0]["name"]
			else: effect_note = " (no target)"

		# ── Toggle / informational traits ──────────────────────────────────
		"LuminousToggle", "AbyssariGlowToggle", "LanternbornGlowToggle", "GlimmerfolkGlowToggle", "AshrotAuraToggle", "ObedientAuraToggle":
			effect_note = " [light toggled]"
		"ShiftingFormToggle":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 1
			effect_note = " [beast form: +1 atk, +10 speed]"
		"ResonantSermonToggle":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 1
			effect_note = " [sermon aura active]"
		"AntiMagicConeToggle":
			_dung_add_condition(ent, "shielded")
			effect_note = " [anti-magic cone — suppresses enemy spells in 30ft]"
		"VoidCommunion":
			ent["sp"] = mini(int(ent.get("sp", 0)) + div_v + randi_range(1, 4), int(ent.get("max_sp", 6)))
			effect_note = " (+%d SP from communion)" % div_v
		"MnemonicRecall", "ScrapSense", "TombSense", "DesertWalker", "DeathsWhisper", "SableNightVision", "MarketWhisperer", "DeathEaterMemory", "IronStomachPoison", "BoundingEscape", "FrostbornIcewalk":
			effect_note = " [passive activated — see trait description]"

		# ── Ranged single-target damage rays ────────────────────
		"ParalyzingRay":
			var nearby_pr: Array = _get_enemies_in_burst(str(ent["id"]), 6)
			if not nearby_pr.is_empty():
				var t: Dictionary = nearby_pr[0]
				var dmg: int = randi_range(1, 6) + int_v
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "stunned")
				effect_note = " (paralyzing ray: %d to %s, stunned)" % [dmg, t["name"]]
			else: effect_note = " (no target in range)"
		"FearRay":
			var nearby_fr: Array = _get_enemies_in_burst(str(ent["id"]), 6)
			if not nearby_fr.is_empty():
				_dung_add_condition(nearby_fr[0], "frightened")
				effect_note = " (fear ray: %s frightened)" % nearby_fr[0]["name"]
			else: effect_note = " (no target in range)"
		"HealingRay":
			var heal_hr: int = randi_range(2, 8) + div_v
			ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal_hr)
			effect_note = " (healing ray: +%d HP)" % heal_hr
		"NecroticRay":
			var nearby_nr: Array = _get_enemies_in_burst(str(ent["id"]), 5)
			if not nearby_nr.is_empty():
				var t: Dictionary = nearby_nr[0]
				var dmg: int = randi_range(1, 8) + div_v
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "vulnerable")
				effect_note = " (necrotic ray: %d to %s)" % [dmg, t["name"]]
			else: effect_note = " (no target in range)"
		"DisintegrationRay":
			var nearby_dr: Array = _get_enemies_in_burst(str(ent["id"]), 5)
			if not nearby_dr.is_empty():
				var t: Dictionary = nearby_dr[0]
				var dmg: int = randi_range(4, 12) + int_v
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				effect_note = " (disintegrate: %d dmg to %s)" % [dmg, t["name"]]
			else: effect_note = " (no target in range)"
		"QuillLaunch":
			var nearby_ql: Array = _get_enemies_in_burst(str(ent["id"]), 4)
			if not nearby_ql.is_empty():
				var t: Dictionary = nearby_ql[0]
				var dmg: int = randi_range(1, 6) + str_v
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				effect_note = " (quill: %d piercing to %s)" % [dmg, t["name"]]
			else: effect_note = " (no target)"
		"MireBurst":
			var targets_mb: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets_mb:
				var dmg: int = randi_range(1, 6)
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "slowed")
			effect_note = " (mire: %d targets slowed)" % targets_mb.size() if not targets_mb.is_empty() else " (no targets)"
		"DisjointedLeap":
			var adj_leap: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj_leap.is_empty():
				var t: Dictionary = adj_leap[0]
				var dmg: int = randi_range(1, 6) + spd_v
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(ent, "dodging")
				effect_note = " (leap strike: %d dmg, dodging)" % dmg
			else:
				_dung_add_condition(ent, "dodging")
				effect_note = " [leap: dodging]"
		"Gore":
			var adj_gore: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj_gore.is_empty():
				var t: Dictionary = adj_gore[0]
				var dmg: int = randi_range(1, 10) + str_v
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				effect_note = " (gore: %d piercing to %s)" % [dmg, t["name"]]
			else: effect_note = " (no adjacent target)"
		# ── AoE pulses ────────────────────
		"AshrotAuraBurst", "AbyssariPulse", "ArcanePulse", "DarkLineagePulse", "MysticPulse":
			var targets_p: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets_p:
				var dmg: int = randi_range(1, 6) + lv
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				if trait_id == "AbyssariPulse":
					_dung_add_condition(t, "blinded")
				elif trait_id == "DarkLineagePulse":
					_dung_add_condition(t, "frightened")
				else:
					_dung_add_condition(t, "dazed")
			effect_note = " (pulse: %d targets hit)" % targets_p.size() if not targets_p.is_empty() else " (no targets)"
		"VoluntaryGasVent":
			var targets_gv: Array = _get_enemies_in_burst(str(ent["id"]), 2)
			for t in targets_gv:
				var dmg: int = randi_range(1, 4)
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				_dung_add_condition(t, "poisoned")
			effect_note = " (gas: %d targets poisoned)" % targets_gv.size() if not targets_gv.is_empty() else " (no targets)"
		"ResonantVoice":
			var targets_rv: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			for t in targets_rv: _dung_add_condition(t, "dazed")
			effect_note = " (resonant voice: %d dazed)" % targets_rv.size() if not targets_rv.is_empty() else " (no targets)"
		"CommandingVoice":
			var nearby_cv: Array = _get_enemies_in_burst(str(ent["id"]), 4)
			if not nearby_cv.is_empty():
				_dung_add_condition(nearby_cv[0], "charmed")
				effect_note = " (%s charmed by command)" % nearby_cv[0]["name"]
			else: effect_note = " (no target)"
		# ── Single-target debuff traits ────────────────────
		"DiseasebornCurse":
			var nearby_dc: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			if not nearby_dc.is_empty():
				_dung_add_condition(nearby_dc[0], "poisoned")
				_dung_add_condition(nearby_dc[0], "exhausted")
				effect_note = " (%s diseased)" % nearby_dc[0]["name"]
			else: effect_note = " (no target)"
		"VerdantCurse":
			var nearby_vc: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			if not nearby_vc.is_empty():
				_dung_add_condition(nearby_vc[0], "restrained")
				effect_note = " (%s entangled in vines)" % nearby_vc[0]["name"]
			else: effect_note = " (no target)"
		"UnnervinGaze", "GnawingGrin", "SmolderingGlare":
			var nearby_ug: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			if not nearby_ug.is_empty():
				_dung_add_condition(nearby_ug[0], "frightened")
				effect_note = " (%s frightened)" % nearby_ug[0]["name"]
			else: effect_note = " (no target)"
		"MindBleed":
			var adj_mb: Array = get_adjacent_enemies(str(ent["id"]))
			if not adj_mb.is_empty():
				var t: Dictionary = adj_mb[0]
				var dmg: int = randi_range(1, 6) + int_v
				_dung_reduce_hp(t, dmg)
				if t["hp"] == 0: t["is_dead"] = true
				t["sp"] = maxi(0, int(t.get("sp", 0)) - 1)
				effect_note = " (mind bleed: %d psychic to %s, -1 SP)" % [dmg, t["name"]]
			else: effect_note = " (no adjacent target)"
		"NullMindShare":
			var nearby_nms: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			for t in nearby_nms: _dung_add_condition(t, "confused")
			effect_note = " (null mind: %d confused)" % nearby_nms.size() if not nearby_nms.is_empty() else " (no targets)"
		"GremlinSabotage":
			var nearby_gs: Array = _get_enemies_in_burst(str(ent["id"]), 3)
			if not nearby_gs.is_empty():
				_dung_add_condition(nearby_gs[0], "vulnerable")
				effect_note = " (%s sabotaged)" % nearby_gs[0]["name"]
			else: effect_note = " (no target)"
		# ── Self-buff traits ────────────────────
		"DawnsBlessingActivate", "EnchantingPresence", "HuntersFocus", "KeenSightFocus", "DregspawnExtend", "MechanicalMindRecall":
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
			effect_note = " [focus: +2 to next roll]"
		"PrismaticReflection", "PrismVeins", "RadiantWard", "CrystalResilience", "FracturedMind", "HeatedScalesToggle":
			_dung_add_condition(ent, "shielded")
			_dung_add_condition(ent, "resistant")
			effect_note = " [ward: shielded + resistant]"
		"RealitySlip", "TrickstersDodge", "Dreamwalk", "MirrorMove":
			_dung_add_condition(ent, "dodging")
			_dung_add_condition(ent, "hidden")
			effect_note = " [slip: dodging + hidden]"
		"RunicFlowAuto", "AlchemicalAffinity", "MemoryTap":
			var gained_sp: int = 1 + int_v
			ent["sp"] = mini(int(ent.get("sp", 0)) + gained_sp, int(ent.get("max_sp", 6)))
			effect_note = " (+%d SP from focus)" % gained_sp
		"LimbRegrowth":
			var heal_lr: int = randi_range(2, 6) + vit_v
			ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal_lr)
			effect_note = " (regrew tissue: +%d HP)" % heal_lr
		"UnstableMutation":
			var rroll: int = randi_range(0, 2)
			if rroll == 0:
				ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 2
				effect_note = " [mutation: +2 attack]"
			elif rroll == 1:
				_dung_add_condition(ent, "shielded")
				effect_note = " [mutation: shielded]"
			else:
				var heal_um: int = randi_range(1, 6) + vit_v
				ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal_um)
				effect_note = " (mutation heal: +%d HP)" % heal_um
		"HarmonicLink":
			var heal_hl: int = randi_range(1, 4) + div_v
			ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal_hl)
			ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 1
			effect_note = " (harmonic: +%d HP, +1 atk)" % heal_hl
		# ── Passive / utility traits ────────────────────
		"GildedBearing", "ExtractVenom", "GremlinTinker", "NaturesVoice", "SootSight", "ScrapInstinct":
			effect_note = " [passive activated]"
		_:
			# Generic keyword fallback for unlisted traits
			var label_lower: String = label.to_lower()
			if "heal" in label_lower or "mend" in label_lower:
				var heal: int = randi_range(4, 10)
				ent["hp"] = mini(int(ent["hp"]) + heal, int(ent["max_hp"]))
				effect_note = " (+%d HP)" % heal
			elif "dodge" in label_lower or "step" in label_lower or "glide" in label_lower:
				_dung_add_condition(ent, "dodging")
				effect_note = " [dodging]"
			elif "burst" in label_lower or "breath" in label_lower or "ray" in label_lower or "slam" in label_lower:
				var adj: Array = get_adjacent_enemies(str(ent["id"]))
				if not adj.is_empty():
					var t: Dictionary = adj[0]
					var dmg: int = randi_range(2, 8)
					_dung_reduce_hp(t, dmg)
					if t["hp"] == 0: t["is_dead"] = true
					effect_note = " (dealt %d to %s)" % [dmg, t["name"]]
				else: effect_note = " (no target in range)"
			elif "toggle" in label_lower:
				effect_note = " [toggled]"
			else:
				effect_note = " [activated]"

	return _dung_ok("%s activates %s%s." % [ent["name"], label, effect_note], ap_cost, 0)

# ── Turn management ───────────────────────────────────────────────────────────

## Advance to the next player unit in the turn queue.
## Returns the new active entity ID, or "" if all players have acted
## (caller should then trigger enemy phase via dungeon_advance_enemy_phase()).
func dungeon_end_individual_turn() -> String:
	_dungeon_queue_idx += 1
	# Skip dead players
	while _dungeon_queue_idx < _dungeon_player_queue.size():
		var eid: String = _dungeon_player_queue[_dungeon_queue_idx]
		var ent = _dung_find(eid)
		if ent != null and not ent["is_dead"]: break
		_dungeon_queue_idx += 1
	if _dungeon_queue_idx >= _dungeon_player_queue.size():
		return ""   # all players done → caller triggers enemy phase
	return _dungeon_player_queue[_dungeon_queue_idx]

## Process the enemy phase: all enemies move and attack,
## then reset for next player round.
func dungeon_advance_enemy_phase() -> Array:
	_dungeon_is_player_phase = false
	var logs: Array = []

	for ent in _dungeon_entities:
		if ent["is_player"] or ent["is_dead"]: continue
		ent["ap_spent"] = 0   # fresh AP for this enemy's turn
		ent["actions_taken"] = 0
		# Tick conditions and matrices
		_dung_tick_conditions(ent)
		if ent["is_dead"]: continue   # may have died from bleeding tick
		_dung_tick_matrices(str(ent["id"]))
		# Phase 3: Spell Echo for enemies (if they have Arcane Wellspring T3)
		var echo_log_e: String = _process_spell_echo(ent)
		if echo_log_e != "": logs.append(echo_log_e)

		# Skip if stunned (ap_spent was maxed by tick)
		if int(ent["ap_spent"]) >= int(ent.get("max_ap", 10)): continue

		# Find nearest visible player (within sight range = 15 tiles)
		const ENEMY_SIGHT: int = 15
		var nearest = null
		var min_d: int = 9999
		for other in _dungeon_entities:
			if other["is_dead"]: continue
			if not other["is_player"] and not other["is_friendly"]: continue
			var d: int = abs(other["x"] - ent["x"]) + abs(other["y"] - ent["y"])
			if d <= ENEMY_SIGHT and d < min_d:
				min_d = d; nearest = other
		if nearest == null: continue

		var is_ranged_enemy: bool = _weapon_is_ranged(str(ent.get("equipped_weapon", "")))
		var hp_pct: float = float(int(ent["hp"])) / float(maxi(1, int(ent["max_hp"])))
		var should_retreat: bool = hp_pct < 0.25 and not is_ranged_enemy

		# ── Morale check for injured creatures ────────────────────────────────────
		if hp_pct < 0.5 and not bool(ent.get("is_player", false)):
			var morale_log: String = _mob_morale_check(ent, 0)
			if morale_log != "": logs.append(morale_log)

		# ── Reset per-turn ability cooldowns ──────────────────────────────────────
		var ab_cds: Dictionary = ent.get("ability_cooldowns", {})
		var cd_keys: Array = ab_cds.keys()
		for k in cd_keys:
			if str(k).ends_with("_turn"): ab_cds.erase(k)
		ent["ability_cooldowns"] = ab_cds

		# ── Evaluate creature abilities before basic attacks ──────────────────────
		var abilities: Array = ent.get("abilities", [])
		var used_ability: bool = false

		if not abilities.is_empty() and not should_retreat:
			# Score each ability: prefer high damage, prefer abilities in range
			var best_ab = null
			var best_score: float = -1.0
			for ab in abilities:
				var ab_ap: int = int(ab.get("ap", 0))
				var ab_sp: int = int(ab.get("sp", 0))
				var ab_range: int = int(ab.get("range", 1))
				var ab_cd: String = str(ab.get("cd", "none"))
				var ab_name: String = str(ab.get("name", ""))
				# Skip passives
				if ab_cd == "passive": continue
				# Check cooldowns
				var cds: Dictionary = ent.get("ability_cooldowns", {})
				if ab_cd == "1/turn" and bool(cds.get(ab_name + "_turn", false)): continue
				if ab_cd == "1/encounter" and bool(cds.get(ab_name + "_enc", false)): continue
				# Check AP/SP affordability
				if int(ent["ap_spent"]) + ab_ap > int(ent.get("max_ap", 10)): continue
				if ab_sp > 0 and int(ent.get("sp", 0)) < ab_sp: continue
				# Check range
				if min_d > ab_range: continue
				# Score: dice damage expected + bonus for conditions
				var ab_dice: Array = ab.get("dice", [0, 0])
				var expected_dmg: float = float(int(ab_dice[0])) * (float(int(ab_dice[1])) + 1.0) / 2.0
				var cond_bonus: float = float(ab.get("conds", []).size()) * 3.0
				# Prefer heal abilities when low HP
				var heal_bonus: float = 0.0
				if hp_pct < 0.4 and ("heal" in ab_name.to_lower() or "regenerat" in ab_name.to_lower()):
					heal_bonus = 20.0
				var score: float = expected_dmg + cond_bonus + heal_bonus
				if score > best_score:
					best_score = score; best_ab = ab

			# Use ability if it outperforms a basic weapon attack (score > 3)
			if best_ab != null and best_score > 3.0:
				var ab_result: Dictionary = _dung_execute_creature_ability(ent, best_ab, nearest)
				logs.append(ab_result["log"])
				used_ability = true

		# ── Retreating enemy: move away from nearest player ───────────────────────
		if should_retreat:
			_enemy_move_away(ent, nearest, ent["speed"])
			continue

		# ── Ranged enemy: attack from distance if ≥ 2 tiles away ─────────────────
		if not used_ability and is_ranged_enemy and min_d >= 2:
			if min_d > 8:
				_enemy_move_toward(ent, nearest, ent["speed"])
			else:
				var r: Dictionary = _dung_do_attack(ent, nearest, ent["equipped_weapon"], false)
				logs.append(r["log"])
			continue

		# ── Normal melee: advance and attack ──────────────────────────────────────
		if not used_ability:
			_enemy_move_toward(ent, nearest, ent["speed"])

			# Attack if now adjacent
			var adj: Array = get_adjacent_enemies(ent["id"])
			if not adj.is_empty():
				var melee_r: Dictionary = _dung_do_attack(ent, adj[0], ent["equipped_weapon"], false)
				logs.append(melee_r["log"])
			elif min_d == 1:
				var r2: Dictionary = _dung_do_attack(ent, nearest, ent["equipped_weapon"], false)
				logs.append(r2["log"])

	# ── Tick summons & shapeshifts at round boundary ─────────────────────────
	var summon_logs: Array = _dung_tick_summons()
	logs.append_array(summon_logs)
	var shape_logs: Array = _dung_tick_shapeshifts()
	logs.append_array(shape_logs)

	# ── Start new player round ────────────────────────────────────────────────
	_dungeon_round += 1
	_dungeon_is_player_phase = true
	_dungeon_player_queue.clear()
	_dungeon_queue_idx = 0

	for ent in _dungeon_entities:
		if ent["is_dead"]: continue
		ent["move_used"] = 0
		ent["actions_taken"] = 0   # reset escalating action cost each round
		ent.erase("_mm_transfer_used_this_round")  # reset Minion Master damage transfer
		# PHB: AP regeneration = Strength score at start of each round (min 1).
		# Player characters use their actual STR; enemies get full reset each turn.
		if ent["is_player"]:
			var h: int = int(ent.get("handle", -1))
			var str_regen: int = 1
			if h >= 0 and _chars.has(h):
				var s: Array = _chars[h].get("stats", [1, 1, 1, 1, 1])
				str_regen = maxi(1, int(s[0]))  # STR score
			elif ent.has("stats"):
				# Allies (handle=-1) use their own stats array
				str_regen = maxi(1, int(ent["stats"][0]))
			ent["ap_spent"] = maxi(0, int(ent["ap_spent"]) - str_regen)
		else:
			ent["ap_spent"] = 0  # enemies: full AP reset at round start
		# Tick conditions and matrices for all entities at round start
		_dung_tick_conditions(ent)
		_dung_tick_matrices(str(ent["id"]))
		# Phase 3: Spell Echo at start of turn
		if not ent["is_dead"]:
			var echo_log: String = _process_spell_echo(ent)
			if echo_log != "": logs.append(echo_log)
		if ent["is_player"]:
			_dungeon_player_queue.append(ent["id"])

	_update_fog()   # refresh visibility at round start
	return logs

# ── Enemy AI movement helpers ─────────────────────────────────────────────────

func _enemy_move_toward(ent: Dictionary, target: Dictionary, steps: int) -> void:
	var steps_left: int = steps
	while steps_left > 0:
		var dx: int = target["x"] - ent["x"]
		var dy: int = target["y"] - ent["y"]
		if dx == 0 and dy == 0: break
		var dirs: Array
		if abs(dx) >= abs(dy):
			dirs = [[sign(dx),0],[0,sign(dy)],[-sign(dx),0],[0,-sign(dy)]]
		else:
			dirs = [[0,sign(dy)],[sign(dx),0],[0,-sign(dy)],[-sign(dx),0]]
		var moved: bool = false
		var cur_idx: int = ent["x"] * MAP_SIZE + ent["y"]
		var cur_z: int = int(_dungeon_elevation[cur_idx]) if _dungeon_elevation.size() > cur_idx else 1
		for dir in dirs:
			var nx2: int = ent["x"] + dir[0]
			var ny2: int = ent["y"] + dir[1]
			if _dung_tile(nx2, ny2) != TILE_FLOOR: continue
			if _dung_occupied(nx2, ny2): continue
			var nidx: int = nx2 * MAP_SIZE + ny2
			var next_z: int = int(_dungeon_elevation[nidx]) if _dungeon_elevation.size() > nidx else 1
			if next_z == 0: continue
			var step_cost: int = 2 if (next_z == 2 and cur_z < 2) else 1
			if step_cost > steps_left: continue
			ent["x"] = nx2; ent["y"] = ny2
			steps_left -= step_cost
			moved = true; break
		if not moved: break

func _enemy_move_away(ent: Dictionary, threat: Dictionary, steps: int) -> void:
	var steps_left: int = steps
	while steps_left > 0:
		var dx: int = ent["x"] - threat["x"]   # reversed: away from threat
		var dy: int = ent["y"] - threat["y"]
		if dx == 0 and dy == 0: break
		var dirs: Array
		if abs(dx) >= abs(dy):
			dirs = [[sign(dx),0],[0,sign(dy)],[-sign(dx),0],[0,-sign(dy)]]
		else:
			dirs = [[0,sign(dy)],[sign(dx),0],[0,-sign(dy)],[-sign(dx),0]]
		var moved: bool = false
		for dir in dirs:
			var nx2: int = ent["x"] + dir[0]
			var ny2: int = ent["y"] + dir[1]
			if _dung_tile(nx2, ny2) != TILE_FLOOR: continue
			if _dung_occupied(nx2, ny2): continue
			var nidx: int = nx2 * MAP_SIZE + ny2
			if nidx < _dungeon_elevation.size() and int(_dungeon_elevation[nidx]) == 0: continue
			ent["x"] = nx2; ent["y"] = ny2
			steps_left -= 1
			moved = true; break
		if not moved: break

# ── Movement ──────────────────────────────────────────────────────────────────

## Move a player entity to (nx, ny).
## Movement costs tiles from the move budget only — 0 AP (matching Rimvale Mobile).
func move_dungeon_player(id: String, nx: int, ny: int) -> bool:
	var ent = _dung_find(id)
	if ent == null or not ent["is_player"] or ent["is_dead"]: return false
	if _dung_has_condition(ent, "grappled"): return false
	var moves: Array = get_valid_dungeon_moves(id)
	var cost: int = 0
	var ok: bool  = false
	for m in moves:
		if m["x"] == nx and m["y"] == ny:
			cost = m["tile_cost"]; ok = true; break
	if not ok: return false
	ent["x"] = nx
	ent["y"] = ny
	ent["move_used"] += cost   # movement costs tiles only — never AP
	_update_fog()
	return true

## Return all tiles the entity can reach this turn.
## Rules (matching Rimvale Mobile):
##   • Movement is FREE (0 AP), uses a separate tile budget = speed − move_used.
##   • Normal floor       → 1 tile cost.
##   • Climbing to elev 2 → 2 tile cost.
##   • Ally standing on tile → difficult terrain (2 tiles), CAN pass through, CANNOT stop.
##   • Enemy on tile      → blocks movement entirely (cannot enter).
##   • Elevation-0 pits   → impassable.
func get_valid_dungeon_moves(id: String) -> Array:
	var ent = _dung_find(id)
	if ent == null or not ent["is_player"] or ent["is_dead"]: return []
	if _dung_has_condition(ent, "grappled"): return []

	# Budget: how many tiles remain this turn
	var budget: int = maxi(0, ent["speed"] - ent["move_used"])
	if budget == 0: return []

	var is_flying: bool = _dung_has_condition(ent, "flying")

	# BFS — visited stores the cheapest tile-cost seen for each grid key.
	# Each node carries a "pass_only" flag: true when the tile is occupied by an ally
	# (can route through, but cannot be a final destination).
	var visited: Dictionary = {}
	var queue: Array        = [{"x": ent["x"], "y": ent["y"], "cost": 0, "pass_only": false}]
	visited[ent["x"] * 1000 + ent["y"]] = 0
	var result: Array       = []

	while not queue.is_empty():
		var cur: Dictionary = queue.pop_front()
		# Reachable stop tile: cost > 0 and not blocked by a standing ally
		if cur["cost"] > 0 and not cur["pass_only"]:
			result.append({"x": cur["x"], "y": cur["y"], "tile_cost": cur["cost"]})
		if cur["cost"] >= budget: continue

		var cur_idx: int = cur["x"] * MAP_SIZE + cur["y"]
		var cur_z: int   = int(_dungeon_elevation[cur_idx]) if _dungeon_elevation.size() > cur_idx else 1

		for dir in [[0,1],[0,-1],[1,0],[-1,0]]:
			var nx2: int = cur["x"] + dir[0]
			var ny2: int = cur["y"] + dir[1]
			var tile: int = _dung_tile(nx2, ny2)

			# Flying units can cross floor + obstacle + wall tiles, but never void
			if is_flying:
				if tile == TILE_VOID: continue
			else:
				if tile != TILE_FLOOR: continue

			# Check who (if anyone) is on the neighbour tile
			var occupant = _dung_entity_at(nx2, ny2)
			var is_enemy: bool = occupant != null and not bool(occupant.get("is_player", false)) \
								 and not bool(occupant.get("is_friendly", false))
			var is_ally:  bool = occupant != null and not is_enemy \
								 and str(occupant["id"]) != id

			# Flying units soar over all characters — treat occupied tiles as
			# pass-through (can fly over, cannot stop on top of someone).
			# Grounded units: enemies block entirely, allies = difficult terrain.
			if is_flying:
				# Can fly over anyone, but cannot land on an occupied tile
				pass   # handled below via pass_only
			else:
				if is_enemy: continue

			# Elevation
			var nidx: int   = nx2 * MAP_SIZE + ny2
			var next_z: int = int(_dungeon_elevation[nidx]) if _dungeon_elevation.size() > nidx else 1
			if not is_flying and next_z == 0: continue   # pits are impassable (flying ignores)

			# Tile cost: climbing = 2, ally (difficult terrain) = 2, otherwise 1
			# Flying ignores climbing cost and difficult terrain from allies
			var step_cost: int = 1
			if not is_flying:
				if next_z == 2 and cur_z < 2: step_cost = 2
				if is_ally: step_cost = maxi(step_cost, 2)

			var new_cost: int = cur["cost"] + step_cost
			if new_cost > budget: continue

			# pass_only: tile is occupied (cannot land there)
			var pass_only: bool = occupant != null and str(occupant["id"]) != id
			if not is_flying:
				pass_only = is_ally   # grounded: only allies are pass-through

			var k: int = nx2 * 1000 + ny2
			if visited.has(k) and visited[k] <= new_cost: continue
			visited[k] = new_cost
			queue.append({"x": nx2, "y": ny2, "cost": new_cost, "pass_only": pass_only})
	return result

# ── Unified action dispatcher ─────────────────────────────────────────────────

## Execute any DungeonAction on behalf of entity_id.
## target_id — entity ID for single-target actions (attacks, spells, grapple)
## cx, cy    — tile coordinates for area spells / teleport
## Returns: {success, log, ap_spent, sp_spent}
func dungeon_perform_action(
		entity_id: String,
		action: Dictionary,
		target_id: String = "",
		cx: int = -1, cy: int = -1) -> Dictionary:

	var ent = _dung_find(entity_id)
	if ent == null or ent["is_dead"]:
		return _dung_fail("No valid actor.")

	# Escalating AP cost: 1st action = 1 AP, 2nd = 2 AP, etc.
	# Free actions (ap_cost == 0) bypass the escalation.
	var base_ap: int = action.get("ap_cost", 0)
	var ap_cost: int = base_ap
	if base_ap > 0:
		ap_cost = int(ent.get("actions_taken", 0)) + 1
	var sp_cost: int = action.get("sp_cost", 0)
	var ap_left: int = ent["max_ap"] - ent["ap_spent"]
	var sp_left: int = ent["sp"]

	if ap_cost > ap_left:
		return _dung_fail("Not enough AP! (need %d, have %d)" % [ap_cost, ap_left])
	if sp_cost > sp_left:
		return _dung_fail("Not enough SP! (need %d, have %d)" % [sp_cost, sp_left])

	# Increment action counter for escalating cost (only for non-free actions)
	if base_ap > 0:
		ent["actions_taken"] = int(ent.get("actions_taken", 0)) + 1

	var action_id: int = action.get("action_id", -1)

	match action_id:
		ACT_MELEE:
			return _dung_dispatch_melee(ent, target_id, ent["equipped_weapon"], ap_cost)
		ACT_RANGED:
			return _dung_dispatch_ranged(ent, target_id, ent["equipped_weapon"], ap_cost)
		ACT_UNARMED:
			return _dung_dispatch_attack(ent, target_id, "", ap_cost)
		ACT_GRAPPLE:
			return _dung_dispatch_grapple(ent, target_id, ap_cost)
		ACT_DODGE:
			return _dung_dispatch_dodge(ent, ap_cost)
		ACT_REST:
			return _dung_dispatch_rest(ent, ap_cost)
		ACT_HIDE:
			return _dung_dispatch_hide(ent, ap_cost)
		ACT_INTERACT:
			return _dung_dispatch_interact(ent, ap_cost)
		ACT_RELOAD:
			return _dung_dispatch_reload(ent, ap_cost)
		ACT_ESC_GRAPPLE:
			return _dung_dispatch_escape_grapple(ent, ap_cost)
		ACT_EXTRA_MOVE:
			return _dung_dispatch_extra_move(ent, ap_cost)
		ACT_USE_ITEM:
			return _dung_dispatch_use_item(ent, action.get("matrix_id", ""), ap_cost)
		ACT_CAST_SPELL:
			return _dung_dispatch_spell(ent, action, target_id, cx, cy, ap_cost, sp_cost)
		ACT_ACTIVATE_MTX:
			return _dung_dispatch_activate_matrix(ent, str(action.get("matrix_id","")), ap_cost)
		ACT_END_MTX:
			return _dung_dispatch_end_matrix(ent, str(action.get("matrix_id","")), ap_cost)
		ACT_TRAIT:
			return _dung_dispatch_trait(ent, str(action.get("matrix_id","")), ap_cost)
		ACT_FLY_TOGGLE:
			return dungeon_toggle_fly(entity_id)
		ACT_FLY_LAND:
			return dungeon_toggle_fly(entity_id)
		ACT_FLY_ASCEND:
			return dungeon_set_entity_z(entity_id, 1)
		ACT_FLY_DESCEND:
			return dungeon_set_entity_z(entity_id, -1)
		ACT_SHAPESHIFT:
			# Form name and SP spent are passed via action extras set by the UI
			var form_name: String = str(action.get("_shapeshift_form", ""))
			var sp_invest: int    = int(action.get("_shapeshift_sp", 0))
			if form_name == "":
				return _dung_fail("No form selected.")
			ent["ap_spent"] = int(ent["ap_spent"]) + ap_cost
			return dung_apply_shapeshift(entity_id, form_name, sp_invest)
		ACT_REVERT_SHAPESHIFT:
			return dung_revert_shapeshift(entity_id, 0)
		ACT_SUMMON_FEAT:
			ent["ap_spent"] = int(ent["ap_spent"]) + ap_cost
			var sf_type: String = str(action.get("matrix_id", "minion_master"))
			return dung_activate_summon_feat(entity_id, sf_type)
		ACT_DISMISS_CONSTRUCT:
			return _dung_dismiss_construct(ent, str(action.get("matrix_id", "")))
		ACT_RECALL_CONSTRUCT:
			ent["ap_spent"] = int(ent["ap_spent"]) + ap_cost
			return _dung_recall_construct(ent, str(action.get("matrix_id", "")))
		ACT_REFORM_CONSTRUCT:
			ent["ap_spent"] = int(ent["ap_spent"]) + ap_cost
			return _dung_reform_construct(ent, str(action.get("matrix_id", "")))
		_:
			return _dung_fail("Action '%s' (id=%d) not implemented." % [action.get("name","?"), action_id])

# ── Action implementations ────────────────────────────────────────────────────

## Weapon range in tiles by type keyword
func _weapon_range_tiles(weapon: String) -> int:
	var w: String = weapon.to_lower()
	if "longbow" in w:              return 20
	if "shortbow" in w or "bow" in w: return 12
	if "crossbow" in w:             return 15
	if "rifle" in w:                return 24
	if "pistol" in w:               return 8
	if "sling" in w or "dart" in w: return 6
	if "javelin" in w:              return 6
	if "wand" in w or "staff" in w: return 10
	if "thrown" in w:               return 4
	return 3   # fallback for generic ranged

## Ammo tracker: "entity_id:weapon" → int remaining
var _dungeon_ammo: Dictionary = {}

func _ammo_key(entity_id: String, weapon: String) -> String:
	return "%s:%s" % [entity_id, weapon]

func _get_ammo(entity_id: String, weapon: String) -> int:
	var key: String = _ammo_key(entity_id, weapon)
	if not _dungeon_ammo.has(key):
		_dungeon_ammo[key] = 20   # default starting ammo
	return int(_dungeon_ammo[key])

func _spend_ammo(entity_id: String, weapon: String) -> bool:
	var key: String = _ammo_key(entity_id, weapon)
	var current: int = _get_ammo(entity_id, weapon)
	if current <= 0: return false
	_dungeon_ammo[key] = current - 1
	return true

func _reload_ammo(entity_id: String, weapon: String) -> void:
	_dungeon_ammo[_ammo_key(entity_id, weapon)] = 20

func get_ammo_count(entity_id: String, weapon: String) -> int:
	return _get_ammo(entity_id, weapon)

## Cover check: returns +2 AC bonus if a wall/obstacle is adjacent to target
func _cover_bonus(tx: int, ty: int) -> int:
	var dirs: Array = [[1,0],[-1,0],[0,1],[0,-1]]
	for d in dirs:
		var nx: int = tx + int(d[0])
		var ny: int = ty + int(d[1])
		var t: int = _dung_tile(nx, ny)
		if t == TILE_WALL or t == TILE_OBSTACLE:
			return 2
	return 0

## Chebyshev distance (diagonal = 1)
func _chebyshev(x0: int, y0: int, x1: int, y1: int) -> int:
	return maxi(abs(x1 - x0), abs(y1 - y0))

func _dung_dispatch_melee(atk: Dictionary, target_id: String, weapon: String, ap_cost: int) -> Dictionary:
	var tgt = _dung_find(target_id)
	if tgt == null or bool(tgt["is_dead"]):
		return _dung_fail("No valid target.")
	if bool(atk["is_player"]) == bool(tgt["is_player"]):
		return _dung_fail("Cannot attack an ally.")
	# Melee range check: Chebyshev ≤ 1 (or flying can dive from any altitude)
	var dist: int = _chebyshev(int(atk["x"]), int(atk["y"]), int(tgt["x"]), int(tgt["y"]))
	if dist > 1 and not _dung_has_condition(atk, "flying"):
		return _dung_fail("Target is not adjacent (distance %d)." % dist)
	atk["ap_spent"] += ap_cost
	var result: Dictionary = _dung_do_attack(atk, tgt, weapon, false)
	return _dung_ok(result["log"], ap_cost, 0)

func _dung_dispatch_ranged(atk: Dictionary, target_id: String, weapon: String, ap_cost: int) -> Dictionary:
	var tgt = _dung_find(target_id)
	if tgt == null or bool(tgt["is_dead"]):
		return _dung_fail("No valid target.")
	if bool(atk["is_player"]) == bool(tgt["is_player"]):
		return _dung_fail("Cannot attack an ally.")
	# Range check
	var max_range: int = _weapon_range_tiles(weapon)
	var dist: int = _chebyshev(int(atk["x"]), int(atk["y"]), int(tgt["x"]), int(tgt["y"]))
	if dist > max_range:
		return _dung_fail("Target is out of range (dist %d, max %d)." % [dist, max_range])
	# Ammo check
	var entity_id: String = str(atk.get("id", ""))
	if not _spend_ammo(entity_id, weapon):
		return _dung_fail("No ammo! Use Reload before shooting.")
	# Cover bonus: target gets +2 AC if adjacent to wall/obstacle
	var cover: int = _cover_bonus(int(tgt["x"]), int(tgt["y"]))
	var note: String = ""
	if cover > 0:
		note = " (target has cover +%d AC)" % cover
	atk["ap_spent"] += ap_cost
	var result: Dictionary = _dung_do_attack(atk, tgt, weapon, false, cover)
	return _dung_ok(result["log"] + note + " [%d ammo left]" % _get_ammo(entity_id, weapon), ap_cost, 0)

func _dung_dispatch_attack(atk: Dictionary, target_id: String, weapon: String, ap_cost: int) -> Dictionary:
	var tgt = _dung_find(target_id)
	if tgt == null or tgt["is_dead"]:
		return _dung_fail("No valid target.")
	if atk["is_player"] == tgt["is_player"]:
		return _dung_fail("Cannot attack an ally.")
	atk["ap_spent"] += ap_cost
	var result: Dictionary = _dung_do_attack(atk, tgt, weapon, weapon == "")
	return _dung_ok(result["log"], ap_cost, 0)

func _dung_dispatch_grapple(atk: Dictionary, target_id: String, ap_cost: int) -> Dictionary:
	var tgt = _dung_find(target_id)
	if tgt == null or tgt["is_dead"]:
		return _dung_fail("No valid target.")
	# Must be adjacent
	var dist: int = abs(tgt["x"] - atk["x"]) + abs(tgt["y"] - atk["y"])
	if dist > 1:
		return _dung_fail("Target is not adjacent.")
	atk["ap_spent"] += ap_cost
	# Contest: d20 + 4 vs d20 + target's (speed / 2)
	var atk_roll: int = randi_range(1, 20) + 4
	var def_roll: int = randi_range(1, 20) + (tgt["speed"] / 2)
	if atk_roll >= def_roll:
		_dung_add_condition(tgt, "grappled")
		return _dung_ok("%s grapples %s! (rolled %d vs %d) %s cannot move." % [
			atk["name"], tgt["name"], atk_roll, def_roll, tgt["name"]], ap_cost, 0)
	else:
		return _dung_ok("%s tries to grapple %s — failed! (rolled %d vs %d)" % [
			atk["name"], tgt["name"], atk_roll, def_roll], ap_cost, 0)

func _dung_dispatch_dodge(ent: Dictionary, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	_dung_add_condition(ent, "dodging")
	var bonus: int = 3
	# Deflective Stance: +tier AC when dodging (additional to base +3)
	var ds_t: int = _ent_feat_tier(ent, "Deflective Stance")
	if ds_t >= 1: bonus += mini(ds_t, 4)
	# Agile Explorer: +1 AC when dodging per tier
	var ae_t: int = _ent_feat_tier(ent, "Agile Explorer")
	if ae_t >= 1: bonus += mini(ae_t, 3)
	return _dung_ok("%s takes a defensive stance. (+%d AC until next turn)" % [ent["name"], bonus], ap_cost, 0)

func _dung_dispatch_hide(ent: Dictionary, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	_dung_add_condition(ent, "hidden")
	return _dung_ok("%s slips into the shadows." % ent["name"], ap_cost, 0)

func _dung_dispatch_rest(ent: Dictionary, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	# Recover HP and SP proportional to AP spent
	var hp_gain: int = maxi(1, ent["max_hp"] / 4)
	var sp_gain: int = maxi(1, ent["max_sp"] / 4)

	# Rest & Recovery feat: T1 +25% rest HP, T2 +50%, T3 +SP on rest, T4 remove condition
	var rr_t: int = _ent_feat_tier(ent, "Rest & Recovery")
	if rr_t >= 2: hp_gain = int(hp_gain * 1.5)
	elif rr_t >= 1: hp_gain = int(hp_gain * 1.25)
	if rr_t >= 3: sp_gain += 1
	if rr_t >= 4:
		# Remove a random negative condition
		for cond in ["poisoned", "bleeding", "burning", "slowed"]:
			if _dung_has_condition(ent, cond):
				_dung_remove_condition(ent, cond); break

	# Explorer's Grit: +1 HP recovered per tier
	var eg_t: int = _ent_feat_tier(ent, "Explorer's Grit")
	if eg_t >= 1: hp_gain += eg_t

	# Healing & Restoration: add Divinity to rest healing
	var hr_t: int = _ent_feat_tier(ent, "Healing & Restoration")
	if hr_t >= 1:
		var h: int = int(ent.get("handle", -1))
		if h >= 0 and _chars.has(h):
			var div_v: int = int(_chars[h].get("stats", [1,1,1,1,1])[4])
			if hr_t >= 5: hp_gain += div_v * 3
			elif hr_t >= 3: hp_gain += div_v * 2
			else: hp_gain += div_v

	ent["hp"] = mini(ent["max_hp"], ent["hp"] + hp_gain)
	ent["sp"] = mini(ent["max_sp"], ent["sp"] + sp_gain)
	# Also sync back to character sheet if this is a player
	var handle: int = ent.get("handle", -1)
	if handle >= 0 and _chars.has(handle):
		_chars[handle]["hp"] = ent["hp"]
		_chars[handle]["sp"] = ent["sp"]
	return _dung_ok("%s rests — recovered %d HP and %d SP." % [ent["name"], hp_gain, sp_gain], ap_cost, 0)

func _dung_dispatch_interact(ent: Dictionary, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	return _dung_ok("%s interacts with the environment." % ent["name"], ap_cost, 0)

func _dung_dispatch_reload(ent: Dictionary, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	var weapon: String = str(ent["equipped_weapon"])
	var entity_id: String = str(ent.get("id", ""))
	_reload_ammo(entity_id, weapon)
	return _dung_ok("%s reloads their %s. (20 ammo)" % [ent["name"], weapon], ap_cost, 0)

func _dung_dispatch_escape_grapple(ent: Dictionary, ap_cost: int) -> Dictionary:
	ent["ap_spent"] += ap_cost
	var roll: int = randi_range(1, 20) + 2
	if roll >= 12:
		_dung_remove_condition(ent, "grappled")
		return _dung_ok("%s breaks free from the grapple! (rolled %d)" % [ent["name"], roll], ap_cost, 0)
	else:
		return _dung_ok("%s struggles but can't break free. (rolled %d)" % [ent["name"], roll], ap_cost, 0)

func _dung_dispatch_extra_move(ent: Dictionary, ap_cost: int) -> Dictionary:
	ent["ap_spent"]  += ap_cost
	ent["move_used"] = maxi(0, ent["move_used"] - ent["speed"])  # grant extra move budget
	return _dung_ok("%s surges forward with extra movement." % ent["name"], ap_cost, 0)

func _dung_dispatch_use_item(ent: Dictionary, item_name: String, ap_cost: int) -> Dictionary:
	var handle: int = ent.get("handle", -1)
	if handle < 0 or not _chars.has(handle):
		return _dung_fail("Item not found.")
	var char_data: Dictionary = _chars[handle]
	var items: Array = char_data.get("items", [])
	if not item_name in items:
		return _dung_fail("%s is not in inventory." % item_name)
	ent["ap_spent"] += ap_cost
	items.erase(item_name)

	# Use the shared consumable effect system
	var result: String = _apply_consumable_effect(ent, item_name)

	# Special combat-only items that need target/area logic
	if result == "":
		match item_name:
			"Holy Water (flask)":
				# Deals 2d6 radiant to all undead within 1 tile
				var dmg: int = _roll_dice(2, 6)
				var hit_count: int = 0
				for adj in _dungeon_entities:
					if bool(adj.get("is_dead", false)): continue
					if adj.get("is_player", false): continue
					if absi(int(adj["x"]) - int(ent["x"])) <= 1 and absi(int(adj["y"]) - int(ent["y"])) <= 1:
						var mob_name: String = str(adj.get("name", "")).to_lower()
						if "undead" in mob_name or "skeleton" in mob_name or "zombie" in mob_name or "ghost" in mob_name or "wraith" in mob_name or "lich" in mob_name or "vampire" in mob_name:
							_dung_reduce_hp(adj, dmg)
							if adj["hp"] == 0: adj["is_dead"] = true; adj["conditions"].clear()
							hit_count += 1
				result = "%s throws Holy Water — %d radiant to %d undead!" % [ent["name"], dmg, hit_count]
			"Alchemist's Fire (flask)":
				# Deals 1d4 fire + applies burning to closest enemy
				var closest = _dung_closest_enemy(ent)
				if closest != null:
					var fire_dmg: int = _roll_dice(1, 4)
					_dung_reduce_hp(closest, fire_dmg)
					if closest["hp"] == 0: closest["is_dead"] = true; closest["conditions"].clear()
					else: _dung_add_condition(closest, "burning")
					result = "%s throws Alchemist's Fire at %s — %d fire damage + burning!" % [ent["name"], closest["name"], fire_dmg]
				else:
					result = "%s throws Alchemist's Fire but no target in range." % ent["name"]
			"Acid (vial)":
				var closest = _dung_closest_enemy(ent)
				if closest != null:
					var acid_dmg: int = _roll_dice(2, 6)
					_dung_reduce_hp(closest, acid_dmg)
					if closest["hp"] == 0: closest["is_dead"] = true; closest["conditions"].clear()
					else: _dung_add_condition(closest, "acid_corroded")
					result = "%s throws Acid at %s — %d acid damage!" % [ent["name"], closest["name"], acid_dmg]
				else:
					result = "%s throws Acid but no target in range." % ent["name"]
			_:
				result = "%s uses %s." % [ent["name"], item_name]

	# Sync dungeon entity stats back to character sheet
	if handle >= 0 and _chars.has(handle):
		_chars[handle]["hp"] = ent["hp"]
		_chars[handle]["sp"] = ent.get("sp", _chars[handle].get("sp", 0))
		_chars[handle]["ap"] = ent.get("ap", _chars[handle].get("ap", 0))

	return _dung_ok(result, ap_cost, 0)

## Spell casting — single-target, multi-target, and area resolution.
func _dung_dispatch_spell(
		caster: Dictionary, action: Dictionary,
		target_id: String, cx: int, cy: int, ap_cost: int, sp_cost: int) -> Dictionary:
	_ensure_spell_db()
	var spell_name: String = str(action.get("matrix_id", ""))
	if not _SPELL_DB.has(spell_name):
		return _dung_fail("Unknown spell: %s" % spell_name)

	var s: Dictionary = _SPELL_DB[spell_name]

	# ── Special: Summon spells — uses creature builder parameters from UI ──
	if spell_name == "Summon Creature" or spell_name == "Animate Undead" or bool(s.get("summon", false)):
		var build: Dictionary = action.get("_summon_build", {})
		if build.is_empty():
			return _dung_fail("No creature build provided — open the creature builder first.")
		return _dung_cast_summon_creature(caster, spell_name, build, ap_cost)

	# ── Special: Construct spells — uses construct builder parameters from UI ──
	if bool(s.get("construct", false)):
		var build: Dictionary = action.get("_construct_build", {})
		if build.is_empty():
			return _dung_fail("No construct build provided — open the construct builder first.")
		return _dung_cast_create_construct(caster, spell_name, build, ap_cost)

	var area_type: int  = int(s["area"])
	var range_tiles: int = int(s["rt"])
	var is_attack: bool = bool(s["atk"])
	var is_heal: bool   = bool(s["heal"])
	var die_count: int  = int(s["dc"])
	var die_sides: int  = int(s["ds"])
	var is_tp: bool     = bool(s["tp"])
	var conds: Array    = s.get("conds", [])
	var dur: int        = int(s["dur"])
	var spell_dom: String = str(s.get("dom", "Physical"))
	var is_ritual: bool   = bool(action.get("ritual", false))

	# ── Fix #3 & #7: Apply alignment, domain affinity, regional, and feat modifiers ──
	var total_mod: int = _alignment_sp_modifier(caster, spell_dom)
	total_mod += _regional_sp_modifier()
	total_mod += _feat_sp_modifier(caster, spell_dom)
	sp_cost = maxi(0, sp_cost + total_mod)
	# Ritual casting: no SP, but lengthy (narrative/time cost applied elsewhere).
	sp_cost = _ritual_adjusted_cost(sp_cost, is_ritual)
	# Phase 3: Arcane Wellspring effects
	sp_cost = _arcane_wellspring_sp_modify(caster, sp_cost)
	# Phase 3: Blood Magic free spell on kill (T5) — 0 SP if flag is set
	if bool(caster.get("blood_magic_free_spell", false)):
		sp_cost = 0
		caster["blood_magic_free_spell"] = false
	# Phase 4: Domain expertise SP scaling (-1 to -6 by expertise level)
	sp_cost = _domain_expertise_sp_modify(caster, spell_dom, sp_cost)

	# ── PHB Combustion: damage dice = half total SP on the scaling table ──────
	# The scaling table (PHB p.174):
	#   1→1d4, 2→1d6, 3→1d8, 4→1d10, 5→1d12,
	#   6→2d4, 7→2d6, 8→2d8, 9→2d10, 10→2d12,
	#   11→3d4, 12→3d6, 13→3d8, 14→3d10, 15→3d12, ...
	if bool(s.get("combustion", false)):
		var half_sp: int = maxi(1, sp_cost / 2)
		var combo: Array = _sp_to_dice(half_sp)
		die_count = int(combo[0])
		die_sides = int(combo[1])

	# ── Fix #4: Overreach check — casting beyond SP pool triggers domain penalty ──
	var overreach_log: String = ""
	var deficit: int = maxi(0, sp_cost - int(caster["sp"]))
	if deficit > 0 and not is_ritual:
		overreach_log = _trigger_overreach(caster, spell_dom, deficit)

	# Deduct costs
	caster["ap_spent"] += ap_cost
	caster["sp"]        = maxi(0, int(caster["sp"]) - sp_cost)
	var handle: int = caster.get("handle", -1)
	if handle >= 0 and _chars.has(handle): _chars[handle]["sp"] = caster["sp"]

	# Verdant Channeler / Biological Domain T2: Bio spell → +SP_spent to next attack
	_verdant_channeler_check(caster, spell_dom, sp_cost)

	# Phase 3: Track last spell for Spell Echo
	caster["last_spell_cast"] = spell_name
	caster["last_spell_target"] = target_id

	# Phase 4: Void Aura spell failure — 50% chance to fizzle when caster has "void_aura" condition
	if _dung_has_condition(caster, "void_aura") and randi() % 2 == 0:
		var void_msg: String = "%s casts %s — VOID AURA DISRUPTION! Spell fizzles (50%% failure)." % [
			caster["name"], spell_name]
		if overreach_log != "": void_msg = overreach_log + "\n" + void_msg
		return _dung_ok(void_msg, ap_cost, sp_cost)

	# ── Self spells (range_tiles == 0, no target needed) ──
	if range_tiles == 0 and area_type == 0:
		var log_parts: Array = []
		if not conds.is_empty():
			for cond in conds:
				_dung_add_condition(caster, cond)
				log_parts.append(cond)
		if is_heal and die_count > 0:
			var heal: int = _roll_dice(die_count, die_sides)
			caster["hp"] = mini(int(caster["max_hp"]), int(caster["hp"]) + heal)
			if handle >= 0 and _chars.has(handle): _chars[handle]["hp"] = caster["hp"]
			log_parts.append("healed %d HP" % heal)
		var cond_str: String = (", ".join(log_parts)) if not log_parts.is_empty() else "activated"
		var dur_note: String = (" [sustained %d rounds]" % dur) if dur > 0 else ""
		if dur > 0:
			_dung_register_matrix(str(caster["id"]), spell_name, dur,
				str(caster["id"]), is_attack, conds)
		var self_msg: String = "%s casts %s — %s%s." % [
			caster["name"], spell_name, cond_str, dur_note]
		if overreach_log != "": self_msg = overreach_log + "\n" + self_msg
		return _dung_ok(self_msg, ap_cost, sp_cost)

	# ── Teleport ──
	if is_tp:
		if cx < 0 or cy < 0:
			return _dung_fail("Teleport requires a destination tile.")
		var tile: int = _dung_tile(cx, cy)
		if tile != 1:   # must be a floor tile
			return _dung_fail("Cannot teleport to that tile.")
		if _dung_occupied(cx, cy):
			return _dung_fail("Cannot teleport to an occupied tile.")
		# Determine who gets teleported: target_id entity or self
		var tp_subject = caster
		var tp_subject_name: String = caster["name"]
		var tp_target_id: String = str(action.get("_teleport_target_id", ""))
		if tp_target_id != "" and tp_target_id != str(caster["id"]):
			var tp_tgt = _dung_find(tp_target_id)
			if tp_tgt != null and not tp_tgt["is_dead"]:
				tp_subject = tp_tgt
				tp_subject_name = tp_tgt["name"]
		# Chebyshev distance from the subject's current position
		var tp_dx: int = abs(cx - int(tp_subject["x"]))
		var tp_dy: int = abs(cy - int(tp_subject["y"]))
		var dist_tiles: int = maxi(tp_dx, tp_dy)
		# Check if teleport has pre-paid range (ritual spell)
		var tp_max_range: int = int(action.get("tp_range", 0))
		var extra_sp: int = 0
		if tp_max_range > 0:
			# Pre-paid ritual teleport: enforce range limit, no extra SP
			if dist_tiles > tp_max_range:
				return _dung_fail("Out of range! Max teleport distance: %d tiles (you tried %d)." % [tp_max_range, dist_tiles])
		else:
			# Ad-hoc teleport: dynamic SP scaling by distance
			var tp_remaining: int = dist_tiles
			var bracket: int = 1
			while tp_remaining > 0:
				var chunk: int = mini(tp_remaining, 3)
				extra_sp += chunk * bracket
				tp_remaining -= chunk
				bracket += 1
			extra_sp = maxi(0, extra_sp / 3)
			if int(caster["sp"]) < extra_sp:
				return _dung_fail("Not enough SP for teleport distance (need %d extra SP)." % extra_sp)
			caster["sp"] = maxi(0, int(caster["sp"]) - extra_sp)
			var tp_handle: int = caster.get("handle", -1)
			if tp_handle >= 0 and _chars.has(tp_handle): _chars[tp_handle]["sp"] = caster["sp"]
		tp_subject["x"] = cx
		tp_subject["y"] = cy
		if tp_max_range > 0:
			# Ritual teleport — no extra SP message
			if tp_subject == caster:
				return _dung_ok("%s teleports to (%d, %d) [%d tiles]." % [
					caster["name"], cx, cy, dist_tiles], ap_cost, sp_cost)
			else:
				return _dung_ok("%s teleports %s to (%d, %d) [%d tiles]." % [
					caster["name"], tp_subject_name, cx, cy, dist_tiles], ap_cost, sp_cost)
		else:
			if tp_subject == caster:
				return _dung_ok("%s teleports to (%d, %d) [%d tiles, %d extra SP]." % [
					caster["name"], cx, cy, dist_tiles, extra_sp], ap_cost, sp_cost + extra_sp)
			else:
				return _dung_ok("%s teleports %s to (%d, %d) [%d tiles, %d extra SP]." % [
					caster["name"], tp_subject_name, cx, cy, dist_tiles, extra_sp], ap_cost, sp_cost + extra_sp)

	# ── Area spells ──
	if area_type > 0:
		if cx < 0 or cy < 0:
			return _dung_fail("Area spell requires a target tile.")
		const AREA_RADII: Array = [0, 1, 3, 10]
		var radius: int = AREA_RADII[clampi(area_type, 0, 3)]
		# Collect all entities within radius
		var targets: Array = []
		for e in _dungeon_entities:
			if e["is_dead"]: continue
			var edx: int = int(e["x"]) - cx
			var edy: int = int(e["y"]) - cy
			# Chebyshev distance (square area)
			if maxi(abs(edx), abs(edy)) <= radius:
				# For attack spells, target enemies; for heal, target allies
				if is_attack and e["is_player"] == caster["is_player"]: continue
				if is_heal and e["is_player"] != caster["is_player"]:  continue
				targets.append(e)
		if targets.is_empty():
			var empty_msg: String = "%s casts %s — no targets in area." % [caster["name"], spell_name]
			if overreach_log != "": empty_msg = overreach_log + "\n" + empty_msg
			return _dung_ok(empty_msg, ap_cost, sp_cost)
		var logs: Array = []
		for tgt in targets:
			var entry: String = _spell_apply_to_target(caster, tgt, spell_name,
				is_attack, is_heal, die_count, die_sides, conds, dur, false)
			logs.append(entry)
		var area_msg: String = "\n".join(logs)
		if overreach_log != "": area_msg = overreach_log + "\n" + area_msg
		return _dung_ok(area_msg, ap_cost, sp_cost)

	# ── Single/multi-target spells ──
	if target_id == "":
		# Self-range fallthrough (shouldn't normally arrive here)
		return _dung_fail("%s requires a target." % spell_name)

	var tgt = _dung_find(target_id)
	if tgt == null or tgt["is_dead"]:
		return _dung_fail("Target is dead or invalid.")

	# Range check (Chebyshev distance)
	if range_tiles > 0:
		var rdx: int = abs(int(tgt["x"]) - int(caster["x"]))
		var rdy: int = abs(int(tgt["y"]) - int(caster["y"]))
		if maxi(rdx, rdy) > range_tiles:
			return _dung_fail("%s is out of range (max %d tiles)." % [spell_name, range_tiles])

	var log_entry: String = _spell_apply_to_target(caster, tgt, spell_name,
		is_attack, is_heal, die_count, die_sides, conds, dur, is_attack)
	if overreach_log != "": log_entry = overreach_log + "\n" + log_entry
	return _dung_ok(log_entry, ap_cost, sp_cost)

## Apply a single spell effect to one target. Returns a log string.
func _spell_apply_to_target(
		caster: Dictionary, tgt: Dictionary, spell_name: String,
		is_attack: bool, is_heal: bool,
		die_count: int, die_sides: int,
		conds: Array, dur: int, needs_hit: bool) -> String:

	var dur_note: String = (" [sustained %d rounds]" % dur) if dur > 0 else ""

	# Attack spells need a to-hit roll — PHB: D20 + DIV + Arcane
	if needs_hit:
		var spell_bonus: int = 3  # fallback for creatures
		var c_handle: int = int(caster.get("handle", -1))
		if c_handle >= 0 and _chars.has(c_handle):
			var ca: Dictionary = _chars[c_handle]
			var ch_stats: Array = ca.get("stats", [1,1,1,1,1])
			var ch_skills: Array = ca.get("skills", [0,0,0,0,0,0,0,0,0,0,0,0,0,0])
			spell_bonus = int(ch_stats[4]) + int(ch_skills[0])  # DIV + Arcane
			# Phase 3: Lineage spell attack bonuses
			var lineage: String = str(ca.get("lineage", ""))
			if lineage == "Runeborn Human":
				spell_bonus += randi_range(1, 4)   # Runeborn Primed: +1d4 spell attack
			elif lineage == "Sparkforged Human":
				spell_bonus += 2                    # Sparkforged Primed: +2 spell attack
		# Safeguard T3 inspiration: +1d4 to next action, then consumed
		if _dung_has_condition(caster, "safeguard_inspire"):
			spell_bonus += randi_range(1, 4)
			caster["conditions"].erase("safeguard_inspire")
		var raw_d20: int = randi_range(1, 20)
		# Phase 3: Groblodyte Arcane Misfire — nat 1 deals 1d6 self damage
		if raw_d20 == 1:
			var gro_handle: int = int(caster.get("handle", -1))
			if gro_handle >= 0 and _chars.has(gro_handle):
				var gro_lineage: String = str(_chars[gro_handle].get("lineage", ""))
				if gro_lineage == "Groblodyte":
					var self_dmg: int = randi_range(1, 6)
					_dung_reduce_hp(caster, self_dmg)
					if gro_handle >= 0 and _chars.has(gro_handle): _chars[gro_handle]["hp"] = caster["hp"]
					return "%s casts %s at %s — ARCANE MISFIRE! Took %d self damage (nat 1)." % [
						caster["name"], spell_name, tgt["name"], self_dmg]
		var roll: int = raw_d20 + spell_bonus
		var eff_ac: int = int(tgt["ac"])
		if _dung_has_condition(tgt, "dodging"): eff_ac += 3
		if roll < eff_ac:
			# Sacred Fragmentation: spell misses still deal half damage
			var sf_t: int = _ent_feat_tier(caster, "Sacred Fragmentation")
			if sf_t >= 1 and die_count > 0 and die_sides > 0:
				var sf_dmg: int = maxi(1, _roll_dice(die_count, die_sides) / 2)
				_dung_reduce_hp(tgt, sf_dmg)
				var sf_dead: bool = int(tgt["hp"]) <= 0
				if sf_dead: tgt["is_dead"] = true; tgt["conditions"].clear()
				var sf_cond_note: String = ""
				if sf_t >= 3:
					# T3: also apply one minor condition
					var minor_conds: Array = ["slowed", "dazed", "weakened"]
					_dung_add_condition(tgt, minor_conds[randi() % minor_conds.size()])
					sf_cond_note = " and applies a condition"
				var sf_suffix: String = " [DEFEATED]" if sf_dead else ""
				return "%s casts %s at %s — MISS but Sacred Fragmentation deals %d!%s%s" % [
					caster["name"], spell_name, tgt["name"], sf_dmg, sf_cond_note, sf_suffix]
			# Mirrorsteel Glint: reflect spell back at caster
			if bool(tgt.get("mirrorsteel_active", false)):
				tgt["mirrorsteel_active"] = false
				if die_count > 0 and die_sides > 0:
					var reflect_dmg: int = _roll_dice(die_count, die_sides)
					_dung_reduce_hp(caster, reflect_dmg)
					return "%s casts %s at %s — REFLECTED by Mirrorsteel! %s takes %d damage!" % [
						caster["name"], spell_name, tgt["name"], caster["name"], reflect_dmg]
			return "%s casts %s at %s — MISS! (rolled %d vs %d)" % [
				caster["name"], spell_name, tgt["name"], roll, eff_ac]

	var parts: Array = []

	# Look up the spell record so we can respect damage-type → condition effects.
	var spell_rec: Dictionary = {}
	if _SPELL_DB.has(spell_name):
		spell_rec = _SPELL_DB[spell_name]
	var dmg_type: String = str(spell_rec.get("dt", ""))

	# ── Fix #2: Non-attack harmful spell gets a saving throw vs DC 10 + DIV ──
	# Applies ONLY to spells that are not a hit-style attack AND not a pure heal
	# (so curses, debuffs, and area harmful spells use saves instead of AC).
	var save_halved: bool = false
	var save_nullified: bool = false
	var is_harm_effect: bool = (die_count > 0 and die_sides > 0 and not is_heal) \
		or (not conds.is_empty() and not is_heal)
	if not needs_hit and is_harm_effect and not bool(tgt.get("is_dead", false)) \
			and tgt.get("is_player", false) != caster.get("is_player", true):
		var dc: int = _spell_save_dc(caster)
		# Condition-only spells: INT save; damage-heavy spells: VIT save
		var save_stat: int = 2 if die_count == 0 else 3
		if _spell_save_roll(tgt, dc, save_stat):
			if die_count > 0:
				save_halved = true
			if not conds.is_empty():
				save_nullified = true
			parts.append("SAVED vs DC%d" % dc)

	# Damage
	if (is_attack or is_harm_effect) and die_count > 0 and die_sides > 0 and not is_heal:
		var dmg: int = _roll_dice(die_count, die_sides)
		# Blood Magic T2+: add caster's Vitality score to spell damage
		var bm_vit_bonus: int = _blood_magic_vitality_bonus(caster)
		dmg += bm_vit_bonus
		if save_halved:
			dmg = maxi(1, dmg / 2)
		_dung_reduce_hp(tgt, dmg)
		if tgt["hp"] == 0:
			tgt["is_dead"] = true
			tgt["conditions"].clear()
		var t_handle: int = tgt.get("handle", -1)
		if t_handle >= 0 and _chars.has(t_handle): _chars[t_handle]["hp"] = tgt["hp"]
		var dead_sfx: String = " [DEFEATED]" if bool(tgt["is_dead"]) else ""
		var type_sfx: String = (" %s" % dmg_type) if dmg_type != "" else ""
		parts.append("dealt %d%s dmg%s" % [dmg, type_sfx, dead_sfx])
		# Blood Magic on-kill trigger (T4: regain SP, T5: heal + free spell)
		if bool(tgt.get("is_dead", false)):
			var bm_log: String = _blood_magic_on_kill(caster)
			if bm_log != "": parts.append(bm_log)
		# Apply matching condition per PHB damage-type table (only on living targets,
		# and only when the target did NOT save the full null condition).
		if not bool(tgt.get("is_dead", false)) and dmg_type != "" and not save_nullified:
			var auto_cond: String = _damage_type_condition(dmg_type)
			if auto_cond != "":
				# "pushed" = displace target 1 tile away from caster (PHB force push)
				if auto_cond == "pushed" and not bool(tgt.get("is_dead", false)):
					var push_dx: int = signi(int(tgt["x"]) - int(caster["x"]))
					var push_dy: int = signi(int(tgt["y"]) - int(caster["y"]))
					if push_dx == 0 and push_dy == 0: push_dx = 1  # default push right
					var nx: int = int(tgt["x"]) + push_dx
					var ny: int = int(tgt["y"]) + push_dy
					if nx >= 0 and ny >= 0 and nx < MAP_SIZE and ny < MAP_SIZE:
						if _dung_tile(nx, ny) == TILE_FLOOR and not _dung_occupied(nx, ny):
							tgt["x"] = nx; tgt["y"] = ny
					parts.append("pushed 5ft")
				else:
					_dung_add_condition(tgt, auto_cond)
					parts.append(auto_cond)

	# Healing
	if is_heal and die_count > 0 and die_sides > 0:
		var heal: int = _roll_dice(die_count, die_sides)
		# Healing & Restoration feat: add DIV/2 (T1), DIV (T3), 2×DIV (T5) to healing
		heal += _healing_restoration_bonus(caster)
		# Blood Magic T2+: add caster's Vitality score to healing spells
		heal += _blood_magic_vitality_bonus(caster)
		# Magic item heal bonus (Glowroot Bandage +2, etc.)
		var caster_h2: int = caster.get("handle", -1)
		heal += _magic_item_bonus(caster_h2, "heal_bonus")
		# PHB Necrotic Taint: healing hurts instead of helping
		if _dung_has_condition(tgt, "necrotic_taint"):
			_dung_reduce_hp(tgt, heal)
			var nh: int = tgt.get("handle", -1)
			if nh >= 0 and _chars.has(nh): _chars[nh]["hp"] = tgt["hp"]
			if int(tgt["hp"]) <= 0:
				tgt["is_dead"] = true; tgt["conditions"].clear()
			parts.append("NECROTIC TAINT — healing dealt %d damage!" % heal)
			heal = 0  # skip normal heal
		tgt["hp"] = mini(int(tgt["max_hp"]), int(tgt["hp"]) + heal)
		var heal_handle: int = tgt.get("handle", -1)
		if heal_handle >= 0 and _chars.has(heal_handle): _chars[heal_handle]["hp"] = tgt["hp"]
		# Special: Revivify revives dead targets
		if bool(tgt.get("is_dead", false)):
			tgt["is_dead"] = false
			tgt["hp"] = 1
			if heal_handle >= 0 and _chars.has(heal_handle): _chars[heal_handle]["hp"] = 1
			parts.append("REVIVED at 1 HP")
		else:
			parts.append("healed %d HP" % heal)

	# Conditions — blocked if a non-attack save nullified them
	for cond in conds:
		if save_nullified: break
		if not bool(tgt.get("is_dead", false)):
			_dung_add_condition(tgt, cond)
			parts.append(cond)

	var effect_str: String = (", ".join(parts)) if not parts.is_empty() else "no effect"
	# Register sustained spell as a matrix on the caster
	if dur > 0 and not bool(tgt.get("is_dead", false)) and not save_nullified:
		_dung_register_matrix(str(caster["id"]), spell_name, dur,
			str(tgt["id"]), is_attack, conds)
	return "%s casts %s on %s — %s%s." % [
		caster["name"], spell_name, tgt["name"], effect_str, dur_note]

## Roll Nd[S] and return the total.
## PHB Healing/Damage Scaling Table (p.174):
## Maps an SP value to [die_count, die_sides].
##   1→1d4, 2→1d6, 3→1d8, 4→1d10, 5→1d12,
##   6→2d4, 7→2d6, 8→2d8, 9→2d10, 10→2d12,
##   11→3d4, 12→3d6, 13→3d8, 14→3d10, 15→3d12,
##   16→4d4, 17→4d6, 18→4d8, 19→4d10, 20→4d12, ...
func _sp_to_dice(sp_val: int) -> Array:
	if sp_val <= 0: return [1, 4]
	const SIDES: Array = [4, 6, 8, 10, 12]
	var idx: int = (sp_val - 1) % 5        # which die size (0=d4 .. 4=d12)
	var count: int = ((sp_val - 1) / 5) + 1  # how many dice (1, 2, 3, ...)
	return [count, SIDES[idx]]

## Roll Nd[S] and return the total.
func _roll_dice(n: int, sides: int) -> int:
	var total: int = 0
	for i in range(n):
		total += randi_range(1, sides)
	return total

## PHB damage-type → auto-applied condition.
## Matches the Magical Damage table on PHB p.174:
##   Acid → AC-2 (tracked as "acid_corroded")
##   Bludgeoning → prone
##   Cold → halve movement ("slowed")
##   Fire → 1d4 burn per turn, stackable ("burning")
##   Force → push 5ft (tracked as "pushed")
##   Lightning → cannot take reactions ("no_reactions")
##   Necrotic → healing hurts ("necrotic_taint")
##   Piercing → 1d4 bleed, stackable ("bleeding")
##   Poison → disadvantage on checks ("poisoned")
##   Psychic → double AP costs ("confused")
##   Radiant → disadvantage on attack rolls ("radiant_dazzle")
##   Slashing → -1 to attack rolls, stackable ("slashed")
##   Thunder → deafened ("deafened")
func _damage_type_condition(dmg_type: String) -> String:
	match dmg_type.to_lower():
		"acid":        return "acid_corroded"
		"bludgeoning": return "prone"
		"cold":        return "slowed"
		"fire":        return "burning"
		"force":       return "pushed"
		"lightning":   return "no_reactions"
		"necrotic":    return "necrotic_taint"
		"piercing":    return "bleeding"
		"poison":      return "poisoned"
		"psychic":     return "confused"
		"radiant":     return "radiant_dazzle"
		"slashing":    return "slashed"
		"thunder":     return "deafened"
	return ""

# ── PHB magic helpers (Fix #2, #3, #4, #6, #7) ────────────────────────────────

## Fix #2: Spell save DC = 10 + Divinity modifier of caster.
## Defaults to 10 when caster is a creature (no handle / no stats).
func _spell_save_dc(caster: Dictionary) -> int:
	var ch: int = int(caster.get("handle", -1))
	if ch >= 0 and _chars.has(ch):
		var stats: Array = _chars[ch].get("stats", [1,1,1,1,1])
		var feats: Dictionary = _chars[ch].get("feats", {})
		var dc: int = 10 + int(stats[4])
		# Spell Shaper T1: DC = 10 + 2×DIV (overrides default)
		var ss_t: int = int(feats.get("Spell Shaper", 0))
		if ss_t >= 1: dc = 10 + int(stats[4]) * 2
		# Magic Expertise T2: +DIV to spell DC
		var me_t: int = int(feats.get("Magic Expertise", 0))
		if me_t >= 2: dc += int(stats[4])
		# Master of Ceremonies: +1 DC per tier
		var moc_t: int = int(feats.get("Master of Ceremonies", 0))
		if moc_t >= 1: dc += mini(moc_t, 3)
		# Illusion & Deception: +tier to DCs
		var id_t: int = int(feats.get("Illusion & Deception", 0))
		if id_t >= 1: dc += mini(id_t, 3)
		# Arcane Seal: +2 DC per tier for seal/ward spells
		var as_t: int = int(feats.get("Arcane Seal", 0))
		if as_t >= 1: dc += mini(as_t, 2)
		return dc
	return 10

## Fix #2: Target makes a saving throw (d20 + best relevant stat).
## Returns true on save.  target_uses defaults to Vitality (stat 3).
func _spell_save_roll(target: Dictionary, dc: int, stat_idx: int = 3) -> bool:
	var bonus: int = 0
	var ch: int = int(target.get("handle", -1))
	if ch >= 0 and _chars.has(ch):
		var c: Dictionary = _chars[ch]
		var stats: Array = c.get("stats", [1,1,1,1,1])
		var si: int = clampi(stat_idx, 0, 4)
		bonus = int(stats[si])
		var feats: Dictionary = c.get("feats", {})

		# ── Safeguard feat ──
		var sg_t: int = int(feats.get("Safeguard", 0))
		var sg_chosen: Array = c.get("safeguard_stats", [])
		# T5 applies to ALL stats; T1-T4 only to chosen stats
		var sg_applies: bool = (sg_t >= 5) or (sg_t >= 1 and si in sg_chosen)
		if sg_applies:
			if sg_t >= 1: bonus += int(stats[si])  # double stat score
			if sg_t >= 2: bonus += 2  # T2: flat +2

		# Mind Over Challenge T2/T3: multiply Intellect for checks
		var moc_t: int = int(feats.get("Mind Over Challenge", 0))
		if moc_t >= 3: bonus += int(stats[2]) * 2
		elif moc_t >= 2: bonus += int(stats[2])
	else:
		bonus = int(target.get("save_bonus", 2))

	var roll: int = randi_range(1, 20)

	# Safeguard T2: Once/SR advantage on saving throw with chosen stat
	if ch >= 0 and _chars.has(ch):
		var c2: Dictionary = _chars[ch]
		var sg_t2: int = int(c2.get("feats", {}).get("Safeguard", 0))
		var sg_chosen2: Array = c2.get("safeguard_stats", [])
		var sg_app2: bool = (sg_t2 >= 5) or (sg_t2 >= 2 and clampi(stat_idx, 0, 4) in sg_chosen2)
		if sg_app2 and sg_t2 >= 2:
			var adv_used: int = int(c2.get("_sg_adv_used", 0))
			if adv_used < 1:
				var roll2: int = randi_range(1, 20)
				if roll2 > roll: roll = roll2
				c2["_sg_adv_used"] = adv_used + 1

	var roll_result: int = roll + bonus

	# Safeguard T4: Once/LR auto-succeed on saving throw with chosen stat
	if ch >= 0 and _chars.has(ch) and roll_result < dc:
		var c3: Dictionary = _chars[ch]
		var sg_t3: int = int(c3.get("feats", {}).get("Safeguard", 0))
		var sg_chosen3: Array = c3.get("safeguard_stats", [])
		var sg_app3: bool = (sg_t3 >= 5) or (sg_t3 >= 4 and clampi(stat_idx, 0, 4) in sg_chosen3)
		if sg_app3 and sg_t3 >= 4:
			var used: int = int(c3.get("_sg_auto_used", 0))
			if used < 1:
				c3["_sg_auto_used"] = used + 1
				return true

	# Safeguard T1: Once/LR reroll a failed saving throw
	if ch >= 0 and _chars.has(ch) and roll_result < dc:
		var c4: Dictionary = _chars[ch]
		var sg_t4: int = int(c4.get("feats", {}).get("Safeguard", 0))
		if sg_t4 >= 1:
			var reroll_used: int = int(c4.get("_sg_reroll_used", 0))
			if reroll_used < 1:
				c4["_sg_reroll_used"] = reroll_used + 1
				var reroll: int = randi_range(1, 20) + bonus
				if reroll >= dc:
					roll_result = reroll  # take the reroll

	var success: bool = roll_result >= dc

	# Safeguard T3: On successful save, grant nearby allies +1d4 to next action
	if success and ch >= 0 and _chars.has(ch):
		var c5: Dictionary = _chars[ch]
		var sg_t5: int = int(c5.get("feats", {}).get("Safeguard", 0))
		if sg_t5 >= 3:
			# Apply safeguard_inspire to nearby party members in dungeon combat
			if _dungeon_entities.size() > 0:
				for ent in _dungeon_entities:
					if ent.get("is_dead", false): continue
					if int(ent.get("handle", -1)) == ch: continue
					if int(ent.get("handle", -1)) >= 0:  # ally (has handle = party member)
						if not ent.has("conditions"): ent["conditions"] = {}
						ent["conditions"]["safeguard_inspire"] = 1  # +1d4 next action

	# Safeguard T5: Once/SR on successful save, regain HP equal to Level
	if success and ch >= 0 and _chars.has(ch):
		var c6: Dictionary = _chars[ch]
		var sg_t6: int = int(c6.get("feats", {}).get("Safeguard", 0))
		if sg_t6 >= 5:
			var regen_used: int = int(c6.get("_sg_regen_used", 0))
			if regen_used < 1:
				c6["_sg_regen_used"] = regen_used + 1
				var lv: int = int(c6.get("level", 1))
				c6["hp"] = mini(int(c6.get("max_hp", 1)), int(c6.get("hp", 1)) + lv)

	return success

## Fix #3: Alignment/domain SP modifier.
## Domain affinity: caster.domain matches spell.dom → -1 SP.
## Alignment affinity: certain alignments favor certain domains.
##   Unity    favors Biological                (-1) / disfavors Physical  (+1)
##   Chaos    favors Chemical, Physical        (-1) / disfavors Spiritual (+1)
##   Void     favors Spiritual                 (-1) / disfavors Biological(+1)
## Returns a signed integer delta applied to the SP cost (never below 0 total).
func _alignment_sp_modifier(caster: Dictionary, spell_dom: String) -> int:
	var delta: int = 0
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return 0
	var cdata: Dictionary = _chars[ch]
	var c_dom: String = str(cdata.get("domain", ""))
	var c_align: String = str(cdata.get("alignment", "Unity"))
	if c_dom == spell_dom:
		delta -= 1
	match c_align:
		"Unity":
			if spell_dom == "Biological": delta -= 1
			elif spell_dom == "Physical": delta += 1
		"Chaos":
			if spell_dom == "Chemical" or spell_dom == "Physical": delta -= 1
			elif spell_dom == "Spiritual": delta += 1
		"Void":
			if spell_dom == "Spiritual": delta -= 1
			elif spell_dom == "Biological": delta += 1
	return delta

## Fix #7: Regional SP modifier — tied to the current dungeon terrain style.
## Returns a flat integer added to every spell's SP cost this session.
##   Arcane / Crystal / Planar regions → -1 SP (abundant ambient magic)
##   Ash / Volcanic / Corrupted regions → +1 SP (magic is choked)
func _regional_sp_modifier() -> int:
	var style: int = int(_dungeon_terrain_style)
	# 0=open,1=plains,2=forest,3=urban,4=volcanic,5=coastal,6=arcane,7=shadow
	match style:
		6: return -1   # Arcane nexus / crystal cavern
		2: return 0
		5: return 0
		4: return 1    # Ash / volcanic — draining
		7: return 1    # Shadow realm — unstable
	return 0

## Fix #7: Feat-based SP modifier.
## Matches the PHB domain-mastery feats (one per domain) and the Spell Shaper
## magic feat, using the exact names stored in _FEAT_REGISTRY. Each domain
## feat reduces SP cost for spells in that domain based on its unlocked tier
## (Tier 1 → −1, Tier 2 → −2, Tier 3 → −3 effectively zero penalty).
func _feat_sp_modifier(caster: Dictionary, spell_dom: String) -> int:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return 0
	var feats: Dictionary = _chars[ch].get("feats", {})
	var delta: int = 0
	# Domain-mastery feats: map of domain name → feat name
	var dom_feat_map: Dictionary = {
		"Biological": "Rooted Initiate",
		"Chemical":   "Alchemical Adept",
		"Physical":   "Ember Manipulator",
		"Spiritual":  "Whispering Mind",
	}
	var dom_feat: String = str(dom_feat_map.get(spell_dom, ""))
	if dom_feat != "" and feats.has(dom_feat):
		# Higher tiers grant progressively larger discounts (−1 per tier, capped at −3).
		var tier: int = int(feats.get(dom_feat, 0)) if feats.get(dom_feat) is int \
			else (1 if feats[dom_feat] else 0)
		delta -= clampi(tier, 0, 3)
	# Backward compat: old saves may store under "<Domain> Domain" name
	var old_name: String = spell_dom + " Domain"
	if dom_feat != "" and not feats.has(dom_feat) and feats.has(old_name):
		var tier2: int = int(feats.get(old_name, 0)) if feats.get(old_name) is int \
			else (1 if feats[old_name] else 0)
		delta -= clampi(tier2, 0, 3)
	# Spell Shaper (magic feat): −1 per tier (capped at −2). Registry name has a space.
	if feats.has("Spell Shaper"):
		var t2: int = int(feats.get("Spell Shaper", 0)) if feats.get("Spell Shaper") is int \
			else (1 if feats["Spell Shaper"] else 0)
		delta -= clampi(t2, 0, 2)
	# Blood Magic (magic feat) Tier 4: spend HP to reduce spell SP cost
	# (tier1 already grants 2HP→1SP via active ability, handled elsewhere; this
	# is the passive discount when the feat is unlocked at tier 4+).
	if feats.has("Blood Magic"):
		var t3: int = int(feats.get("Blood Magic", 0)) if feats.get("Blood Magic") is int \
			else (1 if feats["Blood Magic"] else 0)
		if t3 >= 4:
			delta -= 1
	return delta

## Fix #4: PHB Overreach tables — one d10 table per magic domain.
## Triggered when caster casts a spell whose final SP cost exceeds current SP.
const _OVERREACH_BIOLOGICAL: Array = [
	"Veins burn — take 1d6 necrotic damage.",
	"Flesh warps — gain 1 Exhaustion until long rest.",
	"Muscle spasm — Slowed for 1 round.",
	"Blood boils — Bleeding for 3 rounds.",
	"Nausea — one action lost next turn.",
	"Rapid aging — temporary -1 to VIT until long rest.",
	"Cellular strain — halve your next healing.",
	"Weakened pulse — disadvantage on next save.",
	"Heart stutter — drop to 1 HP instantly.",
	"Body rebellion — gain Poisoned and Fever until long rest.",
]
const _OVERREACH_CHEMICAL: Array = [
	"Backfire — take 1d6 fire damage.",
	"Acrid cloud — adjacent allies take 1d4 acid damage.",
	"Chem burn — Vulnerable for 1 round.",
	"Foaming lungs — Silent for 3 rounds.",
	"Fumes — Blinded until end of next turn.",
	"Caustic residue — gain Poisoned until short rest.",
	"Reactive tide — all your spells +1 SP next scene.",
	"Flash ignition — take 2d6 fire damage.",
	"Detonation — 3d6 force damage in a 10-ft burst centered on you.",
	"Alchemical collapse — lose all remaining SP.",
]
const _OVERREACH_PHYSICAL: Array = [
	"Kinetic feedback — knocked Prone.",
	"Inertia snap — thrown 10 ft and take 1d6 bludgeoning damage.",
	"Gravity lurch — Speed 0 for 1 round.",
	"Force echo — 1d8 force damage.",
	"Matrix tear — all your sustained spells end.",
	"Thunderclap — Deafened until short rest.",
	"Mana static — next spell auto-fails.",
	"Momentum spike — 2d6 bludgeoning and restrained 1 round.",
	"Implosion — 3d6 force and Dazed for 2 rounds.",
	"Total dispersion — fall Unconscious 1 minute.",
]
const _OVERREACH_SPIRITUAL: Array = [
	"Soul scour — 1d4 psychic damage.",
	"Mind echo — Confused for 1 round.",
	"Astral vertigo — Disadvantage on all checks until short rest.",
	"Ego bleed — gain 1 Exhaustion.",
	"Bad omen — next save auto-fails.",
	"Ghost touch — Frightened until short rest.",
	"Void whisper — gain a hostile watcher (narrative flag).",
	"Self doubt — halve your next spell's effect.",
	"Astral riptide — Unconscious 1 round, take 2d6 psychic damage.",
	"Divinity backlash — lose a level of DIV temporarily until long rest.",
]

## Fix #4: Roll on the domain-specific overreach table and apply the effect.
## Returns the log string of what happened.  `cost_over` is the deficit SP.
func _trigger_overreach(caster: Dictionary, spell_dom: String, cost_over: int) -> String:
	var roll: int = randi_range(1, 10)
	var idx: int = clampi(roll - 1, 0, 9)
	var table: Array = _OVERREACH_BIOLOGICAL
	match spell_dom:
		"Chemical":  table = _OVERREACH_CHEMICAL
		"Physical":  table = _OVERREACH_PHYSICAL
		"Spiritual": table = _OVERREACH_SPIRITUAL
	var outcome: String = str(table[idx])
	# Apply mechanical portion of each outcome.
	var dmg: int = 0
	var low: String = outcome.to_lower()
	if "1d6" in low: dmg += _roll_dice(1, 6)
	elif "2d6" in low: dmg += _roll_dice(2, 6)
	elif "3d6" in low: dmg += _roll_dice(3, 6)
	elif "1d4" in low: dmg += _roll_dice(1, 4)
	elif "1d8" in low: dmg += _roll_dice(1, 8)
	if dmg > 0:
		_dung_reduce_hp(caster, dmg)
		var h: int = int(caster.get("handle", -1))
		if h >= 0 and _chars.has(h): _chars[h]["hp"] = caster["hp"]
	# Apply condition triggers per keyword
	if "slowed" in low:      _dung_add_condition(caster, "slowed")
	if "bleeding" in low:    _dung_add_condition(caster, "bleeding")
	if "blinded" in low:     _dung_add_condition(caster, "blinded")
	if "poisoned" in low:    _dung_add_condition(caster, "poisoned")
	if "vulnerable" in low:  _dung_add_condition(caster, "vulnerable")
	if "prone" in low:       _dung_add_condition(caster, "prone")
	if "silent" in low:      _dung_add_condition(caster, "silent")
	if "deafened" in low:    _dung_add_condition(caster, "deafened")
	if "confused" in low:    _dung_add_condition(caster, "confused")
	if "frightened" in low:  _dung_add_condition(caster, "frightened")
	if "restrained" in low:  _dung_add_condition(caster, "restrained")
	if "dazed" in low:       _dung_add_condition(caster, "dazed")
	if "exhausted" in low:   _dung_add_condition(caster, "exhausted")
	if "unconscious" in low: _dung_add_condition(caster, "unconscious")
	if "fever" in low:       _dung_add_condition(caster, "fever")
	if "all your sustained spells end" in low:
		var caster_id: String = str(caster.get("id", ""))
		if _dungeon_matrices.has(caster_id):
			_dungeon_matrices.erase(caster_id)
	if "lose all remaining sp" in low:
		caster["sp"] = 0
		var h2: int = int(caster.get("handle", -1))
		if h2 >= 0 and _chars.has(h2): _chars[h2]["sp"] = 0
	return "OVERREACH (%s d10=%d, deficit %d SP): %s" % [spell_dom, roll, cost_over, outcome]

## Fix #6: Check suppression of all sustained matrices for `ent`.
## If the caster is Incapacitated / Stunned / Unconscious, matrices freeze
## (suppressed=true) and their conditions are pulled from their focus target.
## On recovery, matrices resume and re-apply their conditions.
func _matrix_update_suppression(ent: Dictionary) -> void:
	var eid: String = str(ent.get("id", ""))
	if not _dungeon_matrices.has(eid): return
	var incap: bool = _dung_has_condition(ent, "incapacitated") \
		or _dung_has_condition(ent, "stunned") \
		or _dung_has_condition(ent, "unconscious") \
		or _dung_has_condition(ent, "paralyzed") \
		or bool(ent.get("is_dead", false))
	for mtx in _dungeon_matrices[eid]:
		var was_suppressed: bool = bool(mtx.get("suppressed", false))
		mtx["suppressed"] = incap
		var focus = _dung_find(str(mtx.get("focus_id", "")))
		if focus == null: continue
		if incap and not was_suppressed:
			for cond in mtx.get("conds", []):
				_dung_remove_condition(focus, str(cond))
		elif not incap and was_suppressed:
			for cond in mtx.get("conds", []):
				_dung_add_condition(focus, str(cond))

## Fix #7: Ritual-cast helper — `is_ritual=true` zeroes SP cost (takes time instead).
## Intended to be called by cast paths that flag the cast as ritual.
func _ritual_adjusted_cost(base_cost: int, is_ritual: bool) -> int:
	return 0 if is_ritual else base_cost

# ── Phase 1 helpers: Healing & Restoration feat, Blood Magic vitality ─────────

## PHB Healing & Restoration feat: adds DIV/2 (T1), DIV (T3), 2×DIV (T5) to healing rolls.
func _healing_restoration_bonus(caster: Dictionary) -> int:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return 0
	var feats: Dictionary = _chars[ch].get("feats", {})
	if not feats.has("Healing & Restoration"): return 0
	var tier: int = int(feats["Healing & Restoration"])
	var div_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[4])
	if tier >= 5: return div_score * 2
	if tier >= 3: return div_score
	if tier >= 1: return maxi(1, div_score / 2)
	return 0

## PHB Blood Magic T2+: add caster's Vitality stat score to spell damage and healing.
func _blood_magic_vitality_bonus(caster: Dictionary) -> int:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return 0
	var feats: Dictionary = _chars[ch].get("feats", {})
	if not feats.has("Blood Magic"): return 0
	var tier: int = int(feats["Blood Magic"])
	if tier < 2: return 0
	var vit_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[3])
	return vit_score

## PHB Blood Magic T4: regain DIV SP on kill (1/long rest). Tracked via "blood_magic_kill_used".
func _blood_magic_on_kill(caster: Dictionary) -> String:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return ""
	var feats: Dictionary = _chars[ch].get("feats", {})
	if not feats.has("Blood Magic"): return ""
	var tier: int = int(feats["Blood Magic"])
	var div_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[4])
	var log_parts: Array = []
	# T4: regain DIV SP on kill (1/LR)
	if tier >= 4 and not bool(caster.get("blood_magic_kill_used", false)):
		var sp_gain: int = div_score
		caster["sp"] = mini(int(caster.get("max_sp", 99)), int(caster["sp"]) + sp_gain)
		if ch >= 0 and _chars.has(ch): _chars[ch]["sp"] = caster["sp"]
		caster["blood_magic_kill_used"] = true
		log_parts.append("Blood Magic: regained %d SP from kill" % sp_gain)
	# T5: regain 2×DIV HP + free spell on kill
	if tier >= 5:
		var hp_gain: int = div_score * 2
		caster["hp"] = mini(int(caster["max_hp"]), int(caster["hp"]) + hp_gain)
		if ch >= 0 and _chars.has(ch): _chars[ch]["hp"] = caster["hp"]
		caster["blood_magic_free_spell"] = true
		log_parts.append("Blood Magic: healed %d HP, free spell available" % hp_gain)
	if log_parts.is_empty(): return ""
	return " | ".join(log_parts)

## PHB Verdant Channeler / Biological Domain T2: +SP_spent to next attack roll.
## Called after casting a Biological domain spell; stores the bonus on the caster entity.
func _verdant_channeler_check(caster: Dictionary, spell_dom: String, sp_spent: int) -> void:
	if spell_dom != "Biological": return
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return
	var feats: Dictionary = _chars[ch].get("feats", {})
	# Check both "Rooted Initiate" (old name) and "Biological Domain" (C++ parity name)
	var bio_tier: int = 0
	if feats.has("Rooted Initiate"):
		bio_tier = maxi(bio_tier, int(feats["Rooted Initiate"]))
	if feats.has("Biological Domain"):
		bio_tier = maxi(bio_tier, int(feats["Biological Domain"]))
	if bio_tier >= 2:
		caster["hit_bonus_buff"] = int(caster.get("hit_bonus_buff", 0)) + sp_spent

# ── Phase 3: Arcane Wellspring feat effects ───────────────────────────────────

## PHB Arcane Wellspring:
##   T1: Deep Reserves — 1/LR reduce a spell's SP cost by DIV (tracked via "aw_deep_used")
##   T3: Spell Echo — after spending SP, repeat spell effect at start of next turn (1/encounter)
##       (tracked via "spell_echo_spell" on entity, consumed on next turn)
##   T5: Infinite Font — 1/LR cast a 2nd spell of equal or lower cost for free
##       (tracked via "aw_font_used", sets "aw_free_cast_budget")
func _arcane_wellspring_sp_modify(caster: Dictionary, sp_cost: int) -> int:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return sp_cost
	var feats: Dictionary = _chars[ch].get("feats", {})
	if not feats.has("Arcane Wellspring"): return sp_cost
	var tier: int = int(feats["Arcane Wellspring"])
	var div_score: int = int(_chars[ch].get("stats", [1,1,1,1,1])[4])
	# T5: Infinite Font — free cast if budget is set from previous spell
	if tier >= 5 and int(caster.get("aw_free_cast_budget", 0)) >= sp_cost:
		caster["aw_free_cast_budget"] = 0
		return 0
	# T1: Deep Reserves — 1/LR reduce SP cost by DIV
	if tier >= 1 and not bool(caster.get("aw_deep_used", false)):
		caster["aw_deep_used"] = true
		sp_cost = maxi(0, sp_cost - div_score)
	# T5: After paying, set the free budget for next spell this LR
	if tier >= 5 and not bool(caster.get("aw_font_used", false)):
		caster["aw_font_used"] = true
		caster["aw_free_cast_budget"] = sp_cost  # next spell of equal or lower cost is free
	# T3: Spell Echo — mark for echo on next turn (1/encounter)
	if tier >= 3 and not bool(caster.get("spell_echo_used", false)):
		caster["spell_echo_used"] = true
		caster["spell_echo_pending"] = true  # consumed by turn-start handler
	return sp_cost

## Phase 3: Process Spell Echo at the start of caster's turn.
## If spell_echo_pending is set, the last spell repeats for free.
func _process_spell_echo(ent: Dictionary) -> String:
	if not bool(ent.get("spell_echo_pending", false)): return ""
	ent["spell_echo_pending"] = false
	_ensure_spell_db()
	var echo_spell: String = str(ent.get("last_spell_cast", ""))
	var echo_target: String = str(ent.get("last_spell_target", ""))
	if echo_spell == "" or not _SPELL_DB.has(echo_spell): return ""
	var s: Dictionary = _SPELL_DB[echo_spell]
	var tgt = _dung_find(echo_target)
	if tgt == null or bool(tgt.get("is_dead", false)):
		return "Spell Echo: %s fizzles (no valid target)." % echo_spell
	var result: String = _spell_apply_to_target(ent, tgt, echo_spell,
		bool(s["atk"]), bool(s["heal"]),
		int(s["dc"]), int(s["ds"]),
		s.get("conds", []), 0, bool(s["atk"]))
	return "SPELL ECHO: " + result

# ── Phase 4: Domain expertise SP reduction ────────────────────────────────────

## PHB domain expertise: characters with deep domain knowledge get SP discounts.
## Scales with the number of domain-specific skill points invested.
## Arcane skill (idx 0): every 2 points → -1 SP for that domain, max -6.
func _domain_expertise_sp_modify(caster: Dictionary, spell_dom: String, sp_cost: int) -> int:
	var ch: int = int(caster.get("handle", -1))
	if ch < 0 or not _chars.has(ch): return sp_cost
	var skills: Array = _chars[ch].get("skills", [0,0,0,0,0,0,0,0,0,0,0,0,0,0])
	var arcane_score: int = int(skills[0]) if skills.size() > 0 else 0
	# Expertise discount: 1 SP per 2 Arcane skill points, max -6
	var expertise_discount: int = mini(6, arcane_score / 2)
	return maxi(0, sp_cost - expertise_discount)

## Internal attack resolution used by both player and enemy attacks.
func _dung_do_attack(atk: Dictionary, tgt: Dictionary, weapon: String, is_unarmed: bool, cover_bonus: int = 0) -> Dictionary:
	# ── Condition modifiers ───────────────────────────────────────────────────────
	# Blinded attacker: roll twice, take lower
	var advantage_atk: bool  = false
	var disadvantage_atk: bool = _dung_has_condition(atk, "blinded")

	# Prone target: ranged attackers have disadvantage, melee have advantage
	var is_ranged_atk: bool = _weapon_is_ranged(weapon)
	if _dung_has_condition(tgt, "prone"):
		if is_ranged_atk: disadvantage_atk = true
		else:             advantage_atk    = true

	# Paralyzed / stunned target: attacks against have advantage
	if _dung_has_condition(tgt, "paralyzed") or _dung_has_condition(tgt, "stunned"):
		advantage_atk = true

	# Restrained target: attacks against have advantage
	if _dung_has_condition(tgt, "restrained"):
		advantage_atk = true

	# Hidden attacker: advantage on attack (then hidden is revealed)
	if _dung_has_condition(atk, "hidden"):
		advantage_atk = true
		atk["conditions"].erase("hidden")

	# PHB attack rolls: STR weapons = STR+Exertion; SPD/finesse/ranged = SPD+Nimble
	# Stat order: STR=0, SPD=1, INT=2, VIT=3, DIV=4
	# Skill order: Arcane=0,Crafting=1,Creature Handling=2,Cunning=3,Exertion=4,
	#              Intuition=5,Learnedness=6,Medical=7,Nimble=8,Perception=9,...
	var hit_bonus: int = 2  # fallback for creatures without character sheets
	var atk_handle: int = int(atk.get("handle", -1))
	if atk_handle >= 0 and _chars.has(atk_handle):
		var ca: Dictionary = _chars[atk_handle]
		var ch_stats: Array = ca.get("stats", [1,1,1,1,1])
		var ch_skills: Array = ca.get("skills", [0,0,0,0,0,0,0,0,0,0,0,0,0,0])
		var w_low: String = weapon.to_lower()
		# Speed/finesse weapons or ranged: SPD + Nimble
		var is_speed_wpn: bool = ("dagger" in w_low or "rapier" in w_low or
			"shortsword" in w_low or "scimitar" in w_low or "katana" in w_low or
			"whip" in w_low or "dart" in w_low or "sling" in w_low or
			"blowgun" in w_low or _weapon_is_ranged(weapon) or is_unarmed)
		if is_speed_wpn:
			hit_bonus = int(ch_stats[1]) + int(ch_skills[8])  # SPD + Nimble
		else:
			hit_bonus = int(ch_stats[0]) + int(ch_skills[4])  # STR + Exertion
	# Trait/buff bonus from active abilities (e.g. Arcane Surge, Cursed Spark)
	hit_bonus += int(atk.get("hit_bonus_buff", 0))
	# Penalty from injuries (e.g. Broken Arm)
	hit_bonus -= int(atk.get("hit_penalty", 0))
	var atk_z: int = int(atk.get("z", 1))
	var tgt_z: int = int(tgt.get("z", 1))
	if atk_z > tgt_z: hit_bonus += 1
	elif atk_z < tgt_z: hit_bonus -= 1

	# ── Feat attack bonuses ──────────────────────────────────────────────────────
	var atk_h: int = int(atk.get("handle", -1))
	var atk_feats: Dictionary = {}
	var atk_stats: Array = [1,1,1,1,1]
	var atk_skills: Array = [0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	if atk_h >= 0 and _chars.has(atk_h):
		atk_feats = _chars[atk_h].get("feats", {})
		atk_stats = _chars[atk_h].get("stats", [1,1,1,1,1])
		atk_skills = _chars[atk_h].get("skills", [0,0,0,0,0,0,0,0,0,0,0,0,0,0])

	# Martial Prowess T1: double STR for attack bonus (limited uses/SR)
	var mp_t: int = int(atk_feats.get("Martial Prowess", 0))
	if mp_t >= 1 and not is_ranged_atk:
		hit_bonus += int(atk_stats[0])  # add STR again
	# Martial Prowess T3: +1d4 vs single opponent
	if mp_t >= 3:
		hit_bonus += randi_range(1, 4)

	# Precise Tactician: feat-based crit expansion (checked after roll)
	var pt_t: int = int(atk_feats.get("Precise Tactician", 0))
	# T1: 1/enc reroll; we apply as +1 hit bonus passive
	if pt_t >= 1:
		hit_bonus += 1

	# Weapon Mastery: +1 hit per tier
	var wm_t: int = int(atk_feats.get("Weapon Mastery", 0))
	if wm_t >= 1:
		hit_bonus += mini(wm_t, 3)

	# Linebreaker's Aim: +1 hit per tier with ranged weapons
	var la_t: int = int(atk_feats.get("Linebreaker's Aim", 0))
	if la_t >= 1 and is_ranged_atk:
		hit_bonus += mini(la_t, 3)

	# Iron Fist: unarmed attack bonus (+1 per tier)
	var if_t: int = int(atk_feats.get("Iron Fist", 0))
	if if_t >= 1 and is_unarmed:
		hit_bonus += mini(if_t, 3)

	# Magic Expertise T2: double Divinity on magic attack rolls (not melee, checked elsewhere)
	# Blood Magic T2: add Vitality to spell/attack rolls
	var bm_t: int = int(atk_feats.get("Blood Magic", 0))
	if bm_t >= 2:
		hit_bonus += int(atk_stats[3])  # VIT

	# Duelist's Path: +2 hit when fighting a single target within 5ft
	var dp_t: int = int(atk_feats.get("Duelist's Path", 0))
	if dp_t >= 1 and not is_ranged_atk:
		hit_bonus += mini(dp_t + 1, 3)

	# Magic item hit bonus (Dagger of the Last Word +1, etc.)
	hit_bonus += _magic_item_bonus(atk_h, "hit_bonus")

	# Dagger of the Last Word: auto-hit targets below 5 HP
	if _magic_item_has_flag(atk_h, "auto_hit_below_5") and int(tgt["hp"]) < 5 and int(tgt["hp"]) > 0:
		hit_bonus += 20  # guaranteed hit

	# Weapon poison from consumable (Basic Poison vial)
	var wp_charges: int = int(atk.get("weapon_poison_charges", 0))

	# Poisoned attacker: disadvantage
	if _dung_has_condition(atk, "poisoned"):
		disadvantage_atk = true

	# Safeguard T3 inspiration: +1d4 to next action, then consumed
	if _dung_has_condition(atk, "safeguard_inspire"):
		hit_bonus += randi_range(1, 4)
		atk["conditions"].erase("safeguard_inspire")

	var d20_raw: int = randi_range(1, 20)
	var d20_raw2: int = randi_range(1, 20)
	var raw_roll: int
	if advantage_atk and not disadvantage_atk:
		raw_roll = maxi(d20_raw, d20_raw2)
	elif disadvantage_atk and not advantage_atk:
		raw_roll = mini(d20_raw, d20_raw2)
	else:
		raw_roll = d20_raw
	var roll: int = raw_roll + hit_bonus

	# ── Crit detection (Precise Tactician expands crit range) ────────────────────
	var crit_threshold: int = 20
	if pt_t >= 5: crit_threshold = 15
	elif pt_t >= 4: crit_threshold = 16
	elif pt_t >= 3: crit_threshold = 17
	elif pt_t >= 2: crit_threshold = 18
	elif pt_t >= 1: crit_threshold = 19
	var is_crit: bool = (raw_roll >= crit_threshold)

	# ── Target AC — dodging, conditions, cover, feat defenses ────────────────────
	var tgt_h: int = int(tgt.get("handle", -1))
	var tgt_feats: Dictionary = {}
	var tgt_stats: Array = [1,1,1,1,1]
	if tgt_h >= 0 and _chars.has(tgt_h):
		tgt_feats = _chars[tgt_h].get("feats", {})
		tgt_stats = _chars[tgt_h].get("stats", [1,1,1,1,1])

	var effective_ac: int = tgt["ac"]
	if _dung_has_condition(tgt, "dodging"):  effective_ac += 3
	if _dung_has_condition(tgt, "shielded"): effective_ac += 2
	if _dung_has_condition(tgt, "slowed"):   effective_ac -= 2
	effective_ac += cover_bonus

	# Deflective Stance: T1 +1 AC when dodging (stacking with dodge)
	var ds_t: int = int(tgt_feats.get("Deflective Stance", 0))
	if ds_t >= 1 and _dung_has_condition(tgt, "dodging"):
		effective_ac += mini(ds_t, 4)

	# Unyielding Defender T2: +2 AC when below 1/3 HP
	var ud_t: int = int(tgt_feats.get("Unyielding Defender", 0))
	if ud_t >= 2:
		var hp_frac: float = float(int(tgt["hp"])) / float(maxi(1, int(tgt["max_hp"])))
		if hp_frac <= 0.34:
			effective_ac += 2

	# Wall of the Battered: T1 +1 AC when adjacent to ally with same feat (simplified: flat +1)
	var wob_t: int = int(tgt_feats.get("Wall of the Battered", 0))
	if wob_t >= 1:
		effective_ac += mini(wob_t, 3)

	# Warp (attacker feat): reduce target AC
	var warp_t: int = int(atk_feats.get("Warp", 0))
	if warp_t >= 2:
		var ac_reduce: int = 1 if warp_t < 4 else 2
		effective_ac -= ac_reduce

	var elev_note: String = ""
	if atk_z > tgt_z: elev_note = " (high ground)"
	elif atk_z < tgt_z: elev_note = " (uphill)"

	# ── Illusory Double: 50% chance attack hits illusion instead ─────────────────
	if bool(tgt.get("illusory_double_active", false)):
		if randi() % 6 < 3:  # d6 ≤ 3 = hits illusion
			var illusion_hp: int = int(tgt.get("illusory_double_hp", 3)) - 1
			if illusion_hp <= 0:
				tgt["illusory_double_active"] = false
				tgt.erase("illusory_double_hp")
			else:
				tgt["illusory_double_hp"] = illusion_hp
			return {"hit": false, "damage": 0,
				"log": "%s attacks %s — hits the illusory double instead!%s" % [
					atk["name"], tgt["name"], elev_note],
				"target_dead": false, "target_id": tgt["id"]}

	# ── Refraction Twist: 1/SR impose disadvantage (half damage if still hits) ──
	if bool(tgt.get("refraction_twist_ready", false)):
		var rt_second_roll: int = randi_range(1, 20)
		if rt_second_roll < roll:
			roll = rt_second_roll  # disadvantage
			tgt["refraction_twist_ready"] = false
			tgt["refraction_half_dmg"] = true  # halve damage if hit still lands

	# ── Hollowed Instinct: negate advantage from unseen attackers ────────────────
	if _ent_feat_tier(tgt, "Hollowed Instinct") >= 1 and bool(atk.get("attacking_from_stealth", false)):
		atk["attacking_from_stealth"] = false  # remove stealth advantage

	# ── Miss handling ────────────────────────────────────────────────────────────
	if roll < effective_ac and not is_crit:
		# Martial Prowess T3: miss = deal STR damage (glancing blow)
		var glance_dmg: int = 0
		if mp_t >= 3 and not is_ranged_atk:
			glance_dmg = int(atk_stats[0])
			if glance_dmg > 0:
				var glance_ss: String = _dung_reduce_hp(tgt, glance_dmg)
				if tgt_h >= 0 and _chars.has(tgt_h): _chars[tgt_h]["hp"] = tgt["hp"]
				if int(tgt["hp"]) <= 0:
					tgt["is_dead"] = true; tgt["conditions"].clear()
					return {"hit": false, "damage": glance_dmg,
						"log": "%s attacks %s — MISS but glancing blow for %d! [DEFEATED]%s" % [
							atk["name"], tgt["name"], glance_dmg, elev_note],
						"target_dead": true, "target_id": tgt["id"]}
				var glance_ss_note: String = (" " + glance_ss) if glance_ss != "" else ""
				return {"hit": false, "damage": glance_dmg,
					"log": "%s attacks %s — MISS but glancing blow for %d!%s%s" % [
						atk["name"], tgt["name"], glance_dmg, elev_note, glance_ss_note],
					"target_dead": false, "target_id": tgt["id"]}

		# Deflective Stance T2: counter on miss (1/round)
		if ds_t >= 2 and not is_ranged_atk and _ent_use_feat_charge(tgt, "_ds_counter_used", 1):
			var counter_dmg: int = randi_range(1, 6) + int(tgt_stats[1])
			_dung_reduce_hp(atk, counter_dmg)
			if atk_h >= 0 and _chars.has(atk_h): _chars[atk_h]["hp"] = atk["hp"]
			return {"hit": false, "damage": 0,
				"log": "%s attacks %s — MISS! %s counters for %d!%s" % [
					atk["name"], tgt["name"], tgt["name"], counter_dmg, elev_note],
				"target_dead": false, "target_id": tgt["id"]}

		return {"hit": false, "damage": 0,
			"log": "%s attacks %s — MISS! (rolled %d vs AC %d)%s" % [
				atk["name"], tgt["name"], roll, effective_ac, elev_note],
			"target_dead": false, "target_id": tgt["id"]}

	# ── Damage ────────────────────────────────────────────────────────────────────
	var dmg: int
	if is_unarmed:
		# Iron Fist: T1 1d6, T2 1d8, T3 1d10
		if if_t >= 3: dmg = randi_range(1, 10) + int(atk_stats[0])
		elif if_t >= 2: dmg = randi_range(1, 8) + int(atk_stats[0])
		elif if_t >= 1: dmg = randi_range(1, 6) + int(atk_stats[0])
		else: dmg = randi_range(1, 4) + 1
	elif weapon == "" or weapon == "None":
		dmg = randi_range(1, 6) + 1
	else:
		dmg = _weapon_damage(weapon)

	# Weapon Mastery: +1 damage per tier
	if wm_t >= 1:
		dmg += mini(wm_t, 3)

	# Titanic Damage: +1d4/+1d6/+1d8 per tier
	var td_t: int = int(atk_feats.get("Titanic Damage", 0))
	if td_t >= 3: dmg += randi_range(1, 8)
	elif td_t >= 2: dmg += randi_range(1, 6)
	elif td_t >= 1: dmg += randi_range(1, 4)

	# Crimson Edge: slashing bonus damage (T2 +1d6, T3 +1d8, T5 +1d10)
	var ce_t: int = int(atk_feats.get("Crimson Edge", 0))
	if ce_t >= 5: dmg += randi_range(1, 10)
	elif ce_t >= 3: dmg += randi_range(1, 8)
	elif ce_t >= 2: dmg += randi_range(1, 6)

	# Iron Hammer: bludgeoning bonus damage
	var ih_t: int = int(atk_feats.get("Iron Hammer", 0))
	if ih_t >= 5: dmg += randi_range(1, 10)
	elif ih_t >= 3: dmg += randi_range(1, 8)
	elif ih_t >= 2: dmg += randi_range(1, 6)

	# Iron Thorn: piercing bonus damage
	var it_t: int = int(atk_feats.get("Iron Thorn", 0))
	if it_t >= 5: dmg += randi_range(1, 10)
	elif it_t >= 3: dmg += randi_range(1, 8)
	elif it_t >= 2: dmg += randi_range(1, 6)

	# Grasp of the Titan: +STR to damage
	var gt_t: int = int(atk_feats.get("Grasp of the Titan", 0))
	if gt_t >= 1 and not is_ranged_atk:
		dmg += int(atk_stats[0]) * mini(gt_t, 3)

	# Swift Striker: +SPD to damage
	var ss_t: int = int(atk_feats.get("Swift Striker", 0))
	if ss_t >= 1:
		dmg += int(atk_stats[1]) * mini(ss_t, 2)

	# Fury's Call: +1 damage per missing 10% HP
	var fc_t: int = int(atk_feats.get("Fury's Call", 0))
	if fc_t >= 1:
		var missing_pct: int = int((1.0 - float(int(atk["hp"])) / float(maxi(1, int(atk["max_hp"])))) * 10)
		dmg += missing_pct * mini(fc_t, 3)

	# Twin Fang: T1 +1d4, T3 +1d6, T5 attack twice (simplified as +50% dmg)
	var tf_t: int = int(atk_feats.get("Twin Fang", 0))
	if tf_t >= 5: dmg = int(dmg * 1.5)
	elif tf_t >= 3: dmg += randi_range(1, 6)
	elif tf_t >= 1: dmg += randi_range(1, 4)

	# Improvised Weapon Mastery: +1d4 per tier (max 3)
	var iwm_t: int = int(atk_feats.get("Improvised Weapon Mastery", 0))
	if iwm_t >= 1:
		for _i in range(mini(iwm_t, 3)):
			dmg += randi_range(1, 4)

	# ── Planar Graze: +1d8 force damage on hit (1/SR) ──────────────────────────
	if _ent_feat_tier(atk, "Planar Graze") >= 1 and _ent_use_feat_charge(atk, "_planar_graze_used", 1):
		dmg += _roll_dice(1, 8)

	# ── Emberwake trail damage: if target is on emberwake tile ───────────────────
	if bool(tgt.get("on_emberwake", false)):
		dmg += _roll_dice(1, 6)
		tgt["on_emberwake"] = false

	# ── Poison weapon (from Poisoner's Kit): +1d4 poison ─────────────────────────
	if bool(atk.get("poison_weapon_active", false)):
		dmg += _roll_dice(1, 4)
		_dung_add_condition(tgt, "poisoned")
		atk["poison_weapon_active"] = false

	# ── Crafting & Artifice energy core: +1d6 elemental ──────────────────────────
	if bool(atk.get("energy_core_active", false)):
		dmg += _roll_dice(1, 6)

	# ── Magic item damage bonus (Anvilstone +1, etc.) ────────────────────────────
	dmg += _magic_item_bonus(atk_h, "dmg_bonus")

	# ── Weapon poison charges (from Basic Poison consumable) ─────────────────────
	if wp_charges > 0:
		dmg += _roll_dice(1, 4)
		_dung_add_condition(tgt, "poisoned")
		atk["weapon_poison_charges"] = wp_charges - 1

	# Crit: double damage (Precise Tactician extended crit range, paralyzed auto-crit)
	if is_crit or _dung_has_condition(tgt, "paralyzed"):
		dmg *= 2

	# Precise Tactician T2: crit = gain 2 AP
	if is_crit and pt_t >= 2:
		atk["ap_spent"] = maxi(0, int(atk.get("ap_spent", 0)) - 2)

	# ── Refraction Twist: halve damage if it still hits after disadvantage ────────
	if bool(tgt.get("refraction_half_dmg", false)):
		dmg = maxi(1, dmg / 2)
		tgt["refraction_half_dmg"] = false

	# ── Breath of Stone: immune to push/pull/prone, +2 AC already in AC calc ──
	# Enemies moving within 5 ft have speed halved — tracked via condition on approach

	# ── Damage reduction from defender feats ─────────────────────────────────────
	# Deflective Stance T3: reduce physical damage by Speed (1/round)
	if ds_t >= 3 and _ent_use_feat_charge(tgt, "_ds_reduce_used", 1):
		dmg = maxi(1, dmg - int(tgt_stats[1]))

	# Unarmored Master T2: reduce damage by SPDd4
	var um_t: int = int(tgt_feats.get("Unarmored Master", 0))
	if um_t >= 2 and _is_unarmored(tgt_h):
		var um_reduce: int = 0
		for _i in range(mini(int(tgt_stats[1]), 4)):
			um_reduce += randi_range(1, 4)
		dmg = maxi(1, dmg - um_reduce)

	# Titanic Bastion T3: resistance to non-magical physical (halve damage)
	var tb_t: int = int(tgt_feats.get("Titanic Bastion", 0))
	if tb_t >= 3 and not is_ranged_atk:
		dmg = maxi(1, dmg / 2)

	# Elemental Ward: reduce elemental/magic damage by tier
	var elw_t: int = int(tgt_feats.get("Elemental Ward", 0))
	if elw_t >= 1:
		dmg = maxi(1, dmg - elw_t * 2)

	# Tower Shield T1: reduce area/ranged damage by VIT
	var tsh_t: int = int(tgt_feats.get("Tower Shield", 0))
	if tsh_t >= 1 and is_ranged_atk and _has_shield(tgt_h):
		dmg = maxi(1, dmg - int(tgt_stats[3]))

	# ── Damage threshold (Apex/Kaiju): ignore damage below threshold ─────────
	var tgt_threshold: int = int(tgt.get("threshold", 0))
	if tgt_threshold > 0 and dmg < tgt_threshold:
		return {"hit": true, "damage": 0,
			"log": "%s attacks %s — damage below threshold (%d < %d)!%s" % [
				atk["name"], tgt["name"], dmg, tgt_threshold, elev_note],
			"target_dead": false, "target_id": tgt["id"]}

	# ── Resistances: halve damage if weapon type is resisted ──────────────────
	var tgt_resists: Array = tgt.get("resistances", [])
	if not tgt_resists.is_empty():
		var wpn_low: String = weapon.to_lower()
		var is_phys: bool = ("sword" in wpn_low or "axe" in wpn_low or "mace" in wpn_low or
			"hammer" in wpn_low or "spear" in wpn_low or "dagger" in wpn_low or
			"club" in wpn_low or "flail" in wpn_low or is_unarmed)
		# Crimson Edge T1: ignore slashing resistance; Iron Hammer T1: ignore bludgeoning
		var ignore_phys_resist: bool = (ce_t >= 1 or ih_t >= 1 or it_t >= 1)
		if is_phys and not ignore_phys_resist:
			if "non-magical physical" in tgt_resists or "bludgeoning" in tgt_resists or "slashing" in tgt_resists:
				dmg = maxi(1, dmg / 2)
		if _weapon_is_ranged(weapon) and "ranged" in tgt_resists:
			dmg = maxi(1, dmg / 2)

	# ── On-hit conditions from attacker feats ────────────────────────────────────
	# Turn the Blade T1: 25% chance to apply bleeding
	var ttb_t: int = int(atk_feats.get("Turn the Blade", 0))
	if ttb_t >= 1 and randi() % 4 < mini(ttb_t, 3):
		_dung_add_condition(tgt, "bleeding")

	# Effect Shaper: T1 25% stun, T2 33% slow, T3 50% prone
	var es_t: int = int(atk_feats.get("Effect Shaper", 0))
	if es_t >= 3 and randi() % 2 == 0: _dung_add_condition(tgt, "prone")
	elif es_t >= 2 and randi() % 3 == 0: _dung_add_condition(tgt, "slowed")
	elif es_t >= 1 and randi() % 4 == 0: _dung_add_condition(tgt, "stunned")

	# Assassin's Execution T1: kill grants +1 bonus damage for rest of encounter
	var ae_t: int = int(atk_feats.get("Assassin's Execution", 0))

	# ── Blade Scripture: +1d6 radiant/necrotic and heal 1 HP on hit ──────────────
	if bool(atk.get("blade_scripture_active", false)):
		var bs_bonus: int = _roll_dice(1, 6)
		dmg += bs_bonus
		atk["hp"] = mini(int(atk["max_hp"]), int(atk["hp"]) + 1)

	# ── Soulmark: marked creature takes +1d4 from marker's attacks ───────────
	var sm_marker_id = tgt.get("soulmark_by", "")
	if sm_marker_id != "" and sm_marker_id == atk.get("id", ""):
		dmg += _roll_dice(1, 4)

	# ── Barkskin Ritual: melee attackers take 1 piercing damage back ─────────
	if not is_ranged_atk and bool(tgt.get("barkskin_active", false)):
		_dung_reduce_hp(atk, 1)

	# ── Flare of Defiance: burst on reaching 0 HP ───────────────────────────────
	# (checked after damage is applied below)

	# ── Minion Master T2: damage transfer reaction ──────────────────────────────
	# If target has Minion Master T2+ and a nearby minion, redirect damage to minion
	var mm_transfer_msg: String = ""
	if bool(tgt.get("is_player", false)):
		var mm_t: int = _ent_feat_tier(tgt, "Minion Master")
		if mm_t >= 2 and not bool(tgt.get("_mm_transfer_used_this_round", false)):
			# Find a living minion belonging to this caster within 30ft (~6 tiles)
			for mm_ent in _dungeon_entities:
				if not bool(mm_ent.get("is_summon", false)): continue
				if bool(mm_ent.get("is_dead", false)): continue
				if str(mm_ent.get("summon_caster_id", "")) != str(tgt["id"]): continue
				if str(mm_ent.get("summon_feat", "")) != "minion_master": continue
				var dist: int = absi(int(mm_ent["x"]) - int(tgt["x"])) + absi(int(mm_ent["y"]) - int(tgt["y"]))
				if dist <= 6:  # ~30ft
					# Transfer damage to minion instead
					_dung_reduce_hp(mm_ent, dmg)
					if int(mm_ent["hp"]) <= 0:
						mm_ent["is_dead"] = true; mm_ent["conditions"].clear()
						mm_transfer_msg = " %s absorbs the blow and is destroyed!" % mm_ent["name"]
					else:
						mm_transfer_msg = " %s absorbs the blow! (%d HP left)" % [mm_ent["name"], int(mm_ent["hp"])]
					tgt["_mm_transfer_used_this_round"] = true
					dmg = 0  # target takes no damage
					break

	# ── Apply damage ─────────────────────────────────────────────────────────────
	var _ss_revert_msg: String = _dung_reduce_hp(tgt, dmg)
	var dead: bool = int(tgt["hp"]) <= 0

	# ── Lifesteal: heal attacker for % of damage dealt ───────────────────────────
	var ls_pct: int = int(atk.get("lifesteal_pct", 0))
	if ls_pct > 0 and dmg > 0:
		var heal_amt: int = maxi(1, dmg * ls_pct / 100)
		atk["hp"] = mini(int(atk["max_hp"]), int(atk["hp"]) + heal_amt)
		if atk_h >= 0 and _chars.has(atk_h): _chars[atk_h]["hp"] = atk["hp"]

	# ── Flare of Defiance: on reaching 0 HP, burst 1d6/2d6 to adjacent ──────
	if dead and bool(tgt.get("is_player", false)):
		var fod_t: int = _ent_feat_tier(tgt, "Flare of Defiance")
		if fod_t >= 1 and _ent_use_feat_charge(tgt, "_fod_used", 1):
			var fod_dice: int = 2 if fod_t >= 3 else 1
			var fod_dmg: int = _roll_dice(fod_dice, 6)
			for adj_ent in _dungeon_entities:
				if bool(adj_ent.get("is_dead", false)): continue
				if adj_ent.get("is_player", false): continue
				if absi(int(adj_ent["x"]) - int(tgt["x"])) <= 1 and absi(int(adj_ent["y"]) - int(tgt["y"])) <= 1:
					_dung_reduce_hp(adj_ent, fod_dmg)
					if adj_ent["hp"] == 0:
						adj_ent["is_dead"] = true; adj_ent["conditions"].clear()

	# Iron Vitality T5: 1/LR drop to 1 HP instead of death
	if dead and bool(tgt.get("is_player", false)):
		var iv_t: int = int(tgt_feats.get("Iron Vitality", 0))
		if iv_t >= 5 and _ent_use_feat_charge(tgt, "_iv_deathsave_used", 1):
			tgt["hp"] = 1; dead = false

	if dead:
		tgt["is_dead"] = true
		tgt["conditions"].clear()
		# Assassin's Execution: kill = +1 bonus damage for rest of combat
		if ae_t >= 1:
			atk["hit_bonus_buff"] = int(atk.get("hit_bonus_buff", 0)) + 1
		# Minion Master T2: if owner drops to 0 HP and has a living minion,
		# the minion gets one free attack on the nearest enemy then vanishes
		if bool(tgt.get("is_player", false)):
			var mm_death_t: int = _ent_feat_tier(tgt, "Minion Master")
			if mm_death_t >= 2:
				for mm_ent in _dungeon_entities:
					if not bool(mm_ent.get("is_summon", false)): continue
					if bool(mm_ent.get("is_dead", false)): continue
					if str(mm_ent.get("summon_caster_id", "")) != str(tgt["id"]): continue
					if str(mm_ent.get("summon_feat", "")) != "minion_master": continue
					# Minion gets one free attack on nearest enemy
					var nearest_enemy = null
					var nearest_dist: int = 999
					for enemy_ent in _dungeon_entities:
						if bool(enemy_ent.get("is_dead", false)): continue
						if bool(enemy_ent.get("is_player", false)) or bool(enemy_ent.get("is_friendly", false)): continue
						var d: int = absi(int(enemy_ent["x"]) - int(mm_ent["x"])) + absi(int(enemy_ent["y"]) - int(mm_ent["y"]))
						if d < nearest_dist:
							nearest_dist = d; nearest_enemy = enemy_ent
					if nearest_enemy != null and nearest_dist <= 2:
						var farewell_dmg: int = randi_range(1, 8) + int(mm_ent.get("creature_level", 1))
						_dung_reduce_hp(nearest_enemy, farewell_dmg)
						if int(nearest_enemy["hp"]) <= 0:
							nearest_enemy["is_dead"] = true; nearest_enemy["conditions"].clear()
						mm_transfer_msg += " %s strikes %s for %d before vanishing!" % [mm_ent["name"], nearest_enemy["name"], farewell_dmg]
					# Minion vanishes
					mm_ent["is_dead"] = true; mm_ent["conditions"].clear()
					break  # only first minion gets the farewell action

	# Assassin's Execution T3: execute creatures below 1/4 HP
	if not dead and ae_t >= 3:
		var hp_frac: float = float(int(tgt["hp"])) / float(maxi(1, int(tgt["max_hp"])))
		var exec_thresh: float = 0.5 if ae_t >= 5 else 0.25
		if hp_frac <= exec_thresh and not bool(tgt.get("is_player", false)):
			tgt["hp"] = 0; tgt["is_dead"] = true; tgt["conditions"].clear()
			dead = true

	# Sync HP to character sheet if player
	var handle: int = tgt.get("handle", -1)
	if handle >= 0 and _chars.has(handle): _chars[handle]["hp"] = tgt["hp"]

	# ── Injury check (player units at ≤25% HP get a random injury) ───────────────
	if not dead and bool(tgt.get("is_player", false)):
		var hp_pct: float = float(int(tgt["hp"])) / float(maxi(1, int(tgt["max_hp"])))
		if hp_pct <= 0.25:
			var existing: Array = tgt.get("injuries", [])
			if randi() % 3 == 0 and existing.size() < 3:  # 33% chance, max 3 injuries
				const INJURIES: Array = ["Limping","Broken Arm","Cracked Rib",
					"Concussion","Deep Gash","Sprained Wrist","Twisted Ankle"]
				var inj: String = INJURIES[randi() % INJURIES.size()]
				if inj not in existing:
					if not tgt.has("injuries"): tgt["injuries"] = []
					tgt["injuries"].append(inj)
					if inj == "Limping":
						tgt["speed"] = maxi(1, int(tgt["speed"]) - 1)
					elif inj == "Broken Arm":
						tgt["hit_penalty"] = int(tgt.get("hit_penalty", 0)) + 1
					elif inj == "Concussion":
						tgt["max_ap"] = maxi(2, int(tgt["max_ap"]) - 2)

	var crit_note: String = " CRITICAL!" if is_crit else ""
	var suffix: String = " [DEFEATED]" if dead else ""
	var ss_note: String = (" " + _ss_revert_msg) if _ss_revert_msg != "" else ""
	var mm_note: String = mm_transfer_msg  # already has leading space if non-empty
	return {"hit": true, "damage": dmg,
		"log": "%s attacks %s for %d damage%s%s%s!%s%s" % [atk["name"], tgt["name"], dmg, crit_note, elev_note, suffix, ss_note, mm_note],
		"target_dead": dead, "target_id": tgt["id"]}

# ── Legacy compatibility wrappers ─────────────────────────────────────────────
## Called directly by dungeon.gd — routes through _dung_do_attack.
func dungeon_attack(attacker_id: String, target_id: String) -> Dictionary:
	var atk = _dung_find(attacker_id)
	var tgt = _dung_find(target_id)
	if atk == null or tgt == null:
		return {"hit": false, "damage": 0, "log": "Invalid targets.", "target_dead": false, "target_id": target_id}
	var ap_cost: int = 2
	if atk["ap_spent"] + ap_cost > atk["max_ap"]:
		return {"hit": false, "damage": 0, "log": "Not enough AP!", "target_dead": false, "target_id": target_id}
	atk["ap_spent"] += ap_cost
	return _dung_do_attack(atk, tgt, atk["equipped_weapon"], false)

# ── Adjacency query ───────────────────────────────────────────────────────────
func get_adjacent_enemies(id: String) -> Array:
	var ent = _dung_find(id)
	if ent == null: return []
	var result: Array = []
	for dir in [[0,1],[0,-1],[1,0],[-1,0]]:
		var nx2: int = ent["x"] + dir[0]
		var ny2: int = ent["y"] + dir[1]
		for other in _dungeon_entities:
			if other["is_dead"]: continue
			if other["is_player"] == ent["is_player"]: continue
			if other["is_friendly"] == ent["is_player"]: continue
			if int(other["x"]) == nx2 and int(other["y"]) == ny2:
				result.append(other)
	return result

## Returns all enemies within a Chebyshev radius of the actor's position.
func _get_enemies_in_burst(id: String, radius: int) -> Array:
	var ent = _dung_find(id)
	if ent == null: return []
	var result: Array = []
	for other in _dungeon_entities:
		if other["is_dead"]: continue
		if other["is_player"] == ent["is_player"]: continue
		if other["is_friendly"] == ent["is_player"]: continue
		var dx: int = abs(int(other["x"]) - int(ent["x"]))
		var dy: int = abs(int(other["y"]) - int(ent["y"]))
		if maxi(dx, dy) <= radius:
			result.append(other)
	return result

# ── Condition helpers ─────────────────────────────────────────────────────────
func _dung_has_condition(ent: Dictionary, cond: String) -> bool:
	return cond in ent.get("conditions", [])

func _dung_add_condition(ent: Dictionary, cond: String) -> void:
	if not _dung_has_condition(ent, cond):
		ent["conditions"].append(cond)

func _dung_remove_condition(ent: Dictionary, cond: String) -> void:
	ent["conditions"].erase(cond)

## Called at the start of each entity's turn to clear transient conditions.
func _dung_tick_conditions(ent: Dictionary) -> void:
	# Dodging condition expires each turn
	ent["conditions"].erase("dodging")
	# Reset per-round feat charges
	ent.erase("_ds_counter_used"); ent.erase("_ds_reduce_used")

	# ── Feat: Iron Vitality T1: regain VIT HP when crossing ≤50% threshold ─────
	var iv_t: int = _ent_feat_tier(ent, "Iron Vitality")
	if iv_t >= 1 and bool(ent.get("is_player", false)):
		var hp_frac: float = float(int(ent["hp"])) / float(maxi(1, int(ent["max_hp"])))
		if hp_frac <= 0.5 and _ent_use_feat_charge(ent, "_iv_regen_used", 1):
			var h: int = int(ent.get("handle", -1))
			if h >= 0 and _chars.has(h):
				var vit_v: int = int(_chars[h].get("stats", [1,1,1,1,1])[3])
				var heal: int = vit_v
				if iv_t >= 3: heal += vit_v  # T3: heals increased by VIT
				ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + heal)
				if h >= 0 and _chars.has(h): _chars[h]["hp"] = ent["hp"]

	# ── Feat: Martial Focus T3: +AP = STR on initiative (once per combat) ───────
	var mf_t: int = _ent_feat_tier(ent, "Martial Focus")
	if mf_t >= 3 and _ent_use_feat_charge(ent, "_mf_ap_used", 1):
		var h2: int = int(ent.get("handle", -1))
		if h2 >= 0 and _chars.has(h2):
			var str_bonus: int = int(_chars[h2].get("stats", [1,1,1,1,1])[0])
			ent["ap_spent"] = maxi(0, int(ent.get("ap_spent", 0)) - str_bonus)

	# Bleeding: 1d4 damage per stack at start of turn (PHB stacking bleeds)
	if _dung_has_condition(ent, "bleeding"):
		var bleed_stacks: int = 0
		for cond in ent.get("conditions", []):
			if cond == "bleeding":
				bleed_stacks += 1
		bleed_stacks = maxi(1, bleed_stacks)
		var bleed_dmg: int = 0
		for _i in range(bleed_stacks):
			bleed_dmg += randi_range(1, 4)
		# Elemental Ward: reduce condition damage
		var elw_t: int = _ent_feat_tier(ent, "Elemental Ward")
		if elw_t >= 1: bleed_dmg = maxi(0, bleed_dmg - elw_t * 2)
		_dung_reduce_hp(ent, bleed_dmg)
		if int(ent["hp"]) <= 0:
			ent["is_dead"] = true
			ent["conditions"].clear()
			return

	# Stunned: consume all AP this turn, then auto-clear after 1 round
	if _dung_has_condition(ent, "stunned"):
		ent["ap_spent"] = int(ent.get("max_ap", 10))
		ent["conditions"].erase("stunned")

	# Poisoned: 1d4 poison damage + disadvantage on attacks
	if _dung_has_condition(ent, "poisoned"):
		var poison_dmg: int = randi_range(1, 4)
		var elw_t2: int = _ent_feat_tier(ent, "Elemental Ward")
		if elw_t2 >= 2: poison_dmg = maxi(0, poison_dmg - elw_t2)
		# Safeguard T1: 50% chance to shake off poison
		var sg_t: int = _ent_feat_tier(ent, "Safeguard")
		if sg_t >= 1 and randi() % 2 == 0:
			ent["conditions"].erase("poisoned"); poison_dmg = 0
		_dung_reduce_hp(ent, poison_dmg)
		if int(ent["hp"]) <= 0:
			ent["is_dead"] = true
			ent["conditions"].clear()
			return

	# Burning: 1d6 fire damage at start of turn, 50% chance to self-extinguish
	if _dung_has_condition(ent, "burning"):
		var burn_dmg: int = randi_range(1, 6)
		var elw_t3: int = _ent_feat_tier(ent, "Elemental Ward")
		if elw_t3 >= 3: burn_dmg = maxi(0, burn_dmg - elw_t3 * 2)
		_dung_reduce_hp(ent, burn_dmg)
		if int(ent["hp"]) <= 0:
			ent["is_dead"] = true
			ent["conditions"].clear()
			return
		if randi() % 2 == 0:
			ent["conditions"].erase("burning")

	# Exhaustion: cumulative penalties — each stack gives -1 to all rolls (tracked via exhaustion_stacks)
	if _dung_has_condition(ent, "exhausted"):
		var ex_stacks: int = int(ent.get("exhaustion_stacks", 1))
		# Speed penalty: -5ft (1 tile) per stack
		ent["speed"] = maxi(1, int(ent.get("base_speed", ent.get("speed", 4))) - ex_stacks)
		# At 3+ stacks: lose 1 AP
		if ex_stacks >= 3:
			ent["max_ap"] = maxi(2, int(ent.get("base_max_ap", ent.get("max_ap", 10))) - (ex_stacks - 2))
		# At 5+ stacks: halve max HP
		if ex_stacks >= 5:
			ent["max_hp"] = maxi(1, int(ent.get("base_max_hp", ent.get("max_hp", 20))) / 2)
			ent["hp"] = mini(int(ent["hp"]), int(ent["max_hp"]))

	# Dazed: lose 2 AP this turn
	if _dung_has_condition(ent, "dazed"):
		ent["ap_spent"] = int(ent.get("ap_spent", 0)) + 2
		ent["conditions"].erase("dazed")

	# Slowed: halve speed
	if _dung_has_condition(ent, "slowed"):
		ent["speed"] = maxi(1, int(ent.get("speed", 4)) / 2)

	# Restrained: speed = 0
	if _dung_has_condition(ent, "restrained"):
		ent["speed"] = 0

	# Paralyzed: speed = 0, attacks auto-hit (checked in _dung_do_attack)
	if _dung_has_condition(ent, "paralyzed"):
		ent["speed"] = 0
		ent["ap_spent"] = int(ent.get("max_ap", 10))  # can't act

	# Petrified: turned to stone, can't act
	if _dung_has_condition(ent, "petrified"):
		ent["speed"] = 0
		ent["ap_spent"] = int(ent.get("max_ap", 10))

	# Incapacitated: can't attack or defend
	if _dung_has_condition(ent, "incapacitated"):
		ent["ap_spent"] = int(ent.get("max_ap", 10))

	# Squeezed (PHB): 1d4 bludgeoning at start of turn
	if _dung_has_condition(ent, "squeezed"):
		var squeeze_dmg: int = randi_range(1, 4)
		_dung_reduce_hp(ent, squeeze_dmg)
		if int(ent["hp"]) <= 0:
			ent["is_dead"] = true; ent["conditions"].clear(); return

	# Frozen in time: immune to damage, cannot act
	if _dung_has_condition(ent, "frozen_time"):
		ent["speed"] = 0
		ent["ap_spent"] = int(ent.get("max_ap", 10))

	# Hasted: reduce AP cost by 1 (min 0) for actions
	if _dung_has_condition(ent, "hasted"):
		ent["ap_cost_discount"] = 1  # consumed by action system

	# Depleted: don't regain AP at start of turn
	if _dung_has_condition(ent, "depleted"):
		ent["no_ap_regen"] = true

	# Enraged: must focus on curse source, attacks on others cost double
	if _dung_has_condition(ent, "enraged"):
		pass  # Handled by action cost system

	# Regeneration: if entity has regen_per_turn (from feats/spells), heal that amount
	var regen: int = int(ent.get("regen_per_turn", 0))
	if regen > 0 and not bool(ent.get("is_dead", false)):
		ent["hp"] = mini(int(ent["max_hp"]), int(ent["hp"]) + regen)
		var h: int = int(ent.get("handle", -1))
		if h >= 0 and _chars.has(h): _chars[h]["hp"] = ent["hp"]

	# ── PHB damage-type conditions ──────────────────────────────────────────────

	# Acid corroded: -2 AC until start of next turn, stackable
	if _dung_has_condition(ent, "acid_corroded"):
		ent["ac"] = maxi(0, int(ent.get("ac", 10)) - 2)
		ent["conditions"].erase("acid_corroded")  # clears at turn start

	# Confused (psychic): all actions cost double AP this turn
	if _dung_has_condition(ent, "confused"):
		ent["ap_cost_multiplier"] = 2  # consumed by action system
		ent["conditions"].erase("confused")

	# Necrotic taint: healing hurts instead of helping (checked in heal code)
	# Stays until saved; auto-clear after 1 round in combat
	if _dung_has_condition(ent, "necrotic_taint"):
		ent["conditions"].erase("necrotic_taint")

	# No reactions (lightning): cannot take reactions this round
	if _dung_has_condition(ent, "no_reactions"):
		ent["no_reactions"] = true
		ent["conditions"].erase("no_reactions")

	# Radiant dazzle: disadvantage on attacks this turn
	if _dung_has_condition(ent, "radiant_dazzle"):
		ent["hit_penalty"] = int(ent.get("hit_penalty", 0)) + 3
		ent["conditions"].erase("radiant_dazzle")

	# Slashed: -1 to attacks, stackable, clears at end of next turn
	if _dung_has_condition(ent, "slashed"):
		ent["hit_penalty"] = int(ent.get("hit_penalty", 0)) + 1
		ent["conditions"].erase("slashed")

	# Pushed: handled at damage time (displacement), clear condition
	if _dung_has_condition(ent, "pushed"):
		ent["conditions"].erase("pushed")

	# "grappled" stays until escaped; "hidden" stays until they attack
	# "prone", "flying", "invisible", "charmed" are managed by action handlers

# ── Return helpers ────────────────────────────────────────────────────────────
func _dung_ok(log: String, ap: int, sp: int) -> Dictionary:
	return {"success": true, "log": log, "ap_spent": ap, "sp_spent": sp}

func _dung_fail(reason: String) -> Dictionary:
	return {"success": false, "log": reason, "ap_spent": 0, "sp_spent": 0}

# ── Weapon helpers ────────────────────────────────────────────────────────────
func _weapon_is_ranged(weapon: String) -> bool:
	var ranged_keywords: Array = ["Bow","Crossbow","Rifle","Pistol","Wand","Staff","Sling","Dart","Javelin","Shortbow","Longbow"]
	for kw in ranged_keywords:
		if kw.to_lower() in weapon.to_lower(): return true
	return false

func _weapon_damage(weapon: String) -> int:
	# Returns a damage roll based on weapon type keyword
	var w: String = weapon.to_lower()
	# Construct weapons: light=1d6, martial=1d8, heavy=2d6
	if "construct light" in w:           return randi_range(1, 6)
	if "construct martial" in w:         return randi_range(1, 8) + 1
	if "construct heavy" in w:           return randi_range(2, 6) + 2
	if "dagger" in w or "knife" in w:   return randi_range(1, 4) + 1
	if "short" in w:                     return randi_range(1, 6) + 1
	if "long" in w or "broad" in w:     return randi_range(1, 8) + 2
	if "great" in w or "maul" in w:     return randi_range(2, 6) + 2
	if "axe" in w:                       return randi_range(1, 8) + 1
	if "mace" in w or "hammer" in w:    return randi_range(1, 6) + 2
	if "bow" in w or "crossbow" in w:   return randi_range(1, 8) + 1
	if "staff" in w or "wand" in w:     return randi_range(1, 6) + 1
	if "spear" in w or "lance" in w:    return randi_range(1, 8) + 1
	return randi_range(1, 6) + 1  # generic weapon

# ── Core map helpers ──────────────────────────────────────────────────────────
func _dung_find(id: String):
	for e in _dungeon_entities:
		if e["id"] == id: return e
	return null

func _dung_tile(x: int, y: int) -> int:
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE: return TILE_VOID
	return _dungeon_map[y * MAP_SIZE + x]

func _dung_occupied(x: int, y: int) -> bool:
	for e in _dungeon_entities:
		if not e["is_dead"] and int(e["x"]) == x and int(e["y"]) == y: return true
	return false

## Return the live entity standing on (x,y), or null if the tile is clear.
func _dung_entity_at(x: int, y: int):
	for e in _dungeon_entities:
		if not e["is_dead"] and int(e["x"]) == x and int(e["y"]) == y: return e
	return null

## Find the closest living enemy to a given entity.
func _dung_closest_enemy(ent: Dictionary):
	var is_player: bool = bool(ent.get("is_player", false))
	var ex: int = int(ent["x"]); var ey: int = int(ent["y"])
	var best = null
	var best_dist: int = 9999
	for e in _dungeon_entities:
		if bool(e.get("is_dead", false)): continue
		if e.get("id", "") == ent.get("id", ""): continue
		if bool(e.get("is_player", false)) == is_player: continue
		var dx: int = absi(int(e["x"]) - ex)
		var dy: int = absi(int(e["y"]) - ey)
		var d: int = dx + dy
		if d < best_dist:
			best_dist = d; best = e
	return best

func _dung_set(map: PackedInt32Array, x: int, y: int, t: int) -> void:
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE: return
	map[y * MAP_SIZE + x] = t

# ── Map generation ────────────────────────────────────────────────────────────
func _carve_room(map: PackedInt32Array, x1: int, y1: int, x2: int, y2: int) -> void:
	for ry in range(y1, y2 + 1):
		for rx in range(x1, x2 + 1):
			_dung_set(map, rx, ry, TILE_FLOOR)

func _carve_corridor(map: PackedInt32Array, x1: int, y1: int, x2: int, y2: int, width: int = 1) -> void:
	# Carve a corridor with configurable width (1 = single tile, 2 = two wide, etc.)
	var cx: int = x1; var cy: int = y1
	while cx != x2:
		for w in range(width):
			_dung_set(map, cx, cy + w, TILE_FLOOR)
			if w > 0: _dung_set(map, cx, cy - w, TILE_FLOOR)
		cx += 1 if x2 > x1 else -1
	while cy != y2:
		for w in range(width):
			_dung_set(map, cx + w, cy, TILE_FLOOR)
			if w > 0: _dung_set(map, cx - w, cy, TILE_FLOOR)
		cy += 1 if y2 > y1 else -1
	_dung_set(map, x2, y2, TILE_FLOOR)

## Carve an L-shaped corridor with a random bend point
func _carve_corridor_bent(map: PackedInt32Array, x1: int, y1: int, x2: int, y2: int, rng: RandomNumberGenerator, width: int = 1) -> void:
	# 50% chance: go horizontal first then vertical, or vice versa
	if rng.randf() < 0.5:
		_carve_corridor(map, x1, y1, x2, y1, width)
		_carve_corridor(map, x2, y1, x2, y2, width)
	else:
		_carve_corridor(map, x1, y1, x1, y2, width)
		_carve_corridor(map, x1, y2, x2, y2, width)

## Helper: generate a random room rect within bounds
func _rand_room(rng: RandomNumberGenerator, min_x: int, min_y: int, max_x: int, max_y: int, min_w: int = 3, max_w: int = 6) -> Array:
	var w: int = rng.randi_range(min_w, max_w)
	var h: int = rng.randi_range(min_w, max_w)
	var x1: int = rng.randi_range(min_x, maxi(min_x, max_x - w))
	var y1: int = rng.randi_range(min_y, maxi(min_y, max_y - h))
	return [x1, y1, mini(x1 + w, 23), mini(y1 + h, 23)]

## Find the nearest walkable floor tile to (sx, sy) that isn't in occupied_dict.
## Uses a BFS spiral outward from the starting point.
func _find_nearest_floor(sx: int, sy: int, occupied_dict: Dictionary) -> Array:
	# Check the requested tile first
	var idx: int = sy * MAP_SIZE + sx
	if sx >= 0 and sx < MAP_SIZE and sy >= 0 and sy < MAP_SIZE:
		if _dungeon_map[idx] == TILE_FLOOR and not occupied_dict.has(Vector2i(sx, sy)):
			return [sx, sy]
	# BFS outward
	var visited: Dictionary = {}
	var queue: Array = [[sx, sy]]
	visited[Vector2i(sx, sy)] = true
	var dirs: Array = [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]]
	while not queue.is_empty():
		var cur: Array = queue.pop_front()
		for d in dirs:
			var nx: int = cur[0] + d[0]
			var ny: int = cur[1] + d[1]
			var key := Vector2i(nx, ny)
			if visited.has(key): continue
			visited[key] = true
			if nx < 0 or nx >= MAP_SIZE or ny < 0 or ny >= MAP_SIZE: continue
			var ni: int = ny * MAP_SIZE + nx
			if _dungeon_map[ni] == TILE_FLOOR and not occupied_dict.has(key):
				return [nx, ny]
			queue.append([nx, ny])
	# Fallback: return original position (shouldn't happen on a valid map)
	return [sx, sy]

func _gen_dungeon_map() -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(MAP_SIZE * MAP_SIZE)
	map.fill(TILE_VOID)

	var rng := RandomNumberGenerator.new()
	rng.seed = randi()

	# ── Layout selection (16 archetypes) ─────────────────────────────────────
	var layout: int = rng.randi_range(0, 15)
	var rooms: Array = []
	var corridor_width: int = 1 if rng.randf() < 0.6 else 2

	match layout:
		0:  # Scattered Rooms: 4-6 random rooms across the map
			var room_count: int = rng.randi_range(4, 6)
			for ri in range(room_count):
				rooms.append(_rand_room(rng, 1, 1, 20, 20, 3, 7))

		1:  # Grand Hall with alcoves
			var hall_x1: int = rng.randi_range(4, 7)
			var hall_y1: int = rng.randi_range(4, 7)
			rooms.append([hall_x1, hall_y1, hall_x1 + rng.randi_range(9, 13), hall_y1 + rng.randi_range(9, 13)])
			# Corner alcoves at random positions
			rooms.append(_rand_room(rng, 1, 1, 5, 5, 2, 4))
			rooms.append(_rand_room(rng, 18, 1, 22, 5, 2, 4))
			rooms.append(_rand_room(rng, 1, 18, 5, 22, 2, 4))
			rooms.append(_rand_room(rng, 18, 18, 22, 22, 2, 4))

		2:  # Labyrinth: many small rooms
			for _i in range(rng.randi_range(8, 12)):
				rooms.append(_rand_room(rng, 1, 1, 20, 20, 2, 5))

		3:  # Arena: large circle + random antechambers
			var arena_cx: int = rng.randi_range(10, 14)
			var arena_cy: int = rng.randi_range(10, 14)
			_carve_circle(map, arena_cx, arena_cy, rng.randi_range(6, 9))
			for _i in range(rng.randi_range(3, 5)):
				rooms.append(_rand_room(rng, 1, 1, 22, 22, 2, 4))

		4:  # Cavern: organic blobs
			for _i in range(rng.randi_range(6, 10)):
				var ccx: int = rng.randi_range(3, 21)
				var ccy: int = rng.randi_range(3, 21)
				_carve_circle(map, ccx, ccy, rng.randi_range(2, 5))
			rooms.append([1, 1, rng.randi_range(4, 6), rng.randi_range(4, 6)])
			rooms.append([rng.randi_range(18, 20), rng.randi_range(18, 20), 23, 23])

		5:  # Cross: randomized wings from center hub
			var hub_x: int = rng.randi_range(9, 13)
			var hub_y: int = rng.randi_range(9, 13)
			var hub_r: int = rng.randi_range(2, 4)
			rooms.append([hub_x - hub_r, hub_y - hub_r, hub_x + hub_r, hub_y + hub_r])
			# Wings in 4 directions with random sizes
			rooms.append([rng.randi_range(1, 3), hub_y - rng.randi_range(1, 2), rng.randi_range(hub_x - hub_r - 2, hub_x - hub_r), hub_y + rng.randi_range(1, 2)])
			rooms.append([rng.randi_range(hub_x + hub_r + 1, hub_x + hub_r + 3), hub_y - rng.randi_range(1, 2), rng.randi_range(21, 23), hub_y + rng.randi_range(1, 2)])
			rooms.append([hub_x - rng.randi_range(1, 2), rng.randi_range(1, 3), hub_x + rng.randi_range(1, 2), rng.randi_range(hub_y - hub_r - 2, hub_y - hub_r)])
			rooms.append([hub_x - rng.randi_range(1, 2), rng.randi_range(hub_y + hub_r + 1, hub_y + hub_r + 3), hub_x + rng.randi_range(1, 2), rng.randi_range(21, 23)])

		6:  # Catacombs: randomized grid cells
			var grid_cols: int = rng.randi_range(3, 5)
			var grid_rows: int = rng.randi_range(3, 5)
			var cell_w: int = (MAP_SIZE - 2) / grid_cols
			var cell_h: int = (MAP_SIZE - 2) / grid_rows
			for gx in range(grid_cols):
				for gy in range(grid_rows):
					if rng.randf() < 0.15: continue  # skip some cells for variety
					var bx: int = 1 + gx * cell_w
					var by: int = 1 + gy * cell_h
					rooms.append([bx, by, bx + rng.randi_range(2, cell_w - 1), by + rng.randi_range(2, cell_h - 1)])

		7:  # Throne Room: randomized hall + side rooms
			var hall_w: int = rng.randi_range(14, 18)
			var hall_x: int = (MAP_SIZE - hall_w) / 2
			rooms.append([hall_x, 1, hall_x + hall_w, rng.randi_range(5, 7)])
			rooms.append([rng.randi_range(7, 9), rng.randi_range(7, 9), rng.randi_range(15, 17), rng.randi_range(16, 18)])
			rooms.append([hall_x, rng.randi_range(18, 20), hall_x + hall_w, 23])
			rooms.append(_rand_room(rng, 1, 7, 6, 13, 3, 5))
			rooms.append(_rand_room(rng, 18, 7, 23, 13, 3, 5))

		8:  # Spiral: rooms arranged in a clockwise spiral path
			rooms.append(_rand_room(rng, 1, 1, 6, 6, 3, 5))      # top-left start
			rooms.append(_rand_room(rng, 10, 1, 16, 5, 4, 6))     # top-center
			rooms.append(_rand_room(rng, 18, 1, 23, 7, 3, 5))     # top-right
			rooms.append(_rand_room(rng, 18, 10, 23, 16, 3, 5))   # right-center
			rooms.append(_rand_room(rng, 17, 18, 23, 23, 3, 5))   # bottom-right
			rooms.append(_rand_room(rng, 9, 18, 15, 23, 4, 5))    # bottom-center
			rooms.append(_rand_room(rng, 1, 17, 7, 23, 3, 5))     # bottom-left
			rooms.append(_rand_room(rng, 1, 9, 6, 15, 3, 5))      # left-center
			rooms.append(_rand_room(rng, 8, 8, 16, 16, 4, 7))     # center room (final)

		9:  # River: rooms along a winding vertical or horizontal path
			var vertical: bool = rng.randf() < 0.5
			var num_stops: int = rng.randi_range(5, 7)
			for si in range(num_stops):
				if vertical:
					var seg_y: int = 1 + si * ((MAP_SIZE - 4) / num_stops)
					rooms.append(_rand_room(rng, rng.randi_range(1, 14), seg_y, rng.randi_range(8, 22), mini(seg_y + 5, 23), 3, 5))
				else:
					var seg_x: int = 1 + si * ((MAP_SIZE - 4) / num_stops)
					rooms.append(_rand_room(rng, seg_x, rng.randi_range(1, 14), mini(seg_x + 5, 23), rng.randi_range(8, 22), 3, 5))

		10: # Figure Eight: two large circles connected at center
			var c1x: int = rng.randi_range(6, 8)
			var c1y: int = rng.randi_range(10, 14)
			var c2x: int = rng.randi_range(16, 18)
			var c2y: int = rng.randi_range(10, 14)
			_carve_circle(map, c1x, c1y, rng.randi_range(4, 6))
			_carve_circle(map, c2x, c2y, rng.randi_range(4, 6))
			rooms.append([1, 1, rng.randi_range(3, 5), rng.randi_range(3, 5)])
			rooms.append([rng.randi_range(19, 21), rng.randi_range(19, 21), 23, 23])

		11: # Diamond: rooms at compass points + center
			var mid: int = MAP_SIZE / 2
			rooms.append([mid - 2, mid - 2, mid + 2, mid + 2])  # center
			rooms.append(_rand_room(rng, mid - 2, 1, mid + 2, 5, 3, 4))   # north
			rooms.append(_rand_room(rng, mid - 2, 19, mid + 2, 23, 3, 4)) # south
			rooms.append(_rand_room(rng, 1, mid - 2, 5, mid + 2, 3, 4))   # west
			rooms.append(_rand_room(rng, 19, mid - 2, 23, mid + 2, 3, 4)) # east
			# Diagonal corners
			rooms.append(_rand_room(rng, 1, 1, 6, 6, 2, 4))
			rooms.append(_rand_room(rng, 18, 18, 23, 23, 2, 4))

		12: # Barbell: two large rooms connected by a long narrow corridor
			var r1_w: int = rng.randi_range(5, 8)
			var r1_h: int = rng.randi_range(5, 8)
			var r2_w: int = rng.randi_range(5, 8)
			var r2_h: int = rng.randi_range(5, 8)
			rooms.append([1, 1, r1_w, r1_h])
			rooms.append([MAP_SIZE - 1 - r2_w, MAP_SIZE - 1 - r2_h, MAP_SIZE - 2, MAP_SIZE - 2])
			# One or two midpoint rooms along the corridor
			rooms.append(_rand_room(rng, 9, 9, 15, 15, 2, 4))
			corridor_width = 2

		13: # Archipelago: many circles of varying size
			for _i in range(rng.randi_range(8, 14)):
				var ax: int = rng.randi_range(3, 21)
				var ay: int = rng.randi_range(3, 21)
				_carve_circle(map, ax, ay, rng.randi_range(1, 4))
			rooms.append([1, 1, rng.randi_range(3, 5), rng.randi_range(3, 5)])
			rooms.append([rng.randi_range(19, 21), rng.randi_range(19, 21), 23, 23])

		14: # H-Shape: two vertical halls with horizontal connector
			var left_x: int = rng.randi_range(1, 3)
			var right_x: int = rng.randi_range(17, 19)
			var hall_top: int = rng.randi_range(1, 4)
			var hall_bot: int = rng.randi_range(20, 23)
			rooms.append([left_x, hall_top, left_x + rng.randi_range(3, 5), hall_bot])
			rooms.append([right_x, hall_top, right_x + rng.randi_range(3, 5), hall_bot])
			# Horizontal connector rooms
			var conn_y: int = rng.randi_range(10, 14)
			rooms.append([left_x + 4, conn_y - 1, right_x, conn_y + rng.randi_range(1, 2)])
			# Extra rooms in the voids
			rooms.append(_rand_room(rng, left_x + 5, hall_top, right_x - 1, conn_y - 2, 2, 4))
			rooms.append(_rand_room(rng, left_x + 5, conn_y + 3, right_x - 1, hall_bot, 2, 4))

		15: # Chaos: BSP-inspired random binary partition
			# Split the space recursively for organic room placement
			var partitions: Array = [[1, 1, 23, 23]]
			for _split in range(rng.randi_range(3, 5)):
				var new_parts: Array = []
				for part in partitions:
					var px1: int = int(part[0]); var py1: int = int(part[1])
					var px2: int = int(part[2]); var py2: int = int(part[3])
					var pw: int = px2 - px1; var ph: int = py2 - py1
					if pw < 6 and ph < 6:
						new_parts.append(part)
						continue
					if pw >= ph and pw >= 6:
						var sx: int = px1 + rng.randi_range(3, pw - 3)
						new_parts.append([px1, py1, sx, py2])
						new_parts.append([sx + 1, py1, px2, py2])
					elif ph >= 6:
						var sy: int = py1 + rng.randi_range(3, ph - 3)
						new_parts.append([px1, py1, px2, sy])
						new_parts.append([px1, sy + 1, px2, py2])
					else:
						new_parts.append(part)
				partitions = new_parts
			# Place a room in each partition
			for bsp_part in partitions:
				var bx1: int = int(bsp_part[0]); var by1: int = int(bsp_part[1])
				var bx2: int = int(bsp_part[2]); var by2: int = int(bsp_part[3])
				var rw2: int = maxi(2, (bx2 - bx1) - rng.randi_range(1, 3))
				var rh2: int = maxi(2, (by2 - by1) - rng.randi_range(1, 3))
				var rx2: int = bx1 + rng.randi_range(0, maxi(0, (bx2 - bx1) - rw2))
				var ry2: int = by1 + rng.randi_range(0, maxi(0, (by2 - by1) - rh2))
				rooms.append([rx2, ry2, mini(rx2 + rw2, 23), mini(ry2 + rh2, 23)])

	# ── Carve all rooms ──────────────────────────────────────────────────────
	for r in rooms:
		_carve_room(map, int(r[0]), int(r[1]), int(r[2]), int(r[3]))

	# ── Connect rooms with corridors (sequential chain + shortcuts) ──────────
	# Use bent corridors for more interesting paths
	for i in range(rooms.size() - 1):
		var r1: Array = rooms[i]
		var r2: Array = rooms[i + 1]
		var cx1: int = (int(r1[0]) + int(r1[2])) / 2
		var cy1: int = (int(r1[1]) + int(r1[3])) / 2
		var cx2: int = (int(r2[0]) + int(r2[2])) / 2
		var cy2: int = (int(r2[1]) + int(r2[3])) / 2
		_carve_corridor_bent(map, cx1, cy1, cx2, cy2, rng, corridor_width)

	# Extra shortcut corridors — connect first to last, and random pairs
	if rooms.size() >= 3:
		var r_first: Array = rooms[0]
		var r_last: Array  = rooms[rooms.size() - 1]
		_carve_corridor_bent(map,
			(int(r_first[0]) + int(r_first[2])) / 2,
			(int(r_first[1]) + int(r_first[3])) / 2,
			(int(r_last[0]) + int(r_last[2])) / 2,
			(int(r_last[1]) + int(r_last[3])) / 2,
			rng, corridor_width)
		# Random cross-links for extra connectivity
		var extra_links: int = rng.randi_range(1, 3)
		for _el in range(extra_links):
			var ra_idx: int = rng.randi_range(0, rooms.size() - 1)
			var rb_idx: int = rng.randi_range(0, rooms.size() - 1)
			if ra_idx == rb_idx: continue
			var ra: Array = rooms[ra_idx]
			var rb: Array = rooms[rb_idx]
			_carve_corridor_bent(map,
				(int(ra[0]) + int(ra[2])) / 2,
				(int(ra[1]) + int(ra[3])) / 2,
				(int(rb[0]) + int(rb[2])) / 2,
				(int(rb[1]) + int(rb[3])) / 2,
				rng, 1)

	# ── Guaranteed start and end floor zones ─────────────────────────────────
	# Make sure tiles near (2,2) and (21,21) are carved even if no room landed there
	for sy in range(1, 5):
		for sx in range(1, 5):
			if map[sy * MAP_SIZE + sx] == TILE_VOID:
				_dung_set(map, sx, sy, TILE_FLOOR)
	for sy in range(20, 24):
		for sx in range(20, 24):
			if sx < MAP_SIZE and sy < MAP_SIZE:
				if map[sy * MAP_SIZE + sx] == TILE_VOID:
					_dung_set(map, sx, sy, TILE_FLOOR)
	# Ensure corridor from start zone to nearest room
	if rooms.size() > 0:
		var nearest_to_start: Array = rooms[0]
		var nearest_to_end: Array = rooms[rooms.size() - 1]
		_carve_corridor_bent(map, 2, 2,
			(int(nearest_to_start[0]) + int(nearest_to_start[2])) / 2,
			(int(nearest_to_start[1]) + int(nearest_to_start[3])) / 2,
			rng, corridor_width)
		_carve_corridor_bent(map, 21, 21,
			(int(nearest_to_end[0]) + int(nearest_to_end[2])) / 2,
			(int(nearest_to_end[1]) + int(nearest_to_end[3])) / 2,
			rng, corridor_width)

	# ── Scatter obstacles on ~10-15% of floor tiles ──────────────────────────
	var obs_chance: float = rng.randf_range(0.08, 0.15)
	for idx in range(map.size()):
		if map[idx] == TILE_FLOOR and rng.randf() < obs_chance:
			var ox: int = idx % MAP_SIZE
			var oy: int = idx / MAP_SIZE
			# Don't block spawn zones
			if (ox >= 1 and ox <= 6 and oy >= 1 and oy <= 6): continue
			if (ox >= 18 and ox <= 23 and oy >= 18 and oy <= 23): continue
			map[idx] = TILE_OBSTACLE

	# ── Elevation features (procedural) ──────────────────────────────────────
	if rooms.size() >= 3:
		# Platform in a random interior room
		var plat_idx: int = rng.randi_range(1, rooms.size() - 2)
		var plat_room: Array = rooms[plat_idx]
		for ety in range(int(plat_room[1]) + 1, int(plat_room[3])):
			for etx in range(int(plat_room[0]) + 1, int(plat_room[2])):
				var pidx: int = ety * MAP_SIZE + etx
				if pidx < _dungeon_elevation.size() and map[pidx] == TILE_FLOOR:
					_dungeon_elevation[pidx] = 2
		# Pit in another random room
		var pit_idx: int = rng.randi_range(0, rooms.size() - 1)
		if pit_idx == plat_idx: pit_idx = (pit_idx + 1) % rooms.size()
		var pit_room: Array = rooms[pit_idx]
		for ety2 in range(int(pit_room[1]) + 1, mini(int(pit_room[1]) + 3, int(pit_room[3]))):
			for etx2 in range(int(pit_room[0]) + 1, mini(int(pit_room[0]) + 3, int(pit_room[2]))):
				var pidx2: int = ety2 * MAP_SIZE + etx2
				if pidx2 < _dungeon_elevation.size() and map[pidx2] == TILE_FLOOR:
					_dungeon_elevation[pidx2] = 0

	return map

## Carve a rough circle into the map (for cavern/arena layouts).
func _carve_circle(map: PackedInt32Array, center_x: int, center_y: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				_dung_set(map, center_x + dx, center_y + dy, TILE_FLOOR)

# ── Loot ──────────────────────────────────────────────────────────────────────
func collect_loot(player_handle: int) -> PackedStringArray:
	# Award XP scaled by round and enemy level
	var eff_level: int = maxi(1, _dungeon_enemy_level)
	var xp: int = 15 + _dungeon_round * 2
	# Count defeated combat creatures for extra gold
	var kill_bonus: int = 0
	for h in _combat_creatures:
		if bool(_combat_creatures[h].get("is_dead", false)):
			kill_bonus += eff_level
	var gold_amount: int = randi_range(3, 10) * eff_level + kill_bonus
	var items: PackedStringArray = PackedStringArray([
		"Gold Coin x%d" % gold_amount,
		"Health Potion",
	])
	# Bonus drop from combat creatures
	const BONUS_DROPS: Array = ["Iron Shard", "Leather Scrap", "Rough Gem", "Bone Fragment"]
	for h in _combat_creatures:
		if bool(_combat_creatures[h].get("is_dead", false)):
			items.append(BONUS_DROPS[randi() % BONUS_DROPS.size()])
	# Award XP to all active characters
	for h in GameState.get_active_handles():
		if _chars.has(h): add_xp(h, xp, 20)
	return items

# ── Base building (stubs) ─────────────────────────────────────────────────────
func create_base(name: String, tier: int) -> int:
	return -1

func get_base_name(handle: int) -> String:
	return ""

func get_base_tier(handle: int) -> int:
	return 0

func get_base_stats(handle: int) -> PackedInt32Array:
	return PackedInt32Array()

func get_base_max_facilities(handle: int) -> int:
	return 0

func get_base_facilities(handle: int) -> PackedStringArray:
	return PackedStringArray()

func add_facility_to_base(handle: int, type: int) -> bool:
	return false

func get_base_defense_modifier(handle: int) -> int:
	return 0

func destroy_base(handle: int) -> void:
	pass

# ── Dungeon variant starters ──────────────────────────────────────────────────

## Kaiju boss stat blocks: [name, hp, ac, ap, speed, lv, weapon, desc]
const KAIJU_STATS: Array = [
	["Skarn the Worldbreaker",  280, 19, 15, 3, 13, "Crushing Claw",   "Titanic stone golem. Shakes the earth."],
	["Gorveth Deep-Drinker",    260, 17, 14, 4, 12, "Tentacle Slam",   "Ocean leviathan. Corrodes armor."],
	["Thornspire",              300, 20, 12, 2, 14, "Spine Barrage",   "Ancient rootspawn behemoth."],
	["Ignarath",                240, 18, 16, 5, 12, "Magma Strike",    "Volcanic lava titan."],
	["Vex the Hollow",          270, 15, 18, 6, 13, "Void Smash",      "Planar anomaly of pure hunger."],
	["Aegis Ultima",            350, 22, 20, 3, 13, "Arcane Cannon",   "Arcane construct / lawbringer mecha."],
]

## Apex boss stat blocks: [name, title, hp, ac, ap, sp, speed, lv, weapon]
const APEX_STATS: Array = [
	["Varnok",       "the Moonbound Tyrant",         180, 16, 12, 4, 5, 11, "Feral Maw"],
	["Lady Nyssara", "the Crimson Countess",          160, 17, 14, 8, 4, 12, "Blood Lance"],
	["Malgrin",      "the Bound",                    200, 18, 10, 10,3, 13, "Frost Lash"],
	["Sithra",       "the Venom-Touched Hatchling",   60, 12, 16, 2, 8,  1, "Venom Bite"],
	["Korrak",       "the Bonehowl Ravager",          90, 14, 14, 0, 6,  3, "Bone Cleaver"],
	["Veltraxis",    "the Emberborn Duelist",        120, 15, 15, 6, 7,  5, "Flame Rapier"],
	["Xal'Thuun",    "the Dreaming Maw",             400, 20, 20, 20,4, 20, "Reality Tear"],
	["Braxis",       "the Ironjaw",                  110, 17, 12, 0, 5,  4, "Iron Gauntlet"],
	["Seraphex",     "the Shattered Angel",          140, 16, 14, 8, 6,  7, "Blessed Blade"],
	["Kor'zan",      "the Plague Harbinger",          95, 13, 12, 6, 5,  5, "Pestilence Rod"],
	["Nex",          "the Silent",                   130, 18, 18, 0, 9,  8, "Shadow Blade"],
	["Thornveil",    "the Rootborn",                 170, 15, 10, 4, 3,  9, "Barbed Vine"],
	["Astridax",     "the Void Serpent",             155, 14, 14, 8, 7,  8, "Void Fang"],
	["Ember Ryn",    "the Molten Dancer",            125, 14, 16, 6, 8,  7, "Lava Whip"],
	["Galvorn",      "the Thunder-Crowned",          145, 15, 14, 4, 6,  8, "Storm Maul"],
	["Phaedrix",     "the Dream Weaver",             160, 13, 12, 12,4,  9, "Mind Shard"],
	["Krenox",       "the Forsaken",                 175, 16, 12, 0, 5, 10, "Cursed Blade"],
	["Solvara",      "the Tide Singer",              150, 14, 14, 10,6,  9, "Tidal Staff"],
	["Zareth",       "the Ashwalker",                135, 15, 14, 2, 7,  8, "Cinder Spear"],
	["Morwen",       "the Shadeborn Queen",          165, 17, 14, 6, 5, 10, "Nightshade Bow"],
	["Xeron Prime",  "the Convergence",              190, 17, 16, 8, 6, 11, "Prismatic Ray"],
]

## Militia group configs: [name, size, level, ac, weapon, ability]
const MILITIA_STATS: Array = [
	["Ironroot Guard",    10, 5, 19, "Spear",      "Shield Wall"],
	["Emberveil Recon",    5, 4, 14, "Shortbow",   "Ambush Tactics"],
	["Crimson Crusaders", 10, 6, 18, "Longsword",  "Battle Chant"],
	["Shadow Blades",      5, 5, 16, "Dagger",     "Vanish"],
	["Bone Wardens",       8, 4, 15, "Axe",        "Undead Frenzy"],
	["Void Warband",      10, 6, 14, "Void Blade", "Void-Touched Frenzy"],
	["Storm Riders",      10, 5, 14, "Lance",      "Skirmisher"],
	["Sacred Vigil",      10, 5, 18, "Mace",       "Divine Zeal"],
]

func start_kaiju_dungeon(player_handles, kaiju_idx: int, terrain_style: int) -> void:
	# Starts like a standard dungeon but then replaces enemies with a single kaiju boss
	start_dungeon(player_handles, 1, -1, terrain_style)
	_dungeon_type = 1
	_dungeon_entities = _dungeon_entities.filter(func(e): return bool(e["is_player"]))

	var idx: int = clamp(kaiju_idx, 0, KAIJU_STATS.size() - 1)
	var ks: Array = KAIJU_STATS[idx]
	var boss_hp: int = int(ks[1])
	_dungeon_encounter_name = "Kaiju Hunt: %s" % str(ks[0])
	_dungeon_enemy_level    = int(ks[5])
	_dungeon_entities.append({
		"id":             "enemy_0",
		"name":           str(ks[0]),
		"handle":         -1,
		"lineage_name":   "Kaiju",
		"x": 21, "y": 21, "z": 0,
		"is_player":   false,
		"is_friendly": false,
		"is_dead":     false,
		"is_flying":   false,
		"hp":    boss_hp, "max_hp": boss_hp,
		"ap":    int(ks[3]),  "max_ap": int(ks[3]),
		"sp":    0,           "max_sp": 0,
		"ac":    int(ks[2]),
		"speed": int(ks[4]),
		"ap_spent":  0, "move_used": 0,
		"equipped_weapon": str(ks[6]),
		"equipped_armor":  "None",
		"equipped_shield": "None",
		"equipped_light":  "None",
		"conditions":  [],
		"inventory":   _generate_creature_loot(_dungeon_enemy_level + 4),
		"looted":      false,
		"is_boss":     true,
		"boss_desc":   str(ks[7]),
	})
	_update_fog()

func start_apex_dungeon(player_handles, apex_idx: int, terrain_style: int) -> void:
	start_dungeon(player_handles, 1, -1, terrain_style)
	_dungeon_type = 2
	_dungeon_entities = _dungeon_entities.filter(func(e): return bool(e["is_player"]))

	var idx: int = clamp(apex_idx, 0, APEX_STATS.size() - 1)
	var as_: Array = APEX_STATS[idx]
	var boss_hp: int = int(as_[2])
	_dungeon_encounter_name = "Apex: %s %s" % [str(as_[0]), str(as_[1])]
	_dungeon_enemy_level    = int(as_[7])
	_dungeon_entities.append({
		"id":             "enemy_0",
		"name":           "%s %s" % [str(as_[0]), str(as_[1])],
		"handle":         -1,
		"lineage_name":   "Apex",
		"x": 21, "y": 21, "z": 0,
		"is_player":   false,
		"is_friendly": false,
		"is_dead":     false,
		"is_flying":   false,
		"hp":    boss_hp,    "max_hp": boss_hp,
		"ap":    int(as_[4]),  "max_ap": int(as_[4]),
		"sp":    int(as_[5]),  "max_sp": int(as_[5]),
		"ac":    int(as_[3]),
		"speed": int(as_[6]),
		"ap_spent":  0, "move_used": 0,
		"equipped_weapon": str(as_[8]),
		"equipped_armor":  "None",
		"equipped_shield": "None",
		"equipped_light":  "None",
		"conditions":  [],
		"inventory":   _generate_creature_loot(_dungeon_enemy_level + 2),
		"looted":      false,
		"is_boss":     true,
	})
	_update_fog()

func start_militia_dungeon(player_handles, militia_idx: int, terrain_style: int) -> void:
	start_dungeon(player_handles, 1, -1, terrain_style)
	_dungeon_type = 3
	_dungeon_entities = _dungeon_entities.filter(func(e): return bool(e["is_player"]))

	var idx: int = clamp(militia_idx, 0, MILITIA_STATS.size() - 1)
	var ms: Array = MILITIA_STATS[idx]
	var squad_size: int = int(ms[1])
	var mlv: int        = int(ms[2])
	var mac: int        = int(ms[3])
	_dungeon_encounter_name = "Militia: %s" % str(ms[0])
	_dungeon_enemy_level    = mlv

	var e_spawns: Array = [
		[20,20],[21,20],[20,21],[19,20],[20,19],[22,21],
		[21,19],[19,21],[22,20],[20,22],[18,20],[20,18]
	]
	var ehp: int = 6 + mlv * 3
	for i in range(mini(squad_size, e_spawns.size())):
		var pos: Array = e_spawns[i]
		_dungeon_entities.append({
			"id":             "enemy_%d" % i,
			"name":           "%s #%d" % [str(ms[0]), i + 1],
			"handle":         -1,
			"lineage_name":   "Militia",
			"x": pos[0], "y": pos[1], "z": 0,
			"is_player":   false,
			"is_friendly": false,
			"is_dead":     false,
			"is_flying":   false,
			"hp":    ehp,  "max_hp": ehp,
			"ap":    10,   "max_ap": 10,
			"sp":    0,    "max_sp": 0,
			"ac":    mac,
			"speed": 5,
			"ap_spent":  0, "move_used": 0,
			"equipped_weapon": str(ms[4]),
			"equipped_armor":  "None",
			"equipped_shield": "None",
			"equipped_light":  "None",
			"conditions":  [],
			"inventory":   _generate_creature_loot(mlv),
			"looted":      false,
		})
	_update_fog()

func start_mob_dungeon(player_handles, mob_count: int, mob_level: int, terrain_style: int) -> void:
	start_dungeon(player_handles, 1, -1, terrain_style)
	_dungeon_type = 4
	_dungeon_entities = _dungeon_entities.filter(func(e): return bool(e["is_player"]))

	_dungeon_encounter_name = "Mob Encounter (%d)" % mob_count
	_dungeon_enemy_level    = maxi(1, mob_level)

	var mob_names: Array = ["Kobold", "Goblin", "Skeleton", "Zombie", "Cultist",
		"Bandit", "Imp", "Ghoul", "Ratfolk", "Cave Troll"]
	var mob_name: String = mob_names[mob_level % mob_names.size()]

	# Scatter up to min(mob_count, 24) across the map (avoid spawn room)
	var available_tiles: Array = []
	for x in range(10, 24):
		for y in range(10, 24):
			var tidx: int = x * MAP_SIZE + y
			if tidx < _dungeon_map.size() and _dungeon_map[tidx] == TILE_FLOOR:
				available_tiles.append([x, y])
	available_tiles.shuffle()

	var actual_count: int = mini(mob_count, available_tiles.size())
	var ehp: int = 3 + mob_level * 2
	for i in range(actual_count):
		var pos: Array = available_tiles[i]
		_dungeon_entities.append({
			"id":             "enemy_%d" % i,
			"name":           mob_name,
			"handle":         -1,
			"lineage_name":   "Enemy",
			"x": pos[0], "y": pos[1], "z": 0,
			"is_player":   false,
			"is_friendly": false,
			"is_dead":     false,
			"is_flying":   false,
			"hp":    ehp,  "max_hp": ehp,
			"ap":    6,    "max_ap": 6,
			"sp":    0,    "max_sp": 0,
			"ac":    8 + mob_level,
			"speed": 4,
			"ap_spent":  0, "move_used": 0,
			"equipped_weapon": "Rusty Dagger",
			"equipped_armor":  "None",
			"equipped_shield": "None",
			"equipped_light":  "None",
			"conditions":  [],
			"inventory":   _generate_creature_loot(mob_level),
			"looted":      false,
		})
	_update_fog()

func start_custom_monster_dungeon(player_handles, custom_monster: Dictionary, terrain_style: int) -> void:
	start_dungeon(player_handles, 1, -1, terrain_style)
	_dungeon_type = 5  # Custom Monster
	_dungeon_entities = _dungeon_entities.filter(func(e): return bool(e["is_player"]))

	var level: int = int(custom_monster.get("level", 1))
	var is_apex: bool = bool(custom_monster.get("apex", false))
	var name_str: String = str(custom_monster.get("name", "Custom Monster"))
	var stats: Dictionary = custom_monster.get("stats", {"STR": 1, "SPD": 1, "INT": 1, "VIT": 1, "DIV": 1})

	# Calculate derived stats based on monster creation rules
	var str_val: int = int(stats.get("STR", 1))
	var spd_val: int = int(stats.get("SPD", 1))
	var int_val: int = int(stats.get("INT", 1))
	var vit_val: int = int(stats.get("VIT", 1))
	var div_val: int = int(stats.get("DIV", 1))

	var hp: int
	var ap: int
	var sp: int
	var ac: int = 10

	if is_apex:
		hp = 5 * level + vit_val
		ap = 10 + str_val
		sp = 10 + level + div_val
	else:
		hp = 3 * level + vit_val
		ap = 3 + str_val
		sp = 3 + level + div_val

	_dungeon_encounter_name = "Custom Monster: %s" % name_str
	_dungeon_enemy_level = level

	# Find a valid floor tile far from players
	var occupied: Dictionary = {}
	for e in _dungeon_entities:
		occupied[Vector2i(int(e["x"]), int(e["y"]))] = true
	var best_pos: Array = [12, 12]
	var best_dist: int = 0
	for fy in range(MAP_SIZE):
		for fx in range(MAP_SIZE):
			if _dungeon_map[fy * MAP_SIZE + fx] == 0:  # floor
				if occupied.has(Vector2i(fx, fy)):
					continue
				var min_pd: int = 999
				for e in _dungeon_entities:
					var dx: int = abs(fx - int(e["x"]))
					var dy: int = abs(fy - int(e["y"]))
					min_pd = mini(min_pd, maxi(dx, dy))
				if min_pd > best_dist:
					best_dist = min_pd
					best_pos = [fx, fy]

	_dungeon_entities.append({
		"id":             "enemy_0",
		"name":           name_str,
		"handle":         -1,
		"lineage_name":   "Custom",
		"x": best_pos[0], "y": best_pos[1], "z": 0,
		"is_player":   false,
		"is_friendly": false,
		"is_dead":     false,
		"is_flying":   false,
		"hp":    hp,    "max_hp": hp,
		"ap":    ap,    "max_ap": ap,
		"sp":    sp,    "max_sp": sp,
		"ac":    ac,
		"speed": 5 + spd_val,
		"ap_spent":  0, "actions_taken": 0, "move_used": 0,
		"equipped_weapon": "Claw",
		"equipped_armor":  "None",
		"equipped_shield": "None",
		"equipped_light":  "None",
		"conditions":  [],
		"inventory":   _generate_creature_loot(level),
		"looted":      false,
		"is_boss":     is_apex,
	})
	_update_fog()
