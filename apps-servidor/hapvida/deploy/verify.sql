SET NOCOUNT ON;
SELECT g.GroupID,g.Name,s.SetupID,s.AuthType,s.DefaultDomain,s.ImageFile FROM Groups g JOIN Setup s ON s.SetupID=g.SetupID WHERE g.GroupID=13;
SELECT a.ApplicationID,a.Name,a.AutoStart,a.TM,l.Parameter FROM Application a JOIN Local l ON a.ApplicationID=l.ApplicationID WHERE a.GroupID=13 AND a.ApplicationID IN (79,80);
SELECT f.FileDestination,DATALENGTH(u.FileContent) AS Bytes FROM FileEntry f JOIN UCFT u ON f.UCFTID=u.UCFTID WHERE f.MemberType=1 AND f.MemberID=13 AND (f.FileDestination LIKE '/setup/hapvida/%' OR f.FileDestination='/setup/populos-digital/DESATIVADO');
SELECT Name,GroupID,SetupChanged,ApplicationsChanged FROM Device ORDER BY DeviceID;