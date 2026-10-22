# Copie para parametros.ps1 (NÃO versionar) e preencha.
$Param = @{
    HostName            = '<HOSTNAME>'                 # ex.: WIN-XXXXXXX
    ServerIP            = '<IP_DO_SERVIDOR>'           # IP que os eLux alcançam
    SqlInstance         = 'localhost\SQLEXPRESS'
    SqlSaPassword       = '<SENHA_SQL_SA>'
    SqlScoutUser        = 'scoutdb'
    SqlScoutPassword    = '<SENHA_SQL_SCOUT>'
    EluxDevicePassword  = '<SENHA_DISPOSITIVO_ELUX>'
    EliasAdminPassword  = '<SENHA_ELIAS_ADMIN>'
    EliasContainer      = 'UC_RP6_X64'
    EntraTenantId       = '<TENANT_ID>'
    EntraAppId          = '<APP_ID>'
    EntraClientSecret   = '<SEGREDO_DO_APP>'
    ScoutAdmins         = @('<email1@empresa.com.br>')
    CitrixStoreUrl      = 'https://<loja>.cloud.com'
    # Login AD nos eLux (docs/GUIA-IMPLANTACAO.md, Fase 11)
    Dominio             = '<dominio.local>'
    DcFqdn              = '<DC>.<dominio.local>'
    DcIp                = '<IP_DO_DC>'
    SearchBase          = 'DC=<dominio>,DC=local'
    Ntp                 = @('a.ntp.br','b.ntp.br')
    # Imagens e parede de TVs (Fases 6 e 16)
    Imagem              = 'populos-elux7-v4'
    ImagemTV            = 'populos-elux7-v5'
    ProxyTV             = 'http://<IP_DO_SERVIDOR>:8090'
    UsuarioTV           = '<usuario-do-site>'
    SenhaTV             = '<SENHA_TV>'
}
