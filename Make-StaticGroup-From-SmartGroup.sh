#!/bin/bash

## Script name:   Make-StaticGroup-From-SmartGroup.sh
## Author:        Mike Morales
## Last Modified: 2015-Oct-13

## The line below is the only line in this script you should need to edit
## Set your JSS URL below
jssurlBase="https://jss-mac.emc.com/"

#### Do not edit below this line ####

## Pass the API username and password with read and write privileges to Computer Groups to $1 and $2 respectively
apiuser="$1"
apipass="$2"

## Clean the JSS URL to make sure it does not contain a trailing slash
jssurlCleaned=$(echo "$jssurlBase" | sed 's/\/$//')
## Set the full JSS API URL
jssurl="${jssurlCleaned}/JSSResource/computergroups"

## We leave the selected group name blank so the user is asked for one
selectedGroup=""

## If the apiuser and apipass values were present, move forward with getting the group names
if [[ "$apiuser" != "" ]] && [[ "$apipass" != "" ]]; then

	## Since the 'selectedGroup' variable is blank...
	if [ -z "$selectedGroup" ]; then
		## get a list of JSS Computer Groups (filter only for Smart Groups)
		computerGroupList=$(curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}" -X GET 2>/dev/null | xmllint --format - | grep -B1 "<is_smart>true</is_smart>" | awk -F'>|<' '/<name>/{print $3}')

		if [ "$computerGroupList" != "" ]; then

		## If a list was returned, convert the result to an Applescript list
		## Ask for selection from the list
		value=$(/usr/bin/osascript << EOF
set list_contents to do shell script "echo \"$computerGroupList\""
set selectedGroup to paragraphs of list_contents
tell application "System Events"
activate
choose from list selectedGroup with prompt "Choose a Smart Computer Group to create a Static Group from"
end tell
EOF)
		else
			## If the computerGroupList returned was blank, something didn't work
			echo "Failed to pull a computer list. The API credentials supplied may have been incorrect, or do not have the appropriate privileges"
			exit 1
		fi
	fi
else
	## If we didn't get values for the API account, we exit
	echo "Did not receive values for API username and/or password. Please pass these to the script and try again."
	exit 1
fi

## If the value string was returned as 'false' from osascript, it means the user canceled.
if [ "$value" == "false" ]; then
	echo "User exited."
	exit 0
else
	echo "The Smart Computer Group selected was: \"${value}\""
fi

## Get the group JSS ID using the name that was chosen
SmartGroupID=$(curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}" -X GET 2>/dev/null | xmllint --format - | grep -B1 "<name>${value}</name>" | awk -F'>|<' '/<id>/{print $3}')

## Now pull down the entire group contents to a local xml file for processing
curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/id/${SmartGroupID}" -X GET 2>/dev/null | xmllint --format - > "/private/tmp/${SmartGroupID}.xml"

## Get the current group name, and set a new name for the Static Group
GroupName=$(awk -F'>|<' '/<name>/{print $3; exit}' "/private/tmp/${SmartGroupID}.xml")
NewGroupName="${GroupName}_StaticGroup"

echo "The new Static Computer Group name will be: \"${NewGroupName}\""

## Begin setting up a new xml file for the Static Group
echo "<computer_group>
<name>${NewGroupName}</name>
<is_smart>false</is_smart>
<computers>" > "/tmp/${SmartGroupID}_Static.xml"

## Extract the group contents and send into the new xml file
awk '/<computer>/,/<\/computer>/{print}' "/tmp/${SmartGroupID}.xml" >> "/private/tmp/${SmartGroupID}_Static.xml"

## Finalize the new group xml file
echo "</computers>
</computer_group>" >> "/private/tmp/${SmartGroupID}_Static.xml"

## Upload the new group xml file, using id 0 to create a new group
curl -sfku "${apiuser}:${apipass}" "${jssurl}/id/0" -H "Accept: text/xml" -X POST -T "/private/tmp/${SmartGroupID}_Static.xml" 2>&1 > /dev/null

if [ "$?" == "0" ]; then
	echo "Static Computer Group \"${GroupName}_StaticGroup\" was successfully created in your JSS!"
	rm "/private/tmp/${SmartGroupID}_Static.xml"
	exit 0
else
	echo "Creating the Static Computer Group has failed"
	rm "/private/tmp/${SmartGroupID}_Static.xml"
	exit 1
fi
