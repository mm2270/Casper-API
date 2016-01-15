#!/bin/bash

## Script name:	Create-JSS-Computer-Group-Report.sh
## Author:      Mike Morales
##              E: mm2270@icloud.com
##              JN: https://jamfnation.jamfsoftware.com/viewProfile.html?userID=1927
## Date:        2016-01-14
##
## Description:
##    This script can be used to generate a report on all Computer Groups in your JSS.
##    The report will include a line per group, along with the group's JSS ID, the group name,
##    the Smart Group status, any policies which use the group as 'Scope', and any policies
##    that use the group for 'Exclusions'.

## API information, and JSS base URL (leave off trailing slash in JSS URL)
apiUser="apiusername"
apiPass="apipassword"
jssURL="https://your.jss.address:8443"

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

## Make the new directory writable so we don't run into permission errors
chmod -R 777 "$REPORT_BASE"

## Get relevant information on JSS policies
echo -e "Stage 2: Obtaining list of all policy IDs...\n"
ALL_POLICY_IDS=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/policies" | xmllint --format - | grep -v "|.*|" | grep -B1 "<name>" | awk -F'>|<' '/<id>/{print $3}' | sort -n)

## Get the total number of policies
POLICY_COUNT=$(awk 'END {print NR}' <<< "$ALL_POLICY_IDS")

echo "A total of ${POLICY_COUNT} policies will be accessed..."

while read ID; do
	echo "Downloading relevant data on policy id ${ID}..."
	POLICY_DATA=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/policies/id/${ID}" | xmllint --format -)

	POLICY_NAME=$(echo "$POLICY_DATA" | awk -F'>|<' '/<name>/{print $3; exit}')

	mkdir "${POLICY_DATA_BASE}/${ID}"

	echo "$POLICY_NAME" > "${POLICY_DATA_BASE}/${ID}/00_POLICY_NAME"
	echo "$POLICY_DATA" | xpath /policy/scope/computer_groups[1] 2>/dev/null | xmllint --format - | awk -F'>|<' '/<id>/{print $3}' > "${POLICY_DATA_BASE}/${ID}/01_SCOPE"
	echo "$POLICY_DATA" | xpath /policy/scope/exclusions/computer_groups[1] 2>/dev/null | xmllint --format - | awk -F'>|<' '/<id>/{print $3}' > "${POLICY_DATA_BASE}/${ID}/03_EXCLUSIONS"
done < <(printf '%s\n' "$ALL_POLICY_IDS")

echo -e "Finished downloading policy information...\n"

echo -e "Stage 3: Getting all JSS Computer Group information...\n"

## Single API pull for all JSS Computer Group data. This pulls both the JSS IDs and Names
ALL_JSS_GROUPS=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/computergroups" | xmllint --format - | awk -F'>|<' '/<id>/,/<is_smart>/{print $3}')

## Create 3 arrays from the JSS Computer Group IDs pulled via the API.
## One for the group IDs
## One for the group names
## One for the Smart Group status of the groups
while true; do
	read line1 || break
	read line2 || break
	read line3 || break
	ALL_GROUP_IDS+=("$line1")
	ALL_GROUP_NAMES+=("$line2")
	SMART_GROUPS+=("$line3")
done < <(printf '%s\n' "$ALL_JSS_GROUPS")


## Begin section for csv creation

echo -e "Creating initial csv file header...\n"

## Create the initial file with header. Note this command will overwrite any existing file with the same name in the target directory
#echo "JSS ID,GROUP NAME,SMART GROUP?,POLICY SCOPE,POLICY LIMITATIONS,POLICY EXCLUSIONS" > "${REPORT_BASE}/JSS_GROUPS_REPORT.csv"
echo "JSS ID,GROUP NAME,SMART GROUP?,POLICY SCOPES,POLICY EXCLUSIONS" > "${REPORT_BASE}/JSS_GROUPS_REPORT.csv"

