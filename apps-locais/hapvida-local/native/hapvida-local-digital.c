/*
 * populos-digital - 2º fator por impressão digital no Citrix UniconOS (eLux 7) da POPULOS.
 *
 * Modos com login do AD (2º fator):
 *   populos-digital portao    <usuario>  login: confere a digital do usuário do AD; sem cadastro, cadastra (1º acesso)
 *   populos-digital cadastrar <usuario>  troca a digital: confere a atual (se houver) e cadastra de novo
 * Modos sem AD (a digital é a única entrada; ligado pelo arquivo /setup/populos-digital/MODO_LOCAL):
 *   populos-digital entrada               identifica quem é entre todas as digitais e libera; sem nenhuma, cadastra a 1ª
 *   populos-digital cadastrar-local       confirma a digital de alguém já cadastrado e cadastra outra pessoa (nome + dedo)
 * Modo sala de provas (OU Provas; as digitais vêm do site de provas, cadastradas lá):
 *   populos-digital prova <pasta>         identifica o aluno entre as digitais <id>.fpr da pasta e escreve
 *                                         "IDENTIFICADO:<id>" na saída; não cadastra ninguém (saída 4 = pasta vazia)
 *
 * Leitor: qualquer um suportado pela libfprint 1.94 (testado para HID DigitalPersona U.are.U 4500, driver uru4000).
 * Digitais: /setup/populos-digital/<usuario>.fpr (dono elux, 0600; criado por tmpfiles.d).
 * Desativar o portão sem reinstalar: criar /setup/populos-digital/DESATIVADO (ex.: arquivo entregue pelo Scout).
 * Saída: 0 = liberado; 1 = sessão deve ser encerrada; 2 = erro de uso; 3 = desligar o equipamento (modos entrada e prova);
 *        4 = nenhuma digital na pasta (modo prova); 5 = reiniciar o equipamento (modos entrada e prova).
 */
#include <gtk/gtk.h>
#include <fprint.h>
#include <glib/gstdio.h>
#include <string.h>
#include <ctype.h>

#define PASTA "/setup/hapvida-local"
#define MAX_TENTATIVAS 5

typedef enum { MODO_PORTAO, MODO_CADASTRAR, MODO_ENTRADA, MODO_CADASTRAR_LOCAL, MODO_PACIENTE } Modo;
typedef enum { ETAPA_ABRINDO, ETAPA_CONFERINDO, ETAPA_IDENTIFICANDO, ETAPA_NOME, ETAPA_CADASTRANDO, ETAPA_FIM } Etapa;

typedef struct {
    Modo modo;
    Etapa etapa;
    char *usuario;
    char *arquivo;
    FpContext *ctx;
    FpDevice *dev;
    FpPrint *salva;
    GPtrArray *galeria;          /* modos sem AD: todas as digitais cadastradas */
    const char *pasta_galeria;   /* de onde a galeria é carregada (PASTA, ou a pasta do modo prova) */
    GCancellable *cancel;
    int tentativas;
    int resultado;
    GtkWidget *janela, *titulo, *texto, *barra, *botao_sair, *botao_reiniciar, *nome, *botao_nome;
} App;

static gboolean modo_local(const App *a) { return a->modo == MODO_ENTRADA || a->modo == MODO_CADASTRAR_LOCAL || a->modo == MODO_PACIENTE; }
static gboolean tela_cheia(const App *a) { return a->modo == MODO_PORTAO || a->modo == MODO_ENTRADA; }

static void iniciar(App *a);
static void conferir(App *a);
static void cadastrar(App *a);
static void identificar(App *a);
static void pedir_nome(App *a);
/* para os timers (g_timeout_add precisa de função que devolva gboolean) */
static gboolean iniciar_cb(gpointer p) { iniciar(p); return G_SOURCE_REMOVE; }
static gboolean conferir_cb(gpointer p) { conferir(p); return G_SOURCE_REMOVE; }
static gboolean cadastrar_cb(gpointer p) { cadastrar(p); return G_SOURCE_REMOVE; }
static gboolean identificar_cb(gpointer p) { identificar(p); return G_SOURCE_REMOVE; }

