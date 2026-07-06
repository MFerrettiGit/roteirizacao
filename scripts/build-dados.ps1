# ============================================================
# BUILD-DADOS.PS1 — Roteirização M. Ferretti
# Executa a query no SQL Server e gera dados/clientes.js
# Agendar: diário, 06:00
# ============================================================
param(
    [string]$Server   = "localhost",
    [string]$Database = "PROTHEUS",
    [string]$RepoRoot = $PSScriptRoot + "\.."
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

$OutputDir = Join-Path $RepoRoot "dados"
$SqlFile   = Join-Path $RepoRoot "sql\query-roteirizacao.sql"
$OutFile   = Join-Path $OutputDir "clientes.js"
$LogFile   = Join-Path $RepoRoot "scripts\build-dados.log"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Out-File $LogFile -Append -Encoding utf8
    Write-Host $msg
}

Log "=== Iniciando build-dados ==="

# ── 1. Executa query ──────────────────────────────────────────
Log "Conectando ao SQL Server ($Server / $Database)..."

$sql = Get-Content $SqlFile -Raw -Encoding UTF8

try {
    $conn = New-Object System.Data.SqlClient.SqlConnection
    $conn.ConnectionString = "Server=$Server;Database=$Database;Integrated Security=True;Connection Timeout=60;"
    $conn.Open()

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 300

    $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $ds = New-Object System.Data.DataSet
    $da.Fill($ds) | Out-Null
    $conn.Close()

    $rows = $ds.Tables[0].Rows
    Log "Query retornou $($rows.Count) registros."
} catch {
    Log "ERRO na query: $_"
    exit 1
}

if ($rows.Count -eq 0) {
    Log "Nenhum cliente com geolocalização retornado. Abortando."
    exit 1
}

# ── 2. Agrupa por vendedor ────────────────────────────────────
$vendedores = @{}
$todosClientes = @()

foreach ($row in $rows) {
    $cod = $row["cod_vendedor"].ToString().Trim()
    if (-not $vendedores.ContainsKey($cod)) {
        $vendedores[$cod] = @{
            cod        = $cod
            nome       = $row["nome_vendedor"].ToString().Trim()
            setor      = $row["setor"].ToString().Trim()
            senha      = $row["setor"].ToString().Trim().ToLower() -replace '\s+',''  # senha = setor sem espaços, minúsculo
        }
    }

    $lat  = $row["latitude"].ToString().Trim()
    $lon  = $row["longitude"].ToString().Trim()
    $fat  = 0; [double]::TryParse($row["fat_12m"].ToString(), [ref]$fat) | Out-Null
    $mix  = 0; [int]::TryParse($row["mix_produtos"].ToString(), [ref]$mix) | Out-Null
    $ped  = 0; [int]::TryParse($row["qtd_pedidos"].ToString(), [ref]$ped) | Out-Null
    $vis  = 0; [int]::TryParse($row["qtd_visitas"].ToString(), [ref]$vis) | Out-Null

    # Substitui vírgula por ponto nas coordenadas (padrão BR)
    $lat = $lat -replace ',', '.'
    $lon = $lon -replace ',', '.'

    $todosClientes += @{
        cod_vendedor  = $cod
        cod_cliente   = $row["cod_cliente"].ToString().Trim()
        loja          = $row["loja"].ToString().Trim()
        nome_cliente  = $row["nome_cliente"].ToString().Trim()
        municipio     = $row["municipio"].ToString().Trim()
        latitude      = $lat
        longitude     = $lon
        classificacao = $row["classificacao"].ToString().Trim()
        fat_12m       = [math]::Round($fat, 2)
        mix_produtos  = $mix
        qtd_pedidos   = $ped
        ult_pedido    = $row["ult_pedido"].ToString().Trim()
        ult_visita    = $row["ult_visita"].ToString().Trim()
        qtd_visitas   = $vis
    }
}

Log "Vendedores encontrados: $($vendedores.Count)"

# ── 3. Gera JSON ──────────────────────────────────────────────
function To-JsonValue($v) {
    if ($v -is [string])  { return '"' + ($v -replace '\\','\\' -replace '"','\"') + '"' }
    if ($v -is [double] -or $v -is [float]) { return $v.ToString("F2", [System.Globalization.CultureInfo]::InvariantCulture) }
    return $v.ToString()
}

function Object-ToJson($obj) {
    $pairs = $obj.GetEnumerator() | ForEach-Object {
        '"' + $_.Key + '":' + (To-JsonValue $_.Value)
    }
    return '{' + ($pairs -join ',') + '}'
}

$clientesJson = ($todosClientes | ForEach-Object { Object-ToJson $_ }) -join ","
$vendJson = ($vendedores.Values | ForEach-Object { Object-ToJson $_ }) -join ","
$ts = Get-Date -Format "dd/MM/yyyy HH:mm"

$js = @"
// Gerado automaticamente por scripts/build-dados.ps1
// NÃO editar manualmente — próxima execução sobrescreve
window.CLIENTES_DATA = [$clientesJson];
window.VENDEDORES_DATA = [$vendJson];
window.DADOS_ATUALIZADOS_EM = '$ts';
"@

$js | Out-File $OutFile -Encoding utf8 -NoNewline
Log "Arquivo gerado: $OutFile ($($todosClientes.Count) clientes)"

Log "=== build-dados concluído ==="
