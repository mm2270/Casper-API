####Casper-API - Casper Suite JSS API scripts and applications  
#####This repository contains specific scripts and standalone applications that utilize the Casper Suite API.  
<br>

[Get-Network-Segments-as-csv.sh](#get-network-segments-as-csvsh)  
[JSS-Package-Report.sh](#jss-package-reportsh)  
[Make-StaticGroup-From-SmartGroup.sh](#make-staticgroup-from-smartgroupsh)  


######Get-Network-Segments-as-csv.sh  
Description:  
This script was designed to run against a Casper Suite 9.x server to pull down the current Network Segments as a csv file.  
To use it, you will need to supply the API credentials within the script. The API account must have at least Read access to the "Network Segments" object in the JSS Objects privileges category.

**Usage:**  
`/path/to/Get-Network-Segments-as-csv.sh`  

The resulting csv file will be named "Network-Segments.csv" and moved to your Desktop when completed.  

**To do:**  
Currently this script does no error checking. If you supply incorrect credentials, or credentials that do not have access to the Network Segments object, it will simply not work. it will not currently report back with an error. A future version will add some error checking and validation.  
<br>
<br>
######JSS-Package-Report.sh
**Description:**  
The JSS-Package-Report.sh script was designed to help with building a spreadsheet of all packages in your JSS, and include information about associations of each package with Policies and Casper Admin Configurations.  

The script works by accessing all policy xml data and all configuration xml data and then does an automated cross referencing of each Package ID from the JSS to those policies and configurations. Along the way it builds a local file that is, at the end, converted into a csv file for viewing in a spreadsheet application.

**Requirements:**  
To utilize this script, the JSS API account must have READ access to the following objects:  
- Packages
- Policies
- Configurations

**What it builds:**  
The final spreadsheet will contain the following column headers:  

<table>
    <tr>
        <td><b>Header</b></td><td><b>Explanation</b></td>
    </tr>
    <tr>
        <td>LINK</td><td>A link to the package in your JSS (Note that because it creates a csv, these are not clickable links)</td>
    </tr>
    <tr>
        <td>ID</td><td>The JSS ID for the package</td>
    </tr>
    <tr>
        <td>NAME</td><td>Equivalent to <b>Display Name</b> in your JSS</td>
    </tr>
    <tr>
        <td>CATEGORY</td><td>The Category the package was added to in Casper Admin or within your JSS</td>
    </tr>
    <tr>
        <td>FILENAME</td><td>The physical file name of the package. Often matches the Display Name, but they can differ</td>
    </tr>
    <tr>
        <td>INFO</td><td>Any Info text entered for the package</td>
    </tr>
    <tr>
        <td>NOTES</td><td>Any Notes text entered for the package</td>
    </tr>
    <tr>
        <td>PRIORITY</td><td>The <b>Priority</b> value assigned to the package. Often used in Casper Imaging configurations</td>
    </tr>
    <tr>
        <td>REBOOT REQUIRED</td><td>(Boolean) Whether the <b>Requires restart</b> option is checked for the package</td>
    </tr>
    <tr>
        <td width="300px">FILL USER TEMPLATE</td><td>(Boolean) Whether the <b>Fill user templates (FUT)</b> option is checked for the package</td>
    </tr>
    <tr>
        <td>FILL EXISTING USERS</td><td>(Boolean) Whether the <b>Fill existing user home directories (FEU)</b> option is checked for the package</td>
    </tr>
    <tr>
        <td>BOOT VOLUME REQUIRED</td><td>(Boolean) Whether the <b>Install on boot drive after imaging</b> option is checked for the package</td>
    </tr>
    <tr>
        <td>ALLOW UNINSTALLED</td><td>(Boolean) Whether the <b>Allow package to be uninstalled</b> option is checked for the package</td>
    </tr>
    <tr>
        <td>OS REQUIREMENTS</td><td>Any values entered into the <b>OS Requirement</b> field</td>
    </tr>
    <tr>
        <td>REQUIRED PROCESSOR</td><td>Indicates if the <b>Install only if architecture type is:</b> box is checked and the value chosen from the drop down menu</td>
    </tr>
    <tr>
        <td>SWITCH WITH PACKAGE</td><td>Displays any value chosen from the <b>Substitute Package</b> drop down menu, or <b>Do Not Install<b> if none were selected</td>
    </tr>
    <tr>
        <td>INSTALL IF REPORTED AVAILABLE</td><td>(Boolean) Whether the <b>Install Only if Available in Software Update</b> option was checked for the package</td>
    </tr>
    <tr>
        <td>REINSTALL OPTION</td><td>Unclear, but may refer to if Autorun was enabled for the package</td>
    </tr>
    <tr>
        <td>TRIGGERING FILES</td><td>Unclear what this option refers to. This will get updated once determined</td>
    </tr>
    <tr>
        <td>SEND NOTIFICATION</td><td>(Boolean) Unclear what this option refers to. This will get updated once determined</td>
    </tr>
    <tr>
        <td>POLICIES</td><td>A list of policy names the package is currently assigned to. Each policy name is surrounded by single quotes</td>
    </tr>
    <tr>
        <td>CONFIGURATIONS</td><td>A list of Casper Admin configuration names the package is currently assigned to. Each configuration name is surrounded by single quotes</td>
    </tr>
</table>

<br>
**Usage:**  
`/path/to/JSS-Package-Report.sh`  

The script will output information in Terminal as it runs, explaining steps and indicating which items it is accessing. The final csv file will be moved to your Desktop and named in the format of:
`your-jss-url_Packages_YYYY-MM-DD.csv`  

**Disclaimer**  
This script should **ONLY** be used for reference purposes and not relied solely on for determining which packages can be safely deleted from your JSS. While the script *should* help you wittle down the package list to examine more closely, and I have made every effort to make the script generate an accurate report, **I cannot gurantee 100% accuracy** due to unknown variations in each JSS it may be run against.  
I am not liable for any packages that are deleted which may have had dependencies, and which may cause these dependencies to fail afterwards. As should always be the case, **use discretion** when deciding which items to remove from your JSS.  
<br>
<br>

######Make-StaticGroup-From-SmartGroup.sh  
Description:  
This script was designed to run against a Casper Suite 9.x server to create a new Static Computer Group from a Smart Computer Group. The resulting Static Group will contain all the same computer members as the Smart Group.  

To use it, you will need to supply API credentials (username & password) to the script by passing these in $1 and $2 respectively. The API account must have both **Read** and **Write** access to the "Computer Groups" object in the JSS Objects privileges category.
When the script is run, assuming correct API credentials are passed to it, an Applescript dialog will present on screen with a list of all existing Smart Computer Groups in your JSS. (Note: only Smart Groups are presented in this dialog to avoid selecting any existing Static Group) Select one from the list and click OK to continue to create the new Static Group. The new group name will use the name of the selected Smart Computer Group as a base wtih **_Static** appended to the end.

**Usage:**  
`/path/to/Make-StaticGroup-From-SmartGroup.sh 'apiuser' 'apipassword'`  

The script will report results in the Terminal window (success or failure)

**To do:**  
Currently this script only does some minor error checking. It will detect if the supplied credentials did not have the correct Read access permissions. It will also detect if the creation of the Static Group failed. A future version will add some additional error checking and validation for the various steps the script needs to work.  

<br>
#####Applications to come (watch this space)  

**Casper-Report-Downloader.app**  
*Synopsis:* Download any saved Advanced Computer Search in your JSS as a csv file without needing to log into your JSS first.

**Self Service Checker.app**  
*Synopsis:* View what Self Service.app would show for any Mac in your JSS. Locate the Macs using several different search methods.
