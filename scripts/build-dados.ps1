# ============================================================
# BUILD-DADOS.PS1 — Roteirização M. Ferretti
# Executa a query no SQL Server e gera dados/clientes.js
# Agendar: diário, 06:00 via rodar-auto.ps1
# ============================================================
param(
    [string]$Server      = "189.126.153.75,2270",
    [string]$Database    = "CO136Y_160463_PR_PD",
    [string]$CredTarget  = "Ferretti-LancamentosSQL",
    [string]$RepoRoot    = ($PSScriptRoot + "\.."),
    [switch]$SemPublicar
)

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

# ── Credencial do Cofre (mesmo padrão do site Lançamentos) ──────────────
if (-not ([System.Management.Automation.PSTypeName]'CredManRot').Type) {
    Add-Type -Namespace '' -Name CredManRot -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode, SetLastError=true)]
public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
[System.Runtime.InteropServices.DllImport("advapi32.dll")] public static extern void CredFree(IntPtr cred);
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct CREDENTIAL { public int Flags; public int Type; public IntPtr TargetName; public IntPtr Comment;
  public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten; public int CredentialBlobSize; public IntPtr CredentialBlob;
  public int Persist; public int AttributeCount; public IntPtr Attributes; public IntPtr TargetAlias; public IntPtr UserName; }
public static string GetUser(string t){ IntPtr p; if(!CredRead(t,1,0,out p)) return null; var c=(CREDENTIAL)System.Runtime.InteropServices.Marshal.PtrToStructure(p,typeof(CREDENTIAL)); var u=System.Runtime.InteropServices.Marshal.PtrToStringUni(c.UserName); CredFree(p); return u; }
public static string GetPass(string t){ IntPtr p; if(!CredRead(t,1,0,out p)) return null; var c=(CREDENTIAL)System.Runtime.InteropServices.Marshal.PtrToStructure(p,typeof(CREDENTIAL)); var s=c.CredentialBlobSize>0?System.Runtime.InteropServices.Marshal.PtrToStringUni(c.CredentialBlob,c.CredentialBlobSize/2):null; CredFree(p); return s; }
'@
}

Log "=== Iniciando build-dados ==="

$sqlUser = [CredManRot]::GetUser($CredTarget)
$sqlPass = [CredManRot]::GetPass($CredTarget)
if (-not $sqlPass) { Log "ERRO: credencial '$CredTarget' não encontrada no Cofre."; exit 1 }
Log "Credencial OK (user: $sqlUser)"

# ── Query ────────────────────────────────────────────────────────────────
$sql = Get-Content $SqlFile -Raw -Encoding UTF8
$cs  = "Server=$Server;Database=$Database;User Id=$sqlUser;Password=$sqlPass;Encrypt=True;TrustServerCertificate=True;Connect Timeout=60"

try {
    $conn = New-Object System.Data.SqlClient.SqlConnection($cs)
    $conn.Open()
    Log "Conectado: $Server / $Database"

    $cmd = $conn.CreateCommand()
    $cmd.CommandText  = $sql
    $cmd.CommandTimeout = 600

    $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $ds = New-Object System.Data.DataSet
    $da.Fill($ds) | Out-Null
    $conn.Close()
} catch {
    Log "ERRO na query: $_"; exit 1
}

$rows = $ds.Tables[0].Rows
Log "Query retornou $($rows.Count) registros."

if ($rows.Count -eq 0) {
    Log "Nenhum cliente com geolocalização retornado. Verifique os campos ZZLAT/ZZLONG no SA1010."
    exit 1
}

# ── Agrupa por vendedor ───────────────────────────────────────────────────
$vendedores    = [ordered]@{}
$todosClientes = [System.Collections.Generic.List[object]]::new()

foreach ($row in $rows) {
    $cod = $row["cod_vendedor"].ToString().Trim()
    if (-not $vendedores.Contains($cod)) {
        $setor = $row["setor"].ToString().Trim()
        $vendedores[$cod] = @{
            cod   = $cod
            nome  = $row["nome_vendedor"].ToString().Trim()
            setor = $setor
            senha = ($setor.ToLower() -replace '\s+','')
        }
    }

    $lat = ($row["latitude"].ToString().Trim()  -replace ',','.')
    $lon = ($row["longitude"].ToString().Trim() -replace ',','.')
    $fat = 0.0; [double]::TryParse($row["fat_12m"].ToString(),  [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$fat) | Out-Null
    $mix = 0;   [int]::TryParse($row["mix_produtos"].ToString(), [ref]$mix) | Out-Null
    $ped = 0;   [int]::TryParse($row["qtd_pedidos"].ToString(),  [ref]$ped) | Out-Null
    $vis = 0;   [int]::TryParse($row["qtd_visitas"].ToString(),  [ref]$vis) | Out-Null

    $todosClientes.Add(@{
        cod_vendedor  = $cod
        cod_cliente   = $row["cod_cliente"].ToString().Trim()
        loja          = $row["loja"].ToString().Trim()
        nome_cliente  = ($row["nome_cliente"].ToString().Trim() -replace '"',"'" )
        municipio     = $row["municipio"].ToString().Trim()
        latitude      = $lat
        longitude     = $lon
        classificacao = $row["classificacao"].ToString().Trim()
        tipo_cliente  = $row["tipo_cliente"].ToString().Trim()
        fat_12m       = [math]::Round($fat, 2)
        mix_produtos  = $mix
        qtd_pedidos   = $ped
        ult_pedido    = $row["ult_pedido"].ToString().Trim()
        ult_visita    = $row["ult_visita"].ToString().Trim()
        qtd_visitas   = $vis
    })
}

Log "Vendedores: $($vendedores.Count) | Clientes com geo: $($todosClientes.Count)"

# ── Serializa para JS ─────────────────────────────────────────────────────
function Obj2Json($h) {
    $pairs = foreach ($k in $h.Keys) {
        $v = $h[$k]
        $vj = if ($v -is [string]) { '"' + $v + '"' }
              elseif ($v -is [double] -or $v -is [float]) { $v.ToString("F2", [Globalization.CultureInfo]::InvariantCulture) }
              else { $v.ToString() }
        '"' + $k + '":' + $vj
    }
    '{' + ($pairs -join ',') + '}'
}

$clientesArr = ($todosClientes | ForEach-Object { Obj2Json $_ }) -join ","
$vendArr     = ($vendedores.Values | ForEach-Object { Obj2Json $_ }) -join ","
$ts = Get-Date -Format "dd/MM/yyyy HH:mm"

@"
// Gerado automaticamente por scripts/build-dados.ps1 em $ts
// NAO editar manualmente
window.CLIENTES_DATA = [$clientesArr];
window.VENDEDORES_DATA = [$vendArr];
window.DADOS_ATUALIZADOS_EM = '$ts';
"@ | Out-File $OutFile -Encoding utf8 -NoNewline

Log "clientes.js gerado ($($todosClientes.Count) clientes, $($vendedores.Count) vendedores)"
Log "=== build-dados concluído ==="
