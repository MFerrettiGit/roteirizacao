# ============================================================
# PUBLISH.PS1 — Roteirização M. Ferretti
# Commit e push para GitHub Pages
# ============================================================
param(
    [string]$RepoRoot = $PSScriptRoot + "\..",
    [string]$Msg = "auto: atualiza dados $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

Set-Location $RepoRoot

git add dados/clientes.js
git commit -m $Msg
git push origin main

Write-Host "Publicado: $Msg"