static void mensagem(App *a, const char *titulo, const char *texto)
{
    if (titulo) gtk_label_set_markup(GTK_LABEL(a->titulo), titulo);
    if (texto) gtk_label_set_text(GTK_LABEL(a->texto), texto);
}

static void encerrar(App *a, int resultado)
{
    if (a->etapa == ETAPA_FIM) return;
    a->resultado = resultado;
    a->etapa = ETAPA_FIM;
    g_cancellable_cancel(a->cancel);
    if (a->dev && fp_device_is_open(a->dev))
        fp_device_close_sync(a->dev, NULL, NULL);
    gtk_main_quit();
}

static gboolean encerrar_depois(gpointer p)
{
    App *a = p;
    encerrar(a, a->resultado);
    return G_SOURCE_REMOVE;
}

static void liberar(App *a, const char *texto)
{
    char *t = g_strdup_printf("<span size='xx-large' weight='bold' foreground='#2e7d32'>%s</span>", "Digital confirmada");
    mensagem(a, t, texto);
    g_free(t);
    gtk_widget_hide(a->barra);
    a->resultado = 0;
    g_timeout_add(1200, encerrar_depois, a);
}

/* nome do arquivo seguro a partir do usuário (ex.: POPULOS\Wagner.Poncell -> wagner.poncell) */
static char *arquivo_do_usuario(const char *usuario)
{
    const char *u = strrchr(usuario, '\\');
    u = u ? u + 1 : usuario;
    GString *s = g_string_new(NULL);
    for (; *u && *u != '@'; u++) {
        char c = (char) tolower((unsigned char) *u);
        if (isalnum((unsigned char) c) || c == '.' || c == '-' || c == '_') g_string_append_c(s, c);
    }
    if (s->len == 0) g_string_append(s, "desconhecido");
    char *r = g_strdup_printf("%s/%s.fpr", PASTA, s->str);
    g_string_free(s, TRUE);
    return r;
}

static FpPrint *carregar(App *a)
{
    gchar *dados = NULL; gsize tam = 0;
    if (!g_file_get_contents(a->arquivo, &dados, &tam, NULL)) return NULL;
    GError *e = NULL;
    FpPrint *p = fp_print_deserialize((guchar *) dados, tam, &e);
    g_free(dados);
    if (!p) { g_printerr("digital inválida em %s: %s\n", a->arquivo, e ? e->message : "?"); g_clear_error(&e); }
    return p;
}

/* modos sem AD: carrega todas as digitais da pasta (o nome da pessoa vai dentro da digital) */
static GPtrArray *carregar_galeria(const char *pasta)
{
    GPtrArray *g = g_ptr_array_new_with_free_func(g_object_unref);
    GDir *d = g_dir_open(pasta, 0, NULL);
    if (!d) return g;
    const char *n;
    while ((n = g_dir_read_name(d))) {
        if (!g_str_has_suffix(n, ".fpr")) continue;
        char *caminho = g_build_filename(pasta, n, NULL);
        gchar *dados = NULL; gsize tam = 0;
        if (g_file_get_contents(caminho, &dados, &tam, NULL)) {
            FpPrint *p = fp_print_deserialize((guchar *) dados, tam, NULL);
            if (p) {
                if (!fp_print_get_username(p)) {      /* digital antiga sem nome: usa o nome do arquivo */
                    char *u = g_strndup(n, strlen(n) - 4);
                    fp_print_set_username(p, u);
                    g_free(u);
                }
                g_ptr_array_add(g, p);
            }
            g_free(dados);
        }
        g_free(caminho);
    }
    g_dir_close(d);
    return g;
}

