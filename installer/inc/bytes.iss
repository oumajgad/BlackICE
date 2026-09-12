[Code]

// ---------------------------------------------------------------------------
// Raw byte access for the exe patch.
//
// Pascal Script has no binary file API of its own, but TFileStream is exposed
// and its Read/Write take an AnyString, which carries one byte per character.
// Everything here therefore moves bytes through AnsiString - never String,
// which is UTF-16 in Unicode Inno and would silently double every byte.
// ---------------------------------------------------------------------------

const
  // Declared locally rather than relying on the Delphi names being predeclared.
  fmRead          = $0000;
  fmReadWrite     = $0002;
  fmDenyNone      = $0040;
  fmDenyWrite     = $0020;
  soBeginning     = 0;

{ The value of one hex digit, or -1. Done with Pos rather than StrToInt or a
  character range, neither of which Pascal Script handles the way Delphi does. }
function HexDigit(C: Char): Integer;
begin
  Result := Pos(Uppercase(C), '0123456789ABCDEF') - 1;
end;

{ Parse a hex string such as '9165E5' into the three bytes it names. }
function HexToBytes(const Hex: String): AnsiString;
var
  I, High, Low: Integer;
begin
  Result := '';
  I := 1;
  while I < Length(Hex) do
  begin
    High := HexDigit(Hex[I]);
    Low := HexDigit(Hex[I + 1]);
    if (High < 0) or (Low < 0) then
    begin
      Result := '';
      Exit;
    end;
    Result := Result + Chr((High * 16) + Low);
    I := I + 2;
  end;
end;

{ Render bytes back to lower case hex, for log lines that say what was found. }
function BytesToHex(const Data: AnsiString): String;
var
  I, Value: Integer;
  Digits: String;
begin
  Digits := '0123456789abcdef';
  Result := '';
  for I := 1 to Length(Data) do
  begin
    Value := Ord(Data[I]);
    Result := Result + Digits[(Value div 16) + 1] + Digits[(Value mod 16) + 1];
  end;
end;

{ Read Count bytes at Offset. Returns '' if the file or the range is unreadable. }
function ReadFileBytes(const FileName: String; Offset: Int64; Count: Integer): AnsiString;
var
  Stream: TFileStream;
  Buffer: AnsiString;
begin
  Result := '';
  try
    Stream := TFileStream.Create(FileName, fmRead or fmDenyNone);
    try
      if Stream.Size < Offset + Count then
        Exit;
      Stream.Seek(Offset, soBeginning);
      SetLength(Buffer, Count);
      if Stream.Read(Buffer, Count) = Count then
        Result := Buffer;
    finally
      Stream.Free;
    end;
  except
    Result := '';
  end;
end;

{ Write Data at Offset, in place. The file must already be at least that long. }
function WriteFileBytes(const FileName: String; Offset: Int64; const Data: AnsiString): Boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  try
    Stream := TFileStream.Create(FileName, fmReadWrite or fmDenyWrite);
    try
      if Stream.Size < Offset + Length(Data) then
        Exit;
      Stream.Seek(Offset, soBeginning);
      Result := Stream.Write(Data, Length(Data)) = Length(Data);
    finally
      Stream.Free;
    end;
  except
    Result := False;
  end;
end;
