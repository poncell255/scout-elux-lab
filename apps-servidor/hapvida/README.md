# HAPVIDA — Exames e Prontuário (demonstração)

Sistema local do laboratório POPULOS. Cada paciente cadastrado recebe três exames e três registros de prontuário inteiramente fictícios, com identificação, foto enviada pela recepção e acesso pela digital no UniconOS. Nenhum exame é uma medição real; laudos e impressões levam a indicação de demonstração.

## Acessar

- Início: http://10.5.0.166/hapvida/
- Cadastro: http://10.5.0.166/hapvida/admin
- Usuário: `admin`. Senha somente na linha **HAPVIDA admin** de `C:\ScoutSetup\credenciais.txt`.
- Chave dos aparelhos: linha **HAPVIDA chave dos eLux** no mesmo arquivo. Não copiar para documentação ou repositório.

Na recepção: cadastrar nome, data de nascimento e cenário, enviar foto PNG/JPEG (até 4 MB), clicar em **Capturar digital** e fazer as leituras no leitor do servidor. Se ele não aparecer, conectar o USB e executar `C:\ScoutSetup\continuar.ps1 leitor`. O leitor não estava conectado durante a implantação.

## Dois aplicativos na OU HAPVIDA

1. **Cadastro de Pacientes** (ApplicationID 80): abre `/hapvida/admin` em janela do Edge e solicita a autenticação administrativa.
2. **Exames e Prontuário** (ApplicationID 79): abre a janela nativa HAPVIDA, identifica a digital e abre somente o histórico do paciente reconhecido, em janela normal do Edge.

Ambos têm `AutoStart=0`, `TM=0`, ícone HAPVIDA. Os sete aplicativos anteriores da Populos foram preservados. Grupo 13, setup 9, login **AD populos.local**, sem biometria na entrada da OU. O arquivo `/setup/populos-digital/DESATIVADO` desliga o portão de digital nas imagens antigas que ainda tenham o componente. O novo pacote HAPVIDA não contém `login.d` e não lê esse marcador.

### Instalar nos eLux

Imagem **populos-elux7-v29.idf** pronta no ELIAS: v22 + `populos_hapvida` 1.0.0, 3.627,86 MB, sem conflitos/faltantes. No Scout, **Deliver software**, esperar o término e então **Update software**. A implantação não enviou comandos de update/reboot e não moveu dispositivos. Sem instalar a v29, o binário dedicado do aplicativo do paciente não estará disponível. Os atalhos, arquivos e marcador de desativação também precisam ser recebidos pela configuração do Scout.

O paciente precisa de um leitor USB no próprio eLux; o leitor do servidor serve para cadastro. Fechar a janela de identificação cancela a abertura. Fechar o navegador encerra a execução e revoga o acesso no servidor quando houver rede. **Encerrar acesso** revoga a sessão e mostra a tela de encerramento; o usuário pode fechar a janela. A sessão também expira após 15 minutos. Reabrir exige a digital novamente.

## Estrutura

- Código instalado: `C:\ScoutSetup\hapvida\app` (montado somente leitura no Docker).
- Código de trabalho, pacote e verificações: `C:\Users\Administrator\Downloads\hapvida-saude`.
- Container `hapvida`, imagem local já disponível `populos-provas` (ferramentas Flask/waitress/libfprint, sem usar dados ou rotas de Provas).
- Porta Docker: `127.0.0.1:3101`, publicada via diretório virtual IIS `/hapvida`. Nenhuma nova porta externa/firewall.
- Dados persistentes no WSL: `/root/hapvida/data/hapvida.db`, `digitais/`, `fotos/`. Independentes de `/root/provas/data`.
- Credenciais originadas apenas no arquivo central e fornecidas ao container por stdin/ambiente de execução. Não há `.env` ou credenciais no código.
- API do eLux: `/hapvida/api/galeria`, `/api/sessao`, `/api/sessao/<token>/encerrar`, cabeçalho `X-Hapvida-Chave`.
- Configuração dos aparelhos: `/setup/hapvida/{servidor,chave,logo.png,cor-fundo}` via UCFT/FileEntry no Scout.
- Binários no pacote: `/usr/bin/hapvida-digital`, `/usr/bin/hapvida-prontuario`, libfprint/libgusb e regra USB. Sem portão AD, reiniciar/desligar ou kiosk.

