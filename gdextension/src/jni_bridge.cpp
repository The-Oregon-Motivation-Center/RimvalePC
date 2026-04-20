#include <jni.h>
#include <string>
#include <sstream>
#include <vector>
#include <memory>
#include <algorithm>
#include <set>
#include <unordered_set>
#include <cstdint>
#include "Character.h"
#include "CharacterCreator.h"
#include "Dice.h"
#include "LineageRegistry.h"
#include "Feats.h"
#include "Creature.h"
#include "ItemRegistry.h"
#include "NPC.h"
#include "NpcRegistry.h"
#include "World.h"
#include "Quest.h"
#include "Faction.h"
#include "CombatManager.h"
#include "Base.h"
#include "SpellRegistry.h"
#include "Dungeon.h"
#include "SocietalRoleRegistry.h"
#include "CharacterRegistry.h"
#include "CreatureRegistry.h"

// --- Safety Helpers ---

namespace rimvale {
    Character* getSafeChar(jlong handle) {
        return CharacterRegistry::instance().get_character_by_handle(handle);
    }
    Creature* getSafeCreature(jlong handle) {
        auto* c = CreatureRegistry::instance().get_creature(handle);
        if (!c) return reinterpret_cast<Creature*>(getSafeChar(handle));
        return c;
    }
}

jobjectArray to_jstring_array(JNIEnv *env, const std::vector<std::string>& vec) {
    jclass string_class = env->FindClass("java/lang/String");
    jobjectArray res = env->NewObjectArray(static_cast<jsize>(vec.size()), string_class, env->NewStringUTF(""));
    for (size_t i = 0; i < vec.size(); ++i) {
        env->SetObjectArrayElement(res, static_cast<jsize>(i), env->NewStringUTF(vec[i].c_str()));
    }
    return res;
}

std::string dam_to_str(rimvale::DamageType type) {
    switch (type) {
        case rimvale::DamageType::Bludgeoning: return "Bludgeoning";
        case rimvale::DamageType::Piercing: return "Piercing";
        case rimvale::DamageType::Slashing: return "Slashing";
        case rimvale::DamageType::Force: return "Force";
        case rimvale::DamageType::Fire: return "Fire";
        case rimvale::DamageType::Cold: return "Cold";
        case rimvale::DamageType::Lightning: return "Lightning";
        case rimvale::DamageType::Thunder: return "Thunder";
        case rimvale::DamageType::Acid: return "Acid";
        case rimvale::DamageType::Poison: return "Poison";
        case rimvale::DamageType::Psychic: return "Psychic";
        case rimvale::DamageType::Radiant: return "Radiant";
        case rimvale::DamageType::Necrotic: return "Necrotic";
        default: return "Unknown";
    }
}

std::vector<std::string> get_item_info_vec(const rimvale::Item* item) {
    std::vector<std::string> d;
    if (!item) return d;
    std::string r;
    switch(item->get_rarity()) {
        case rimvale::Rarity::Mundane: r = "Mundane"; break;
        case rimvale::Rarity::Common: r = "Common"; break;
        case rimvale::Rarity::Uncommon: r = "Uncommon"; break;
        case rimvale::Rarity::Rare: r = "Rare"; break;
        case rimvale::Rarity::VeryRare: r = "Very Rare"; break;
        case rimvale::Rarity::Legendary: r = "Legendary"; break;
        case rimvale::Rarity::Apex: r = "Apex"; break;
    }
    d.push_back(r); d.push_back(std::to_string(item->get_current_hp()));
    d.push_back(std::to_string(item->get_max_hp())); d.push_back(std::to_string(item->get_cost_gp()));
    if (auto* w = dynamic_cast<const rimvale::Weapon*>(item)) {
        d.push_back("Weapon"); d.push_back(w->get_damage_dice()); d.push_back(dam_to_str(w->get_damage_type()));
        d.push_back(w->get_category() == rimvale::WeaponCategory::Simple ? "Simple" : "Martial");
        std::string p; for (const auto& s : w->get_properties()) p += s + ", "; d.push_back(p); d.push_back(w->get_mastery());
    } else if (auto* a = dynamic_cast<const rimvale::Armor*>(item)) {
        d.push_back("Armor"); d.push_back(std::to_string(a->get_ac_bonus())); d.push_back(std::to_string(a->get_strength_req()));
        d.push_back(a->has_stealth_disadvantage() ? "True" : "False");
        std::string cat; switch(a->get_category()){
            case rimvale::ArmorCategory::Light: cat="Light";break; case rimvale::ArmorCategory::Medium: cat="Medium";break;
            case rimvale::ArmorCategory::Heavy: cat="Heavy";break; case rimvale::ArmorCategory::Shield: cat="Shield";break;
            case rimvale::ArmorCategory::TowerShield: cat="Tower Shield";break;
        } d.push_back(cat);
    } else if (item->is_consumable()) d.push_back("Consumable");
    else d.push_back("General");
    d.push_back(item->get_description());
    return d;
}

