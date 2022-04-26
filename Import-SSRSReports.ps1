<#
.SYNOPSIS
Uploads SQL Server Reporting Services report and dataset files.

.DESCRIPTION
The script will change the content of rdl and rsd files and will upload them to a SQL Server Reporting Services (SSRS) of your choice.
The rdl and rsd files contain specific strings which are simply replaced by the parameter values of this script. 

Disclaimer
This sample script is not supported under any Microsoft standard support program or service. This sample
script is provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties
including, without limitation, any implied warranties of merchantability or of fitness for a particular
purpose. The entire risk arising out of the use or performance of this sample script and documentation
remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation,
production, or delivery of this script be liable for any damages whatsoever (including, without limitation,
damages for loss of business profits, business interruption, loss of business information, or other
pecuniary loss) arising out of the use of or inability to use this sample script or documentation, even
if Microsoft has been advised of the possibility of such damages.

.PARAMETER ReportServerURI
The URL of the SQL Reporting Services Server. For example: http://reportserver.domain.local/reportserver

.PARAMETER TargetFolderPath
The folder were the reports should be placed in. I created a folder called "Custom_UpdateReporting" below the default MECM reporting folder. My sitecode is P11, so the default folder is called "ConfigMgr_P11".
For example: "ConfigMgr_P11/Custom_UpdateReporting"
Use "/"" instead of "\"" because it's a website

.PARAMETER TargetDataSourcePath
The path should point to the default ConfigMgr/MECM data source. 
In my case the Sitecode is P11 and the default data source is therefore in the folder "ConfigMgr_P11" and has the ID "{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}"
The path with the default folder is required. For example: "ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}""
Use "/"" instead of "\"" because it's a website

.PARAMETER DefaultCollection
The report can show data of a default collection when it will be run, so that you don't need to provide a collection name each time you run the report. 
The default value is "SMS00001" which is the CollectionID of "All Systems", which might not be the best choice for bigger environments. 

.PARAMETER DefaultCollectionFilter
The filter is used to find the collection you are interested in and the value needs to match the name of the collection you choose to be the default collection for the parameter "defaultCollection". 
In my case "All%" or All Syst% or "Servers%" to get the "Servers of the environment" collection for  example. 

.PARAMETER DoNotHideReports
Array of reports which should not be set to hidden. You should not use the parameter unless you really want more reports to be visible.

.PARAMETER $DoNotUpload
If used each reports will be changed to have the correct values, but will not be uploaded. 
That might be helpful, if you do not have the rights to upload and need to give the files to another person so that they can be uploaded manually

.PARAMETER ReportSourcePath
The script will use the script root path to look for a folder called "Sourcefiles" and will copy all the report files from there. 
 But you could also provide a different path where the script should look for a "Sourcefiles" folder.

.PARAMETER ForceLegacyFormat
The report xml definition will be changed to the older pre SSRS 2016 format. That way the reports also work with SSRS 2014 for example.

.PARAMETER ForceLegacyCardinalitySQL2016SP1AndHigher
Will add SQL query hint "OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'))" to important queries to increase performance. 
Works only with SQL Server 2016 SP1 and higher (SQL version >= 13.0.4001.0)
More infos can be found here: https://support.microsoft.com/en-us/help/3196320/sql-query-times-out-or-console-slow-on-certain-configuration-manager-d

.PARAMETER ForceLegacyCardinalityOlderThanSQL2016SP1
Will add SQL query trace flag "OPTION (QUERYTRACEON 9481)" to important queries to increase performance. 
Works only with older SQL version than SQL Server 2016 SP1 (SQL version < 13.0.4001.0)
More infos can be found here: https://support.microsoft.com/en-us/help/3196320/sql-query-times-out-or-console-slow-on-certain-configuration-manager-d

.PARAMETER TryOverwrite
If set, the script will try to overwrite existing reports. In some cases not all settings are overwritten unfortunately, hence the name TRY-Overwrite

.INPUTS
None. You cannot pipe objects to Import-SSRSReports.ps1

.OUTPUTS
Just normal console output. Nothing to work with. 

.EXAMPLE
PS> .\Import-SSRSReports.ps1 -ReportServerURI "http://reportserver.domain.local/reportserver" -TargetFolderPath  "ConfigMgr_P11/Custom_UpdateReporting" -TargetDataSourcePath "ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}"

.EXAMPLE
PS> .\Import-SSRSReports.ps1 -ReportServerURI "http://reportserver.domain.local/reportserver" -TargetFolderPath  "ConfigMgr_P11/Custom_UpdateReporting" -TargetDataSourcePath "ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}" -TryOverwrite