static gboolean salvar(App *a, FpPrint *p, GError **e)
{
    guchar *dados = NULL; gsize tam = 0;
    if (!fp_print_serialize(p, &dados, &tam, e)) return FALSE;
    char *tmp = g_strdup_printf("%s.novo", a->arquivo);
    gboolean ok = g_file_set_contents(tmp, (const gchar *) dados, tam, e);
    if (ok) { g_chmod(tmp, 0600); ok = g_rename(tmp, a->arquivo) == 0; }
    g_free(tmp); g_free(dados);
    return ok;
}

/* ---------- cadastro ---------- */
static void progresso_cadastro(FpDevice *dev, gint feitas, FpPrint *p, gpointer ud, GError *erro)
{
    App *a = ud;
    gint total = fp_device_get_nr_enroll_stages(dev);
    char *t;
    if (erro) t = g_strdup_printf("Leitura não aproveitada (%s). Coloque o dedo de novo.", erro->message);
    else t = g_strdup_printf("Leitura %d de %d. Levante e coloque o MESMO dedo de novo.", feitas, total);
    mensagem(a, NULL, t);
    g_free(t);
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(a->barra), total > 0 ? (double) feitas / total : 0);
}

static void fim_cadastro(GObject *o, GAsyncResult *r, gpointer ud)
{
    App *a = ud;
    if (a->etapa == ETAPA_FIM) return;
    GError *e = NULL;
    FpPrint *p = fp_device_enroll_finish(FP_DEVICE(o), r, &e);
    if (!p) {
        char *t = g_strdup_printf("Não foi possível cadastrar (%s). Vamos tentar de novo.", e ? e->message : "?");
        mensagem(a, NULL, t); g_free(t); g_clear_error(&e);
        g_timeout_add_seconds(2, cadastrar_cb, a);
        return;
    }
    if (!salvar(a, p, &e)) {
        char *t = g_strdup_printf("Digital lida, mas não foi possível gravar em %s (%s).", PASTA, e ? e->message : "?");
        mensagem(a, "<span size='xx-large' weight='bold' foreground='#c62828'>Erro ao gravar</span>", t);
        g_free(t); g_clear_error(&e); g_object_unref(p);
        return;
    }
    g_object_unref(p);
    if (a->modo == MODO_CADASTRAR_LOCAL) {
        char *t = g_strdup_printf("Digital de %s cadastrada.", a->usuario);
        liberar(a, t); g_free(t);
    } else if (a->modo == MODO_ENTRADA) {
        char *t = g_strdup_printf("Bem-vindo(a), %s! Sua digital passa a abrir este equipamento.", a->usuario);
        liberar(a, t); g_free(t);
    } else {
        liberar(a, "Digital cadastrada. Nas próximas entradas ela será pedida depois do login.");
    }
}

static void cadastrar(App *a)
{
    if (a->etapa == ETAPA_FIM) return;
    a->etapa = ETAPA_CADASTRANDO;
    char *t = g_strdup_printf("<span size='xx-large' weight='bold'>Cadastro de digital</span>\n<span size='large'>%s</span>", a->usuario);
    mensagem(a, t, "Coloque o dedo no leitor. Serão várias leituras do mesmo dedo.");
    g_free(t);
    gtk_widget_show(a->barra);
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(a->barra), 0);
    FpPrint *modelo = fp_print_new(a->dev);
    fp_print_set_username(modelo, a->usuario);
    fp_print_set_finger(modelo, FP_FINGER_RIGHT_INDEX);
    fp_device_enroll(a->dev, modelo, a->cancel, progresso_cadastro, a, NULL, fim_cadastro, a);
}

