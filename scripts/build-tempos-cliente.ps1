# ============================================================
# BUILD-TEMPOS-CLIENTE.PS1 — Roteirização M. Ferretti
# Gera dados/tempos-cliente.js = média INDIVIDUAL de atendimento (min) por cliente,
# a partir da planilha de visitas do TimeService (VISITAS SETORES.xls).
#
# Uso:  powershell -File scripts\build-tempos-cliente.ps1 -Xls "C:\...\VISITAS SETORES.xls"
#
# A média é o tempo real (checkout - checkin) que CADA cliente costuma levar.
# Visitas fora de 5..180 min são descartadas (erro de marcação / almoço).
# Chave = cod_cliente + '_' + loja (igual ao clientes.js). Só grava quem está no cadastro.
# ============================================================
param(
  [Parameter(Mandatory=$true)][string]$Xls,
  [string]$RepoRoot = ""
)
$ErrorActionPreference='Stop'
if (-not $RepoRoot -or -not (Test-Path (Join-Path $RepoRoot 'dados\clientes.js'))) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$lib = "C:\Users\COMPRASD\.claude\skills\fechamento-variaveis\scripts\lib\NPOI.dll"
[void][Reflection.Assembly]::LoadFile($lib)

# copia p/ temp (a planilha costuma estar aberta no Excel)
$tmp = Join-Path $env:TEMP ("visitas_" + [guid]::NewGuid().ToString('N').Substring(0,8) + ".xls")
Copy-Item -LiteralPath $Xls -Destination $tmp -Force
$fs = New-Object System.IO.FileStream($tmp,'Open','Read')
$wb = New-Object NPOI.HSSF.UserModel.HSSFWorkbook($fs); $fs.Close()

function S($row,$c){ if($null -eq $row){return ''}; $x=$row.GetCell($c); if($null -eq $x){return ''}; try{ if($x.CellType -eq 1){return $x.StringCellValue}; if($x.CellType -eq 0){return $x.NumericCellValue}; return $x.ToString() }catch{ return '' } }
function DTcell($row,$c){ if($null -eq $row){return $null}; $x=$row.GetCell($c); if($null -eq $x){return $null}; try{ if($x.CellType -eq 0){ return $x.DateCellValue } }catch{}; $s=''; try{ $s=$x.StringCellValue }catch{ $s=$x.ToString() }; $r=[datetime]::MinValue; if([datetime]::TryParseExact($s,'dd/MM/yyyy HH:mm',[Globalization.CultureInfo]::InvariantCulture,'None',[ref]$r)){return $r}; if([datetime]::TryParse($s,[ref]$r)){return $r}; return $null }

$acc=@{}
for($s=0;$s -lt $wb.NumberOfSheets;$s++){
  $sh=$wb.GetSheetAt($s)
  for($r=1;$r -le $sh.LastRowNum;$r++){
    $row=$sh.GetRow($r); if($null -eq $row){continue}
    if(([string](S $row 8)) -notlike 'VISITA*'){continue}
    $cod=([string](S $row 15)).Trim(); if(-not $cod){continue}
    $lojaRaw=([string](S $row 16)).Trim(); if($lojaRaw -match '\.'){ $lojaRaw=[int][double]$lojaRaw }
    $loja=([string]$lojaRaw).PadLeft(4,'0')
    $ci=DTcell $row 6; $co=DTcell $row 7; if(-not $ci -or -not $co){continue}
    $dur=($co-$ci).TotalMinutes
    if($dur -lt 5 -or $dur -gt 180){continue}
    $key="$cod`_$loja"
    if(-not $acc.ContainsKey($key)){ $acc[$key]=New-Object System.Collections.ArrayList }
    [void]$acc[$key].Add($dur)
  }
}

$js=Get-Content (Join-Path $RepoRoot "dados\clientes.js") -Raw
$i=$js.IndexOf('['); $fim=$js.IndexOf('window.VENDEDORES_DATA'); $j=$js.LastIndexOf(']',$fim)
$cli=$js.Substring($i,$j-$i+1)|ConvertFrom-Json
$idsCad=@{}; foreach($c in $cli){ $idsCad[("$($c.cod_cliente)_$($c.loja)")]=$true }

$pairs=New-Object System.Collections.ArrayList
foreach($k in $acc.Keys){
  if(-not $idsCad.ContainsKey($k)){continue}
  $m=[math]::Round(($acc[$k]|Measure-Object -Average).Average)
  [void]$pairs.Add('"'+$k+'":'+$m)
}
$ts=Get-Date -Format 'dd/MM/yyyy HH:mm'
$body ="// Gerado por scripts/build-tempos-cliente.ps1 em $ts a partir de VISITAS SETORES.xls`n"
$body+="// Media INDIVIDUAL de atendimento por cliente (min), das visitas reais.`n"
$body+="// Chave = cod_cliente + '_' + loja. Visitas fora de 5..180 min descartadas.`n"
$body+="window.TEMPO_CLIENTE = {"+($pairs -join ",")+"};"
$out=Join-Path $RepoRoot "dados\tempos-cliente.js"
Set-Content -Path $out -Value $body -Encoding UTF8 -NoNewline
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
Write-Host "tempos-cliente.js gerado: $($pairs.Count) clientes com media real (de $($idsCad.Count) no cadastro)."
