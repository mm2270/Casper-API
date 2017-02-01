#!/bin/bash

## Script name: convert-sg-search-search-sg.sh
## Author:      Mike Morales

## Convert an existing Smart Group into Advanced Computer Search or an existing Advanced Computer Search into a Smart Group in your JSS

## Values for API account information and JSS URL
## Notes:
## • The API User MUST have these privileges to be used effectively:
##  - READ Smart Computer Groups
##  - READ Advanced Computer Searches
##  - CREATE Smart Computer Groups
##  - CREATE Advanced Computer Searches
## • These can be hardcoded. If any are left null, the script will prompt you to enter them interactively
## • You may hardcode only certain variables, for example only the username and JSS URL, and the script will prompt interactively for the password
## • If all left null, the script will prompt to enter each item one by one

apiUser=""
apiPass=""
jssURL=""

## Script starts here
echo "$(date) - Starting script: ${0}
"

## This function will prompt at the cli for a JSS URL.
## Determines the default URL if the Mac its being run on is managed.
function askForjssURL ()
{

if [ -z "$jssURL" ]; then
	## Try to get the JSS URL from the Mac
	if [ -e "/Library/Preferences/com.jamfsoftware.jamf.plist" ]; then
		jssURL=$(defaults read "/Library/Preferences/com.jamfsoftware.jamf.plist" jss_url | sed 's/\/$//')

		echo "
Use this URL?: ${jssURL}

• Yes - Use the URL presented above
• No - you will be prompted to enter the JSS URL
• Exit - Exits the script (you will need to supply the JSS URL in this script)

[y]	Yes
[n]	No
[x]	Exit"

		read urlResponse

		case "$urlResponse" in
			y|Y)
			jssURL="$jssURL"
			echo "JSS URL captured"
			;;
			n|N)
			echo "Enter the JSS URL:"
			read newURLResponse
			jssURL="$newURLResponse"
			;;
			x|X)
			echo "Exiting. Goodbye!"
			exit 0
			;;
			*)
			echo "Invalid response! Please try again"
			askForjssURL
			;;
		esac
	fi
fi

## Format the captured variable for the curl commands
jssURL=$(echo "$jssURL" | sed 's/\/$//')

}

## This function prompts at the cli for the API Password, if none is provided within the script
function askForAPIPass ()
{

if [ -z "$apiPass" ]; then
	echo "
No API Password has been supplied. Enter it now?

• Yes - you will be able to type in the password (not shown in the output)
• No/Exit - you will need to supply the APi Password in the script itself

[y]	Yes
[n]	No/Exit"

	read apiPResponse

	case "$apiPResponse" in
		y|Y)
		echo "API Password:"
		read -s apiPassword
		apiPass="$apiPassword"
		echo "Password captured"
		;;
		n|N)
		echo "Exiting. Goodbye!"
		exit 0
		;;
		*)
		echo "Invalid response! Please try again"
		askForAPIPass
		;;
	esac
else
	apiPass="$apiPass"
fi

## Move on to obtaining the JSS URL
askForjssURL

}

## This function prompts at the cli for the API Username, if none is provided within the script
function askForAPIUser ()
{

if [ -z "$apiUser" ]; then
	echo "No API Username has been supplied. Enter it now?

• Yes - you will be able to type in the Username
• No/Exit - you will need to supply the API Username in the script itself

[y]	Yes
[n]	No/Exit"
	
	read apiUResponse

	case "$apiUResponse" in
		y|Y)
		echo "API Username:"
		read apiUserName
		apiUser="$apiUserName"
		echo "Username captured"
		;;
		n|N)
		echo "Exiting. Goodbye!"
		exit 0
		;;
		*)
		echo "Invalid response! Please try again"
		askForAPIUser
		;;
	esac
else
	apiUser="$apiUser"
fi

## Move on to checking for the API Password
askForAPIPass

}


