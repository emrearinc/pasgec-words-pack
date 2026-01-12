@echo off
setlocal
cd /d %~dp0

powershell -NoProfile -ExecutionPolicy Bypass -File "tools\release_pack.ps1" ^
  -CommitMessage "words update" ^
  -RepoOwner "emrearinc" ^
  -RepoName "pasgec-words-pack" ^
  -OpenFirestore

pause
