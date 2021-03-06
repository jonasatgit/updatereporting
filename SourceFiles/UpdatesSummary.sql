---SCRIPTVERSION: 20201130

-----------------------------------------------------------------------------------------------------------------------
---- Disclaimer
----
---- This sample script is not supported under any Microsoft standard support program or service. This sample
---- script is provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties
---- including, without limitation, any implied warranties of merchantability or of fitness for a particular
---- purpose. The entire risk arising out of the use or performance of this sample script and documentation
---- remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation,
---- production, or delivery of this script be liable for any damages whatsoever (including, without limitation,
---- damages for loss of business profits, business interruption, loss of business information, or other
---- pecuniary loss) arising out of the use of or inability to use this sample script or documentation, even
---- if Microsoft has been advised of the possibility of such damages.
-----------------------------------------------------------------------------------------------------------------------
---- Changelog:
---- 20201130: Added "System Center Endpoint Protection" back to the exclusion list
---- 20201124: Changed some descriptions, the QuickFixEngineering query due to missing date entries and the language problem from 20201103, 
----           QuickFixEngineering query will also use the rollups as a reference if possible, simplified the current- and last-rollup queries and removed the limitation for Server 2008
---- 20201103: Changed 'max(CASE WHEN (ISDATE(QFE.InstalledOn0) = 0' to 'max(CASE WHEN (LEN(QFE.InstalledOn0) > 10' due to language problems
---- 20201103: Changed 'Windows Defender' to 'Microsoft Defender Antivirus'

----- just for testing in SQL directly
declare @CollectionIDs as varchar(8)
set @CollectionIDs = 'SMS00001'

-- using prefix like "2017-07" to filter for the security rollup of the past month
DECLARE @LastRollupPrefix as char(7);
SET @LastRollupPrefix = (SELECT convert(char(7),DATEADD(MONTH,-1,GETDATE()),126)); 

-- using prefix like "2017-08" to filter for the current security rollup
DECLARE @CurrentRollupPrefix as char(7);
SET @CurrentRollupPrefix = (SELECT convert(char(7),DATEADD(MONTH,0,GETDATE()),126)); 

-- calculate 2nd Tuesday of month to add the correct date string in case install date is missing in v_GS_QUICK_FIX_ENGINEERING
DECLARE @FirstDayOfMonth datetime;
DECLARE @SecondTuesdayOfMonth datetime;
DECLARE @UpdatePrefix as char(7);

SET  @FirstDayOfMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0)     
SET @SecondTuesdayOfMonth = DATEADD(DAY,((10 - DATEPART(dw,@FirstDayOfMonth)) % 7) + 7, @FirstDayOfMonth)

IF GETDATE() < @SecondTuesdayOfMonth
              SET @UpdatePrefix = @LastRollupPrefix
ELSE
              SET @UpdatePrefix = @CurrentRollupPrefix;


/*
---- Query to filter by product
---- could be added as a filter to the report
select distinct CICI.CategoryInstanceName, CICI.CategoryInstanceID from v_CICategoryInfo CICI
where CICI.CategoryTypeName = 'Product'
order by CICI.CategoryInstanceName

*/


-- Defender Updates will be filtered out, because they will be updated more frequently
With ExcludedUpdates (AssignmentID,CI_ID) as
              (            
                            select CIA.AssignmentID, CIATOCI.CI_ID 
                            from v_CIAssignment CIA 
                            inner join v_CIAssignmentToCI CIATOCI on CIATOCI.AssignmentID = CIA.AssignmentID 
                            inner join v_CICategoryInfo CICI on CICI.Ci_ID = CIATOCI.CI_ID and CICI.CategoryInstanceName in ('Microsoft Defender Antivirus','System Center Endpoint Protection')
              ),
-- list of cumulative updates of the current and the past month
CumulativeUpdates (ArticleID,CI_ID, Latest) as
(
              Select 'KB' + updi.ArticleID as Article, CI_ID, Latest = 0 from v_updateinfo updi where (updi.Title like @LastRollupPrefix + ' Cumulative Update for Windows%' or updi.Title like @LastRollupPrefix + ' Security Monthly Quality Rollup%')
              UNION ALL
              Select 'KB' + updi.ArticleID as Article, CI_ID, Latest = 1 from v_updateinfo updi where (updi.Title like @CurrentRollupPrefix + ' Cumulative Update for Windows%' or updi.Title like @CurrentRollupPrefix + ' Security Monthly Quality Rollup%')
)


