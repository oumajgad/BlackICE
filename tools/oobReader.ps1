$path = Read-Host "Enter path to OOB File"
$regimentPattern = "(?<=((?<!(#.*))regiment(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$shipPattern = "(?<=((?<!(#.*))ship(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$wingPattern = "(?<=((?<!(#.*))wing(\ )?=(\ )?\n?{\n?.*type(\ )?=(\ )?))[^\ ]+(?!\n?})"
$typePattern = "[^#]regiment ?= ?\n?{\n?.*\n?}*"
$types = @{}
Select-String -Path $path -Pattern $regimentPattern | foreach{$types[$_.Matches[0].value] += 1}
Select-String -Path $path -Pattern $shipPattern | foreach{$types[$_.Matches[0].value] += 1}
Select-String -Path $path -Pattern $wingPattern | foreach{$types[$_.Matches[0].value] += 1}
foreach($key in $types.Keys) { Write-Host ($key, $types[$key]) -Separator ";" }