[Code]

// ---------------------------------------------------------------------------
// Choosing which versions to remove, on the way out.
//
// The mirror of the page the installer shows. Without it there is no way to
// drop an old version short of reinstalling: the installer only offers that
// while installing something new.
//
// The uninstaller has no wizard pages of its own, so this is a custom form.
//
// Two outcomes, and the distinction matters:
//
//   everything ticked  ->  a real uninstall. Inno removes what it installed,
//                          the entry goes from the apps list, and the usual
//                          offer to restore the exe and sprites follows.
//
//   only some ticked   ->  housekeeping. Those folders go, BlackICE stays
//                          installed, and InitializeUninstall returns False so
//                          Inno removes nothing else. The entry is relabelled
//                          to the newest version still present, so the apps
//                          list never names a version that is no longer there.
//
// Saves are never touched either way - they live outside the game folder.
// ---------------------------------------------------------------------------

{ Where this install recorded itself, so a partial removal can relabel it.
  Which hive depends on whether it was installed for all users or just one. }
function UninstallRegKey(): String;
begin
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\'
            + ExpandConstant('{#SetupSetting("AppId")}') + '_is1';
end;

{ Point the apps list entry at the newest version still on disk. }
procedure RelabelUninstallEntry(const GameDir: String);
var
  Newest: String;
  I: Integer;
begin
  // ScanOldVersions with no folder excluded lists everything that is left.
  ScanOldVersions(GameDir, '');
  if OldVersionCount = 0 then
    Exit;

  // The scan returns them in the order Windows enumerates, which sorts
  // lexically, so the last one is the highest version for names of this shape.
  Newest := OldVersionFolder[OldVersionCount - 1];
  for I := 0 to OldVersionCount - 1 do
    if CompareText(OldVersionFolder[I], Newest) > 0 then
      Newest := OldVersionFolder[I];

  if not RegWriteStringValue(HKLM, UninstallRegKey(), 'DisplayName', Newest) then
    RegWriteStringValue(HKCU, UninstallRegKey(), 'DisplayName', Newest);
  Log('UninstallPick: entry relabelled to ' + Newest);
end;

{ Ask which versions to remove.

  Returns True to let the uninstall proceed, False to stop it - either because
  the player cancelled, or because they chose to remove only some versions and
  keep BlackICE installed. }
function ChooseVersionsToRemove(const GameDir: String): Boolean;
var
  Form: TSetupForm;
  Caption, Explain, Note: TNewStaticText;
  List: TNewCheckListBox;
  OkButton, CancelButton: TNewButton;
  I, Ticked, Removed, ModalResult: Integer;
  Reclaimed: Int64;
  Message: String;
