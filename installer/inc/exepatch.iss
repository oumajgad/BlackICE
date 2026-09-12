[Code]

// ---------------------------------------------------------------------------
// The Large Address Aware patch for hoi3_tfh.exe.
//
// This is the LAA half of tools/PythonExePatcher/ExePatcher.py and nothing else.
// The minister, war exhaustion and off-map IC patches that script also carries
// are applied at runtime by BiceLib.dll and must not be written to the file.
//
// Applying these nine writes to a stock 21,011,968 byte hoi3_tfh.exe produces a
// file byte-identical to Podcat's LAA exe (sha256 0eb63e3e4a844383...), which is
// why the installer does not need to ship that exe and the old instruction to
// download it separately is gone.
//
// The exe is fingerprinted before anything is written: all nine regions must
// already hold either the stock bytes or the patched ones. A build we do not
// recognise is left alone rather than blind-written, because these are absolute
// offsets and the wrong build would be corrupted silently.
// ---------------------------------------------------------------------------

const
  EXE_SIZE = 21011968;
  PATCH_SITES = 9;

  // Set by ClassifyExe.
  EXE_MISSING   = 0;
  EXE_STOCK     = 1;   // known build, not yet patched
  EXE_PATCHED   = 2;   // already Large Address Aware
  EXE_UNKNOWN   = 3;   // some other build, or partly patched

var
  PatchOffset: array[0..PATCH_SITES - 1] of Int64;
  PatchStock:  array[0..PATCH_SITES - 1] of String;
  PatchLAA:    array[0..PATCH_SITES - 1] of String;
  PatchTableReady: Boolean;

procedure BuildPatchTable();
begin
  if PatchTableReady then
    Exit;

  // PE header: the characteristics word at $146 carries the LAA bit; the
  // others are the checksum and the fields the retail build stamps alongside it.
  PatchOffset[0] := $0000138; PatchStock[0] := '2f8b97';   PatchLAA[0] := '9165e5';
  PatchOffset[1] := $0000146; PatchStock[1] := '02';       PatchLAA[1] := '22';
  PatchOffset[2] := $0000188; PatchStock[2] := '43da';     PatchLAA[2] := '67b1';
  PatchOffset[3] := $1180524; PatchStock[3] := '2f8b97';   PatchLAA[3] := '9165e5';
  // Build timestamp strings, rewritten so the patched exe identifies itself.
  PatchOffset[4] := $11fb60d; PatchStock[4] := '303a34303a3431'; PatchLAA[4] := '313a35363a3436';
  PatchOffset[5] := $11fb618; PatchStock[5] := '4e6f76202035';   PatchLAA[5] := '4a616e202033';
  PatchOffset[6] := $11fb622; PatchStock[6] := '32';             PatchLAA[6] := '33';
  // Build GUID.
  PatchOffset[7] := $120d77c;
  PatchStock[7] := '4f4ffaff4df14a4fb81f7ec0e1d6974b';
  PatchLAA[7]   := '6e68dad73de05f4394c72cd557d09411';
  PatchOffset[8] := $12f34b4; PatchStock[8] := 'f28997';   PatchLAA[8] := '4c64e5';

  PatchTableReady := True;
end;

{ Which of the builds we know, if any, this exe is. }
function ClassifyExe(const ExePath: String): Integer;
var
  I, Stock, Patched, Length_: Integer;
  Found: String;
begin
  BuildPatchTable();

  if not FileExists(ExePath) then
  begin
    Result := EXE_MISSING;
    Exit;
  end;

  Stock := 0;
  Patched := 0;
  for I := 0 to PATCH_SITES - 1 do
  begin
    Length_ := Length(PatchStock[I]) div 2;
    Found := BytesToHex(ReadFileBytes(ExePath, PatchOffset[I], Length_));
    if Found = PatchStock[I] then
      Stock := Stock + 1
    else if Found = PatchLAA[I] then
      Patched := Patched + 1;
  end;

  if Patched = PATCH_SITES then
    Result := EXE_PATCHED
  else if Stock = PATCH_SITES then
    Result := EXE_STOCK
  else
    Result := EXE_UNKNOWN;

  Log(Format('LAA: %s - %d/%d stock, %d/%d patched, verdict %d', [ExePath,
    Stock, PATCH_SITES, Patched, PATCH_SITES, Result]));
