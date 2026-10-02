#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$compiler = 'C:\Program Files\Windhawk\Compiler'
$libraries = @('-lole32','-loleaut32','-lruntimeobject','-lwindowsapp','-lwinhttp','-luser32','-lshell32','-lgdi32','-ladvapi32','-lws2_32','-liphlpapi','-lcrypt32','-lbcrypt','-lcomctl32','-lcomdlg32')
Push-Location $PSScriptRoot
try {
    & "$compiler\bin\clang++.exe" --target=x86_64-w64-mingw32 -std=c++23 -O1 -static -DWH_EDITING -DWH_MOD '-DWH_MOD_ID=L"local@taskbar-ai-quota"' -DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN "-I$compiler\include" -include windhawk_api.h taskbar-side-tests.cpp @libraries -o build\taskbar-side-tests.exe
    if ($LASTEXITCODE) { throw 'Settings test compilation failed' }
    & .\build\taskbar-side-tests.exe
    if ($LASTEXITCODE) { throw "Settings tests failed: $LASTEXITCODE" }
} finally { Pop-Location }
