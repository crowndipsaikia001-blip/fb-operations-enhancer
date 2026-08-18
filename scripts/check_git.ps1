# Lightweight repository diagnostic script (safe to run from repo root)
# Purpose: quick checks for local development — git status, untracked files, suspicious items, and supabase SQL files

$repoRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
Set-Location -Path $repoRoot

Write-Host "===== GIT STATUS =====" -ForegroundColor Cyan
git status --porcelain
Write-Host ""
Write-Host "===== UNTRACKED FILES =====" -ForegroundColor Cyan
git ls-files --others --exclude-standard
Write-Host ""
Write-Host "===== SUSPICIOUS ITEMS =====" -ForegroundColor Cyan
# Patterns to check relative to repository root
$suspicious = @(
    '.env',
    '.env.local',
    '.env.*',
    'supabase',
    'supabase/*.sql',
    '.gemini/skills',
    '*.pem',
    '*.key'
)

foreach ($p in $suspicious) {
    $full = Join-Path -Path $repoRoot -ChildPath $p
    if (Test-Path -Path $full) {
        Write-Host "$p`: EXISTS"
        $info = Get-Item -Path $full -Force
        Write-Host "  Type: $(if ($info.PSIsContainer) { 'FOLDER' } else { 'FILE' })"
        Write-Host "  Last Modified: $($info.LastWriteTime)"
    } else {
        Write-Host "$p`: NOT FOUND"
    }
}

Write-Host ""
Write-Host "===== SQL FILES IN SUPABASE/ =====" -ForegroundColor Cyan
$supabaseDir = Join-Path $repoRoot 'supabase'
if (Test-Path $supabaseDir) {
    Get-ChildItem -Path $supabaseDir -Recurse -Filter "*.sql" | ForEach-Object { Write-Host $_.FullName }
} else {
    Write-Host "supabase/ folder not found"
}

Write-Host ""
Write-Host "===== NOTE =====" -ForegroundColor Yellow
Write-Host "This script is intended for local discovery only. For deeper secret scanning, use the provided CI tools (gitleaks/truffleHog) or enable GitHub Advanced Security."