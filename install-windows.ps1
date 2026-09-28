# Windows counterpart to install.sh (Arch) and install-macos.sh. Sets up a
# fresh Windows machine to use this Neovim config: Scoop, language servers,
# formatting tools, a C toolchain for treesitter parsers and plugin builds,
# plugins and the global .clang-format.
#
# Run it from inside a clone of this repo, in a normal (non-admin) PowerShell:
#
#     powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
#
# If the clone isn't at %LOCALAPPDATA%\nvim, it gets linked there with a
# directory junction (no admin or Developer Mode needed); an existing config
# is moved aside first.
#
# Safe to re-run: every step checks before acting, so running this again
# after adding new tools just fills in whatever's missing.
#
# Kept to plain ASCII and Windows PowerShell 5.1 syntax on purpose: a fresh
# Windows only has 5.1, which reads BOM-less files as ANSI and would mangle
# any non-ASCII characters.

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'  # Invoke-WebRequest is very slow with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ScriptDir = $PSScriptRoot
$Failed = New-Object System.Collections.Generic.List[string]
$Skipped = New-Object System.Collections.Generic.List[string]

function Note($msg) { Write-Host ''; Write-Host '==> ' -ForegroundColor Blue -NoNewline; Write-Host $msg }
function Ok($msg)   { Write-Host '  ok: ' -ForegroundColor Green -NoNewline; Write-Host $msg }
function Warn($msg) { Write-Host '  warn: ' -ForegroundColor Yellow -NoNewline; Write-Host $msg }

if ($env:OS -ne 'Windows_NT') {
    Write-Error 'This script is for Windows only. Use install.sh on Arch Linux or install-macos.sh on macOS.'
    exit 1
}

if (-not (Test-Path (Join-Path $ScriptDir 'init.lua'))) {
    Write-Error 'Run this from inside the cloned nvim config (expected init.lua next to install-windows.ps1).'
    exit 1
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# Adds a directory to the user's persistent PATH (if not already there) and
# to this session's PATH, so later steps can use what was just installed.
function Add-UserPath($dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_ } }
    if ($parts -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', (@($dir) + $parts) -join ';', 'User')
    }
    if (($env:Path -split ';') -notcontains $dir) {
        $env:Path = "$dir;$env:Path"
    }
}