extern "C" {

// --- Lineages ---
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllLineages(JNIEnv *env, jobject) { return to_jstring_array(env, rimvale::LineageRegistry::instance().get_all_names()); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getLineageDetails(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr); const auto* l = rimvale::LineageRegistry::instance().get_lineage(n);
    std::vector<std::string> d; if (l) {
        d.push_back(l->type); d.push_back(std::to_string(l->base_speed));
        std::string f; for (const auto& s : l->features) f += s + "||"; d.push_back(f);
        std::string ln; for (const auto& s : l->languages) ln += s + ", "; d.push_back(ln);
        d.push_back(l->description); d.push_back(l->culture);
    } env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, d);
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllFeatCategories(JNIEnv *env, jobject) {
    return to_jstring_array(env, {"Stat feats", "Weapons and Combat feats", "Armor feats", "Magic feats", "Alignment feats", "Domain feats", "Exploration feats", "Crafting feats", "Apex feats", "Ascendant Feats"});
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatTreesByCategory(JNIEnv *env, jobject, jstring cat) {
    const char *c = env->GetStringUTFChars(cat, nullptr);
    auto feats = rimvale::FeatRegistry::instance().get_feats_by_category(c);
    std::set<std::string> trees; for (const auto& f : feats) if(!f.tree_name.empty()) trees.insert(f.tree_name);
    env->ReleaseStringUTFChars(cat, c);
    return to_jstring_array(env, std::vector<std::string>(trees.begin(), trees.end()));
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatTreesByCharacter(JNIEnv *env, jobject, jlong handle) {
    auto* c = rimvale::getSafeChar(handle);
    if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    std::string dom; switch(c->get_domain()){
        case rimvale::Domain::Biological:dom="Biological Domain";break;
        case rimvale::Domain::Chemical:dom="Chemical Domain";break;
        case rimvale::Domain::Physical:dom="Physical Domain";break;
        case rimvale::Domain::Spiritual:dom="Spiritual Domain";break;
    }
    return to_jstring_array(env, {dom, "Arcane Wellspring", "Iron Vitality", "Martial Focus", "Safeguard"});
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatsByTree(JNIEnv *env, jobject, jstring tree) {
    const char *t = env->GetStringUTFChars(tree, nullptr);
    auto feats = rimvale::FeatRegistry::instance().get_feats_by_tree(t);
    std::vector<std::string> names; for (const auto& f : feats) names.push_back(f.name + " (Tier " + std::to_string(f.tier) + ")");
    env->ReleaseStringUTFChars(tree, t);
    return to_jstring_array(env, names);
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatsByCategory(JNIEnv *env, jobject, jstring cat) {
    const char *c = env->GetStringUTFChars(cat, nullptr); auto feats = rimvale::FeatRegistry::instance().get_feats_by_category(c);
    std::vector<std::string> names; for (const auto& f : feats) names.push_back(f.name);
    env->ReleaseStringUTFChars(cat, c); return to_jstring_array(env, names);
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatsByTier(JNIEnv *env, jobject, jint tier) {
    auto feats = rimvale::FeatRegistry::instance().get_feats_by_tier(tier);
    std::vector<std::string> names; for (const auto& f : feats) names.push_back(f.name);
    return to_jstring_array(env, names);
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatDetails(JNIEnv *env, jobject, jstring name, jint tier) {
    const char *n = env->GetStringUTFChars(name, nullptr); const auto* f = rimvale::FeatRegistry::instance().find_feat_by_name(n);
    std::vector<std::string> d = { f ? f->description : "Not found", f ? f->category : "Unknown", f ? f->tree_name : "" };
    env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, d);
}

JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatDescription(JNIEnv *env, jobject, jstring name, jint tier) {
    const char *n = env->GetStringUTFChars(name, nullptr); std::string desc = "Not found";
    for(const auto& f : rimvale::FeatRegistry::instance().get_all_feats()) if (f.name == n && f.tier == tier) { desc = f.description; break; }
    env->ReleaseStringUTFChars(name, n); return env->NewStringUTF(desc.c_str());
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllSocietalRoles(JNIEnv *env, jobject) {
    const auto& roles = rimvale::SocietalRoleRegistry::instance().get_all_roles();
    std::vector<std::string> names; for (const auto& r : roles) names.push_back(r.name);
    return to_jstring_array(env, names);
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getSocietalRoleDetails(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr); const auto* r = rimvale::SocietalRoleRegistry::instance().get_role(n);
    std::vector<std::string> d; if (r) { d.push_back(r->primary_benefit); d.push_back(r->secondary_benefit); d.push_back(r->description); }
    env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, d);
}

JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_addSocietalRole(JNIEnv *env, jobject, jlong h, jstring name) {
    auto* c = rimvale::getSafeChar(h); const char *n = env->GetStringUTFChars(name, nullptr);
    const auto* r = rimvale::SocietalRoleRegistry::instance().get_role(n); if (c && r) c->add_societal_role(*r);
    env->ReleaseStringUTFChars(name, n);
}

JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterSocietalRoleName(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h);
    if (c && !c->get_societal_roles().empty()) return env->NewStringUTF(c->get_societal_roles()[0].name.c_str());
    return env->NewStringUTF("");
}

JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setSocietalRole(JNIEnv *env, jobject, jlong h, jstring name) {
    auto* c = rimvale::getSafeChar(h); const char *n = env->GetStringUTFChars(name, nullptr);
    const auto* r = rimvale::SocietalRoleRegistry::instance().get_role(n);
    if (c && r) { c->clear_societal_roles(); c->add_societal_role(*r); }
    env->ReleaseStringUTFChars(name, n);
}

JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setCharacterName(JNIEnv *env, jobject, jlong h, jstring name) {
    auto* c = rimvale::getSafeChar(h); const char *n = env->GetStringUTFChars(name, nullptr);
    if (c) c->set_name(n);
    env->ReleaseStringUTFChars(name, n);
}

JNIEXPORT jlong JNICALL Java_com_rimvale_mobile_RimvaleEngine_createCharacter(JNIEnv *env, jobject, jstring name, jstring lineage, jint age) {
    const char *n = env->GetStringUTFChars(name, nullptr); const char *l_n = env->GetStringUTFChars(lineage, nullptr);
    const auto* l_ptr = rimvale::LineageRegistry::instance().get_lineage(l_n);
    auto* c = new rimvale::Character(n, l_ptr ? *l_ptr : rimvale::Lineage{l_n, "Unknown"});
    c->set_age(age); rimvale::CharacterRegistry::instance().register_character(c);
    env->ReleaseStringUTFChars(name, n); env->ReleaseStringUTFChars(lineage, l_n);
    return reinterpret_cast<jlong>(c);
}

JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_fuseCharacters(JNIEnv*, jobject, jlong target, jlong sacrifice) {
    auto* t = rimvale::getSafeChar(target); auto* s = rimvale::getSafeChar(sacrifice);
    if (t && s) t->fuse_with(*s);
}

JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterName(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c ? c->get_name().c_str() : ""); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterId(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c ? c->get_id().c_str() : ""); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterLineageName(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c ? c->get_lineage().name.c_str() : "Unknown"); }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterLevel(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_level() : 1; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterXp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_xp() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterXpRequired(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_xp_required() : 3; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_addXp(JNIEnv*, jobject, jlong h, jint amount, jint limit) { if (auto* c = rimvale::getSafeChar(h)) c->add_xp(amount, limit); }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_addGold(JNIEnv*, jobject, jlong h, jint amount) { if (auto* c = rimvale::getSafeChar(h)) c->add_gold(amount); }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterStatPoints(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_stat_points() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterFeatPoints(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_feat_points() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterSkillPoints(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_skill_points() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterStat(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); return c ? c->get_stats().get_stat(static_cast<rimvale::StatType>(t)) : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterSkill(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); return c ? c->get_skills().get_skill(static_cast<rimvale::SkillType>(t)) : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterFeatTier(JNIEnv *env, jobject, jlong h, jstring name) {
    auto* c = rimvale::getSafeChar(h); if (!c) return 0; const char *n = env->GetStringUTFChars(name, nullptr);
    const auto* f = rimvale::FeatRegistry::instance().find_feat_by_name(n); int tier = f ? c->get_feat_tier(f->id) : 0;
    env->ReleaseStringUTFChars(name, n); return tier;
}
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_canUnlockFeat(JNIEnv *env, jobject, jlong h, jstring name, jint tier) {
    auto* c = rimvale::getSafeChar(h); if (!c) return false; const char *n = env->GetStringUTFChars(name, nullptr);
    const auto* f = rimvale::FeatRegistry::instance().find_feat_by_name(n);
    bool can = false; if (f) {
        int cur = c->get_feat_tier(f->id); bool lvl_ok = true; int lvl = c->get_level();
        if (tier == 2 && lvl < 5) lvl_ok = false; if (tier == 3 && lvl < 9) lvl_ok = false;
        if (tier == 4 && lvl < 13) lvl_ok = false; if (tier == 5 && lvl < 17) lvl_ok = false;
        can = lvl_ok && (cur < tier) && (c->get_feat_points() >= tier) && rimvale::FeatRegistry::instance().is_next_available_tier(f->id, cur, tier);
    } env->ReleaseStringUTFChars(name, n); return can;
}
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_spendStatPoint(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); return c ? c->spend_stat_point(static_cast<rimvale::StatType>(t)) : false; }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_spendSkillPoint(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); return c ? c->spend_skill_point(static_cast<rimvale::SkillType>(t)) : false; }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_spendFeatPoint(JNIEnv *env, jobject, jlong h, jstring name, jint tier) {
    auto* character = rimvale::getSafeChar(h); if (!character) return false;
    const char *native_feat_name = env->GetStringUTFChars(name, nullptr);
    const auto* feat = rimvale::FeatRegistry::instance().find_feat_by_name(native_feat_name); bool res = feat ? character->spend_feat_point(feat->id, tier) : false;
    env->ReleaseStringUTFChars(name, native_feat_name); return res;
}
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterHp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->current_hp_ : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterMaxHp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_max_hp() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterAp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->current_ap_ : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterMaxAp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_max_ap() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterSp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->current_sp_ : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterMaxSp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_max_sp() : 0; }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_spendCharacterSp(JNIEnv*, jobject, jlong h, jint amount) { auto* c = rimvale::getSafeChar(h); if (!c || c->current_sp_ < amount) return JNI_FALSE; c->current_sp_ -= amount; return JNI_TRUE; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_restoreCharacterSp(JNIEnv*, jobject, jlong h, jint amount) { auto* c = rimvale::getSafeChar(h); if (c) c->restore_sp(amount); }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterAc(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_armor_class() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterMovementSpeed(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_movement_speed() : 0; }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterInjuries(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h); if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    std::vector<std::string> names; for (const auto& i : c->injuries_) names.push_back(i.name);
    return to_jstring_array(env, names);
}
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_characterTakeDamage(JNIEnv*, jobject, jlong h, jint a) { auto* c = rimvale::getSafeChar(h); if (c) { rimvale::Dice d; c->take_damage(a, d); return c->current_hp_; } return 0; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_characterStartTurn(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); if (c) c->start_turn(); }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_shortRest(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); if (c) { rimvale::Dice d; c->short_rest(d); } }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_longRest(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); if (c) { c->long_rest(); } }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_restParty(JNIEnv *env, jobject, jlongArray h) {
    if (rimvale::CombatManager::instance().is_dungeon_mode() || rimvale::CombatManager::instance().is_mission_active()) return JNI_FALSE;
    jsize len = env->GetArrayLength(h); jlong *ptr = env->GetLongArrayElements(h, nullptr);
    for (int i=0; i<len; ++i) { auto* c = rimvale::getSafeChar(ptr[i]); if (c) c->long_rest(); }
    env->ReleaseLongArrayElements(h, ptr, JNI_ABORT); return JNI_TRUE;
}
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_serializeCharacter(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c ? c->serialize().c_str() : ""); }
JNIEXPORT jlong JNICALL Java_com_rimvale_mobile_RimvaleEngine_deserializeCharacter(JNIEnv *env, jobject, jstring data) {
    const char *d = env->GetStringUTFChars(data, nullptr); auto c = rimvale::Character::deserialize(d);
    env->ReleaseStringUTFChars(data, d); return c ? reinterpret_cast<jlong>(c.release()) : 0L;
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_destroyCharacter(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); if (c) { rimvale::CharacterRegistry::instance().unregister_character(h); delete c; } }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_isProficientInSavingThrow(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); return c ? c->is_proficient_in_saving_throw(static_cast<rimvale::StatType>(t)) : false; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_toggleSavingThrowProficiency(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); if (c) c->toggle_saving_throw_proficiency(static_cast<rimvale::StatType>(t)); }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_isFavoredSkill(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); return c ? c->is_favored_skill(static_cast<rimvale::SkillType>(t)) : false; }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_toggleFavoredSkill(JNIEnv*, jobject, jlong h, jint t) { auto* c = rimvale::getSafeChar(h); return c ? c->toggle_favored_skill(static_cast<rimvale::SkillType>(t)) : false; }

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getLearnedSpells(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF("")); return to_jstring_array(env, c->get_learned_spells()); }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_learnSpell(JNIEnv *env, jobject, jlong h, jstring name) { auto* c = rimvale::getSafeChar(h); if (c) { const char *n = env->GetStringUTFChars(name, nullptr); c->add_learned_spell(n); env->ReleaseStringUTFChars(name, n); } }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_forgetSpell(JNIEnv *env, jobject, jlong h, jstring name) { auto* c = rimvale::getSafeChar(h); if (c) { const char *n = env->GetStringUTFChars(name, nullptr); c->remove_learned_spell(n); env->ReleaseStringUTFChars(name, n); } }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllSpells(JNIEnv *env, jobject) {
    const auto& spells = rimvale::SpellRegistry::instance().get_all_spells(); jclass sa = env->FindClass("[Ljava/lang/String;"); jobjectArray result = env->NewObjectArray(static_cast<jsize>(spells.size()), sa, nullptr);
    for (size_t i=0; i<spells.size(); ++i) {
        std::vector<std::string> sd = { spells[i].name, std::to_string(static_cast<int>(spells[i].domain)), std::to_string(spells[i].base_sp_cost), spells[i].description, std::to_string(static_cast<int>(spells[i].range)), spells[i].is_attack ? "true" : "false", std::to_string(static_cast<int>(spells[i].area_type)), std::to_string(spells[i].max_targets), spells[i].is_teleport ? "true" : "false" };
        env->SetObjectArrayElement(result, static_cast<jsize>(i), to_jstring_array(env, sd));
    } return result;
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getSpellsByDomain(JNIEnv *env, jobject, jint dom) {
    const auto& spells = rimvale::SpellRegistry::instance().get_spells_by_domain(static_cast<rimvale::Domain>(dom)); jclass sa = env->FindClass("[Ljava/lang/String;"); jobjectArray res = env->NewObjectArray(static_cast<jsize>(spells.size()), sa, nullptr);
    for (size_t i=0; i<spells.size(); ++i) {
        std::vector<std::string> sd = { spells[i].name, std::to_string(static_cast<int>(spells[i].domain)), std::to_string(spells[i].base_sp_cost), spells[i].description, std::to_string(static_cast<int>(spells[i].range)), spells[i].is_attack ? "true" : "false", std::to_string(static_cast<int>(spells[i].area_type)), std::to_string(spells[i].max_targets), spells[i].is_teleport ? "true" : "false" };
        env->SetObjectArrayElement(res, static_cast<jsize>(i), to_jstring_array(env, sd));
    } return res;
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCustomSpells(JNIEnv *env, jobject) {
    const auto& spells = rimvale::SpellRegistry::instance().get_custom_spells(); jclass sa = env->FindClass("[Ljava/lang/String;"); jobjectArray result = env->NewObjectArray(static_cast<jsize>(spells.size()), sa, nullptr);
    for (size_t i=0; i<spells.size(); ++i) {
        std::vector<std::string> sd = { spells[i].name, std::to_string(static_cast<int>(spells[i].domain)), std::to_string(spells[i].base_sp_cost), spells[i].description, std::to_string(static_cast<int>(spells[i].range)), spells[i].is_attack ? "true" : "false", std::to_string(static_cast<int>(spells[i].area_type)), std::to_string(spells[i].max_targets), spells[i].is_teleport ? "true" : "false" };
        env->SetObjectArrayElement(result, static_cast<jsize>(i), to_jstring_array(env, sd));
    } return result;
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_addCustomSpell(JNIEnv *env, jobject, jstring name, jint dom, jint cost, jstring desc, jint range, jboolean is_attack, jint die_count, jint die_sides, jint damage_type, jboolean is_healing, jint duration_rounds, jint max_targets, jint area_type, jstring conditions_csv, jboolean is_teleport) {
    const char *n = env->GetStringUTFChars(name, nullptr); const char *d = env->GetStringUTFChars(desc, nullptr);
    const char *ccsv = env->GetStringUTFChars(conditions_csv, nullptr);
    std::vector<rimvale::ConditionType> conds;
    std::string csv(ccsv); std::stringstream ss(csv); std::string token;
    while (std::getline(ss, token, ',')) { if (!token.empty()) { try { conds.push_back(static_cast<rimvale::ConditionType>(std::stoi(token))); } catch (...) {} } }
    rimvale::Spell s = { n, static_cast<rimvale::Domain>(dom), cost, d, static_cast<rimvale::SpellRange>(range), is_attack == JNI_TRUE, die_count, die_sides, true, static_cast<rimvale::DamageType>(damage_type), is_healing == JNI_TRUE, conds, duration_rounds, max_targets, static_cast<rimvale::SpellAreaType>(area_type), is_teleport == JNI_TRUE };
    rimvale::SpellRegistry::instance().add_custom_spell(s);
    env->ReleaseStringUTFChars(name, n); env->ReleaseStringUTFChars(desc, d); env->ReleaseStringUTFChars(conditions_csv, ccsv);
}

JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getInventoryGold(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return c ? c->get_inventory().get_gold() : 0; }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getInventoryItems(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h); if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    std::vector<std::string> names; for (const auto& i : c->get_inventory().get_items()) names.push_back(i->get_name());
    return to_jstring_array(env, names);
}
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_useConsumable(JNIEnv *env, jobject, jlong h, jstring name) {
    auto* c = rimvale::getSafeChar(h); if (!c) return env->NewStringUTF("No char."); const char *n = env->GetStringUTFChars(name, nullptr);
    std::string res = "Not found"; auto& inv = c->get_inventory(); for (const auto& i : inv.get_items()) if (i->get_name() == n && i->is_consumable()) { res = dynamic_cast<rimvale::Consumable*>(i.get())->use(c); inv.remove_item(n); break; }
    env->ReleaseStringUTFChars(name, n); return env->NewStringUTF(res.c_str());
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getItemDetails(JNIEnv *env, jobject, jlong h, jstring name) {
    auto* c = rimvale::getSafeChar(h); if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    const char *n = env->GetStringUTFChars(name, nullptr); std::vector<std::string> det; for (const auto& i : c->get_inventory().get_items()) if (i->get_name() == n) { det = get_item_info_vec(i.get()); break; }
    env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, det);
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getRegistryItemDetails(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr);
    auto weapon = rimvale::ItemRegistry::instance().create_weapon(n);
    std::unique_ptr<rimvale::Item> i_ptr;
    if (weapon) i_ptr = std::move(weapon);
    else {
        auto armor = rimvale::ItemRegistry::instance().create_armor(n);
        if (armor) i_ptr = std::move(armor);
        else i_ptr = rimvale::ItemRegistry::instance().create_general_item(n);
    }
    std::vector<std::string> det = get_item_info_vec(i_ptr.get()); env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, det);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_addItemToInventory(JNIEnv *env, jobject, jlong h, jstring name) {
    auto* c = rimvale::getSafeChar(h); if (!c) return; const char *n = env->GetStringUTFChars(name, nullptr);
    auto w = rimvale::ItemRegistry::instance().create_weapon(n); if (w) c->get_inventory().add_item(std::move(w));
    else { auto a = rimvale::ItemRegistry::instance().create_armor(n); if (a) c->get_inventory().add_item(std::move(a)); else { auto i = rimvale::ItemRegistry::instance().create_general_item(n); if (i) c->get_inventory().add_item(std::move(i)); } }
    env->ReleaseStringUTFChars(name, n);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_removeItemFromInventory(JNIEnv *env, jobject, jlong h, jstring name) { auto* c = rimvale::getSafeChar(h); if (c) { const char *n = env->GetStringUTFChars(name, nullptr); c->get_inventory().remove_item(n); env->ReleaseStringUTFChars(name, n); } }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_equipItem(JNIEnv *env, jobject, jlong h, jstring name) {
    static const std::unordered_set<std::string> kLightSources = {"Torch", "Lantern, Bullseye", "Lantern, Hooded", "Lamp", "Candle"};
    auto* c = rimvale::getSafeChar(h); if (!c) return; const char *n = env->GetStringUTFChars(name, nullptr);
    std::string nameStr(n); env->ReleaseStringUTFChars(name, n);
    if (kLightSources.count(nameStr)) { c->equip_light_source(nameStr); return; }
    for (const auto& i : c->get_inventory().get_items()) if (i->get_name() == nameStr) {
        if (dynamic_cast<rimvale::Weapon*>(i.get())) c->equip_weapon(rimvale::ItemRegistry::instance().create_weapon(nameStr));
        else if (auto* a = dynamic_cast<rimvale::Armor*>(i.get())) { if (a->get_category() == rimvale::ArmorCategory::Shield || a->get_category() == rimvale::ArmorCategory::TowerShield) c->equip_shield(rimvale::ItemRegistry::instance().create_armor(nameStr)); else c->equip_armor(rimvale::ItemRegistry::instance().create_armor(nameStr)); }
        break;
    }
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_unequipItem(JNIEnv*, jobject, jlong h, jint s) { auto* c = rimvale::getSafeChar(h); if (c) { if (s==0) c->equip_weapon(nullptr); else if (s==1) c->equip_armor(nullptr); else if (s==2) c->equip_shield(nullptr); else if (s==3) c->unequip_light_source(); } }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getEquippedWeapon(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c && c->get_weapon() ? c->get_weapon()->get_name().c_str() : "None"); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getEquippedArmor(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c && c->get_armor() ? c->get_armor()->get_name().c_str() : "None"); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getEquippedShield(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c && c->get_shield() ? c->get_shield()->get_name().c_str() : "None"); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getEquippedLightSource(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); return env->NewStringUTF(c && !c->get_light_source().empty() ? c->get_light_source().c_str() : "None"); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllRegistryWeapons(JNIEnv *env, jobject) { return to_jstring_array(env, rimvale::ItemRegistry::instance().get_all_weapon_names()); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllRegistryArmor(JNIEnv *env, jobject) { return to_jstring_array(env, rimvale::ItemRegistry::instance().get_all_armor_names()); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllRegistryGeneralItems(JNIEnv *env, jobject) { return to_jstring_array(env, rimvale::ItemRegistry::instance().get_all_general_item_names()); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllRegistryMagicItems(JNIEnv *env, jobject) {
    std::vector<std::string> res; auto w = rimvale::ItemRegistry::instance().get_all_weapon_names(); for(const auto& n : w) { auto it = rimvale::ItemRegistry::instance().create_weapon(n); if (it && it->is_magical()) res.push_back(n); }
    auto a = rimvale::ItemRegistry::instance().get_all_armor_names(); for(const auto& n : a) { auto it = rimvale::ItemRegistry::instance().create_armor(n); if (it && it->is_magical()) res.push_back(n); }
    auto g = rimvale::ItemRegistry::instance().get_all_general_item_names(); for(const auto& n : g) { auto it = rimvale::ItemRegistry::instance().create_general_item(n); if (it && it->is_magical()) res.push_back(n); }
    return to_jstring_array(env, res);
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllRegistryMundaneItems(JNIEnv *env, jobject) {
    std::vector<std::string> res; auto w = rimvale::ItemRegistry::instance().get_all_weapon_names(); for(const auto& n : w) { auto it = rimvale::ItemRegistry::instance().create_weapon(n); if (it && !it->is_magical()) res.push_back(n); }
    auto a = rimvale::ItemRegistry::instance().get_all_armor_names(); for(const auto& n : a) { auto it = rimvale::ItemRegistry::instance().create_armor(n); if (it && !it->is_magical()) res.push_back(n); }
    auto g = rimvale::ItemRegistry::instance().get_all_general_item_names(); for(const auto& n : g) { auto it = rimvale::ItemRegistry::instance().create_general_item(n); if (it && !it->is_magical()) res.push_back(n); }
    return to_jstring_array(env, res);
}

// --- Creature ---
JNIEXPORT jlong JNICALL Java_com_rimvale_mobile_RimvaleEngine_spawnCreature(JNIEnv *env, jobject, jstring name, jint cat, jint lvl) {
    const char *n = env->GetStringUTFChars(name, nullptr); auto* c = new rimvale::Creature(n, static_cast<rimvale::CreatureCategory>(cat), lvl);
    c->get_inventory().add_item(rimvale::ItemRegistry::instance().create_weapon("Rusty Dagger")); c->get_inventory().add_gold((lvl + 1) * 10);
    rimvale::CreatureRegistry::instance().register_creature(c); env->ReleaseStringUTFChars(name, n); return reinterpret_cast<jlong>(c);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setCreatureStats(JNIEnv*, jobject, jlong h, jint str, jint spd, jint intel, jint vit, jint div) {
    auto* c = rimvale::getSafeCreature(h); if (c) { auto& s = c->get_stats(); s.strength = str; s.speed = spd; s.intellect = intel; s.vitality = vit; s.divinity = div; c->reset_resources(); }
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setCreatureFeat(JNIEnv *env, jobject, jlong h, jstring name, jint tier) {
    auto* c = rimvale::getSafeCreature(h); if (!c) return;
    const char *n = env->GetStringUTFChars(name, nullptr);
    c->set_feat_tier(n, tier);
    env->ReleaseStringUTFChars(name, n);
}
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureName(JNIEnv *env, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return env->NewStringUTF(c ? c->get_name().c_str() : ""); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureId(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeCreature(h);
    if (!c) return env->NewStringUTF("");
    // Using a simple handle-based ID for creatures if they don't have a stable ID
    return env->NewStringUTF(("creature_" + std::to_string(h)).c_str());
}
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureHp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return c ? c->get_current_hp() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureMaxHp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return c ? c->get_max_hp() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureAp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return c ? c->get_current_ap() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureMaxAp(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return c ? c->get_max_ap() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureMovementSpeed(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return c ? c->get_movement_speed() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureThreshold(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return c ? c->get_damage_threshold() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureAc(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); return c ? 10 + c->get_stats().speed : 10; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_creatureTakeDamage(JNIEnv*, jobject, jlong h, jint a) { auto* c = rimvale::getSafeCreature(h); if (c) { rimvale::Dice d; c->take_damage(a, d); return c->get_current_hp(); } return 0; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_destroyCreature(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); if (c) { rimvale::CreatureRegistry::instance().unregister_creature(h); delete c; } }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureInventoryItems(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeCreature(h); if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    const auto& items = c->get_inventory().get_items();
    std::vector<std::string> names; for (const auto& i : items) names.push_back(i->get_name());
    return to_jstring_array(env, names);
}
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_lootCreature(JNIEnv*, jobject, jlong ch, jlong ph) {
    auto* c = rimvale::getSafeCreature(ch); auto* p = rimvale::getSafeChar(ph); if (!c || !p) return false;
    auto items = c->get_inventory().take_all_items(); for (auto& i : items) p->get_inventory().add_item(std::move(i));
    p->get_inventory().add_gold(c->get_inventory().get_gold()); c->get_inventory().set_gold(0); return true;
}

// --- NPC ---
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllRegisteredNpcs(JNIEnv *env, jobject) { return to_jstring_array(env, rimvale::NpcRegistry::instance().get_all_npc_names()); }
JNIEXPORT jlong JNICALL Java_com_rimvale_mobile_RimvaleEngine_spawnRegisteredNpc(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr); auto npc = rimvale::NpcRegistry::instance().create_npc(n);
    if (npc) rimvale::CreatureRegistry::instance().register_creature(npc.get()); env->ReleaseStringUTFChars(name, n); return reinterpret_cast<jlong>(npc.release());
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setNpcDrivers(JNIEnv*, jobject, jlong h, jint c, jint v, jint r) {
    auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(h)); if (n) { auto& d = n->get_drivers(); d.community = c; d.validation = v; d.resources = r; d.clamp(); }
}
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getNpcDisposition(JNIEnv*, jobject, jlong h) { auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(h)); return n ? n->get_disposition() : 0; }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getNpcDispositionText(JNIEnv *env, jobject, jlong h) { auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(h)); return env->NewStringUTF(n ? n->get_disposition_text().c_str() : "Neutral"); }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_interactWithNpc(JNIEnv*, jobject, jlong h, jint cm, jint vm, jint rm) { auto* n = dynamic_cast<rimvale::NPC*>(rimvale::getSafeCreature(h)); if (n) n->handle_interaction(cm, vm, rm); }
JNIEXPORT jlong JNICALL Java_com_rimvale_mobile_RimvaleEngine_spawnAdversary(JNIEnv *env, jobject, jstring name, jint lvl) {
    const char *n = env->GetStringUTFChars(name, nullptr); auto* a = new rimvale::Adversary(n, lvl);
    rimvale::CreatureRegistry::instance().register_creature(a); env->ReleaseStringUTFChars(name, n); return reinterpret_cast<jlong>(a);
}
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAdversaryVengeanceBonus(JNIEnv*, jobject, jlong h) { auto* a = dynamic_cast<rimvale::Adversary*>(rimvale::getSafeCreature(h)); return a ? a->get_vengeance_bonus() : 0; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_adversarySurviveEncounter(JNIEnv*, jobject, jlong h) { auto* a = dynamic_cast<rimvale::Adversary*>(rimvale::getSafeCreature(h)); if (a) a->on_encounter_survived(); }

// --- World ---
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllRegions(JNIEnv *env, jobject) { return to_jstring_array(env, rimvale::WorldRegistry::instance().get_all_region_names()); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getRegionDetails(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr); const auto* r = rimvale::WorldRegistry::instance().get_region(n);
    std::vector<std::string> d; if (r) { d.push_back(r->climate_summary); d.push_back(std::to_string(r->base_trr)); }
    env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, d);
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getRegionTerrains(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr); const auto* r = rimvale::WorldRegistry::instance().get_region(n);
    std::vector<std::string> t; if (r) for (const auto& tr : r->terrains) t.push_back(tr.name);
    env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, t);
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getTerrainDetails(JNIEnv *env, jobject, jstring r_n, jstring t_n) {
    const char *rn = env->GetStringUTFChars(r_n, nullptr); const char *tn = env->GetStringUTFChars(t_n, nullptr);
    const auto* r = rimvale::WorldRegistry::instance().get_region(rn); jclass sa = env->FindClass("[Ljava/lang/String;"); jobjectArray res = env->NewObjectArray(2, sa, nullptr);
    if (r) for (const auto& t : r->terrains) if (t.name == tn) { env->SetObjectArrayElement(res, 0, to_jstring_array(env, t.beneficial_conditions)); env->SetObjectArrayElement(res, 1, to_jstring_array(env, t.harmful_conditions)); break; }
    env->ReleaseStringUTFChars(r_n, rn); env->ReleaseStringUTFChars(t_n, tn); return res;
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getQuestsByRegion(JNIEnv *env, jobject, jstring reg) {
    const char *n = env->GetStringUTFChars(reg, nullptr); auto quests = rimvale::QuestRegistry::instance().get_quests_by_region(n);
    jclass sa = env->FindClass("[Ljava/lang/String;"); jobjectArray res = env->NewObjectArray(static_cast<jsize>(quests.size()), sa, nullptr);
    for (size_t i=0; i<quests.size(); ++i) { std::vector<std::string> q = { quests[i].title, quests[i].type, quests[i].threat, quests[i].objective, quests[i].anomaly, quests[i].complication, quests[i].description }; env->SetObjectArrayElement(res, static_cast<jsize>(i), to_jstring_array(env, q)); }
    env->ReleaseStringUTFChars(reg, n); return res;
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getQuestRegions(JNIEnv *env, jobject) {
    return to_jstring_array(env, rimvale::QuestRegistry::instance().get_all_regions());
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_generateQuest(JNIEnv *env, jobject) { rimvale::Dice d; auto q = rimvale::QuestGenerator::generate_random_quest(d); return to_jstring_array(env, { q.region, q.type, q.threat, q.objective, q.anomaly, q.complication, q.description }); }

// --- Factions ---
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getAllFactions(JNIEnv *env, jobject) { return to_jstring_array(env, rimvale::FactionRegistry::instance().get_all_faction_names()); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFactionDetails(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr); const auto* f = rimvale::FactionRegistry::instance().get_faction(n);
    std::vector<std::string> d; if (f) { d.push_back(f->region); d.push_back(f->influence); d.push_back(f->territory_feature); }
    env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, d);
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFactionRanks(JNIEnv *env, jobject, jstring name) {
    const char *n = env->GetStringUTFChars(name, nullptr); const auto* f = rimvale::FactionRegistry::instance().get_faction(n);
    std::vector<std::string> r; if (f) for (const auto& rk : f->ranks) r.push_back(rk.title + ": " + rk.benefit);
    env->ReleaseStringUTFChars(name, n); return to_jstring_array(env, r);
}

// --- Combat Manager ---
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_startCombat(JNIEnv*, jobject) { rimvale::CombatManager::instance().start_combat(); }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_addPlayerToCombat(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeChar(h); if (c) { rimvale::Dice d; rimvale::CombatManager::instance().add_player(c, d); } }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_addCreatureToCombat(JNIEnv*, jobject, jlong h) { auto* c = rimvale::getSafeCreature(h); if (c) { rimvale::Dice d; rimvale::CombatManager::instance().add_creature(c, d); } }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_nextTurn(JNIEnv*, jobject) { rimvale::CombatManager::instance().next_turn(); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCurrentCombatantName(JNIEnv *env, jobject) { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return env->NewStringUTF(c ? c->name.c_str() : "None"); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCurrentCombatantId(JNIEnv *env, jobject) { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return env->NewStringUTF(c ? c->id.c_str() : "None"); }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_setCurrentCombatantById(JNIEnv *env, jobject, jstring id) { const char *nid = env->GetStringUTFChars(id, nullptr); bool res = rimvale::CombatManager::instance().set_current_combatant_by_id(nid); env->ReleaseStringUTFChars(id, nid); return res; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_endPlayerPhase(JNIEnv*, jobject) { rimvale::CombatManager::instance().end_player_phase(); }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCurrentCombatantIsPlayer(JNIEnv*, jobject) { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return c ? c->is_player : false; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCurrentCombatantAp(JNIEnv*, jobject) { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return c ? c->get_current_ap() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCurrentCombatantHp(JNIEnv*, jobject) { auto* c = rimvale::CombatManager::instance().get_current_combatant(); return c ? c->get_current_hp() : 0; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCombatRound(JNIEnv*, jobject) { return rimvale::CombatManager::instance().get_round(); }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getActionCost(JNIEnv *env, jobject, jint act, jstring param) {
    const char *p = param ? env->GetStringUTFChars(param, nullptr) : "";
    int cost = rimvale::CombatManager::instance().get_action_cost(static_cast<rimvale::ActionType>(act), p ? p : "");
    if (param) env->ReleaseStringUTFChars(param, p);
    return cost;
}
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_performAction(JNIEnv *env, jobject, jint act, jstring param) {
    const char *p = param ? env->GetStringUTFChars(param, nullptr) : ""; rimvale::Dice d;
    bool res = rimvale::CombatManager::instance().perform_action(static_cast<rimvale::ActionType>(act), d, p ? p : "");
    if (param) env->ReleaseStringUTFChars(param, p); return res;
}
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_processEnemyPhase(JNIEnv *env, jobject) { rimvale::Dice d; return env->NewStringUTF(rimvale::CombatManager::instance().process_enemy_phase(d).c_str()); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getLastActionLog(JNIEnv *env, jobject) { return env->NewStringUTF(rimvale::CombatManager::instance().get_last_action_log().c_str()); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getInitiativeOrder(JNIEnv *env, jobject) { const auto& c = rimvale::CombatManager::instance().get_combatants(); std::vector<std::string> o; for (const auto& co : c) o.push_back(co.name + " (" + std::to_string(co.initiative) + ")"); return to_jstring_array(env, o); }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setMissionActive(JNIEnv*, jobject, jboolean act) { rimvale::CombatManager::instance().set_mission_active(act == JNI_TRUE); }

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getActiveMatrices(JNIEnv *env, jobject, jstring id) {
    const char *nid = env->GetStringUTFChars(id, nullptr);
    auto* c = rimvale::CombatManager::instance().find_combatant_by_id(nid);
    std::vector<std::string> res;
    if (c) {
        for (const auto& m : c->active_matrices) {
            bool is_atk = false;
            const auto* spell = rimvale::SpellRegistry::instance().find_spell(m.spell_name);
            if (spell) is_atk = spell->is_attack;
            std::string info = m.spell_name + "|" + std::to_string(m.duration_rounds) + "|" + m.bound_item_name + "|" + (m.suppressed ? "true" : "false") + "|" + (is_atk ? "true" : "false");
            res.push_back(info);
        }
    }
    env->ReleaseStringUTFChars(id, nid);
    return to_jstring_array(env, res);
}

// --- Base Building ---
JNIEXPORT jlong JNICALL Java_com_rimvale_mobile_RimvaleEngine_createBase(JNIEnv *env, jobject, jstring name, jint tier) { const char *n = env->GetStringUTFChars(name, nullptr); auto* b = new rimvale::Base(n, tier); env->ReleaseStringUTFChars(name, n); return reinterpret_cast<jlong>(b); }
JNIEXPORT jstring JNICALL Java_com_rimvale_mobile_RimvaleEngine_getBaseName(JNIEnv *env, jobject, jlong h) { auto* b = reinterpret_cast<rimvale::Base*>(h); return env->NewStringUTF(b ? b->get_name().c_str() : ""); }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getBaseTier(JNIEnv*, jobject, jlong h) { auto* b = reinterpret_cast<rimvale::Base*>(h); return b ? b->get_tier() : 1; }
JNIEXPORT jintArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getBaseStats(JNIEnv *env, jobject, jlong h) { auto* b = reinterpret_cast<rimvale::Base*>(h); jintArray res = env->NewIntArray(4); if (b) { jint f[4] = {b->get_supplies(), b->get_defense(), b->get_morale(), b->get_acreage()}; env->SetIntArrayRegion(res, 0, 4, f); } return res; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getBaseMaxFacilities(JNIEnv*, jobject, jlong h) { auto* b = reinterpret_cast<rimvale::Base*>(h); return b ? b->get_max_facilities() : 0; }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getBaseFacilities(JNIEnv *env, jobject, jlong h) { auto* b = reinterpret_cast<rimvale::Base*>(h); if (!b) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF("")); std::vector<std::string> fl; for (const auto& f : b->get_facilities()) fl.push_back(f.name + ": " + f.description); return to_jstring_array(env, fl); }
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_addFacilityToBase(JNIEnv*, jobject, jlong h, jint t) { auto* b = reinterpret_cast<rimvale::Base*>(h); if (b) return b->add_facility(static_cast<rimvale::FacilityType>(t)); return false; }
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_getBaseDefenseModifier(JNIEnv*, jobject, jlong h) { auto* b = reinterpret_cast<rimvale::Base*>(h); return b ? b->get_defense_modifier() : 0; }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_destroyBase(JNIEnv*, jobject, jlong h) { delete reinterpret_cast<rimvale::Base*>(h); }
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setBaseStats(JNIEnv*, jobject, jlong h, jint sup, jint def, jint mor, jint acr) { auto* b = reinterpret_cast<rimvale::Base*>(h); if (b) { b->set_supplies(sup); b->set_defense(def); b->set_morale(mor); b->set_acreage(acr); } }

// --- Rules & Dice ---
JNIEXPORT jint JNICALL Java_com_rimvale_mobile_RimvaleEngine_rollSkill(JNIEnv*, jobject, jlong h, jint s) { auto* c = rimvale::getSafeChar(h); if (c) { rimvale::Dice d; return c->roll_skill_check(d, static_cast<rimvale::SkillType>(s)).total; } return 0; }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_rollSkillCheck(JNIEnv *env, jobject, jlong h, jint s, jint st) {
    auto* c = rimvale::getSafeChar(h); if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    rimvale::Dice d; auto r = c->roll_skill_check(d, static_cast<rimvale::SkillType>(s));
    std::string details = "Roll: " + std::to_string(r.die_roll) + " + Mod: " + std::to_string(r.modifier) + " = " + std::to_string(r.total);
    if (r.is_critical_success) details += " [CRIT SUCCESS]";
    if (r.is_critical_failure) details += " [CRIT FAILURE]";
    std::vector<std::string> res = { std::to_string(r.die_roll), std::to_string(r.modifier), std::to_string(r.total), details };
    return to_jstring_array(env, res);
}

// --- Dungeon System ---
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_startDungeon(JNIEnv *env, jobject, jlongArray h, jint l, jlong s, jint terrain) {
    jsize len = env->GetArrayLength(h); jlong *ptr = env->GetLongArrayElements(h, nullptr);
    std::vector<int64_t> players; for (int i=0; i<len; ++i) players.push_back(ptr[i]);
    rimvale::DungeonManager::instance().start_new_dungeon(players, l, s, terrain);
    env->ReleaseLongArrayElements(h, ptr, JNI_ABORT);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_startKaijuDungeon(JNIEnv *env, jobject, jlongArray h, jint kaiju_index, jint terrain) {
    jsize len = env->GetArrayLength(h); jlong *ptr = env->GetLongArrayElements(h, nullptr);
    std::vector<int64_t> players; for (int i=0; i<len; ++i) players.push_back(ptr[i]);
    rimvale::DungeonManager::instance().start_kaiju_dungeon(players, static_cast<int>(kaiju_index), static_cast<int>(terrain));
    env->ReleaseLongArrayElements(h, ptr, JNI_ABORT);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_startMilitiaDungeon(JNIEnv *env, jobject, jlongArray h, jint militia_index, jint terrain) {
    jsize len = env->GetArrayLength(h); jlong *ptr = env->GetLongArrayElements(h, nullptr);
    std::vector<int64_t> players; for (int i=0; i<len; ++i) players.push_back(ptr[i]);
    rimvale::DungeonManager::instance().start_militia_dungeon(players, static_cast<int>(militia_index), static_cast<int>(terrain));
    env->ReleaseLongArrayElements(h, ptr, JNI_ABORT);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_startApexDungeon(JNIEnv *env, jobject, jlongArray h, jint apex_index, jint terrain) {
    jsize len = env->GetArrayLength(h); jlong *ptr = env->GetLongArrayElements(h, nullptr);
    std::vector<int64_t> players; for (int i=0; i<len; ++i) players.push_back(ptr[i]);
    rimvale::DungeonManager::instance().start_apex_dungeon(players, static_cast<int>(apex_index), static_cast<int>(terrain));
    env->ReleaseLongArrayElements(h, ptr, JNI_ABORT);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_startMobDungeon(JNIEnv *env, jobject, jlongArray h, jint mob_count, jint mob_level, jint terrain, jint trait_idx, jint leader_idx, jint mood_idx) {
    jsize len = env->GetArrayLength(h); jlong *ptr = env->GetLongArrayElements(h, nullptr);
    std::vector<int64_t> players; for (int i=0; i<len; ++i) players.push_back(ptr[i]);
    rimvale::DungeonManager::instance().start_mob_dungeon(players,
        static_cast<int>(mob_count), static_cast<int>(mob_level),
        static_cast<int>(terrain), static_cast<int>(trait_idx),
        static_cast<int>(leader_idx), static_cast<int>(mood_idx));
    env->ReleaseLongArrayElements(h, ptr, JNI_ABORT);
}
JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_endDungeon(JNIEnv*, jobject) { rimvale::CombatManager::instance().set_dungeon_mode(false); }
JNIEXPORT jintArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getDungeonMap(JNIEnv *env, jobject) {
    const auto* m = rimvale::DungeonManager::instance().get_map(); if (!m) return env->NewIntArray(0);
    int s = rimvale::DungeonMap::SIZE * rimvale::DungeonMap::SIZE; jintArray res = env->NewIntArray(s);
    std::vector<int> b; for (int y=0; y<rimvale::DungeonMap::SIZE; ++y) for (int x=0; x<rimvale::DungeonMap::SIZE; ++x) b.push_back(static_cast<int>(m->get_tile(x,y)));
    env->SetIntArrayRegion(res, 0, s, b.data()); return res;
}
JNIEXPORT jintArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getDungeonElevation(JNIEnv *env, jobject) {
    const auto* m = rimvale::DungeonManager::instance().get_map();
    int s = rimvale::DungeonMap::SIZE * rimvale::DungeonMap::SIZE; jintArray res = env->NewIntArray(s);
    std::vector<int> b; b.reserve(s);
    for (int y=0; y<rimvale::DungeonMap::SIZE; ++y) for (int x=0; x<rimvale::DungeonMap::SIZE; ++x) b.push_back(m ? m->get_elevation(x,y) : 1);
    env->SetIntArrayRegion(res, 0, s, b.data()); return res;
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getDungeonEntities(JNIEnv *env, jobject) {
    const auto& ent = rimvale::DungeonManager::instance().get_entities();
    jclass sa = env->FindClass("[Ljava/lang/String;"); jobjectArray res = env->NewObjectArray(static_cast<jsize>(ent.size()), sa, nullptr);
    for (size_t i=0; i<ent.size(); ++i) { std::vector<std::string> d = { ent[i].id, ent[i].name, std::to_string(ent[i].position.x), std::to_string(ent[i].position.y), ent[i].is_player ? "true" : "false", std::to_string(ent[i].handle), ent[i].is_dead ? "true" : "false", ent[i].is_friendly ? "true" : "false" }; env->SetObjectArrayElement(res, static_cast<jsize>(i), to_jstring_array(env, d)); }
    return res;
}
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_moveDungeonPlayer(JNIEnv *env, jobject, jstring id, jint x, jint y) {
    const char *nid = env->GetStringUTFChars(id, nullptr);
    std::string sid(nid);
    env->ReleaseStringUTFChars(id, nid);

    // Walk each step of the path through perform_action(Move) so that
    // movement_tiles_remaining and AP are correctly tracked per the rules:
    //   - First speed/5 tiles each turn cost 0 AP (free move)
    //   - Additional movement costs 1 AP per speed/5 tiles (extra action)
    auto path = rimvale::DungeonManager::instance().get_path(sid, x, y);
    if (path.empty()) return false;

    rimvale::CombatManager::instance().set_current_combatant_by_id(sid);
    rimvale::Dice dice;
    bool moved = false;
    for (const auto& step : path) {
        std::string param = std::to_string(step.x) + "|" + std::to_string(step.y);
        if (!rimvale::CombatManager::instance().perform_action(rimvale::ActionType::Move, dice, param)) {
            break; // Ran out of movement budget and AP
        }
        moved = true;
    }
    return moved;
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getValidDungeonMoves(JNIEnv *env, jobject, jstring id) {
    const char *nid = env->GetStringUTFChars(id, nullptr); auto moves = rimvale::DungeonManager::instance().get_reachable_tiles(nid); env->ReleaseStringUTFChars(id, nid);
    jclass sa = env->FindClass("[Ljava/lang/String;"); jobjectArray res = env->NewObjectArray(static_cast<jsize>(moves.size()), sa, nullptr);
    for (size_t i=0; i<moves.size(); ++i) { std::vector<std::string> md = { std::to_string(moves[i].first.x), std::to_string(moves[i].first.y), std::to_string(moves[i].second) }; env->SetObjectArrayElement(res, static_cast<jsize>(i), to_jstring_array(env, md)); }
    return res;
}
JNIEXPORT jboolean JNICALL Java_com_rimvale_mobile_RimvaleEngine_isDungeonPlayerPhase(JNIEnv*, jobject) { return rimvale::DungeonManager::instance().is_player_phase(); }
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getLineageTraitStates(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h);
    if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    const std::string& ln = c->get_lineage().name;
    std::vector<std::string> states;
    // Plains lineages
    if (ln == "Bouncian") {
        states.push_back("BoundingEscape:" + std::string(c->sr_bouncian_escape_available_ ? "true" : "false"));
    } else if (ln == "Goldscale") {
        states.push_back("HeatedScalesToggle:true");
        states.push_back("SunsFavor:" + std::string(c->lr_goldscale_sun_favor_available_ ? "true" : "false"));
    } else if (ln == "Ironhide") {
        states.push_back("ArmoredPlating:" + std::string(c->lr_ironhide_plating_available_ ? "true" : "false"));
        states.push_back("MechanicalMindRecall:" + std::string(c->sr_ironhide_mind_available_ ? "true" : "false"));
    } else if (ln == "Verdant") {
        states.push_back("Regrowth:" + std::string(c->sr_verdant_regrowth_available_ ? "true" : "false"));
        states.push_back("NaturesVoice:" + std::string(c->lr_verdant_natures_voice_available_ ? "true" : "false"));
    } else if (ln == "Vulpin") {
        states.push_back("IllusoryEcho:" + std::string(c->lr_vulpin_echo_available_ ? "true" : "false"));
        states.push_back("TrickstersDodge:true");
    // SubEden lineages
    } else if (ln == "Bramblekin") {
        states.push_back("Photosynthesis:true"); // costs 1 SP per use, no per-rest limit
    } else if (ln == "Fae-Touched Human") {
        states.push_back("FeyStep:true"); // costs 1 AP per use, always available
        states.push_back("EnchantingPresence:" + std::string(c->sr_fae_enchanting_available_ ? "true" : "false"));
    } else if (ln == "Myconid") {
        states.push_back("SporeCloud:" + std::string(c->lr_myconid_spore_available_ ? "true" : "false"));
        states.push_back("FungalFortitude:" + std::string(c->sr_myconid_fortitude_available_ ? "true" : "false"));
    // Eternal Library lineages
    } else if (ln == "Bookborn") {
        if (!c->bookborn_origami_active_) states.push_back("Origami:true");
        else states.push_back("OrigamiMaintain:true");
        // PaperWard is fully passive (auto-triggers in take_damage)
    } else if (ln == "Archivist") {
        states.push_back("MnemonicRecall:" + std::string(c->sr_archivist_recall_available_ ? "true" : "false"));
    } else if (ln == "Panoplian") {
        states.push_back("SentinelStand:true"); // always available each turn (resets on start_turn)
    // House of Arachana lineages
    } else if (ln == "Blackroot") {
        states.push_back("ToxicRoots:" + std::string(c->lr_toxic_roots_available_ ? "true" : "false"));
        states.push_back("WitherbornDecay:" + std::string(c->lr_witherborn_decay_available_ ? "true" : "false"));
    } else if (ln == "Bloodsilk Human") {
        states.push_back("SilkenTrap:" + std::string(c->sr_silken_trap_available_ ? "true" : "false"));
        states.push_back("DrainingFangs:true"); // 1 AP per use, no per-rest limit
    } else if (ln == "Mirevenom") {
        states.push_back("LurkerStep:" + std::string(c->sr_lurker_step_available_ ? "true" : "false"));
        // VenomousBlood is fully passive
    } else if (ln == "Serpentine") {
        states.push_back("VenomousBite:true"); // always available, 1 AP
        states.push_back("ExtractVenom:" + std::string(c->lr_serpentine_venom_weapon_available_ ? "true" : "false"));
        states.push_back("HypnoticGaze:true"); // always available, 3 AP
    // Wilds of Endero lineages
    } else if (ln == "Canidar") {
        states.push_back("PackHowl:" + std::string(c->lr_pack_howl_available_ ? "true" : "false"));
        // LoyalStrike is a passive auto-reaction; no button
    } else if (ln == "Cervin") {
        states.push_back("NaturesGrace:" + std::string(c->lr_natures_grace_available_ ? "true" : "false"));
    } else if (ln == "Tetrasimian") {
        states.push_back("AdaptiveHide:true"); // always available; no per-rest limit
    } else if (ln == "Thornwrought Human") {
        states.push_back("VerdantCurse:" + std::string(c->lr_verdant_curse_available_ ? "true" : "false"));
        // BarbedEmbrace and poison resistance are passive
    // Beetlefolk and Lithari are fully passive; no active buttons needed
    // Qunorum lineages
    } else if (ln == "Grimshell") {
        // HeavyFrame is a passive reaction; no active button. TombCore is also passive.
    } else if (ln == "Hearthkin") {
        states.push_back("KindleFlame:" + std::string(c->lr_kindle_flame_available_ ? "true" : "false"));
    } else if (ln == "Kindlekin") {
        states.push_back("AlchemicalAffinity:" + std::string(c->lr_alchemical_affinity_available_ ? "true" : "false"));
    } else if (ln == "Regal Human") {
        states.push_back("ResilientSpirit:" + std::string(c->sr_resilient_spirit_uses_ > 0 ? "true" : "false"));
        states.push_back("VersatileGrant:" + std::string(c->lr_versatile_grant_remaining_ > 0 ? "true" : "false"));
    } else if (ln == "Quillari") {
        states.push_back("QuillLaunch:" + std::string(c->lr_quill_launch_available_ ? "true" : "false"));
        states.push_back("QuickReflexes:" + std::string(c->sr_quick_reflexes_available_ ? "true" : "false"));
    // Metropolitan lineages
    } else if (ln == "Arcanite Human") {
        states.push_back("ArcaneSurge:" + std::string(c->lr_arcane_surge_available_ ? "true" : "false"));
    } else if (ln == "Groblodyte") {
        states.push_back("ScrapInstinct:" + std::string(c->sr_groblodyte_scrap_available_ ? "true" : "false"));
    } else if (ln == "Kettlekyn") {
        states.push_back("SteamJet:" + std::string(c->lr_steam_jet_available_ ? "true" : "false"));
    } else if (ln == "Marionox") {
        states.push_back("TetherStep:" + std::string(c->lr_tether_step_available_ ? "true" : "false"));
    } else if (ln == "Voxshell") {
        states.push_back("ResonantVoice:" + std::string(c->sr_resonant_voice_uses_ > 0 ? "true" : "false"));
    // Upper Forty lineages
    } else if (ln == "Gilded Human") {
        states.push_back("MarketWhisperer:" + std::string(c->lr_market_whisperer_available_ ? "true" : "false"));
    } else if (ln == "Gremlidian") {
        states.push_back("ArcaneTinker:" + std::string(c->lr_arcane_tinker_available_ ? "true" : "false"));
        states.push_back("GremlinsLuck:" + std::string(c->sr_gremlins_luck_uses_ > 0 ? "true" : "false"));
    } else if (ln == "Hexkin") {
        states.push_back("HexMark:" + std::string(c->lr_hex_mark_available_ ? "true" : "false"));
        states.push_back("Witchblood:" + std::string(c->sr_witchblood_available_ ? "true" : "false"));
    } else if (ln == "Voxilite") {
        states.push_back("CommandingVoice:" + std::string(c->lr_commanding_voice_available_ ? "true" : "false"));
    // Lower Forty lineages
    } else if (ln == "Ferrusk") {
        states.push_back("OverdriveCore:" + std::string(c->sr_overdrive_core_available_ ? "true" : "false"));
    } else if (ln == "Gremlin") {
        states.push_back("GremlinTinker:" + std::string(c->lr_gremlin_tinker_available_ ? "true" : "false"));
        states.push_back("GremlinSabotage:" + std::string(c->sr_gremlin_sabotage_available_ ? "true" : "false"));
    } else if (ln == "Hexshell") {
        states.push_back("ReflectHex:" + std::string(c->lr_reflect_hex_available_ ? "true" : "false"));
    } else if (ln == "Ironjaw") {
        states.push_back("IronStomachPoison:" + std::string(c->sr_iron_stomach_available_ ? "true" : "false"));
    } else if (ln == "Scavenger Human") {
        states.push_back("ScrapSense:" + std::string(c->sr_scrap_sense_available_ ? "true" : "false"));
    // Shadows Beneath lineages
    } else if (ln == "Corvian") {
        states.push_back("ShadowGlide:true"); // 3 AP, no per-rest limit
    } else if (ln == "Duskling") {
        states.push_back("Shadowgrasp:true"); // 3 AP, no per-rest limit
    } else if (ln == "Duckslings") {
        states.push_back("QuackAlarm:" + std::string(c->lr_quack_alarm_available_ ? "true" : "false"));
    } else if (ln == "Hollowborn Human") {
        // Fully passive (Undead Resilience, Deathless)
    } else if (ln == "Sable") {
        states.push_back("SableNightVision:" + std::string(c->lr_sable_night_vision_available_ ? "true" : "false"));
    } else if (ln == "Twilightkin") {
        states.push_back("Veilstep:" + std::string(c->sr_veilstep_available_ ? "true" : "false"));
        states.push_back("DuskbornGrace:" + std::string(c->sr_duskborn_grace_available_ ? "true" : "false"));
    // Corrupted Marshes lineages
    } else if (ln == "Bogtender") {
        states.push_back("MossyShroud:" + std::string(c->lr_mossy_shroud_available_ ? "true" : "false"));
    } else if (ln == "Mireborn Human") {
        states.push_back("MireBurst:" + std::string(c->sr_mire_burst_available_ ? "true" : "false"));
    } else if (ln == "Myrrhkin") {
        states.push_back("SoothingAura:" + std::string(c->lr_soothing_aura_available_ ? "true" : "false"));
        states.push_back("Dreamscent:" + std::string(c->lr_dreamscent_available_ ? "true" : "false"));
    } else if (ln == "Oozeling") {
        // Amorphous Form and Corrosive Touch are fully passive
    // Crypt at the End of the Valley lineages
    } else if (ln == "Blood Spawn") {
        states.push_back("BloodlettingBlow:true"); // 3 AP, no per-rest limit
    } else if (ln == "Cryptkin Human") {
        states.push_back("Boneclatter:true"); // 3 AP, no per-rest limit
        states.push_back("DiseasebornCurse:" + std::string(c->lr_diseaseborn_curse_available_ ? "true" : "false"));
    } else if (ln == "Gloomling") {
        states.push_back("UmbralDodge:true"); // 3 AP, no per-rest limit
    } else if (ln == "Skulkin") {
        states.push_back("GnawingGrin:" + std::string(c->lr_gnawing_grin_available_ ? "true" : "false"));
    // Spindle York's Schism lineages
    } else if (ln == "Cragborn Human") {
        // Earth's Embrace and Stonecunning are passive
    } else if (ln == "Gravari") {
        states.push_back("StonesEndurance:" + std::string(c->sr_stones_endurance_uses_ > 0 ? "true" : "false"));
    } else if (ln == "Graveleaps") {
        // Stoneclimb and Gravebound Leap are passive/narrative
    } else if (ln == "Shardkin") {
        states.push_back("CrystalResilience:true"); // toggle, always available
        states.push_back("HarmonicLink:" + std::string(c->lr_harmonic_link_available_ ? "true" : "false"));
    // Peaks of Isolation lineages
    } else if (ln == "Boreal Human") {
        states.push_back("WinterBreath:true"); // 3 AP, unlimited
    } else if (ln == "Frostborn") {
        states.push_back("FrostBurst:" + std::string(c->sr_frost_burst_available_ ? "true" : "false"));
        states.push_back("FrostbornIcewalk:" + std::string(c->sr_frostborn_icewalk_available_ ? "true" : "false"));
    } else if (ln == "Glaceari") {
        states.push_back("FrozenVeil:" + std::string(c->lr_frozen_veil_available_ ? "true" : "false"));
    } else if (ln == "Nimbari") {
        states.push_back("StormCall:true"); // 3 AP, unlimited
    } else if (ln == "Tombwalker") {
        states.push_back("GraveBind:true"); // 3 AP, unlimited
        // Deathless Endurance is passive (auto-triggers in take_damage)
    // Pharaoh's Den lineages
    } else if (ln == "Chokeling") {
        states.push_back("Sporespit:true"); // 3 AP, unlimited
        states.push_back("RotbornItem:" + std::string(c->lr_rotborn_item_available_ ? "true" : "false"));
    } else if (ln == "Crimson Veil") {
        states.push_back("BloodlettingTouch:true"); // 3 AP, unlimited
        states.push_back("VelvetTerror:true"); // SP-gated, always available button
    } else if (ln == "Jackal Human") {
        states.push_back("TombSense:" + std::string(c->lr_tomb_sense_available_ ? "true" : "false"));
    } else if (ln == "Whisperspawn") {
        states.push_back("Mindscratch:" + std::string(c->sr_mindscratch_available_ ? "true" : "false"));
    // The Darkness lineages
    } else if (ln == "Gravemantle") {
        states.push_back("GravitationalLeap:" + std::string(c->sr_gravitational_leap_available_ ? "true" : "false"));
    } else if (ln == "Nightborne Human") {
        states.push_back("NightborneVeilstep:true"); // 3 AP, unlimited
        states.push_back("CreepingDark:" + std::string(c->lr_creeping_dark_available_ ? "true" : "false"));
    } else if (ln == "Snareling") {
        // Ambusher's Gift and Tangle Teeth are passive
    // Arcane Collapse lineages
    } else if (ln == "Blightmire") {
        states.push_back("AbsorbMagic:" + std::string(c->sr_absorb_magic_available_ ? "true" : "false"));
    } else if (ln == "Dregspawn") {
        states.push_back("DregspawnExtend:" + std::string(c->sr_dregspawn_extend_available_ ? "true" : "false"));
        states.push_back("AberrantFlex:" + std::string(c->sr_aberrant_flex_available_ ? "true" : "false"));
    } else if (ln == "Nullborn") {
        states.push_back("VoidAura:" + std::string((c->lr_void_aura_available_ || c->current_sp_ >= 6) ? "true" : "false"));
    } else if (ln == "Shardwraith") {
        states.push_back("CrystalSlash:" + std::string(c->sr_crystal_slash_available_ ? "true" : "false"));
    // Argent Hall lineages
    } else if (ln == "Argent Dvarrim") {
        states.push_back("SealOfFrost:true"); // SP-gated
        states.push_back("SilentLedger:true"); // toggle, always available
    } else if (ln == "Frostbound Dvarrim") {
        states.push_back("GlacialWall:true"); // toggle, always available
        states.push_back("UnyieldingBulwark:true"); // SP-gated
    } else if (ln == "Stonemind Dvarrim") {
        states.push_back("StoneMoldReshape:true"); // SP-gated
        states.push_back("ArchitectsShield:true"); // toggle, always available
    } else if (ln == "Glaciervein Dvarrim") {
        states.push_back("MinersInstinct:true"); // toggle, always available
    // ===== THE GLASS PASSAGE =====
    } else if (ln == "Galesworn Human") {
        states.push_back("WindCloak:" + std::string(c->lr_wind_step_available_ ? "true" : "false"));
        states.push_back("Gustcaller:true");
    } else if (ln == "Pangol") {
        states.push_back("PangolArmorReact:" + std::string(c->lr_pangol_armor_reaction_uses_ > 0 ? "true" : "false"));
        states.push_back("CurlUp:" + std::string(c->sr_curl_up_available_ ? "true" : "false"));
        if (c->curl_up_active_) states.push_back("Uncurl:true");
    } else if (ln == "Porcelari") {
        states.push_back("GildedBearing:" + std::string(c->sr_gilded_bearing_available_ ? "true" : "false"));
    } else if (ln == "Prismari") {
        states.push_back("ChromaticShift:" + std::string(c->sr_chromatic_shift_available_ ? "true" : "false"));
        states.push_back("PrismaticReflection:" + std::string(c->lr_prismatic_reflection_available_ ? "true" : "false"));
    } else if (ln == "Rustspawn") {
        // Passive lineage — no active buttons
    // ===== SACRAL SEPARATION =====
    } else if (ln == "Dustborn") {
        states.push_back("DustShroud:" + std::string(c->lr_dust_shroud_available_ ? "true" : "false"));
        if (c->dust_shroud_rounds_ > 0) states.push_back("DustStrike:true");
    } else if (ln == "Glassborn") {
        states.push_back("ShatterPulseGlassborn:" + std::string(c->lr_shatter_pulse_glassborn_available_ ? "true" : "false"));
        states.push_back("PrismVeins:" + std::string(c->sr_prism_veins_available_ ? "true" : "false"));
    } else if (ln == "Gravetouched") {
        states.push_back("DeathsWhisper:" + std::string(c->lr_deaths_whisper_available_ ? "true" : "false"));
    } else if (ln == "Madness-Touched Human") {
        states.push_back("UnstableMutation:true");
        states.push_back("FracturedMind:" + std::string(c->get_insanity_level() > 0 ? "true" : "false"));
    // ===== THE INFERNAL MACHINE =====
    } else if (ln == "Candlites") {
        states.push_back("LuminousToggle:true");
        if (c->candlite_flame_lit_) states.push_back("WaxenForm:true");
    } else if (ln == "Flenskin") {
        states.push_back("PainMadeFlesh:" + std::string(c->lr_pain_made_flesh_available_ ? "true" : "false"));
    } else if (ln == "Hellforged") {
        states.push_back("InfernalStare:" + std::string(c->lr_infernal_stare_available_ ? "true" : "false"));
        states.push_back("InfernalSmite:" + std::string(c->sr_infernal_smite_available_ ? "true" : "false"));
    } else if (ln == "Obsidian Seraph") {
        // Passive (Cracked Resilience) — no active buttons
    } else if (ln == "Scourling Human") {
        states.push_back("WhipLash:true");
    // ===== TITAN'S LAMENT =====
    } else if (ln == "Ashenborn") {
        states.push_back("CursedSpark:" + std::string(c->sr_cursed_spark_available_ ? "true" : "false"));
    } else if (ln == "Sandstrider Human") {
        states.push_back("DesertWalker:" + std::string(c->lr_desert_walker_available_ ? "true" : "false"));
    } else if (ln == "Taurin") {
        states.push_back("Gore:" + std::string(c->sr_gore_uses_ > 0 ? "true" : "false"));
        states.push_back("StubbornWill:" + std::string(c->sr_stubborn_will_available_ ? "true" : "false"));
    } else if (ln == "Ursari") {
        states.push_back("HibernateUrsari:" + std::string(c->lr_hibernate_available_ ? "true" : "false"));
    } else if (ln == "Volcant") {
        // Lava Burst is passive — no button
    // ===== THE MORTAL ARENA =====
    } else if (ln == "Emberkin") {
        states.push_back("Blazeblood:" + std::string(c->sr_blazeblood_available_ ? "true" : "false"));
        states.push_back("SootSight:" + std::string(c->lr_soot_sight_available_ ? "true" : "false"));
    } else if (ln == "Saurian") {
        // Tail Lash and Scaled Resilience are passive reactions — no button
    } else if (ln == "Stormclad") {
        states.push_back("ShockPulse:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    } else if (ln == "Sunderborn Human") {
        states.push_back("SunderbornHibernate:" + std::string(c->lr_sunderborn_hibernate_available_ ? "true" : "false"));
        states.push_back("LimbRegrowth:" + std::string(c->current_sp_ >= 2 ? "true" : "false"));
    // ===== VULCAN VALLEY =====
    } else if (ln == "Ashrot Human") {
        states.push_back("AshrotAuraToggle:true");
        states.push_back("AshrotAuraBurst:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    } else if (ln == "Cindervolk") {
        states.push_back("SmolderingGlare:" + std::string(c->lr_smoldering_glare_available_ ? "true" : "false"));
    } else if (ln == "Drakari") {
        states.push_back("DraconicAwakening:" + std::string((c->lr_draconic_awakening_available_ || c->current_sp_ >= 4) ? "true" : "false"));
        states.push_back("BreathWeapon:true");
    } else if (ln == "Obsidian") {
        // Shard Skin and Magma Blood are passive — no button
    } else if (ln == "Scornshard") {
        // Fracture Burst and Crackling Edge are passive — no button
    // ===== THE ISLES =====
    } else if (ln == "Abyssari") {
        states.push_back("AbyssariGlowToggle:true");
        states.push_back("AbyssariPulse:" + std::string(c->lr_abyssari_pulse_available_ ? "true" : "false"));
    } else if (ln == "Mireling") {
        states.push_back("MirelingEscape:" + std::string(c->lr_mireling_escape_available_ ? "true" : "false"));
    } else if (ln == "Moonkin") {
        states.push_back("LunarRadiance:" + std::string(c->lr_lunar_radiance_available_ ? "true" : "false"));
    } else if (ln == "Tiderunner Human") {
        states.push_back("BrineCone:true");
        states.push_back("EbbAndFlow:" + std::string(c->lr_ebb_flow_uses_ > 0 ? "true" : "false"));
    // ===== THE DEPTHS OF DENORIM =====
    } else if (ln == "Driftwood Woken") {
        // Fire and cold resistance are passive — no button
    } else if (ln == "Fathomari") {
        // Cold resistance is passive — no button
    } else if (ln == "Hydrakari") {
        states.push_back("HydrasResilience:" + std::string(c->sr_hydras_resilience_available_ ? "true" : "false"));
        states.push_back("LimbSacrifice:" + std::string(c->lr_hydra_limb_sacrifice_available_ ? "true" : "false"));
    } else if (ln == "Kelpheart Human") {
        states.push_back("Tidebind:true");
    } else if (ln == "Trenchborn") {
        states.push_back("AbyssalMutation:" + std::string(c->sr_abyssal_mutation_available_ ? "true" : "false"));
    // ===== MOROBOROS =====
    } else if (ln == "Cloudling") {
        states.push_back("CloudlingFly:true");
        states.push_back("MistForm:" + std::string((c->sr_mist_form_available_ || c->current_sp_ >= 1) ? "true" : "false"));
    } else if (ln == "Rotborn Herald") {
        states.push_back("RotVoice:true");
    } else if (ln == "Tidewoven") {
        states.push_back("SurgeStep:true");
    } else if (ln == "Venari") {
        states.push_back("HuntersFocus:" + std::string(c->lr_hunters_focus_available_ ? "true" : "false"));
    } else if (ln == "Weirkin Human") {
        states.push_back("WeirdResilience:" + std::string(c->lr_weird_resilience_available_ ? "true" : "false"));
    // ===== GLOAMFEN HOLLOW =====
    } else if (ln == "Bilecrawler") {
        // Corrosive Slime is passive — no button
    } else if (ln == "Huskdrone") {
        states.push_back("VoluntaryGasVent:" + std::string(c->lr_voluntary_gas_vent_available_ ? "true" : "false"));
    } else if (ln == "Bloatfen Whisperer") {
        states.push_back("ObedientAuraToggle:true");
    } else if (ln == "Filthlit Spawn") {
        // Toxic Form is passive — no button
    } else if (ln == "Hagborn Crone") {
        states.push_back("MemoryEchoToggle:true");
        states.push_back("LeechHex:true");
        states.push_back("WitchsDraught:true");
        states.push_back("HexOfWithering:true");
    // ===== THE ASTRAL TEAR =====
    } else if (ln == "Aetherian") {
        states.push_back("EtherealStep:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
        states.push_back("VeiledPresence:" + std::string(c->lr_veiled_presence_available_ ? "true" : "false"));
    } else if (ln == "Convergents") {
        states.push_back("ConvergentSynthesis:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    } else if (ln == "Dreamer") {
        states.push_back("Dreamwalk:" + std::string(c->lr_dreamwalk_available_ ? "true" : "false"));
    } else if (ln == "Riftborn Human") {
        states.push_back("PhaseStep:true");
        states.push_back("Flicker:" + std::string(c->sr_flicker_available_ ? "true" : "false"));
    } else if (ln == "Shadewretch") {
        states.push_back("Shadowmeld:" + std::string(c->lr_shadowmeld_available_ ? "true" : "false"));
    } else if (ln == "Umbrawyrm") {
        states.push_back("VoidStep:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    // ===== L.I.T.O. =====
    } else if (ln == "Corrupted Wyrmblood") {
        states.push_back("CorruptBreath:true");
        states.push_back("DarkLineagePulse:" + std::string(c->lr_dark_lineage_uses_ > 0 ? "true" : "false"));
    } else if (ln == "Hollowroot") {
        states.push_back("SapHealing:" + std::string(c->sr_sap_healing_available_ ? "true" : "false"));
    } else if (ln == "Nihilian") {
        states.push_back("EntropyTouch:true");
        states.push_back("Unravel:" + std::string(c->lr_unravel_available_ ? "true" : "false"));
    } else if (ln == "Oblivari Human") {
        states.push_back("MindBleed:" + std::string(c->lr_mind_bleed_available_ ? "true" : "false"));
        states.push_back("NullMindShare:" + std::string(c->lr_null_mind_share_available_ ? "true" : "false"));
    } else if (ln == "Sludgeling") {
        states.push_back("AmorphousSplit:" + std::string(c->lr_amorphous_split_available_ ? "true" : "false"));
        states.push_back("ToxicSeep:true");
    // ===== THE WEST END GULLET =====
    } else if (ln == "Carrionari") {
        states.push_back("DeathEaterMemory:" + std::string(c->lr_death_eater_memory_available_ ? "true" : "false"));
        states.push_back("WingsOfForgotten:true");
    } else if (ln == "Disjointed Hounds") {
        states.push_back("ShiftingFormToggle:true");
        states.push_back("DisjointedLeap:" + std::string(c->sr_disjointed_leap_available_ ? "true" : "false"));
    } else if (ln == "Lost") {
        states.push_back("TemporalFlicker:" + std::string(c->lr_temporal_flicker_available_ ? "true" : "false"));
        states.push_back("HauntingWail:true");
    } else if (ln == "Gullet Mimes") {
        states.push_back("MirrorMove:true");
        states.push_back("SilentScream:" + std::string(c->lr_silent_scream_available_ ? "true" : "false"));
    } else if (ln == "Parallax Watchers") {
        states.push_back("RealitySlip:" + std::string(c->sr_reality_slip_available_ ? "true" : "false"));
        states.push_back("UnnervinGaze:true");
    // ===== THE CRADLING DEPTHS =====
    } else if (ln == "Echo-Touched") {
        states.push_back("ResonantFormMimic:" + std::string(c->sr_resonant_form_available_ ? "true" : "false"));
        states.push_back("DivineMimicry:" + std::string(c->lr_divine_mimicry_available_ ? "true" : "false"));
    } else if (ln == "Lifeborne") {
        states.push_back("VitalSurge:" + std::string(c->vital_surge_pool_ > 0 ? "true" : "false"));
        states.push_back("AbyssalGlow:" + std::string(c->lr_abyssal_glow_available_ ? "true" : "false"));
    // ===== TERMINUS VOLARUS =====
    } else if (ln == "Lanternborn") {
        states.push_back("LanternbornGlowToggle:true");
        states.push_back("GuidingLight:true");
    } else if (ln == "Luminar Human") {
        states.push_back("BeaconAbsorb:" + std::string(c->sr_beacon_available_ ? "true" : "false"));
    } else if (ln == "Skysworn") {
        states.push_back("KeenSightFocus:true");
    } else if (ln == "Starborn") {
        states.push_back("RadiantPulse:true");
    // ===== THE CITY OF ETERNAL LIGHT =====
    } else if (ln == "Auroran") {
        states.push_back("LightStepTeleport:" + std::string(c->sr_light_step_available_ ? "true" : "false"));
        states.push_back("DawnsBlessingActivate:" + std::string(c->lr_dawns_blessing_available_ ? "true" : "false"));
    } else if (ln == "Lightbound") {
        states.push_back("RadiantWard:" + std::string(c->sr_radiant_ward_available_ ? "true" : "false"));
        states.push_back("Flareburst:" + std::string(c->sr_flareburst_available_ ? "true" : "false"));
    } else if (ln == "Runeborn Human") {
        states.push_back("RunicSurgePrime:" + std::string(c->lr_runic_surge_available_ ? "true" : "false"));
        states.push_back("MysticPulse:" + std::string(c->sr_mystic_pulse_available_ ? "true" : "false"));
    } else if (ln == "Zephyrkin") {
        states.push_back("Windstep:" + std::string(c->sr_windstep_uses_ > 0 ? "true" : "false"));
    // ===== THE HALLOWED SACRAMENT =====
    } else if (ln == "Glimmerfolk") {
        states.push_back("GlimmerfolkGlowToggle:true");
        states.push_back("Dazzle:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    } else if (ln == "Mistborn Human") {
        states.push_back("VaporFormActivate:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
        states.push_back("DriftingFog:" + std::string(c->lr_drifting_fog_available_ ? "true" : "false"));
    } else if (ln == "Mossling") {
        states.push_back("SporeBloom:" + std::string(c->lr_spore_bloom_available_ ? "true" : "false"));
    } else if (ln == "Zephyrite") {
        states.push_back("WindswiftActivate:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    // ===== THE LAND OF TOMORROW =====
    } else if (ln == "Chronogears") {
        states.push_back("TemporalShift:" + std::string(c->sr_temporal_shift_available_ ? "true" : "false"));
    } else if (ln == "Silverblood") {
        states.push_back("ArcanePulse:" + std::string(c->lr_arcane_pulse_available_ ? "true" : "false"));
        states.push_back("RunicFlowAuto:" + std::string(c->lr_runic_flow_auto_available_ ? "true" : "false"));
    } else if (ln == "Sparkforged Human") {
        states.push_back("SparkforgedArcaneSurge:" + std::string(c->lr_sparkforged_arcane_surge_available_ ? "true" : "false"));
    } else if (ln == "Watchling") {
        states.push_back("StaticSurge:true");
    // ===== SUBLIMINI DOMINUS =====
    } else if (ln == "Echoform Warden") {
        states.push_back("EchoReflection:true");
        states.push_back("MemoryTap:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    } else if (ln == "Nullborn Ascetic") {
        states.push_back("VoidCloakToggle:true");
        states.push_back("SpellSink:true");
    } else if (ln == "Mistborne Hatchling") {
        states.push_back("WarpResistanceToggle:true");
        states.push_back("SurgePulse:" + std::string(c->current_sp_ >= 1 ? "true" : "false"));
    // ===== BEATING HEART OF THE VOID =====
    } else if (ln == "Bespoker") {
        states.push_back("ParalyzingRay:" + std::string(c->bespoker_last_ray_name_ != "ParalyzingRay" ? "true" : "false"));
        states.push_back("FearRay:" + std::string(c->bespoker_last_ray_name_ != "FearRay" ? "true" : "false"));
        states.push_back("HealingRay:" + std::string(c->bespoker_last_ray_name_ != "HealingRay" ? "true" : "false"));
        states.push_back("NecroticRay:" + std::string(c->bespoker_last_ray_name_ != "NecroticRay" ? "true" : "false"));
        states.push_back("DisintegrationRay:" + std::string(c->bespoker_last_ray_name_ != "DisintegrationRay" ? "true" : "false"));
        states.push_back("AntiMagicConeToggle:true");
    } else if (ln == "Brain Eater") {
        states.push_back("NeuralLiquefaction:true");
        states.push_back("SkullDrill:true");
    } else if (ln == "Pulsebound Hierophant") {
        states.push_back("ResonantSermonToggle:true");
        states.push_back("VoidCommunion:" + std::string(c->lr_void_communion_available_ ? "true" : "false"));
    } else if (ln == "Threnody Warden") {
        states.push_back("ThrenodySlamAttack:true");
    }
    return to_jstring_array(env, states);
}
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_collectLoot(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h); auto loot = rimvale::DungeonManager::instance().collect_loot(c); return to_jstring_array(env, loot);
}

// Stat feat active action states — returns "ActionId:available" pairs for active stat feat buttons
JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getFeatActionStates(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h);
    if (!c) return env->NewObjectArray(0, env->FindClass("java/lang/String"), env->NewStringUTF(""));
    std::vector<std::string> states;
    int aw_tier = c->get_feat_tier(rimvale::FeatID::ArcaneWellspring);
    if (aw_tier >= 1) states.push_back("DeepReserves:" + std::string(c->aw_deep_reserves_lr_available_ ? "true" : "false"));
    if (aw_tier >= 3) states.push_back("SpellEchoArm:" + std::string(c->aw_spell_echo_enc_available_ ? "true" : "false"));
    if (aw_tier >= 5) states.push_back("InfiniteFont:" + std::string(c->aw_infinite_font_lr_available_ ? "true" : "false"));
    int mf_tier = c->get_feat_tier(rimvale::FeatID::MartialFocus);
    if (mf_tier >= 1) states.push_back("BattleReady:" + std::string(c->mf_battle_ready_enc_available_ ? "true" : "false"));
    int iv_tier = c->get_feat_tier(rimvale::FeatID::IronVitality);
    if (iv_tier >= 3) states.push_back("EnduringHeal:" + std::string(c->iv_enduring_spirit_lr_available_ ? "true" : "false"));
    int sg_tier = c->get_feat_tier(rimvale::FeatID::Safeguard);
    if (sg_tier >= 1) states.push_back("SG_Reroll:" + std::string(c->sg_reroll_lr_available_ ? "true" : "false"));
    if (sg_tier >= 2) states.push_back("SG_Advantage:" + std::string(c->sg_advantage_sr_available_ ? "true" : "false"));
    if (sg_tier >= 4) states.push_back("SG_AutoSucceed:" + std::string(c->sg_auto_succeed_lr_available_ ? "true" : "false"));
    if (sg_tier >= 5) states.push_back("SG_Heal:" + std::string(c->sg_heal_sr_available_ ? "true" : "false"));
    return to_jstring_array(env, states);
}

// Safeguard chosen stats — get/set the stat indices the player chose for Safeguard (0=STR,1=SPD,2=INT,3=VIT,4=DIV)
JNIEXPORT jintArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getSafeguardChosenStats(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h);
    if (!c) { jintArray arr = env->NewIntArray(0); return arr; }
    std::vector<jint> chosen(c->safeguard_chosen_stats_.begin(), c->safeguard_chosen_stats_.end());
    jintArray arr = env->NewIntArray((jsize)chosen.size());
    if (!chosen.empty()) env->SetIntArrayRegion(arr, 0, (jsize)chosen.size(), chosen.data());
    return arr;
}

JNIEXPORT void JNICALL Java_com_rimvale_mobile_RimvaleEngine_setSafeguardChosenStats(JNIEnv *env, jobject, jlong h, jintArray stats) {
    auto* c = rimvale::getSafeChar(h);
    if (!c) return;
    c->safeguard_chosen_stats_.clear();
    jsize len = env->GetArrayLength(stats);
    jint* elems = env->GetIntArrayElements(stats, nullptr);
    for (jsize i = 0; i < len; i++) c->safeguard_chosen_stats_.insert(elems[i]);
    env->ReleaseIntArrayElements(stats, elems, JNI_ABORT);
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCharacterConditions(JNIEnv *env, jobject, jlong h) {
    auto* c = rimvale::getSafeChar(h);
    jclass sc = env->FindClass("java/lang/String");
    if (!c) return env->NewObjectArray(0, sc, env->NewStringUTF(""));
    const auto& conds = c->get_status().get_conditions();
    std::vector<std::string> names;
    if (c->get_status().get_bleed_stacks() > 0) names.push_back("Bleed");
    for (const auto& ct : conds) names.push_back(rimvale::StatusManager::get_condition_name(ct));
    jobjectArray res = env->NewObjectArray(static_cast<jsize>(names.size()), sc, env->NewStringUTF(""));
    for (size_t i = 0; i < names.size(); ++i) env->SetObjectArrayElement(res, static_cast<jsize>(i), env->NewStringUTF(names[i].c_str()));
    return res;
}

JNIEXPORT jobjectArray JNICALL Java_com_rimvale_mobile_RimvaleEngine_getCreatureConditions(JNIEnv *env, jobject, jlong h) {
    auto* cr = reinterpret_cast<rimvale::Creature*>(h);
    jclass sc = env->FindClass("java/lang/String");
    if (!cr) return env->NewObjectArray(0, sc, env->NewStringUTF(""));
    const auto& conds = cr->get_status().get_conditions();
    std::vector<std::string> names;
    for (const auto& ct : conds) names.push_back(rimvale::StatusManager::get_condition_name(ct));
    jobjectArray res = env->NewObjectArray(static_cast<jsize>(names.size()), sc, env->NewStringUTF(""));
    for (size_t i = 0; i < names.size(); ++i) env->SetObjectArrayElement(res, static_cast<jsize>(i), env->NewStringUTF(names[i].c_str()));
    return res;
}

}