/* ---------- conferência ---------- */
static void fim_conferencia(GObject *o, GAsyncResult *r, gpointer ud)
{
    App *a = ud;
    if (a->etapa == ETAPA_FIM) return;
    GError *e = NULL; gboolean bateu = FALSE;
    fp_device_verify_finish(FP_DEVICE(o), r, &bateu, NULL, &e);
    if (e) {
        char *t = g_strdup_printf("Leitura falhou (%s). Coloque o dedo de novo.", e->message);
        mensagem(a, NULL, t); g_free(t); g_clear_error(&e);
        g_timeout_add_seconds(1, conferir_cb, a);
        return;
    }
    if (bateu) {
        if (a->modo == MODO_CADASTRAR) { cadastrar(a); return; }
        liberar(a, "Bem-vindo(a)!");
        return;
    }
    a->tentativas++;
    char *t = g_strdup_printf("Digital não reconhecida (%d de %d). Tente de novo com o dedo cadastrado.", a->tentativas, MAX_TENTATIVAS);
    mensagem(a, NULL, t); g_free(t);
    if (a->tentativas >= MAX_TENTATIVAS) {
        mensagem(a, "<span size='xx-large' weight='bold' foreground='#c62828'>Digital não reconhecida</span>",
                 "Limite de tentativas atingido. A sessão será encerrada.");
        a->resultado = 1;
        g_timeout_add_seconds(3, encerrar_depois, a);
        return;
    }
    g_timeout_add_seconds(1, conferir_cb, a);
}

static void conferir(App *a)
{
    if (a->etapa == ETAPA_FIM) return;
    a->etapa = ETAPA_CONFERINDO;
    char *t = g_strdup_printf("<span size='xx-large' weight='bold'>%s</span>\n<span size='large'>%s</span>",
                              a->modo == MODO_CADASTRAR ? "Confirme a digital atual" : "Confirme sua digital", a->usuario);
    mensagem(a, t, "Coloque o dedo cadastrado no leitor.");
    g_free(t);
    gtk_widget_hide(a->barra);
    fp_device_verify(a->dev, a->salva, a->cancel, NULL, NULL, NULL, fim_conferencia, a);
}

/* ---------- identificação (modos sem AD) ---------- */
static void fim_identificacao(GObject *o, GAsyncResult *r, gpointer ud)
{
    App *a = ud;
    if (a->etapa == ETAPA_FIM) return;
    GError *e = NULL; FpPrint *achou = NULL;
    fp_device_identify_finish(FP_DEVICE(o), r, &achou, NULL, &e);
    if (e) {
        char *t = g_strdup_printf("Leitura falhou (%s). Coloque o dedo de novo.", e->message);
        mensagem(a, NULL, t); g_free(t); g_clear_error(&e);
        g_timeout_add_seconds(1, identificar_cb, a);
        return;
    }
    if (achou) {
        const char *quem = fp_print_get_username(achou);
        if (a->modo == MODO_PACIENTE) {
            /* o script da sala de provas lê esta linha e abre a prova do aluno */
            g_print("IDENTIFICADO:%s\n", quem ? quem : "");
            const char *nome = fp_print_get_description(achou);
            char *t = g_strdup_printf("Olá, %s! Abrindo seus exames e prontuário...", nome && *nome ? nome : (quem ? quem : ""));
            liberar(a, t); g_free(t);
            return;
        }
        if (a->modo == MODO_CADASTRAR_LOCAL) {
            char *t = g_strdup_printf("Autorizado por %s. Agora informe o nome da pessoa que será cadastrada.", quem ? quem : "?");
            mensagem(a, NULL, t); g_free(t);
            pedir_nome(a);
        } else {
            char *t = g_strdup_printf("Bem-vindo(a), %s!", quem ? quem : "");
            liberar(a, t); g_free(t);
        }
        return;
    }
    a->tentativas++;
    char *t = g_strdup_printf("Digital não reconhecida (%d). Tente de novo com um dedo cadastrado.", a->tentativas);
    mensagem(a, NULL, t); g_free(t);
    /* sem limite de tentativas (não há para onde voltar sem AD); pausa de 10 s a cada 5 erros */
    g_timeout_add_seconds(a->tentativas % MAX_TENTATIVAS == 0 ? 10 : 1, identificar_cb, a);
}

