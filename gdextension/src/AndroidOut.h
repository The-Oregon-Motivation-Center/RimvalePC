#pragma once
// Cross-platform replacement for Android's AndroidOut.h
// Used when building outside of Android (GDExtension, PC, macOS, iOS, etc.)
// The interface is identical so engine source files compile unchanged.

#ifndef ANDROIDGLINVESTIGATIONS_ANDROIDOUT_H
#define ANDROIDGLINVESTIGATIONS_ANDROIDOUT_H

#include <iostream>
#include <sstream>

extern std::ostream aout;

class AndroidOut : public std::stringbuf {
public:
    inline AndroidOut(const char* kLogTag) : logTag_(kLogTag) {}
protected:
    virtual int sync() override {
        std::cout << "[" << logTag_ << "] " << str() << std::flush;
        str("");
        return 0;
    }
private:
    const char* logTag_;
};

#endif // ANDROIDGLINVESTIGATIONS_ANDROIDOUT_H
