-- ============================================================
-- ROTEIRIZACAO M. FERRETTI
-- Dados de clientes por vendedor para o site de roteirizacao
--
-- REGRAS (definidas pelo gestor):
--  * CLIENTE ATIVO   = comprou (faturado) nos ultimos 120 dias.
--  * CARTEIRA        = o cliente e de QUEM VENDEU para ele nesse periodo;
--                      se mais de um vendedor vendeu, fica com o da venda MAIS RECENTE.
--                      (NAO usa o vendedor do cadastro A1_VEND.)
--  * FATURAMENTO     = so item de pedido que virou NOTA FISCAL (C6_NOTA preenchido).
--  * fat_medio_mes   = media mensal dos ultimos 12 meses.
--  * mix_medio       = media de SKUs distintos POR PEDIDO nos ultimos 12 meses.
-- ============================================================

DECLARE @Meses12  VARCHAR(8) = CONVERT(VARCHAR(8), DATEADD(MONTH, -12, GETDATE()), 112) -- metricas
DECLARE @Dias120  VARCHAR(8) = CONVERT(VARCHAR(8), DATEADD(DAY,  -120, GETDATE()), 112) -- ativo + carteira
DECLARE @DataFim  VARCHAR(8) = CONVERT(VARCHAR(8), GETDATE(), 112)

;WITH ITENS AS (
    SELECT
        SC5.C5_CLIENTE,
        SC5.C5_LOJACLI,
        SC5.C5_NUM,
        SC5.C5_VEND1,
        SC5.C5_EMISSAO,
        SC6.C6_PRODUTO,
        SC6.C6_VALOR
    FROM SC5010 SC5
    INNER JOIN SC6010 SC6
        ON SC6.C6_FILIAL = SC5.C5_FILIAL
       AND SC6.C6_NUM    = SC5.C5_NUM
    WHERE SC5.D_E_L_E_T_ = ' '
      AND SC6.D_E_L_E_T_ = ' '
      AND SC5.C5_FILIAL   = '01'
      AND SC5.C5_EMISSAO >= @Meses12
      AND SC5.C5_EMISSAO <= @DataFim
      AND ISNULL(LTRIM(RTRIM(SC6.C6_NOTA)), '') <> ''   -- faturado
),
POR_PEDIDO AS (
    SELECT
        C5_CLIENTE,
        C5_LOJACLI,
        C5_NUM,
        C5_VEND1,
        MAX(C5_EMISSAO)                AS EMISSAO,
        SUM(C6_VALOR)                  AS VLR_PEDIDO,
        COUNT(DISTINCT C6_PRODUTO)     AS SKUS_PEDIDO
    FROM ITENS
    GROUP BY C5_CLIENTE, C5_LOJACLI, C5_NUM, C5_VEND1
),
-- Metricas dos 12 meses (por cliente, independente de vendedor)
VENDAS AS (
    SELECT
        C5_CLIENTE,
        C5_LOJACLI,
        SUM(VLR_PEDIDO) / 12.0                    AS FAT_MEDIO_MES, -- media mensal 12m
        AVG(CAST(SKUS_PEDIDO AS DECIMAL(12,2)))   AS MIX_MEDIO,     -- SKUs medios por pedido
        SUM(VLR_PEDIDO)                           AS FAT_12M,
        COUNT(*)                                  AS QTD_PEDIDOS,
        MAX(EMISSAO)                              AS ULT_PEDIDO
    FROM POR_PEDIDO
    GROUP BY C5_CLIENTE, C5_LOJACLI
),
-- ATIVO (120 dias) + dono da carteira = vendedor da venda MAIS RECENTE no periodo
CARTEIRA AS (
    SELECT C5_CLIENTE, C5_LOJACLI, C5_VEND1, EMISSAO
    FROM (
        SELECT
            C5_CLIENTE, C5_LOJACLI, C5_VEND1, EMISSAO,
            ROW_NUMBER() OVER (
                PARTITION BY C5_CLIENTE, C5_LOJACLI
                ORDER BY EMISSAO DESC, C5_NUM DESC
            ) AS RN
        FROM POR_PEDIDO
        WHERE EMISSAO >= @Dias120
    ) X
    WHERE RN = 1
)
SELECT
    SA3.A3_COD                                                       AS cod_vendedor,
    SA3.A3_NOME                                                      AS nome_vendedor,
    SA3.A3_NREDUZ                                                    AS setor,
    SA1.A1_COD                                                       AS cod_cliente,
    SA1.A1_LOJA                                                      AS loja,
    LTRIM(RTRIM(SA1.A1_NOME))                                        AS nome_cliente,
    LTRIM(RTRIM(SA1.A1_MUN))                                         AS municipio,
    LTRIM(RTRIM(SA1.A1_ZZLAT))                                       AS latitude,
    LTRIM(RTRIM(SA1.A1_ZZLONG))                                      AS longitude,
    ISNULL(LTRIM(RTRIM(SA1.A1_CLASVEN)), '')                         AS classificacao,
    ISNULL(LTRIM(RTRIM(SA1.A1_TIPO)),   '')                          AS tipo_cliente,
    ISNULL(LTRIM(RTRIM(SA1.A1_CGC)),    '')                          AS cnpj,
    CONVERT(DECIMAL(14,2), ISNULL(V.FAT_MEDIO_MES, 0))               AS fat_medio_mes,
    CONVERT(DECIMAL(8,1),  ISNULL(V.MIX_MEDIO,     0))               AS mix_medio,
    ISNULL(V.FAT_12M,     0)                                         AS fat_12m,
    ISNULL(V.QTD_PEDIDOS,  0)                                        AS qtd_pedidos,
    ISNULL(CONVERT(VARCHAR(10), CONVERT(DATE, V.ULT_PEDIDO, 12)), '') AS ult_pedido,
    ''                                                                AS ult_visita,
    0                                                                 AS qtd_visitas
