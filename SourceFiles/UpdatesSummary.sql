---SCRIPTVERSION: 20220404

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
---- 2022-04-04: Changed the way deployed updates are shown. "MissingUpdatesApproved" will not show updates for excluded deployments anymore. Makes it more consistant with the rest of the report
----			 Added systems domain name to the list
----			 Removed unnecessary where clause: "where (QFE.Description0 = 'Security Update' or QFE.Description0 is null)"
----			 Added Parameter @MonthIndex to be able to set the report one month back. Only possible if updates are delayed for one month and not deployed within the month of their release date
----			 Added Paremeter to be able exclude future deployments based on starttime or deadline, exclude available and diabled deployments 
---- 2022-03-02: Fixed @SecondTuesdayOfMonth and change logic for pulling the current and last rollups. Based on pull request 11
---- 2021-11-18: Added "Cumulative Update for Microsoft server operating system" string for server 2022 updates.
---- 2021-08-01: Changed multi value parameter handling to use CTEs due to performance issues with some environments. 
----             Also changed overall compliance to be only compliant in case the last rollup has been installed and changed name from "UpdateAssignmentCompliance" to "OverallComplianceState"
----		     Changed name from "UpdateStatusCompliant" to "UpdateAssignmentCompliant" to be more accurate with the wording
----             Removed condition "UPDATESTATES.UpdatesApprovedAndMissing = 0" of overall compliance state since it does not really work with the way we exclude deployments
----		     Added option to exclude deployments with starttime in the future
----		     Disabled update deployments will now be excluded from overall compliance state
---- 2021-06-14: Simplified RollupStatus and CurrentRollupStatus case when clauses				
---- 2021-06-10: Added update install errors and changed query logic due to performance problems starting with 35k systems
---- 2020-11-30: Added "System Center Endpoint Protection" back to the exclusion list
---- 2020-11-24: Changed some descriptions, the QuickFixEngineering query due to missing date entries and the language problem from 20201103, 
----             QuickFixEngineering query will also use the rollups as a reference if possible, simplified the current- and last-rollup queries and removed the limitation for Server 2008
---- 2020-11-03: Changed 'max(CASE WHEN (ISDATE(QFE.InstalledOn0) = 0' to 'max(CASE WHEN (LEN(QFE.InstalledOn0) > 10' due to language problems
---- 2020-11-03: Changed 'Windows Defender' to 'Microsoft Defender Antivirus'

--- START just for testing in SQL directly
Declare @CollectionID as varchar(max) = 'SMS00001' ---- semicolon seperated list of collectionIDs
Declare @ExcludeProductList as varchar(max) = N'Microsoft Defender Antivirus;System Center Endpoint Protection'; ---- semicolon seperated list of update products
Declare @MonthIndex as int = 0; -- 0 = current month, 1 = previous month

-- Using a bitmask like parameter. Makes it possible to use a multivalue parameter instead of multiple parameters to filter out some deployments
-- Using the same CTE function to convert parameter arraylist to CTE as with other multi value parameters due to perf issues on some SQL systems
Declare @ExcludeDeplBitMask as varchar(20) = '8;16'---'2;4;8;16';
-- 2 = Deployments with starttime in the future will be excluded 
-- 4 = Deployments with deadline in the future will be excluded
-- 8 = Available deployments will be excluded
-- 16 = Disabled deployments will be excluded
--- END just for testing in SQL directly 

---- Extra variables to prevent variable performance issues in some SQL configurations
Declare @CollectionIDList as varchar(max) = @CollectionID ---- semicolon seperated list of collectionIDs
Declare @ExcludeProducts as varchar(max) = @ExcludeProductList ---- semicolon seperated list of update products
Declare @MonthIndexInternal as int = @MonthIndex
Declare @ExcludeDeplBitMaskInternal as varchar(20) = @ExcludeDeplBitMask

-- using prefix like "2017-07" to filter for the security rollup of the past month
DECLARE @LastRollupPrefix as char(7);
DECLARE @CurrentRollupPrefix as char(7);
DECLARE @SecondTuesdayOfMonth datetime;

-- Calculate 2nd Tuesday of month to add the correct date string in case install date is missing in v_GS_QUICK_FIX_ENGINEERING
-- Also used to fill the gap between the first day of a month and the next time a rollup will be released
SET @SecondTuesdayOfMonth = (DATEADD(Month, DATEDIFF(Month, 0, GETDATE()), 0) + 6 + 7 - (DATEPART(Weekday, DATEADD(Month, DATEDIFF(Month, 0, GETDATE()), 0)) + (@@DateFirst + 3) + 7) %7)

