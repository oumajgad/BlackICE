# Installs the BlackICE Script extension from the .vsix beside this file into VS Code.
#
# From VS Code's terminal, at the repository root:
#     .\tools\BiceValidator\dist\install-vscode-extension.ps1
# If Windows refuses to run scripts, use instead:
#     powershell -ExecutionPolicy Bypass -File .\tools\BiceValidator\dist\install-vscode-extension.ps1
#
# Run it again after the .vsix changes, then reload VS Code (Developer: Reload Window).

param(
    # Install into this extensions folder instead of VS Code's own - for trying the script.
    [string]$ExtensionsDir
)

$ErrorActionPreference = "Stop"
$vsix = Join-Path $PSScriptRoot "blackice-script.vsix"
if (-not (Test-Path $vsix)) {
    Write-Error "Not found: $vsix"
}

# In VS Code's terminal `code` is the editor the terminal belongs to; elsewhere, look in
# the places the VS Code installer puts it.
$code = Get-Command code -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
if (-not $code) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd")
    )
    $code = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $code) {
    Write-Error "VS Code was not found. In VS Code use Extensions > ... > Install from VSIX and pick $vsix"
}

$arguments = @("--install-extension", $vsix, "--force")
if ($ExtensionsDir) {
    $arguments = @("--extensions-dir", $ExtensionsDir) + $arguments
}
& $code @arguments
if ($LASTEXITCODE -ne 0) {
    Write-Error "VS Code could not install $vsix (exit code $LASTEXITCODE)."
}

Write-Host ""
Write-Host "Installed. Reload VS Code (Developer: Reload Window) to start using it." -ForegroundColor Green
