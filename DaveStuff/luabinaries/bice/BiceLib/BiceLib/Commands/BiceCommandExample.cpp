#include <Commands/BiceCommandExample.hpp>

#include <Commands/CBiceCommands.hpp>
#include <utils.hpp>

#include <cstdio>

namespace {

    bool installed = false;

    /**
    @brief the whole of what a command does, and the shape every handler has

    **It reads its arguments and nothing else.** That is not a stylistic preference: this runs
    on every machine in the game, inside the ordered command pump, so anything it read that
    exists on one machine only would make it do something different on each one. The arguments
    arrived in the payload, which is the ordered path; the machine it happens to be running on
    is not.

    What it does with them is deliberately trivial - log them - because the thing being
    demonstrated is that they arrive at all, identically, everywhere. One line however many
    there are, so two machines' logs can be compared directly.
    */
    void onPing(const int32_t* args, int count) {
        if (count == 0) {
            INFO_OUT(printf("BiceCommand ping: no arguments\n"));
            return;
        }
        char rendered[CBiceCommands::MAX_ARGS * 13 + 1];
        int at = 0;
        for (int i = 0; i < count && i < CBiceCommands::MAX_ARGS; i++) {
            at += sprintf_s(rendered + at, sizeof(rendered) - at, (i == 0 ? "%d" : ", %d"),
                args[i]);
        }
        INFO_OUT(printf("BiceCommand ping: [%s]\n", rendered));
    }
}

bool BiceCommandExample::install() {
    if (installed) {
        return true;
    }
    installed = CBiceCommands::registerKind(Kinds::Ping, "ping", onPing);
    return installed;
}

bool BiceCommandExample::post(const int32_t* args, int count) {
    return CBiceCommands::post(Kinds::Ping, args, count);
}