IF GETDATE() < @SecondTuesdayOfMonth
	BEGIN
		SET @LastRollupPrefix = (SELECT convert(char(7),DATEADD(MONTH,-2-@MonthIndexInternal,GETDATE()),126))
		SET @CurrentRollupPrefix = (SELECT convert(char(7),DATEADD(MONTH,-1-@MonthIndexInternal,GETDATE()),126)) 
	END
ELSE
    BEGIN
		SET @LastRollupPrefix = (SELECT convert(char(7),DATEADD(MONTH,-1-@MonthIndexInternal,GETDATE()),126))
		SET @CurrentRollupPrefix = (SELECT convert(char(7),DATEADD(MONTH,0-@MonthIndexInternal,GETDATE()),126))
	END;

-- PRE QUERIES
-- Create table for collection IDs. Converting string based list into CTE to avoid any parameter performance issues with certain SQL configurations.
WITH CTE_CollIDPieces
AS 
(
    SELECT 1 AS ID
        ,1 AS [StartString]
        ,Cast(CHARINDEX(';', @CollectionIDList,0) as int) AS StopString
    UNION ALL
    SELECT ID + 1
                    ,StopString + 1
                    ,Cast(CHARINDEX(';', @CollectionIDList, StopString + 1) as int)
    FROM CTE_CollIDPieces
    WHERE StopString > 0
)
,CTE_CollIDs
AS
(
    SELECT (SUBSTRING(@CollectionIDList, StartString, 
                                CASE WHEN StopString > 0 THEN StopString - StartString
                                ELSE LEN(@CollectionIDList)
                END)) AS CollectionID
    FROM CTE_CollIDPieces 
)
-- Create CTE for excluded products. Converting string based list into CTE to avoid any parameter performance issues with certain SQL configurations.
,CTE_ProductPieces
AS 
(
    SELECT 1 AS ID
        ,1 AS [StartString]
        ,Cast(CHARINDEX(';', @ExcludeProducts,0) as int) AS StopString
    UNION ALL
    SELECT ID + 1
                    ,StopString + 1
                    ,Cast(CHARINDEX(';', @ExcludeProducts, StopString + 1) as int)
    FROM CTE_ProductPieces
    WHERE StopString > 0
)
,CTE_Products
AS
(
    SELECT (SUBSTRING(@ExcludeProducts, StartString, 
                                CASE WHEN StopString > 0 THEN StopString - StartString
                                ELSE LEN(@ExcludeProducts)
                END)) AS Product
    FROM CTE_ProductPieces 
),
-- Using the same CTE function to convert parameter arraylist to CTE as with other multi value parameters due to perf issues on some SQL systems
CTE_ExcludePieces
AS 
(
    SELECT 1 AS ID
        ,1 AS [StartString]
        ,Cast(CHARINDEX(';', @ExcludeDeplBitMaskInternal,0) as int) AS StopString
    UNION ALL
    SELECT ID + 1
                    ,StopString + 1
                    ,Cast(CHARINDEX(';', @ExcludeDeplBitMaskInternal, StopString + 1) as int)
    FROM CTE_ExcludePieces
    WHERE StopString > 0
)
,CTE_ExcludeIDs
AS
(
    SELECT (SUBSTRING(@ExcludeDeplBitMaskInternal, StartString, 
                                CASE WHEN StopString > 0 THEN StopString - StartString
                                ELSE LEN(@ExcludeDeplBitMaskInternal)
                END)) AS ExcludeID
    FROM CTE_ExcludePieces 
),
-- generate list of systems we are insterested in
ResourceList (ResourceID) as
(
			Select Distinct ResourceID from v_FullCollectionMembership FCM
			inner join CTE_CollIDs on CTE_CollIDs.CollectionID = FCM.CollectionID
),
-- List of deployments we might need to exclude
ExcludedDeploymentsBaseList (AssignmentID, AssignmentType) as
(
			--- Getting a list of deployments/assignments based on different criteria to further limit the output later on
			-- parameter to be able to toggle to ex or include future deployments
			-- deployments with STARTTIME in the future
			select CIA.AssignmentID, AssignmentType = 2 
			from v_CIAssignment cia 
			where cia.AssignmentType in (1,5) -- 1 = updates, 5 = update groups
			and cia.StartTime > GETDATE() 
			-- deployments with DEADLINE in the future
			UNION ALL
			select CIA.AssignmentID, AssignmentType = 4
			from v_CIAssignment cia 			
			where cia.AssignmentType in (1,5) -- 1 = updates, 5 = update groups
			and cia.EnforcementDeadline > GETDATE() 
			-- availabe deployments
			UNION ALL
			select CIA.AssignmentID, AssignmentType = 8
			from v_CIAssignment cia 			
			where cia.AssignmentType in (1,5) -- 1 = updates, 5 = update groups
			and cia.EnforcementDeadline is null
			-- disabled deployments
			UNION ALL
			select CIA.AssignmentID, AssignmentType = 16
			from v_CIAssignment cia 
			where cia.AssignmentType in (1,5) -- 1 = updates, 5 = update groups
			and cia.AssignmentEnabled = 0 
),
ExcludedDeployments (AssignmentID,AssignmentType, CI_ID) as
(
			-- Select just the deployments we need to exclude
			Select AssignmentID, AssignmentType, CI_ID = 0 from ExcludedDeploymentsBaseList 
			where AssignmentType in (Select ExcludeID from CTE_ExcludeIDs)
			UNION ALL
			-- Defender Updates will be filtered out, because they will be updated more frequently
			-- Other producst can be filtered as well via @ExcludeProductList
            select CIA.AssignmentID, AssignmentType = 1, CIATOCI.CI_ID 
            from v_CIAssignment CIA 
            inner join v_CIAssignmentToCI CIATOCI on CIATOCI.AssignmentID = CIA.AssignmentID 
            inner join v_CICategoryInfo CICI on CICI.Ci_ID = CIATOCI.CI_ID
			inner join CTE_Products PR on PR.Product = CICI.CategoryInstanceName
),
-- list of cumulative updates of the current and the past month
CumulativeUpdates (ArticleID,CI_ID, Latest) as
(
            Select 'KB' + updi.ArticleID as Article, CI_ID, Latest = 0 from v_updateinfo updi where (updi.Title like @LastRollupPrefix + ' Cumulative Update for Windows%' or updi.Title like @LastRollupPrefix + ' Security Monthly Quality Rollup%' or updi.Title like @LastRollupPrefix + ' Cumulative Update for Microsoft server operating system%')
            UNION ALL
            Select 'KB' + updi.ArticleID as Article, CI_ID, Latest = 1 from v_updateinfo updi where (updi.Title like @CurrentRollupPrefix + ' Cumulative Update for Windows%' or updi.Title like @CurrentRollupPrefix + ' Security Monthly Quality Rollup%' or updi.Title like @CurrentRollupPrefix + ' Cumulative Update for Microsoft server operating system%')
)


