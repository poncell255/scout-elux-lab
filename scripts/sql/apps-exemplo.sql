-- Exemplos de aplicativos por OU (troque @ou). IDs não são identity: use MAX+1.
-- Depois: UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=@ou;
DECLARE @ou int = <GROUP_ID>, @id int;

-- Ícone global (UCFT FileType=1, FileMode=-1, PNG 32x32): inserir FileContent via script (varbinary).
-- INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (-1,-1,1,'outlook.png',-1,0,<epoch_utc>,<bytes>);

-- Outlook (Edge em modo app)
SELECT @id = MAX(ApplicationID) + 1 FROM Application WITH (UPDLOCK, HOLDLOCK);
INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1)
VALUES (@id, 5, 'Outlook', 0, 0, 1, 0, 1, @ou, 'outlook', 0, -1, 1, '', 'Outlook', 0);
INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id, 'CUSTOM', '/usr/bin/microsoft-edge --app=https://outlook.office.com --no-first-run', 0);

-- Citrix Workspace (StoreFront) com loja
SELECT @id = MAX(ApplicationID) + 1 FROM Application WITH (UPDLOCK, HOLDLOCK);
INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1)
VALUES (@id, 17, 'Citrix Workspace', 0, 0, 1, 0, 1, @ou, 'citrix', 0, -1, 1, '', 'Citrix Workspace', 0);
INSERT INTO Storefront (ApplicationID, Stores, LogoffSessions, DesktopsUseFullscreen, AutostartResources, Username, Pass, Domain, LogoffDelay, UseLogoffDelay, ForcedLogoff, ShowLastUser, UseCRFile, CRFile)
VALUES (@id, 'https://<loja>.cloud.com', 4, 1, '', '', '', '', 0, 0, 0, 1, 0, '');
-- Quiosque: AutoStart=1, TM=1, AutostartResources='<nome do desktop>', e Groups.UseParentApps=0 na OU.

-- Horizon (Omnissa)
SELECT @id = MAX(ApplicationID) + 1 FROM Application WITH (UPDLOCK, HOLDLOCK);
INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1)
VALUES (@id, 15, 'Horizon', 0, 0, 1, 0, 1, @ou, '', 0, -1, 1, '', 'Horizon', 0);
INSERT INTO VDA (ApplicationID, Server, Username, Pass, Domain, UseSSL, ShowLastUser, Options, USBRules, Protocol, AllowH264, USBConnectOptions)
VALUES (@id, '', '', '', '', 1, 1, 0, '', 0, 1, 0);