static void identificar(App *a)
{
    if (a->etapa == ETAPA_FIM) return;
    a->etapa = ETAPA_IDENTIFICANDO;
    mensagem(a, a->modo == MODO_PACIENTE
                 ? "<span size='xx-large' weight='bold'>Coloque o dedo no leitor</span>\n<span size='large'>HAPVIDA: exames e prontuário</span>"
             : a->modo == MODO_ENTRADA
                 ? "<span size='xx-large' weight='bold'>Coloque o dedo no leitor</span>\n<span size='large'>Entrada por impressão digital</span>"
                 : "<span size='xx-large' weight='bold'>Autorização</span>\n<span size='large'>Uma pessoa já cadastrada precisa confirmar a digital</span>",
             a->tentativas ? NULL : "Aguardando a digital...");
    gtk_widget_hide(a->barra);
    fp_device_identify(a->dev, a->galeria, a->cancel, NULL, NULL, NULL, fim_identificacao, a);
}

static void confirmou_nome(GtkWidget *w, gpointer ud)
{
    App *a = ud;
    (void) w;
    const char *n = gtk_entry_get_text(GTK_ENTRY(a->nome));
    char *limpo = g_strstrip(g_strdup(n ? n : ""));
    if (!*limpo && a->modo == MODO_ENTRADA) {
        /* na tela de entrada (sem gerenciador de janelas) o teclado pode não chegar ao campo: usa um nome padrão */
        g_free(limpo); limpo = g_strdup("Administrador");
    }
    if (!*limpo) { g_free(limpo); mensagem(a, NULL, "Digite o nome da pessoa."); return; }
    a->usuario = limpo;
    g_free(a->arquivo);
    a->arquivo = arquivo_do_usuario(limpo);
    gtk_widget_hide(a->nome); gtk_widget_hide(a->botao_nome);
    cadastrar(a);
}

static void pedir_nome(App *a)
{
    a->etapa = ETAPA_NOME;
    mensagem(a, "<span size='xx-large' weight='bold'>Cadastro de digital</span>",
             a->galeria->len == 0 ? "Nenhuma digital cadastrada neste equipamento. Digite o nome da primeira pessoa e clique em Continuar."
                                  : "Digite o nome da pessoa e clique em Continuar.");
    gtk_widget_show(a->nome); gtk_widget_show(a->botao_nome);
    gtk_widget_grab_focus(a->nome);
}

/* ---------- leitor ---------- */
static void leitor_aberto(GObject *o, GAsyncResult *r, gpointer ud)
{
    App *a = ud;
    if (a->etapa == ETAPA_FIM) return;
    GError *e = NULL;
    if (!fp_device_open_finish(FP_DEVICE(o), r, &e)) {
        char *t = g_strdup_printf("Não foi possível abrir o leitor (%s). Tentando de novo...", e ? e->message : "?");
        mensagem(a, NULL, t); g_free(t); g_clear_error(&e);
        g_clear_object(&a->dev);
        g_timeout_add_seconds(3, iniciar_cb, a);
        return;
    }
    if (modo_local(a)) {
        if (a->galeria->len == 0 && a->modo == MODO_PACIENTE) {
            /* sala de provas: quem cadastra é o site; sem nenhum aluno pendente, avisa e devolve 4 (o script tenta de novo) */
            mensagem(a, "<span size='xx-large' weight='bold'>Nenhum paciente com digital</span>",
                     "Cadastre o paciente e sua digital na recepção para continuar.");
            a->resultado = 4;
            g_timeout_add_seconds(15, encerrar_depois, a);
            return;
        }
        if (a->galeria->len == 0) pedir_nome(a); else identificar(a);
        return;
    }
    if (a->salva) conferir(a); else cadastrar(a);
}

/* Notebooks com sensor embutido (ex.: Goodix 27c6:639c) mostram mais de um leitor: prefere o U.are.U USB
 * (driver uru4000), em que as digitais foram cadastradas. Outro driver: variável POPULOS_LEITOR (ex.: goodixmoc). */
