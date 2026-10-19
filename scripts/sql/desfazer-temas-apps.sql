-- Remove o tema POPULOS da OU Enterprise (gravado em 2026-10-15).
-- Executar no banco ScoutEnterprise (ex.: sqlcmd -S localhost\SQLEXPRESS -U sa -d ScoutEnterprise -i este_arquivo).
-- Alternativa total: restaurar C:\ScoutSetup\backup\ScoutEnterprise-pre-tema.bak (perde alteracoes posteriores).
BEGIN TRANSACTION;
DELETE FROM UCFT WHERE UCFTID IN (SELECT UCFTID FROM FileEntry WHERE MemberType = 1 AND MemberID = 2 AND Description = N'Tema POPULOS');
DELETE FROM FileEntry WHERE MemberType = 1 AND MemberID = 2 AND Description = N'Tema POPULOS';
DELETE FROM IniEntry WHERE MemberType = 1 AND MemberID = 2 AND IniFile = N'/setup/terminal.ini' AND IniSection = N'Layout' AND IniKey = N'CurrentTheme' AND IniValue IN (N'populos-theme', N'populos-theme-v2');
-- Perfil OpenVPN (2026-10-16), remover só se quiser tirar a VPN da OU:
-- DELETE FROM UCFT WHERE UCFTID IN (SELECT UCFTID FROM FileEntry WHERE MemberType = 1 AND MemberID = 2 AND Description = N'VPN POPULOS');
-- DELETE FROM FileEntry WHERE MemberType = 1 AND MemberID = 2 AND Description = N'VPN POPULOS';
-- OU Populos (GroupID 4), 2026-10-19: tema populos-ou-v1 e apps Outlook/Teams. Remover só se quiser desfazer:
-- DELETE FROM UCFT WHERE UCFTID IN (SELECT UCFTID FROM FileEntry WHERE MemberType = 1 AND MemberID = 4 AND Description = N'Tema POPULOS OU');
-- DELETE FROM FileEntry WHERE MemberType = 1 AND MemberID = 4 AND Description = N'Tema POPULOS OU';
-- DELETE FROM IniEntry WHERE MemberType = 1 AND MemberID = 4 AND IniKey = N'CurrentTheme' AND IniValue = N'populos-ou-v1';
-- DELETE FROM Browser WHERE ApplicationID IN (4,5); DELETE FROM Application WHERE ApplicationID IN (4,5) AND GroupID = 4;
-- DELETE FROM UCFT WHERE FileType = 1 AND FileName IN (N'outlook.png', N'teams.png');
-- DELETE FROM Local WHERE ApplicationID IN (4,5);
-- DELETE FROM Storefront WHERE ApplicationID = 6; DELETE FROM VDA WHERE ApplicationID = 7; DELETE FROM Application WHERE ApplicationID IN (6,7) AND GroupID = 4;
-- OU Bom Jesus (GroupID 6), 2026-10-19 — preferir restaurar C:\ScoutSetup\backup\ScoutEnterprise-pre-bomjesus.bak se for desfazer tudo:
-- DELETE FROM UCFT WHERE UCFTID IN (SELECT UCFTID FROM FileEntry WHERE MemberType = 1 AND MemberID = 6);
-- DELETE FROM FileEntry WHERE MemberType = 1 AND MemberID = 6; DELETE FROM IniEntry WHERE MemberType = 1 AND MemberID = 6;
-- DELETE FROM Local WHERE ApplicationID IN (8,9,10,11); DELETE FROM Storefront WHERE ApplicationID IN (8,9,10,11); DELETE FROM VDA WHERE ApplicationID IN (8,9,10,11);
-- DELETE FROM Application WHERE GroupID = 6; DELETE FROM Groups WHERE GroupID = 6 AND Name = N'Bom Jesus';
COMMIT;
