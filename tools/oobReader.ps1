$unitsPath = Read-Host "Enter path to Units Directory"
$oobPath = Read-Host "Enter path to OOB File"
$regimentPattern = "(?<=((?<!(#.*))regiment(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$shipPattern = "(?<=((?<!(#.*))ship(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$wingPattern = "(?<=((?<!(#.*))wing(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$unitGroupPattern = "(?<=(?<!#.*)(unit_group(\ )?=(\ )?)).*"
$types = @{}
Select-String -Path $oobPath -Pattern $regimentPattern | foreach{$types[$_.Matches[0].value] += 1}
Select-String -Path $oobPath -Pattern $shipPattern | foreach{$types[$_.Matches[0].value] += 1}
Select-String -Path $oobPath -Pattern $wingPattern | foreach{$types[$_.Matches[0].value] += 1}
$files = Get-ChildItem $unitsPath -File | foreach{$_}
$unitGroups = @{}
foreach($file in $files) {
   Select-String -Path $file.FullName -Pattern $unitGroupPattern | foreach{$unitGroups[$file.BaseName] = $_.Matches[0].value}
}
foreach($key in $types.Keys) { Write-Host ($unitGroups[$key], $key, $types[$key]) -Separator ";" }