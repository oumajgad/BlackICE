[Code]

// ---------------------------------------------------------------------------
// Finding and checking the base Hearts of Iron 3 folder.
//
// "Base folder" means the one holding hoi3_tfh.exe and the tfh subfolder - the
// single thing people got wrong most often with the old self extracting archive,
// which happily unpacked a mod tree into whatever folder it was pointed at and
// gave no sign that it was the wrong one.
//
// The Steam check only warns. Steam can revert the patched exe when it verifies
// files, but that is a thing that may happen later, not a reason to refuse to
// install now.
// ---------------------------------------------------------------------------

{ Everything a base game folder must have. }
function IsGameFolder(const Path: String): Boolean;
begin
  Result := FileExists(AddBackslash(Path) + 'hoi3_tfh.exe') and
            DirExists(AddBackslash(Path) + 'tfh');
end;

{ Why the chosen folder is not usable, or '' when it is fine. }
function GameFolderProblem(const Path: String): String;
begin
  Result := '';

  if Path = '' then
  begin
    Result := 'Choose the folder Hearts of Iron 3 is installed in.';
    Exit;
  end;

  if not DirExists(Path) then
  begin
    Result := 'That folder does not exist.';
    Exit;
  end;

  if FileExists(AddBackslash(Path) + 'hoi3_tfh.exe') and
     not DirExists(AddBackslash(Path) + 'tfh') then
  begin
    Result := 'This folder has hoi3_tfh.exe but no "tfh" folder, so it is not a' + #13#10 +
              'Their Finest Hour install. BlackICE needs Their Finest Hour.';
    Exit;
  end;

  // The classic mistake: pointing at tfh, tfh\mod, or an existing mod folder
  // instead of at the game. Recognised by walking up: if a parent is the game
  // folder, the player is simply too deep.
  if not FileExists(AddBackslash(Path) + 'hoi3_tfh.exe') then
  begin
    if IsGameFolder(ExtractFileDir(RemoveBackslashUnlessRoot(Path))) or
       IsGameFolder(ExtractFileDir(ExtractFileDir(RemoveBackslashUnlessRoot(Path)))) or
       IsGameFolder(ExtractFileDir(ExtractFileDir(ExtractFileDir(RemoveBackslashUnlessRoot(Path))))) or
       (Lowercase(ExtractFileName(RemoveBackslashUnlessRoot(Path))) = 'mod') then
      Result := 'This looks like a folder inside the game rather than the game' + #13#10 +
                'folder itself. Go up until you can see hoi3_tfh.exe.'
    else
      Result := 'No hoi3_tfh.exe here, so this is not the base game folder.' + #13#10 +
                'It is the folder that contains hoi3_tfh.exe and the "tfh" folder.';
    Exit;
  end;
end;

{ Steam reverts files it owns when it verifies, including the patched exe. }
function IsSteamFolder(const Path: String): Boolean;
var
  Lower: String;
begin
  Lower := Lowercase(Path);
  Result := (Pos('\steamapps\', Lower) > 0) or (Pos('\steam\', Lower) > 0);
end;

{ Look in the usual places so most people never have to browse. }
function GuessGameFolder(): String;
var
  Candidates: array of String;
  Registered: String;
  I: Integer;
begin
  Result := '';

  SetArrayLength(Candidates, 0);

  // Whatever the game itself recorded, if anything.
  if RegQueryStringValue(HKLM, 'SOFTWARE\Paradox Interactive\Hearts of Iron 3', 'path', Registered) or
     RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Paradox Interactive\Hearts of Iron 3', 'path', Registered) then
  begin
    SetArrayLength(Candidates, GetArrayLength(Candidates) + 1);
    Candidates[GetArrayLength(Candidates) - 1] := Registered;
  end;

  SetArrayLength(Candidates, GetArrayLength(Candidates) + 6);
  I := GetArrayLength(Candidates) - 6;
  // Straight off the profile rather than {userdocs}\.., which would leave a
  // ".." in the path shown on the directory page.
  Candidates[I + 0] := ExpandConstant('{%USERPROFILE}\Hearts of Iron 3');
  Candidates[I + 1] := ExpandConstant('{pf32}\Steam\steamapps\common\Hearts of Iron 3');
  Candidates[I + 2] := 'C:\Program Files (x86)\Steam\steamapps\common\Hearts of Iron 3';
  Candidates[I + 3] := 'D:\SteamLibrary\steamapps\common\Hearts of Iron 3';
  Candidates[I + 4] := 'C:\SteamLibrary\steamapps\common\Hearts of Iron 3';
  Candidates[I + 5] := ExpandConstant('{pf32}\Paradox Interactive\Hearts of Iron III');

  for I := 0 to GetArrayLength(Candidates) - 1 do
  begin
    if (Candidates[I] <> '') and IsGameFolder(Candidates[I]) then
    begin
      Result := Candidates[I];
      Log('Game folder guessed: ' + Result);
      Exit;
    end;
  end;
end;
