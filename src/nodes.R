
#'  Os nodes são as unidades básicas de transformação de dados em um projeto. Eles
#'  representam uma única transformação de dados, como leitura de dados brutos,
#'  pré-processamento, limpeza, treinamento de modelo, avaliação de modelo etc.
#'  Cada nó é implementado como uma função e é armazenado em um arquivo separado.
#'  Isso permite que cada nó seja testado individualmente e reutilizado em
#'  diferentes pipelines.




# Leitura do Planilhao...
load_data <- function() {
  # define o padrão de nome de arquivo a ser procurado
  file_pattern <- "ALIATA|ALIVAR"
  
  # lista os arquivos no diretório "data" que possuem os nomes "ALIATA" ou "ALIVAR"
  data_dir <- list.files(path = "input",
                         pattern = file_pattern,
                         full.names = TRUE)
  
  if (length(data_dir) == 0) {
    cat("\014")
    stop(
      "\n \nNão foi possível encontrar arquivos com o padrão '",
      file_pattern,
      "' no diretório especificado. Verifique se a pasta de input está aualizada."
    )
  }
  
  # Número da coluna "Dt.Ref."
  coluna_data <- 12
  
  # Definindo os tipos de dados para cada coluna
  tipos <-
    c(rep("text", coluna_data - 1),
      "date",
      rep("text", ncol(readxl::read_excel(data_dir[1])) - coluna_data))
  
  cat(crayon::green$bold(" \n Lendo arquivos...\n"))
  
  
  # utiliza a função map do pacote purrr para ler e selecionar colunas em cada arquivo
  data <- data_dir |>
    purrr::map_df(
      ~ readxl::read_excel(.x, skip = 7, col_types = tipos) |>
        dplyr::select(1:20) |>
        dplyr::mutate(
          file_name = stringr::str_remove(tools::file_path_sans_ext(basename(.x)), "^.*/")
        )
    )
  
  cat(crayon::green$bold(" \n Carregando os dados do planilhao... Ok!\n"))
  
  
  
  # retorna data frame com os dados
  return(data)
}




# -------------------------------------------------------------------------

# Arrumar os dados do planilhao (ALIATA | ALIVAR) em um formato 'tidy'
data_wrangling <- function(data) {
  data <- data |>
    
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
    dplyr::mutate(variacao = (preco_atu / preco_atu) - 1) |>
    
    # Arrumar a dt de referencia
    dplyr::mutate()
  
  cat(crayon::green$bold(" \n Arrumando os dados do planlhão... Ok!\n"))
  
  return(data)
  
}




# -------------------------------------------------------------------------

# Criando a tabela com o comparativo de precos
create_table <- function(data) {
  # Criando uma tabela com os preços de atacado
  precos_aliata_df = data |>
    dplyr::filter(stringr::str_detect(file_name, "ALIATA")) |>
    dplyr::select(elementar, cod_ext, preco_atu, preco_ant) |>
    dplyr::rename(cod_fgv = elementar,
                  p_atacado = preco_atu,
                  p_atacado_old = preco_ant)
  
  # Criando uma tabela com os preços de varejo
  precos_alivar_df = data |>
    dplyr::filter(stringr::str_detect(file_name, "ALIVAR")) |>
    dplyr::select(elementar, cod_ext, preco_atu, preco_ant) |>
    dplyr::rename(cod_fgv = elementar,
                  p_varejo = preco_atu,
                  p_varejo_old = preco_ant)
  
  # Importando uma tabela auxiliar com o de-Para entre os codigos existentes e
  # os novos codigos criados
  itens_codigos <-
    readxl::read_excel("conf/base/auxiliary_files/item_codes.xlsx",
                       col_types = "text") |>
    janitor::clean_names() |>
    dplyr::mutate(especificacao_cliente = stringr::str_to_upper(especificacao_cliente))
  
  # Criando uma tabela com o codigo fgv e o codigo externo (metodologia 1)
  metodologia_1 = data |>
    dplyr::select(cod_ext, elementar) |>
    dplyr::rename(cod_fgv = elementar) |>
    dplyr::filter(!startsWith(cod_ext, "90")) |>
    dplyr::distinct()
  
  # Criando uma tabela com o codigo fgv e o codigo externo: 27 itens
  metodologia_2 = data |>
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
      p_varejo = ifelse(is.na(p_varejo), 0, p_varejo),
      p_atacado = ifelse(is.na(p_atacado), 0, p_atacado)
    ) |>
    dplyr::relocate(p_varejo, .before = p_atacado)
  
  df2 = metodologia_2 |>
    dplyr::left_join(itens_codigos, by = c("cod_fgv", "cod_ext")) |>
    dplyr::left_join(precos_aliata_df, by = c("cod_fgv", "cod_ext")) |>
    dplyr::left_join(precos_alivar_df, by = c("cod_fgv", "cod_ext")) |>
    dplyr::mutate(
      novo_cod_ext = cod_ext,
      novo_cod_fgv = cod_fgv,
      p_varejo = ifelse(is.na(p_varejo), 0, p_varejo),
      p_atacado = ifelse(is.na(p_atacado), 0, p_atacado)
    ) |>
    dplyr::select(
      -cod_ext,-cod_fgv,-descricao_item_fgv,
      -especificacao_cliente,-medida,-nivel,-descricao
    )
  
  lista <- list(df1 = df1, df2 = df2)
  
  cat(crayon::green$bold(" \n Tabelas criadas com sucesso!\n"))
  
  return(lista)
  
}