begin
  Result := True;

  ScanOldVersions(GameDir, '');
  Log(Format('UninstallPick: %d version(s) present in %s', [OldVersionCount, GameDir]));

  // Nothing to choose between: the ordinary uninstall says it all.
  if OldVersionCount < 2 then
  begin
    Log('UninstallPick: fewer than two, no picker shown');
    Exit;
  end;

  // Size is passed in rather than assigned: CreateCustomForm takes the client
  // area up front. The last two arguments are auto scroll and "no vertical
  // sizing", which is what we want - nothing here grows downwards.
  Form := CreateCustomForm(ScaleX(440), ScaleY(300), False, True);
  try
    Form.Caption := 'Remove BlackICE';

    Caption := TNewStaticText.Create(Form);
    Caption.Parent := Form;
    Caption.Left := ScaleX(16);
    Caption.Top := ScaleY(14);
    Caption.Width := Form.ClientWidth - ScaleX(32);
    Caption.AutoSize := False;
    Caption.Height := ScaleY(16);
    Caption.Font.Style := [fsBold];
    Caption.Caption := 'More than one version is installed. Which should go?';

    Explain := TNewStaticText.Create(Form);
    Explain.Parent := Form;
    Explain.Left := ScaleX(16);
    Explain.Top := ScaleY(36);
    Explain.Width := Form.ClientWidth - ScaleX(32);
    Explain.AutoSize := False;
    Explain.Height := ScaleY(32);
    Explain.WordWrap := True;
    Explain.Caption := 'Leave them all ticked to remove BlackICE completely. '
      + 'Untick the ones you want to keep and only the rest are removed.';

    List := TNewCheckListBox.Create(Form);
    List.Parent := Form;
    List.Left := ScaleX(16);
    List.Top := ScaleY(74);
    List.Width := Form.ClientWidth - ScaleX(32);
    List.Height := ScaleY(150);
    List.BorderStyle := bsSingle;
    for I := 0 to OldVersionCount - 1 do
      List.AddCheckBox(OldVersionCaption(I), '', 0, True, True, False, False, nil);

    Note := TNewStaticText.Create(Form);
    Note.Parent := Form;
    Note.Left := ScaleX(16);
    Note.Top := ScaleY(232);
    Note.Width := Form.ClientWidth - ScaleX(32);
    Note.AutoSize := False;
    Note.Height := ScaleY(30);
    Note.WordWrap := True;
    Note.Caption := 'Saved games are never touched - they are kept in '
      + 'Documents\Paradox Interactive\Hearts of Iron III\, not in the game folder.';

    OkButton := TNewButton.Create(Form);
    OkButton.Parent := Form;
    OkButton.Width := ScaleX(90);
    OkButton.Height := ScaleY(26);
    OkButton.Left := Form.ClientWidth - ScaleX(200);
    OkButton.Top := Form.ClientHeight - ScaleY(38);
    OkButton.Caption := 'Remove';
    OkButton.ModalResult := mrOk;
    OkButton.Default := True;

    CancelButton := TNewButton.Create(Form);
    CancelButton.Parent := Form;
    CancelButton.Width := ScaleX(90);
    CancelButton.Height := ScaleY(26);
    CancelButton.Left := Form.ClientWidth - ScaleX(104);
    CancelButton.Top := Form.ClientHeight - ScaleY(38);
    CancelButton.Caption := 'Cancel';
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;

    ModalResult := Form.ShowModal();
    Log(Format('UninstallPick: dialog closed with ModalResult %d (mrOk is %d)', [ModalResult,
        mrOk]));
    if ModalResult <> mrOk then
    begin
      Result := False;
      Exit;
    end;

    Ticked := 0;
    for I := 0 to OldVersionCount - 1 do
      if List.Checked[I] then
        Ticked := Ticked + 1;

    if Ticked = 0 then
    begin
      MsgBox('Nothing was ticked, so nothing has been removed.', mbInformation, MB_OK);
      Result := False;
      Exit;
    end;

    // Everything: fall through to the normal uninstall, which also offers to
    // put the exe and the sprites back.
    Log(Format('UninstallPick: %d of %d ticked', [Ticked, OldVersionCount]));
    if Ticked = OldVersionCount then
    begin
      Log('UninstallPick: all ticked, proceeding with a full uninstall');
      Exit;
    end;

    // A subset: do it here and stop Inno removing anything else.
    Removed := 0;
    Reclaimed := 0;
    for I := 0 to OldVersionCount - 1 do
    begin
      if not List.Checked[I] then
        Continue;
      if RemoveOldVersion(GameDir, OldVersionFolder[I]) then
      begin
        Removed := Removed + 1;
        Reclaimed := Reclaimed + OldVersionBytes[I];
      end;
    end;

    RelabelUninstallEntry(GameDir);

    Message := Format('Removed %d version(s), freeing %s.', [Removed,
               DescribeSize(Reclaimed)]) + #13#10 + #13#10
               + 'BlackICE is still installed, so the game has been left exactly '
               + 'as it is - the memory patch and the moved sprites are untouched.';
    MsgBox(Message, mbInformation, MB_OK);
    Result := False;
  finally
    Form.Free();
  end;
end;