function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
Note 'Linking config into place'
# ---------------------------------------------------------------------------
if ($env:XDG_CONFIG_HOME) {
    $NvimConfigDir = Join-Path $env:XDG_CONFIG_HOME 'nvim'
} else {
    $NvimConfigDir = Join-Path $env:LOCALAPPDATA 'nvim'
}
$ScriptDirFull = (Resolve-Path $ScriptDir).Path.TrimEnd('\')
$existing = Get-Item $NvimConfigDir -Force -ErrorAction SilentlyContinue
$linkedHere = $false
if ($existing) {
    if ($existing.FullName.TrimEnd('\') -eq $ScriptDirFull) {
        $linkedHere = $true
    } elseif ($existing.LinkType -and (@($existing.Target) | ForEach-Object { $_.TrimEnd('\') }) -contains $ScriptDirFull) {
        $linkedHere = $true
    }
}
if ($linkedHere) {
    Ok 'already in place'
} else {
    if ($existing) {
        $backup = "$NvimConfigDir.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item -LiteralPath $NvimConfigDir -Destination $backup
        Warn "moved existing config to $backup"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $NvimConfigDir) | Out-Null
    New-Item -ItemType Junction -Path $NvimConfigDir -Target $ScriptDirFull | Out-Null
    if (Test-Path (Join-Path $NvimConfigDir 'init.lua')) {
        Ok "linked $NvimConfigDir -> $ScriptDirFull"
    } else {
        Warn "could not link $NvimConfigDir -> $ScriptDirFull"
        $Failed.Add('config link')
    }
}

# ---------------------------------------------------------------------------
Note 'PowerShell execution policy'
# ---------------------------------------------------------------------------
# Scoop's shims are .ps1 scripts, which the default Restricted policy blocks
# in every future terminal.
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Undefined' -or $policy -eq 'Restricted' -or $policy -eq 'AllSigned') {
    # When this script itself runs with -ExecutionPolicy Bypass, the setting
    # is saved but Set-ExecutionPolicy still throws about the override, so
    # judge success by reading the saved value back.
    try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop } catch { }
    if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'RemoteSigned') {
        Ok 'set to RemoteSigned for the current user'
    } else {
        Warn 'could not set execution policy (maybe enforced by group policy)'
        $Failed.Add('execution policy')
    }
} else {
    Ok "already $policy"
}

# ---------------------------------------------------------------------------
Note 'Scoop'
# ---------------------------------------------------------------------------
if ($env:SCOOP) { $ScoopRoot = $env:SCOOP } else { $ScoopRoot = Join-Path $env:USERPROFILE 'scoop' }
if (-not (Test-Command 'scoop')) {
    Warn 'not found, installing'
    $installer = Join-Path $env:TEMP 'install-scoop.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://get.scoop.sh' -OutFile $installer
    # Scoop refuses to install from an elevated shell unless told to.
    if ($IsAdmin) { & $installer -RunAsAdmin } else { & $installer }
    Remove-Item $installer -ErrorAction SilentlyContinue
}
Add-UserPath (Join-Path $ScoopRoot 'shims')
if (-not (Test-Command 'scoop')) {
    Write-Error 'Scoop install did not produce a usable scoop command - aborting.'
    exit 1
}
Ok "scoop available at $ScoopRoot"

# On ARM64 Windows, install x64 builds of everything. The C toolchain
# (mingw) only exists for x64, and parsers and plugin libraries it compiles
# have to match Neovim's architecture to load, so Neovim must be x64 too.
# Windows runs x64 programs under emulation. This also makes an ARM64 test VM
# behave like an ordinary x64 PC.
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    # Underscore, not hyphen: `scoop config` stores any key as typed, but
    # Scoop only reads default_architecture.
    scoop config default_architecture 64bit | Out-Null
    Warn 'ARM64 Windows: installing x64 builds (run under emulation) so the C toolchain matches Neovim'
}

# Installs one Scoop app unless already present, and verifies it afterwards
# (Scoop's exit codes aren't reliable for "already installed" vs "failed").
# Scoop writes install.json only once an install fully succeeds.
function Install-ScoopApp($app) {
    $name = ($app -split '/')[-1]
    $installed = Join-Path $ScoopRoot "apps\$name\current\install.json"
    if (Test-Path $installed) { Ok "$name (already installed)"; return $true }
    # Out-Host: anything left on the pipeline would become part of the
    # function's return value, making a failed install look truthy.
    # try/catch: some manifests' scripts throw, which would otherwise end
    # this whole script.
    try { scoop install $app | Out-Host } catch { Write-Host $_ }
    if (Test-Path $installed) { Ok $name; return $true }
    Warn "$name failed to install"
    return $false
}

# git first: Scoop needs it to add buckets.
if (-not (Install-ScoopApp 'git')) { $Failed.Add('scoop: git') }

# ---------------------------------------------------------------------------
Note 'Installing core packages (Scoop)'
# ---------------------------------------------------------------------------
$CorePkgs = @(
    'neovim', 'ripgrep', 'fd', 'cmake',
    'make', 'mingw',        # gcc + make for telescope-fzf-native and LuaSnip's jsregexp
    'tree-sitter',          # nvim-treesitter needs it to build parsers
    'llvm',                 # clangd + clang-format
    'rustup-gnu',           # rustfmt; GNU toolchain so no Visual Studio is needed
    'rust-analyzer',
    'go',
    'lua-language-server',
    'nodejs-lts',
    'uv',                   # cmake-language-server (uv brings its own Python, no MSI installer)
    'python',               # jdtls's launcher is a Python script
    'zls'
)
foreach ($pkg in $CorePkgs) {
    if (-not (Install-ScoopApp $pkg)) { $Failed.Add("scoop: $pkg") }
}
# Scoop adds some apps' bin dirs to the user PATH (mingw, llvm, node, rustup)
# rather than shimming them; pick those up in this session too.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')

# ---------------------------------------------------------------------------
Note 'Java (JDK + jdtls)'
# ---------------------------------------------------------------------------
# Scoop's jdtls shims whichever python.exe is on PATH, so it has to come after
# python above; jdtls itself needs Java 21+, which the LTS JDK covers.
if (-not (Test-Path (Join-Path $ScoopRoot 'buckets\java'))) {
    scoop bucket add java | Out-Null
}
if (-not (Install-ScoopApp 'java/temurin-lts-jdk')) { $Failed.Add('scoop: temurin-lts-jdk') }
if (-not (Install-ScoopApp 'jdtls')) { $Failed.Add('scoop: jdtls') }
# The JDK sets JAVA_HOME and adds its bin dir for new terminals; pick those
# up in this session too.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')

# ---------------------------------------------------------------------------
Note 'Nerd Font (Hermit)'
# ---------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $ScoopRoot 'buckets\nerd-fonts'))) {
    scoop bucket add nerd-fonts | Out-Null
}
if (-not (Install-ScoopApp 'nerd-fonts/Hermit-NF')) {
    Warn 'install manually if icons look wrong in nvim'
    $Failed.Add('Nerd Font')
}

