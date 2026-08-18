Write-Host "===== GIT STATUS =====" -ForegroundColor Cyan
git status --porcelain
Write-Host ""
Write-Host "===== UNTRACKED FILES =====" -ForegroundColor Cyan
git ls-files --others --exclude-standard
Write-Host ""
Write-Host "===== SUSPICIOUS ITEMS =====" -ForegroundColor Cyan
@("0", "0)", "people.id", "supabase", "supabase-inventory") | ForEach-Object {
    if (Test-Path $_) {
        Write-Host "$_`: EXISTS"
        $info = Get-Item -Path $_ -Force
        Write-Host "  Type: $(if ($info.PSIsContainer) { 'FOLDER' } else { 'FILE' })"
        Write-Host "  Last Modified: $($info.LastWriteTime)"
    } else {
        Write-Host "$_`: NOT FOUND"
    }
}
Write-Host ""
Write-Host "===== SQL FILES IN SUPABASE/ =====" -ForegroundColor Cyan
if (Test-Path supabase) {
    Get-ChildItem -Recurse supabase -Filter "*.sql" | ForEach-Object { Write-Host $_.FullName }
} else {
    Write-Host "supabase/ folder not found"
}
