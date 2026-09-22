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
//       DumpType  = 1        (mini dump)
//
// Nothing else on the machine is affected, and only this one game is covered.
// Dumps land in %LOCALAPPDATA%\CrashDumps and are capped at five, so the worst
// case is a few hundred MB that Windows recycles by itself.
//
// IMPORTANT: this must be written to the 64 bit view. The installer is a 32 bit
// program, so a plain HKLM write is redirected into Wow6432Node - where Windows
// Error Reporting does not look, leaving a setting that appears to be there and
// does nothing. Hence WerRootKey below.
// ---------------------------------------------------------------------------

const
  WER_DUMP_KEY = 'SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\hoi3_tfh.exe';
  WER_DUMP_COUNT = 5;
  WER_DUMP_TYPE = 1;      // 1 = mini dump; 2 would be full, and gigabytes each

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
  pollute a Windows key or be deleted before the uninstaller could read it. }
function CrashDumpsAreOurs(): Boolean;
var
  Count, DumpType: Cardinal;
begin
  Result := False;
  if not RegQueryDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpCount', Count) then
    Exit;
  if not RegQueryDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpType', DumpType) then
    Exit;
  Result := (Count = WER_DUMP_COUNT) and (DumpType = WER_DUMP_TYPE);
end;

{ A line for the system check page. }
function DescribeCrashDumps(): String;
begin
  if not CrashDumpsConfigured() then
    Result := 'off - Windows keeps nothing when the game crashes'
  else if CrashDumpsAreOurs() then
    Result := 'on, keeping the last 5 dumps in %LOCALAPPDATA%\CrashDumps'
  else
    Result := 'already set up your own way - it will be left alone';
end;

{ Switch it on. An existing setting is never overwritten. }
function EnableCrashDumps(var Message: String): Boolean;
begin
  if CrashDumpsConfigured() and not CrashDumpsAreOurs() then
  begin
    Message := 'Windows crash dumps were already set up differently on this PC,' + #13#10 +
               'so that was left exactly as it is.';
    Log('CrashDumps: an existing configuration was left alone');
    Result := True;
    Exit;
  end;

  if not RegWriteDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpCount', WER_DUMP_COUNT) or
     not RegWriteDWordValue(WerRootKey(), WER_DUMP_KEY, 'DumpType', WER_DUMP_TYPE) then
  begin
    Message := 'Windows crash dumps could not be switched on. The mod is fine' + #13#10 +
               'without them; they only help us read a crash if you report one.' + #13#10 +
               'CRASH-REPORTS.md explains how to do it by hand.';
    Log('CrashDumps: could not write ' + WER_DUMP_KEY);
    Result := False;
    Exit;
  end;

  Message := 'On. If the game crashes, Windows now keeps a dump in' + #13#10 +
             '%LOCALAPPDATA%\CrashDumps - see CRASH-REPORTS.md for what to send.';
  Log('CrashDumps: enabled for hoi3_tfh.exe');
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
