[Code]

// ---------------------------------------------------------------------------
// Antivirus warning.
//
// The mod ships script\BiceLib.dll, which the game loads and which hooks the
// game's own functions. Windows Defender leaves it alone, but a third party
// antivirus has flagged it at least twice, and what the player then sees is a
// game that will not start or a mod that is missing features, with nothing
// pointing at why.
//
// So the installer says so three times, each where it will be read:
//   - the system check page names the folder to exclude, before Install;
//   - the finished page repeats it in one line ([Messages] in BlackICE.iss);
//   - after the copy, CheckBiceLibPresent looks for the DLL itself, because an
//     antivirus that deletes it usually does so the moment it is written - and
//     then the player is told now, rather than finding out in game.
// ---------------------------------------------------------------------------

function ModFolderPath(GameDir: String; ModFolder: String): String;
begin
  Result := AddBackslash(GameDir) + 'tfh\mod\' + ModFolder;
end;

{ A section for the system check page. }
function DescribeAntivirus(GameDir: String; ModFolder: String): String;
begin
  Result :=
    '   BlackICE ships script\BiceLib.dll, which hooks into the game. Windows' + #13#10 +
    '   Defender accepts it, but some other antivirus programs have flagged it.' + #13#10 +
    '   If yours does, add an exception (exclusion) for the mod folder:' + #13#10 +
    '      ' + ModFolderPath(GameDir, ModFolder) + #13#10;
end;

{ True when the DLL is where it was copied. Tells the player when it is not. }
function CheckBiceLibPresent(GameDir: String; ModFolder: String): Boolean;
var
  Dll: String;
begin
  Dll := AddBackslash(ModFolderPath(GameDir, ModFolder)) + 'script\BiceLib.dll';
  Result := FileExists(Dll);
  if Result then
    Exit;

  Log('Antivirus: ' + Dll + ' is missing after the install');
  if WizardSilent() then
    Exit;

  MsgBox('BiceLib.dll was removed right after it was installed:' + #13#10 + #13#10 +
         '   ' + Dll + #13#10 + #13#10 +
         'This is almost certainly your antivirus program. BiceLib hooks into the ' +
         'game, which some antivirus programs mistake for something harmful. ' +
         'BlackICE will not work properly without it.' + #13#10 + #13#10 +
         'Restore the file from your antivirus quarantine, add an exception for ' +
         'the mod folder below, and run this installer again:' + #13#10 + #13#10 +
         '   ' + ModFolderPath(GameDir, ModFolder),
         mbError, MB_OK);
end;
