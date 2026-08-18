# repo-root aware git status and suspicious file checks
$repoRoot = (git rev-parse --show-toplevel)
Write-Host "Repository root: $repoRoot" -ForegroundColor Cyan

Write-Host "===== GIT STATUS =====" -ForegroundColor Cyan
git -C $repoRoot status --porcelain
Write-Host ""
Write-Host "===== UNTRACKED FILES =====" -ForegroundColor Cyan
git -C $repoRoot ls-files --others --exclude-standard
Write-Host ""
Write-Host "===== SUSPICIOUS ITEMS =====" -ForegroundColor Cyan
# Meaningful suspicious checks; use repo-root-normalized paths
$suspicious = @(
    ".env",
    ".env.local",
    "supabase",
    "supabase/*.sql",
    ".gemini/skills"
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
Write-Host "===== OPTIONAL: GITLEAKS (if installed under tools/gitleaks.exe) =====" -ForegroundColor Cyan
$gitleaks = Join-Path $repoRoot 'tools\\gitleaks.exe'
if (Test-Path $gitleaks) {
    & $gitleaks detect --source $repoRoot --report-path (Join-Path $repoRoot 'gitleaks-report.json')
    if (Test-Path (Join-Path $repoRoot 'gitleaks-report.json')) { Write-Host "gitleaks report saved to gitleaks-report.json" }
} else {
    Write-Host "gitleaks not found at $gitleaks — skipping" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===== END CHECKS =====" -ForegroundColor Cyan
