# File: tools/release_pack.ps1
# Screen: Windows PowerShell (repo root içinde çalıştırılır)
# Purpose: Excel -> pack build -> git commit/push -> Firestore meta için hazır çıktı üretir.

[CmdletBinding()]
param(
  [string]$CommitMessage = "update words pack",
  [string]$RepoOwner = "emrearinc",
  [string]$RepoName  = "pasgec-words-pack",
  [switch]$OpenFirestore
)

$ErrorActionPreference = "Stop"

# UTF-8 düzgün görünsün (✅ gibi)
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

# 1) Repo root'u bul
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
Write-Host "Repo: $root"

# 2) Python var mı?
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  throw "python bulunamadı. Python'ı kurun veya PATH'e ekleyin."
}

# 3) Build pack
Write-Host "Running build..." -ForegroundColor Cyan
python tools\build_words_pack.py

# 4) Version oku
$metaPath = Join-Path $root "pack_meta.json"
if (!(Test-Path $metaPath)) { throw "pack_meta.json bulunamadı." }

$meta = Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
$version = [int]$meta.version
if ($version -le 0) { throw "pack_meta.json version hatalı: $version" }

$packFile = "packs/words_pack_v$version.json.gz"
$packAbs  = Join-Path $root $packFile
if (!(Test-Path $packAbs)) { throw "Pack dosyası yok: $packFile" }

# 5) Git var mı?
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git bulunamadı. Git kurun veya PATH'e ekleyin."
}

# 6) Git add/commit/push (değişiklik varsa)
Write-Host "Git add/commit/push..." -ForegroundColor Cyan
git add .

$hasChanges = (git status --porcelain).Length -gt 0
if ($hasChanges) {
  git commit -m "$CommitMessage (v$version)"
  git push
} else {
  Write-Host "No changes to commit." -ForegroundColor Yellow
}

# 7) Download URL (raw)
# Not: raw.githubusercontent.com linki genelde daha stabil
$downloadUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/$packFile"

# 8) Firestore'a gireceğin değerleri hazır ver
Write-Host ""
Write-Host "====================" -ForegroundColor Green
Write-Host "FIRESTORE meta/words_pack" -ForegroundColor Green
Write-Host "version    : $version"
Write-Host "downloadUrl: $downloadUrl"
Write-Host "====================" -ForegroundColor Green
Write-Host ""

# 9) Panoya kopyala (Windows)
try {
  $clipObj = [pscustomobject]@{ version = $version; downloadUrl = $downloadUrl }
  $clipObj | ConvertTo-Json -Compress | Set-Clipboard
  Write-Host "Panoya kopyalandı ✅ (JSON: version + downloadUrl)" -ForegroundColor Green
} catch {
  Write-Host "Panoya kopyalanamadı (önemsiz): $_" -ForegroundColor Yellow
}

# 10) İstersen Firestore dokümanını aç (elle düzenleyeceksin)
if ($OpenFirestore) {
  $firestoreUrl = "https://console.firebase.google.com/project/pasgec-a8c7c/firestore/databases/-default-/data/~2Fmeta~2Fwords_pack"
  Start-Process $firestoreUrl
}
