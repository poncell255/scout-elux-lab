/*
 * ler-digital - mostra os metadados de uma digital salva (driver, device id, id e nome).
 * Uso: ler-digital <arquivo.fpr>
 */
#include <fprint.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "uso: %s <arquivo.fpr>\n", argv[0]); return 2; }
    gchar *dados = NULL; gsize tam = 0; GError *e = NULL;
    if (!g_file_get_contents(argv[1], &dados, &tam, &e)) { printf("ERRO %s\n", e->message); return 1; }
    FpPrint *p = fp_print_deserialize((guchar *) dados, tam, &e);
    if (!p) { printf("ERRO %s\n", e->message); return 1; }
    printf("driver=%s device_id=%s id=%s nome=%s\n", fp_print_get_driver(p), fp_print_get_device_id(p),
           fp_print_get_username(p), fp_print_get_description(p));
    return 0;
}
