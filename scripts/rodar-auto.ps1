# ============================================================
# RODAR-AUTO.PS1 — Roteirização M. Ferretti
# Executado pelo Agendador de Tarefas do Windows
# Tarefa: "Ferretti - Roteirizacao Dados" — diário 06:00
# ============================================================
param(
    [string]$Server   = "localhost",
    [string]$Database = "PROTHEUS",
    [string]$RepoRoot = "C:\Users\COMPRASD\roteirizacao"
)

$log = "$RepoRoot\scripts\rodar-auto.log"
function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File $log -Append -Encoding utf8; Write-Host $m }

Log "=== rodar-auto iniciado ==="

try {
    & "$RepoRoot\scripts\build-dados.ps1" -Server $Server -Database $Database -RepoRoot $RepoRoot
    if ($LASTEXITCODE -ne 0) { Log "Erro no build-dados (exit $LASTEXITCODE). Abortando."; exit 1 }
    & "$RepoRoot\scripts\publish.ps1" -RepoRoot $RepoRoot
    Log "=== Concluído com sucesso ==="
} catch {
    Log "ERRO: $_"
    exit 1
}
