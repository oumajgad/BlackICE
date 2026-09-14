[Code]

// ---------------------------------------------------------------------------
// DXVK and the borderless window fix, on the way out.
//
// Both drop DLLs into the base game folder, and both are worth keeping even
// once the mod is gone: DXVK lowers memory use for plain HoI3 just as much, and
// the borderless fix is a general windowed mode fix. Inno would delete them
// with everything else it installed, so their [Files] entries carry
// uninsneveruninstall and removal is asked about here instead.
//
// v2winfix.ini in Documents\Paradox Interactive is deliberately NOT touched.
// The borderless DLL writes it, but it is shared with the other Paradox games
// v2winfix supports, so deleting it could take another game's settings with it.
// ---------------------------------------------------------------------------

const
  EXTRA_FILE_COUNT = 4;

{ The files the two optional components place in the base game folder.
  Kept in step with the archives staged by buildInstaller.py (ARCHIVES). }
function ExtraFileName(Index: Integer): String;
begin
  case Index of
    0: Result := 'd3d9.dll';                                    // DXVK
    1: Result := 'dxgi.dll';                                    // DXVK
    2: Result := 'dinput8.dll';                                 // borderless
    3: Result := 'readme_borderless_windowed_with_stretching.md';
  else
    Result := '';
  end;
end;

function DxvkInstalled(const GameDir: String): Boolean;
begin
  Result := FileExists(AddBackslash(GameDir) + 'd3d9.dll') or
            FileExists(AddBackslash(GameDir) + 'dxgi.dll');
end;

function BorderlessInstalled(const GameDir: String): Boolean;
begin
  Result := FileExists(AddBackslash(GameDir) + 'dinput8.dll');
end;

function ExtrasInstalled(const GameDir: String): Boolean;
begin
  Result := DxvkInstalled(GameDir) or BorderlessInstalled(GameDir);
end;

{ Names what is actually there, so the question is about real files rather than
  a list of things the player may never have installed. }
function DescribeExtras(const GameDir: String): String;
begin
  Result := '';
  if DxvkInstalled(GameDir) then
    Result := Result + '   - DXVK (d3d9.dll, dxgi.dll)' + #13#10;
  if BorderlessInstalled(GameDir) then
    Result := Result + '   - the borderless window fix (dinput8.dll)' + #13#10;
end;

{ Delete them. Missing files are simply skipped. }
procedure RemoveExtras(const GameDir: String);
var
  I: Integer;
  Target: String;
begin
  for I := 0 to EXTRA_FILE_COUNT - 1 do
  begin
    Target := AddBackslash(GameDir) + ExtraFileName(I);
    if not FileExists(Target) then
      Continue;
    if DeleteFile(Target) then
      Log('Extras: removed ' + ExtraFileName(I))
    else
      Log('Extras: could not remove ' + ExtraFileName(I));
  end;
end;
