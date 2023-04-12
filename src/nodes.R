
#'  Os nodes são as unidades básicas de transformação de dados em um projeto. Eles 
#'  representam uma única transformação de dados, como leitura de dados brutos, 
#'  pré-processamento, limpeza, treinamento de modelo, avaliação de modelo etc. 
#'  Cada nó é implementado como uma função e é armazenado em um arquivo separado. 
#'  Isso permite que cada nó seja testado individualmente e reutilizado em 
#'  diferentes pipelines.


load_data <- function() {
  
  # define o padrão de nome de arquivo a ser procurado
  file_pattern <- "ALIATA|ALIVAR"
  
  # lista os arquivos no diretório "data" que possuem os nomes "ALIATA" ou "ALIVAR"
  data_dir <- list.files(path = "data/raw",
                         pattern = file_pattern,
                         full.names = TRUE)
  
  if (length(data_dir) == 0) {
    stop("Não foi possível encontrar arquivos com o padrão '", file_pattern, "' no diretório especificado.")
  }
  
  message("Lendo arquivos...")
  
  # utiliza a função map do pacote purrr para ler e selecionar colunas em cada arquivo
  data <- data_dir |>
    purrr::map_df(
      ~ readxl::read_excel(.x, skip = 7, col_types = 'text') |>
        dplyr::select(1:20) |>
        dplyr::mutate(file_name = stringr::str_remove(tools::file_path_sans_ext(basename(.x)), "^.*/"))
    )
  
  
  message("Leitura dos arquivos de input OK!")
  
  # retorna data frame com os dados
  return(data)
}


data_wrangling <- function(data) {
  
  data_clean <- data |>
    
    # filtrar linhas que contêm palavras específicas na coluna 'Elementar'
    dplyr::filter(!stringr::str_detect(Elementar, "Referência|Insumo|Elementar")) |>
    
    # Filtrar valores nulos na coluna 7 e depois remover colunas desnecessárias
    dplyr::filter(is.na(...7)) |>
    
    # Remover colunas desnecessárias
    dplyr::select(-...3, -...7, -...8, -...14, -Busca) |> 
    
    # padronizar nomes 
    janitor::clean_names() |>
    
    # renomear as colunas
    dplyr::rename_with(~ stringr::str_replace(., "^x5$", "cod_ext"), x5) |>
    dplyr::rename_with(~ stringr::str_replace(., "^x6$", "status"), x6) |>  
    dplyr::rename(descricao = descricao_2) |> 
    
    # converter as colunas de preco para numerico
    dplyr::mutate(across(starts_with("preco"), readr::parse_number)) |>
    
    # calcular a variacao
    dplyr::mutate(variacao = (preco_atu / preco_atu) - 1)
  
  message("Data wrangling ok!")
  
  return(data_clean)
  
}


  
# Criando o arquivo comparativo de precos

create_table <- function(data_clean) {
  
  # Criando uma tabela com os preços de atacado
  precos_aliata_df = data_clean |>
    dplyr::filter(stringr::str_detect(file_name, "ALIATA")) |>
    dplyr::select(elementar, cod_ext, preco_atu) |>
    dplyr::rename(cod_fgv = elementar, p_atacado = preco_atu)
  
  # Criando uma tabela com os preços de varejo
  precos_alivar_df = data_clean |>
    dplyr::filter(stringr::str_detect(file_name, "ALIVAR")) |>
    dplyr::select(elementar, cod_ext, preco_atu) |>
    dplyr::rename(cod_fgv = elementar, p_varejo = preco_atu)
  
  # Importando uma tabela auxiliar com o de-Para entre os codigos existentes e 
  # os novos codigos criados
  itens_codigos <-
    readxl::read_excel(
      "data/auxiliary_files/item_codes.xlsx",
      col_types = "text"
    ) |>
    janitor::clean_names() |>
    dplyr::mutate(especificacao_cliente = stringr::str_to_upper(especificacao_cliente))
  
  # Criando uma tabela com o codigo fgv e o codigo externo (metodologia 1)
  metodologia_1 = data_clean |>
    dplyr::select(cod_ext, elementar) |>
    dplyr::rename(cod_fgv = elementar) |>
    dplyr::filter(!startsWith(cod_ext, "90")) |>
    dplyr::distinct()
  
  # Criando uma tabela com o codigo fgv e o codigo externo: 27 itens
  metodologia_2 = data_clean |>
    dplyr::select(cod_ext, elementar) |>
    dplyr::rename(cod_fgv = elementar) |>
    dplyr::filter(!startsWith(cod_ext, "89")) |>
    dplyr::distinct()
  
  # Criando uma tabela com os preços de varejo e atacado e os novos codigos 
  df1 = metodologia_1 |>
    dplyr::left_join(itens_codigos, by = c("cod_fgv", "cod_ext")) |>
    dplyr::left_join(precos_aliata_df, by = c("cod_fgv", "cod_ext")) |>
    dplyr::left_join(precos_alivar_df, by = c("cod_fgv", "cod_ext")) |>
    dplyr::mutate(
      p_varejo = ifelse(is.na(p_varejo),0,p_varejo),
      p_atacado = ifelse(is.na(p_atacado),0,p_atacado),
      check = p_varejo > p_atacado
      ) |> dplyr::relocate(p_varejo, .before = p_atacado)
  
  df2 = metodologia_2 |>
    dplyr::left_join(itens_codigos, by = c("cod_fgv", "cod_ext")) |>
    dplyr::left_join(precos_aliata_df, by = c("cod_fgv", "cod_ext")) |>
    dplyr::left_join(precos_alivar_df, by = c("cod_fgv", "cod_ext")) |>
    dplyr::mutate(
      novo_cod_ext = cod_ext,
      novo_cod_fgv = cod_fgv,
      p_varejo_2 = ifelse(is.na(p_varejo),0,p_varejo),
      p_atacado_2 = ifelse(is.na(p_atacado),0,p_atacado)) |> 
    dplyr::select(-p_varejo,-p_atacado,-cod_ext,-cod_fgv,-descricao_item_fgv,-especificacao_cliente)
  
  lista <- list(df1 = df1, df2 = df2)
  
  message("Tabelas criadas com sucesso!")
  
  return(lista)
  
}


# Define a função de cálculo de precos (AT,VA)
calcular_preco <- function(p_atacado, p_varejo) {
  ifelse(p_atacado == 0, 0.9 * p_varejo,
         ifelse(p_varejo == 0, 1.1 * p_atacado,
                ifelse(p_atacado < p_varejo, p_atacado + 0.75 * (p_varejo - p_atacado),
                       p_varejo)))
}


# Define o formato de exibição dos números
# fomatar_numericos <- function(tabela) {
#   
#   tabela |> 
#     dplyr::mutate(
#       p_atacado = round(p_atacado,2),
#       p_varejo = round(p_varejo,2),
#       praticado = round(praticado,2),
#       p_atacado = formatC(p_atacado, width = 2, flag = "0", decimal.mark = ","),
#       p_varejo = formatC(p_varejo, width = 2, flag = "0", decimal.mark = ","),
#       praticado = formatC(praticado, width = 2, flag = "0", decimal.mark = ",")
#     )
# 
# }

  




