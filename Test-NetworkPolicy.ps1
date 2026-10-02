#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllText("$PSScriptRoot\local@taskbar-ai-quota.wh.cpp")
$helperStart = $source.IndexOf('static bool DisableHttpRedirects(')
$helperEnd = $source.IndexOf("`n}", $helperStart) + 2
$localStart = $source.IndexOf('static HttpResult HttpRequestLocal(int port, bool secure, PCWSTR path, PCWSTR csrfToken,' , $source.IndexOf('// The language server is loopback-only'))
$localEnd = $source.IndexOf('static bool ParseAntigravityQuotaSummary(', $localStart)
$testSource = @'
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#include <string>
#include <cstdlib>
#include <cstdio>
static bool g_unloading = false;
struct HttpResult { bool ok=false; int status=0; int retryAfterSec=0; std::string body; };
static bool TrackHttpHandle(HINTERNET h) { return h != nullptr; }
static bool UntrackHttpHandle(HINTERNET) { return true; }
'@ + "`n" + $source.Substring($helperStart,$helperEnd-$helperStart) + "`n" + $source.Substring($localStart,$localEnd-$localStart) + @'
int main(int argc, char** argv) {
    if (argc != 3) return 2;
    auto result = HttpRequestLocal(atoi(argv[1]), false, L"/quota", L"synthetic-test-token", 2000);
    printf("ok=%d status=%d\n", result.ok, result.status);
    return result.ok && result.status == atoi(argv[2]) ? 0 : 1;
}
'@
$build = Join-Path $PSScriptRoot 'build'
[IO.File]::WriteAllText("$build\network-policy-test.cpp",$testSource)
& 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' --target=x86_64-w64-mingw32 -std=c++23 -static "$build\network-policy-test.cpp" -lwinhttp -o "$build\network-policy-test.exe"
if ($LASTEXITCODE) { throw 'Network policy test compilation failed' }
$target = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$target.Start()
try {
    $targetPort = $target.LocalEndpoint.Port
    foreach ($status in @(200,302)) {
        $server = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
        $server.Start()
        try {
            $process = Start-Process "$build\network-policy-test.exe" -ArgumentList @($server.LocalEndpoint.Port,$status) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$build\network-$status.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (!$server.Pending() -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
            if (!$server.Pending()) { throw 'No local request received' }
            $client = $server.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $stream.ReadTimeout = 3000
                $buffer = [byte[]]::new(16384)
                $count = $stream.Read($buffer,0,$buffer.Length)
                $request = [Text.Encoding]::ASCII.GetString($buffer,0,$count)
                if (!$request.Contains('X-Codeium-Csrf-Token: synthetic-test-token')) { throw 'Expected test header missing' }
                $headers = if ($status -eq 302) { "Location: http://127.0.0.1:$targetPort/redirected`r`n" } else { '' }
                $response = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status Test`r`n${headers}Content-Length: 2`r`nConnection: close`r`n`r`n{}")
                $stream.Write($response,0,$response.Length)
            } finally { $client.Dispose() }
            if (!$process.WaitForExit(5000)) { $process.Kill(); throw 'Test timed out' }
            if ($process.ExitCode) { throw "HTTP $status test failed" }
            if ($target.Pending()) { throw 'Request followed redirect and leaked the test header' }
            Get-Content "$build\network-$status.txt"
        } finally { $server.Stop() }
    }
    'PASS: normal requests work; redirects do not reach a second endpoint.'
} finally { $target.Stop() }