end;

{ A one line description of the exe state, for the system check page. }
function DescribeExe(const ExePath: String): String;
begin
  case ClassifyExe(ExePath) of
    EXE_MISSING: Result := 'hoi3_tfh.exe not found';
    EXE_STOCK:   Result := 'stock exe, limited to 2 GB - will be patched';
    EXE_PATCHED: Result := 'already Large Address Aware - nothing to do';
  else
    Result := 'unrecognised build - will be left untouched';
  end;
end;

{ Back up then patch. Returns True when the exe ends up Large Address Aware. }
function ApplyLargeAddressAware(const GameDir: String; var Message: String): Boolean;
var
  ExePath, BackupPath: String;
  I, State: Integer;
begin
  ExePath := AddBackslash(GameDir) + 'hoi3_tfh.exe';
  BackupPath := AddBackslash(GameDir) + 'hoi3_tfh.exe.preBlackICE';

  State := ClassifyExe(ExePath);

  if State = EXE_PATCHED then
  begin
    Message := 'Already Large Address Aware, left as it is.';
    Result := True;
    Exit;
  end;

  if State = EXE_MISSING then
  begin
    Message := 'hoi3_tfh.exe was not found, so it could not be patched.';
    Result := False;
    Exit;
  end;

  if State = EXE_UNKNOWN then
  begin
    Message := 'This hoi3_tfh.exe is not the build the patch was made for, so it' + #13#10 +
               'was left untouched. The mod will still run, but the game stays' + #13#10 +
               'limited to 2 GB of memory and will be less stable.';
    Result := False;
    Exit;
  end;

  // Only ever taken from a known stock exe, so a restore always gives back a
  // clean binary rather than whatever state a half finished run left behind.
  if not FileExists(BackupPath) then
  begin
    if not CopyFile(ExePath, BackupPath, True) then
    begin
      Message := 'Could not write a backup of hoi3_tfh.exe, so it was not patched.' + #13#10 +
                 'Close the game and any launcher and run the installer again.';
      Result := False;
      Exit;
    end;
    Log('LAA: backed up to ' + BackupPath);
  end;

  for I := 0 to PATCH_SITES - 1 do
  begin
    if not WriteFileBytes(ExePath, PatchOffset[I], HexToBytes(PatchLAA[I])) then
    begin
      // Put the original back rather than leave a half written exe behind.
      CopyFile(BackupPath, ExePath, False);
      Message := 'Writing the patch failed, so the original exe was restored.' + #13#10 +
                 'Make sure the game is closed and that hoi3_tfh.exe is not read only.';
      Result := False;
      Exit;
    end;
  end;

  if ClassifyExe(ExePath) <> EXE_PATCHED then
  begin
    CopyFile(BackupPath, ExePath, False);
    Message := 'The patched exe did not verify, so the original was restored.';
    Result := False;
    Exit;
  end;

  Message := 'Patched for 4 GB. The original is kept as hoi3_tfh.exe.preBlackICE.';
  Result := True;
end;

{ Undo, used by the uninstaller. }
procedure RestoreStockExe(const GameDir: String);
var
  ExePath, BackupPath: String;
begin
  ExePath := AddBackslash(GameDir) + 'hoi3_tfh.exe';
  BackupPath := AddBackslash(GameDir) + 'hoi3_tfh.exe.preBlackICE';
  if FileExists(BackupPath) then
  begin
    if CopyFile(BackupPath, ExePath, False) then
      DeleteFile(BackupPath);
  end;
end;