select [Name]                                                                        = VRS.Name0
              ,[ResourceID]                                                           = VRS.ResourceID
              ,[Counter]                                                                              = 1 -- a counter to make it easier to count in reporting services
              ,[PendingReboot]                                                    = BGBL.ClientState                         
              ,[OSType]                                                                               = GOS.Caption0
              ,[ClientVersion]                                         = VRS.Client_Version0
              ,[WSUSVersion]                                                       = USS.LastWUAVersion
              ,[DefenderPattern]                                                 = AHS.AntivirusSignatureVersion
              ,[DefenderPatternAge]           = AHS.AntivirusSignatureAge
              ,[WSUSScanError]                                                   = USS.LastErrorCode
              ,[DaysSinceLastOnline]                             = ISNULL((DateDiff(DAY,CHCS.LastPolicyRequest,GETDATE())),999)
              ,[DaysSinceLastAADSLogon]                    = ISNULL((DateDiff(DAY,VRS.Last_Logon_Timestamp0,GETDATE())), 999)
              ,[DaysSinceLastBoot]                                = ISNULL((DateDiff(DAY,GOS.LastBootUpTime0,GETDATE())), 999)
              ,[DaysSinceLastUpdateInstall]   = ISNULL((DateDiff(DAY,UPDINSTDATE.LastInstallTime,GETDATE())), 999)
              ,[MonthSinceLastOnline]                                       = ISNULL((DateDiff(MONTH,CHCS.LastPolicyRequest,GETDATE())), 999)
              ,[MonthSinceLastOnlineABC]                                = case when ISNULL((DateDiff(MONTH,CHCS.LastPolicyRequest,GETDATE())), 999) = 0 then 'A'
                                                                                                                                                       when ISNULL((DateDiff(MONTH,CHCS.LastPolicyRequest,GETDATE())), 999) = 1 then 'B'
                                                                                                                                                       else 'C' end
              ,[MonthSinceLastAADSLogon]                 = ISNULL((DateDiff(MONTH,VRS.Last_Logon_Timestamp0,GETDATE())), 999)
              ,[MonthSinceLastAADSLogonABC]                       = case when ISNULL((DateDiff(MONTH,VRS.Last_Logon_Timestamp0,GETDATE())), 999) = 0 then 'A'
                                                                                                                                                       when ISNULL((DateDiff(MONTH,VRS.Last_Logon_Timestamp0,GETDATE())), 999) = 1 then 'B'
                                                                                                                                                       else 'C' end
              ,[MonthSinceLastBoot]                            = ISNULL((DateDiff(MONTH,GOS.LastBootUpTime0,GETDATE())), 999)
              ,[MonthSinceLastBootABC]                                   = case when ISNULL((DateDiff(MONTH,GOS.LastBootUpTime0,GETDATE())), 999) = 0 then 'A'
                                                                                                                                                       when ISNULL((DateDiff(MONTH,GOS.LastBootUpTime0,GETDATE())), 999) = 1 then 'B'
                                                                                                                                                       else 'C' end
              ,[MonthSinceLastUpdateInstall] = ISNULL((DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE())), 999)
              ,[MonthSinceLastUpdateInstallABC]      = case when ISNULL((DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE())), 999) = 0 then 'A'
                                                                                                                                                       when ISNULL((DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE())), 999) = 1 then 'B'
                                                                                                                                                       else 'C' end
              ,[MonthSinceLastUpdateScan]                = ISNULL((DateDiff(MONTH,USS.LastScanTime,GETDATE())), 999)
              -- custom compliance state based on deploymentstatus, update status and last installdate. Less or equal 1 because the last update install needs to be at least in the last month
              ,[UpdateAssignmentCompliance]           = Case when AssignmentStatus.Compliant = AssignmentStatus.AssignmentSum and UPDMISSINGTARGET.UpdatesApprovedAndMissing = 0 and (DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE()) <= 1) then 1 else 0 end
              ,[UpdateStatusCompliant]                       = AssignmentStatus.Compliant
              ,[UpdateAssignmentSum]                                      = AssignmentStatus.AssignmentSum
              ,[UpdateStatusNonCompliant]                = AssignmentStatus.NonCompliant
              ,[UpdateStatusUnknown]                                      = case when AssignmentStatus.Unknown is null then 999
                                                                                                                                          when (AssignmentStatus.Compliant is null  and AssignmentStatus.NonCompliant is null and AssignmentStatus.Failed is null and AssignmentStatus.Pending is null) then 999
                                                                                                                                          else AssignmentStatus.Unknown end    ---some are unknown, because the state message seems to be missing
              ,[UpdateStatusFailed]                               = AssignmentStatus.Failed
              ,[UpdateStatusPending]                                         = AssignmentStatus.Pending
              ,[MissingUpdatesAll]                                = UPDMISSING.MissingUpdates
              ,[MissingUpdatesApproved]                    = UPDMISSINGTARGET.UpdatesApprovedAndMissing
              ,[UpdatesApprovedAll]                             = UPDMISSINGTARGET.UpdatesApproved
              ---- show status of reference security rollup update
              ---- if current rollup ist installed, the last one doesn't matter and will be set to installed as well
              ,[LastRollupStatus]                                                  = case when CURRROLLUPSTAT.Status = 3 then 3
                                                                                                                                          when Isnull(LASTROLLUPSTAT.Status, '') = '' then 2
                                                                                                                                          else LASTROLLUPSTAT.Status end
              ,[CurrentRollupStatus]                             = Case When isnull(CURRROLLUPSTAT.Status, '') = '' then 2
                                                                                                                                          else CURRROLLUPSTAT.Status end
              ---- add a list of all the collections having a software update or all deployments maintenance window
              --,[UpdateMWs]                                                                    = STUFF((select ';' + Description 
              --                         from v_FullCollectionMembership TX0 
              --                         inner join v_ServiceWindow TX1 on TX1.CollectionID = TX0.CollectionID                      
              --                         where TX1.ServiceWindowType in (1,4) and TX0.ResourceID = VRS.ResourceID FOR XML PATH('')), 1, 1, '')
              ---- add a list of all collections with update deployments to see gaps
              ,[UpdateCollections]                                 = STUFF((select '; ' + CIA.CollectionName
                                         from v_FullCollectionMembership FCM
                                         inner join v_CIAssignment CIA on CIA.CollectionID = FCM.CollectionID
                                         where CIA.AssignmentType in (1,5) and FCM.ResourceID = VRS.ResourceID 
                                         group by FCM.ResourceID, CIA.CollectionName FOR XML PATH('')), 1, 1, '')
