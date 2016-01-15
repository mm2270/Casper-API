#!/bin/bash

## Script name: Create-JSS-Policy-Scope-Report.sh
## Author:      Mike Morales
##              E: mm2270@icloud.com
##              JN: https://jamfnation.jamfsoftware.com/viewProfile.html?userID=1927
## Date:        2016-01-15
##
## Description:
##  This script can be used to generate a report on all Policies in your JSS.
##  The report will include a line per policy, along with the policy's JSS ID, the policy name,
##  and various scopes that may be assigned to within the policy, such as "All Computers",
##  individual computers, Computer Groups, Limitations and Exclusions.

## API information, and JSS base URL (leave off trailing slash in JSS URL)
apiUser="apiusername"
apiPass="apipassword"
jssURL="https://jss-server.address.com:8443"    ## Leave off trailing slash for the JSS URL

## Get current logged in user
loggedInUser=$(stat -f%Su /dev/console)

## Get the current time at the start of the script run
startTime=$(date +"%s")

echo -e "Stage 1: Creating directory structure...\n"

## Statements to create the required directory structure
if [[ ! -d "/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT" ]]; then
	mkdir "/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT"
	REPORT_BASE="/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT"
else
	REPORT_BASE="/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT"
fi

if [[ ! -d "/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT/_POLICY_DATA" ]]; then
	mkdir "/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT/_POLICY_DATA"
	POLICY_DATA_BASE="/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT/_POLICY_DATA"
else
	POLICY_DATA_BASE="/Users/${loggedInUser}/Library/Application Support/_JSS_REPORT/_POLICY_DATA"
fi


echo "Stage 2: Getting all JSS policy IDs..."
ALL_POLICY_DATA=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/policies" | xmllint --format - | awk -F'>|<' '/<id>/,/<name>/{print $3}')

ALL_POLICY_IDS=$(echo "$ALL_POLICY_DATA" | awk 'NR % 2')
ALL_POLICY_NAMES=$(echo "$ALL_POLICY_DATA" | awk 'NR % 2 == 0' | sed 's/^/"/g;s/$/"/g')

POLICY_IDS=()
POLICY_NAMES=()

echo -e "Placing all policy names and IDs into arrays...\n"
while read ID; do
	POLICY_IDS+=($ID)
done < <(printf '%s\n' "$ALL_POLICY_IDS")

while read NAME; do
	POLICY_NAMES+=("$NAME")
done < <(printf '%s\n' "$ALL_POLICY_NAMES")

echo "Stage 3: Obtaining scope values from all JSS policies..."
for PID in "${POLICY_IDS[@]}"; do
	echo "Getting data on policy id ${PID}..."
	curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/policies/id/${PID}" | xmllint --format - | awk '/<scope>/,/<\/scope>/{print}' | xmllint --format - > "${POLICY_DATA_BASE}/${PID}.xml"
done < <(printf '%s\n' "{POLICY_IDS[@]}")

function GET_POLICY_DATA ()
{

## 5 variables that scan the policy xml file to generate data for the csv
ALLCOMPS=$(xmllint --xpath /scope/all_computers[1] "${POLICY_DATA_BASE}/${FILE}.xml" | awk -F'>|<' '{print $3}')
COMPS=$(xmllint --xpath /scope/computers[1] "${POLICY_DATA_BASE}/${FILE}.xml" | awk -F'>|<' '/<name>/{print $3}' 2>/dev/null | sed 's/,//g' | sed "s/^/'&/g;s/$/&'/g" | tr '\n' ' ')
COMPGROUPS=$(xmllint --xpath /scope/computer_groups[1] "${POLICY_DATA_BASE}/${FILE}.xml" | awk -F'>|<' '/<name>/{print $3}' 2>/dev/null | sed 's/,//g' | sed "s/^/'&/g;s/$/&'/g" | tr '\n' ' ')
LIMITS=$(xmllint --xpath /scope/limitations[1] "${POLICY_DATA_BASE}/${FILE}.xml" | awk -F'>|<' '/<name>/{print $3}' 2>/dev/null | sed 's/,//g' | sed "s/^/'&/g;s/$/&'/g" | tr '\n' ' ')
EXCLUSIONS=$(xmllint --xpath /scope/exclusions[1] "${POLICY_DATA_BASE}/${FILE}.xml" | awk -F'>|<' '/<name>/{print $3}' 2>/dev/null | sed 's/,//g' | sed "s/^/'&/g;s/$/&'/g" | tr '\n' ' ')

## Generate a full data string, then echo the string into the csv file (appending)
DATA_STRING="${FILE},${POLICY_NAMES[$i]},${ALLCOMPS},${COMPS},${COMPGROUPS},${LIMITS},${EXCLUSIONS}"
echo "$DATA_STRING" >> "${REPORT_BASE}/POLICY_REPORT.csv"

}

echo "Done."
echo -e "Creating initial csv file header...\n"
## Create initial csv file by echoing in the headers
echo "JSS ID,POLICY,ALL COMPUTERS (SCOPE),COMPUTERS (SCOPE),COMPUTER GROUPS (SCOPE),LIMITATIONS (SCOPE),EXCLUSIONS (SCOPE)" > "${REPORT_BASE}/POLICY_REPORT.csv"

echo "Stage 4: Scanning all policy scope details and creating report..."

## While looping over all policy IDs, run the function above to get the relevant data from the corresponding local xml file
i=0;
while read FILE; do
	GET_POLICY_DATA
	
	let i=$((i+1))
done < <(printf '%s\n' "${POLICY_IDS[@]}")

## Final cleanup commands. Remove the _POLICY_DATA folder that contains the data on each JSS policy
echo -e "\nStage 5: Final cleanup. Removing temp files and making final adjustments to the report...\n"
rm -Rfd "${POLICY_DATA_BASE}"

## Clean up the data in the csv, replacing escaped any characters with their actual characters
## Also replace 'false' with 'no' and 'true' with 'yes'
sed -i "" -e 's/\&amp;/\&/g;s/\&quot;/\"/g;s/\&lt;/</g;s/\&gt;/>/g' "${REPORT_BASE}/POLICY_REPORT.csv"
sed -i "" 's/,false,/,No,/g;s/,true,/,Yes,/g' "${REPORT_BASE}/POLICY_REPORT.csv"

## This line removes any policy lines that are likely from Casper Remote sessions, as these are not 'real' policies
sed -i "" '/|.*|/d' "${REPORT_BASE}/POLICY_REPORT.csv"

## Get the current time at the end of the script run
endTime=$(date +"%s")

echo "Run time: $((endTime-startTime)) seconds..."
echo -e "\nReport complete. The final file is located in: ${REPORT_BASE}/ and is named \"POLICY_REPORT.csv\". Opening enclosing directory...\n"

## Open the report base directory, which contains the completed csv file.
sleep 2
open "${REPORT_BASE}"
