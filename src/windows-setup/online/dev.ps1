# The developer environment, which needs the internet.

# Scoop installs into your user profile either way. Its installer refuses to run as an
# administrator unless told to, and with UAC off every terminal of an administrator account is.
Register-SetupItem -Id 'scoop' -Title 'Install Scoop and the tools' -Description 'Installs Scoop, adds its java bucket, then installs git, gh, curl, fnm, pnpm, python, uv, mingw-winlibs, rustup-gnu, temurin-lts-jdk, fastfetch, yazi, fd, ripgrep, less, fzf, 7zip, jq, poppler, ffmpeg and imagemagick.' -Action {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        $installer = Invoke-RestMethod -Uri 'https://get.scoop.sh'
        if (Test-IsAdmin) {
            & ([scriptblock]::Create($installer)) -RunAsAdmin
        } else {
            & ([scriptblock]::Create($installer))
        }
    }
    $shims = Join-Path $env:USERPROFILE 'scoop\shims'
    if (($env:PATH -split ';') -notcontains $shims) { $env:PATH = "$shims;$env:PATH" }

    # Buckets are Git repositories, so Git comes first.
    scoop install git
    scoop bucket add java
    scoop update
    scoop install gh curl fnm pnpm python uv mingw-winlibs rustup-gnu temurin-lts-jdk fastfetch yazi fd ripgrep less fzf 7zip jq poppler ffmpeg imagemagick
    if ($LASTEXITCODE -ne 0) { throw 'scoop install reported an error.' }
}

Register-SetupItem -Id 'node' -Title 'Install Node.js 24 with fnm' -Description 'Runs fnm install 24 and makes it the default, then adds fnm env to your PowerShell profile so every new terminal finds node and npm.' -Action {
    fnm install 24
    if ($LASTEXITCODE -ne 0) { throw 'fnm install failed.' }
    fnm default 24
    if ($LASTEXITCODE -ne 0) { throw 'fnm default failed.' }
    # This window needs node too, for the npm install below.
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

    $line = 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression'
    if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force | Out-Null }
    if (-not (Select-String -Path $PROFILE -Pattern $line -SimpleMatch -Quiet)) {
        Add-Content -Path $PROFILE -Value $line
    }
}

Register-SetupItem -Id 'git-long-paths' -Title 'Let Git use long paths' -Description 'Runs git config --global core.longpaths true, so Git can check out files with paths over 260 characters.' -Action {
    git config --global core.longpaths true
    if ($LASTEXITCODE -ne 0) { throw 'git config failed.' }
}

Register-SetupItem -Id 'pi-agent' -Title 'Install the pi coding agent' -Description 'Installs @earendil-works/pi-coding-agent from npm globally, without running its install scripts.' -Action {
    npm install -g --ignore-scripts '@earendil-works/pi-coding-agent'
    if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
}

Register-SetupItem -Id 'github-login' -Title 'Sign in to GitHub CLI' -Description 'Runs gh auth login for github.com over HTTPS, which opens the browser to sign in.' -Action {
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'gh auth login did not finish.' }
}
