[Code]

// ---------------------------------------------------------------------------
// Moving the 3D unit sprites aside.
//
// The mod never draws them, and they cost roughly 300 MB of a 32 bit address
// space. This is the same operation as the Utility's "Remove sprites" button
// (BiceLib SpecialPage.cpp): move everything in gfx\anims into gfx\anims\backup,
// keeping the generic tank so units still have a fallback model.
//
// Doing it here removes steps 8, 9 and 10 of the old instructions, which asked
// the player to start the game, alt-tab out, find the button, and restart.
//
// Nothing is deleted. The move is reversible from the Utility, and the
// uninstaller puts the files back.
// ---------------------------------------------------------------------------

{ The game still needs one model or units are drawn with nothing at all.
  Thumbs.db is Explorer's and would only be recreated. }
function SpriteIsKept(const Name: String): Boolean;
var
  Lower: String;
begin
  Lower := Lowercase(Name);
  Result := (Lower = 'thumbs.db') or
            (Lower = 'generictankdiffuse.dds') or
            (Lower = 'generictankspecular.dds') or
            (Lower = 'generictank.xac') or
            (Lower = 'tankidlea.xsm');
end;

{ How many files in gfx\anims could be moved, and how many bytes that is. }
procedure CountSprites(const GameDir: String; var Files: Integer; var Bytes: Int64);
var
  AnimsDir: String;
  FindRec: TFindRec;
begin
  Files := 0;
  Bytes := 0;
  AnimsDir := AddBackslash(GameDir) + 'gfx\anims\';
  if not DirExists(AnimsDir) then
    Exit;

  if FindFirst(AnimsDir + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          Continue;
        if SpriteIsKept(FindRec.Name) then
          Continue;
        Files := Files + 1;
        Bytes := Bytes + (Int64(FindRec.SizeHigh) shl 32) + FindRec.SizeLow;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

{ Move gfx\anims\* into gfx\anims\backup\, keeping the fallback model.
  Reports how many files could not be moved rather than stopping at the first. }
function MoveSpritesAside(const GameDir: String; var Message: String): Boolean;
var
  AnimsDir, BackupDir: String;
  FindRec: TFindRec;
  Names: array of String;
  Count, I, Moved, Failed: Integer;
begin
  AnimsDir := AddBackslash(GameDir) + 'gfx\anims\';
  BackupDir := AnimsDir + 'backup\';

  if not DirExists(AnimsDir) then
  begin
    Message := 'gfx\anims was not found, so there were no sprites to move.';
    Result := False;
    Exit;
  end;

  // Collected up front: renaming while the search handle is open is asking for
  // the enumeration to skip entries.
  Count := 0;
  SetArrayLength(Names, 2048);
  if FindFirst(AnimsDir + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          Continue;
        if SpriteIsKept(FindRec.Name) then
          Continue;
        if Count >= GetArrayLength(Names) then
          SetArrayLength(Names, Count * 2);
        Names[Count] := FindRec.Name;
        Count := Count + 1;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;

  if Count = 0 then
  begin
    Message := 'The sprites had already been moved aside.';
    Result := True;
    Exit;
  end;

  if not DirExists(BackupDir) then
  begin
    if not CreateDir(BackupDir) then
    begin
      Message := 'Could not create gfx\anims\backup, so the sprites were left in place.';
      Result := False;
      Exit;
    end;
  end;

  Moved := 0;
  Failed := 0;
  for I := 0 to Count - 1 do
  begin
    if RenameFile(AnimsDir + Names[I], BackupDir + Names[I]) then
      Moved := Moved + 1
    else
    begin
      Failed := Failed + 1;
      Log('Sprites: could not move ' + Names[I]);
    end;
  end;

  if Failed = 0 then
    Message := Format('Moved %d sprite files into gfx\anims\backup.', [Moved])
  else
    Message := Format('Moved %d sprite files; %d were in use and stayed put.' + #13#10 +
                      'Close the game and use the Utility''s Special page to finish.', [Moved,
                      Failed]);
  Result := Failed = 0;
end;

{ Undo, used by the uninstaller. }
procedure RestoreSprites(const GameDir: String);
var
  AnimsDir, BackupDir: String;
  FindRec: TFindRec;
  Names: array of String;
  Count, I: Integer;
begin
  AnimsDir := AddBackslash(GameDir) + 'gfx\anims\';
  BackupDir := AnimsDir + 'backup\';
  if not DirExists(BackupDir) then
    Exit;

  Count := 0;
  SetArrayLength(Names, 2048);
  if FindFirst(BackupDir + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          Continue;
        if Count >= GetArrayLength(Names) then
          SetArrayLength(Names, Count * 2);
        Names[Count] := FindRec.Name;
        Count := Count + 1;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;

  for I := 0 to Count - 1 do
    RenameFile(BackupDir + Names[I], AnimsDir + Names[I]);

  RemoveDir(BackupDir);
end;