.EXAMPLE
PS> .\Import-SSRSReports.ps1 -ReportServerURI "http://reportserver.domain.local/reportserver" -TargetFolderPath  "ConfigMgr_P11/Custom_UpdateReporting" -TargetDataSourcePath "ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}" -ForceLegacyFormat -ForceLegacyCardinalitySQL2016SP1AndHigher

.EXAMPLE
PS> .\Import-SSRSReports.ps1 -ReportServerURI "http://reportserver.domain.local/reportserver" -TargetFolderPath  "ConfigMgr_P11/Custom_UpdateReporting" -TargetDataSourcePath "ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}" -DoNotUpload

.EXAMPLE
PS> .\Import-SSRSReports.ps1 -ReportServerURI "http://reportserver.domain.local/reportserver" -TargetFolderPath  "ConfigMgr_P11/Custom_UpdateReporting" -TargetDataSourcePath "ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}" -ForceLegacyCardinalitySQL2016SP1AndHigher

.EXAMPLE
PS> .\Import-SSRSReports.ps1 -ReportServerURI "http://reportserver.domain.local/reportserver" -TargetFolderPath  "ConfigMgr_P11/Custom_UpdateReporting" -TargetDataSourcePath "ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}" -DefaultCollectionID "P1100012" -DefaultCollectionFilter "All Servers of Contoso%" 

.LINK
https://github.com/jonasatgit/updatereporting

.LINK
https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/mastering-configuration-manager-patch-compliance-reporting/ba-p/1415088

#>
[CmdletBinding(DefaultParametersetName='None')]
param(

    [parameter(Mandatory=$true)]
    [string]$ReportServerUri = "http://reportserver.domain.local/reportserver",

    [parameter(Mandatory=$true)]
    [string]$TargetFolderPath = 'ConfigMgr_P11/Custom_UpdateReporting',

    [parameter(Mandatory=$true)]
    [string]$TargetDataSourcePath = 'ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}',

    [parameter(ParameterSetName = 'CollectionInfo',Mandatory=$false)]
    [string]$DefaultCollectionID = 'SMS00001',

    [parameter(ParameterSetName = 'CollectionInfo',Mandatory=$true)]
    [string]$DefaultCollectionFilter = 'All%',

    [parameter(Mandatory=$false)]
    [array]$DoNotHideReports = @('Software Updates Compliance - Overview','Software Updates Compliance - Per device','Software Updates Compliance - Per device deployments','Software Updates Compliance - Overview compliance list','Compare Update Compliance','Software Updates Compliance - Offline Scan Results'),

    [parameter(Mandatory=$false)]
    [Switch]$DoNotUpload,

    #[parameter(Mandatory=$false)]
    #[bool]$UseViewForDataset = $false,

    [parameter(Mandatory=$false)]
    [switch]$ForceLegacyFormat,

    [parameter(Mandatory=$false)]
    [switch]$ForceLegacyCardinalitySQL2016SP1AndHigher,

    [parameter(Mandatory=$false)]
    [switch]$ForceLegacyCardinalityOlderThanSQL2016SP1,

    [parameter(Mandatory=$false)]
    [string]$ReportSourcePath = $($PSScriptRoot),

    [parameter(Mandatory=$false)]
    [switch]$TryOverwrite

)

#[string]$datasetUsingSQLView = 'UpdatesSummaryView'

$cleanFolder = "$reportSourcePath\SourceFiles"
$workFolder = "$reportSourcePath\work"

$overwriteReportItem = $false
if ($TryOverwrite)
{
    $overwriteReportItem = $true
    Write-Host "Will try to overwrite existing reports..." -ForegroundColor Yellow
}

