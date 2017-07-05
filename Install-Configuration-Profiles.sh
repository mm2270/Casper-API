#!/bin/bash

## Script Name:		Install-Configuration-Profiles.sh
## Author:		Mike Morales
## Last Modified:	2017-July-04
## Last Change:		Modified process to obtain Config Profile data. Now gets the profile as xml in one line instead of two.

## Purpose:
## This script will download and install a macOS Configuration Profile(s) that exists in your JSS, using the API

## Special Note: This script is designed to be used on macOS versions 10.10.x and up, when installing a User Level mobileconfig profile.
## It will fail to install User Level profiles on any older OS versions, but will work with System Level profiles.
##
## I have no desire or time to work on making the script able to install User Level profiles on older OSes,
## but feel free to work on it if this is something you should need yourself.

## How it works:
## 1. The supplied API credentials and JSS URL are used to obtain a Config Profile (or multiples) using the JSS ID(s) passed to the script.
## 2. If successful, the profile is curl'ed down. The 'payloads' section is extracted from the data, then converted into proper xml format.
## 3. The xml formed Config Profile is saved into /private/tmp/ as a .mobileconfig, using the JSS ID as the name for the file.
## 4. The PayloadScope is determined from the profile, so it knows if it's User Level or System Level.
## 5. The profiles command is then used to install the Configuration Profile to the local machine, at the appropriate level, if possible.
## 6. Finally, the local .mobileconfig file is removed from /private/tmp/ as part of a cleanup process.

## Begin defined variables ##

## Set the first part of the new UUID string
## (This would typically be something like "com.organization." but can be anything you want. Avoid spaces)
IDStringStart="com.org."

## API User Name (Hardcode here, or leave blank to obtain from $4)
apiUser=""

## API Password (Hardcode here, or leave blank to obtain from $5)
apiPass=""

## JSS URL (Hardcode here, or leave blank to obtain from $6, or from the local machine)
jssURL=""

## Configuration Profile JSS ID (Hardcode here or leave blank to obtain from $7)
ProfileJSSID=""

## Flag to rename the Jamf generated identifier to a human readable identifier, based on the name of the profile
## Can be set to variations of yes, true, no, false. See the case statement below for all possible recognizable strings
renameID=""

## End defined variables ##

## Do not edit below this line ##

## Check for variable assignments
if [[ -z "$apiUser" ]] && [[ ! -z "$4" ]]; then
	apiUser="$4"
elif [[ ! -z "$apiUser" ]]; then
	apiUser="$apiUser"
elif [[ -z "$apiUser" ]] && [[ -z "$4" ]]; then
	echo "Error! The API Username was not passed to the script in parameter 4, or hardcoded into the script. Exiting"
	exit 1
fi


if [[ -z "$apiPass" ]] && [[ ! -z "$5" ]]; then
	apiPass="$5"
elif [[ ! -z "$apiPass" ]]; then
	apiPass="$apiPass"
elif [[ -z "$apiPass" ]] && [[ -z "$5" ]]; then
	echo "Error! The API Password was not passed to the script in parameter 5, or hardcoded into the script. Exiting"
	exit 1
fi


if [[ -z "$jssURL" ]] && [[ ! -z "$6" ]]; then
	jssURL="${6%/}"
elif [[ ! -z "$jssURL" ]]; then
	jssURL="${jssURL%/}"
elif [[ -z "$jssURL" ]] && [[ -z "$6" ]]; then
	## Try to get the JSS URL from the local machine
	jssURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url 2>/dev/null | sed 's|/$||')
	if [ -z "$jssURL" ]; then
		echo "Error! The JSS URL was not entered in the script, passed as parameter 6, or located on this machine. Exiting"
		exit 1
	fi
fi


if [[ -z "$renameID" ]] && [[ ! -z "$8" ]]; then
	renameID="${8}"
elif [[ ! -z "$renameID" ]] && [[ -z "$8" ]]; then
	renameID="$renameID"
elif [[ ! -z "$renameID" ]] && [[ ! -z "$8" ]]; then
	## Parameter 7 was supplied, but the local flag within the script was also filled in.
	## In this case, we override the local script flag with the one supplied in the parameter.
	renameID="${8}"
fi

if [ "$renameID" ]; then
	case "$renameID" in
		Y|y|Yes|yes|YES)
		renameFlag="true"
		;;
		N|n|No|no|NO)
		renameFlag="false"
		;;
		"true"|TRUE|True)
		renameFlag="true"
		;;
		"false"|FALSE|False)
		renameFlag="false"
		;;
		*)
		renameFlag="false"
		echo "The renameID flag was set to an unrecognizable string. Please supply one of the following:
Y/Yes/True to enable, N/No/False to disable"
		;;
	esac
else
	## If no flag was supplied at all, we assume no rename is desired. The Profiles original UUID will be used
	renameFlag="false"
fi