# ---------------------------------------------------------------------------
Note 'Installing npm-based language servers'
# ---------------------------------------------------------------------------
if (Test-Command 'npm') {
    $NpmPkgs = @(
        'typescript@6', 'typescript-language-server',  # 7.x has no tsserver.js; see ts_ls in lsp.lua
        'intelephense',
        'vscode-langservers-extracted',
        'vscode-json-languageserver',
        '@tailwindcss/language-server'
    )
    foreach ($pkg in $NpmPkgs) {
        npm install -g $pkg *> $null
        if ($LASTEXITCODE -eq 0) { Ok "npm: $pkg" } else { Warn "npm: $pkg failed to install"; $Failed.Add("npm package: $pkg") }
    }
} else {
    Warn 'npm not found, skipping npm-based language servers'
    $Failed.Add('all npm language servers (npm missing)')
}

# ~/.local/bin holds uv tools and the release binaries below.
$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
New-Item -ItemType Directory -Force -Path $LocalBin | Out-Null
Add-UserPath $LocalBin

# ---------------------------------------------------------------------------
Note 'Installing cmake-language-server (uv)'
# ---------------------------------------------------------------------------
if (Test-Command 'cmake-language-server') {
    Ok 'cmake-language-server (already installed)'
} elseif (Test-Command 'uv') {
    uv tool install cmake-language-server *> $null
    if (Test-Command 'cmake-language-server') { Ok 'cmake-language-server' } else { Warn 'cmake-language-server failed to install via uv'; $Failed.Add('cmake-language-server') }
} else {
    Warn 'uv not found, skipping cmake-language-server'
    $Failed.Add('cmake-language-server (uv missing)')
}

# ---------------------------------------------------------------------------
Note 'Installing gopls and templ (go install)'
# ---------------------------------------------------------------------------
if (Test-Command 'go') {
    $GoBin = Join-Path (go env GOPATH) 'bin'
    Add-UserPath $GoBin
    foreach ($mod in @('golang.org/x/tools/gopls@latest', 'github.com/a-h/templ/cmd/templ@latest')) {
        $name = ($mod -split '/')[-1] -replace '@.*$', ''
        go install $mod *> $null
        if ($LASTEXITCODE -eq 0) { Ok "$name (installed to $GoBin)" } else { Warn "$name failed to install"; $Failed.Add($name) }
    }
} else {
    Warn 'go not found, skipping gopls and templ'
    $Failed.Add('gopls and templ (go missing)')
}

# ---------------------------------------------------------------------------
Note 'Installing language servers not on Scoop (into ~/.local/bin)'
# ---------------------------------------------------------------------------
$TmpDl = Join-Path $env:TEMP "nvim-install-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TmpDl | Out-Null

# Downloads a GitHub release zip and copies the files from one folder inside
# it into ~/.local/bin (the whole folder, since some servers ship DLLs next
# to the exe). Args: name, zip URL, folder inside the zip ('' for the root).
function Install-ReleaseZip($name, $url, $inner) {
    $dir = Join-Path $TmpDl $name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile "$dir\archive.zip" -ErrorAction Stop
        Expand-Archive -Path "$dir\archive.zip" -DestinationPath "$dir\out" -Force -ErrorAction Stop
        Copy-Item -Path (Join-Path "$dir\out" "$inner\*") -Destination $LocalBin -Recurse -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# glsl_analyzer: native builds for both x64 and ARM64.
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $glslAsset = 'aarch64-windows.zip' } else { $glslAsset = 'x86_64-windows.zip' }
if (Install-ReleaseZip 'glsl_analyzer' "https://github.com/nolanderc/glsl_analyzer/releases/latest/download/$glslAsset" 'bin') {
    Ok 'glsl_analyzer'
} else { Warn 'glsl_analyzer failed to download'; $Failed.Add('glsl_analyzer') }

# c3lsp and serve-d: x64 only (they run under emulation on ARM64).
if (Install-ReleaseZip 'c3lsp' 'https://github.com/pherrymason/c3-lsp/releases/latest/download/c3lsp-windows-amd64.zip' 'server\bin\release') {
    Ok 'c3lsp'
} else { Warn 'c3lsp failed to download'; $Failed.Add('c3lsp') }

try {
    $serveDVer = (Invoke-RestMethod -Uri 'https://api.github.com/repos/Pure-D/serve-d/releases/latest' -ErrorAction Stop).tag_name -replace '^v', ''
} catch { $serveDVer = '' }
if ($serveDVer -and (Install-ReleaseZip 'serve-d' "https://github.com/Pure-D/serve-d/releases/download/v$serveDVer/serve-d_$serveDVer-windows-x86_64.zip" '')) {
    Ok "serve-d $serveDVer"
} else { Warn 'serve-d failed to download'; $Failed.Add('serve-d') }

