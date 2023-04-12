## README

Esse projeto está organizado de forma similar a estrutura utilizada pelo framework Kedro. O Kedro ajuda na estruturação de um projeto para Data Science (DS), em um formato bem próximo ao TDSP da Microsfot. E foi projetado para trabalhar com fluxos de trabalho, utilizando o conceito de nodes e pipelines.

projeto/
    data/
        raw/
        processed/
    src/
        nodes.R
        pipeline.R
    excel/
        template.xlsx
    README.md
    main.R


- .Rprofile– Um arquivo executado pelo RStudio toda vez que você carrega ou recarrega uma sessão do R. Ele chama o arquivo. renv/activate.R

-renv/.gitignore– Diz ao Git para ignorar a pasta library, pois ela contém dependências que podem ser grandes. Não há necessidade de rastreá-los, pois a versão correta pode ser facilmente baixada pela equipe de trabalho.

-renv/activate.R– Um arquivo usado para ativar um ambiente R local.

-renv/library/*– Pasta com várias subpastas – contém as dependências do projeto.
