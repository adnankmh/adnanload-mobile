$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Check-Exit([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed (exit code $LASTEXITCODE)." }
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git missing. Download from https://git-scm.com/downloads/win' }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI missing. Download from https://cli.github.com/' }

    $ErrorActionPreference = 'Continue'
    & gh auth status *> $null
    $authenticated = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if (-not $authenticated) {
        Write-Host 'Complete GitHub login in your browser.' -ForegroundColor Cyan
        & gh auth login --web --git-protocol https
        Check-Exit 'GitHub login'
    }

    $repoName = Read-Host 'Repository name [adnanload-mobile]'
    if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = 'adnanload-mobile' }
    if ($repoName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$') { throw 'Invalid repository name.' }

    if (-not (Test-Path '.git')) {
        & git init -b main
        Check-Exit 'git init'
    }

    $ErrorActionPreference = 'Continue'
    & git config user.name *> $null
    $hasName = ($LASTEXITCODE -eq 0)
    & git config user.email *> $null
    $hasEmail = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if (-not $hasName) {
        $gitName = Read-Host 'Git commit display name'
        if (-not $gitName) { throw 'A commit name is required.' }
        & git config user.name "$gitName"
        Check-Exit 'Git user.name'
    }
    if (-not $hasEmail) {
        $gitEmail = Read-Host 'Git commit email (GitHub noreply email recommended)'
        if (-not $gitEmail) { throw 'A commit email is required.' }
        & git config user.email "$gitEmail"
        Check-Exit 'Git user.email'
    }

    & git add -A
    Check-Exit 'git add'
    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        & git commit -m 'ADNANLOAD Mobile release APK on GitHub Actions'
        Check-Exit 'git commit'
    }

    $ErrorActionPreference = 'Continue'
    $origin = & git remote get-url origin 2>$null
    $hasOrigin = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($origin))
    $ErrorActionPreference = 'Stop'
    if (-not $hasOrigin) {
        Write-Host 'Creating a PRIVATE GitHub repository and uploading...' -ForegroundColor Cyan
        & gh repo create $repoName --private --source . --remote origin --push
        Check-Exit 'gh repo create'
    } else {
        Write-Host "Existing origin: $origin"
        & git push -u origin HEAD:main
        Check-Exit 'git push'
    }
    Write-Host 'Upload complete. Open Actions > ADNANLOAD - Release APK' -ForegroundColor Green
    & gh repo view --web
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
