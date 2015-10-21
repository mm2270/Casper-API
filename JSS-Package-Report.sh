#!/bin/bash

## Script name:   JSS-Package-Report.sh
## Author:        Mike Morales (mm2270)
## Last Modified: 2015-Oct-21

## API Username & Password
## Note: API account must have READ access to:
##	• Packages
##	• Policies
##	• Computer Configurations

apiuser="apiusername"
apipass="apipassword"

## JSS URL (Leave off trailing slash)
jssurl="https://your.jss.org:8443"
jssBase=$(echo "$jssurl" | sed 's|https://||;s|:8443||')

function finalizeCSV ()
{

echo -e "Finalizing csv file...\n"

## Use paste to join all data into a final csv file
paste -s -d',' "/tmp/workingDir/Packages_temp" >> "/tmp/Packages.csv"

## Create the line endings in the csv file utilizing the line end markers
sed -i "" -e $'s/,-----,/\\\n/g;s/-----//' "/tmp/Packages.csv"

## Rename the final csv file with the current date and copy to current Desktop
dateString=$(date +"%Y-%m-%d")
mv "/tmp/Packages.csv" "${currentHome}/Desktop/${jssBase}_Packages_${dateString}.csv"

echo "The final csv file has been moved to your Desktop, named \"${jssBase}_Packages_${dateString}.csv\""

}

function getPkgDetails ()
{

echo "${jssurl}/packages.html?id=${pkgID}" >> "/tmp/workingDir/Packages_temp"

echo "Getting package details for ID ${pkgID}..."
#curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/packages/id/${pkgID}" 2>/dev/null | xmllint --format - | awk -F'>|<' '/<package>/,/<\/package>/{print $3}' | sed -e '1d;$d;s/^/"&/g;s/$/&"/g' > "/tmp/workingDir/${pkgID}"
curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/packages/id/${pkgID}" 2>/dev/null | xmllint --format - | awk -F'>|<' '/<package>/,/<\/package>/{print $3}' | sed -e 's/^false$/No/g;s/^true$/Yes/g' | sed -e '1d;$d;s/^/"&/g;s/$/&"/g' >> "/tmp/workingDir/Packages_temp"

PoliciesInUse=()
ConfigsInUse=()

echo -e "Searching all policies and configurations for ID ${pkgID}...\n"
while read PID; do
	if [[ $(awk '/<packages>/,/<\/packages>/{print}' "/tmp/workingDir/Policies/${PID}" | grep "<id>${pkgID}</id>") != "" ]]; then
		PolicyName=$(awk -F'>|<' '/<name>/{print $3; exit}' "/tmp/workingDir/Policies/${PID}" | sed '/|.*|/d')
		if [ "$PolicyName" != "" ]; then
			PoliciesInUse+=("'${PolicyName}' ")
		fi
	fi
done < <(ls "/tmp/workingDir/Policies/")

## Send the PoliciesInUse array results into the Packages_temp file
echo "\"${PoliciesInUse[@]}\"" >> "/tmp/workingDir/Packages_temp"

while read CID; do
	if [[ $(awk '/<packages>/,/<\/packages>/{print}' "/tmp/workingDir/Configs/${CID}" | grep "<id>${pkgID}</id>") != "" ]]; then
		ConfigName=$(awk -F'>|<' '/<name>/{print $3; exit}' "/tmp/workingDir/Configs/${CID}")
		ConfigsInUse+=("'${ConfigName}' ")
	fi
done < <(ls "/tmp/workingDir/Configs/")

## Send the ConfigsInUse array results into the Packages_temp file
echo "\"${ConfigsInUse[@]}\"" >> "/tmp/workingDir/Packages_temp"

## Finalize package section with marker
echo "-----" >> "/tmp/workingDir/Packages_temp"

}


## Start of script

startTime=$(date +"%s")
echo "Script started at: $(date +"%b %d %Y, %H:%M:%S")"

