# Dev session helper: add Node to PATH and load tools/course-catalog-search/.env
# Usage (repo root):
#   . .\scripts\dev-env.ps1
#   npm run sync-wa-courses
# Or run a one-off command:
#   . .\scripts\dev-env.ps1; node tools/course-catalog-search/search.mjs "fremantle"

$nodeDir = "C:\Program Files\nodejs"
if (Test-Path "$nodeDir\node.exe") {
  if ($env:Path -notlike "*$nodeDir*") {
    $env:Path = "$nodeDir;$env:Path"
  }
} else {
  Write-Warning "Node not found at $nodeDir — install Node.js or adjust dev-env.ps1"
}

$envFile = Join-Path $PSScriptRoot "..\tools\course-catalog-search\.env"
if (-not (Test-Path $envFile)) {
  Write-Warning "Missing $envFile — copy from .env.example and add Supabase credentials."
  return
}

Get-Content $envFile | ForEach-Object {
  $t = $_.Trim()
  if (-not $t -or $t.StartsWith('#')) { return }
  $i = $t.IndexOf('=')
  if ($i -le 0) { return }
  $k = $t.Substring(0, $i).Trim()
  $v = $t.Substring($i + 1).Trim()
  if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
  if ($v.StartsWith("'") -and $v.EndsWith("'")) { $v = $v.Substring(1, $v.Length - 2) }
  if (-not (Get-Item "env:$k" -ErrorAction SilentlyContinue)) {
    Set-Item -Path "env:$k" -Value $v
  }
}

Write-Host "Dev env ready (Node + Supabase vars from course-catalog-search/.env)."
