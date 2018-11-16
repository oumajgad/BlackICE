$path = Read-Host "Enter path to hoi3 / mod directory"
$unitsPath = $path + "\units"
$historyPath = $path + "\history\units"
$regimentPattern = "(?<=((?<!(#.*))regiment(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$shipPattern = "(?<=((?<!(#.*))ship(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$wingPattern = "(?<=((?<!(#.*))wing(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$unitGroupPattern = "(?<=(?<!#.*)(unit_group(\ )?=(\ )?)).*"
$files = Get-ChildItem $unitsPath -File | foreach{$_}
$unitGroups = @{}
foreach($file in $files) {
   Select-String -Path $file.FullName -Pattern $unitGroupPattern | foreach{$unitGroups[$file.BaseName] = $_.Matches[0].value}
}
$files = Get-ChildItem -Path $historyPath -Recurse -File -Include "*_1936.txt" | foreach{$_}
$oobs = @{}
foreach ($file in $files) {
    $oobPath = $file.FullName
    $types = @{}
    Select-String -Path $oobPath -Pattern $regimentPattern | foreach{$types[$_.Matches[0].value] += 1}
    Select-String -Path $oobPath -Pattern $shipPattern | foreach{$types[$_.Matches[0].value] += 1}
    Select-String -Path $oobPath -Pattern $wingPattern | foreach{$types[$_.Matches[0].value] += 1}
    $name = $file.BaseName | Select-String -Pattern "[^_1936]*" | foreach{$_.Matches[0].value}
    $oobs[$name] = $types
}
foreach($oob in $oobs.Keys){
    foreach($type in $oobs[$oob].Keys) {
        Write-Host ($oob, $unitGroups[$type], $type, $oobs[$oob][$type]) -Separator ";"
    }
}