FROM CARTEIRA C
INNER JOIN SA1010 SA1
    ON SA1.A1_COD     = C.C5_CLIENTE
   AND SA1.A1_LOJA    = C.C5_LOJACLI
   AND SA1.A1_FILIAL  = ''
   AND SA1.D_E_L_E_T_ = ' '
INNER JOIN SA3010 SA3
    ON SA3.A3_COD     = C.C5_VEND1        -- vendedor da VENDA, nao do cadastro
   AND SA3.A3_FILIAL  = ''
   AND SA3.D_E_L_E_T_ = ' '
LEFT JOIN VENDAS V
    ON V.C5_CLIENTE = C.C5_CLIENTE
   AND V.C5_LOJACLI = C.C5_LOJACLI
WHERE SA1.A1_MSBLQL  != '1'
  AND ISNULL(LTRIM(RTRIM(SA1.A1_ZZLAT)),  '') NOT IN ('', '0')
  AND ISNULL(LTRIM(RTRIM(SA1.A1_ZZLONG)), '') NOT IN ('', '0')
  -- CLIENTES excluidos da roteirizacao (caso a caso, decisao do gestor):
  -- 50853720/0001 COMERCIAL FURTUOSO (Piracicaba, setor Campinas Norte) = so digitacao,
  -- o vendedor nao visita esse cliente.
  AND NOT (SA1.A1_COD = '50853720' AND SA1.A1_LOJA = '0001')
  -- Excluir setores fora da cobertura da roteirizacao:
  -- Centro Oeste (Marilia, Aracatuba, Bauru, etc.), excluidos, M. Ferretti e outros sem vendedor externo
  -- 2026-07-17: AMERICANA e RIO CLARO saíram da exclusão (passam a ser roteirizados).
  AND LTRIM(RTRIM(SA3.A3_NREDUZ)) NOT IN (
      'EXCLUIDOS',
      'M. FERRETTI',
      'CENTRO OESTE',
      'CENTROOESTE/SET17',
      'C.OESTE\MAR18',
      'MARILIA',
      'ARACATUBA',
      'AVARE',
      'BAURU',
      'FERNANDOPOLIS',
      'PRES.PRUDENTE',
      'RIO PRETO',
      'JABOTICABAL',
      'NORDESTE',
      'CONTAS CHAVES CPS',
      'GERENCIA INTERIOR SP',
      'SUDESTE/NOV20',
      'SUDESTE/OUT17'
  )
ORDER BY SA3.A3_COD, ISNULL(V.FAT_MEDIO_MES, 0) DESC
