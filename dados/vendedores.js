// Endereços residenciais dos vendedores — ponto de partida/chegada do roteiro
// Fonte: cards "ENDEREÇOS VENDEDORES" — coordenadas geocodificadas via Nominatim/OSM
//
// ⚠️ A CHAVE TEM QUE SER O SETOR EXATAMENTE COMO VEM DO ERP (A3_NREDUZ = ?setor= na URL).
// Chave divergente = o motor não acha a casa e cai no centróide dos clientes, o que
// desmancha o grupo-casa e a regra da sexta. Setores do ERP (14):
//   SOROCABA · S.J.BOA VISTA · SETOR PIRACICABA · S.J.DOS CAMPOS · CIRCUITO · ATIBAIA
//   FRANCA · CAMPINAS NORTE · JUNDIAI · SAO CARLOS · ITAPETININGA · RIBEIRAO PRETO
//   INDAIATUBA · CARAGUATATUBA
//
// Onde a casa fica em cidade diferente do nome do setor, está anotado abaixo.
window.VENDEDORES_HOME = {
  "FRANCA":           { nome:"Luis",        lat:-20.5282000, lon:-47.3995000 }, // Franca
  "RIBEIRAO PRETO":   { nome:"Fernando",    lat:-21.1337532, lon:-47.8354706 }, // Jd. Procópio, Ribeirão Preto
  "ITAPETININGA":     { nome:"Nelson",      lat:-23.5919002, lon:-48.0537234 }, // Centro, Itapetininga
  "SETOR PIRACICABA": { nome:"Cominatto",   lat:-22.6779298, lon:-47.6736982 }, // Santa Terezinha, Piracicaba
  "SAO CARLOS":       { nome:"Bragatto",    lat:-22.0180395, lon:-47.8911540 }, // Jd. Macarengo, São Carlos
  "INDAIATUBA":       { nome:"Lucas",       lat:-23.0729207, lon:-47.2065687 }, // Jd. Belval, Indaiatuba
  "CIRCUITO":         { nome:"Rachel",      lat:-22.7073690, lon:-46.7768998 }, // mora em AMPARO
  "SOROCABA":         { nome:"Mauricio",    lat:-23.4895299, lon:-47.4752633 }, // Vila Trujillo, Sorocaba
  "CAMPINAS NORTE":   { nome:"Alan",        lat:-22.9440141, lon:-47.1331817 }, // Cid. Satélite Íris, Campinas
  "JUNDIAI":          { nome:"José Castro", lat:-23.0726175, lon:-46.8422387 }, // mora em ITATIBA
  "ATIBAIA":          { nome:"Eugênio",     lat:-23.1177393, lon:-46.5547861 }, // Campos de Atibaia
  "S.J.DOS CAMPOS":   { nome:"Mariângela",  lat:-23.2036247, lon:-45.8862359 }, // Vila Sanches, S.J. dos Campos
  "S.J.BOA VISTA":    { nome:"Célia",       lat:-21.9718858, lon:-46.7615039 }, // Riviera de São João, S.J. Boa Vista
  "CARAGUATATUBA":    { nome:"Karina",      lat:-23.6263070, lon:-45.4370867 }, // Vila Marcondes, Caraguatatuba
};

// Fora da roteirização (setor excluído da query), mantidos só como referência:
//   SANTA BÁRBARA / Maira (Americana) · LEME / Aparecido
//   RIBEIRÃO PRETO / Lopes = regional Nordeste (não é vendedor de setor)
//   JUNDIAÍ / Eduardo = Contas Chaves (não é vendedor de setor)
window.VENDEDORES_HOME_OUTROS = {
  "SANTA BARBARA":  { nome:"Maira",     lat:-22.7365032, lon:-47.3840733 },
  "LEME":           { nome:"Aparecido", lat:-22.2097364, lon:-47.3875149 },
  "LOPES":          { nome:"Lopes",     lat:-21.1302153, lon:-47.8288414 },
  "EDUARDO":        { nome:"Eduardo",   lat:-23.1914161, lon:-46.8488784 },
};

// Mapeamento cod_vendedor → setor (A3_NREDUZ do ERP)
window.VENDEDORES_COD = {
  "000009": "SOROCABA",
  "000014": "S.J.BOA VISTA",
  "000022": "SETOR PIRACICABA",
  "000027": "S.J.DOS CAMPOS",
  "000082": "CIRCUITO",
  "000095": "ATIBAIA",
  "000097": "FRANCA",
  "000103": "CAMPINAS NORTE",
  "000105": "JUNDIAI",
  "000112": "SAO CARLOS",
  "000116": "ITAPETININGA",
  "000117": "RIBEIRAO PRETO",
  "000118": "INDAIATUBA",
  "000119": "CARAGUATATUBA"
};
