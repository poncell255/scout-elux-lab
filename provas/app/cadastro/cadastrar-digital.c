/*
 * cadastrar-digital - cadastra uma digital pela libfprint (mesma biblioteca e formato do populos-digital no eLux).
 * Uso: cadastrar-digital <arquivo.fpr> <id> <nome>
 * Escreve o progresso em stdout, uma linha por evento, para o site acompanhar:
 *   LEITOR <nome do leitor>
 *   ETAPAS <total>
 *   LEITURA <feitas> <total>
 *   REPETIR <mensagem>
 *   OK <arquivo>
 *   ERRO <mensagem>
 * Saída: 0 = cadastrada; 1 = erro.
 */
#include <fprint.h>
#include <glib/gstdio.h>
#include <stdio.h>

static GMainLoop *laco;
static int resultado = 1;
static const char *arquivo;

static void progresso(FpDevice *dev, gint feitas, FpPrint *p, gpointer ud, GError *erro)
{
    (void) p; (void) ud;
    if (erro) printf("REPETIR %s\n", erro->message);
    else printf("LEITURA %d %d\n", feitas, fp_device_get_nr_enroll_stages(dev));
    fflush(stdout);
}

static void fim(GObject *o, GAsyncResult *r, gpointer ud)
{
    (void) ud;
    GError *e = NULL;
    FpPrint *p = fp_device_enroll_finish(FP_DEVICE(o), r, &e);
    if (!p) {
        printf("ERRO %s\n", e ? e->message : "falha no cadastro");
    } else {
        guchar *dados = NULL; gsize tam = 0;
        if (fp_print_serialize(p, &dados, &tam, &e) && g_file_set_contents(arquivo, (const gchar *) dados, tam, &e)) {
            printf("OK %s\n", arquivo);
            resultado = 0;
        } else {
            printf("ERRO %s\n", e ? e->message : "falha ao gravar");
        }
        g_free(dados);
        g_object_unref(p);
    }
    g_clear_error(&e);
    fflush(stdout);
    fp_device_close_sync(FP_DEVICE(o), NULL, NULL);
    g_main_loop_quit(laco);
}

int main(int argc, char **argv)
{
    if (argc < 4) { fprintf(stderr, "uso: %s <arquivo.fpr> <id> <nome>\n", argv[0]); return 2; }
    arquivo = argv[1];
    FpContext *ctx = fp_context_new();
    GPtrArray *devs = fp_context_get_devices(ctx);
    if (!devs || devs->len == 0) { printf("ERRO leitor de digital não encontrado\n"); return 1; }
    FpDevice *dev = g_ptr_array_index(devs, 0);
    GError *e = NULL;
    if (!fp_device_open_sync(dev, NULL, &e)) { printf("ERRO não foi possível abrir o leitor: %s\n", e->message); return 1; }
    printf("LEITOR %s\nETAPAS %d\n", fp_device_get_name(dev), fp_device_get_nr_enroll_stages(dev));
    fflush(stdout);
    /* o id vai no "username" (é o que o eLux devolve ao identificar) e o nome na descrição */
    FpPrint *modelo = fp_print_new(dev);
    fp_print_set_username(modelo, argv[2]);
    fp_print_set_description(modelo, argv[3]);
    fp_print_set_finger(modelo, FP_FINGER_RIGHT_INDEX);
    laco = g_main_loop_new(NULL, FALSE);
    fp_device_enroll(dev, modelo, NULL, progresso, NULL, NULL, fim, NULL);
    g_main_loop_run(laco);
    return resultado;
}
