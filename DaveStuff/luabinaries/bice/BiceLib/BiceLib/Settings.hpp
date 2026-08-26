#pragma once

#include <string>

/**
 * The settings BiceLib keeps between sessions.
 *
 * A flat key/value file, `BiceLibSettings.ini`, kept beside the DLL alongside the
 * docking layout. Plain text, one `key=value` per line, so it can be read and edited
 * by hand; lines starting with `#` are comments and anything unparseable is skipped
 * rather than treated as an error.
 *
 * The file is read once, on the first access, and written again on every change.
 * Settings are few and change only when somebody clicks something, so there is no
 * reason to batch the writes and a good reason not to: a setting survives even if the
 * game never shuts down cleanly.
 *
 * Keys are namespaced by the thing that owns them - `overlay.toggleKey`,
 * `customMapMode.palette` - so the file stays readable as more of them appear.
 *
 * This is not for anything large or anything per save game. The combat records have
 * their own store, and the mod's own Lua data is written by the mod.
 */
namespace Settings {
    /**@brief the setting as a string, or \p fallback when it is not in the file*/
    std::string getString(const char* key, const char* fallback);

    /**@brief the setting as a number, or \p fallback when absent or not a number*/
    int getInt(const char* key, int fallback);

    /**@brief records the setting and writes the file*/
    void setString(const char* key, const std::string& value);
    void setInt(const char* key, int value);

    /**
    @brief where the file is, for a page that wants to say so

    Empty if the DLL's own directory could not be worked out, which is also the case
    where nothing is read or written and every get returns its fallback.
    */
    const std::string& path();
}