--MAIN QUERY
select [Name] = VRS.Name0
              ,[ResourceID] = VRS.ResourceID
              ,[Counter] = 1 -- a counter to make it easier to count in reporting services
			  ,[Domain] = VRS.Resource_Domain_OR_Workgr0
              ,[PendingReboot] = BGBL.ClientState                         
              ,[OSType] = GOS.Caption0
			  ,[OSBuild] = BGBL.DeviceOSBuild
              ,[ClientVersion] = VRS.Client_Version0
              ,[WSUSVersion] = USS.LastWUAVersion
              ,[DefenderPattern] = AHS.AntivirusSignatureVersion
              ,[DefenderPatternAge] = AHS.AntivirusSignatureAge
              ,[WSUSScanError] = USS.LastErrorCode
              ,[DaysSinceLastOnline] = ISNULL((DateDiff(DAY,BGBL.LastPolicyRequest,GETDATE())),999)
              ,[DaysSinceLastAADSLogon] = ISNULL((DateDiff(DAY,VRS.Last_Logon_Timestamp0,GETDATE())), 999)
              ,[DaysSinceLastBoot] = ISNULL((DateDiff(DAY,GOS.LastBootUpTime0,GETDATE())), 999)
              ,[DaysSinceLastUpdateInstall] = ISNULL((DateDiff(DAY,UPDINSTDATE.LastInstallTime,GETDATE())), 999)
              ,[MonthSinceLastOnline] = ISNULL((DateDiff(MONTH,BGBL.LastPolicyRequest,GETDATE())), 999)
              ,[MonthSinceLastOnlineABC] = case when ISNULL((DateDiff(MONTH,BGBL.LastPolicyRequest,GETDATE())), 999) = 0 then 'A'
                                                when ISNULL((DateDiff(MONTH,BGBL.LastPolicyRequest,GETDATE())), 999) = 1 then 'B' else 'C' end
              ,[MonthSinceLastAADSLogon] = ISNULL((DateDiff(MONTH,VRS.Last_Logon_Timestamp0,GETDATE())), 999)
              ,[MonthSinceLastAADSLogonABC] = case when ISNULL((DateDiff(MONTH,VRS.Last_Logon_Timestamp0,GETDATE())), 999) = 0 then 'A'
                                        when ISNULL((DateDiff(MONTH,VRS.Last_Logon_Timestamp0,GETDATE())), 999) = 1 then 'B' else 'C' end
              ,[MonthSinceLastBoot] = ISNULL((DateDiff(MONTH,GOS.LastBootUpTime0,GETDATE())), 999)
              ,[MonthSinceLastBootABC] = case when ISNULL((DateDiff(MONTH,GOS.LastBootUpTime0,GETDATE())), 999) = 0 then 'A'
                                        when ISNULL((DateDiff(MONTH,GOS.LastBootUpTime0,GETDATE())), 999) = 1 then 'B' else 'C' end
              ,[MonthSinceLastUpdateInstall] = ISNULL((DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE())), 999)
              ,[MonthSinceLastUpdateInstallABC] = case when ISNULL((DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE())), 999) = 0 then 'A'
                                                 when ISNULL((DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE())), 999) = 1 then 'B' else 'C' end
              ,[MonthSinceLastUpdateScan] = ISNULL((DateDiff(MONTH,USS.LastScanTime,GETDATE())), 999)
              ---- custom compliance state based on deploymentstatus, update status, last installdate and last rollup state. Last update install needs to be at least in the past month
			  ---- 20210801: Changed compliance to contain the last rollup
              ,[OverallComplianceState] = Case when AssignmentStatus.Compliant = AssignmentStatus.AssignmentSum and (DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE()) <= 1+@MonthIndexInternal) and (LASTROLLUPSTAT.Status = 3 or CURRROLLUPSTAT.Status = 3) then 1 else 0 end
			  ---- 20210801: Original UpdateAssignmentCompliance query without last rollup state and with UPDATESTATES.UpdatesApprovedAndMissing = 0
			  ---- Query does not work anymore because of the way we filter future and not enabled update deployments and the changed name to "OverallComplianceState"
			  --,[UpdateAssignmentCompliance] = Case when AssignmentStatus.Compliant = AssignmentStatus.AssignmentSum and UPDATESTATES.UpdatesApprovedAndMissing = 0 and (DateDiff(MONTH,UPDINSTDATE.LastInstallTime,GETDATE()) <= 1) then 1 else 0 end
			  ---- "UpdateStatusCompliant" is now called "UpdateAssignmentCompliant"
              ,[UpdateAssignmentCompliant] = AssignmentStatus.Compliant
              ,[UpdateAssignmentSum] = AssignmentStatus.AssignmentSum
			  ,[UpdateAssignmentNonCompliant] = AssignmentStatus.AssignmentSum - AssignmentStatus.Compliant              
              --,[UpdateStatusNonCompliant] = AssignmentStatus.NonCompliant
              --,[UpdateStatusUnknown] = case when AssignmentStatus.Unknown is null then 999
					--when (AssignmentStatus.Compliant is null  and AssignmentStatus.NonCompliant is null and AssignmentStatus.Failed is null and AssignmentStatus.Pending is null) then 999
					--else AssignmentStatus.Unknown end    ---some are unknown, because the state message seems to be missing
              --,[UpdateStatusFailed] = AssignmentStatus.Failed
              --,[UpdateStatusPending] = AssignmentStatus.Pending
              ,[MissingUpdatesAll] = UPDATESTATES.UpdatesMissingAll
              ,[MissingUpdatesApproved] = UPDATESTATES.UpdatesApprovedAndMissing
              ,[UpdatesApprovedAll] = UPDATESTATES.UpdatesApproved
                                     ,[UpdatesApprovedMissingAndError] = UPDATESTATES.UpdatesApprovedAndMissingAndError
              ---- show status of reference security rollup update
              ---- if current rollup ist installed, the last one doesn't matter and will be set to installed as well
			  ,[LastRollupStatus] = case when LASTROLLUPSTAT.Status = 3 or CURRROLLUPSTAT.Status = 3 then 3 else 2 end
			  ,[CurrentRollupStatus] = case when CURRROLLUPSTAT.Status = 3 then 3 else 2 end
              ---- add a list of all the collections having a software update or all deployments maintenance window
              --,[UpdateMWs]                                                                    = STUFF((select ';' + Description 
              --                         from v_FullCollectionMembership TX0 
              --                         inner join v_ServiceWindow TX1 on TX1.CollectionID = TX0.CollectionID                      
              --                         where TX1.ServiceWindowType in (1,4) and TX0.ResourceID = VRS.ResourceID FOR XML PATH('')), 1, 1, '')
              ---- add a list of all collections with update deployments to see gaps
              ,[UpdateCollections] = STUFF((select '; ' + CIA.CollectionName
                                         from v_FullCollectionMembership FCM
                                         inner join v_CIAssignment CIA on CIA.CollectionID = FCM.CollectionID
                                         where CIA.AssignmentType in (1,5) and FCM.ResourceID = VRS.ResourceID 
                                         group by FCM.ResourceID, CIA.CollectionName FOR XML PATH('')), 1, 1, '')
