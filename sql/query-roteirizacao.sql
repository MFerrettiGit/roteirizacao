-- ============================================================
-- ROTEIRIZACAO M. FERRETTI
-- Dados de clientes por vendedor para o site de roteirizacao
-- Visitas do TIMESERVICE: requer usuario com permissao no linked server.
-- Se necessario, executar separadamente e juntar pelo cod_cliente+loja.
-- ============================================================

DECLARE @DataIni VARCHAR(8) = CONVERT(VARCHAR(8), DATEADD(MONTH, -12, GETDATE()), 112)
DECLARE @DataFim VARCHAR(8) = CONVERT(VARCHAR(8), GETDATE(), 112)

-- FATURAMENTO REAL: só item de pedido que virou NOTA FISCAL (C6_NOTA preenchido).
-- Antes somava o pedido inteiro, incluindo cancelado/bloqueado/não faturado.
;WITH POR_PEDIDO AS (
    SELECT
        SC5.C5_CLIENTE,
        SC5.C5_LOJACLI,
        SC5.C5_NUM,
        SUM(SC6.C6_VALOR)              AS VLR_PEDIDO,
        COUNT(DISTINCT SC6.C6_PRODUTO) AS SKUS_PEDIDO,
        MAX(SC5.C5_EMISSAO)            AS EMISSAO
    FROM SC5010 SC5
    INNER JOIN SC6010 SC6
        ON SC6.C6_FILIAL = SC5.C5_FILIAL
       AND SC6.C6_NUM    = SC5.C5_NUM
    WHERE SC5.D_E_L_E_T_ = ' '
      AND SC6.D_E_L_E_T_ = ' '
      AND SC5.C5_FILIAL   = '01'
      AND SC5.C5_EMISSAO >= @DataIni
      AND SC5.C5_EMISSAO <= @DataFim
      AND ISNULL(LTRIM(RTRIM(SC6.C6_NOTA)), '') <> ''   -- faturado
    GROUP BY SC5.C5_CLIENTE, SC5.C5_LOJACLI, SC5.C5_NUM
),
VENDAS AS (
    -- NÃO agrupar por vendedor: se o cliente foi atendido por 2 vendedores no período,
    -- o LEFT JOIN duplicaria a linha do cliente.
    SELECT
        C5_CLIENTE,
        C5_LOJACLI,
        SUM(VLR_PEDIDO) / 12.0                          AS FAT_MEDIO_MES, -- média mensal 12m
        AVG(CAST(SKUS_PEDIDO AS DECIMAL(12,2)))         AS MIX_MEDIO,     -- SKUs médios por pedido
        SUM(VLR_PEDIDO)                                 AS FAT_12M,
        COUNT(*)                                        AS QTD_PEDIDOS,
        MAX(EMISSAO)                                    AS ULT_PEDIDO
    FROM POR_PEDIDO
    GROUP BY C5_CLIENTE, C5_LOJACLI
)
SELECT
    SA3.A3_COD                                                       AS cod_vendedor,
    SA3.A3_NOME                                                      AS nome_vendedor,
    SA3.A3_NREDUZ                                                    AS setor,
    SA1.A1_COD                                                       AS cod_cliente,
    SA1.A1_LOJA                                                      AS loja,
    LTRIM(RTRIM(SA1.A1_NOME))                                        AS nome_cliente,
    LTRIM(RTRIM(SA1.A1_MUN))                                         AS municipio,
    LTRIM(RTRIM(SA1.A1_ZZLAT))                                          AS latitude,
    LTRIM(RTRIM(SA1.A1_ZZLONG))                                         AS longitude,
    ISNULL(LTRIM(RTRIM(SA1.A1_CLASVEN)), '')                         AS classificacao,
    ISNULL(LTRIM(RTRIM(SA1.A1_TIPO)),   '')                         AS tipo_cliente,
    ISNULL(LTRIM(RTRIM(SA1.A1_CGC)),    '')                         AS cnpj,
    CONVERT(DECIMAL(14,2), ISNULL(V.FAT_MEDIO_MES, 0))               AS fat_medio_mes,
    CONVERT(DECIMAL(8,1),  ISNULL(V.MIX_MEDIO,     0))               AS mix_medio,
    ISNULL(V.FAT_12M,     0)                                         AS fat_12m,
    ISNULL(V.QTD_PEDIDOS,  0)                                        AS qtd_pedidos,
    ISNULL(CONVERT(VARCHAR(10), CONVERT(DATE, V.ULT_PEDIDO, 12)), '') AS ult_pedido,
    ''                                                                AS ult_visita,
    0                                                                 AS qtd_visitas
FROM SA1010 SA1
INNER JOIN SA3010 SA3
    ON SA3.A3_COD     = SA1.A1_VEND
   AND SA3.A3_FILIAL  = ''
   AND SA3.D_E_L_E_T_ = ' '
LEFT JOIN VENDAS V
    ON V.C5_CLIENTE = SA1.A1_COD
   AND V.C5_LOJACLI = SA1.A1_LOJA
WHERE SA1.D_E_L_E_T_ = ' '
  AND SA1.A1_FILIAL   = ''
  AND SA1.A1_MSBLQL  != '1'
  AND ISNULL(LTRIM(RTRIM(SA1.A1_ZZLAT)),  '') NOT IN ('', '0')
  AND ISNULL(LTRIM(RTRIM(SA1.A1_ZZLONG)), '') NOT IN ('', '0')
  -- Somente clientes ativos: com pedido nos últimos 12 meses OU classificados
  AND (
        V.FAT_12M > 0
     OR LTRIM(RTRIM(SA1.A1_CLASVEN)) IN ('A','B','C')
  )
  -- Excluir setores fora da cobertura da roteirização:
  -- Centro Oeste (Marília, Araçatuba, Bauru, etc.), excluídos, M. Ferretti e outros sem vendedor externo
  AND LTRIM(RTRIM(SA3.A3_NREDUZ)) NOT IN (
      'EXCLUIDOS',
      'M. FERRETTI',
      'CENTRO OESTE',
      'CENTROOESTE/SET17',
      'C.OESTE\MAR18',
      'MARILIA',
      'ARACATUBA',
      'AMERICANA',
      'AVARE',
      'BAURU',
      'FERNANDOPOLIS',
      'PRES.PRUDENTE',
      'RIO CLARO',
      'RIO PRETO',
      'JABOTICABAL',
      'NORDESTE',
      'CONTAS CHAVES CPS',
      'GERENCIA INTERIOR SP',
      'SUDESTE/NOV20',
      'SUDESTE/OUT17'
  )
ORDER BY SA3.A3_COD, ISNULL(V.FAT_12M, 0) DESC
