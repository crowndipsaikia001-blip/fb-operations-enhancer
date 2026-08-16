Param(
  [int]$Port = 3000
)

$p = (Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue).OwningProcess
if ($p) {
  Write-Output "Killing process $p listening on port $Port"
  Stop-Process -Id $p -Force
} else {
  Write-Output "No process found listening on port $Port"
}
