#ifndef RIMVALE_INVENTORY_H
#define RIMVALE_INVENTORY_H

#include "Item.h"
#include <vector>
#include <memory>
#include <algorithm>

namespace rimvale {

class Inventory {
public:
    Inventory() = default;
    ~Inventory() = default;

    // Deep copy
    Inventory(const Inventory& other) : gold_(other.gold_) {
        items_.clear();
        for (const auto& item : other.items_) {
            if (item) {
                items_.push_back(item->clone());
            }
        }
    }

    Inventory& operator=(const Inventory& other) {
        if (this != &other) {
            items_.clear();
            gold_ = other.gold_;
            for (const auto& item : other.items_) {
                if (item) {
                    items_.push_back(item->clone());
                }
            }
        }
        return *this;
    }

    // Move
    Inventory(Inventory&& other) noexcept : items_(std::move(other.items_)), gold_(other.gold_) {
        other.gold_ = 0;
    }

    Inventory& operator=(Inventory&& other) noexcept {
        if (this != &other) {
            items_ = std::move(other.items_);
            gold_ = other.gold_;
            other.gold_ = 0;
        }
        return *this;
    }

    void add_item(std::unique_ptr<Item> item) {
        if (item) {
            items_.push_back(std::move(item));
        }
    }

    void remove_item(const std::string& name) {
        auto it = std::find_if(items_.begin(), items_.end(),
            [&name](const std::unique_ptr<Item>& item) {
                return item->get_name() == name;
            });
        if (it != items_.end()) {
            items_.erase(it);
        }
    }

    [[nodiscard]] const std::vector<std::unique_ptr<Item>>& get_items() const {
        return items_;
    }

    std::vector<std::unique_ptr<Item>> take_all_items() {
        return std::move(items_);
    }

    [[nodiscard]] int get_gold() const { return gold_; }
    void set_gold(int gold) { gold_ = gold; }
    void add_gold(int amount) { gold_ += amount; }

private:
    std::vector<std::unique_ptr<Item>> items_;
    int gold_ = 0;
};

} // namespace rimvale

#endif // RIMVALE_INVENTORY_H
