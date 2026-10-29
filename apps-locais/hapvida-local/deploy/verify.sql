SET NOCOUNT ON;
SELECT g.GroupID,g.Name,g.UseParent,g.UseParentApps,s.SetupID,s.AuthType,s.DefaultDomain,s.ImageFile
FROM Groups g JOIN Setup s ON s.SetupID=g.SetupID WHERE g.GroupID IN (13,14);
SELECT a.ApplicationID,a.Name,a.AutoStart,a.TM,l.Parameter
FROM Application a JOIN Local l ON l.ApplicationID=a.ApplicationID
WHERE a.GroupID=14 AND a.ApplicationID IN (88,89);
SELECT f.FileDestination,DATALENGTH(u.FileContent) AS Bytes
FROM FileEntry f JOIN UCFT u ON u.UCFTID=f.UCFTID
WHERE f.MemberType=1 AND f.MemberID=14 AND f.FileDestination LIKE '/setup/hapvida-local/%';
SELECT COUNT(*) AS ArquivosRemotosDeSaude FROM FileEntry
WHERE MemberType=1 AND MemberID=14 AND FileDestination LIKE '/setup/hapvida/%';
SELECT Name,GroupID FROM Device ORDER BY DeviceID;
