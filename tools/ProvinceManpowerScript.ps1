$Path = Read-Host "Enter path to History/Provinces folder"
$Tag = Read-Host "Enter Tag of target Country"
$files = Get-ChildItem $Path -Recurse -File
$MpPattern = "manpower(\ )?=(\ )?[0-9]+.[0-9]+"
$TagPattern = "^controller(\ )?=(\ )?" + $Tag + "$"

foreach($file in $files) {
    $IsTag = Select-String -Path $file.PSPath -Pattern $TagPattern -Quiet
    $HasManpower = Select-String -Path $file.PSPath -Pattern $MpPattern -Quiet
    if ($HasManpower -and $IsTag) {
        $mp = Select-String -Path $file.PSPath -Pattern $MpPattern | foreach{$_.Matches[0].value}
        $loc = $file.Name | Select-String -Pattern "^[0-9]+" | foreach{$_.Matches[0].value}
        $result = $loc + " = { change_" + $mp + " }"
        Write-Host $result
    }
    foreach($line in Get-Content $file.PSPath) {
        
    }
}