#ifndef RIMVALE_CHARACTER_REGISTRY_H
#define RIMVALE_CHARACTER_REGISTRY_H

#include "Character.h"
#include <mutex>
#include <unordered_map>
#include <string>

namespace rimvale {

class CharacterRegistry {
public:
    static CharacterRegistry& instance() {
        static CharacterRegistry registry;
        return registry;
    }

    void register_character(Character* character) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (character) {
            handle_to_ptr_[reinterpret_cast<int64_t>(character)] = character;
            id_to_ptr_[character->get_id()] = character;
        }
    }

    void unregister_character(int64_t handle) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = handle_to_ptr_.find(handle);
        if (it != handle_to_ptr_.end()) {
            id_to_ptr_.erase(it->second->get_id());
            handle_to_ptr_.erase(it);
        }
    }

    Character* get_character_by_handle(int64_t handle) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = handle_to_ptr_.find(handle);
        return (it != handle_to_ptr_.end()) ? it->second : nullptr;
    }

    Character* get_character_by_id(const std::string& id) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = id_to_ptr_.find(id);
        return (it != id_to_ptr_.end()) ? it->second : nullptr;
    }

    bool is_valid(int64_t handle) {
        std::lock_guard<std::mutex> lock(mutex_);
        return handle_to_ptr_.find(handle) != handle_to_ptr_.end();
    }

private:
    CharacterRegistry() = default;
    std::mutex mutex_;
    std::unordered_map<int64_t, Character*> handle_to_ptr_;
    std::unordered_map<std::string, Character*> id_to_ptr_;
};

} // namespace rimvale

#endif // RIMVALE_CHARACTER_REGISTRY_H
