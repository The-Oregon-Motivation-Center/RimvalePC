#ifndef RIMVALE_NPC_REGISTRY_H
#define RIMVALE_NPC_REGISTRY_H

#include "NPC.h"
#include <map>
#include <vector>
#include <memory>

namespace rimvale {

class NpcRegistry {
public:
    static NpcRegistry& instance() {
        static NpcRegistry registry;
        return registry;
    }

    [[nodiscard]] std::unique_ptr<NPC> create_npc(const std::string& name) const {
        auto it = npc_templates_.find(name);
        if (it != npc_templates_.end()) {
            auto npc = std::make_unique<NPC>(it->second);
            npc->reset_resources();
            return npc;
        }
        return nullptr;
    }

    [[nodiscard]] std::vector<std::string> get_all_npc_names() const {
        std::vector<std::string> names;
        for (const auto& pair : npc_templates_) names.push_back(pair.first);
        return names;
    }

private:
    NpcRegistry() {
        // --- ACF Leadership ---
        auto thalindra = create_template("Grand Overseer Thalindra", CreatureCategory::Villager, 20, 2, 2, 6, 4, 10);
        thalindra.add_dialogue("Welcome to the Foundation. We safeguard reality itself.", 0);
        thalindra.add_dialogue("The Choir's reach is expanding. We need agents in the field.", 1, "The Whispering Winds");
        thalindra.add_dialogue("I have served for centuries. I have seen what happens when Unity fails.", 2);
        register_npc(std::move(thalindra));

        auto auron = create_template("Archmage Auron Velkari", CreatureCategory::Villager, 15, 3, 2, 5, 4, 8);
        auron.add_dialogue("The cold of the Peaks is honest. It doesn't hide its intent.", 0);
        auron.add_dialogue("Something stirs in the Pharaoh's Den. A chill that isn't from the ice.", 1, "Heart of the Storm");
        register_npc(std::move(auron));

        // --- Eclipsed Enclave / Choir of Reclamation ---
        auto sereth = create_template("High Null Sereth", CreatureCategory::Adversary, 15, 1, 2, 8, 4, 10);
        sereth.add_dialogue("Memory is a parasite. It keeps you chained to a dying world.", -1);
        sereth.add_dialogue("Why cling to a name? Join the Choir, and find true peace.", 0);
        sereth.add_dialogue("The Beating Heart will soon hatch. Your world is but an eggshell.", 1);
        register_npc(std::move(sereth));

        // --- Regional Specialists ---
        auto thalia = create_template("Specialist Thalia Greenmantle", CreatureCategory::Villager, 8, 3, 2, 3, 4, 2);
        thalia.add_dialogue("The Plains seem peaceful, but the grass remembers every drop of blood.", 0);
        thalia.add_dialogue("There's a blight spreading near the orchard. It's... hungry.", 1, "Seeds of Desolation");
        register_npc(std::move(thalia));

        auto syric = create_template("Specialist Syric Venomstrike", CreatureCategory::Villager, 8, 2, 3, 4, 3, 4);
        syric.add_dialogue("In Arachana, you are either the spider or the fly.", 0);
        syric.add_dialogue("The Broodmothers are restless. The webs are vibrating with a new frequency.", 1, "The Weaver's Rebirth");
        register_npc(std::move(syric));
    }

    void register_npc(NPC npc) {
        npc_templates_.emplace(npc.get_name(), std::move(npc));
    }

    NPC create_template(std::string name, CreatureCategory cat, int lvl, int str, int spd, int intel, int vit, int div) {
        NPC npc(std::move(name), cat, lvl);
        auto& s = npc.get_stats();
        s.strength = str; s.speed = spd; s.intellect = intel; s.vitality = vit; s.divinity = div;
        npc.get_drivers().clamp();
        return npc;
    }

    std::map<std::string, NPC> npc_templates_;
};

} // namespace rimvale

#endif // RIMVALE_NPC_REGISTRY_H
