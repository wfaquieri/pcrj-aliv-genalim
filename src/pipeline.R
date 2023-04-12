
#' Os pipelines são sequências de nós que transformam dados em um projeto. 
#' Eles são definidos em um arquivo pipeline.R. Cada pipeline é uma sequência de 
#' nós interconectados, onde a saída de um nó é a entrada de outro. 
#' Isso permite que os dados fluam por todo o pipeline de transformação e sejam 
#' transformados em diferentes etapas do processo



data <- load_data()

data_clean <- data_wrangling(data)

tabelas <- create_table(data_clean)

df1 <- tabelas$df1 |> dplyr::mutate(praticado = calcular_preco(p_varejo, p_atacado)) 
df2 <- tabelas$df2 |> dplyr::mutate(praticado = calcular_preco(p_varejo_2, p_atacado_2)) 

tabela_final = df1 |> 
  dplyr::left_join(df2, by = c("novo_cod_ext", "novo_cod_fgv"))

tabela_final |> writexl::write_xlsx("tabela_final_03042023.xlsx")
