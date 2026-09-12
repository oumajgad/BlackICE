[Code]

// ---------------------------------------------------------------------------
// Finding and removing older BlackICE versions.
//
// Installing 15.1 over 15.0 replaces the entry in Windows' installed apps list
// - they share an AppId, so there is only ever one - but it does not touch
// tfh\mod\BlackICE 15.0, which is around 2.4 GB. Left alone that quietly costs
// a couple of gigabytes per release with nothing in the UI pointing at it.
//
// So the installer finds the older folders, says how much they take, and offers
// to remove them. Ticked by default: keeping an old version is the unusual
// choice, and the removal happens after the new version is installed, so a
// failed install never costs anyone their existing one.
//
// Saves are NOT touched. Each version's user_dir lives under
// Documents\Paradox Interactive\Hearts of Iron III\BlackICE <version>, outside
// the game folder entirely, so a removed version can be reinstalled and its
// campaigns picked up again.
// ---------------------------------------------------------------------------

const
  MAX_OLD_VERSIONS = 32;

var
  OldVersionFolder: array[0..MAX_OLD_VERSIONS - 1] of String;
  OldVersionBytes: array[0..MAX_OLD_VERSIONS - 1] of Int64;
  OldVersionCount: Integer;

{ Bytes as something readable, e.g. '2.4 GB'. }
function DescribeSize(Bytes: Int64): String;
begin
  if Bytes >= 1073741824 then
    Result := Format('%.1f GB', [Bytes / 1073741824.0])
  else if Bytes >= 1048576 then
    Result := Format('%d MB', [Bytes div 1048576])
  else
    Result := Format('%d KB', [Bytes div 1024]);
end;

{ Total size of a folder and everything under it. }
function FolderSize(const Path: String): Int64;
var
  FindRec: TFindRec;
  Total: Int64;
begin
  Total := 0;
  if FindFirst(AddBackslash(Path) + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Name = '.') or (FindRec.Name = '..') then
          Continue;
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          Total := Total + FolderSize(AddBackslash(Path) + FindRec.Name)
        else
          Total := Total + (Int64(FindRec.SizeHigh) shl 32) + FindRec.SizeLow;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
  Result := Total;
end;

{ Is this folder a released version rather than something else living in
  tfh\mod that happens to start with the mod's name?

  'BlackICE 15.0' yes, 'BlackICE GitHub' no. That second one is a working copy
  someone develops against, and it must never be offered for deletion, let
  alone ticked by default. So a version has to be 'BlackICE ' followed by a
  digit; anything else is left alone. }
function IsVersionFolder(const Name: String): Boolean;
var
  FirstOfVersion: String;
begin
  Result := False;
  if Length(Name) < 10 then
    Exit;
  if CompareText(Copy(Name, 1, 9), 'BlackICE ') <> 0 then
    Exit;
  FirstOfVersion := Copy(Name, 10, 1);
  Result := (FirstOfVersion >= '0') and (FirstOfVersion <= '9');
end;

{ Every released BlackICE version in tfh\mod except the one being installed.

  Junctions and symlinks are skipped: deleting through one would reach out of
  the game folder and take whatever it points at with it. }
procedure ScanOldVersions(const GameDir, CurrentFolder: String);
var
  ModRoot: String;
  FindRec: TFindRec;
begin
  OldVersionCount := 0;
  ModRoot := AddBackslash(GameDir) + 'tfh\mod\';
  if not DirExists(ModRoot) then
    Exit;

  if FindFirst(ModRoot + 'BlackICE *', FindRec) then
  begin
    try
      repeat
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
          Continue;
        if (FindRec.Name = '.') or (FindRec.Name = '..') then
          Continue;
        if (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
        begin
          Log('OldVersions: skipping reparse point ' + FindRec.Name);
          Continue;
        end;
        if not IsVersionFolder(FindRec.Name) then
        begin
          Log('OldVersions: not a version folder, left alone: ' + FindRec.Name);
          Continue;
        end;
        if CompareText(FindRec.Name, CurrentFolder) = 0 then
          Continue;
        if OldVersionCount >= MAX_OLD_VERSIONS then
          Break;

        OldVersionFolder[OldVersionCount] := FindRec.Name;
        OldVersionBytes[OldVersionCount] := FolderSize(ModRoot + FindRec.Name);
        Log(Format('OldVersions: found %s (%d bytes)', [FindRec.Name,
          OldVersionBytes[OldVersionCount]]));
        OldVersionCount := OldVersionCount + 1;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

{ The caption for one entry on the removal page. }
function OldVersionCaption(Index: Integer): String;
begin
  Result := Format('%s   (%s)', [OldVersionFolder[Index],
                                 DescribeSize(OldVersionBytes[Index])]);
end;

{ Delete one old version: its folder and the .mod file that points at it. }
function RemoveOldVersion(const GameDir, Folder: String): Boolean;
var
  ModRoot, Target, ModFile: String;
begin
  ModRoot := AddBackslash(GameDir) + 'tfh\mod\';
  Target := ModRoot + Folder;
  ModFile := ModRoot + Folder + '.mod';

  Result := DelTree(Target, True, True, True);
  if Result then
    Log('OldVersions: removed ' + Target)
  else
    Log('OldVersions: could not fully remove ' + Target);

  // The .mod goes too, or the launcher keeps offering a mod that is not there.
  if FileExists(ModFile) then
    DeleteFile(ModFile);
end;
