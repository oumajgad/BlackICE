[Code]

// ---------------------------------------------------------------------------
// Runtime detection and installation.
//
// The list is not "everything since 2005". It is what the shipped binaries
// actually import, read off their import tables and SxS manifests:
//
//   VC++ 2005 SP1 x86   lua51.dll, lua5.1.dll, script\lfs.dll   Microsoft.VC80.CRT
//   VC++ 2008 SP1 x86   PdxConnect.dll, script\wx.dll           Microsoft.VC90.CRT
//   VC++ 2010 SP1 x86   tbb.dll, tbbmalloc.dll, hoi3game.exe    msvcr100.dll
//   VC++ 2015-2022 x86  script\BiceLib.dll                      vcruntime140.dll, UCRT
//   VC++ 2015-2022 x64  stats\visualizeStatisticCLI.exe         64 bit tool
//   DirectX 9.0c        hoi3_tfh.exe imports d3dx9_42.dll
//   .NET 3.5            launcher.exe is managed, CLR v2.0.50727
//
// VC++ 2012 and 2013 are absent on purpose: nothing links against them.
//
// The VC++ redistributables are bundled and installed silently. .NET 3.5 is a
// Windows feature rather than a download, so it goes through DISM, which needs
// a connection; if that is not available the installer says so plainly instead
// of failing silently.
// ---------------------------------------------------------------------------

const
  RUNTIME_COUNT = 7;

  RT_VC2005     = 0;
  RT_VC2008     = 1;
  RT_VC2010     = 2;
  RT_VC2022_X86 = 3;
  RT_VC2022_X64 = 4;
  RT_DIRECTX    = 5;
  RT_NETFX35    = 6;

var
  RuntimeName:     array[0..RUNTIME_COUNT - 1] of String;
  RuntimeNeededBy: array[0..RUNTIME_COUNT - 1] of String;
  RuntimeFile:     array[0..RUNTIME_COUNT - 1] of String;
  RuntimePresent:  array[0..RUNTIME_COUNT - 1] of Boolean;
  RuntimeTableReady: Boolean;

{ Is there a WinSxS assembly folder whose name starts with Prefix?
  Side by side assemblies are how the 2005 and 2008 runtimes register, and
  there is no single registry value that survives every servicing update. }