from v_R_System VRS
----- Join all installed updates
left join (
              Select ucs.ResourceID
              from v_UpdateComplianceStatus ucs where Status = 3
              group by ucs.ResourceID
) as UPD on UPD.ResourceID = VRS.ResourceID
---- Join all missing updates which are deployed to the system
left join (
              Select ucs.ResourceID
                            ,[UpdatesApproved] = count(CT.ResourceID) 
                            ,[UpdatesApprovedAndMissing] = sum(case when ucs.Status = 2 then 1 else 0 end)
              from v_UpdateComplianceStatus ucs
              inner join v_CITargetedMachines CT on CT.ResourceID = ucs.ResourceID and CT.CI_ID = ucs.CI_ID -- updates deployed to the system
              where ucs.CI_ID not in (Select CI_ID from ExcludedUpdates)
              group by ucs.ResourceID
) as UPDMISSINGTARGET on UPDMISSINGTARGET.ResourceID = VRS.ResourceID
--- Join ALL missing updates whether or not deployed to the system
left join (
              Select UCS.ResourceID
              ,[MissingUpdates] = count(UCS.ResourceID) 
              from v_UpdateComplianceStatus UCS where Status = 2
              group by UCS.ResourceID
) as UPDMISSING on UPDMISSING.ResourceID = VRS.ResourceID
--- join last Rollup as reference
left join (
              select UCS.ResourceID,
              max(UCS.Status) as Status
              from v_UpdateComplianceStatus UCS
              inner join CumulativeUpdates CUU on CUU.CI_ID = UCS.CI_ID and CUU.Latest = 0
              group by UCS.ResourceID
) as LASTROLLUPSTAT on LASTROLLUPSTAT.ResourceID = VRS.ResourceID
--- join current Rollup as reference
left join (
              select UCS.ResourceID,
              max(UCS.Status) as Status
              from v_UpdateComplianceStatus UCS
              inner join CumulativeUpdates CUU on CUU.CI_ID = UCS.CI_ID and CUU.Latest = 1
              group by UCS.ResourceID
) as CURRROLLUPSTAT on CURRROLLUPSTAT.ResourceID = VRS.ResourceID
--- Join OS Information
left join v_GS_OPERATING_SYSTEM GOS on GOS.ResourceID = VRS.ResourceID
--- Join Client Health status
left join v_CH_ClientSummary CHCS on CHCS.ResourceID = VRS.ResourceID
--- Join WSUS Client Info
left join v_UpdateScanStatus USS on USS.ResourceID = VRS.ResourceID
--- Join Antimalware Info 
left join v_GS_AntimalwareHealthStatus AHS on AHS.ResourceID = VRS.ResourceID
--- join update compliance status (for overall compliance, failed and pending status)
left join (
              SELECT uas.ResourceID,
                            count(uas.ResourceID) as AssignmentSum,
                            --max(uas.LastComplianceMessageTime) as LastComplianceMessageTime,
                            sum(CASE WHEN (IsCompliant = 1) THEN 1 ELSE 0 END) AS Compliant, 
                            sum(CASE WHEN (IsCompliant = 0) THEN 1 ELSE 0 END) AS NonCompliant, 
                            sum(CASE WHEN (IsCompliant is null) THEN 1 ELSE 0 END) AS Unknown, 
                            sum(CASE WHEN (IsCompliant = 0) AND LastEnforcementMessageID in (6,9) THEN 1 ELSE 0 END) AS Failed, 
                            sum(CASE WHEN (IsCompliant = 0) AND LastEnforcementMessageID not in (0,6,9) THEN 1 ELSE 0 END) AS Pending
              FROM v_UpdateAssignmentStatus uas
              where UAS.AssignmentID not in (Select AssignmentID from ExcludedUpdates) 
              group by uas.ResourceID
) as AssignmentStatus on AssignmentStatus.ResourceID = VRS.ResourceID
---- join last update installdate for security updates just as a reference to find problematic clients not installing securita updates at all
---- need to convert datetime for older OS from 64bit binary to datetime
left join (
              select qfe.ResourceID
                            --- CUU.CI_ID is not null means the current rollup is installed and we can use that installdate as reference
                            ,LastInstallTime = max(CASE WHEN CUU.CI_ID is not null then 
                            (
                                         --- the current rollup is installed, but do we have a valid install date? In some cases the installdate seems to be mising. For some Win10 1803 systems for example.
                                         --- "-05" impossible date, since the update could not be released the 5th day of the month (normally). That should indicate the missing date info and give us enough info about the state of the system
                                         CASE WHEN qfe.InstalledOn0 = '' THEN @UpdatePrefix + '-05 00:00:00' ELSE TRY_CONVERT(datetime,qfe.InstalledOn0,101) END      
                            )
                            else --CUU.CI_ID IS null
                            (
                                         --- due to some older systems sending datetime as binary like this: 01cc31160e1c4bac and since there is no cumulative update for such systems "CUU.CI_ID is null" should always be valid
                                         --- Found three different date strings so far: MM/dd/yyyy or yyyMMdd or binary
                                         CASE WHEN (LEN(QFE.InstalledOn0) > 10) 
                                         THEN CAST((TRY_CONVERT(BIGINT,TRY_CONVERT(VARBINARY(64), '0x' + QFE.InstalledOn0,1)) / 864000000000.0 - 109207) AS DATETIME) 
                                         ELSE TRY_CONVERT(datetime,qfe.InstalledOn0,101)
                                         END 
                            ) END)
              from v_GS_QUICK_FIX_ENGINEERING QFE
              left join CumulativeUpdates CUU on CUU.ArticleID = QFE.HotFixID0
              where (QFE.Description0 = 'Security Update' or QFE.Description0 is null)
              group by qfe.ResourceID
) UPDINSTDATE on UPDINSTDATE.ResourceID = VRS.ResourceID
---- join Pending Reboot Info
---- left join BGB_LiveData BGBL on BGBL.ResourceID = VRS.ResourceID ---- <- no direct rights assigned and no other view available, using v_CombinedDeviceResources instead
left join v_CombinedDeviceResources BGBL on BGBL.MachineID = VRS.ResourceID

where VRS.ResourceID in (Select ResourceID from v_FullCollectionMembership where CollectionID in (@CollectionIDs))

---- fix for SQL compat level problem 
---- https://support.microsoft.com/en-us/help/3196320/sql-query-times-out-or-console-slow-on-certain-configuration-manager-d
-- OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'))
