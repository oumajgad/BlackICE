[Code]

// ---------------------------------------------------------------------------
// Turning on Windows crash dumps for the game.
//
// Replaces step 2 of CRASH-REPORTS.md, which asked the player to type a .reg
// file in Notepad, save it with the right extension and run it as admin. Almost
// nobody does that, so the crashes that matter most - the ones that happen
// before BlackICE has even loaded, and so leave no report of its own - went
// unreported.
//
// The setting is Windows Error Reporting's LocalDumps, scoped to one executable:
//
//   HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\hoi3_tfh.exe
//       DumpCount = 5
//       DumpType  = 2        (full memory - the default, the crashdumps\full task)
//                   1        (mini dump - that task unticked)
//
// Nothing else on the machine is affected, and only this one game is covered.
// Dumps land in %LOCALAPPDATA%\CrashDumps and are capped at five; Windows deletes
// the oldest by itself.
//
// Full is the default because a mini dump holds the crashing thread's stack and
// little else - no heap - so it can say where the game crashed but rarely what
// it was holding. The load crash of 2026-11-02 (extra_infra) could only be
// explained from a full dump, which named the two units and the provinces.
//
// What it costs is disk space, and only when the game crashes. A full dump is
// everything the game has in memory, which for a 32 bit program is at most its
// address space: 4 GB with the memory patch (patchexe), 2 GB without. Measured:
// 3.0 GB for a game at 3.17 GB. So the worst case is 5 x 4 GB = about 20 GB.
// A mini dump is about 40 MB, 200 MB for five.
//
// IMPORTANT: this must be written to the 64 bit view. The installer is a 32 bit
// program, so a plain HKLM write is redirected into Wow6432Node - where Windows
// Error Reporting does not look, leaving a setting that appears to be there and
// does nothing. Hence WerRootKey below.
// ---------------------------------------------------------------------------

const
  WER_DUMP_KEY = 'SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\hoi3_tfh.exe';
  WER_DUMP_COUNT = 5;
  WER_DUMP_TYPE_MINI = 1; // about 40 MB each
  WER_DUMP_TYPE_FULL = 2; // up to 4 GB each - the game's whole address space

{ The registry view Windows Error Reporting actually reads.

  On 64 bit Windows that is the native view, which a 32 bit installer only
  reaches through HKLM64. Asking for a 64 bit view on 32 bit Windows is an
  error in Inno, so that case uses plain HKLM. }
function WerRootKey(): Integer;
begin
  if IsWin64 then
    Result := HKLM64
  else
    Result := HKLM;
end;

function CrashDumpsConfigured(): Boolean;
begin
  Result := RegKeyExists(WerRootKey(), WER_DUMP_KEY);
end;

{ Whether the key holds exactly what this installer writes.

  Used on the way out to tell our own setting apart from one the player had
  already, so uninstalling does not quietly undo somebody's own configuration.
  There is no marker to check instead: anything stored alongside would either
  pollute a Windows key or be deleted before the uninstaller could read it.

  Either dump type counts as ours: this installer writes both, and older ones
  wrote the mini dump, which a reinstall then moves to the player's new choice. }
function CrashDumpsAreOurs(): Boolean;
var
  Count, DumpType: Cardinal;
begin
  Result := False;
  if not RegQueryDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpCount', Count) then
    Exit;
  if not RegQueryDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpType', DumpType) then
    Exit;
  Result := (Count = WER_DUMP_COUNT) and
            ((DumpType = WER_DUMP_TYPE_MINI) or (DumpType = WER_DUMP_TYPE_FULL));
end;

{ Whether our setting is the full memory one. Only meaningful when it is ours. }
function CrashDumpsAreFull(): Boolean;
var
  DumpType: Cardinal;
begin
  Result := RegQueryDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpType', DumpType) and
            (DumpType = WER_DUMP_TYPE_FULL);
end;

{ A line for the system check page. }
function DescribeCrashDumps(): String;
begin
  if not CrashDumpsConfigured() then
    Result := 'off - Windows keeps nothing when the game crashes'
  else if CrashDumpsAreOurs() and CrashDumpsAreFull() then
    Result := 'on, full memory, keeping the last 5 dumps in %LOCALAPPDATA%\CrashDumps (up to ~20 GB)'
  else if CrashDumpsAreOurs() then
    Result := 'on, mini dumps, keeping the last 5 in %LOCALAPPDATA%\CrashDumps (~200 MB)'
  else
    Result := 'already set up your own way - it will be left alone';
end;

{ Switch it on, full memory or mini. An existing setting that is not ours is
  never overwritten; one of ours is moved to the type asked for. }
function EnableCrashDumps(Full: Boolean; var Message: String): Boolean;
var
  DumpType: Cardinal;
begin
  if Full then
    DumpType := WER_DUMP_TYPE_FULL
  else
    DumpType := WER_DUMP_TYPE_MINI;

  if CrashDumpsConfigured() and not CrashDumpsAreOurs() then
  begin
    Message := 'Windows crash dumps were already set up differently on this PC,' + #13#10 +
               'so that was left exactly as it is.';
    Log('CrashDumps: an existing configuration was left alone');
    Result := True;
    Exit;
  end;

  if not RegWriteDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpCount', WER_DUMP_COUNT) or
     not RegWriteDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpType', DumpType) then
  begin
    Message := 'Windows crash dumps could not be switched on. The mod is fine' + #13#10 +
               'without them; they only help us read a crash if you report one.' + #13#10 +
               'CRASH-REPORTS.md explains how to do it by hand.';
    Log('CrashDumps: could not write ' + WER_DUMP_KEY);
    Result := False;
    Exit;
  end;

  if Full then
    Message := 'On, full memory. If the game crashes, Windows now keeps a dump in' + #13#10 +
               '%LOCALAPPDATA%\CrashDumps - up to 4 GB each, the last 5 kept, so' + #13#10 +
               'about 20 GB at most. See CRASH-REPORTS.md for what to send.'
  else
    Message := 'On, mini dumps. If the game crashes, Windows now keeps a dump in' + #13#10 +
               '%LOCALAPPDATA%\CrashDumps - about 40 MB each, the last 5 kept.' + #13#10 +
               'See CRASH-REPORTS.md for what to send.';
  Log(Format('CrashDumps: enabled for hoi3_tfh.exe, DumpType %d', [DumpType]));
  Result := True;
end;

{ Switch it off again, used by the uninstaller. Leaves a configuration that is
  not the one we wrote, and leaves any dumps already saved where they are. }
procedure DisableCrashDumps();
begin
  if not CrashDumpsConfigured() then
    Exit;
  if not CrashDumpsAreOurs() then
  begin
    Log('CrashDumps: left alone, not the configuration we wrote');
    Exit;
  end;
  if RegDeleteKeyIncludingSubkeys(WerRootKey(), WER_DUMP_KEY) then
    Log('CrashDumps: disabled for hoi3_tfh.exe');
end;
