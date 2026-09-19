#include <GameState/OobFile.hpp>

#include <GameState/Localisation.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>

namespace {
    // Where `load_oob` paths are relative to. The DLL sits in the mod's `script`, so
    // the mod's own copy is one folder up and the game's own is four - the same order
    // the game looks in, mod first.
    const char* const UNITS_FOLDER = "\\history\\units\\";
    const char* const MOD_UP = "\\..";
    const char* const GAME_UP = "\\..\\..\\..\\..";

    std::map<std::string, OobFile::Summary> parsed;

    /**@brief the folder this DLL is in, which is the mod's `script`*/
    std::string dllFolder() {
        HMODULE self = nullptr;
        if (!GetModuleHandleExA(
                GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                reinterpret_cast<LPCSTR>(&dllFolder), &self)) {
            return "";
        }
        char path[MAX_PATH] = {};
        if (GetModuleFileNameA(self, path, MAX_PATH) == 0) {
            return "";
        }
        const std::string text(path);
        const size_t slash = text.find_last_of("\\/");
        return slash == std::string::npos ? "" : text.substr(0, slash);
    }

    /**@brief a file whole, or "" if it is not there*/
    std::string readFile(const std::string& path) {
        FILE* file = nullptr;
        if (fopen_s(&file, path.c_str(), "rb") != 0 || file == nullptr) {
            return "";
        }
        std::string contents;
        char block[64 * 1024];
        size_t read = 0;
        while ((read = fread(block, 1, sizeof(block), file)) > 0) {
            contents.append(block, read);
        }
        fclose(file);
        return contents;
    }

    bool isWord(char c) {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
            || c == '_' || c == '-';
    }

    /**
     * Enough of the game's file syntax to count what is in one.
     *
     * Not a parser: it walks the characters keeping only the names of the blocks it is
     * inside, so that a `location` can be attributed to the block that carries it. That
     * is all these files need - the values that matter are plain numbers, and comments
     * and quoted names are the only things that could lie about a brace.
     */
    class Scanner
    {
    public:
        Scanner(const std::string& text) : text_(text), at_(0) {}

        void run(OobFile::Summary& into) {
            std::vector<std::string> open;          // the blocks we are inside
            std::string word;                       // the identifier last seen
            std::map<int, int> byProvince;

            while (at_ < text_.size()) {
                const char c = text_[at_];

                if (c == '#') {                     // a comment, to end of line
                    while (at_ < text_.size() && text_[at_] != '\n') {
                        at_++;
                    }
                    continue;
                }
                if (c == '"') {                     // a name, which may hold anything
                    at_++;
                    while (at_ < text_.size() && text_[at_] != '"') {
                        at_++;
                    }
                    at_++;
                    word.clear();
                    continue;
                }
                if (c == '{') {
                    open.push_back(word);
                    count(word, into);
                    word.clear();
                    at_++;
                    continue;
                }
                if (c == '}') {
                    if (!open.empty()) {
                        open.pop_back();
                    }
                    word.clear();
                    at_++;
                    continue;
                }
                if (isWord(c)) {
                    const size_t from = at_;
                    while (at_ < text_.size() && isWord(text_[at_])) {
                        at_++;
                    }
                    const std::string token = text_.substr(from, at_ - from);
                    // A number belongs to whatever key came before it, and the two keys
                    // worth reading both take one.
                    if (word == "location" && !open.empty()) {
                        const int province = atoi(token.c_str());
                        if (province > 0) {
                            byProvince[province] += 1;
                            into.units += 1;
                        }
                        word.clear();
                        continue;
                    }
                    if (word == "leader") {
                        const int id = atoi(token.c_str());
                        if (id > 0) {
                            OobFile::Assignment assignment;
                            assignment.leaderId = id;
                            assignment.kind = open.empty() ? "" : open.back();
                            into.leaders.push_back(assignment);
                        }
                        word.clear();
                        continue;
                    }
                    word = token;
                    continue;
                }
                at_++;                              // whitespace, '=', anything else
            }

            for (const std::pair<const int, int>& entry : byProvince) {
                OobFile::Place place;
                place.provinceId = entry.first;
                place.units = entry.second;
                place.name = Localisation::textForId("PROV", entry.first);
                into.places.push_back(place);
            }
            // Most first, and by province id where two are level, so the same file
            // always reads the same way.
            std::sort(into.places.begin(), into.places.end(),
                [](const OobFile::Place& a, const OobFile::Place& b) {
                    return a.units != b.units ? a.units > b.units : a.provinceId < b.provinceId;
                });
        }

    private:
        /**@brief the blocks that are worth a number of their own*/
        static void count(const std::string& name, OobFile::Summary& into) {
            if (name == "regiment") {
                into.brigades += 1;
            }
            else if (name == "ship") {
                into.ships += 1;
            }
            else if (name == "wing") {
                into.wings += 1;
            }
            else if (name == "military_construction") {
                into.constructions += 1;
            }
        }

        const std::string& text_;
        size_t at_;
    };
}

const OobFile::Summary& OobFile::of(const std::string& relativePath) {
    const std::map<std::string, Summary>::const_iterator found = parsed.find(relativePath);
    if (found != parsed.end()) {
        return found->second;
    }

    Summary summary;
    const std::string folder = dllFolder();
    if (!folder.empty() && !relativePath.empty()) {
        const std::string places[2] = {
            folder + MOD_UP + UNITS_FOLDER + relativePath,
            folder + GAME_UP + UNITS_FOLDER + relativePath,
        };
        for (const std::string& path : places) {
            const std::string contents = readFile(path);
            if (contents.empty()) {
                continue;
            }
            summary.found = true;
            Scanner(contents).run(summary);
            break;      // the mod's copy wins, as it does for the game
        }
    }
    if (!summary.found) {
        INFO_OUT(printf("OobFile: no history/units/%s under %s\n",
            relativePath.c_str(), folder.c_str()));
    }

    parsed[relativePath] = summary;
    return parsed[relativePath];
}
