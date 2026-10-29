# HAPVIDA Local — sistema autônomo por eLux

OU **HAPVIDA Local**, GroupID **14**, SetupID **10**, sem AD. Mesmo tema HAPVIDA, com os aplicativos anteriores e dois aplicativos de saúde locais:

- **Cadastro de Pacientes** (89): `/usr/bin/hapvida-local-admin`.
- **Exames e Prontuário** (88): `/usr/bin/hapvida-local-paciente`.

Ambos abrem em janelas normais. A digital é usada somente no sistema de saúde. O cadastro, a foto pela câmera, a captura da digital e a consulta do histórico funcionam no próprio eLux. Cada aparelho tem sua própria base; não há sincronização automática entre aparelhos nem com o servidor. Nenhum paciente, foto ou digital da base do servidor foi copiado.

## Implantar

1. Mover o aparelho escolhido para a OU HAPVIDA Local no Scout.
2. Executar **Deliver software** da `populos-elux7-v30.idf`, aguardar a conclusão e executar **Update software**.
3. Receber os arquivos de configuração da OU e iniciar a imagem nova.
4. Abrir Cadastro de Pacientes, cadastrar nome/nascimento/cenário, adicionar ou tirar a foto e capturar a digital no leitor USB **do próprio eLux**.
5. Abrir Exames e Prontuário e identificar o paciente com a digital.

A primeira instalação ainda utiliza Scout/ELIAS para entregar software e configuração. Depois disso, o sistema de saúde roda sem este servidor e sem rede externa. Nenhum aparelho foi movido, atualizado ou reiniciado automaticamente durante a preparação.

Usuário administrativo: `admin`. A credencial inicial é a mesma do cadastro HAPVIDA no momento da criação, guardada no rótulo **HAPVIDA Local admin** de `C:\ScoutSetup\credenciais.txt`. O eLux recebe apenas um verificador PBKDF2-SHA256, sem senha administrativa em texto no pacote. A interface continua exigindo autenticação administrativa; o desktop da OU não exige AD ou digital.

## Imagem e componentes

- Imagem **v30**, **3.657,51 MB**, sem conflitos ou faltantes no ELIAS.
- v29 + EPM `populos_hapvida_local` 1.0.0 + Python 3.10 oficial e FPM oficial `python3_flask`.
- Python/Flask já fazem parte do catálogo UniconOS; não há Docker no eLux.
- Serviço `hapvida-local.service`, usuário `elux`, habilitado no target multi-user.
- HTTP apenas em **127.0.0.1:3131**. Não publica atendimento para a rede.
- Endereço do cadastro no próprio aparelho: `http://127.0.0.1:3131/hapvida/admin`.
- A câmera usa o contexto local do navegador, sem exceção para origem HTTP remota.
- Backend e páginas em `/opt/hapvida-local`, dependências adicionais em `vendor/`, executáveis `/usr/bin/hapvida-local-*`.
- Dados persistentes: `/setup/hapvida-local/dados/hapvida.db`, `digitais/`, `fotos/`.
- `/setup/hapvida-local/admin-auth.json`: verificador administrativo entregue pelo Scout.
- `/setup/hapvida-local/.chave-local`: chave criada no primeiro início, própria de cada aparelho, modo 0600; não é a chave do servidor HAPVIDA.
- Logo e cor da identificação em `/setup/hapvida-local/logo.png` e `cor-fundo`.

O serviço espera a configuração administrativa da OU antes de atender. `systemd-tmpfiles` cria as pastas persistentes com permissão 0700 para `elux`. O launcher do paciente lê somente as digitais locais, solicita sessão na API de loopback e abre Edge em perfil temporário exclusivo. Fechar o navegador revoga a sessão local; ela também pode ser encerrada pelo botão do portal e expira em 15 minutos. O launcher administrativo usa um perfil separado para manter a permissão da câmera.

Os três exames e três registros gerados para cada paciente são inteiramente fictícios e identificados como demonstração. Outros aplicativos preservados da HAPVIDA (Citrix, Teams etc.) continuam tendo suas próprias necessidades de rede; isso não é requisito para o sistema de saúde local.

## Validação realizada

1. Python e Flask oficiais foram extraídos e testados.
2. Oito testes do backend passaram com o interpretador oficial, em container de teste com `--network none`: cadastro, autenticação e CSRF, isolamento do paciente, foto privada, token único, expiração/revogação, galeria e preservação da digital antiga quando o cadastro falha.
3. O FPM real compilado foi extraído e seu backend executado com o Python oficial, também com a rede externa desativada. Cadastro, galeria, sessão e seis documentos funcionaram em loopback.
4. O serviço de teste foi encerrado e iniciado novamente com a mesma pasta: paciente, registro biométrico fictício de teste e chave local foram preservados.
5. Permissões executáveis dos launchers/cadastro e symlink de ativação do serviço foram conferidos no payload.

Os testes foram isolados e não criaram pacientes no sistema instalado. O artefato biométrico usado nos testes de API é fictício e não comprova reconhecimento. **Faltam instalação/boot num eLux real, captura/reconhecimento do leitor e webcam física.** Não foi afirmado teste de hardware concluído.

## Manutenção e backup

Fontes e saídas em `C:\ScoutSetup\hapvida-local` e `Downloads\hapvida-local`. Build/testes/importação/criação da OU em `deploy/`. Backups Scout registrados na seção 7.13 do diário. Antes de apagar/reinstalar/reformatar um aparelho, salvar a pasta persistente local; uma alteração destrutiva pode eliminar seus únicos cadastros. Nenhuma sincronização ou backup central desses cadastros foi implementado neste escopo.

Para mudar a credencial da OU, gerar novo verificador a partir do rótulo central e atualizar seu FileEntry com backup do Scout; mudar apenas o arquivo central não altera o verificador já entregue. Não publicar verificadores, dados, fotos, digitais ou chaves junto do código. Não executar scripts de implantação novamente sem ler suas guardas contra duplicação. Nenhum envio ao GitHub foi feito.
