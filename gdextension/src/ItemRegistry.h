#ifndef RIMVALE_ITEM_REGISTRY_H
#define RIMVALE_ITEM_REGISTRY_H

#include "Weapon.h"
#include "Armor.h"
#include "Item.h"
#include "Character.h"
#include <map>
#include <memory>
#include <vector>
#include <string>

namespace rimvale {

class ItemRegistry {
public:
    static ItemRegistry& instance() {
        static ItemRegistry registry;
        return registry;
    }

    [[nodiscard]] std::unique_ptr<Weapon> create_weapon(const std::string& name) const {
        auto it = weapon_templates_.find(name);
        return (it != weapon_templates_.end()) ? std::make_unique<Weapon>(it->second) : nullptr;
    }

    [[nodiscard]] std::unique_ptr<Armor> create_armor(const std::string& name) const {
        auto it = armor_templates_.find(name);
        return (it != armor_templates_.end()) ? std::make_unique<Armor>(it->second) : nullptr;
    }

    [[nodiscard]] std::unique_ptr<Item> create_general_item(const std::string& name) const {
        auto it = item_templates_.find(name);
        if (it != item_templates_.end()) return std::make_unique<Item>(it->second);

        auto it_c = consumable_templates_.find(name);
        if (it_c != consumable_templates_.end()) return std::make_unique<Consumable>(it_c->second);

        return nullptr;
    }

    [[nodiscard]] std::unique_ptr<Item> create_any_item(const std::string& name) const {
        auto w = create_weapon(name);
        if (w) return w;
        auto a = create_armor(name);
        if (a) return a;
        return create_general_item(name);
    }

    [[nodiscard]] std::vector<std::string> get_all_weapon_names() const {
        std::vector<std::string> names;
        for (const auto& pair : weapon_templates_) names.push_back(pair.first);
        return names;
    }

    [[nodiscard]] std::vector<std::string> get_all_armor_names() const {
        std::vector<std::string> names;
        for (const auto& pair : armor_templates_) names.push_back(pair.first);
        return names;
    }

    [[nodiscard]] std::vector<std::string> get_all_general_item_names() const {
        std::vector<std::string> names;
        for (const auto& pair : item_templates_) names.push_back(pair.first);
        for (const auto& pair : consumable_templates_) names.push_back(pair.first);
        return names;
    }