static FpDevice *escolher_leitor(GPtrArray *devs)
{
    const char *quero = g_getenv("POPULOS_LEITOR");
    if (!quero || !*quero) quero = "uru4000";
    for (guint i = 0; i < devs->len; i++) {
        FpDevice *d = g_ptr_array_index(devs, i);
        if (!g_strcmp0(fp_device_get_driver(d), quero)) return d;
    }
    return g_ptr_array_index(devs, 0);
}

static gboolean procurar_leitor(gpointer p)
{
    App *a = p;
    if (a->etapa == ETAPA_FIM) return G_SOURCE_REMOVE;
    GPtrArray *devs = fp_context_get_devices(a->ctx);
    if (!devs || devs->len == 0) {
        mensagem(a, "<span size='xx-large' weight='bold'>Leitor de digital não encontrado</span>",
                 "Conecte o leitor USB. Procurando de novo...");
        return G_SOURCE_CONTINUE;
    }
    a->dev = g_object_ref(escolher_leitor(devs));
    g_print("leitor: %s (driver %s, %u encontrado(s))\n", fp_device_get_name(a->dev), fp_device_get_driver(a->dev), devs->len);
    mensagem(a, NULL, "Abrindo o leitor...");
    fp_device_open(a->dev, a->cancel, leitor_aberto, a);
    return G_SOURCE_REMOVE;
}

static void iniciar(App *a)
{
    a->etapa = ETAPA_ABRINDO;
    if (procurar_leitor(a) == G_SOURCE_CONTINUE)
        g_timeout_add_seconds(2, procurar_leitor, a);
}

static void clicou_sair(GtkButton *b, gpointer ud)
{
    App *a = ud;
    (void) b;
    encerrar(a, a->modo == MODO_PORTAO ? 1 : (a->modo == MODO_ENTRADA) ? 3 : 0);
}

static void clicou_reiniciar(GtkButton *b, gpointer ud)
{
    (void) b;
    encerrar(ud, 5);
}

static gboolean fechou_janela(GtkWidget *w, GdkEvent *ev, gpointer ud)
{
    (void) w; (void) ev;
    encerrar(ud, 0);
    return TRUE;
}