# -------------------------------------------------------------------------

# Define a função de cálculo de precos (Praticado)
calcular_praticado <- function(preco_atacado, preco_varejo) {
  ifelse(
    preco_atacado == 0,
    0.9 * preco_varejo,
    ifelse(
      preco_varejo == 0,
      1.1 * preco_atacado,
      ifelse(
        preco_atacado < preco_varejo,
        preco_atacado + 0.75 * (preco_varejo - preco_atacado),
        preco_varejo
      )
    )
  )
}





# -------------------------------------------------------------------------

# Define a função de cálculo variacao (atacado, varejo, praticado)
calcular_variacao_percentual <- function(df) {
  # Calcula a variação percentual para cada coluna de cada data frame
  df$var_varejo <- (df$p_varejo - df$p_varejo_old) / df$p_varejo_old
  df$var_atacado <-
    (df$p_atacado - df$p_atacado_old) / df$p_atacado_old
  df$var_praticado <-
    (df$praticado - df$praticado_old) / df$praticado_old
  
  # Retorna um data frame com as variações percentuais de todas as colunas
  return(df)
}




# -------------------------------------------------------------------------

obter_praticado_anterior <- function() {
  GENEROS_CGM <- readr::read_delim(
    'input/GENEROSCGM.txt',
    delim = "@",
    col_names = F,
    col_types = readr::cols(.default = "c")
  )
  
  
  gen_89 = GENEROS_CGM |>
    dplyr::filter(stringr::str_detect(X1, '^89')) |>
    dplyr::mutate(X11 = stringr::str_replace(X11,',','.') |> as.numeric()) |>
    dplyr::select(X1, X11) |>
    dplyr::rename(cod_ext = X1, praticado_old = X11)
  
  # CONTEXTO: O código do item que inicia com 90 foi criado no sistema FGV e
  # precisa ser modificado para o código do sistema da PCRJ. Para tal, basta
  # alterar de 90 para 89
  
  gen_90 = GENEROS_CGM |> 
    dplyr::filter(stringr::str_detect(X1, '^90')) |>
    dplyr::mutate(X11 = stringr::str_replace(X11,',','.') |> as.numeric()) |>
    dplyr::select(X1, X11) |>
    dplyr::rename(novo_cod_ext = X1, praticado_old = X11)
  
  return(list(gen_89, gen_90))
  
}




# -------------------------------------------------------------------------

