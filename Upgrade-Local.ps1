#requires -Version 7.0
param([string]$ExpectedVersion = '1.6.8')
$ErrorActionPreference = 'Stop'
$base = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\local@taskbar-ai-quota'
$build = Join-Path $PSScriptRoot 'build'
$result = Join-Path $build 'upgrade-result.txt'
$changed = $false
try {
    $old = Get-ItemProperty $base
    $manifest = Get-Content "$build\manifest.json" -Raw | ConvertFrom-Json
    $old | Select-Object Version,LibraryFileName,Disabled | ConvertTo-Json | Set-Content "$build\upgrade-before.json"
    if ($old.Version -ne $ExpectedVersion) { throw "Expected installation version $ExpectedVersion" }
    $destination = "C:\ProgramData\Windhawk\Engine\Mods\64\$($manifest.dll)"
    Copy-Item "$build\$($manifest.dll)" $destination
    if ((Get-FileHash $destination).Hash -ne $manifest.sha256) { throw 'DLL hash mismatch' }
    Copy-Item 'C:\ProgramData\Windhawk\ModsSource\local@taskbar-ai-quota.wh.cpp' "$build\source-before-upgrade.wh.cpp"
    $changed = $true
    Set-ItemProperty $base Disabled 1
    Start-Sleep -Seconds 3
    foreach ($process in Get-Process explorer) {
        if ($process.Modules | Where-Object ModuleName -eq $old.LibraryFileName) { throw 'Old DLL did not unload' }
    }
    Copy-Item $manifest.source 'C:\ProgramData\Windhawk\ModsSource\local@taskbar-ai-quota.wh.cpp' -Force
    Set-ItemProperty $base LibraryFileName $manifest.dll
    Set-ItemProperty $base Version $manifest.version
    Set-ItemProperty $base Disabled 0
    Start-Sleep -Seconds 5
    $loaded = @(foreach ($process in Get-Process explorer) {
        if ($process.Modules | Where-Object ModuleName -eq $manifest.dll) { $process.Id }
    })
    if (!$loaded.Count) { throw 'New DLL did not load' }
    $loaded | ConvertTo-Json | Set-Content "$build\upgrade-loaded-processes.json"
    $profilePath = 'C:\ProgramData\Windhawk\userprofile.json'
    Copy-Item $profilePath "$build\userprofile-before-upgrade.json"
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json -AsHashtable
    $profile.mods[$manifest.id] = @{version=$manifest.version;disabled=$false}
    $profile | ConvertTo-Json -Depth 12 | Set-Content $profilePath
    'success' | Set-Content $result
} catch {
    if ($changed) {
        Set-ItemProperty $base Disabled 1
        Start-Sleep -Seconds 3
        Set-ItemProperty $base LibraryFileName $old.LibraryFileName
        Set-ItemProperty $base Version $old.Version
        Copy-Item "$build\source-before-upgrade.wh.cpp" 'C:\ProgramData\Windhawk\ModsSource\local@taskbar-ai-quota.wh.cpp' -Force
        Set-ItemProperty $base Disabled $old.Disabled
    }
    $_ | Out-String | Set-Content $result
    exit 1
}
