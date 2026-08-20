// The two statistics pages.
//
// Setup switches collection on and picks which countries it covers. Statistics reads
// what has been written and either plots it here or hands it to the external tool.
//
// Collection itself belongs to utility/stats/stats.lua and runs from the game's daily
// handlers. Nothing here drives it - the switches are country variables on OMG, so
// every Lua context sees the same answer whichever utility flipped them.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>
#include <Overlay.hpp>

#include <Windows.h>
#include <algorithm>
#include <cfloat>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <map>
#include <set>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Stats.Collect";
    const char* SET_COLLECTING = "BiceLibGui.Stats.SetCollecting";
    const char* SET_CUSTOM_LIST = "BiceLibGui.Stats.SetCustomListActive";
    const char* SET_COUNTRY = "BiceLibGui.Stats.SetCountryCollected";

    bool valid = false;
    bool available = false;
    std::string reason;

    bool collecting = false;
    bool customListActive = false;
    int ident = 0;
    std::string statsPath;  // relative to the game directory, as Lua reports it
    std::string modVersion; // an argument to the plotting tool
    std::vector<std::string> countries;
    std::vector<std::string> custom;

    bool loaded = false;
    ULONGLONG lastPollMs = 0;

    // Toggles asked for but not yet applied; the switches go through Post like every
    // other command.
    int pendingCollecting = -1;
    int pendingCustomList = -1;

    // Country -> whether it was asked to be collected. Same reason: the list comes back
    // from the game unchanged until the command is applied, so an entry would appear to
    // jump back out of the list for a second.
    std::map<std::string, bool> pendingCountries;

    void readSnapshot() {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        if (!available) {
            return;
        }

        collecting = Gui::Lua::boolField("collecting");
        customListActive = Gui::Lua::boolField("customListActive");
        ident = static_cast<int>(Gui::Lua::numberField("ident"));
        statsPath = Gui::Lua::stringField("path");
        modVersion = Gui::Lua::stringField("version");

        countries.clear();
        const int countryCount = Gui::Lua::arrayLength("countries");
        countries.reserve(static_cast<size_t>(countryCount));
        for (int i = 0; i < countryCount; i++) {
            countries.push_back(Gui::Lua::arrayStringAt("countries", i));
        }

        custom.clear();
        const int customCount = Gui::Lua::arrayLength("custom");
        for (int i = 0; i < customCount; i++) {
            custom.push_back(Gui::Lua::arrayStringAt("custom", i));
        }

        if (pendingCollecting >= 0 && pendingCollecting == (collecting ? 1 : 0)) {
            pendingCollecting = -1;
        }
        if (pendingCustomList >= 0 && pendingCustomList == (customListActive ? 1 : 0)) {
            pendingCustomList = -1;
        }

        // A country the game now reports the way it was asked for is no longer pending.
        for (auto it = pendingCountries.begin(); it != pendingCountries.end();) {
            const bool inList = std::find(custom.begin(), custom.end(), it->first) != custom.end();
            it = (inList == it->second) ? pendingCountries.erase(it) : ++it;
        }

        loaded = true;
    }

    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setSwitch(const char* path, bool value) {
        if (!Gui::Lua::beginTableCallWithNumber(path, value ? 1 : 0)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setCountry(const std::string& tag, bool collected) {
        if (!Gui::Lua::beginTableCallWithStringAndNumber(SET_COUNTRY, tag.c_str(), collected ? 1 : 0)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    /**@brief the switches, polled; cheap enough and they can be changed elsewhere*/
    bool poll() {
        const ULONGLONG now = GetTickCount64();
        if (lastPollMs == 0 || now - lastPollMs >= 2000) {
            refresh();
            lastPollMs = now;
        }

        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return false;
        }
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
            return false;
        }
        return true;
    }

    /**@brief a switch that has to hold its new value until the game reports it back*/
    void drawSwitch(const char* label, const char* path, bool actual, int* pending) {
        const bool isPending = (*pending >= 0);
        bool shown = isPending ? (*pending == 1) : actual;

        if (ImGui::Checkbox(label, &shown)) {
            *pending = shown ? 1 : 0;
            setSwitch(path, shown);
        }
        if (isPending) {
            ImGui::SameLine();
            ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f), "waiting...");
        }
    }

    char countryFilter[32] = {};
    std::string selectedCountry;

    void drawSetup() {
        if (!poll()) {
            return;
        }

        drawSwitch("Collect statistics", SET_COLLECTING, collecting, &pendingCollecting);
        ImGui::SameLine(260.0f);
        if (ident > 0) {
            ImGui::Text("Run %d", ident);
            ImGui::SetItemTooltip("Each run writes to its own folder, so a new game does "
                "not overwrite the last one. Assigned on the first collection.");
        }
        else {
            ImGui::TextDisabled("no run number yet");
            ImGui::SetItemTooltip("Assigned when collection first writes something.");
        }

        drawSwitch("Only the countries listed below", SET_CUSTOM_LIST, customListActive,
            &pendingCustomList);

        ImGui::TextWrapped("Meant for development: collection writes a file per statistic "
            "per country every day, which the game feels. Restricting it to a few "
            "countries keeps that in hand. Expect command prompts to flash past while "
            "the folders are created.");

        ImGui::SeparatorText("Countries collected");
        if (!customListActive) {
            ImGui::TextDisabled("Every human player is collected while the switch above "
                "is off. The list is still editable.");
        }

        const float paneWidth = 200.0f;
        ImGui::BeginChild("all", ImVec2(paneWidth, 220.0f));
        ImGui::TextDisabled("All countries");
        // The list is the whole country database, so a filter is not optional.
        if (Gui::filteredList("countries", ImVec2(0, 0), countries,
            countryFilter, sizeof(countryFilter), selectedCountry)) {
            // selection only; adding is the button below
        }
        ImGui::EndChild();

        ImGui::SameLine();
        ImGui::BeginGroup();
        ImGui::Dummy(ImVec2(0.0f, 60.0f));

        // What the buttons act on is the requested state, not the game's, so a second
        // click cannot undo a request the game has not answered yet.
        const auto pending = pendingCountries.find(selectedCountry);
        const bool inList = (pending != pendingCountries.end())
            ? pending->second
            : std::find(custom.begin(), custom.end(), selectedCountry) != custom.end();

        ImGui::BeginDisabled(selectedCountry.empty() || inList);
        if (ImGui::Button("Add >>")) {
            pendingCountries[selectedCountry] = true;
            setCountry(selectedCountry, true);
        }
        ImGui::EndDisabled();
        ImGui::BeginDisabled(selectedCountry.empty() || !inList);
        if (ImGui::Button("<< Remove")) {
            pendingCountries[selectedCountry] = false;
            setCountry(selectedCountry, false);
        }
        ImGui::EndDisabled();
        ImGui::EndGroup();

        // The list as asked for: what the game reports, plus anything added but not yet
        // applied. A removal stays on show, in amber, until the game confirms it.
        std::vector<std::string> shown = custom;
        for (const auto& entry : pendingCountries) {
            if (entry.second && std::find(shown.begin(), shown.end(), entry.first) == shown.end()) {
                shown.push_back(entry.first);
            }
        }
        std::sort(shown.begin(), shown.end());

        ImGui::SameLine();
        ImGui::BeginChild("chosen", ImVec2(paneWidth, 220.0f));
        ImGui::TextDisabled("Collected (%d)", static_cast<int>(shown.size()));
        for (const std::string& tag : shown) {
            const bool waiting = pendingCountries.find(tag) != pendingCountries.end();
            if (waiting) {
                ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.80f, 0.60f, 0.20f, 1.0f));
            }
            if (ImGui::Selectable(tag.c_str(), tag == selectedCountry)) {
                selectedCountry = tag;
            }
            if (waiting) {
                ImGui::PopStyleColor();
                ImGui::SetItemTooltip("Waiting for the game to apply this");
            }
        }
        ImGui::EndChild();
    }

    // --- Statistics page ------------------------------------------------------------

    struct Series
    {
        std::string country;
        std::string stat;
        std::vector<float> values;
        // Kept alongside the values: a combined plot needs a shared x axis, and series
        // do not have to cover the same days - a country joining the list later starts
        // its file later.
        std::vector<int> days;
        // Points dropped as belonging to an abandoned timeline; see loadSeries.
        int discarded = 0;
        float minimum = 0.0f;
        float maximum = 0.0f;
        int firstDay = 0;
        int lastDay = 0;
    };

    std::vector<std::string> dataCountries; // countries with a folder on disk
    std::vector<std::string> dataStats;     // stat names found under them
    std::set<std::string> chosenCountries;
    std::set<std::string> chosenStats;
    std::vector<Series> plotted;
    std::string scanNote;
    bool scanned = false;
    char statFilter[32] = {};
    std::string selectedStat;

    /**
    @brief the stats folder, absolute and in Windows separators

    Lua reports its half of the path with forward slashes, as it uses it, so the join
    is normalised here rather than handing a mixed path to ShellExecute.
    */
    std::string statsRoot() {
        std::string path = Overlay::gameDirectory() + statsPath + "/";
        std::replace(path.begin(), path.end(), '/', '\\');
        return path;
    }

    /**@brief the folder this run writes into*/
    std::string runDirectory() {
        return statsRoot() + std::to_string(ident) + "\\";
    }

    /**@brief lists a directory, either its files or its subdirectories*/
    std::vector<std::string> entriesIn(const std::string& directory, bool wantDirectories) {
        std::vector<std::string> names;

        WIN32_FIND_DATAA found = {};
        const HANDLE search = FindFirstFileA((directory + "*").c_str(), &found);
        if (search == INVALID_HANDLE_VALUE) {
            return names;
        }
        do {
            const bool isDirectory = (found.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
            if (isDirectory != wantDirectories) {
                continue;
            }
            const std::string name = found.cFileName;
            if (name == "." || name == ".." || name == "zzSetup") {
                continue;
            }
            names.push_back(name);
        } while (FindNextFileA(search, &found) != 0);
        FindClose(search);

        // Sorted, which for these names also groups them: every stat is prefixed by
        // what it is about (res_, prod_, pol_ ...), exactly as the wx list was.
        std::sort(names.begin(), names.end(), [](const std::string& a, const std::string& b) {
            return _stricmp(a.c_str(), b.c_str()) < 0;
        });
        return names;
    }

    /**@brief finds what has actually been collected, rather than what could be*/
    void scanRun() {
        dataCountries.clear();
        dataStats.clear();
        plotted.clear();
        scanned = true;

        if (ident <= 0) {
            scanNote = "Nothing collected yet.";
            return;
        }

        dataCountries = entriesIn(runDirectory(), true);
        if (dataCountries.empty()) {
            scanNote = "No data in " + runDirectory();
            return;
        }

        // The stat names are the file names, and every country holds the same set once
        // a day has passed, so the union across countries is what to offer.
        std::set<std::string> names;
        for (const std::string& country : dataCountries) {
            for (const std::string& stat : entriesIn(runDirectory() + country + "\\", false)) {
                names.insert(stat);
            }
        }
        dataStats.assign(names.begin(), names.end());
        std::sort(dataStats.begin(), dataStats.end(), [](const std::string& a, const std::string& b) {
            return _stricmp(a.c_str(), b.c_str()) < 0;
        });

        scanNote = std::to_string(dataCountries.size()) + " countries, " +
            std::to_string(dataStats.size()) + " statistics";
    }

    /**
    @brief reads one "Date,value" file
    @returns false if it holds nothing plottable
    */
    bool loadSeries(const std::string& country, const std::string& stat, Series& series) {
        std::ifstream file((runDirectory() + country + "\\" + stat).c_str());
        if (!file) {
            return false;
        }

        series.country = country;
        series.stat = stat;

        std::string line;
        std::getline(file, line); // the header the collector writes
        while (std::getline(file, line)) {
            const size_t comma = line.find(',');
            if (comma == std::string::npos) {
                continue;
            }
            const int day = std::atoi(line.substr(0, comma).c_str());
            const float value = static_cast<float>(std::atof(line.substr(comma + 1).c_str()));

            // A file is appended to, never rewritten, so a crash or a reload from an
            // earlier save carries on writing behind where it had already reached. The
            // days then jump backwards, and everything from that day onwards describes
            // a timeline that was abandoned - so it is dropped in favour of what is
            // being read now. The kept days stay strictly increasing, which the plot
            // and its lookup both rely on.
            while (!series.days.empty() && series.days.back() >= day) {
                series.days.pop_back();
                series.values.pop_back();
                series.discarded++;
            }

            series.days.push_back(day);
            series.values.push_back(value);
        }

        if (series.values.empty()) {
            return false;
        }

        // Worked out once at the end: an abandoned branch may well have held the
        // highest or lowest value in the file, and it must not stretch the axes.
        series.firstDay = series.days.front();
        series.lastDay = series.days.back();
        series.minimum = series.values[0];
        series.maximum = series.values[0];
        for (const float value : series.values) {
            series.minimum = (value < series.minimum) ? value : series.minimum;
            series.maximum = (value > series.maximum) ? value : series.maximum;
        }
        return true;
    }

    void loadChosenSeries() {
        plotted.clear();
        for (const std::string& country : chosenCountries) {
            for (const std::string& stat : chosenStats) {
                Series series;
                if (loadSeries(country, stat, series)) {
                    plotted.push_back(series);
                }
            }
        }
    }

    /**@brief comma separated, with no trailing separator to become an empty entry*/
    std::string joined(const std::set<std::string>& values) {
        std::string text;
        for (const std::string& value : values) {
            if (!text.empty()) {
                text += ",";
            }
            text += value;
        }
        return text;
    }

    /**@brief hands the selection to the external plotting tool, as the wx page did*/
    void launchExternalPlot() {
        // The tool sits beside the data and takes: version ident tags stats
        const std::string exe = statsRoot() + "visualizeStatisticCLI.exe";
        if (GetFileAttributesA(exe.c_str()) == INVALID_FILE_ATTRIBUTES) {
            scanNote = "Not found: " + exe;
            return;
        }

        const std::string arguments = modVersion + " " + std::to_string(ident) + " " +
            joined(chosenCountries) + " " + joined(chosenStats);

        // Started in the game's directory, not the tool's own: it builds its paths as
        // ".\tfh\mod\BlackICE <version>\stats\..." from the working directory, which is
        // what it inherited when the wx page launched it through cmd. Given any other
        // directory it finds no files and draws an empty window, which is exactly what
        // it looks like when nothing happens at all.
        const HINSTANCE result = ShellExecuteA(nullptr, "open", exe.c_str(), arguments.c_str(),
            Overlay::gameDirectory().c_str(), SW_SHOWNORMAL);

        // The return is an error code below 32 rather than a handle, and silence here
        // is indistinguishable from the tool starting and finding nothing.
        if (reinterpret_cast<INT_PTR>(result) <= 32) {
            scanNote = "Could not start the tool (error " +
                std::to_string(reinterpret_cast<INT_PTR>(result)) + ")";
        }
        else {
            scanNote = "Started the plotting tool";
        }
    }

    /**
    @brief the in game date a collected day number stands for

    The collector writes GetTotalDays() - 706640, and the engine counts 365 day years
    with no leap day at all: 365 * 1936 is exactly 706640, so day 0 is 1 January 1936
    and every year is the same length. February is therefore always 28 days.

    Days before the epoch are possible - a scenario can start earlier - so the division
    is floored rather than truncated.
    */
    std::string gameDate(int day) {
        static const int MONTH_LENGTHS[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        static const char* const MONTHS[] = { "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

        int year = 1936 + day / 365;
        int dayOfYear = day % 365;
        if (dayOfYear < 0) {
            dayOfYear += 365;
            year--;
        }

        int month = 0;
        while (month < 11 && dayOfYear >= MONTH_LENGTHS[month]) {
            dayOfYear -= MONTH_LENGTHS[month];
            month++;
        }

        char text[32];
        sprintf_s(text, "%d %s %d", dayOfYear + 1, MONTHS[month], year);
        return text;
    }

    bool singlePlot = false;

    // Enough to tell a handful of lines apart without any of them being unreadable
    // against the frame background.
    const ImU32 PLOT_COLOURS[] = {
        IM_COL32(120, 190, 255, 255), IM_COL32(255, 170, 90, 255),
        IM_COL32(130, 220, 140, 255), IM_COL32(240, 130, 200, 255),
        IM_COL32(230, 220, 120, 255), IM_COL32(180, 150, 255, 255),
        IM_COL32(120, 230, 220, 255), IM_COL32(255, 130, 130, 255),
    };

    ImU32 seriesColour(size_t index) {
        return PLOT_COLOURS[index % IM_ARRAYSIZE(PLOT_COLOURS)];
    }

    /**@brief the point nearest \p day; the days ascend, so this is a binary search*/
    size_t nearestPoint(const Series& series, int day) {
        const auto at = std::lower_bound(series.days.begin(), series.days.end(), day);
        size_t point = static_cast<size_t>(at - series.days.begin());
        if (point >= series.days.size()) {
            return series.days.size() - 1;
        }
        if (point > 0 && (day - series.days[point - 1]) < (series.days[point] - day)) {
            point--;
        }
        return point;
    }

    /**
    @brief draws the given series into one set of axes, with a hover readout

    Drawn by hand rather than with PlotLines, which takes one series at a time and whose
    own tooltip reports the index into the array - a number that means nothing here. The
    x axis is the day a value was recorded rather than its position in the file, so
    series covering different spans still line up.

    @param indices which of the loaded series to draw, and their colours
    */
    void drawPlot(const char* id, const std::vector<size_t>& indices, float height) {
        if (indices.empty()) {
            return;
        }

        int firstDay = 0;
        int lastDay = 0;
        float lowest = 0.0f;
        float highest = 0.0f;
        bool first = true;
        for (const size_t index : indices) {
            const Series& series = plotted[index];
            if (first) {
                firstDay = series.firstDay;
                lastDay = series.lastDay;
                lowest = series.minimum;
                highest = series.maximum;
                first = false;
                continue;
            }
            firstDay = (series.firstDay < firstDay) ? series.firstDay : firstDay;
            lastDay = (series.lastDay > lastDay) ? series.lastDay : lastDay;
            lowest = (series.minimum < lowest) ? series.minimum : lowest;
            highest = (series.maximum > highest) ? series.maximum : highest;
        }
        if (lastDay <= firstDay) {
            ImGui::TextDisabled("Not enough data to plot.");
            return;
        }

        const float span = (highest > lowest) ? (highest - lowest) : 1.0f;
        const ImVec2 origin = ImGui::GetCursorScreenPos();
        const ImVec2 size(ImGui::GetContentRegionAvail().x, height);
        ImGui::InvisibleButton(id, size);

        ImDrawList* draw = ImGui::GetWindowDrawList();
        const ImVec2 corner(origin.x + size.x, origin.y + size.y);
        draw->AddRectFilled(origin, corner, ImGui::GetColorU32(ImGuiCol_FrameBg));
        draw->AddRect(origin, corner, ImGui::GetColorU32(ImGuiCol_Border));

        // A value's place in the frame, shared by the lines and the hover markers.
        const auto position = [&](const Series& series, size_t point) {
            const float x = static_cast<float>(series.days[point] - firstDay) /
                static_cast<float>(lastDay - firstDay);
            const float y = (series.values[point] - lowest) / span;
            return ImVec2(origin.x + x * size.x, corner.y - y * (size.y - 4.0f) - 2.0f);
        };

        std::vector<ImVec2> points;
        for (const size_t index : indices) {
            const Series& series = plotted[index];
            points.clear();
            points.reserve(series.values.size());
            for (size_t point = 0; point < series.values.size(); point++) {
                points.push_back(position(series, point));
            }
            if (points.size() > 1) {
                draw->AddPolyline(points.data(), static_cast<int>(points.size()),
                    seriesColour(index), 0, 1.5f);
            }
        }

        // Hovering reads the series at that date. Without axes or gridlines the plot
        // shows shape but no numbers, and this is where they come from.
        if (ImGui::IsItemHovered()) {
            const float mouseX = ImGui::GetIO().MousePos.x;
            const float fraction = (mouseX - origin.x) / size.x;
            const int day = firstDay + static_cast<int>(fraction * (lastDay - firstDay) + 0.5f);

            draw->AddLine(ImVec2(mouseX, origin.y), ImVec2(mouseX, corner.y),
                ImGui::GetColorU32(ImGuiCol_TextDisabled));

            ImGui::BeginTooltip();
            ImGui::TextUnformatted(gameDate(day).c_str());
            ImGui::Separator();

            for (const size_t index : indices) {
                const Series& series = plotted[index];
                const size_t point = nearestPoint(series, day);

                ImGui::PushStyleColor(ImGuiCol_Text, seriesColour(index));
                ImGui::Text("--");
                ImGui::PopStyleColor();
                ImGui::SameLine();
                ImGui::Text("%s %s", series.country.c_str(), series.stat.c_str());
                ImGui::SameLine();
                ImGui::Text("%.2f", series.values[point]);
                if (series.days[point] != day) {
                    // Said plainly rather than implying a reading exists for that date:
                    // a crash or a reload leaves gaps in a run.
                    ImGui::SameLine();
                    ImGui::TextDisabled("(%s)", gameDate(series.days[point]).c_str());
                }

                draw->AddCircleFilled(position(series, point), 3.0f, seriesColour(index));
            }
            ImGui::EndTooltip();
        }

        // No axes are drawn, so the range has to be said in words.
        ImGui::TextDisabled("%.2f to %.2f, %s to %s", lowest, highest,
            gameDate(firstDay).c_str(), gameDate(lastDay).c_str());
    }

    void drawStatistics() {
        if (!poll()) {
            return;
        }
        if (!scanned) {
            scanRun();
        }

        if (ImGui::Button("Rescan")) {
            scanRun();
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%s", scanNote.c_str());

        if (dataCountries.empty()) {
            ImGui::TextWrapped("Statistics appear here once collection has been switched "
                "on for a while. Each day writes one line per statistic.");
            return;
        }

        const float paneWidth = 190.0f;
        ImGui::BeginChild("countries", ImVec2(paneWidth, 200.0f), ImGuiChildFlags_Borders);
        ImGui::TextDisabled("Countries");
        for (const std::string& country : dataCountries) {
            bool chosen = chosenCountries.count(country) != 0;
            if (ImGui::Checkbox(country.c_str(), &chosen)) {
                if (chosen) {
                    chosenCountries.insert(country);
                }
                else {
                    chosenCountries.erase(country);
                }
                plotted.clear();
            }
        }
        ImGui::EndChild();

        ImGui::SameLine();
        ImGui::BeginChild("stats", ImVec2(320.0f, 200.0f), ImGuiChildFlags_Borders);
        ImGui::TextDisabled("Statistics");
        ImGui::SetNextItemWidth(-FLT_MIN);
        ImGui::InputTextWithHint("##statfilter", "Filter", statFilter, sizeof(statFilter));
        for (const std::string& stat : dataStats) {
            if (statFilter[0] != '\0' && stat.find(statFilter) == std::string::npos) {
                continue;
            }
            bool chosen = chosenStats.count(stat) != 0;
            if (ImGui::Checkbox(stat.c_str(), &chosen)) {
                if (chosen) {
                    chosenStats.insert(stat);
                }
                else {
                    chosenStats.erase(stat);
                }
                plotted.clear();
            }
        }
        ImGui::EndChild();

        ImGui::SameLine();
        ImGui::BeginGroup();
        ImGui::Text("%d countries", static_cast<int>(chosenCountries.size()));
        ImGui::Text("%d statistics", static_cast<int>(chosenStats.size()));
        ImGui::Spacing();

        ImGui::BeginDisabled(chosenCountries.empty() || chosenStats.empty());
        if (ImGui::Button("Plot here")) {
            loadChosenSeries();
        }
        if (ImGui::Button("Open in the tool")) {
            launchExternalPlot();
        }
        ImGui::EndDisabled();
        ImGui::SetItemTooltip("Runs visualizeStatisticCLI.exe, which draws proper axes "
            "and takes a few seconds");

        ImGui::SameLine();
        if (ImGui::Button("Clear")) {
            chosenCountries.clear();
            chosenStats.clear();
            plotted.clear();
        }
        ImGui::EndGroup();

        if (plotted.empty()) {
            return;
        }

        ImGui::SeparatorText("Plot");
        ImGui::Checkbox("One plot", &singlePlot);
        ImGui::SetItemTooltip("Draws every series into the same axes instead of one "
            "plot each");
        if (singlePlot) {
            std::vector<size_t> all;
            for (size_t index = 0; index < plotted.size(); index++) {
                all.push_back(index);
            }
            drawPlot("combined", all, 260.0f);

            // The legend is what ties a colour to a series once they share a frame.
            for (size_t index = 0; index < plotted.size(); index++) {
                const Series& series = plotted[index];
                ImGui::PushStyleColor(ImGuiCol_Text, seriesColour(index));
                ImGui::Text("--");
                ImGui::PopStyleColor();
                ImGui::SameLine();
                ImGui::Text("%s - %s", series.country.c_str(), series.stat.c_str());
                ImGui::SameLine();
                ImGui::TextDisabled("(%.2f to %.2f)", series.minimum, series.maximum);
            }
            return;
        }

        // One plot per series, drawn through the same routine so both modes read the
        // same way when hovered. Their scales have nothing to do with each other, which
        // is what the separate frames are for.
        for (size_t index = 0; index < plotted.size(); index++) {
            const Series& series = plotted[index];

            ImGui::PushStyleColor(ImGuiCol_Text, seriesColour(index));
            ImGui::Text("--");
            ImGui::PopStyleColor();
            ImGui::SameLine();
            ImGui::Text("%s - %s", series.country.c_str(), series.stat.c_str());
            ImGui::SameLine();
            ImGui::TextDisabled("%d points", static_cast<int>(series.values.size()));
            if (series.discarded > 0) {
                ImGui::SameLine();
                ImGui::TextDisabled("(%d dropped)", series.discarded);
                ImGui::SetItemTooltip("The file carries on past a crash or a reload from "
                    "an earlier save. Readings from the timeline that was abandoned are "
                    "dropped rather than plotted alongside the one that replaced it.");
            }

            char id[64];
            sprintf_s(id, "plot%d", static_cast<int>(index));
            drawPlot(id, std::vector<size_t>(1, index), 90.0f);
            ImGui::Spacing();
        }
    }

    class StatsSetupPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Setup"; }
        const char* group() const override { return "Stats"; }
        int order() const override { return 10; }
        void draw() override { drawSetup(); }
    };

    class StatisticsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Statistics"; }
        const char* group() const override { return "Stats"; }
        int order() const override { return 20; }
        void draw() override { drawStatistics(); }
    };
}

REGISTER_GUI_PAGE(StatsSetupPage);
REGISTER_GUI_PAGE(StatisticsPage);