# Função para processar tabelas e calcular variações percentuais em relação à
# quinzena anterior
processar_tabelas <- function(df1, df2) {
  # Junta a tabela df1 com a série histórica sem decreto
  df1$praticado <- calcular_praticado(df1$p_atacado, df1$p_varejo)
  
  df1 <- df1 |>
    dplyr::mutate(check = p_varejo > p_atacado) |>
    dplyr::relocate(p_varejo_old, .before = p_atacado_old) |>
    dplyr::relocate(praticado, .before = p_varejo_old) |>
    dplyr::relocate(check, .before = p_varejo_old)
  
  
  # Calculo do praticado
  df2$praticado <- calcular_praticado(df2$p_varejo, df2$p_atacado)
  
  df2 <- df2 |>
    dplyr::mutate(check = p_varejo > p_atacado) |>
    dplyr::relocate(p_varejo, .before = p_atacado) |>
    dplyr::relocate(p_varejo_old, .before = p_atacado_old) |>
    dplyr::relocate(praticado, .before = p_varejo_old) |>
    dplyr::relocate(check, .before = p_varejo_old)
  
  ## FALTA INCLUIR O PRATICADO DA QUINZENA ANTERIOR PARA CALCULO DA
  ## VARIACAO PERCENTUAL
  
  praticado_old = obter_praticado_anterior()
  df1_join = df1 |> dplyr::left_join(praticado_old[[1]], by = "cod_ext")
  df2_join = df2 |> dplyr::left_join(praticado_old[[2]], by = "novo_cod_ext")
  
  # Calcula as variações percentuais em relação à quinzena anterior
  df1_var <- calcular_variacao_percentual(df1_join)
  df2_var <- calcular_variacao_percentual(df2_join)
  
  # Retorna a lista com as tabelas processadas
  return(list(df1_var, df2_var))
  
}




#' Define a função para alterar o nome do arquivo de acordo com a quinzena.
#' 1Q: PRIMEIRA QUINZENA; 2Q: SEGUNDA QUINZENA.
define_nome_arquivo <- function() {
  # Obter a data atual
  data_atual <- Sys.Date()
  
  # Obter o mês e o ano anterior
  mes_anterior <-
    toupper(substring(
      format(
        lubridate::floor_date(data_atual, unit = "month") - lubridate::days(1),
        format = "%b"
      ),
      1,
      3
    ))
  
  ano_anterior <-
    format(lubridate::floor_date(data_atual, unit = "month") - lubridate::days(1),
           format = "%Y")
  
  data_atual_sem_traco <- gsub("-", "", as.character(Sys.Date()))
  
  
  # Definir o nome do arquivo de acordo com a data atual
  if (as.numeric(format(data_atual, "%d")) < 15) {
    nome_arquivo <-
      paste0(
        "2Q",
        mes_anterior,
        ano_anterior,
        "-COMPARATIVO-",
        data_atual_sem_traco,
        ".xlsx"
      )
  } else {
    nome_arquivo <-
      paste0(
        "1Q",
        toupper(format(data_atual, "%b")),
        format(data_atual, "%Y"),
        "-COMPARATIVO-",
        data_atual_sem_traco,
        ".xlsx"
      )
  }
  
  return(nome_arquivo)
}




# Define a função para salvar os resultados no 'template.xlsx'
write_to_excel <- function(df, filename) {
  # Ler o arquivo template.xlsx
  template_file <- paste0("conf/base/templates/template.xlsx")
  
  wb <- openxlsx::loadWorkbook(template_file)
  
  # Escrever os dados do data frame na planilha, pulando a primeira linha e
  # ocultando o nome das colunas
  openxlsx::writeData(
    wb,
    df[, 1:9],
    sheet = 1,
    startCol = 1,
    startRow = 5,
    colNames = FALSE
  )
  openxlsx::writeData(
    wb,
    df[, 10:19],
    sheet = 1,
    startCol = 11,
    startRow = 5,
    colNames = FALSE
  )
  openxlsx::writeData(
    wb,
    df[, 20:29],
    sheet = 1,
    startCol = 22,
    startRow = 5,
    colNames = FALSE
  )
  
  
  # Salvar o arquivo
  openxlsx::saveWorkbook(wb, paste0("excel/", filename), overwrite = T)
}


# -------------------------------------------------------------------------

remover_inputs <- function(file_pattern){

  # lista os arquivos no diretório "input" 
  data_dir <- list.files(path = "input",
                         pattern = file_pattern,
                         full.names = TRUE)
  
  file.remove(data_dir)
  
  
}