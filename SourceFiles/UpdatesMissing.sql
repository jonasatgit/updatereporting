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

--- START just for testing in SQL directly
---- Semicolon seperated list of collectionIDs
Declare @CollectionID as varchar(max) = 'SMS00001' 
---- Semicolon seperated list of update products
Declare @ExcludeProductList as varchar(max) = N'System Center Endpoint Protection;Microsoft Server operating system-21H2;Microsoft Server Operating System-22H2';
---- Parameter to show or hide superseded updates from the report
declare @SupersededVisible as varchar(3) = 'Yes';
---- Parameter to exclude specific products or show all
declare @ExcludeProductsFromQuery as varchar(3) = 'Yes';


 
---------------------------------------
--- SQL Testing END
---------------------------------------
--- Main Reporting query
Declare @CollectionIDList as varchar(max) = @CollectionID ---- semicolon seperated list of collectionIDs
Declare @ExcludeProducts as varchar(max) = @ExcludeProductList ---- semicolon seperated list of update products
Declare @SupersededOption as int

IF @SupersededVisible = 'Yes'
	SET @SupersededOption = 1
Else
	SET @SupersededOption = 0
 
IF @ExcludeProductsFromQuery = 'Yes'
	
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
	,ResourceList (ResourceID) as
	(
				Select Distinct ResourceID from v_FullCollectionMembership FCM
				inner join CTE_CollIDs on CTE_CollIDs.CollectionID = FCM.CollectionID
	)	
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
	)
    ,CTE_ExcludedProductUpdates
    AS
    (
		select ciall.CI_ID
		from v_CICategoryInfo_All as ciall
		inner join CTE_Products products on products.Product = ciall.CategoryInstanceName and ciall.categoryTypeName = 'Product'
    )
              
    select UPD.Title
	,VRS.Netbios_Name0
	,VRS.ResourceID
	,CCI.CategoryInstanceName
	,UCS.CI_ID
	,UPD.IsSuperseded
	,UPD.DatePosted
	,count(UCS.CI_ID) over(partition by UCS.CI_ID) as [SystemsWithSameUpdate]
	from v_UpdateComplianceStatus UCS
	left join v_CITargetedMachines CTM on CTM.CI_ID = UCS.CI_ID and CTM.ResourceID = UCS.ResourceID
	inner join v_CICategoryInfo_All CCI on CCI.CI_ID = UCS.CI_ID and CCI.CategoryTypeName = 'UpdateClassification' and (CCI.CategoryInstanceName = 'Security Updates' or CCI.CategoryInstanceName = 'Critical Updates')
	inner join v_UpdateInfo UPD on UPD.CI_ID = UCS.CI_ID
	inner join v_R_System VRS on VRS.ResourceID = UCS.ResourceID
	inner join ResourceList res on res.ResourceID = UCS.ResourceID
	--where UCS.ResourceID IN (Select ResourceID from v_FullCollectionMembership fcm where fcm.CollectionID IN (@CollectionIDs))
	--where UCS.ResourceID IN (Select ResourceID from v_FullCollectionMembership fcm where fcm.CollectionID IN ('SMS00001'))
	-- Either smaller or equal 1 or 0. One means all updates no matter the supersedence state are visible
	Where UCS.Status = 3 and CTM.ResourceID is null and UPD.IsSuperseded <= @SupersededOption
	and UCS.CI_ID not in (Select CI_ID from CTE_ExcludedProductUpdates)
	order by SystemsWithSameUpdate desc, UPD.Title, UPD.DatePosted
	---- fix for SQL compat level problem
	---- https://support.microsoft.com/en-us/help/3196320/sql-query-times-out-or-console-slow-on-certain-configuration-manager-d
	---- Force legacy cardinality for SQL server versions before 2016 SP1 (SQL version less than 13.0.4001.0)
	--OPTION (QUERYTRACEON 9481)
	---- Force legacy cardinality for SQL server versions 2016 SP1 and higher (SQL version equal or greater than 13.0.4001.0)
	--OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'))
ELSE

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
	,ResourceList (ResourceID) as
	(
				Select Distinct ResourceID from v_FullCollectionMembership FCM
				inner join CTE_CollIDs on CTE_CollIDs.CollectionID = FCM.CollectionID
	)	

	select UPD.Title
	,VRS.Netbios_Name0
	,VRS.ResourceID
	,CCI.CategoryInstanceName
	,UCS.CI_ID
	,UPD.IsSuperseded
	,UPD.DatePosted
	,count(UCS.CI_ID) over(partition by UCS.CI_ID) as [SystemsWithSameUpdate]
	from v_UpdateComplianceStatus UCS
	left join v_CITargetedMachines CTM on CTM.CI_ID = UCS.CI_ID and CTM.ResourceID = UCS.ResourceID
	inner join v_CICategoryInfo_All CCI on CCI.CI_ID = UCS.CI_ID and CCI.CategoryTypeName = 'UpdateClassification' and (CCI.CategoryInstanceName = 'Security Updates' or CCI.CategoryInstanceName = 'Critical Updates')
	inner join v_UpdateInfo UPD on UPD.CI_ID = UCS.CI_ID
	inner join v_R_System VRS on VRS.ResourceID = UCS.ResourceID
	inner join ResourceList res on res.ResourceID = UCS.ResourceID
	-- Either smaller or equal 1 or 0. One means all updates no matter the supersedence state are visible
	Where UCS.Status = 3 and CTM.ResourceID is null and UPD.IsSuperseded <= @SupersededOption -- Either smaller or equal 1 or 0
	order by SystemsWithSameUpdate desc, UPD.Title, UPD.DatePosted
	---- fix for SQL compat level problem
	---- https://support.microsoft.com/en-us/help/3196320/sql-query-times-out-or-console-slow-on-certain-configuration-manager-d
	---- Force legacy cardinality for SQL server versions before 2016 SP1 (SQL version less than 13.0.4001.0)
	--OPTION (QUERYTRACEON 9481)
	---- Force legacy cardinality for SQL server versions 2016 SP1 and higher (SQL version equal or greater than 13.0.4001.0)
	--OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'))