-- ============================================================
-- PRODUTOS POR CLIENTE — Roteirizacao M. Ferretti
-- O que o vendedor vende para cada cliente e quanto sai por mes (media 12m).
-- Mesmas regras da query principal: so item FATURADO (C6_NOTA preenchido).
-- ============================================================

DECLARE @Meses12 VARCHAR(8) = CONVERT(VARCHAR(8), DATEADD(MONTH, -12, GETDATE()), 112)
DECLARE @Dias120 VARCHAR(8) = CONVERT(VARCHAR(8), DATEADD(DAY,  -120, GETDATE()), 112)
DECLARE @DataFim VARCHAR(8) = CONVERT(VARCHAR(8), GETDATE(), 112)

;WITH ITENS AS (
    SELECT
        SC5.C5_CLIENTE, SC5.C5_LOJACLI, SC5.C5_NUM, SC5.C5_EMISSAO,
        SC6.C6_PRODUTO, SC6.C6_VALOR, SC6.C6_QTDVEN
    FROM SC5010 SC5
    INNER JOIN SC6010 SC6
        ON SC6.C6_FILIAL = SC5.C5_FILIAL
       AND SC6.C6_NUM    = SC5.C5_NUM
    WHERE SC5.D_E_L_E_T_ = ' '
      AND SC6.D_E_L_E_T_ = ' '
      AND SC5.C5_FILIAL   = '01'
      AND SC5.C5_EMISSAO >= @Meses12
      AND SC5.C5_EMISSAO <= @DataFim
      AND ISNULL(LTRIM(RTRIM(SC6.C6_NOTA)), '') <> ''
),
-- so clientes ATIVOS (compraram nos ultimos 120 dias), igual a query principal
ATIVOS AS (
    SELECT DISTINCT C5_CLIENTE, C5_LOJACLI
    FROM ITENS
    WHERE C5_EMISSAO >= @Dias120
)
SELECT
    I.C5_CLIENTE                                        AS cod_cliente,
    I.C5_LOJACLI                                        AS loja,
    LTRIM(RTRIM(I.C6_PRODUTO))                          AS cod_produto,
    LTRIM(RTRIM(ISNULL(SB1.B1_DESC, '')))               AS descricao,
    CONVERT(DECIMAL(14,2), SUM(I.C6_VALOR) / 12.0)      AS valor_medio_mes,
    CONVERT(DECIMAL(14,2), SUM(I.C6_QTDVEN) / 12.0)     AS qtd_media_mes,
    COUNT(DISTINCT I.C5_NUM)                            AS pedidos
FROM ITENS I
INNER JOIN ATIVOS A
    ON A.C5_CLIENTE = I.C5_CLIENTE AND A.C5_LOJACLI = I.C5_LOJACLI
LEFT JOIN SB1010 SB1
    ON SB1.B1_COD    = I.C6_PRODUTO
   AND SB1.B1_FILIAL = ''
   AND SB1.D_E_L_E_T_ = ' '
GROUP BY I.C5_CLIENTE, I.C5_LOJACLI, I.C6_PRODUTO, SB1.B1_DESC
ORDER BY I.C5_CLIENTE, I.C5_LOJACLI, SUM(I.C6_VALOR) DESC
