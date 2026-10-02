#requires -Version 7.0
# Run elevated. Installs only this separate local mod; never replaces the catalog mod.
$ErrorActionPreference = 'Stop'
$result = Join-Path $PSScriptRoot 'build\install-result.txt'
$changed = $false
$base = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\local@taskbar-ai-quota'
try {
    if (Test-Path $base) { throw 'Local mod already exists; refusing to overwrite it.' }
    if ((Get-ItemProperty 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\taskbar-ai-quota').Disabled -ne 1) { throw 'Disable the catalog mod first.' }
    $manifest = Get-Content "$PSScriptRoot\build\manifest.json" -Raw | ConvertFrom-Json
    $runtime = 'C:\ProgramData\Windhawk\Engine\Mods\64'
    $destination = Join-Path $runtime $manifest.dll
    Copy-Item "$PSScriptRoot\build\$($manifest.dll)" $destination
    if ((Get-FileHash $destination).Hash -ne $manifest.sha256) { throw 'DLL hash mismatch' }
    Copy-Item $manifest.source 'C:\ProgramData\Windhawk\ModsSource\local@taskbar-ai-quota.wh.cpp'
    New-Item $base -Force | Out-Null
    $changed = $true
    foreach ($entry in @{LibraryFileName=$manifest.dll;Version=$manifest.version;Include='explorer.exe';Exclude='';Architecture='x86-64'}.GetEnumerator()) {
        New-ItemProperty $base $entry.Key -Value $entry.Value -PropertyType String -Force | Out-Null
    }
    New-ItemProperty $base Disabled -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty $base LoggingEnabled -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty $base SettingsChangeTime -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -PropertyType DWord -Force | Out-Null
    Set-ItemProperty $base Disabled 0
    Start-Sleep -Seconds 5
    $statuses = @(foreach ($file in Get-ChildItem 'C:\ProgramData\Windhawk\Engine\ModsWritable\mod-status' -Filter '*_local@taskbar-ai-quota') {
        $stream = [IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try { $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::Unicode); $status=$reader.ReadToEnd() } finally { $stream.Dispose() }
        @{file=$file.Name;status=$status}
    })
    $statuses | ConvertTo-Json | Set-Content "$PSScriptRoot\build\initial-status.json"
    if (!$statuses.Count -or @($statuses | Where-Object status -ne 'explorer.exe|Loaded').Count) { throw 'Mod initialization failed' }
    # Exercise the real shell unload/reload path before leaving the mod enabled.
    Set-ItemProperty $base Disabled 1
    Start-Sleep -Seconds 3
    foreach ($process in Get-Process explorer) {
        if ($process.Modules | Where-Object ModuleName -eq $manifest.dll) { throw 'DLL did not unload' }
    }
    Set-ItemProperty $base Disabled 0
    Start-Sleep -Seconds 4
    $loaded = @(foreach ($process in Get-Process explorer) {
        if ($process.Modules | Where-Object ModuleName -eq $manifest.dll) { $process.Id }
    })
    if (!$loaded.Count) { throw 'DLL did not reload' }
    $loaded | ConvertTo-Json | Set-Content "$PSScriptRoot\build\loaded-processes.json"
    $profilePath = 'C:\ProgramData\Windhawk\userprofile.json'
    Copy-Item $profilePath "$PSScriptRoot\build\userprofile-before.json"
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json -AsHashtable
    $profile.mods[$manifest.id] = @{version=$manifest.version;disabled=$false}
    $profile | ConvertTo-Json -Depth 12 | Set-Content $profilePath
    'success: initialization, unload and reload passed' | Set-Content $result
} catch {
    if ($changed) { Set-ItemProperty $base Disabled 1 }
    $_ | Out-String | Set-Content $result
    exit 1
}
