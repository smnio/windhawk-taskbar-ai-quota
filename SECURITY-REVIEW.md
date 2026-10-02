# Source review and local trial — 2026-10-02

## Assessment

Reasonable for a cautious personal trial of the reviewed source with redirect
blocking. No evidence of malicious exfiltration, unrelated telemetry, remote
code download, or command execution was found. This is a manual source review,
not a security certification or a guarantee against undiscovered defects.

Reviewed upstream: `Cleroth/windhawk-taskbar-ai-quota`, commit
`ea63812`, version 1.6.5. Local fork version: 1.6.6. Review covered credential
storage, OAuth sign-in/refresh, network call sites, process inspection, logging,
settings persistence, private taskbar hooks, and worker/UI teardown.

## Data and destinations

- Anthropic sign-in opens `claude.ai`; token exchange/refresh uses
  `console.anthropic.com/v1/oauth/token`; usage uses
  `api.anthropic.com/api/oauth/usage`.
- OpenAI sign-in/token exchange uses `auth.openai.com`; usage uses
  `chatgpt.com/backend-api/wham/usage`. Its callback listener binds IPv4 loopback
  on port 1455 or 1457, validates the callback route and random OAuth state, and
  uses PKCE. No listener starts merely by enabling the mod.
- Access and refresh tokens are stored only in the mod's own Windhawk storage,
  encrypted using current-user Windows DPAPI. Refresh tokens are sent only in
  provider token requests, not as bearer tokens on usage requests. CLI auth
  files are not read or rewritten. Same-user software can decrypt DPAPI blobs;
  encryption at rest does not protect against an already compromised session.
- Antigravity discovers matching processes in the current Windows session,
  reads their command lines for local ports/CSRF tokens, and queries 127.0.0.1.
  It does not persist a Google OAuth token. Certificate validation is relaxed
  for its local self-signed server only; public provider HTTPS retains normal
  certificate validation. Local process identity is not cryptographically
  verified, so this does not protect against malicious same-user processes.
- Logs contain labels, status, and provider error descriptions. No deliberate
  token logging was found; provider error text remains untrusted and potentially
  sensitive. Runtime trial leaves debug logging disabled.

## Remaining risks

1. The DLL executes inside Explorer and hooks private taskbar implementation
   details. Bugs or Windows updates can crash or hang the shell. Worker joins,
   cancellation, owner-thread XAML cleanup, and generation checks are present,
   but this trial does not exhaustively validate all concurrency paths.
2. OAuth permissions exceed a quota-only scope. Anthropic requests
   `org:create_api_key user:profile user:inference`; OpenAI requests
   `openid profile email offline_access api.connectors.read api.connectors.invoke`.
   These are reusable CLI sessions, not narrowly scoped quota keys. Review the
   provider consent screen before signing in. Reducing scopes needs separate
   compatibility testing and has not been attempted here.
3. Anthropic's pasted `code#state` has its state suffix discarded locally;
   PKCE and the generated state are still included in token exchange. Explicit
   local state checking would be another possible defense-in-depth improvement.
4. Usage APIs/public CLI OAuth clients are unofficial integration points and
   can change. This review makes no claim about provider approval or policy.
5. Automatic HTTP redirects were enabled upstream. WinHTTP warns that custom
   headers can transfer across redirects. The fork disables redirects before
   sending both cloud and local requests and fails closed if setting that
   policy fails. This also prevents token-exchange bodies and local CSRF headers
   from being forwarded to a redirected destination.

WinHTTP references:
https://learn.microsoft.com/en-us/windows/win32/winhttp/winhttp-security-considerations
https://learn.microsoft.com/en-us/windows/win32/winhttp/option-flags

## Verification performed

- Upstream `check-mod.ps1`: passed before and after modification.
- Full production DLL compilation and linking with bundled Windhawk clang:
  passed. DLL: `local@taskbar-ai-quota_1.6.6_638699.dll`.
- No-shim guard: compliant before installation; no shim introduced by build.
- Native network regression test extracts the actual redirect helper and local
  HTTP implementation from the source. A synthetic CSRF-bearing request returns
  HTTP 200 normally. HTTP 302 remains 302 and a separate redirect destination
  receives no connection. Passed. No real account tokens used.
- Installed as a separate `local@taskbar-ai-quota` mod. Catalog version 1.6.5
  remains disabled. Windhawk status files reported successful initialization.
- Disabled the fork, confirmed its DLL unloaded, re-enabled it, and confirmed
  it reloaded into five Explorer processes. Original Explorer processes remained
  running during the observed trial.

## Not yet verified

Desktop computer-use transport failed with a missing native pipe, including
retry after runtime reset. No taskbar screenshot, visual preview interaction,
or signed-in quota request was verified. Neither Codex nor Claude credentials
were accessed. Both provider sign-ins require the user. OAuth refresh, quota
accuracy, signed-in unload, notifications, and long-term stability remain to test.

Local test output lives in ignored `build/`. The mod is enabled with fresh,
empty mod-owned settings, ready for the visual preview and account setup.
Disable **Taskbar AI Quota Bars** with local ID `local@taskbar-ai-quota` in
Windhawk to stop the trial. Sign out/remove stored sign-ins separately if any
were added later; disabling alone preserves encrypted credentials.
