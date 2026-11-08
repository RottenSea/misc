# A developer environment. Not applied unless you ask for it, and it needs the internet.

Register-SetupGroup -Id 'dev' -Title 'Developer environment' -Description 'Scoop with Git, Node.js, Python, Rust, Java and command-line tools, then Git and GitHub CLI setup. Needs the internet.'

# Scoop installs into your user profile and is meant to run without administrator rights.
Register-SetupItem -Id 'scoop' -Group 'dev' -Title 'Install Scoop and the tools' -Description 'Installs Scoop, adds its java bucket, then installs git, gh, curl, nodejs-lts, pnpm, python, uv, mingw-winlibs, rustup-gnu, temurin-lts-jdk, fastfetch, yazi, fd, ripgrep, less, fzf, 7zip, jq, poppler, ffmpeg and imagemagick.' -Action {
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
    scoop install gh curl nodejs-lts pnpm python uv mingw-winlibs rustup-gnu temurin-lts-jdk fastfetch yazi fd ripgrep less fzf 7zip jq poppler ffmpeg imagemagick
    if ($LASTEXITCODE -ne 0) { throw 'scoop install reported an error.' }
}

Register-SetupItem -Id 'git-long-paths' -Group 'dev' -Title 'Let Git use long paths' -Description 'Runs git config --global core.longpaths true, so Git can check out files with paths over 260 characters.' -Action {
    git config --global core.longpaths true
    if ($LASTEXITCODE -ne 0) { throw 'git config failed.' }
}

Register-SetupItem -Id 'pi-agent' -Group 'dev' -Title 'Install the pi coding agent' -Description 'Installs @earendil-works/pi-coding-agent from npm globally, without running its install scripts.' -Action {
    npm install -g --ignore-scripts '@earendil-works/pi-coding-agent'
    if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
}

Register-SetupItem -Id 'github-login' -Group 'dev' -Title 'Sign in to GitHub CLI' -Description 'Runs gh auth login for github.com over HTTPS, which opens the browser to sign in.' -Action {
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'gh auth login did not finish.' }
}