## Function to download and install the Configuration Profile
function download_install_profile ()
{

## Pull the profile down in raw URL encoded format
echo "Obtaining Configuration Profile as xml…"
FormattedProfile=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/osxconfigurationprofiles/id/${ID}" -X GET | xpath '/os_x_configuration_profile/general/payloads/text()' | perl -MHTML::Entities -pe 'decode_entities($_);' | xmllint --format -)

## Obtain the old/original UUID string from the profile xml, store in variable
echo "Obtaining the old ID string from the xml…"
IDStringOld=$(echo "$FormattedProfile" | awk -F'>|<' '/PayloadUUID/{getline; print $3; exit}')

echo "renameFlag was set to: ${renameFlag}…"

if [ "$renameFlag" == "true" ]; then
	## Generate a string based on the DisplayName string from the profile xml
	echo "Obtaining the display name string from the xml…"
	DisplayName=$(echo "$FormattedProfile" | awk -F'>|<' '/PayloadDisplayName/{getline; print $3; exit}' | sed 's/ - /-/g;s/ /-/g')

	## Make a new full UUID string
	echo "Creating a new ID string…"
	IDStringNew=$(echo "${IDStringStart}${DisplayName}" | awk '{print tolower}')

	## Create a new profile and replace the old UUID string with the new one defined above
	echo "Creating final .mobileconfig file…"
	echo "$FormattedProfile" | sed "s/$IDStringOld/$IDStringNew/g" > "/tmp/${ID}.mobileconfig"

	## Set the new Profile name string based on the above obtained information
	profileName="$IDStringNew"
else
	## Create a new profile using the original UUID string within the profile
	echo "Creating final .mobileconfig file…"
	echo "$FormattedProfile" > "/tmp/${ID}.mobileconfig"

	## Set the profile name to the existing ID string
	profileName="$IDStringOld"
fi

## Output the new profile xml (used only for testing purposes. Is left uncommented out here)
# echo "$new_formatted_profile"

## Determine the Payload Scope for the Profile.
## "User" indicates it should be installed as a user level profile. "System" indicates system level profile
scopeLevel=$(awk -F'>|<' '/PayloadScope/{getline; print $3}' "/tmp/${ID}.mobileconfig")

if [ "$scopeLevel" == "User" ]; then
	echo "Profile has a User Level scope"
	## Attempt to install the profile as the current user
	loggedInUser=$(stat -f%Su /dev/console)
	loggedInUID=$(id -u "$loggedInUser")

	echo "Installing Configuration Profile as current user…"
	/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" "/usr/bin/profiles -I -F \"/tmp/${ID}.mobileconfig\""

	## Capture the exit result of the profile install command
	res=$?
elif [ "$scopeLevel" == "System" ]; then
	echo "Profile has a System Level scope"
	## Attempt to install profile as a System level profile (from root)
	echo "Installing Configuration Profile…"
	/usr/bin/profiles -I -F "/tmp/${ID}.mobileconfig"

	## Capture the exit result of the profile install command
	res=$?
elif [ "$scopeLevel" == "" ]; then
	echo "Profile does not have a specific scope. We will install it as a System level profile"
	## Attempt to install profile as a System level profile (from root)
	echo "Installing Configuration Profile…"
	/usr/bin/profiles -I -F "/tmp/${ID}.mobileconfig"

	## Capture the exit result of the profile install command
	res=$?
fi

## Check the result and print out a result to stdout
if [ "$res" == "0" ]; then
	echo "Installation result: Successful"
	echo "Configuration Profile \"${profileName}\" installed. Cleaning up…"
	rm -f "/tmp/${ID}.mobileconfig"
else
	echo "Installation result: Failed"
	echo "Configuration Profile \"${profileName}\" installation failed. Cleaning up…"
	rm -f "/tmp/${ID}.mobileconfig"
fi

}


## This function may get called if more than one JSS Configuration Profile ID was supplied.
## If so, this loop function is called to loop over the values and install any it can download.
function install_multi_profiles ()
{

## Place the values into an array
for i in "$ProfileJSSID"; do
	idArr+=($i)
done

## Loop over the array to run the download_install_profile function for each array index
for i in "${idArr[@]}"; do
	ID="$i"
	download_install_profile
done

}

## First check to make sure we have a profile ID(s) passed to parameter 7, or hardcoded into the script
if [[ -z "$ProfileJSSID" ]] && [[ ! -z "$7" ]]; then
	ProfileJSSID="$7"
elif [[ ! -z "$ProfileJSSID" ]]; then
	ProfileJSSID="$ProfileJSSID"
elif [[ -z "$ProfileJSSID" ]] && [[ -z "$7" ]]; then
	echo "Error! The Configuration Profile ID was not passed to the script in parameter 7, or hardcoded into the script. Exiting"
	exit 1
fi

## Now check to see if the ProfileJSSID string contains multiple items
regex=" | "

if [[ $ProfileJSSID =~ $regex ]]; then
	echo "Multiple IDs passed. Running in loop mode"
	install_multi_profiles
else
	echo "Single ID was passed. Running in single mode"
	ID="$ProfileJSSID"
	download_install_profile
fi
