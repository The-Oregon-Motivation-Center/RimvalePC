#ifndef RIMVALE_CREATURE_REGISTRY_H
#define RIMVALE_CREATURE_REGISTRY_H

#include "Creature.h"
#include <mutex>
#include <unordered_map>
#include <vector>

namespace rimvale {

class CreatureRegistry {
public:
    static CreatureRegistry& instance() {
        static CreatureRegistry registry;
        return registry;
    }

    void register_creature(Creature* creature) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (creature) {
            handle_to_ptr_[reinterpret_cast<int64_t>(creature)] = creature;
        }
    }

    void unregister_creature(int64_t handle) {
        std::lock_guard<std::mutex> lock(mutex_);
        handle_to_ptr_.erase(handle);
    }

    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        handle_to_ptr_.clear();
    }

    Creature* get_creature(int64_t handle) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = handle_to_ptr_.find(handle);
        return (it != handle_to_ptr_.end()) ? it->second : nullptr;
    }

    bool is_valid(int64_t handle) {
        std::lock_guard<std::mutex> lock(mutex_);
        return handle_to_ptr_.find(handle) != handle_to_ptr_.end();
    }

private:
    CreatureRegistry() = default;
    std::mutex mutex_;
    std::unordered_map<int64_t, Creature*> handle_to_ptr_;
};

} // namespace rimvale

#endif // RIMVALE_CREATURE_REGISTRY_H
