# Hi, Jonas here! 
Or as we say in the north of Germany: **"Moin Moin!"**<br>
I am a Microsoft Premier Field Engineer (PFE) based in Hamburg and a while back I was asked to analyze the update compliance status of a customers SCCM (ConfigMgr/MECM) environment.
I used different reports to look for clients not installing the necessary updates, but it was time consuming ans I was missing a general overview with some meanigful KPIs. I ended up with a comprehensive SQL query and an Excel sheet, but changed that to a SQL Server Reporting Services (SSRS) report and made that available to several departments in the organization later on.<br>
As mentioned before, it's been a while since I created the report and if I would start now it would be a PowerBI version or I would simply grab one of the PowerBI reports available right now, but since I still use the report and find it quite helpful, I decided to share that with the rest of the world.

# TL/DR
The following report should help you identify update problems within a specific collection and is designed to work well for a few thousand clients. If you have more then 10k systems, then the query might run long and you might need to improve it or run it not within business hours to show results.<br>
The installation guide for the custom update reporting can be found at the end of this post but you should at least start with the "Some key facts and prerequisites" section.<br>
If you're just looking for the SQL statement behind the report, copy the query from the "UpdatesSummary.rsd" file and use it in SQL directly. 

# Some key facts and prerequisites:
- The report is made to show the update compliance status of members of a collection or multiple collections no matter what type of systems are a member or which or how many updates are deployed to each of the systems.
- If you have a simple group of systems and deploy every needed update with one deployment, the deployment status might be enough, but if you have a more complex setup, you might want to see details based on a specific group of systems no matter if, how or how many updates are deployed to each system.
- The report will also count updates deployed as "available" and is not made to just focus on updates deployed as "required"
- The report consists of multiple KPIs to indicate the update compliance or update/client health state and should give you an overview from different viewpoints to help identify problematic systems or a flaw in your patch strategy. 
- The report will use data from the WMI class Win32_Quickfixengineering which needs to be enabled in the hardware inventory client settings. The class is only used to determine the last installation of A security update to identify systems which seem to be fine, but have never installed anything.
- The report is also using the LastLogonTimeStamp from AD System Discovery to visually show systems which have not logged on to the domain in a while and which might be disposed already and could be deleted from the SCCM database. If you don't use AD system discovery the report will show all systems of the specified collection as not compliant in the pie chart "Last ADDS logon" (12).
  - AD system discovery is no hard requirement to run the report
- The report does not show historical data and will always show the current status. So if you change a deployment in the middle of the month, the compliance percentage will drop almost immediately
- I have defined "compliant" to be a system which has:
   - all the updates installed which are deployed
   - the last security update installation in Win32_Quickfixengineering was in the current month (not neccesarily the monthly security rollup, just one security update)
- The update report has multiple sub-reports to drill further down and each report will use the same dataset
- The SQL query of the dataset is made to filter out Defender Update Deployments, because they normally will be changed every x hours and could interfere with the overall compliance state and should be monitored with other reports. 
- The 2nd Level sub-report per system will also show Defender updates, even if they are filtered out on the dashbaord
- The SQL query might run long in bigger environments (<10.000 clients) depending on SQL performance and SQL maintenance
- There are several sub-reports with the same look and feel, because it was simpler to copy the report and just change the filter for the specific need.
- Each sub-report will be hidden in SSRS to avoid direct usage and keep the folder as clean as possible.
- The reports are made on SSRS 2017. I haven't tested other versions. 

# The report explained:
The main report dashboard looks like this:

PICTURE

I used different KPIs to measure update compliance and the following report combines all that into one dashboard. The main KPI is the first bar and all the others should simply help identify patch problems or flaws in your deployment strategy.  


| Number | Name                    | Description |
|--------|-------------------------|----------------------------------|
| 1      | Filter Collection Name  | A filter to easily find the collections you are looking for. Especially helpful if you have a lot of them. <br> If you don't know the correct name of the collection use the % sign as a wildcard. <br> The filter will filter the result of the "Choose Collections" parameter and reduce the number of collections visible in the drop down list.            |
| 2      | Choose Collections      |  The drop down list will show collections based on the filter you set.<br> You can choose just one collection or multiple ones.<br>If you choose more then one collection, the combined compliance status of all the systems will be shown in the report.<br>The report will always open with a default collection if the filter and the collection is set correctly during setup. Meaning, if the filter is set to "All%" the "All Systems" collection will be used.            |
| 3      |       |             |
| 4      |       |             |
| 5      |       |             |
| 6      |       |             |
| 7      |       |             |
| 8      |       |             |
| 9      |       |             |
| 10     |       |             |
| 11     |       |             |
| 12     |       |             |
| 13     |       |             |




