[Code]

// ---------------------------------------------------------------------------
// Base folder files that the mod replaces.
//
// A few of the mod's files go into the base game folder rather than the mod
// folder, and at least one of them - lua5.1.dll - is a file the game ships too.
// Inno tracks what it installed and deletes it on uninstall, which would leave
// the game without its own copy, so the original is set aside first and put
// back when the mod is removed.
//
// Same .preBlackICE convention as the exe backup, so everything the installer
// displaces is recognisable in the folder.
// ---------------------------------------------------------------------------

const
  BASE_FILE_COUNT = 1;
  BACKUP_SUFFIX = '.preBlackICE';

{ The base folder files the mod overwrites and the game also ships. }
function BaseFileName(Index: Integer): String;
begin
  case Index of
    0: Result := 'lua5.1.dll';
  else
    Result := '';
  end;
end;

{ Set the originals aside. Must run before the files are copied over them. }
procedure BackupBaseFiles(const GameDir: String);
var
  I: Integer;
  Original, Backup: String;
begin
  for I := 0 to BASE_FILE_COUNT - 1 do
  begin
    Original := AddBackslash(GameDir) + BaseFileName(I);
    Backup := Original + BACKUP_SUFFIX;

    // Only the first time, so reinstalling over an existing BlackICE does not
    // overwrite the genuine original with the mod's copy.
    if FileExists(Original) and not FileExists(Backup) then
    begin
      if CopyFile(Original, Backup, True) then
        Log('BaseFiles: backed up ' + BaseFileName(I))
      else
        Log('BaseFiles: could not back up ' + BaseFileName(I));
    end;
  end;
end;

{ Put the originals back, used by the uninstaller. }
procedure RestoreBaseFiles(const GameDir: String);
var
  I: Integer;
  Original, Backup: String;
begin
  for I := 0 to BASE_FILE_COUNT - 1 do
  begin
    Original := AddBackslash(GameDir) + BaseFileName(I);
    Backup := Original + BACKUP_SUFFIX;
    if FileExists(Backup) then
    begin
      if CopyFile(Backup, Original, False) then
      begin
        DeleteFile(Backup);
        Log('BaseFiles: restored ' + BaseFileName(I));
      end;
    end;
  end;
end;
