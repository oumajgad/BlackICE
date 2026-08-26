#include <Settings.hpp>

#include <Overlay.hpp>

#include <cstdlib>
#include <fstream>
#include <map>
#include <sstream>

namespace {
    const char* FILE_NAME = "BiceLibSettings.ini";

    std::map<std::string, std::string> values;
    std::string filePath;
    bool loaded = false;

    std::string trim(const std::string& text) {
        const size_t first = text.find_first_not_of(" \t\r\n");
        if (first == std::string::npos) {
            return std::string();
        }
        const size_t last = text.find_last_not_of(" \t\r\n");
        return text.substr(first, last - first + 1);
    }

    /**
    @brief reads the file, once

    A missing file is the ordinary case on a first run, not a failure: the map stays
    empty and every get answers with its fallback.
    */
    void load() {
        if (loaded) {
            return;
        }
        loaded = true;

        const std::string& directory = Overlay::directory();
        if (directory.empty()) {
            return;     // no path to read from, so nothing is read or written
        }
        filePath = directory + FILE_NAME;

        std::ifstream file(filePath.c_str());
        if (!file) {
            return;
        }

        std::string line;
        while (std::getline(file, line)) {
            const std::string trimmed = trim(line);
            if (trimmed.empty() || trimmed[0] == '#') {
                continue;
            }
            const size_t equals = trimmed.find('=');
            if (equals == std::string::npos) {
                continue;   // not a setting, so not this file's business
            }
            const std::string key = trim(trimmed.substr(0, equals));
            if (!key.empty()) {
                values[key] = trim(trimmed.substr(equals + 1));
            }
        }
    }

    /**@brief writes every setting, replacing whatever was there*/
    void save() {
        if (filePath.empty()) {
            return;
        }
        std::ofstream file(filePath.c_str(), std::ios::trunc);
        if (!file) {
            return;     // read only, or gone; the settings still hold for this session
        }
        file << "# BiceLib settings. Written by the overlay, safe to edit by hand.\n";
        // std::map orders by key, which groups each owner's settings together.
        for (std::map<std::string, std::string>::const_iterator it = values.begin();
            it != values.end(); ++it) {
            file << it->first << "=" << it->second << "\n";
        }
    }
}

std::string Settings::getString(const char* key, const char* fallback) {
    load();
    std::map<std::string, std::string>::const_iterator found = values.find(key);
    return (found == values.end()) ? std::string(fallback) : found->second;
}

int Settings::getInt(const char* key, int fallback) {
    load();
    std::map<std::string, std::string>::const_iterator found = values.find(key);
    if (found == values.end()) {
        return fallback;
    }
    // Hand edited files are expected, so a value that is not a number is treated the
    // same as one that is not there.
    std::istringstream stream(found->second);
    int parsed = 0;
    if (!(stream >> parsed)) {
        return fallback;
    }
    return parsed;
}

void Settings::setString(const char* key, const std::string& value) {
    load();
    values[key] = value;
    save();
}

void Settings::setInt(const char* key, int value) {
    std::ostringstream stream;
    stream << value;
    setString(key, stream.str());
}

const std::string& Settings::path() {
    load();
    return filePath;
}
