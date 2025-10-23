
#pragma once
#include <cstring>
#include <exception>
#include <string>
namespace pluto {
class logic_error: public std::runtime_error {
private:
    std::string w;

public:
    logic_error(std::string str, const char* file = nullptr, int line = -1):
        std::runtime_error(""),
        w(std::move(str)) {
        if (file == nullptr)
            return;
        w.append("(");
        w.append(file);
        if (line >= 0) {
            w.append(":");
            w.append(std::to_string(line));
        }
        w.append(")");
    }

    logic_error(const logic_error& e) = default;
    logic_error(logic_error&& e) = default;
    logic_error& operator=(const logic_error& e) = default;
    logic_error& operator=(logic_error&& e) = default;

    const char* what() const noexcept override {
        return w.c_str();
    }
};
} // namespace pluto

#if TARGET_PLATFORM == PLATFORM_WINDOWS
    #define __FILENAME__ (strrchr(__FILE__, '\\') ? (strrchr(__FILE__, '\\') + 1) : __FILE__)
#else
    #define __FILENAME__ (strrchr(__FILE__, '/') ? (strrchr(__FILE__, '/') + 1) : __FILE__)
#endif

#define MOON_CHECK(cnd, msg) \
    { \
        if (!(cnd)) \
            throw pluto::logic_error { (msg), __FILENAME__, __LINE__ }; \
    }

#ifdef DEBUG
    #define MOON_ASSERT(cnd, msg) assert(cnd&& msg)
#else
    #define MOON_ASSERT(cnd, msg)
#endif