# No Windows builds exist for these.
Warn 'nil (Nix) and alejandra have no Windows builds, skipping'
$Skipped.Add('nil (no Windows build)')
$Skipped.Add('alejandra (no Windows build)')
Warn 'haskell-language-server needs GHCup + MSYS2; install via https://www.haskell.org/ghcup/ if you need it'
$Skipped.Add('haskell-language-server (install via GHCup)')

# ---------------------------------------------------------------------------
Note 'Installing global .clang-format'
# ---------------------------------------------------------------------------
$clangFormatSrc = Join-Path $ScriptDir 'assets\clang-format-global'
if (Test-Path $clangFormatSrc) {
    Copy-Item $clangFormatSrc (Join-Path $env:USERPROFILE '.clang-format') -Force
    Ok 'copied to ~/.clang-format'
} else {
    Warn 'assets/clang-format-global not found in repo, skipping'
    $Failed.Add('.clang-format')
}

# ---------------------------------------------------------------------------
Note 'Installing Neovim plugins and treesitter parsers'
# ---------------------------------------------------------------------------
$SyncLog = Join-Path $env:TEMP 'nvim-install-sync.log'
if (Test-Command 'nvim') {
    # restore installs each plugin at the version pinned in lazy-lock.json, so
    # a fresh machine matches the tested setup. The cyberpunk theme is the
    # exception: it's my own, so it's then updated to its latest commit.
    # Headless nvim exits 0 even if :Lazy doesn't exist, so fail explicitly
    # when lazy.nvim never loaded.
    & nvim --headless "+lua if not package.loaded['lazy'] then vim.cmd('cquit 1') end" `
        '+Lazy! restore' '+Lazy! update cyberpunk' '+Lazy! build LuaSnip' '+qa' 2>&1 | Out-File -Encoding utf8 $SyncLog
    if ($LASTEXITCODE -eq 0) { Ok 'plugins installed at lockfile versions' } else {
        Warn "plugin install reported an issue - see $SyncLog"
        $Failed.Add('lazy.nvim plugin install')
    }

    # The treesitter config installs missing parsers at startup (blocking when
    # headless), so one more start fills any gaps; then check none are missing.
    # The check lives in a temp Lua file: PowerShell 5.1 mangles quoting in
    # long multi-line native arguments.
    $parserCheck = (Join-Path $TmpDl 'missing-parsers') -replace '\\', '/'
    $checkLua = Join-Path $TmpDl 'check-parsers.lua'
    @"
local have = {}
for _, p in ipairs(require('nvim-treesitter.config').get_installed()) do have[p] = true end
local miss = {}
for _, p in ipairs(require('config.parsers')) do if not have[p] then table.insert(miss, p) end end
vim.fn.writefile({ table.concat(miss, ' ') }, '$parserCheck')
"@ | Out-File -Encoding ascii $checkLua
    & nvim --headless "+luafile $($checkLua -replace '\\', '/')" '+qa' 2>&1 | Out-File -Encoding utf8 -Append $SyncLog
    if (-not (Test-Path $parserCheck)) {
        Warn "could not check treesitter parsers - see $SyncLog"
        $Failed.Add('treesitter parser check')
    } else {
        $missing = (Get-Content $parserCheck -Raw).Trim()
        if ($missing) {
            Warn "treesitter parsers missing: $missing - see $SyncLog"
            $Failed.Add("treesitter parsers: $missing")
        } else {
            Ok 'treesitter parsers installed'
        }
    }
} else {
    Warn 'nvim not found even after package install - something went wrong above'
    $Failed.Add('nvim itself')
}

Remove-Item -Recurse -Force $TmpDl -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
Note 'Summary'
# ---------------------------------------------------------------------------
if ($Failed.Count -eq 0) {
    Ok 'Everything installed cleanly.'
} else {
    Warn 'These need attention:'
    foreach ($f in $Failed) { Write-Host "    - $f" }
}
if ($Skipped.Count -gt 0) {
    Warn "Skipped: $($Skipped -join ', ')"
}
Write-Host ''
Write-Host 'Open a new terminal (so the PATH changes take effect) and nvim is ready'
Write-Host 'to use. Set your terminal font to Hurmit Nerd Font Mono (Windows'
Write-Host 'Terminal: Settings > Profiles > Defaults > Appearance) so icons render.'

if ($Failed.Count -eq 0) { exit 0 } else { exit 1 }
