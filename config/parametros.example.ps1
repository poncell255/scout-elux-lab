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
}
