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