static GtkWidget *montar_janela(App *a)
{
    /* No login ainda não há gerenciador de janelas: janela "popup" ocupando a tela toda, acima da tela de carregamento */
    GtkWidget *w = gtk_window_new(tela_cheia(a) ? GTK_WINDOW_POPUP : GTK_WINDOW_TOPLEVEL);
    GdkRectangle g = { 0, 0, 1280, 800 };
    GdkMonitor *m = gdk_display_get_primary_monitor(gdk_display_get_default());
    if (!m) m = gdk_display_get_monitor(gdk_display_get_default(), 0);
    if (m) gdk_monitor_get_geometry(m, &g);
    if (tela_cheia(a)) { gtk_window_move(GTK_WINDOW(w), g.x, g.y); gtk_window_set_default_size(GTK_WINDOW(w), g.width, g.height); }
    else { gtk_window_set_title(GTK_WINDOW(w), "HAPVIDA Local · Exames e Prontuário"); gtk_window_set_default_size(GTK_WINDOW(w), 700, 650); gtk_window_set_position(GTK_WINDOW(w), GTK_WIN_POS_CENTER); }
    gtk_window_set_keep_above(GTK_WINDOW(w), FALSE);

    /* personalização por OU (arquivos entregues pelo Scout): PASTA/cor-fundo (ex.: #0099ff) e PASTA/logo.png */
    char *fundo = NULL;
    if (g_file_get_contents(PASTA "/cor-fundo", &fundo, NULL, NULL)) {
        g_strstrip(fundo);
        if (!g_regex_match_simple("^#[0-9a-fA-F]{6}$", fundo, 0, 0)) g_clear_pointer(&fundo, g_free);
    }
    char *estilo = g_strdup_printf(
        "window { background: %s; } label { color: #17344d; } "
        "progressbar trough { min-height: 14px; } progressbar progress { min-height: 14px; background: %s; } "
        "button { padding: 10px 24px; } button label { color: #0f1729; } "
        ".cartao { background: #ffffff; border-radius: 24px; padding: 24px 40px; } "
        "image { color: #ffffff; -gtk-icon-style: symbolic; }",
        fundo ? fundo : "#FFF7EC", "#F48B18");
    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(css, estilo, -1, NULL);
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(), GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_free(estilo); g_free(fundo);

    GtkWidget *caixa = gtk_box_new(GTK_ORIENTATION_VERTICAL, 24);
    gtk_widget_set_halign(caixa, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(caixa, GTK_ALIGN_CENTER);
    GdkPixbuf *logo = gdk_pixbuf_new_from_file_at_scale(PASTA "/logo.png", 200, 200, TRUE, NULL);
    if (logo) {
        /* logo num cartão branco, para não sumir quando a cor da marca é igual à do fundo */
        GtkWidget *cartao = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
        gtk_style_context_add_class(gtk_widget_get_style_context(cartao), "cartao");
        gtk_widget_set_halign(cartao, GTK_ALIGN_CENTER);
        gtk_box_pack_start(GTK_BOX(cartao), gtk_image_new_from_pixbuf(logo), FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(caixa), cartao, FALSE, FALSE, 0);
        g_object_unref(logo);
    }
    /* ícone de digital só se o tema de ícones tiver um (senão o GTK mostra "imagem quebrada") */
    GtkWidget *icone = NULL;
    const char *nomes_icone[] = { "fingerprint-gui", "auth-fingerprint-symbolic", "fingerprint", NULL };
    for (int i = 0; nomes_icone[i] && !icone; i++)
        if (gtk_icon_theme_has_icon(gtk_icon_theme_get_default(), nomes_icone[i])) {
            icone = gtk_image_new_from_icon_name(nomes_icone[i], GTK_ICON_SIZE_DIALOG);
            gtk_image_set_pixel_size(GTK_IMAGE(icone), 96);
        }
    a->titulo = gtk_label_new(NULL);
    gtk_label_set_justify(GTK_LABEL(a->titulo), GTK_JUSTIFY_CENTER);
    a->texto = gtk_label_new("Procurando o leitor...");
    gtk_label_set_line_wrap(GTK_LABEL(a->texto), TRUE);
    gtk_label_set_justify(GTK_LABEL(a->texto), GTK_JUSTIFY_CENTER);
    a->barra = gtk_progress_bar_new();
    gtk_widget_set_size_request(a->barra, 420, -1);
    a->botao_sair = gtk_button_new_with_label(a->modo == MODO_PORTAO ? "Encerrar sessão" : (a->modo == MODO_ENTRADA) ? "Desligar" : "Fechar");
    g_signal_connect(a->botao_sair, "clicked", G_CALLBACK(clicou_sair), a);
    /* nas telas sem login (entrada e sala de provas) também dá para reiniciar o equipamento */
    GtkWidget *botoes = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 16);
    gtk_widget_set_halign(botoes, GTK_ALIGN_CENTER);
    if (a->modo == MODO_ENTRADA) {
        a->botao_reiniciar = gtk_button_new_with_label("Reiniciar");
        g_signal_connect(a->botao_reiniciar, "clicked", G_CALLBACK(clicou_reiniciar), a);
        gtk_box_pack_start(GTK_BOX(botoes), a->botao_reiniciar, FALSE, FALSE, 0);
    }
    gtk_box_pack_start(GTK_BOX(botoes), a->botao_sair, FALSE, FALSE, 0);
    a->nome = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(a->nome), "Nome da pessoa (ex.: Maria Souza)");
    gtk_entry_set_max_length(GTK_ENTRY(a->nome), 60);
    gtk_widget_set_size_request(a->nome, 420, -1);
    g_signal_connect(a->nome, "activate", G_CALLBACK(confirmou_nome), a);
    a->botao_nome = gtk_button_new_with_label("Continuar");
    gtk_widget_set_halign(a->botao_nome, GTK_ALIGN_CENTER);
    g_signal_connect(a->botao_nome, "clicked", G_CALLBACK(confirmou_nome), a);
    if (icone) gtk_box_pack_start(GTK_BOX(caixa), icone, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(caixa), a->titulo, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(caixa), a->texto, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(caixa), a->nome, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(caixa), a->botao_nome, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(caixa), a->barra, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(caixa), botoes, FALSE, FALSE, 12);
    gtk_container_add(GTK_CONTAINER(w), caixa);
    if (!tela_cheia(a)) g_signal_connect(w, "delete-event", G_CALLBACK(fechou_janela), a);
    return w;
}