    [[nodiscard]] std::vector<std::string> get_all_magic_item_names() const {
        std::vector<std::string> names;
        for (const auto& pair : weapon_templates_) if (pair.second.is_magical()) names.push_back(pair.first);
        for (const auto& pair : armor_templates_) if (pair.second.is_magical()) names.push_back(pair.first);
        for (const auto& pair : item_templates_) if (pair.second.is_magical()) names.push_back(pair.first);
        for (const auto& pair : consumable_templates_) if (pair.second.is_magical()) names.push_back(pair.first);
        return names;
    }

private:
    ItemRegistry() {
        // --- Consumables: Healing ---
        register_consumable({"Potion of Healing", 50, [](Character* c) {
            c->heal(10);
            return "Regained 10 HP.";
        }, Rarity::Common, "A vial of glowing red liquid that restores 10 hit points."});

        register_consumable({"Lesser Potion of Healing", 25, [](Character* c) {
            c->heal(5);
            return "Regained 5 HP.";
        }, Rarity::Common, "A small vial of red liquid that restores 5 hit points."});

        register_consumable({"Potion of Revive", 150, [](Character* c) {
            if (c->current_hp_ <= 0) {
                c->current_hp_ = 5;
                return "Agent has been revived with 5 HP.";
            }
            c->heal(5);
            return "Agent was already alive. Regained 5 HP.";
        }, Rarity::Uncommon, "A powerful alchemical mixture that revives an agent at 0 HP to 5 HP."});

        // --- Consumables: SP/AP Restoration ---
        register_consumable({"Ether Flask", 60, [](Character* c) {
            c->restore_sp(5);
            return "Restored 5 SP.";
        }, Rarity::Common, "A shimmering blue mist in a bottle that restores 5 Soul Points."});

        register_consumable({"Adrenaline Shot", 40, [](Character* c) {
            c->restore_ap(3);
            return "Restored 3 AP.";
        }, Rarity::Common, "A chemical stimulant that restores 3 Action Points."});

        // --- Consumables: Buffs ---
        register_consumable({"Ironroot Draught", 100, [](Character* c) {
            c->add_dodge_bonus();
            return "Increased defense slightly.";
        }, Rarity::Uncommon, "A thick, earthy brew that hardens the skin, providing a temporary dodge bonus."});

        // --- SIMPLE MELEE WEAPONS ---
        register_weapon({"Chakram", 15, 5, "1d6", DamageType::Slashing, WeaponCategory::Simple, {"Light", "Finesse", "Thrown (30/90)"}, "Bounce", Rarity::Mundane, "A circular throwing blade used by scouts."});
        register_weapon({"Club", 10, 1, "1d4", DamageType::Bludgeoning, WeaponCategory::Simple, {"Light", "Finesse"}, "Slow", Rarity::Mundane, "A simple wooden cudgel."});
        register_weapon({"Dagger", 10, 2, "1d4", DamageType::Piercing, WeaponCategory::Simple, {"Finesse", "Light", "Thrown (20/60)"}, "Nick", Rarity::Mundane, "A standard tactical knife."});
        register_weapon({"Greatclub", 20, 2, "1d8", DamageType::Bludgeoning, WeaponCategory::Simple, {"Two-Handed"}, "Push", Rarity::Mundane, "A massive wooden log used for smashing."});
        register_weapon({"Handaxe", 15, 5, "1d6", DamageType::Slashing, WeaponCategory::Simple, {"Light", "Thrown (20/60)", "Finesse"}, "Vex", Rarity::Mundane, "A small, balanced axe."});
        register_weapon({"Javelin", 20, 5, "1d6", DamageType::Piercing, WeaponCategory::Simple, {"Thrown (30/120)", "Finesse"}, "Slow", Rarity::Mundane, "A light spear designed for throwing."});
        register_weapon({"Light Hammer", 15, 2, "1d4", DamageType::Bludgeoning, WeaponCategory::Simple, {"Light", "Thrown (20/60)", "Finesse"}, "Nick", Rarity::Mundane, "A small smith's hammer repurposed for combat."});
        register_weapon({"Mace", 20, 5, "1d6", DamageType::Bludgeoning, WeaponCategory::Simple, {"Finesse"}, "Sap", Rarity::Mundane, "A heavy iron-headed club."});
        register_weapon({"Quarterstaff", 20, 2, "1d6", DamageType::Bludgeoning, WeaponCategory::Simple, {"Versatile (1d8)", "Finesse"}, "Topple", Rarity::Mundane, "A long wooden staff."});
        register_weapon({"Sickle", 15, 1, "1d4", DamageType::Slashing, WeaponCategory::Simple, {"Light", "Finesse"}, "Nick", Rarity::Mundane, "A curved farm tool used as a weapon."});
        register_weapon({"Spear", 20, 1, "1d6", DamageType::Piercing, WeaponCategory::Simple, {"Thrown (20/60)", "Versatile (1d8)", "Finesse"}, "Sap", Rarity::Mundane, "A simple wooden pole with a sharp metal point."});
        register_weapon({"Shortsword", 15, 10, "1d6", DamageType::Piercing, WeaponCategory::Simple, {"Finesse", "Light"}, "Vex", Rarity::Mundane, "A versatile short-range blade."});

        // --- SIMPLE RANGED WEAPONS ---
        register_weapon({"Dart", 10, 1, "1d4", DamageType::Piercing, WeaponCategory::Simple, {"Finesse", "Thrown (20/60)"}, "Vex", Rarity::Mundane, "Small throwing spikes."});
        register_weapon({"Light Crossbow", 10, 25, "1d8", DamageType::Piercing, WeaponCategory::Simple, {"Range (80/320)", "Two-Handed"}, "Slow", Rarity::Mundane, "A compact mechanical bow."});
        register_weapon({"Shortbow", 15, 25, "1d6", DamageType::Piercing, WeaponCategory::Simple, {"Range (80/320)", "Two-Handed"}, "Vex", Rarity::Mundane, "A small, lightweight bow."});
        register_weapon({"Sling", 10, 1, "1d4", DamageType::Bludgeoning, WeaponCategory::Simple, {"Range (30/120)"}, "Slow", Rarity::Mundane, "A leather strap for throwing stones."});

        // --- MARTIAL MELEE WEAPONS ---
        register_weapon({"Battleaxe", 25, 10, "1d8", DamageType::Slashing, WeaponCategory::Martial, {"Versatile (1d10)"}, "Topple", Rarity::Mundane, "A heavy axe designed for warfare."});
        register_weapon({"Flail", 25, 10, "1d8", DamageType::Bludgeoning, WeaponCategory::Martial, {}, "Sap", Rarity::Mundane, "A spiked ball on a chain."});
        register_weapon({"Glaive", 30, 20, "2d6", DamageType::Slashing, WeaponCategory::Martial, {"Heavy", "Reach", "Two-Handed"}, "Graze", Rarity::Mundane, "A polearm with a large blade."});
        register_weapon({"Greataxe", 30, 30, "1d12", DamageType::Slashing, WeaponCategory::Martial, {"Heavy", "Two-Handed"}, "Cleave", Rarity::Mundane, "A massive two-handed axe."});
        register_weapon({"Greatsword", 30, 50, "2d6", DamageType::Slashing, WeaponCategory::Martial, {"Heavy", "Two-Handed"}, "Graze", Rarity::Mundane, "A massive two-handed sword."});
        register_weapon({"Halberd", 30, 20, "1d10", DamageType::Slashing, WeaponCategory::Martial, {"Heavy", "Reach", "Two-Handed"}, "Cleave", Rarity::Mundane, "A polearm combining an axe and a spear."});
        register_weapon({"Katana", 25, 15, "1d8", DamageType::Slashing, WeaponCategory::Martial, {"Versatile (1d10)"}, "Cleave", Rarity::Mundane, "A curved, single-edged blade from distant lands."});
        register_weapon({"Lance", 30, 10, "1d12", DamageType::Piercing, WeaponCategory::Martial, {"Heavy", "Reach", "Two-Handed (unless mounted)"}, "Topple", Rarity::Mundane, "A long cavalry spear."});
        register_weapon({"Longsword", 20, 15, "1d8", DamageType::Slashing, WeaponCategory::Martial, {"Versatile (1d10)"}, "Sap", Rarity::Mundane, "A classic military blade."});
        register_weapon({"Maul", 30, 10, "2d6", DamageType::Bludgeoning, WeaponCategory::Martial, {"Heavy", "Two-Handed"}, "Topple", Rarity::Mundane, "A massive two-handed hammer."});
        register_weapon({"Morningstar", 25, 15, "1d8", DamageType::Piercing, WeaponCategory::Martial, {"Versatile (1d10)"}, "Sap", Rarity::Mundane, "A spiked mace."});
        register_weapon({"Pike", 30, 5, "1d10", DamageType::Piercing, WeaponCategory::Martial, {"Heavy", "Reach", "Two-Handed"}, "Push", Rarity::Mundane, "A very long spear used in formations."});
        register_weapon({"Rapier", 25, 25, "1d8", DamageType::Piercing, WeaponCategory::Martial, {"Finesse"}, "Vex", Rarity::Mundane, "A thin, elegant dueling blade."});
        register_weapon({"Scimitar", 20, 25, "1d6", DamageType::Slashing, WeaponCategory::Martial, {"Finesse", "Light"}, "Nick", Rarity::Mundane, "A curved blade designed for quick slashes."});
        register_weapon({"Trident", 25, 5, "1d8", DamageType::Piercing, WeaponCategory::Martial, {"Thrown (20/60)", "Versatile (1d10)", "Finesse"}, "Topple", Rarity::Mundane, "A three-pronged spear."});
        register_weapon({"Warhammer", 20, 15, "1d8", DamageType::Bludgeoning, WeaponCategory::Martial, {"Versatile (1d10)"}, "Push", Rarity::Mundane, "A heavy hammer built for crushing armor."});
        register_weapon({"War Pick", 20, 5, "1d8", DamageType::Piercing, WeaponCategory::Martial, {"Versatile (1d10)"}, "Sap", Rarity::Mundane, "A sharp, armor-piercing pick."});
        register_weapon({"Whip", 15, 2, "1d4", DamageType::Slashing, WeaponCategory::Martial, {"Finesse", "Reach"}, "Slow", Rarity::Mundane, "A long, flexible lash."});

        // --- MARTIAL RANGED WEAPONS ---
        register_weapon({"Blowgun", 10, 10, "1d4", DamageType::Piercing, WeaponCategory::Martial, {"Range (25/100)"}, "Vex", Rarity::Mundane, "A tube for firing small darts."});
        register_weapon({"Hand Crossbow", 15, 75, "1d6", DamageType::Piercing, WeaponCategory::Martial, {"Range (30/120)", "Light"}, "Vex", Rarity::Mundane, "A one-handed mechanical bow."});
        register_weapon({"Heavy Crossbow", 30, 50, "1d10", DamageType::Piercing, WeaponCategory::Martial, {"Range (100/400)", "Heavy", "Two-Handed"}, "Push", Rarity::Mundane, "A powerful mechanical bow."});
        register_weapon({"Longbow", 25, 50, "1d8", DamageType::Piercing, WeaponCategory::Martial, {"Range (150/600)", "Heavy", "Two-Handed"}, "Slow", Rarity::Mundane, "A tall bow with exceptional range."});
        register_weapon({"Heavy Sling", 20, 10, "1d10", DamageType::Bludgeoning, WeaponCategory::Martial, {"Range (100/400)"}, "Push", Rarity::Mundane, "A military-grade sling."});
        register_weapon({"Musket", 30, 500, "1d12", DamageType::Piercing, WeaponCategory::Martial, {"Range (40/120)", "Two-Handed"}, "Slow", Rarity::Mundane, "A black powder longarm."});
        register_weapon({"Pistol", 25, 250, "1d10", DamageType::Piercing, WeaponCategory::Martial, {"Range (30/90)"}, "Vex", Rarity::Mundane, "A black powder handgun."});

        // --- ARMOR ---
        register_armor({"Padded", 20, 5, 11, 0, true, ArmorCategory::Light, Rarity::Mundane, "Quilted layers of cloth."});
        register_armor({"Leather", 20, 10, 11, 0, false, ArmorCategory::Light, Rarity::Mundane, "Tough, cured animal hide."});
        register_armor({"Studded Leather", 20, 45, 12, 0, false, ArmorCategory::Light, Rarity::Mundane, "Leather reinforced with metal studs."});
        register_armor({"Hide", 20, 10, 12, 0, false, ArmorCategory::Medium, Rarity::Mundane, "Rough, thick animal skins."});
        register_armor({"Chain Shirt", 20, 50, 13, 0, false, ArmorCategory::Medium, Rarity::Mundane, "A shirt of interlocking metal rings."});
        register_armor({"Scale Mail", 30, 50, 14, 0, true, ArmorCategory::Medium, Rarity::Mundane, "Metal scales sewn onto a leather backing."});
        register_armor({"Breastplate", 40, 400, 14, 0, false, ArmorCategory::Medium, Rarity::Mundane, "A fitted metal plate for the torso."});
        register_armor({"Half Plate", 50, 750, 15, 0, true, ArmorCategory::Medium, Rarity::Mundane, "Plate armor covering most of the body."});
        register_armor({"Ring Mail", 30, 30, 14, 0, true, ArmorCategory::Heavy, Rarity::Mundane, "Leather with heavy rings sewn into it."});
        register_armor({"Chain Mail", 40, 75, 16, 2, true, ArmorCategory::Heavy, Rarity::Mundane, "A full suit of interlocking metal rings."});
        register_armor({"Splint", 50, 200, 17, 3, true, ArmorCategory::Heavy, Rarity::Mundane, "Metal strips on leather with chainmail joints."});
        register_armor({"Plate", 60, 1500, 18, 3, true, ArmorCategory::Heavy, Rarity::Mundane, "Complete suit of articulated metal plates."});
        register_armor({"Standard Shield", 20, 10, 2, 0, false, ArmorCategory::Shield, Rarity::Mundane, "A reliable wooden or metal shield."});
        register_armor({"Tower Shield", 40, 100, 3, 3, true, ArmorCategory::TowerShield, Rarity::Mundane, "A massive shield that covers the entire body."});

        // --- COMMON MAGIC ITEMS ---
        register_item({"Amberglow Pendant", 10, 50, Rarity::Common, "A pendant that emits a warm, soothing light."});
        register_item({"Amulet of Comfort +1", 10, 50, Rarity::Common, "An amulet that regulates the wearer's temperature."});
        register_item({"Aether-Touched Lens", 10, 50, Rarity::Common, "A glass lens that reveals faint magical signatures."});
        register_item({"Anvilstone", 10, 50, Rarity::Common, "A small stone that sharpens blades effortlessly."});
        register_item({"Arcane Stitching Kit", 10, 50, Rarity::Common, "Self-threading needles that repair fabric with light."});
        register_item({"Ashcloak Thread", 10, 50, Rarity::Common, "Thread that makes garments resistant to minor burns."});
        register_item({"Babelstone Charm", 10, 50, Rarity::Common, "A charm that helps understand basic phrases in common dialects."});
        register_item({"Binding Nail", 10, 50, Rarity::Common, "A nail that, once hammered, cannot be removed except by its owner."});
        register_item({"Candle of Clarity", 10, 50, Rarity::Common, "A candle whose smoke sharpens the mind slightly."});
        register_item({"Candle of Echoes", 10, 50, Rarity::Common, "A candle that plays back the last sound it 'heard' when lit."});
        register_item({"Cleansing Stone", 10, 50, Rarity::Common, "A smooth stone that removes dirt and grime on contact."});
        register_item({"Cradleleaf Poultice", 10, 50, Rarity::Common, "A medicinal leaf that speeds up natural recovery during rest."});
        register_item({"Dagger of the Last Word", 10, 50, Rarity::Common, "A dagger that always hits a target that is already below 5 HP."});
        register_item({"Dowsing Rod", 10, 50, Rarity::Common, "A forked stick that twitches when near fresh water."});
        register_item({"Dustveil Cloak", 10, 50, Rarity::Common, "A cloak that seems to blend into dusty environments."});
        register_item({"Echoing Rift Stone", 10, 50, Rarity::Common, "A stone that can record and replay 5 seconds of sound."});
        register_item({"Flickerflame Matchbox", 10, 50, Rarity::Common, "A box that creates a tiny, harmless magical flame."});
        register_item({"Forager's Pouch", 10, 50, Rarity::Common, "A pouch that slightly increases the quality of found food."});
        register_item({"Glass of Truth", 10, 50, Rarity::Common, "A monocle that reveals if a liquid is poisonous."});
        register_item({"Glass of Revelation", 10, 50, Rarity::Common, "Reveals hidden runes."});
        register_item({"Glowroot Bandage", 10, 50, Rarity::Common, "A bandage that glows faintly, providing light while healing."});
        register_item({"Mender's Thread", 10, 50, Rarity::Common, "Magical thread that mends small tears in clothing instantly."});
        register_item({"Messenger Feather", 10, 50, Rarity::Common, "A feather that can deliver written notes to a nearby person."});
        register_item({"Mothwing Brooch", 10, 50, Rarity::Common, "A brooch that slows fall speed very slightly."});
        register_item({"Needle of Silence", 10, 50, Rarity::Common, "A needle used to sew lips shut magically (temporary)."});
        register_item({"Pebble of Echoes", 10, 50, Rarity::Common, "A stone that repeats the user's whisper after a delay."});
        register_item({"Scribe's Quill", 10, 50, Rarity::Common, "A quill that never runs out of ink."});
        register_item({"Shadow Sovereign's Coin", 10, 50, Rarity::Common, "A coin that always lands on the side the owner chooses."});
        register_item({"Scent Masker", 10, 50, Rarity::Common, "A small vial that neutralizes the wearer's scent."});
        register_item({"Silent Bell", 10, 50, Rarity::Common, "A bell that makes no sound when rung, except in the user's mind."});
        register_item({"Smoke Puff", 10, 50, Rarity::Common, "A small ball that creates a 5ft cloud of obscuring smoke."});
        register_item({"Traveler's Chalice", 10, 50, Rarity::Common, "A cup that purifies any water poured into it."});

        // --- MUNDANE ADVENTURING GEAR (PHB 292-306) ---
        // Containers & Storage
        register_item({"Backpack", 5, 2, Rarity::Mundane, "A leather pack with straps, holds 30 lb."});
        register_item({"Barrel", 5, 2, Rarity::Mundane, "A wooden barrel, holds 40 gallons of liquid or 4 cubic feet of solids."});
        register_item({"Basket", 5, 1, Rarity::Mundane, "A wicker basket, holds 2 cubic feet or 40 lb."});
        register_item({"Chest", 10, 5, Rarity::Mundane, "A sturdy wooden chest with a latch, holds 12 cubic feet or 300 lb."});
        register_item({"Flask", 2, 1, Rarity::Mundane, "A glass or metal flask holding 1 pint of liquid."});
        register_item({"Jug", 5, 1, Rarity::Mundane, "A ceramic jug that holds 1 gallon of liquid."});
        register_item({"Pot, Iron", 5, 2, Rarity::Mundane, "A large iron cooking pot."});
        register_item({"Pouch", 2, 1, Rarity::Mundane, "A small leather pouch that holds 6 lb or 1/5 cubic feet."});
        register_item({"Sack", 2, 1, Rarity::Mundane, "A cloth sack that holds 30 lb or 1 cubic foot."});
        register_item({"Map or Scroll Case", 5, 1, Rarity::Mundane, "A leather tube with a cap, used to store maps or scrolls."});
        register_item({"Waterskin", 3, 1, Rarity::Mundane, "A leather pouch that holds 4 pints of liquid."});

        // Light & Fire
        register_item({"Candle", 1, 1, Rarity::Mundane, "A tallow candle that sheds dim light in a 5-foot radius for 1 hour."});
        register_item({"Lamp", 3, 1, Rarity::Mundane, "A clay lamp that sheds bright light in a 15-foot radius and dim light for 30 feet."});
        register_item({"Lantern, Bullseye", 5, 10, Rarity::Mundane, "Casts bright light in a 60-foot cone and dim light for another 60 feet."});
        register_item({"Lantern, Hooded", 5, 5, Rarity::Mundane, "Sheds bright light in a 30-foot radius; hood can reduce light to dim."});
        register_item({"Oil Flask", 2, 1, Rarity::Mundane, "A flask of lamp oil. Can be thrown to coat a 5-foot square, igniting for 2 turns."});
        register_item({"Tinderbox", 3, 1, Rarity::Mundane, "A small container with flint, fire steel, and tinder for starting fires."});
        register_item({"Torch", 1, 1, Rarity::Mundane, "A wooden torch that sheds bright light in a 20-foot radius for 1 hour."});

        // Climbing & Exploration
        register_item({"Climber's Kit", 5, 25, Rarity::Mundane, "Includes pitons, boot tips, gloves, and a harness. Gives advantage on climbing checks."});
        register_item({"Crowbar", 5, 2, Rarity::Mundane, "A metal pry bar that grants advantage on Strength checks for forcing doors or crates."});
        register_item({"Grappling Hook", 5, 2, Rarity::Mundane, "An iron hook attached to a length of rope for scaling walls or anchoring lines."});
        register_item({"Hammer", 3, 1, Rarity::Mundane, "A standard carpenter's hammer for driving pitons and spikes."});
        register_item({"Hammer, Sledge", 5, 2, Rarity::Mundane, "A heavy two-handed hammer for breaking through walls and doors."});
        register_item({"Ladder (10 ft)", 3, 1, Rarity::Mundane, "A 10-foot wooden ladder."});
        register_item({"Piton", 1, 1, Rarity::Mundane, "A metal spike hammered into rock or wood as an anchor."});
        register_item({"Pole (10 ft)", 3, 1, Rarity::Mundane, "A 10-foot wooden pole useful for probing pits and triggering traps."});
        register_item({"Rope, Hempen (50 ft)", 5, 1, Rarity::Mundane, "50 feet of hemp rope. Has 2 hit points and can be burst with a DC 17 Strength check."});
        register_item({"Rope, Silk (50 ft)", 5, 10, Rarity::Mundane, "50 feet of strong, lightweight silk rope. Has 2 hit points and DC 17 to burst."});
        register_item({"Shovel", 5, 2, Rarity::Mundane, "An iron-headed digging shovel."});
        register_item({"String (10 ft)", 1, 1, Rarity::Mundane, "A 10-foot length of thin but strong string."});

        // Tools & Utility
        register_item({"Ball Bearings (bag)", 2, 1, Rarity::Mundane, "A bag of 1000 steel ball bearings. Scattered over 10 ft square, creatures must make DC 10 Dex save or fall prone."});
        register_item({"Block and Tackle", 5, 1, Rarity::Mundane, "A set of pulleys and rope that allows lifting objects up to 4x your normal capacity."});
        register_item({"Caltrops (bag)", 2, 1, Rarity::Mundane, "A bag of 20 iron caltrops. Scattered over 5 ft square, creatures moving through take 1 piercing damage and speed halved."});
        register_item({"Chain (10 ft)", 5, 5, Rarity::Mundane, "10 feet of heavy iron chain with 10 hit points and AC 19."});
        register_item({"Fishing Tackle", 3, 1, Rarity::Mundane, "A leather pouch containing hooks, line, floats, and lures."});
        register_item({"Hourglass", 5, 25, Rarity::Mundane, "A glass hourglass that tracks up to 1 hour of time."});
        register_item({"Lock", 5, 10, Rarity::Mundane, "An iron lock with matching key. Picking requires thieves' tools and DC 15 check."});
        register_item({"Magnifying Glass", 3, 100, Rarity::Mundane, "A lens that grants advantage on Perception checks involving fine detail."});
        register_item({"Manacles", 5, 2, Rarity::Mundane, "Iron manacles that can bind a Small or Medium creature. Breaking free requires DC 20 Strength."});
        register_item({"Mirror, Steel", 3, 5, Rarity::Mundane, "A small polished steel hand mirror."});
        register_item({"Net", 3, 1, Rarity::Mundane, "A weighted net (10 ft diameter) that can be thrown to restrain creatures."});
        register_item({"Pick, Miner's", 5, 2, Rarity::Mundane, "An iron pick used for breaking up earth and rock."});
        register_item({"Spyglass", 5, 1000, Rarity::Mundane, "A brass telescope. Objects viewed are magnified to twice their size."});
        register_item({"Whetstone", 1, 1, Rarity::Mundane, "A small stone used to sharpen bladed weapons."});

        // Food & Sustenance
        register_item({"Rations (1 day)", 2, 1, Rarity::Mundane, "One day's worth of dry food: hard biscuits, dried fruit, and jerked meat."});

        // Writing & Communication
        register_item({"Book", 5, 25, Rarity::Mundane, "A bound book with 100 pages, blank or with lore."});
        register_item({"Bottle, Glass", 3, 2, Rarity::Mundane, "A glass bottle with a stopper, holds 1.5 pints."});
        register_item({"Chalk (1 piece)", 1, 1, Rarity::Mundane, "A piece of white chalk for marking surfaces."});
        register_item({"Ink (1 oz)", 1, 10, Rarity::Mundane, "A small bottle of black writing ink."});
        register_item({"Ink Pen", 1, 1, Rarity::Mundane, "A feather quill or reed pen for writing."});
        register_item({"Paper (sheet)", 1, 1, Rarity::Mundane, "A single sheet of fine writing paper."});
        register_item({"Parchment (sheet)", 1, 1, Rarity::Mundane, "A sheet of treated animal skin used as writing material."});
        register_item({"Sealing Wax", 1, 1, Rarity::Mundane, "A stick of wax for sealing letters and documents."});
        register_item({"Signet Ring", 3, 5, Rarity::Mundane, "A ring bearing a personal seal for marking wax."});

        // Clothing & Personal
        register_item({"Bedroll", 3, 1, Rarity::Mundane, "A roll of blankets and padding for sleeping outdoors."});
        register_item({"Blanket", 3, 1, Rarity::Mundane, "A wool blanket providing warmth while resting."});
        register_item({"Clothes, Common", 3, 1, Rarity::Mundane, "Simple, sturdy everyday clothing."});
        register_item({"Clothes, Costume", 3, 5, Rarity::Mundane, "An elaborate costume outfit for performances or disguises."});
        register_item({"Clothes, Fine", 3, 15, Rarity::Mundane, "Elegant garments fit for nobles and formal occasions."});
        register_item({"Clothes, Traveler's", 3, 2, Rarity::Mundane, "Durable, comfortable clothes suited for long journeys."});
        register_item({"Perfume (vial)", 1, 5, Rarity::Mundane, "A small vial of pleasant-smelling fragrance."});
        register_item({"Signal Whistle", 1, 1, Rarity::Mundane, "A small metal whistle audible up to 600 feet away."});
        register_item({"Soap", 1, 1, Rarity::Mundane, "A bar of lye soap."});

        // Arcane & Religious Supplies
        register_item({"Component Pouch", 5, 25, Rarity::Mundane, "A leather pouch for storing spell components."});
        register_item({"Holy Symbol", 5, 5, Rarity::Mundane, "An emblem of a deity—amulet, reliquary, or embossed shield."});
        register_item({"Holy Water (flask)", 3, 25, Rarity::Mundane, "A flask of blessed water. Deals 2d6 radiant damage to undead and fiends."});
        register_item({"Hunting Trap", 5, 5, Rarity::Mundane, "A serrated metal trap. A creature stepping on it is restrained until freed (DC 13 Str check)."});
        register_item({"Poison, Basic (vial)", 1, 100, Rarity::Mundane, "A vial of contact poison. Coated weapon deals extra 1d4 poison damage for 1 minute."});
        register_item({"Spellbook", 5, 50, Rarity::Mundane, "A leather-bound book with 100 pages for recording spells."});
        register_item({"Vial", 1, 1, Rarity::Mundane, "A small glass vial with a stopper, holds up to 4 ounces."});

        // Kits & Sets
        register_item({"Alchemist's Fire (flask)", 3, 50, Rarity::Mundane, "A sticky incendiary fluid. On hit, target burns for 1d4 fire damage per turn until action used to extinguish."});
        register_item({"Acid (vial)", 3, 25, Rarity::Mundane, "A vial of corrosive acid. On hit, deals 2d6 acid damage to the target and 1 damage to armor."});
        register_item({"Healer's Kit", 5, 5, Rarity::Mundane, "A leather pouch with bandages and herbs. Stabilizes a creature at 0 HP without a check (10 uses)."});
        register_item({"Disguise Kit", 5, 25, Rarity::Mundane, "Cosmetics, hair dye, and small props for creating disguises."});
        register_item({"Abacus", 3, 2, Rarity::Mundane, "A wooden counting frame with beads used for calculations."});
    }

    void register_weapon(Weapon w) { weapon_templates_.emplace(w.get_name(), std::move(w)); }
    void register_armor(Armor a) { armor_templates_.emplace(a.get_name(), std::move(a)); }
    void register_item(Item i) { item_templates_.emplace(i.get_name(), std::move(i)); }
    void register_consumable(Consumable c) { consumable_templates_.emplace(c.get_name(), std::move(c)); }

    std::map<std::string, Weapon> weapon_templates_;
    std::map<std::string, Armor> armor_templates_;
    std::map<std::string, Item> item_templates_;
    std::map<std::string, Consumable> consumable_templates_;
};

} // namespace rimvale

#endif // RIMVALE_ITEM_REGISTRY_H
