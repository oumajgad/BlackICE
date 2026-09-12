; ===========================================================================
; BlackICE installer.
;
; Replaces the self extracting archive and the ten step forum post. Everything
; installInstructions.txt used to ask the player to do by hand happens here:
;
;   old step 4    pick the base folder      - checked, and guessed where it can be
;   old step 5    extract, say yes to all   - just happens
;   old step 6    download Podcat's LAA exe - gone, the patch produces that exe
;   old step 7    run zDsafe_ExePatcher     - done here, with a backup
;   old steps 8-10 remove sprites in game   - done here, no game restart
;   optional      unpack dxvk.rar by hand   - a checkbox
;   redistributables                        - detected and installed
;
; Build with installer/buildInstaller.py, which stamps the version and calls
; ISCC. Do not compile this file directly: ModVersion has no default on purpose,
; so a hand compile fails loudly rather than shipping an unversioned mod.
; ===========================================================================

#ifndef ModVersion
  #error ModVersion is not set. Build with: python installer/buildInstaller.py <version>
#endif

#define ModName    "BlackICE"
#define ModFolder  "BlackICE " + ModVersion
#define Publisher  "BlackICE Team"
#define RepoRoot   ".."

[Setup]
; The doubled brace is Inno's escape for a literal '{', so this reaches the
; registry as {48024E7B-...}. Must never change once a version has shipped:
; it is the key Windows finds the installed mod under, and a new one would
; leave every existing install orphaned with its own entry.
;
; Test builds get their own AppId. They install per user (HKCU) while a release
; installs for all users (HKLM), so the two do NOT replace each other; sharing
; an AppId once left a dead test entry sitting in the apps list next to a real
; install, wearing the same identity and impossible to tell apart.
#ifdef FastBuild
AppId={{D0E6A293-8903-49EF-BE0A-6DB520BF36F3}
#else
AppId={{48024E7B-6F6B-4FAD-B5ED-9B421ED9DA9D}
#endif
AppName={#ModName}
AppVersion={#ModVersion}
AppVerName={#ModName} {#ModVersion}
AppPublisher={#Publisher}
VersionInfoVersion=1.0.0.0
VersionInfoDescription={#ModName} {#ModVersion} installer

; The mod lives inside the game folder, so the directory page picks the game
; rather than a fresh install location. DisableDirPage stays off - that page is
; the whole point.
DefaultDirName={code:GuessDefaultDir}
DirExistsWarning=no
AppendDefaultDirName=no
UsePreviousAppDir=yes

DefaultGroupName={#ModName}
AllowNoIcons=yes
OutputDir=output
OutputBaseFilename={#ModName} {#ModVersion} Setup
; Optional. Drop a BlackICE.ico into installer\assets and it gets used; without
; one the installer carries Inno's default icon rather than failing to build.
#if FileExists(AddBackslash(SourcePath) + "assets\BlackICE.ico")
SetupIconFile=assets\BlackICE.ico
#endif

; Writing into the game folder and installing runtimes both need elevation.
#ifdef FastBuild
; Test builds run unelevated so the wizard and the post install steps can be
; exercised against a scratch folder without a UAC prompt. Never shipped:
; buildInstaller.py --fast also leaves the payload uncompressed and says so.
PrivilegesRequired=lowest
#else
PrivilegesRequired=admin
#endif
ArchitecturesAllowed=x86compatible x64compatible

; 2.4 GB of mod files come down to roughly 800 MB like this, against 1.5 GB for
; the old deflate zip. Inno refuses to build a single file installer above
; ~2.1 GB, so buildInstaller.py checks the output size and says so if that ever
; starts getting close.
#ifdef FastBuild
; buildInstaller.py --fast: skip compression so wizard changes can be tried out
; in seconds instead of waiting on LZMA2 over the 2 GB gfx tree.
Compression=none
SolidCompression=no
#else
Compression=lzma2/max
SolidCompression=yes
LZMANumBlockThreads=4
InternalCompressLevel=max
#endif

WizardStyle=modern
DisableWelcomePage=no
DisableProgramGroupPage=yes
ShowLanguageDialog=no
#ifdef FastBuild
UninstallDisplayName={#ModName} {#ModVersion} (TEST BUILD - not a release)
#else
UninstallDisplayName={#ModName} {#ModVersion}
#endif
UninstallDisplayIcon={app}\hoi3_tfh.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full";   Description: "Recommended - everything the mod needs"
Name: "custom"; Description: "Custom"; Flags: iscustom

[Components]
Name: "mod";      Description: "{#ModName} {#ModVersion} game files"; Types: full custom; Flags: fixed
Name: "runtimes"; Description: "Missing Microsoft runtimes (C++, DirectX, .NET)"; Types: full custom
Name: "dxvk";     Description: "DXVK - lower memory use, needs a Vulkan 1.3 GPU"; Types: custom
; Needs two edits afterwards to actually switch on - fullScreen=no in the mod's
; settings.txt, and borderless=1 in v2winfix.ini - so the description says so
; rather than leaving people with a file that appears to do nothing.
Name: "border";   Description: "Borderless window (needs settings.txt edited afterwards - see the readme it installs)"; Types: custom

[Tasks]
Name: "patchexe";  Description: "Patch hoi3_tfh.exe so the game can use 4 GB of memory"; GroupDescription: "Fixes applied to the game:"
Name: "sprites";   Description: "Move the unused 3D unit sprites aside (frees ~300 MB)"; GroupDescription: "Fixes applied to the game:"
Name: "desktop";   Description: "Create a desktop shortcut that launches {#ModName} directly"; GroupDescription: "Shortcuts:"
Name: "startmenu"; Description: "Create a Start menu entry"; GroupDescription: "Shortcuts:"

[Files]
; --- the mod itself -------------------------------------------------------
; Every folder in releaseCommon.MOD_FOLDERS. recursesubdirs picks up the tree;
; createallsubdirs keeps folders that exist but hold nothing.
Source: "{#RepoRoot}\battleplans\*";  DestDir: "{app}\tfh\mod\{#ModFolder}\battleplans";  Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\cgm\*";          DestDir: "{app}\tfh\mod\{#ModFolder}\cgm";          Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\common\*";       DestDir: "{app}\tfh\mod\{#ModFolder}\common";       Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\decisions\*";    DestDir: "{app}\tfh\mod\{#ModFolder}\decisions";    Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\events\*";       DestDir: "{app}\tfh\mod\{#ModFolder}\events";       Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\history\*";      DestDir: "{app}\tfh\mod\{#ModFolder}\history";      Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\localisation\*"; DestDir: "{app}\tfh\mod\{#ModFolder}\localisation"; Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\map\*";          DestDir: "{app}\tfh\mod\{#ModFolder}\map";          Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\interface\*";    DestDir: "{app}\tfh\mod\{#ModFolder}\interface";    Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\music\*";        DestDir: "{app}\tfh\mod\{#ModFolder}\music";        Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\script\*";       DestDir: "{app}\tfh\mod\{#ModFolder}\script";       Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\sound\*";        DestDir: "{app}\tfh\mod\{#ModFolder}\sound";        Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\technologies\*"; DestDir: "{app}\tfh\mod\{#ModFolder}\technologies"; Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\units\*";        DestDir: "{app}\tfh\mod\{#ModFolder}\units";        Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\gfx\*";          DestDir: "{app}\tfh\mod\{#ModFolder}\gfx";          Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion

; The .mod file the launcher reads. Generated by buildInstaller.py.
Source: "staging\{#ModFolder}.mod"; DestDir: "{app}\tfh\mod"; Components: mod; Flags: ignoreversion

; Utility resources and the statistics tool, as zipperRelease.py placed them.
Source: "{#RepoRoot}\tools\wxWidget\projects\tfh\mod\BlackICE-utility-resources\*"; DestDir: "{app}\tfh\mod\{#ModFolder}\utility"; Components: mod; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RepoRoot}\tools\visualizeStatistics\visualizeStatisticCLI.exe";          DestDir: "{app}\tfh\mod\{#ModFolder}\stats";   Components: mod; Flags: ignoreversion

; The Lua the game loads out of the base folder, not the mod folder.
Source: "{#RepoRoot}\DaveStuff\luabinaries\lua5.1.dll"; DestDir: "{app}"; Components: mod; Flags: ignoreversion

; --- optional extras ------------------------------------------------------
; Unpacked at build time, so nobody has to find "extract here" in a context menu.
Source: "staging\dxvk\*";       DestDir: "{app}"; Components: dxvk;   Flags: ignoreversion
Source: "staging\borderless\*"; DestDir: "{app}"; Components: border; Flags: ignoreversion

; --- runtimes -------------------------------------------------------------
; Extracted to {tmp} only when that component is selected, and deleted after.
Source: "redist\*"; DestDir: "{tmp}\redist"; Components: runtimes; Flags: recursesubdirs createallsubdirs deleteafterinstall skipifsourcedoesntexist

[Icons]
; -mod= launches straight into BlackICE, which skips the launcher entirely and
; with it the "pick the mod in the launcher" step and the .NET dependency.
;
; The mod path must NOT be quoted, even though it contains spaces. This is the
; form the game's own launcher uses, read off a running hoi3_tfh.exe:
;     "hoi3_tfh.exe"  -mod=mod/BlackICE 1.0.0.mod
; Quoting it the way a command line normally would stops the game finding the
; mod. The path is relative to tfh\, while WorkingDir is the base folder.
Name: "{group}\{#ModName} {#ModVersion}"; Filename: "{app}\hoi3_tfh.exe"; Parameters: "-mod=mod/{#ModFolder}.mod"; WorkingDir: "{app}"; Tasks: startmenu
Name: "{group}\Hearts of Iron 3 launcher"; Filename: "{app}\launcher.exe"; WorkingDir: "{app}"; Tasks: startmenu
Name: "{autodesktop}\{#ModName} {#ModVersion}"; Filename: "{app}\hoi3_tfh.exe"; Parameters: "-mod=mod/{#ModFolder}.mod"; WorkingDir: "{app}"; Tasks: desktop

[Run]
Filename: "{app}\hoi3_tfh.exe"; Parameters: "-mod=mod/{#ModFolder}.mod"; WorkingDir: "{app}"; Description: "Launch {#ModName} {#ModVersion} now"; Flags: nowait postinstall skipifsilent unchecked

[UninstallDelete]
; The mod tree, plus what the game writes into it while running.
Type: filesandordirs; Name: "{app}\tfh\mod\{#ModFolder}"
Type: files;          Name: "{app}\tfh\mod\{#ModFolder}.mod"

#include "inc\bytes.iss"
#include "inc\gamefolder.iss"
#include "inc\basefiles.iss"
#include "inc\exepatch.iss"
#include "inc\sprites.iss"
#include "inc\oldversions.iss"
#include "inc\uninstallpick.iss"
#include "inc\redist.iss"

[Code]

var
  CheckPage: TOutputMsgMemoWizardPage;
  OldVersionPage: TInputOptionWizardPage;
  SteamWarned: Boolean;
  Summary: String;

function GuessDefaultDir(Param: String): String;
begin
  Result := GuessGameFolder();
  if Result = '' then
    Result := 'C:\Hearts of Iron 3';
end;

procedure InitializeWizard();
begin
  SteamWarned := False;

  // Only shown when an older version is actually there; the checkboxes are
  // added once the game folder is known. See ScanOldVersions.
  OldVersionPage := CreateInputOptionPage(wpSelectTasks,
    'Older versions found', 'Remove the versions you no longer want',
    'These older BlackICE versions are still in the game folder. Removing one '
    + 'deletes only its files.' + #13#10 + #13#10
    + 'Your saved games are not touched. They are not kept in the game folder '
    + 'at all, but in Documents\Paradox Interactive\Hearts of Iron III\, one '
    + 'folder per version, so you can reinstall a version later and carry on.',
    False, False);

  // A read only page rather than a set of checkboxes: it reports, the install
  // acts. Filled in on the fly because it depends on the folder just chosen.
  CheckPage := CreateOutputMsgMemoPage(OldVersionPage.ID,
    'System check', 'What this installer found on your machine',
    'This is what the game and the mod need, and what is already here. ' +
    'Anything missing is installed for you when you continue.',
    '');
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = OldVersionPage.ID) and (OldVersionCount = 0);
end;

procedure CurPageChanged(CurPageID: Integer);
var
  Report: String;
  Files: Integer;
  Bytes: Int64;
begin
  if CurPageID <> CheckPage.ID then
    Exit;

  Report := 'Game folder' + #13#10;
  Report := Report + '   ' + WizardDirValue + #13#10 + #13#10;

  Report := Report + 'hoi3_tfh.exe' + #13#10;
  Report := Report + '   ' + DescribeExe(AddBackslash(WizardDirValue) + 'hoi3_tfh.exe') + #13#10 + #13#10;

  CountSprites(WizardDirValue, Files, Bytes);
  Report := Report + '3D unit sprites' + #13#10;
  if Files = 0 then
    Report := Report + '   already moved aside' + #13#10 + #13#10
  else
    Report := Report + Format('   %d files, %d MB that the mod never draws', [Files, Bytes div 1048576]) + #13#10 + #13#10;

  Report := Report + 'Runtimes' + #13#10;
  Report := Report + RuntimeReport();

  if MissingRuntimeCount() > 0 then
  begin
    Report := Report + #13#10;
    if WizardIsComponentSelected('runtimes') then
      Report := Report + 'The missing ones are installed when you press Install.' + #13#10
    else
      Report := Report + 'You cleared the runtimes component, so these are left alone.' + #13#10 +
                'If the game does not start, that is the first thing to look at.' + #13#10;
  end;

  CheckPage.RichEditViewer.Text := Report;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Problem: String;
  Index: Integer;
begin
  Result := True;
  if CurPageID <> wpSelectDir then
    Exit;

  Problem := GameFolderProblem(WizardDirValue);
  if Problem <> '' then
  begin
    MsgBox(Problem, mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // Scanning walks the old mod trees to size them, so it happens once here
  // rather than every time the page is shown.
  ScanOldVersions(WizardDirValue, '{#ModFolder}');
  OldVersionPage.CheckListBox.Items.Clear();
  for Index := 0 to OldVersionCount - 1 do
  begin
    OldVersionPage.Add(OldVersionCaption(Index));
    // Ticked by default: keeping an old version is the unusual choice.
    OldVersionPage.Values[Index] := True;
  end;

  if IsSteamFolder(WizardDirValue) and not SteamWarned then
  begin
    SteamWarned := True;
    if MsgBox('This is a Steam copy of the game.' + #13#10 + #13#10 +
              'BlackICE patches hoi3_tfh.exe. Steam replaces files it owns whenever ' +
              'it verifies the install, which would undo that patch and, with it, the ' +
              '4 GB memory fix.' + #13#10 + #13#10 +
              'It will work now. If the game later becomes unstable again, move the ' +
              'game folder out of Steam and install here once more.' + #13#10 + #13#10 +
              'Continue with this folder?',
              mbConfirmation, MB_YESNO) = IDNO then
      Result := False;
  end;
end;

{ The custom steps, run after the files are in place. }
procedure CurStepChanged(CurStep: TSetupStep);
var
  Message: String;
  Index, Removed: Integer;
  Reclaimed: Int64;
begin
  if CurStep = ssInstall then
  begin
    // Before any file is copied: the game ships its own lua5.1.dll and the mod
    // replaces it, so the original has to be set aside while it is still there.
    BackupBaseFiles(WizardDirValue);
    Exit;
  end;

  if CurStep <> ssPostInstall then
    Exit;

  Summary := '';

  if WizardIsComponentSelected('runtimes') then
  begin
    WizardForm.StatusLabel.Caption := 'Checking Microsoft runtimes...';
    Summary := Summary + 'Runtimes' + #13#10 + InstallMissingRuntimes() + #13#10;
  end;

  if WizardIsTaskSelected('patchexe') then
  begin
    WizardForm.StatusLabel.Caption := 'Patching hoi3_tfh.exe...';
    Message := '';
    ApplyLargeAddressAware(WizardDirValue, Message);
    Summary := Summary + 'Memory patch' + #13#10 + '  ' + Message + #13#10 + #13#10;
  end;

  if WizardIsTaskSelected('sprites') then
  begin
    WizardForm.StatusLabel.Caption := 'Moving the 3D unit sprites aside...';
    Message := '';
    MoveSpritesAside(WizardDirValue, Message);
    Summary := Summary + 'Unit sprites' + #13#10 + '  ' + Message + #13#10 + #13#10;
  end;

  // Last, so that a failed install never costs anyone the version they had.
  Removed := 0;
  Reclaimed := 0;
  for Index := 0 to OldVersionCount - 1 do
  begin
    if not OldVersionPage.Values[Index] then
      Continue;
    WizardForm.StatusLabel.Caption := 'Removing ' + OldVersionFolder[Index] + '...';
    if RemoveOldVersion(WizardDirValue, OldVersionFolder[Index]) then
    begin
      Removed := Removed + 1;
      Reclaimed := Reclaimed + OldVersionBytes[Index];
    end;
  end;
  if Removed > 0 then
    Summary := Summary + 'Older versions' + #13#10 +
               Format('  Removed %d, freeing %s.', [Removed, DescribeSize(Reclaimed)]) + #13#10 + #13#10;

  Log('Summary:' + #13#10 + Summary);
end;

{ Shown on the last page, so a failure is read rather than scrolled past. }
function UpdateReadyMemo(Space, NewLine, MemoUserInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := 'Game folder:' + NewLine + Space + WizardDirValue + NewLine + NewLine;
  if MemoComponentsInfo <> '' then
    Result := Result + MemoComponentsInfo + NewLine;
  if MemoTasksInfo <> '' then
    Result := Result + MemoTasksInfo + NewLine;
  Result := Result + NewLine + 'The mod goes into:' + NewLine +
            Space + 'tfh\mod\{#ModFolder}' + NewLine;
end;

procedure DeinitializeSetup();
begin
  // Nothing to clean up: deleteafterinstall handles the runtime payload.
end;

{ ----------------------------- uninstall ------------------------------- }

function InitializeUninstall(): Boolean;
begin
  // A silent uninstall takes the whole lot, as a silent run should: no dialog
  // to answer and no half state to be surprised by later.
  if UninstallSilent() then
  begin
    Result := True;
    Exit;
  end;

  // Returns False when the player cancelled, or when they picked a subset -
  // in which case those versions are already gone and BlackICE stays installed.
  Result := ChooseVersionsToRemove(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  GameDir: String;
begin
  // usPostUninstall, not usUninstall: Inno deletes the files it installed
  // between the two, and lua5.1.dll is one of them. Restoring earlier would put
  // the game's original back only for Inno to delete it a moment later.
  if CurUninstallStep <> usPostUninstall then
    Exit;

  GameDir := ExpandConstant('{app}');

  if MsgBox('Put the game back the way it was before BlackICE?' + #13#10 + #13#10 +
            'This restores:' + #13#10 +
            '   - the original hoi3_tfh.exe (undoing the 4 GB patch)' + #13#10 +
            '   - the 3D unit sprites in gfx\anims' + #13#10 +
            '   - the game''s own lua5.1.dll' + #13#10 + #13#10 +
            'Choose No to leave all three as they are and only remove the mod files.',
            mbConfirmation, MB_YESNO) = IDYES then
  begin
    RestoreSprites(GameDir);
    RestoreStockExe(GameDir);
    RestoreBaseFiles(GameDir);
  end;
end;
