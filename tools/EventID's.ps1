$eventsFolder = Read-Host "Please Enter the path to your Events Folder"
$files = Get-ChildItem -Path $eventsFolder -File -Recurse
$eventIdPattern = "(?<!#.*)(?<=id(\ )?=(\ ))[0-9]+"
$eventIds = @()
$duplicates = @()
foreach ($file in $files) {
    $hits = Select-String -Path $file.PSPath -Pattern $eventIdPattern -AllMatches | foreach{$_.Matches}
    foreach ($match in $hits) {
        if ($eventIds -contains $match.Value/1) {
            $duplicates = $duplicates + $match.Value/1
        } else {
            $eventIds = $eventIds + $match.Value/1
        }
    }
}

$eventIds = $eventIds | Sort
Write-Host "EventIds"
foreach ($id in $eventIds) {
    Write-Host $id
}
Write-Host "Duplicates"
foreach ($id in $duplicates) {
    Write-Host $id
}