#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$compiler = 'C:\Program Files\Windhawk\Compiler'
$source = Join-Path $PSScriptRoot 'local@taskbar-ai-quota.wh.cpp'
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory $build -Force | Out-Null
$version = [regex]::Match([IO.File]::ReadAllText($source), '(?m)^// @version\s+(\S+)').Groups[1].Value
$id = 'local@taskbar-ai-quota'
$dll = "${id}_${version}_$(Get-Random -Minimum 100000 -Maximum 999999).dll"
$libs = @('-DWIN32_LEAN_AND_MEAN','-lole32','-loleaut32','-lruntimeobject','-lwindowsapp','-lwinhttp','-luser32','-lshell32','-lgdi32','-ladvapi32','-lws2_32','-liphlpapi','-lcrypt32','-lbcrypt','-lcomctl32','-lcomdlg32')
$arguments = @('-std=c++23','-O2','-shared','-DUNICODE','-D_UNICODE','-DWINVER=0x0A00','-D_WIN32_WINNT=0x0A00','-D_WIN32_IE=0x0A00','-DNTDDI_VERSION=0x0A000008','-D__USE_MINGW_ANSI_STDIO=0','-DWH_MOD',('-DWH_MOD_ID=L"'+$id+'"'),('-DWH_MOD_VERSION=L"'+$version+'"'),'C:\Program Files\Windhawk\Engine\1.7.3\64\windhawk.lib','-x','c++',$source,'-include','windhawk_api.h','-target','x86_64-w64-mingw32','-Wl,--export-all-symbols','-o',"$build\$dll") + $libs
Push-Location $compiler
try {
    & "$compiler\bin\clang++.exe" @arguments > "$build\compile.log" 2>&1
    if ($LASTEXITCODE) { Get-Content "$build\compile.log"; throw 'Compilation failed' }
    @{id=$id;version=$version;dll=$dll;source=$source;sha256=(Get-FileHash "$build\$dll").Hash} | ConvertTo-Json | Set-Content "$build\manifest.json"
    "Compiled $dll"
} finally { Pop-Location }