## Get info on logged in user
loggedInUser=$(stat -f%Su /dev/console)
currentHome=$(dscl . read /Users/${loggedInUser} NFSHomeDirectory | awk '{print $NF}')

echo "Obtaining all JSS Package IDs..."
allPackageIDs=$(curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/packages" 2>/dev/null | xmllint --format - | awk -F'>|<' '/<id>/{print $3}' | sort -n)

echo "Obtaining all JSS Policy IDs..."
allPolicyIDs=$(curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/policies" 2>/dev/null | xmllint --format - | awk -F'>|<' '/<id>/{print $3}' | sort -n)

echo "Obtaining all Casper Admin Configuration IDs..."
allConfigIDs=$(curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/computerconfigurations" 2>/dev/null | xmllint --format - | awk -F'>|<' '/<id>/{print $3}' | sort -n)

## Before pulling any files down, create necessary folder structure if not already present
if [ ! -d "/tmp/workingDir/Policies/" ]; then
	echo "Creating working directory structure..."
	mkdir -p "/tmp/workingDir/Policies/"
fi

if [ ! -d "/tmp/workingDir/Configs/" ]; then
	echo "Creating working directory structure..."
	mkdir -p "/tmp/workingDir/Configs/"
fi

## Obtain all policy details
echo "Getting all Policy details for later package comparison (this step may take some time)..."
while read PolicyID; do
	curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/policies/id/${PolicyID}" 2>/dev/null | xmllint --format - | awk '/<policy>/,/<\/packages>/{print}' > "/tmp/workingDir/Policies/${PolicyID}"
	echo "Policy ID ${PolicyID} done..."
done < <(echo "$allPolicyIDs")

## Obtain all Configuration details
echo "Getting all Casper Admin Configuration details for later package comparison..."
while read configID; do
	curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/computerconfigurations/id/${configID}" 2>/dev/null | xmllint --format - | awk '/<general>/,/<\/packages>/{print}' > "/tmp/workingDir/Configs/${configID}"
	echo "Config ID ${configID} done..."
done < <(echo "$allConfigIDs")

echo "All Policy and Configuration details successfully pulled down..."
echo "Getting first package ID value..."
## Get the first ID so we can pull the header strings
firstID=$(echo "$allPackageIDs" | head -1)

echo "Getting header strings for csv..."
headersRaw=$(curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/packages/id/${firstID}" 2>/dev/null | xmllint --format - | awk '/<package>/,/<\/package>/{print}' | sed '/<package>/d;/<\/package>/d' | awk -F'<|>' '{print $2}' | sed 's/\/$//;s/_/ /g')

## Set up the initial array with a 'LINK' header item
headerArr+=("LINK")

## Loop over each header string and uppercase it, enclose it in quotes, then add it to the array
echo "Converting raw header strings into final header strings..."
while read HeadString; do
	StringUpper=$(echo "$HeadString" | awk '{print toupper}' | sed 's/\(.*\)/"\1"/g')
	headerArr+=("${StringUpper}")
done < <(printf '%s\n' "$headersRaw")

## Finalize the header array
headerArr+=("POLICIES" "CONFIGURATIONS" "-----")

echo "Sending final header strings into temp file..."
printf '%s\n' "${headerArr[@]}" > "/tmp/workingDir/Packages_temp"

## Move into cross referencing all packages with policies and configurations
echo "Please wait while we cross reference all packages, policies and configurations..."

## While looping over each package ID we pulled above, run the 'getPkgDetails' function
while read pkgID; do
	getPkgDetails
done < <(echo "$allPackageIDs")

## Run the finalize function
finalizeCSV

echo "Script run complete"
echo "Cleaning up resource files..."
rm -R "/tmp/workingDir"

endTime=$(date +"%s")
timeDiff=$((endTime-startTime))
echo "Script completed at: $(date +"%b %d %Y, %H:%M:%S"), total run time: ${timeDiff} Seconds"
