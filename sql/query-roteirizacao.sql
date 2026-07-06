-- ============================================================
-- ROTEIRIZACAO M. FERRETTI
-- Dados de clientes por vendedor para o site de roteirização
-- Executar no SQL Server conectado ao Protheus
-- ============================================================

DECLARE @DataIni VARCHAR(8) = CONVERT(VARCHAR(8), DATEADD(MONTH, -12, GETDATE()), 112)
DECLARE @DataFim VARCHAR(8) = CONVERT(VARCHAR(8), GETDATE(), 112)

;WITH VENDAS AS (
    SELECT
        SC5.C5_CLIENTE,
        SC5.C5_LOJACLI,
        SC5.C5_VEND1,
        SUM(SC6.C6_VALOR)              AS FAT_12M,
        COUNT(DISTINCT SC6.C6_PRODUTO) AS MIX_PRODUTOS,
        COUNT(DISTINCT SC5.C5_NUM)     AS QTD_PEDIDOS,
        MAX(SC5.C5_EMISSAO)            AS ULT_PEDIDO
    FROM SC5010 SC5
    INNER JOIN SC6010 SC6
        ON SC6.C6_FILIAL = SC5.C5_FILIAL
       AND SC6.C6_NUM    = SC5.C5_NUM
    WHERE SC5.D_E_L_E_T_ = ' '
      AND SC6.D_E_L_E_T_ = ' '
      AND SC5.C5_FILIAL   = '01'
      AND SC5.C5_EMISSAO >= @DataIni
      AND SC5.C5_EMISSAO <= @DataFim
    GROUP BY SC5.C5_CLIENTE, SC5.C5_LOJACLI, SC5.C5_VEND1
),
VISITAS_RAW AS (
    SELECT
        LTRIM(RTRIM(r.codcli))    AS codcli,
        LTRIM(RTRIM(r.lojacli))   AS lojacli,
        u.usrerp                  AS vendedor,
        MAX(CONVERT(DATE, r.dtinicio, 103)) AS ULT_VISITA,
        COUNT(*)                  AS QTD_VISITAS
    FROM OPENQUERY(TIMESERVICE,
        'SELECT codcli, lojacli, idusuario, dtinicio
         FROM recagenda
         WHERE status IN (''F'',''R'')
           AND dtinicio >= DATEADD(MONTH,-12,GETDATE())'
    ) r
    INNER JOIN OPENQUERY(TIMESERVICE,
        'SELECT idusuario, usrerp FROM tabuser WHERE usrerp IS NOT NULL AND usrerp != '''''
    ) u ON u.idusuario = r.idusuario
    WHERE r.codcli IS NOT NULL AND LTRIM(RTRIM(r.codcli)) != ''
    GROUP BY LTRIM(RTRIM(r.codcli)), LTRIM(RTRIM(r.lojacli)), u.usrerp
)
SELECT
    SA3.A3_COD                                                     AS cod_vendedor,
    SA3.A3_NOME                                                    AS nome_vendedor,
    SA3.A3_NREDUZ                                                  AS setor,
    SA1.A1_COD                                                     AS cod_cliente,
    SA1.A1_LOJA                                                    AS loja,
    LTRIM(RTRIM(SA1.A1_NOME))                                      AS nome_cliente,
    LTRIM(RTRIM(SA1.A1_MUN))                                       AS municipio,
    LTRIM(RTRIM(SA1.ZZLAT))                                        AS latitude,
    LTRIM(RTRIM(SA1.ZZLONG))                                       AS longitude,
    ISNULL(LTRIM(RTRIM(SA1.A1_CLASVEN)), '')                       AS classificacao,
    ISNULL(V.FAT_12M, 0)                                           AS fat_12m,
    ISNULL(V.MIX_PRODUTOS, 0)                                      AS mix_produtos,
    ISNULL(V.QTD_PEDIDOS, 0)                                       AS qtd_pedidos,
    ISNULL(
        CONVERT(VARCHAR(10), CONVERT(DATE, V.ULT_PEDIDO, 12)), ''
    )                                                              AS ult_pedido,
    ISNULL(CONVERT(VARCHAR(10), VS.ULT_VISITA), '')                AS ult_visita,
    ISNULL(VS.QTD_VISITAS, 0)                                      AS qtd_visitas
FROM SA1010 SA1
INNER JOIN SA3010 SA3
    ON SA3.A3_COD    = SA1.A1_VEND
   AND SA3.A3_FILIAL = ''
   AND SA3.D_E_L_E_T_ = ' '
LEFT JOIN VENDAS V
    ON V.C5_CLIENTE  = SA1.A1_COD
   AND V.C5_LOJACLI  = SA1.A1_LOJA
LEFT JOIN VISITAS_RAW VS
    ON VS.codcli     = SA1.A1_COD
   AND VS.lojacli    = SA1.A1_LOJA
   AND VS.vendedor   = SA3.A3_COD
WHERE SA1.D_E_L_E_T_ = ' '
  AND SA1.A1_FILIAL   = ''
  AND SA1.A1_MSBLQL  != '1'
  AND ISNULL(LTRIM(RTRIM(SA1.ZZLAT)),  '') NOT IN ('', '0')
  AND ISNULL(LTRIM(RTRIM(SA1.ZZLONG)), '') NOT IN ('', '0')
ORDER BY SA3.A3_COD, ISNULL(V.FAT_12M, 0) DESC
