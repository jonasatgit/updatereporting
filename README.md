# Original blog and documentation:
The original blog and documentation can be found [HERE](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/mastering-configuration-manager-patch-compliance-reporting/ba-p/1415088 "Mastering configuration manager patch compliance reporting")


# Other blogs
All my other blogs can be found [HERE](https://aka.ms/JonasOhmsenBlogs "JonasOhmsenBlogs")
and [HERE](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/mastering-configuration-manager-bandwidth-limitations-for-vpn/ba-p/1280002 "Mastering Configuration Manager Bandwidth limitations for VPN connected Clients")


# MEM/MECM/ConfigMgr patch compliance report solution
![Update dashboard](/.attachments/Dashboard-B.png)
![Simplified report dependencies](/.attachments/UpdateReporting001-level.PNG)


# Changes
(The version number can be found in the lower left corner of the dashboard. No version number means v1.0)

## 2021-11-18 v3.6:
1. Added "Cumulative Update for Microsoft server operating system" string for server 2022 updates

## 2021-07-02 v3.5:
1. Changed the overall compliance state from "all approved and missing updates" + "a security update installation happend within one month" to "All deployments are compliant" + "either the last or the current cumulative update is installed" + "a security update installation happend within one month"
1. Added help text to all report column headers
1. Added Update install errors bar graph to dashboard (below WSUS scan errors)
1. Changed filter for top 10 systems on dashboard to be more accurate
1. Added top 10 update install errors to dashboard
1. Added new report with details about install errors and WSUS scan errors
   1. Contains around 400 common windows update related errors with possible actions on how to fix them
1. Added new parameter to exclude deployments containing Microsoft Defender and System Center Endpoint Protection updates
   1. Was previously part of the SQL query and not easily changeable nor visible to the report user
1. Removed Server 2008 specific parts
1. Added new filter to "per device" report called: "Missing updates with errors" and “All missing updates deployed or not”
1. Added more details about errors to "per device" report
1. Added update collection and maintenance window list to “per device” report
1. Added column: “Earliest Deadline” to “per device” report
1. Changed first sub-report name from “all uncompliant” to “compliance list”
1. Changed default sort order from "count of missing updates" to "month since last update install"
1. Changed "WSUS version" to "OS build version". Easier to determine actual OS version and patch level
1. Changed "Defender Pattern Version" to "Defender Pattern Age" to be able to spot systems with older pattern more easily
1. Added column "WSUS scan error" to system list
1. Added column count of "Updates with install error" to system list
1. Added column number of "Deployments non compliant" to system list
   1. Helps to determine any problems with deployments when all updates are installed, but deployments are still marked as uncompliant
1. Added new report to list all update deployments and their states per device
1. Made "Per device" and “compliance list" report visible to be able to schedule subscriptions without the dashboard
1. Fixed several minor issues with each report
1. Changed SQL query for deployed updates to work better in larger environments
1. Changed import script to also handle SSRS folder path with spaces in it
1. Changed import script to delete existing contents of "work" folder from a previous run
1. Changed import script parameter name "Upload" to "DoNotUpload". Function is the same.
1. Removed import script parameter "UseViewForDataset". (To much work to keep the view consistent with regular query)
1. Added new import script parameters: "ForceLegacyCardinalitySQL2016SP1AndHigher" and "ForceLegacyCardinalityOlderThanSQL2016SP1" Read more about it here

## 2020-12-09 v2.1:
1. Fixed language and QFE problem
1. Added new parameter -ForceLegacyFormat,
1. Fixed minor issues and linked all reports to the per device sub-report

## 2020-11-03 v1.0:
1. Fixed wrong parameter name, updated repository with several fixes
