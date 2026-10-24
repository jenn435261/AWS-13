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
Push-Location app; flutter build web --release; Pop-Location
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

Write-Host '==> staging bundle into cloud/web'
Get-ChildItem cloud\web -Exclude index.html -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
Copy-Item app\build\web\* cloud\web -Recurse -Force

$branch = git branch --show-current
$tmp = 'heroku-deploy-tmp'
git checkout -q -B $tmp
try {
  git add -f cloud/web
  git commit -q -m 'deploy: web bundle' --allow-empty
  git subtree split --prefix=cloud -b heroku-deploy | Out-Null
  if (-not (git remote | Select-String -SimpleMatch heroku)) { git remote add heroku "https://git.heroku.com/$App.git" }
  Write-Host '==> git push heroku'
  git push heroku heroku-deploy:main --force
} finally {
  git checkout -q $branch
  git branch -D heroku-deploy 2>$null | Out-Null
  git branch -D $tmp 2>$null | Out-Null
  git checkout -- cloud/web 2>$null
}
Write-Host "==> done: https://$App.herokuapp.com/healthz"
