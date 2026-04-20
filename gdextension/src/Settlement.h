#ifndef RIMVALE_SETTLEMENT_H
#define RIMVALE_SETTLEMENT_H

#include <string>
#include <vector>
#include <map>

namespace rimvale {

enum class SettlementTier {
    Hamlet = 1,
    Village = 2,
    Town = 3,
    City = 4,
    Metropolis = 5
};

struct EconomicData {
    int liquid_wealth_min;
    int liquid_wealth_max;
    int annual_wealth_min;
    int annual_wealth_max;
};

class Settlement {
public:
    Settlement(std::string name, SettlementTier tier)
        : name_(std::move(name)), tier_(tier) {}

    [[nodiscard]] const std::string& get_name() const { return name_; }
    [[nodiscard]] SettlementTier get_tier() const { return tier_; }

    [[nodiscard]] int get_sp_per_day() const {
        // PHB/GMG: Metropolis 100,000+ per day, etc.
        // Small Village: 50-200, Town: 500-2,000, City: 5,000-50,000
        switch (tier_) {
            case SettlementTier::Hamlet: return 20; // Estimated for Hamlet
            case SettlementTier::Village: return 100;
            case SettlementTier::Town: return 1000;
            case SettlementTier::City: return 25000;
            case SettlementTier::Metropolis: return 100000;
            default: return 0;
        }
    }

    [[nodiscard]] EconomicData get_economic_data() const {
        switch (tier_) {
            case SettlementTier::Hamlet: return {100, 500, 1000, 5000};
            case SettlementTier::Village: return {500, 2000, 5000, 20000};
            case SettlementTier::Town: return {2000, 10000, 20000, 100000};
            case SettlementTier::City: return {10000, 50000, 100000, 500000};
            case SettlementTier::Metropolis: return {50000, 250000, 500000, 2500000};
            default: return {0, 0, 0, 0};
        }
    }

private:
    std::string name_;
    SettlementTier tier_;
};

} // namespace rimvale

#endif // RIMVALE_SETTLEMENT_H
