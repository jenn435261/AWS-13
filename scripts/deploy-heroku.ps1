# Build the Flutter web app and deploy the Go API + web bundle to Heroku.
#
#   ./scripts/deploy-heroku.ps1 [-App resilience-api-chris]
#
# Prereqs: flutter + heroku on PATH, `heroku login` done, and the `heroku`
# git remote (this script adds it). The built bundle (~43 MB) is NOT committed
# to the repo; it is added only to a throwaway branch that is pushed to Heroku.
param([string]$App = 'resilience-api-chris')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host '==> flutter build web'
Push-Location app; flutter build web --release --no-wasm-dry-run; if ($LASTEXITCODE -ne 0) { Pop-Location; throw "flutter build failed" }; Pop-Location
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

Write-Host '==> staging bundle into cloud/web'
Get-ChildItem cloud\web -Exclude index.html -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
Copy-Item app\build\web\* cloud\web -Recurse -Force

# git writes harmless warnings (e.g. CRLF) to stderr; under PowerShell 5.1 with
# 'Stop' those become terminating errors, so run git with 'Continue' and check
# exit codes explicitly.
$ErrorActionPreference = 'Continue'
function Invoke-Git { & git @args; if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed ($LASTEXITCODE)" } }

$branch = (git branch --show-current)
$tmp = 'heroku-deploy-tmp'
Invoke-Git checkout -q -B $tmp
try {
  Invoke-Git add -f cloud/web
  Invoke-Git commit -q -m 'deploy: web bundle' --allow-empty
  Invoke-Git subtree split --prefix=cloud -b heroku-deploy | Out-Null
  if (-not (git remote | Select-String -SimpleMatch heroku)) { Invoke-Git remote add heroku "https://git.heroku.com/$App.git" }
  Write-Host '==> git push heroku'
  Invoke-Git push heroku heroku-deploy:main --force
} finally {
  git checkout -q -f $branch
  git branch -D heroku-deploy 2>&1 | Out-Null
  git branch -D $tmp 2>&1 | Out-Null
  git reset -q cloud/web 2>&1 | Out-Null
  git checkout -- cloud/web 2>&1 | Out-Null
}
Write-Host "==> done: https://$App.herokuapp.com/healthz"
