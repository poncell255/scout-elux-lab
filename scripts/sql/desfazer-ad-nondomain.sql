-- Desfaz o AD nos setups 0/1/2 e remove a OU Populos NonDomain (GroupID 8 / setup 3).
-- Alternativa: restaurar C:\ScoutSetup\backup\ScoutEnterprise-pre-ad.bak
BEGIN TRAN;
UPDATE Setup SET AuthType=0, DefaultDomain=NULL, DomainFieldStatus=NULL WHERE SetupID IN (0,1,2);
DELETE FROM AuthDomain WHERE SetupID IN (0,1,2);
-- mova antes os dispositivos da OU 8 para outra OU
DELETE FROM Local WHERE ApplicationID IN (SELECT ApplicationID FROM Application WHERE GroupID=8);
DELETE FROM Storefront WHERE ApplicationID IN (SELECT ApplicationID FROM Application WHERE GroupID=8);
DELETE FROM VDA WHERE ApplicationID IN (SELECT ApplicationID FROM Application WHERE GroupID=8);
DELETE FROM Application WHERE GroupID=8;
DELETE FROM IniEntry WHERE MemberType=1 AND MemberID=8;
DELETE FROM FileEntry WHERE MemberType=1 AND MemberID=8;
DELETE FROM UCFT WHERE MemberType=1 AND MemberID=8;
DELETE FROM Groups WHERE GroupID=8;
DELETE FROM Screen WHERE ScreenSettingsID IN (SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=3);
DELETE FROM ScreenSettings WHERE MemberType=5 AND MemberID=3;
DELETE FROM Multimedia WHERE MemberType=5 AND MemberID=3;
DELETE FROM PowerManagementProfile WHERE SetupID=3;
DELETE FROM NetworkProfile WHERE SetupID=3;
DELETE FROM ComPort WHERE SetupID=3;
DELETE FROM ScreenSaver WHERE SetupID=3;
DELETE FROM Setup WHERE SetupID=3;
UPDATE Device SET SetupChanged=1, ApplicationsChanged=1;
COMMIT;