## Function to loop over various policy scopes (Scope, Limitations, Exclusions) per JSS Compute Group ID 
function CHECK_POLICY_SCOPES ()
{

## Blank out any previous data string so it can repopulate during the loops
CURRENT_DATA=""

echo "Scanning policy Scopes for group id ${ID}..."

## Start with an empty 'SCOPES' data string
SCOPES=""

## Loop over each directory, locating the '01_SCOPE' file in each and scan for the Computer Group ID
while read DIR; do
	POLICY_NAME="$(cat "${POLICY_DATA_BASE}/${DIR}/00_POLICY_NAME" | sed "s/^/'/;s/$/'/")"

	if [[ $(grep "^${ID}$" "${POLICY_DATA_BASE}/${DIR}/01_SCOPE") ]]; then
		if [ -z "$SCOPES" ]; then
			SCOPES+="\"$POLICY_NAME\" "
		else
			SCOPES+="$POLICY_NAME "
		fi
	else
		SCOPES+=""
	fi
done < <(ls "${POLICY_DATA_BASE}")

## Create current data string from the information found so far, and continue
CURRENT_DATA="${DATA_STRING},${SCOPES}"


echo "Scanning policy Exclusions for group id ${ID}..."

## Start with an empty 'EXCLUSIONS' data string
EXCLUSIONS=""

## Loop over each directory, locating the '03_EXCLUSIONS' file in each and scan for the Computer Group ID
while read DIR; do
	POLICY_NAME="$(cat "${POLICY_DATA_BASE}/${DIR}/00_POLICY_NAME" | sed "s/^/'/;s/$/'/")"

	if [[ $(grep "^${ID}$" "${POLICY_DATA_BASE}/${DIR}/03_EXCLUSIONS") ]]; then
		if [ -z "$EXCLUSIONS" ]; then
			EXCLUSIONS+="\"$POLICY_NAME\" "
		else
			EXCLUSIONS+="$POLICY_NAME "
		fi
	else
		EXCLUSIONS+=""
	fi
done < <(ls "${POLICY_DATA_BASE}")

## Append to current data string from the information found so far, and continue
CURRENT_DATA="${CURRENT_DATA},${EXCLUSIONS}"

## Echo contents of current data string into our csv file
echo "${CURRENT_DATA}" >> "${REPORT_BASE}/JSS_GROUPS_REPORT.csv"

echo ""

}

echo -e "Stage 4: Cross referencing all policies and computer groups...\n"

## Loop over each ID from the ALL_GROUP_IDS array, locate policies using that ID in the function
i=0;
for ID in "${ALL_GROUP_IDS[@]}"; do
	GROUP_NAME="${ALL_GROUP_NAMES[$i]}"
	SMARTSTATUS="${SMART_GROUPS[$i]}"
	DATA_STRING="${ID},${GROUP_NAME},${SMARTSTATUS}"
	echo "Group ID: ${ID}, Group Name: \"${GROUP_NAME}\""
	CHECK_POLICY_SCOPES

	let i=$((i+1))
done

## Make final modifications to the csv file
## Here, we just change the 'TRUE' and 'FALSE' strings under the Smart Group column to 'Yes' and 'No' respectively
sed -i "" 's/,TRUE,/,Yes,/g;s/,FALSE,/,No,/g' "${REPORT_BASE}/JSS_GROUPS_REPORT.csv"

## Final cleanup commands. Remove the _POLICY_DATA folder that contains the data on each JSS policy
rm -Rfd "${POLICY_DATA_BASE}"

## Get the current time at the end of the script run
endTime=$(date +"%s")

echo "Run time: $((endTime-startTime)) seconds..."
echo -e "\nReport complete. The final file is located in: ${REPORT_BASE}/ and is named \"JSS_GROUPS_REPORT.csv\". Opening enclosing directory...\n"

## Open the report base directory, which contains the completed csv file.
sleep 2
open "${REPORT_BASE}"