3	Show report	Will run the report with the currently selected collections
4	Update compliance	"Compliant" (green bar) means, all the deployed updates to the systems are installed and at least one security update was installed within the month. The report is using the Win32_QuickfixEngineering class to determine the last installation time. (See also the: "Some key facts and prerequisites" section)Click either on the green bar to get a sub-report which shows a list of compliant systems or the yellow bar to get a list of non compliant systems.
		
5	Updates approved	The green bar will indicate that all the security and critical updates each system need is deployed and could be installed by the system.
		The yellow bar indicates systems which are missing security and critical updates which are currently not deployed to the systems. 
		It could mean that your update group is simply missing some important updates, which should be deployed. You can click on the yellow bar to get a list of the updates missing for the systems in the chosen collection/s.
		
6	Last Rollup Installed	Green means the system has either the last or the current rollup installed. 
		Either the cumulative update or the Security Monthly Quality Rollup like this:
		2020-01 Cumulative Update for Windows%
		2020-01 Security Monthly Quality Rollup%
		
		Yellow means, the system is missing the rollup of the last month.Since Microsoft is releasing updates with a year and date prefix, it is easy to determine the rollup of a given month by just that prefix. Like 2020-01 for the January rollup of 2020.Click either on the green bar to get a sub-report which shows a list of compliant systems or the yellow bar to get a list of non compliant systems.
7	Current Rollup Installed	Green means the system has the current rollup installed. 
		Either the cumulative update or the Security Monthly Quality Rollup like this:
		2020-01 Cumulative Update for Windows%
		2020-01 Security Monthly Quality Rollup%
		
		Yellow means, the system is missing the current rollup.Since Microsoft is releasing updates with a year and date prefix, it is easy to determine the rollup of a given month by just that prefix. Like 2020-01 for the January rollup of 2020.Click either on the green bar to get a sub-report which shows a list of compliant systems or the yellow bar to get a list of non compliant systems.
		
		Keep in mind that the green bar depends on when you open up the report. So if you want to report the compliance for lets say January, but you open up the report the 1st of February, then the current rollup bar will be using February as the current month and should only show yellow.In that case the "Last Rollup Installed" is a good indicator, because it will show the rollup compliance based on January.
		
8	Reboot pending	Green means there is no reboot pending. 
		Yellow means, the system needs a reboot. Since the data is coming from the SCCM client via fast channel and not via hardware inventory or other method, the status should update quite fast. Click on the yellow bar to get to a sub-report of systems in need for a reboot.
		
9	WSUS-Scan Error	Green means there is no problem with the WSUS client scanning for updates. 
		Yellow means, the system reported a WSUS client scan error and the WSUS client should be checked. 
		The WindowsUpdate.log is a good starting point. Click on the yellow bar to get to a sub-report of systems with a wsus client scan error.
		
10	Last Update Installation	The pie chart is using data from Win32_QuickfixEngineering and is divided into three parts. 
		Group A (green) systems were the last security update was installed in the current month. 
		Group B (yellow) systems were the last security update was installed in the last month.Group C (red) systems were the last security update was installed before two or more month.
		
11	Last Reboot	The pie chart is using data from hardware inventory and is divided into three parts. 
		Group A (green) systems were the last reboot was in the current month. 
		Group B (yellow) systems were the last reboot was in the last month. Group C (red) systems were the last reboot was before two or more month
		
12	Last ADDS Login	The pie chart is using data from AD system discovery and is divided into three parts. 
		Group A (green) systems were the last logon in AD was in the current month. 
		Group B (yellow) systems were the last logon in AD was in the last month. Group C (red) systems were the last logon in AD was before two or more month
		
13	Last SCCM Policy request	The pie chart is using data from normal SCCM data and is divided into three parts. 
		Group A (green) systems were the last policy request was in the current month. 
		Group B (yellow) systems were the last policy request was in the last month. Group C (red) systems were the last policy request was before two or more month
		
14	Top 10 systems with missing updates	A list of the top 10 systems with the most missing updates. You might want to check those systems first.
		I also tried the top 10 by month since last security update installation, but that list mostly contained systems which are decommissioned or off for a while, so I changed it to most missing updates.
		