if ($ForceLegacyCardinalityOlderThanSQL2016SP1 -and $ForceLegacyCardinalitySQL2016SP1AndHigher)
{
    Write-Host "Get-Help .\Import-SSRSReports.ps1 -Examples"
    Get-Help .\Import-SSRSReports.ps1 -Examples
    Write-Host " "
    Write-host "Use either ForceLegacyCardinalityOlderThanSQL2016SP1 or ForceLegacyCardinalitySQL2016SP1AndHigher" -ForegroundColor Yellow
    Write-Host "Run `"Get-Help .\Import-SSRSReports.ps1 -Full`" to get help" -ForegroundColor Yellow
    break   
}

# not using validatepattern to genereate nice error messages
if ($ReportServerUri -notmatch '^[a-z0-9\./:\{\}\-_ ]+$')
{
    Write-Host "Get-Help .\Import-SSRSReports.ps1 -Examples"
    Get-Help .\Import-SSRSReports.ps1 -Examples
    Write-Host " "
    Write-host "Parameter `"ReportServerUri`" needs to match regex: '^[a-z0-9\./:\{\}\-_ ]+$'" -ForegroundColor Yellow
    Write-host "Please use slash `"/`" instead of backslash `"\`" for parameter `"ReportServerUri`"" -ForegroundColor Yellow
    Write-Host "Run `"Get-Help .\Import-SSRSReports.ps1 -Full`" to get help" -ForegroundColor Yellow
    break
}


if ($TargetFolderPath -notmatch '^[a-z0-9\./:\{\}\-_ ]+$')
{
    Write-Host "Get-Help .\Import-SSRSReports.ps1 -Examples"
    Get-Help .\Import-SSRSReports.ps1 -Examples
    Write-Host " "
    Write-host "Parameter `"TargetFolderPath`" needs to match regex: '^[a-z0-9\./:\{\}\-_ ]+$'" -ForegroundColor Yellow
    Write-host "Please use slash `"/`" instead of backslash `"\`" for parameter `"TargetFolderPath`"" -ForegroundColor Yellow
    Write-Host "Run `"Get-Help .\Import-SSRSReports.ps1 -Full`" to get help" -ForegroundColor Yellow
    break
}


if ($TargetDataSourcePath -notmatch '^[a-z0-9\./:\{\}\-_ ]+$')
{
    Write-Host "Get-Help .\Import-SSRSReports.ps1 -Examples"
    Get-Help .\Import-SSRSReports.ps1 -Examples
    Write-Host " "
    Write-host "Parameter `"TargetDataSourcePath`" needs to match regex: '^[a-z0-9\./:\{\}\-_ ]+$'" -ForegroundColor Yellow
    Write-host "Please use slash `"/`" instead of backslash `"\`" for parameter `"TargetDataSourcePath`"" -ForegroundColor Yellow
    Write-Host "Run `"Get-Help .\Import-SSRSReports.ps1 -Full`" to get help" -ForegroundColor Yellow
    break
}


if ($DefaultCollectionFilter -match '&')
{
    Write-Host "Get-Help .\Import-SSRSReports.ps1 -Examples"
    Get-Help .\Import-SSRSReports.ps1 -Examples
    Write-Host " "
    Write-host "Parameter `"DefaultCollectionFilter`" should not contain the ampersand sign `"&`"" -ForegroundColor Yellow
    Write-Host "Run `"Get-Help .\Import-SSRSReports.ps1 -Full`" to get help" -ForegroundColor Yellow
    break    
}


if (-not (Test-Path $cleanFolder))
{
    Write-Host "Folder `"$($cleanFolder)`" not found!"  -ForegroundColor Yellow
    break
}

if (-not (Test-Path $workFolder))
{
    $null = New-Item -ItemType "directory" -Path $workFolder -Force
}
else
{
    Get-ChildItem $workFolder | Remove-Item -Force
}
Write-host "Copy `"$($cleanFolder)\*`" to `"$($workFolder)\`"" -ForegroundColor Green
$null = Copy-Item -Path "$($cleanFolder)\*" -Destination "$($workFolder)\" -Force

