-- Cadastra um usuário do Entra ID como administrador do Scout (mesmos direitos do administrador inicial).
-- O e-mail/UPN precisa ser igual ao claim "email" (ou preferred_username) do token.
DECLARE @email nvarchar(200) = N'<email@empresa.com.br>';
IF NOT EXISTS (SELECT 1 FROM Administrator WHERE UPPER(Name) = UPPER(@email))
INSERT INTO Administrator (AdministratorID, Name, Sid, Rights, Type, ID, ProfileType, RootOUFMD)
SELECT (SELECT MAX(AdministratorID) + 1 FROM Administrator WITH (UPDLOCK, HOLDLOCK)), @email, Sid, Rights, Type, ID, ProfileType, RootOUFMD
FROM Administrator WHERE AdministratorID = 1;