A galeria contém apenas as digitais cadastradas neste sistema. O ID interno da digital identifica o paciente; a API do aparelho pressupõe um eLux gerenciado com a chave do laboratório, como no fluxo de Provas. URLs de abertura usam token único, trocado por cookie HttpOnly. A API do portal limita dados/foto ao paciente daquela sessão. Esta implementação é um simulador local, não um sistema clínico de produção.

## Validação

Oito testes de backend passaram: autenticação/CSRF, validação de cadastro, histórico sintético, controle da galeria, isolamento entre pacientes, token de uso único, expiração/revogação, fotos privadas e preservação da digital anterior quando a captura falha. Navegador Edge headless: cadastro real carregou; portal com fixture visual em memória renderizou seis documentos, abriu laudo e filtrou exames, sem erros JavaScript. Nenhum paciente fictício foi semeado no banco instalado. Prévia GTK em Xvfb conferida com logo e botão Fechar.

**Pendente:** cadastro/reconhecimento de uma digital física e ciclo completo no eLux com v29. Ausência do leitor impede afirmar validação biométrica. Prévias visuais não comprovam a identificação.

## Manutenção

Para atualizar código, revisar os arquivos em `app`, copiar para `C:\ScoutSetup\hapvida\app` e reiniciar **somente** o container `hapvida`. Antes de mudar o SQLite com dados cadastrados, fazer backup consistente. Scripts `deploy/install-server.ps1`, `import-image.ps1` e `register-scout.ps1` são de implantação e incluem guardas contra duplicação; não executá-los novamente cegamente. Backups do Scout e IIS estão registrados na seção 7.13 do diário.

O `continuar.ps1 sync` atual ainda não inclui esta pasta; incluir HAPVIDA na próxima preparação de repositório, sem fotos, digitais, banco, credenciais ou perfis de navegador. Não houve sync/commit/push neste trabalho.

## Foto pela câmera

O cadastro permite **Tirar foto com a câmera**, ver a prévia, refazer e confirmar a imagem. Funciona no formulário novo e na troca de foto de um paciente existente. A câmera utilizada é a do equipamento que abriu o navegador. O vídeo não é enviado ao servidor; somente o JPEG confirmado é enviado pelo mesmo endpoint de fotos. Os tracks da câmera são encerrados ao confirmar, cancelar ou sair da página. O teste automatizado usou câmera sintética; não comprova uma webcam física.

No próprio servidor, `http://localhost/hapvida/admin` permite usar a câmera como contexto local seguro. Navegadores comuns acessando o IP por HTTP podem impedir getUserMedia; nesse caso, usar HTTPS ou o aplicativo administrativo configurado no eLux. O atalho **Cadastro de Pacientes** utiliza perfil separado e `--unsafely-treat-insecure-origin-as-secure=http://10.5.0.166` apenas para a origem interna do laboratório. Isso não altera políticas globais, portas ou o aplicativo do paciente; o usuário ainda deve autorizar a câmera no navegador. Fechar todas as janelas desse perfil e reabrir o atalho após receber a configuração para o argumento fazer efeito. Não ampliar essa exceção para outras origens; em uma implantação definitiva, usar HTTPS confiável.

A senha administrativa foi alterada a pedido do Wagner e aplicada no container, com teste HTTP 200 para a nova e HTTP 401 para a anterior. O valor permanece exclusivamente no arquivo central. `deploy/rotate-credentials.py` recebe a senha por stdin, mantém a chave de runtime dos aparelhos e a mesma imagem/volumes, cria backup SQLite consistente e testa a rotação. Depois da troca, recarregar a página para atualizar a sessão administrativa e o CSRF.
Atualização 28/10: o cadastro no eLux usa agora o perfil novo /home/elux/.config/microsoft-edge/app-hapvida-camera. A configuração anterior ainda não havia sido recebida no diagnóstico pelo banco; reiniciar o aparelho para receber e usar o atalho atualizado antes de testar a câmera.