int main(int argc, char **argv)
{
    if (argc >= 3 && !strcmp(argv[1], "aviso")) {
        gtk_init(&argc, &argv);
        GtkWidget *d = gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_CLOSE, "%s", argv[2]);
        gtk_window_set_title(GTK_WINDOW(d), "HAPVIDA Local · Exames e Prontuário");
        gtk_dialog_run(GTK_DIALOG(d)); gtk_widget_destroy(d); return 0;
    }
    App a = { 0 };
    if (argc >= 3 && !strcmp(argv[1], "portao")) a.modo = MODO_PORTAO;
    else if (argc >= 3 && !strcmp(argv[1], "cadastrar")) a.modo = MODO_CADASTRAR;
    else if (argc >= 2 && !strcmp(argv[1], "entrada")) a.modo = MODO_ENTRADA;
    else if (argc >= 2 && !strcmp(argv[1], "cadastrar-local")) a.modo = MODO_CADASTRAR_LOCAL;
    else if (argc >= 3 && !strcmp(argv[1], "paciente")) a.modo = MODO_PACIENTE;
    else {
        g_printerr("uso: %s portao|cadastrar <usuario>\n       %s entrada|cadastrar-local\n       %s prova <pasta>\n", argv[0], argv[0], argv[0]);
        return 2;
    }
    a.usuario = argc >= 3 && a.modo != MODO_PACIENTE ? argv[2] : "";
    a.pasta_galeria = a.modo == MODO_PACIENTE ? argv[2] : PASTA;
    a.resultado = 1;
    a.cancel = g_cancellable_new();

    if (tela_cheia(&a) && g_file_test(PASTA "/DESATIVADO", G_FILE_TEST_EXISTS)) {
        g_print("portão desativado (%s/DESATIVADO)\n", PASTA);
        return 0;
    }
    gtk_init(&argc, &argv);
    if (modo_local(&a)) {
        a.galeria = carregar_galeria(a.pasta_galeria);
        g_print("digitais cadastradas: %u\n", a.galeria->len);
    } else {
        a.arquivo = arquivo_do_usuario(a.usuario);
        a.salva = carregar(&a);
    }
    a.ctx = fp_context_new();
    a.janela = montar_janela(&a);
    gtk_widget_show_all(a.janela);
    gtk_widget_hide(a.barra);
    gtk_widget_hide(a.nome);
    gtk_widget_hide(a.botao_nome);
    if (tela_cheia(&a)) {
        /* segura teclado e mouse para a janela do portão (não há gerenciador de janelas ainda) */
        GdkSeat *seat = gdk_display_get_default_seat(gdk_display_get_default());
        gdk_seat_grab(seat, gtk_widget_get_window(a.janela), GDK_SEAT_CAPABILITY_ALL, TRUE, NULL, NULL, NULL, NULL);
    }
    iniciar(&a);
    gtk_main();
    g_print("resultado: %d (%s)\n", a.resultado, a.arquivo ? a.arquivo : a.usuario);
    return a.resultado;
}
