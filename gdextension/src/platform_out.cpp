// Cross-platform implementation of the aout stream.
// On Android this was provided by AndroidOut.cpp using __android_log_print.
// Here we just route to stdout, which Godot's editor console will capture.
#include "AndroidOut.h"

static AndroidOut androidOut("RimvaleEngine");
std::ostream aout(&androidOut);