## This function converts a Smart Group selection into a corresponding saved Advanced Computer Search
function SGtoAS ()
{

## Build 2 lists from the API. One for Smart Group names. The other for their respective IDs
SGList=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/computergroups" | xmllint --format - | grep -B2 "<is_smart>true</is_smart>" | awk -F'>|<' '/<name>/{print $3}')
SGIDs=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/computergroups" | xmllint --format - | grep -B2 "<is_smart>true</is_smart>" | awk -F'>|<' '/<id>/{print $3}')

## Set up array for Smart Group names
while read GroupName; do
	SGListArray+=("$GroupName")
done < <(printf '%s\n' "$SGList")

## Set up array for Smart Group IDs
while read GroupID; do
	SGIDsArray+=("$GroupID")
done < <(printf '%s\n' "$SGIDs")

## Print out Smart Group names with index labels
for i in "${!SGListArray[@]}"; do 
  printf "%s\t%s\n" "[$i]" "${SGListArray[$i]}"
done

echo "
Choose the Smart Group from the list by typing in the index number in the brackets to the left of its name"

read SGChoice

echo "Smart Group chosen:	${SGListArray[$SGChoice]}"
echo "Smart Group ID:		${SGIDsArray[$SGChoice]}"

## Assign Smart Group ID to variable
SGID="${SGIDsArray[$SGChoice]}"

echo "
Gathering Smart Group information"

## Obtain the Smart Group xml header info and store into a local file
curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/computergroups/id/${SGID}" | xmllint --format - | awk '/<computer_group>/,/<\/criteria>/{print}' > "/tmp/${SGID}_SG.xml"

SGName=$(awk -F'>|<' '/<name>/{print $3; exit}' "/tmp/${SGID}_SG.xml")
SGCriteria=$(awk '/<criteria>/,/<\/criteria>/{print}' "/tmp/${SGID}_SG.xml")

echo "New Advanced Search will be named \"${SGName} [Converted]\""

echo "
Starting creation of new Saved Advanced Search. Please wait..."

## Form start of new Advanced Search xml
echo "<advanced_computer_search>
<id>0</id>
<name>${SGName} [Converted]</name>
<type>Computers</type>
<view_as>Standard Web Page</view_as>" > "/tmp/${SGID}_AS.xml"

echo "Adding criteria..."

## Add criteria obtained from Smart Group
echo "${SGCriteria}" >> "/tmp/${SGID}_AS.xml"

echo "Finishing xml file..."

echo "<display_fields>
<display_field>
<name>Computer Name</name>
</display_field>
</display_fields>
</advanced_computer_search>" >> "/tmp/${SGID}_AS.xml"

## Test the new xml file to be sure its properly formed
XMLTest=$(xmllint "/tmp/${SGID}_AS.xml" 2> /dev/null 1> /dev/null; echo $?)

if [ "$XMLTest" == "0" ]; then
	echo "XML creation successful"
else
	echo "XML creation failed. Error code was $XMLTest"
	exit 1
fi

echo "Creating new Saved Advanced Search in the JSS. Please wait..."

newID=$(curl -sku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/advancedcomputersearches/id/0" -X POST -T "/tmp/${SGID}_AS.xml" 2>&1 | xmllint --format - | awk -F'>|<' '/<id>/{print $3}')

result=$?

if [ "$result" == 0 ]; then
	echo -e "\nNew Advanced Computer Search \"${SGName} [Converted]\" was successfully created with ID ${newID}"
else
	echo -e "\nFailed to create new Advanced Computer Search. Exit code was ${result}"
fi

echo -e "\nCleaning up and exiting"
rm -f "/tmp/${SGID}_SG.xml" 2>/dev/null
rm -f "/tmp/${SGID}_AS.xml" 2>/dev/null
exit

}

## This function converts a saved Advanced Computer Search to a computer Smart Group
function AStoSG ()
{

## Build 2 lists from the API. One for Advanced Computer Search names. The other for their respective IDs
ASList=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/advancedcomputersearches" | xmllint --format - | awk -F'>|<' '/<name>/{print $3}')
ASIDs=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/advancedcomputersearches" | xmllint --format - | awk -F'>|<' '/<id>/{print $3}')

## Set up array for Advanced Computer Search names
while read SearchName; do
	ASListArray+=("$SearchName")
done < <(printf '%s\n' "$ASList")

## Set up array for Advanced Computer Search IDs
while read SearchID; do
	ASIDsArray+=("$SearchID")
done < <(printf '%s\n' "$ASIDs")

## Print out Advanced Computer Search names with index labels
for i in "${!ASListArray[@]}"; do 
  printf "%s\t%s\n" "[$i]" "${ASListArray[$i]}"
done

echo "
Choose the Advanced Computer Search from the list by typing in the index number in the brackets to the left of its name"

## Read the user selection
read ASChoice

## Print out user selection (name + ID)
echo "Smart Group chosen:	${ASListArray[$ASChoice]}"
echo "Smart Group ID:		${ASIDsArray[$ASChoice]}"

## Assign Smart Group ID to variable
ASID="${ASIDsArray[$ASChoice]}"

echo "Gathering Advanced Computer Search information. Please be patient. This may take a moment..."

## Obtain the Advanced Computer Search xml header info and store into a local file
curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/advancedcomputersearches/id/${ASID}" | xmllint --format - | awk '/<advanced_computer_search>/,/<\/criteria>/{print}' > "/tmp/${ASID}_AS.xml"

## Create variables for the Advanced Search name and the criteria section
ASName=$(awk -F'>|<' '/<name>/{print $3; exit}' "/tmp/${ASID}_AS.xml")
ASCriteria=$(awk '/<criteria>/,/<\/criteria>/{print}' "/tmp/${ASID}_AS.xml")

echo "New Smart Group will be named \"${ASName} [Converted]\""

echo "
Starting creation of new Smart Group. Please wait..."

## Start Smart Group creation
echo "<computer_group>
<id>0</id>
<name>${ASName} [Converted]</name>
<is_smart>true</is_smart>" > "/tmp/${ASID}_SG.xml"

echo "Adding criteria..."

## Add criteria obtained from Advanced Computer Search
echo "${ASCriteria}" >> "/tmp/${ASID}_SG.xml"

echo "Finishing xml file..."
echo "</computer_group>" >> "/tmp/${ASID}_SG.xml"

## Test the new xml file to be sure its properly formed
XMLTest=$(xmllint "/tmp/${ASID}_SG.xml" 2> /dev/null 1> /dev/null; echo $?)

if [ "$XMLTest" == "0" ]; then
	echo "XML creation successful"
else
	echo "XML creation failed. Error code was $XMLTest"
	exit 1
fi

echo "Creating new Smart Group in the JSS. Please wait..."

newID=$(curl -sku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/computergroups/id/0" -X POST -T "/tmp/${ASID}_SG.xml" 2>&1 | xmllint --format - | awk -F'>|<' '/<id>/{print $3}')

result=$?

if [ "$result" == 0 ]; then
	echo -e "\nNew Smart Group \"${ASName} [Converted]\" was successfully created with ID ${newID}"
else
	echo -e "\nFailed to create new Smart Group. Exit code was ${result}"
fi

echo -e "\nCleaning up and exiting"
rm -f "/tmp/${ASID}_AS.xml" 2>/dev/null
rm -f "/tmp/${ASID}_SG.xml" 2>/dev/null

exit

}


## This function prompts for the type of conversion to perform - Smart Group to Search or Search to Smart Group
function askForConversionType ()
{

echo "
Choose the type of conversion to perform:
[1]	Smart Group to Advanced Search
[2]	Advanced Search to Smart Group
[x]	Exit"

read convChoice

case "$convChoice" in
	"1")
	echo "Converting from Smart Group to Advanced Search"
	SGtoAS
	;;
	"2")
	echo "Converting from Advanced Search to Smart Group"
	AStoSG
	;;
	"x|X")
	echo "Goodbye!"
	exit 0
	;;
	*)
	echo "Invalid response! Please try again"
	askForConversionType
	;;
esac

}

## Run function to begin checking on API credentials
askForAPIUser

## Run function to ask for conversion type
askForConversionType
