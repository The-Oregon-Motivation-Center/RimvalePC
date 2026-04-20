#ifndef RIMVALE_COSMIC_H
#define RIMVALE_COSMIC_H

#include <string>
#include <vector>
#include <map>

namespace rimvale {

enum class VeyrunPhase { Calm, Flare, Radiant, Dim };
enum class MoonPhase { Silent, EchoPulse, Distortion, Dormant, Ignition, Eruption, Opaque, Translucent, Clear, Stable, Surge, Fracture, Wild };

struct CelestialBody {
    std::string name;
    std::string description;
    std::string current_effect;
};

class CosmicRegistry {
public:
    static CosmicRegistry& instance() {
        static CosmicRegistry registry;
        return registry;
    }

    void advance_time() {
        // Simple logic to cycle phases
        veyrun_index = (veyrun_index + 1) % 4;
        moon_index = (moon_index + 1) % 4;
    }

    [[nodiscard]] std::vector<CelestialBody> get_current_status() const {
        std::vector<CelestialBody> status;

        // Veyrun
        std::string v_effect;
        switch (static_cast<VeyrunPhase>(veyrun_index)) {
            case VeyrunPhase::Calm: v_effect = "Divine magic stabilizes. Ideal for healing."; break;
            case VeyrunPhase::Flare: v_effect = "Teleportation and summoning become volatile."; break;
            case VeyrunPhase::Radiant: v_effect = "Divine spells empowered. Celestial beings descend."; break;
            case VeyrunPhase::Dim: v_effect = "Necrotic and void magic becomes stronger."; break;
        }
        status.push_back({"Veyrun (Star)", "The final breath of Veyra.", v_effect});

        // Example Moon: Dominus Echo
        std::string m_effect;
        switch (moon_index) {
            case 0: m_effect = "Psychic magic suppressed. Memory spells may misfire."; break;
            case 1: m_effect = "Shared dreams. Telepathy and mind-reading are easier."; break;
            case 2: m_effect = "Reality bends around memory. Illusions unstable."; break;
            case 3: m_effect = "Neutral resonance."; break;
        }
        status.push_back({"Dominus Echo", "The tomb of a forgotten Demi-god.", m_effect});

        return status;
    }

private:
    CosmicRegistry() : veyrun_index(0), moon_index(0) {}
    int veyrun_index;
    int moon_index;
};

} // namespace rimvale

#endif // RIMVALE_COSMIC_H
