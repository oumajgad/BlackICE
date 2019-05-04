param([string] $path);
function addDirectory($path, $pattern) {
    if ($path -cmatch $pattern) {
        Write-Host $path;
        $directoryName = split-path -leaf -Path $path;
        $out = '<Directory Id="' + $path + '" Name="' + $directoryName + '">';
        $data = Get-ChildItem -Path $path -Directory;
        foreach($item in $data) {
            $directoryOut = addDirectory -path $item.FullName -pattern $pattern;
            $out = $out + $directoryOut;
        }
        $data = Get-ChildItem -Path $path -File;
        foreach($item in $data) {
            $out = $out + '<File Source="' + "$path\$item" + '" />';
        }
        $out = $out + "</Directory>";
        return $out;
    }

}
$whitelist = Get-Content -Path "$path/installWhitelist.txt";
$whitelist = $whitelist -join '|';
$directoryName = split-path -leaf -Path $path;
$pattern = "$directoryName\\?(($whitelist)|$)";
addDirectory -path $path -pattern $pattern| Out-File -FilePath "$path\test.wxs";