[array]$reportsToWorkWith = Get-ChildItem -Path "$workFolder" | Where-Object {$_.Extension -eq '.rdl' -or $_.Extension -eq '.rsd'}
Write-host "Found $($reportsToWorkWith.Count) .rdl and .rsd files in `"$reportSourcePath\work`"" -ForegroundColor Green
if ($reportsToWorkWith.Count -gt 0)
{
    if ($ForceLegacyFormat)
    {
        Write-Host "Changing xml format to work with pre 2016 SSRS versions" -ForegroundColor Yellow
    }

    if ($ForceLegacyCardinalitySQL2016SP1AndHigher)
    {
        Write-Host "Will add SQL query hint: `"OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'))`" to larger queries" -ForegroundColor Yellow
    }

    if ($ForceLegacyCardinalityOlderThanSQL2016SP1)
    {
        Write-Host "Will add SQL query trace flag `"OPTION (QUERYTRACEON 9481)`" to larger queries" -ForegroundColor Yellow
    }

    $reportsToWorkWith | ForEach-Object {

        Write-host "Working on: $($_.Name)" -ForegroundColor Green

        $reportContent = ''
        $reportContent = Get-Content -Path $_.FullName
        # simply replacing the neccesary parts
        $reportContent = $reportContent.Replace("<DataSourceReference>/ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}</DataSourceReference>","<DataSourceReference>/$($targetDataSourcePath)</DataSourceReference>")
        $reportContent = $reportContent.Replace("<SharedDataSetReference>/ConfigMgr_P11/Custom_UpdateReporting","<SharedDataSetReference>/$($targetFolderPath)")
        $reportContent = $reportContent.Replace("http://reportserver.domain.local/reportserver","$($ReportServerUri)") # case sensitive
        $reportContent = $reportContent.Replace("http://reportserver.domain.local/ReportServer","$($ReportServerUri)") # case sensitive
        $reportContent = $reportContent.Replace("<ReportName>/ConfigMgr_P11/Custom_UpdateReporting/","<ReportName>/$($targetFolderPath)/")
        $reportContent = $reportContent.Replace("<Value>All%</Value>","<Value>$defaultCollectionFilter</Value>")
        $reportContent = $reportContent.Replace('SMS00001',"$($defaultCollectionID)")

        if ($ForceLegacyCardinalitySQL2016SP1AndHigher) # uncomment SQL hint
        {
            $reportContent = $reportContent.Replace('--OPTION (USE HINT','OPTION (USE HINT')
        }

        if ($ForceLegacyCardinalityOlderThanSQL2016SP1)
        {
            $reportContent = $reportContent.Replace('--OPTION (QUERYTRACEON 9481)','OPTION (QUERYTRACEON 9481)')
        }


       <#
        if ($UseViewForDataset)
        {
            $reportContent = $reportContent.Replace('UpdatesSummary</SharedDataSetReference>',"$($datasetUsingSQLView)</SharedDataSetReference>")
        }
        #>

        if ($ForceLegacyFormat)
        {
            # Changing xml format to work with pre 2016 SSRS versions
            [xml]$ContentXML=$reportContent
            if ($ContentXML.report.xmlns -eq "http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition")
            {
                $ContentXML.report.xmlns = "http://schemas.microsoft.com/sqlserver/reporting/2010/01/reportdefinition"
                $ContentXML.report.SetAttribute("cl","http://schemas.microsoft.com/sqlserver/reporting/2010/01/componentdefinition")
            }
            if ($ContentXML.report.ReportParameterslayout -ne $NULL)
            {
                [void]$ContentXML.Report.RemoveChild($ContentXML.report.ReportParameterslayout)
            }
            $ContentXML.Save($_.FullName)
        }
        else
        {
            # save all the changes to the file
            $reportContent | Out-File -FilePath $($_.FullName) -Encoding utf8 -Force
        }
    }

    if (-NOT ($DoNotUpload))
    {
        Write-host "Connecting to: $ReportServerUri..." -ForegroundColor Green

        $ReportServerUriFull = "$ReportServerUri/ReportService2010.asmx?wsdl"
        $ReportServerConnection = New-WebServiceProxy -Uri $ReportServerUriFull -Namespace "SSRS" -UseDefaultCredential;
        if($ReportServerConnection)
        {
            Write-host "Connected to: $ReportServerUri" -ForegroundColor Green

            # import datasets first to make them available to reports          
            $reportsToWorkWith | Sort-Object Extension -Descending | ForEach-Object {
                Write-host "Uploading: $($_.Name)..." -ForegroundColor Green
            
                $reportName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                $reportBytes = [System.IO.File]::ReadAllBytes($_.FullName)
            
                $targetPath = "/$targetFolderPath"
            
                if($_.Extension -eq '.rsd')
                {
                    $itemType = "DataSet"
                }
                else
                {
                    $itemType = "Report"
                }
                $warnings = $null
                $null = $ReportServerConnection.CreateCatalogItem(
                    $itemType,        # Catalog item type: Report, Model, Dataset, Component, Resource, and DataSource
                    $reportName,      # Name of the item
                    $targetPath,      # Destination folder
                    $overwriteReportItem, # Overwrite report if it exists, not all settings are overwritten, therefore set to false. Delete items manually or use TryOverwrite parameter
                    $reportBytes,     # Bytes of item
                    $null,            # Item properties
                    [ref]$warnings)   # Warnings during upload

                if(-NOT($warnings -eq $null))
                {
                    $warnings | ForEach-Object {
                        Write-Host "Warning: $($_.Message)" -ForegroundColor Yellow
                    }
                }

                # hide all reports exept for reports found in $doNotHideReports
                if($doNotHideReports -notcontains $reportName)
                {
                    $Properties = $ReportServerConnection.GetProperties("$targetPath/$reportName",$tmp)
                    $prop = $Properties | Where-Object {$_.Name -eq 'Hidden'}
                    $prop.Value = $true
                    $ReportServerConnection.SetProperties("$targetPath/$reportName",$prop)
                }
            }
        
        }
        else
        {
            Write-host "Problem with connection..." -ForegroundColor Yellow
        }
    }
    else
    {
        Write-host "Parameter is set to NOT upload any reports to: $ReportServerUri" -ForegroundColor Yellow
    }
}
Write-host "End of script!" -ForegroundColor Green
