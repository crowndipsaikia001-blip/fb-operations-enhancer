Write-Host "===== REPO CHECKS =====" -ForegroundColor Cyan
Write-Host ""
Write-Host "===== GIT STATUS (porcelain) =====" -ForegroundColor Cyan
git status --porcelain
Write-Host ""
Write-Host "===== CURRENT BRANCH =====" -ForegroundColor Cyan
git branch --show-current
Write-Host ""
Write-Host "===== REMOTES =====" -ForegroundColor Cyan
git remote -v
Write-Host ""
Write-Host "===== UNTRACKED FILES =====" -ForegroundColor Cyan
git ls-files --others --exclude-standard
Write-Host ""
Write-Host "===== SUSPICIOUS ITEMS =====" -ForegroundColor Cyan
$repoRoot = (git rev-parse --show-toplevel)
# Repo-root-normalized suspicious checks
$suspicious = @(
    ".env",
    ".env.local",
    "supabase",
    "supabase/*.sql",
    ".gemini\\skills"
)
foreach ($item in $suspicious) {
    $full = Join-Path -Path $repoRoot -ChildPath $item
    if (Test-Path $full) {
        Write-Host "$item`: EXISTS at $full"
        $info = Get-Item -LiteralPath $full -Force
        Write-Host "  Type: $(if ($info.PSIsContainer) { 'FOLDER' } else { 'FILE' })"
        Write-Host "  Last Modified: $($info.LastWriteTime)"
    } else {
        Write-Host "$item`: NOT FOUND"
    }
}
Write-Host ""
Write-Host "===== SQL FILES IN SUPABASE/ =====" -ForegroundColor Cyan
if (Test-Path supabase) {
    Get-ChildItem -Recurse supabase -Filter "*.sql" | ForEach-Object { Write-Host $_.FullName }
} else {
    Write-Host "supabase/ folder not found"
}
Write-Host ""
Write-Host "===== TOP 10 LARGEST FILES (tracked) =====" -ForegroundColor Cyan
Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch "\\.git|node_modules" } | Sort-Object Length -Descending | Select-Object -First 10 | ForEach-Object { Write-Host ("{0:N0} bytes - {1}" -f $_.Length, $_.FullName) }
Write-Host ""
Write-Host "===== TOP 10 LARGEST UNTRACKED FILES =====" -ForegroundColor Cyan
$untracked = git ls-files --others --exclude-standard -z | ForEach-Object { $_ };
if ($untracked) {
    $untracked -split "\0" | Where-Object { $_ -ne "" } | ForEach-Object {
        $f = Get-Item -LiteralPath $_ -ErrorAction SilentlyContinue
        if ($f) { Write-Host ("{0:N0} bytes - {1}" -f $f.Length, $f.FullName) }
    }
} else {
    Write-Host "No untracked files"
}
Write-Host ""
Write-Host "===== STAGED CHANGES (files) =====" -ForegroundColor Cyan
$stagedFiles = git diff --cached --name-only -z | ForEach-Object { $_ }
if ($stagedFiles) {
    $stagedFiles -split "\0" | Where-Object { $_ -ne "" } | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No staged files"
}
Write-Host ""
Write-Host "===== GITLEAKS (staged) =====" -ForegroundColor Cyan
$gitleaksPath = Join-Path -Path $PSScriptRoot -ChildPath 'tools\\gitleaks.exe'
if (Test-Path $gitleaksPath) {
    & $gitleaksPath detect --staged --report-path (Join-Path $PSScriptRoot 'gitleaks-staged-report.json') | Out-Null
    if (Test-Path (Join-Path $PSScriptRoot 'gitleaks-staged-report.json')) {
        Write-Host "gitleaks staged report saved to gitleaks-staged-report.json"
    } else {
        Write-Host "gitleaks ran but no report found"
    }
} else {
    Write-Host "gitleaks not found at $gitleaksPath — skip staged gitleaks scan"
}
Write-Host ""
Write-Host "===== END REPO CHECKS =====" -ForegroundColor Cyan