from v_R_System VRS
inner join ResourceList on ResourceList.ResourceID = VRS.ResourceID
----- Join update states
left join (
           Select ucs.ResourceID
                            ,[UpdatesApproved] = sum(case when AssignedUpdates.CI_ID is not null then 1 else 0 end) 
                            ,[UpdatesApprovedAndMissing] = sum(case when AssignedUpdates.CI_ID is not null and ucs.Status = 2 then 1 else 0 end)
                            ,[UpdatesMissingAll] = sum(case when ucs.Status = 2 then 1 else 0 end)
                            ,[UpdatesApprovedAndMissingAndError] = sum(case when AssignedUpdates.CI_ID is not null and ucs.Status = 2 and (ucs.LastErrorCode is not null and ucs.LastErrorCode !=0) then 1 else 0 end)
              from v_UpdateComplianceStatus ucs
	 		  inner join v_UpdateCIs upd on upd.CI_ID = ucs.CI_ID			  
              inner join ResourceList on ResourceList.ResourceID = ucs.ResourceID
              left join (
							 -- updates deployed to the system
							 select ATM.ResourceID, CATC.CI_ID 
							 from v_CIAssignmentTargetedMachines ATM 
							 inner join v_CIAssignmentToCI CATC on CATC.AssignmentID = ATM.AssignmentID
							 inner join ResourceList on ResourceList.ResourceID = ATM.ResourceID
							 inner join v_CIAssignment CIA on CIA.AssignmentID = CATC.AssignmentID
							 where CIA.AssignmentType in (1,5) -- 1 = updates, 5 = update groups
							 and CIA.AssignmentID not in (Select AssignmentID from ExcludedDeployments) -- Exclude some deployments based on parameter settings
							 group by ATM.ResourceID, CATC.CI_ID
              ) as AssignedUpdates on UCS.ResourceID = AssignedUpdates.ResourceID and AssignedUpdates.CI_ID = UCS.CI_ID
              where upd.IsHidden = 0 and upd.CIType_ID in (1,8) --- 1 = update, 8 = update bundle, 9 = update group
			  and ucs.CI_ID not in (Select CI_ID from ExcludedDeployments) -- exclude Defender and SCEP from statistic
              group by ucs.ResourceID
) UPDATESTATES on UPDATESTATES.ResourceID = VRS.ResourceID
--- join last Rollup as reference
left join (
              select UCS.ResourceID,
              max(UCS.Status) as Status
              from v_UpdateComplianceStatus UCS
              inner join ResourceList on ResourceList.ResourceID = ucs.ResourceID
              inner join CumulativeUpdates CUU on CUU.CI_ID = UCS.CI_ID and CUU.Latest = 0
              group by UCS.ResourceID
) as LASTROLLUPSTAT on LASTROLLUPSTAT.ResourceID = VRS.ResourceID
--- join current Rollup as reference
left join (
              select UCS.ResourceID,
              max(UCS.Status) as Status
              from v_UpdateComplianceStatus UCS
              inner join ResourceList on ResourceList.ResourceID = ucs.ResourceID
              inner join CumulativeUpdates CUU on CUU.CI_ID = UCS.CI_ID and CUU.Latest = 1
              group by UCS.ResourceID
) as CURRROLLUPSTAT on CURRROLLUPSTAT.ResourceID = VRS.ResourceID
--- Join OS Information
left join v_GS_OPERATING_SYSTEM GOS on GOS.ResourceID = VRS.ResourceID
--- Join Client Health status
--left join v_CH_ClientSummary CHCS on CHCS.ResourceID = VRS.ResourceID
--- Join WSUS Client Info
left join v_UpdateScanStatus USS on USS.ResourceID = VRS.ResourceID
--- Join Antimalware Info 
left join v_GS_AntimalwareHealthStatus AHS on AHS.ResourceID = VRS.ResourceID
--- join update compliance status (for overall compliance, failed and pending status)
left join (
              SELECT uas.ResourceID,
                            count(uas.ResourceID) as AssignmentSum,
                            --max(uas.LastComplianceMessageTime) as LastComplianceMessageTime,
                            sum(CASE WHEN (IsCompliant = 1) THEN 1 ELSE 0 END) AS Compliant
                            --sum(CASE WHEN (IsCompliant = 0) THEN 1 ELSE 0 END) AS NonCompliant,
                            --sum(CASE WHEN (IsCompliant is null) THEN 1 ELSE 0 END) AS Unknown, 
                            --sum(CASE WHEN (IsCompliant = 0) AND LastEnforcementMessageID in (6,9) THEN 1 ELSE 0 END) AS Failed, 
                            --sum(CASE WHEN (IsCompliant = 0) AND LastEnforcementMessageID not in (0,6,9) THEN 1 ELSE 0 END) AS Pending
              FROM v_UpdateAssignmentStatus uas
              inner join ResourceList on ResourceList.ResourceID = uas.ResourceID
              where UAS.AssignmentID not in (Select AssignmentID from ExcludedDeployments) -- exclude defender and scep deployments from compliants as well as other deployments if selected
              group by uas.ResourceID
) as AssignmentStatus on AssignmentStatus.ResourceID = VRS.ResourceID
---- join last update installdate for security updates just as a reference to find problematic clients not installing security updates at all
---- need to convert datetime for older OS from 64bit binary to datetime
left join (
              select qfe.ResourceID
                            --- CUU.CI_ID is not null means the current rollup is installed and we can use that installdate as reference
                            ,LastInstallTime = max(CASE WHEN CUU.CI_ID is not null then 
                            (
                                         --- the current rollup is installed, but do we have a valid install date? In some cases the installdate seems to be mising. For some Win10 1803 systems for example.
                                         --- "-05" impossible date, since the update could not be released the 5th day of the month (normally). That should indicate the missing date info and give us enough info about the state of the system
                                         --CASE WHEN qfe.InstalledOn0 = '' THEN @UpdatePrefix + '-05 00:00:00' ELSE TRY_CONVERT(datetime,qfe.InstalledOn0,101) END
										 CASE WHEN qfe.InstalledOn0 = '' THEN @CurrentRollupPrefix + '-05 00:00:00' ELSE TRY_CONVERT(datetime,qfe.InstalledOn0,101) END      
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
              inner join ResourceList on ResourceList.ResourceID = QFE.ResourceID
              left join CumulativeUpdates CUU on CUU.ArticleID = QFE.HotFixID0
              --where (QFE.Description0 = 'Security Update' or QFE.Description0 is null)
              group by qfe.ResourceID
) UPDINSTDATE on UPDINSTDATE.ResourceID = VRS.ResourceID
---- join Pending Reboot Info
--left join BGB_LiveData BGBL on BGBL.ResourceID = VRS.ResourceID ---- <- no direct rights assigned and no other view available, using v_CombinedDeviceResources instead
left join v_CombinedDeviceResources BGBL on BGBL.MachineID = VRS.ResourceID

---- fix for SQL compat level problem 
---- https://support.microsoft.com/en-us/help/3196320/sql-query-times-out-or-console-slow-on-certain-configuration-manager-d
---- Force legacy cardinality for SQL server versions before 2016 SP1 (SQL version less than 13.0.4001.0)
--OPTION (QUERYTRACEON 9481)
---- Force legacy cardinality for SQL server versions 2016 SP1 and higher (SQL version equal or greater than 13.0.4001.0)
--OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'))