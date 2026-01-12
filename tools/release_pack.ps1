# File: tools/release_pack.ps1
# Screen: Windows PowerShell (repo root içinde çalıştırılır)
# Purpose: Excel -> pack build -> git commit/push -> Firestore meta için hazır çıktı üretir.

param(
  [string]$CommitMessage = "update words pack",
  [string]$RepoOwner = "emrearinc",
  [string]$RepoName  = "pasgec-words-pack",
  [switch]$OpenFirestore
)

$ErrorActionPreference = "Stop"

# 1) Repo root'u bul (tools klasörünün 1 üstü repo root)
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root


Write-Host "Repo: $root"

# 2) Build pack
Write-Host "Running build..." -ForegroundColor Cyan
python tools\build_words_pack.py

# 3) Version oku
$metaPath = Join-Path $root "pack_meta.json"
if (!(Test-Path $metaPath)) { throw "pack_meta.json bulunamadı." }

$meta = Get-Content $metaPath -Raw | ConvertFrom-Json
$version = [int]$meta.version
if ($version -le 0) { throw "pack_meta.json version hatalı: $version" }

$packFile = "packs/words_pack_v$version.json.gz"
if (!(Test-Path (Join-Path $root $packFile))) { throw "Pack dosyası yok: $packFile" }

# 4) Git commit/push
Write-Host "Git add/commit/push..." -ForegroundColor Cyan
git add .

# değişiklik yoksa hata vermesin
$hasChanges = (git status --porcelain).Length -gt 0
if ($hasChanges) {
  git commit -m "$CommitMessage (v$version)"
  git push
} else {
  Write-Host "No changes to commit." -ForegroundColor Yellow
}

# 5) URL üret (raw link)
$downloadUrl = "https://github.com/$RepoOwner/$RepoName/raw/refs/heads/main/$packFile"

# 6) Firestore'a gireceğin değerleri hazır ver
Write-Host ""
Write-Host "====================" -ForegroundColor Green
Write-Host "FIRESTORE meta/words_pack" -ForegroundColor Green
Write-Host "version    : $version"
Write-Host "downloadUrl: $downloadUrl"
Write-Host "====================" -ForegroundColor Green
Write-Host ""

# 7) Panoya kopyala (Windows)
try {
  $clip = "version=$version`ndownloadUrl=$downloadUrl"
  $clip | Set-Clipboard
  Write-Host "Panoya kopyalandı ✅ (version + downloadUrl)" -ForegroundColor Green
} catch {
  Write-Host "Panoya kopyalanamadı (önemsiz): $_" -ForegroundColor Yellow
}

# 8) İstersen Firestore dokümanını aç (elle düzenleyeceksin)
if ($OpenFirestore) {
  $firestoreUrl = "https://console.firebase.google.com/project/pasgec-a8c7c/firestore/databases/-default-/data/~2Fmeta~2Fwords_pack"
  Start-Process $firestoreUrl
}
