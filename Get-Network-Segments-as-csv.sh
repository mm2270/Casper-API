#!/bin/bash

## Script name:           Get-Network-Segments-as-csv.sh
## Script author:         Mike Morales
## Last Modification:     2015-Oct-13

## Set the API username, password and JSS URL here
## Note: Leave off the trailing slash in the JSS URL
apiUser="apiusername"
apiPass="apipassword"
jssURL="https://your.casperjss.com:8443"    ## Remember, no trailing slash in this address

## Pull down an xml file of the network segments
curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jssURL}/JSSResource/networksegments" | xmllint --format - > /tmp/nsraw.xml

## Generate a header tags string
allTags=$(cat /tmp/nsraw.xml | xpath /network_segments/network_segment[1] | sed -e '1d;$d;/<id>/d' | awk -F'>|<' '{print $2}' | sed 's/_/ /g')

## Format the headers by looping over each one, and sending into a new bash array
while read item; do
	formattedHeader=$(echo "$item" | sed 's/^n/N/;s/^s/S/;s/^e/E/' | sed 's/address/Address/')
	headerArray+=("${formattedHeader},")
done < <(printf '%s\n' "$allTags")

## Clean up the string of headers
headerString=$(echo "${headerArray[@]}" | sed 's/, /,/g')

## Add headers to initial csv file
echo "$headerString" > /tmp/Network-Segments.csv

## Pull a formatted list of strings from the xml file
awk '/<network_segment>/,/<\/network_segment>/{print}' "/tmp/nsraw.xml" | sed '/<id>/d;s/<\/network_segment>/ /g;/<network_segment>/d' | awk -F'>|<' '{print $3}' | sed 's/^/"&/g;s/$/&"/g' | sed 's/^""$/---/g' > /tmp/nsformatted

## Paste the data contents into the new csv file, creating comma separators between each item
paste -s -d ',' "/tmp/nsformatted" >> "/tmp/Network-Segments.csv"

## Finalize step 1: Change the csv file by converting line ending marks into carriage returns
sed -i "" -e $'s/,---,/\\\n/g;s/---//' "/tmp/Network-Segments.csv"
## Finalize step 2: Change the csv file by converting any xml escaped characters into their proper characters
sed -i "" -e 's/\&amp;/\&/g;s/\&quot;/\"/g;s/\&lt;/</g;s/\&gt;/>/g' "/tmp/Network-Segments.csv"

## Final steps
## Move the final file to the Desktop
mv /tmp/Network-Segments.csv ~/Desktop/

## Delete the temp xml file in /tmp/
rm /private/tmp/nsraw.xml

## Open the final csv file in the default application for csv's
open ~/Desktop/Network-Segments.csv