function SxSAssemblyPresent(const Prefix: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(ExpandConstant('{win}\WinSxS\') + Prefix + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
        begin
          Result := True;
          Break;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

{ The 32 bit system folder, whatever the bitness of Windows. }
function SysWow(): String;
begin
  if IsWin64 then
    Result := ExpandConstant('{syswow64}\')
  else
    Result := ExpandConstant('{sys}\');
end;

function DetectRuntime(Index: Integer): Boolean;
var
  Installed: Cardinal;
begin
  case Index of
    RT_VC2005:
      Result := SxSAssemblyPresent('x86_microsoft.vc80.crt_');
    RT_VC2008:
      Result := SxSAssemblyPresent('x86_microsoft.vc90.crt_');
    RT_VC2010:
      Result := FileExists(SysWow() + 'msvcr100.dll');
    RT_VC2022_X86:
      begin
        Result := FileExists(SysWow() + 'vcruntime140.dll') and
                  FileExists(SysWow() + 'msvcp140.dll');
        if not Result then
          if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86',
               'Installed', Installed) then
            Result := Installed = 1;
      end;
    RT_VC2022_X64:
      begin
        if not IsWin64 then
        begin
          // Nothing 64 bit can run here, so the stats tool is simply unavailable.
          Result := True;
          Exit;
        end;
        Result := FileExists(ExpandConstant('{sysnative}\vcruntime140.dll')) and
                  FileExists(ExpandConstant('{sysnative}\msvcp140.dll'));
        if not Result then
          if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
               'Installed', Installed) then
            Result := Installed = 1;
      end;
    RT_DIRECTX:
      Result := FileExists(SysWow() + 'd3dx9_42.dll');
    RT_NETFX35:
      begin
        Result := False;
        if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5',
             'Install', Installed) then
          Result := Installed = 1;
      end;
  else
    Result := True;
  end;
end;

procedure BuildRuntimeTable();
begin
  if RuntimeTableReady then
    Exit;

  RuntimeName[RT_VC2005]     := 'Visual C++ 2005 SP1 (32 bit)';
  RuntimeNeededBy[RT_VC2005] := 'the Lua engine and the Utility window';
  RuntimeFile[RT_VC2005]     := 'vcredist2005_x86.exe';

  RuntimeName[RT_VC2008]     := 'Visual C++ 2008 SP1 (32 bit)';
  RuntimeNeededBy[RT_VC2008] := 'PdxConnect and the Utility window';
  RuntimeFile[RT_VC2008]     := 'vcredist2008_x86.exe';

  RuntimeName[RT_VC2010]     := 'Visual C++ 2010 SP1 (32 bit)';
  RuntimeNeededBy[RT_VC2010] := 'the threading library the game loads at startup';
  RuntimeFile[RT_VC2010]     := 'vcredist2010_x86.exe';

  RuntimeName[RT_VC2022_X86]     := 'Visual C++ 2015-2022 (32 bit)';
  RuntimeNeededBy[RT_VC2022_X86] := 'BiceLib.dll - the mod will not load without it';
  RuntimeFile[RT_VC2022_X86]     := 'vcredist2022_x86.exe';

  RuntimeName[RT_VC2022_X64]     := 'Visual C++ 2015-2022 (64 bit)';
  RuntimeNeededBy[RT_VC2022_X64] := 'the statistics viewer';
  RuntimeFile[RT_VC2022_X64]     := 'vcredist2022_x64.exe';

  RuntimeName[RT_DIRECTX]     := 'DirectX 9.0c (d3dx9_42)';
  RuntimeNeededBy[RT_DIRECTX] := 'the game itself - it will not start without it';
  RuntimeFile[RT_DIRECTX]     := 'directx\DXSETUP.exe';

  RuntimeName[RT_NETFX35]     := '.NET Framework 3.5';
  RuntimeNeededBy[RT_NETFX35] := 'launcher.exe';
  RuntimeFile[RT_NETFX35]     := '';

  RuntimeTableReady := True;
end;

{ Refresh what is present. Called on the check page and again after installing. }
procedure ScanRuntimes();
var
  I: Integer;
  State: String;
begin
  BuildRuntimeTable();
  for I := 0 to RUNTIME_COUNT - 1 do
  begin
    RuntimePresent[I] := DetectRuntime(I);
    if RuntimePresent[I] then
      State := 'present'
    else
      State := 'MISSING';
    Log(Format('Runtime: %s -> %s', [RuntimeName[I], State]));
  end;
end;

function MissingRuntimeCount(): Integer;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 0 to RUNTIME_COUNT - 1 do
    if not RuntimePresent[I] then
      Count := Count + 1;
  Result := Count;
end;

{ Was this runtime's installer bundled? fetchRedists.py may have been skipped. }
function RuntimeBundled(Index: Integer): Boolean;
begin
  if RuntimeFile[Index] = '' then
    Result := False
  else
    Result := FileExists(ExpandConstant('{tmp}\redist\') + RuntimeFile[Index]);
end;

{ The report shown on the system check page. }
function RuntimeReport(): String;
var
  I: Integer;
  Line: String;
begin
  ScanRuntimes();
  Result := '';
  for I := 0 to RUNTIME_COUNT - 1 do
  begin
    if RuntimePresent[I] then
      Line := '   [ok]       ' + RuntimeName[I]
    else
      Line := '   [MISSING]  ' + RuntimeName[I] + '  -  needed by ' + RuntimeNeededBy[I];
    Result := Result + Line + #13#10;
  end;
end;

{ Enable the .NET 3.5 Windows feature. Needs Windows Update or install media. }
function EnableNetFx35(var Message: String): Boolean;
var
  Code: Integer;
begin
  Log('Runtime: enabling NetFx3 through DISM');
  if not Exec(ExpandConstant('{sys}\dism.exe'),
       '/Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart /Quiet',
       '', SW_HIDE, ewWaitUntilTerminated, Code) then
  begin
    Message := 'DISM could not be started.';
    Result := False;
    Exit;
  end;

  Log(Format('Runtime: DISM exit code %d', [Code]));
  // 3010 is "done, reboot required", which is fine for our purposes.
  Result := (Code = 0) or (Code = 3010);
  if not Result then
    Message := Format('Windows could not add .NET 3.5 (DISM code %d). It fetches the' + #13#10 +
                      '            feature from Windows Update, so a connection is needed. It can' + #13#10 +
                      '            also be added under "Turn Windows features on or off".', [Code]);
end;

{ Install everything detected as missing. Returns a report for the final page. }
function InstallMissingRuntimes(): String;
var
  I, Code: Integer;
  Source, Arguments, Note, Report: String;
begin
  Report := '';
  ScanRuntimes();

  for I := 0 to RUNTIME_COUNT - 1 do
  begin
    if RuntimePresent[I] then
      Continue;

    WizardForm.StatusLabel.Caption := 'Installing ' + RuntimeName[I] + '...';

    if I = RT_NETFX35 then
    begin
      Note := '';
      if EnableNetFx35(Note) then
        Report := Report + '  installed  ' + RuntimeName[I] + #13#10
      else
        Report := Report + '  FAILED     ' + RuntimeName[I] + #13#10 +
                  '            ' + Note + #13#10;
      Continue;
    end;

    if not RuntimeBundled(I) then
    begin
      Report := Report + '  skipped    ' + RuntimeName[I] +
                ' (not bundled in this build)' + #13#10;
      Continue;
    end;

    Source := ExpandConstant('{tmp}\redist\') + RuntimeFile[I];
    if I = RT_DIRECTX then
      Arguments := '/silent'
    else if (I = RT_VC2005) or (I = RT_VC2008) then
      Arguments := '/q'                    // Windows Installer wrapped packages
    else if I = RT_VC2010 then
      Arguments := '/q /norestart'
    else
      Arguments := '/install /quiet /norestart';

    if not Exec(Source, Arguments, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    begin
      Report := Report + '  FAILED     ' + RuntimeName[I] + ' (could not be started)' + #13#10;
      Continue;
    end;

    Log(Format('Runtime: %s exit code %d', [RuntimeName[I], Code]));
    // 0 success, 1638/1641 this or a newer build is already there, 3010 reboot pending.
    if (Code = 0) or (Code = 3010) or (Code = 1638) or (Code = 1641) then
      Report := Report + '  installed  ' + RuntimeName[I] + #13#10
    else
      Report := Report + Format('  FAILED     %s (code %d)', [RuntimeName[I], Code]) + #13#10;
  end;

  ScanRuntimes();
  if Report = '' then
    Report := '  Everything was already present.' + #13#10;
  Result := Report;
end;
