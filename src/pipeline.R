
#' Os pipelines são sequências de nós que transformam dados em um projeto. 
#' Eles são definidos em um arquivo pipeline.R. Cada pipeline é uma sequência de 
#' nós interconectados, onde a saída de um nó é a entrada de outro. 
#' Isso permite que os dados fluam por todo o pipeline de transformação e sejam 
#' transformados em diferentes etapas do processo


# Carregando dados do planilhao (ALIATA|ALIVAR)
data <- load_data()

# Arrumar os dados do planilhao (ALIATA | ALIVAR) em um formato 'tidy'
data_tidy <- data_wrangling(data)

# Criação de tabelas a partir dos dados arrumados
tabelas <- create_table(data_tidy)

# Processamento das tabelas...
tab_proc = processar_tabelas(tabelas$df1,tabelas$df2)

# Convertendo lista para data frames
df1 <- tab_proc[[1]]
df2 <- tab_proc[[2]]

# Combinação dos data frames "df1" e "df2" 
tabela_final =  dplyr::left_join(df1, df2, by = c("novo_cod_ext", "novo_cod_fgv"))

# # Preparar os dados mais recentes para atualizacao da serie historica
# novos_dados <- prep_dados_historica(data_tidy, df1, df2)
# 
# # Atualizando e guardando a serie historica
# atualizar_serie(novos_dados)

# Definir o nome do arquivo
nome_arquivo <- define_nome_arquivo()

# Escrever o data frame em um arquivo Excel com o nome definido
write_to_excel(tabela_final, filename = nome_arquivo)

remover_inputs(file_pattern = "ALIATA|ALIVAR|GENEROSCGM")

rm(list=ls())

cat("\014")

cat(crayon::green$bold(" \n \n \n  \n \n \n \n  \n \n \n  \n \n \n  \n \n \n Comparativo de preços gerado com sucesso!\n"))

