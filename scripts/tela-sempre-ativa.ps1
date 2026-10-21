# Tela sempre ativa em todos os setups: sem bloqueio de tela, sem desligar monitor, sem suspensão (com e sem login).
# PowerManagementProfile (um por SetupID x ProfileType 1..4 = Eco, Eco expediente, Performance, Performance expediente)
#   DPMS -> DisplayOffTimerEnabled, S3 -> IdleTimerEnabled, S3NoLogin -> IdleTimerNoLoginEnabled, ScreenSaver -> DisplayLockTimerEnabled
# Setup.PowerManagementProfileType: 0 automático, 1 Eco, 2 Performance.
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-tela-ativa.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$sql=@"
SET XACT_ABORT ON; BEGIN TRAN;
DECLARE @max int = 5999940;
INSERT INTO PowerManagementProfile (SetupID, ProfileType, BrightnessLevel, ActionOnLid, ActionOnPowerButton, ActionOnS3, ActionOnS3NoLogin, ActionOnSleepButton, DPMS, DPMSDelay, S3, S3Delay, S3NoLogin, NoLoginDelay, ScreenSaver, ScreenSaverDelay)
SELECT s.SetupID, t.v, 100, 3, 2, 3, 3, 3, 0, @max, 0, @max, 0, @max, 0, @max
FROM Setup s CROSS JOIN (VALUES (1),(2),(3),(4)) t(v)
WHERE NOT EXISTS (SELECT 1 FROM PowerManagementProfile p WHERE p.SetupID=s.SetupID AND p.ProfileType=t.v);
UPDATE PowerManagementProfile SET DPMS=0, DPMSDelay=@max, S3=0, S3Delay=@max, S3NoLogin=0, NoLoginDelay=@max, ScreenSaver=0, ScreenSaverDelay=@max;
UPDATE Setup SET PowerManagementProfileType=2;
UPDATE Device SET SetupChanged=1, ApplicationsChanged=1;
COMMIT;
SELECT SetupID, ProfileType, DPMS, S3, S3NoLogin, ScreenSaver FROM PowerManagementProfile ORDER BY 1,2;
"@
sqlcmd -S localhost -d ScoutEnterprise -E -C -W -b -s '|' -Q $sql
