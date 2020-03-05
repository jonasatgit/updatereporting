#************************************************************************************************************
# Disclaimer
#
# This sample script is not supported under any Microsoft standard support program or service. This sample
# script is provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties
# including, without limitation, any implied warranties of merchantability or of fitness for a particular
# purpose. The entire risk arising out of the use or performance of this sample script and documentation
# remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation,
# production, or delivery of this script be liable for any damages whatsoever (including, without limitation,
# damages for loss of business profits, business interruption, loss of business information, or other
# pecuniary loss) arising out of the use of or inability to use this sample script or documentation, even
# if Microsoft has been advised of the possibility of such damages.
#************************************************************************************************************

[CmdletBinding()]
param(

    [parameter(Mandatory=$true)]
    [string]$ReportServerUri = "http://reportserver.domain.local/reportserver",

    [parameter(Mandatory=$true)]
    [string]$TargetFolderPath = 'ConfigMgr_P11/Custom_UpdateReporting', # use / instead of \ because it's a website

    [parameter(Mandatory=$true)]
    [string]$TargetDataSourcePath = 'ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}', # use / instead of \ because it's a website

    [parameter(Mandatory=$false)]
    [string]$DefaultCollectionID = 'SMS00001',

    [parameter(Mandatory=$false)]
    [string]$DefaultCollectionFilter = 'All%',

    [parameter(Mandatory=$false)]
    [array]$DoNotHideReports = @('Software Updates Compliance - Overview','Compare Update Compliance','Software Updates Compliance - Offline Scan Results'),

    [parameter(Mandatory=$false)]
    [bool]$Upload = $true,

    [parameter(Mandatory=$false)]
    [bool]$UseViewForDataset = $false,

    [parameter(Mandatory=$false)]
    [string]$ReportSourcePath = $($PSScriptRoot)

)

[string]$datasetUsingSQLView = 'UpdatesSummaryView'

$cleanFolder = "$reportSourcePath\SourceFiles"
$workFolder = "$reportSourcePath\work"

if(-not (Test-Path $cleanFolder))
{
    Write-Host "Folder `"$($cleanFolder)`" not found!"  -ForegroundColor Yellow
    break
}

if(-not (Test-Path $workFolder))
{
    $null = New-Item -ItemType "directory" -Path $workFolder -Force
}
Write-host "Copy `"$($cleanFolder)\*`" to `"$($workFolder)\`"" -ForegroundColor Green
$null = Copy-Item -Path "$($cleanFolder)\*" -Destination "$($workFolder)\" -Force

$reportsToWorkWith = Get-ChildItem -Path "$reportSourcePath\work" | Where-Object {$_.Extension -eq '.rdl' -or $_.Extension -eq '.rsd'}
Write-host "Found $($reportsToWorkWith.Count) .rdl and .rsd files in `"$reportSourcePath\work`"" -ForegroundColor Green
if($reportsToWorkWith.Count -gt 0)
{
    $reportsToWorkWith | ForEach-Object {

        Write-host "Working on: $($_.Name)" -ForegroundColor Green

        $reportContent = ''
        $reportContent = Get-Content -Path $_.FullName
        # simply replacing the neccesary parts
        $reportContent = $reportContent.Replace("<DataSourceReference>/ConfigMgr_P11/{5C6358F2-4BB6-4a1b-A16E-8D96795D8602}</DataSourceReference>","<DataSourceReference>/$($targetDataSourcePath)</DataSourceReference>")
        $reportContent = $reportContent.Replace("<SharedDataSetReference>/ConfigMgr_P11/Custom_UpdateReporting","<SharedDataSetReference>/$($targetFolderPath)")
        $reportContent = $reportContent.Replace("<rd:ReportServerUrl>http://reportserver.domain.local/reportserver</rd:ReportServerUrl>","<rd:ReportServerUrl>$($ReportServerUri)</rd:ReportServerUrl>")
        $reportContent = $reportContent.Replace("<ReportName>/ConfigMgr_P11/Custom_UpdateReporting/","<ReportName>/$($targetFolderPath)/")
        $reportContent = $reportContent.Replace("<Value>COLLECTIONNAMEFILTER</Value>","<Value>$defaultCollectionFilter</Value>")
        $reportContent = $reportContent.Replace('SMS00001',"$($defaultCollectionID)")

        if($UseViewForDataset)
        {
            $reportContent = $reportContent.Replace('UpdatesSummary</SharedDataSetReference>',"$($datasetUsingSQLView)</SharedDataSetReference>")
        }

        # save all the changes to the file
        $reportContent | Out-File -FilePath $($_.FullName) -Encoding utf8 -Force
    }

    if($Upload)
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
                $report = $ReportServerConnection.CreateCatalogItem(
                    $itemType,        # Catalog item type: Report, Model, Dataset, Component, Resource, and DataSource
                    $reportName,      # Name of the item
                    $targetPath,      # Destination folder
                    $false,           # Overwrite report if it exists, not all settings are overwritten, therefore set to false. Delete items manually.
                    $reportBytes,     # Bytes of item
                    $null,            # Item properties
                    [ref]$warnings)   # Warnings during upload
 
                if($warnings.count -gt 0)
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
