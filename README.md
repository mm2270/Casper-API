### Casper-API
#####Casper Suite JSS API scripts and applications  
#####This repository contains specific scripts and standalone applications that utilize the Casper Suite API.  

######Get-Network-Segments-as-csv.sh  
Description:  
This script was designed to run against a Casper Suite 9.x server to pull down the current Network Segments as a csv file.  
To use it, you will need to supply the API credentials within the script. The API account must have at least Read access to the "Network Segments" object in the JSS Objects privileges category.

**Usage:**  
`/path/to/Get-Network-Segments-as-csv.sh`  

The resulting csv file will be named "Network-Segments.csv" and moved to your Desktop when completed.  

**To do:**  
Currently this script does no error checking. If you supply incorrect credentials, or credentials that do not have access to the Network Segments object, it will simply not work. it will not currently report back with an error. A future version will add some error checking and validation.  


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
