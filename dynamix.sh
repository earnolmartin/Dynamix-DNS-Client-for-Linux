#!/bin/bash
# Author Dynamix.run <earnolmartin@gmail.com>

##################
#   Variables    #
##################
AccountKey="{USER_KEY_HERE}" #AccountKey="{USERKEYHERE}"
IgnoredHosts=('') ### For example: IgnoredHosts=('subdomain.domain.com' 'domain.com') # Array of hosts that should be ignored when updating the IP address
LogFile="dynamix.log"

IPServiceURL="https://dynamix.run/ip.php"
CURDATETIME=$(date +"%m-%d-%Y %r")
CURDATETIMEFN=$(date +"%m_%d_%Y_%H_%M_%S")
OldIPFile="oldIP"
debug=false
##################
#    Functions   #
##################
function getHostsListAndProcess(){
	# $1 = http/https url for list of hosts
	# $2 = name file to store them in
	# $3 = name of array to append to
	if [ ! -z "$1" ] && [ ! -z "$2" ]; then
		wget -q -N "$1" -O "$2" --no-check-certificate
	fi
	
	# Process the hosts
	if [ -e "$2" ] && [ ! -z "$3" ]; then
		readarray -t "${3}" < "${2}"
	fi
}

function getExternalIPAddress(){
	IPAddr=$(wget -qO- "$IPServiceURL" --no-check-certificate)
	if [ ! -z "$IPAddr" ]; then
		# If the oldIP file doesn't exist, store the current IP address in there
		if [ ! -e "$OldIPFile" ]; then
			echo "$IPAddr" > "$OldIPFile"
		fi
		
		oldIP=$(cat "$OldIPFile")
		# If the IPAddr doesn't match the old one, it's changed
		if [ "$IPAddr" != "$oldIP" ] || [ "$debug" = true ]; then
			logMessage "IP Address has changed... Running sync scripts!"
			logMessage "IP Address is ${IPAddr} and the old IP Address is ${oldIP}..."
			logMessage "" "true"
			echo "$IPAddr" > "$OldIPFile"
			updateDynamixHosts
		else
			logMessage "IP Address has NOT changed... doing nothing!"
			logMessage "" "true"
		fi
	fi
}

function updateDynamixHosts(){
	getHostsListAndProcess "https://dynamix.run/api/public_api.php?key=${AccountKey}&action=ddns&subaction=getHosts" "my_dynamix_hosts.txt" "dynHosts"
	if [ ! -z "$dynHosts" ]; then
		for dynHost in "${dynHosts[@]}"
		do			
			if ! containsElement "${dynHost}" "${IgnoredHosts[@]}"; then
				echo -e "Updating ${dynHost} to point to IP address of ${IPAddr}..."
				getSubdomainDomain "$dynHost"
				if [ ! -z "$domain" ];	then
					output=$(wget -qO- "https://dynamix.run/api/public_api.php?key=${AccountKey}&action=ddns&subaction=update&subdomain=${subdomain}&domain=${domain}&ip=${IPAddr}" --no-check-certificate)
					if [ "$output" == "1" ]; then
						logMessage "Successfully updated ${dynHost} to point to the IP address of ${IPAddr}..."
					else
						logMessage "Failed to update ${dynHost} to point to the IP address of ${IPAddr}... ${output}"
					fi
				fi
			else
				logMessage "Host ${dynHost} is ignored, so no need to call the Dynamix API... skipping..."
			fi
			logMessage "" "true"
		done
	fi
}

function containsElement(){
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}

function getSubdomainDomain(){
	# $1 is the host
	count=$(echo "$1" | tr -cd '.' | wc -c)
	if [ "$count" == 2 ]; then
		IFS='.' read -ra ADDR <<< "$1"
		subdomain=${ADDR[0]}
		domain="${ADDR[1]}.${ADDR[2]}"
	elif [ "$count" == 1 ]; then
		IFS='.' read -ra ADDR <<< "$1"
		subdomain=
		domain="${ADDR[0]}.${ADDR[1]}"
	else
		subdomain=
		domain=
	fi
	
	if [ "$debug" = true ]; then
		echo "Subdomain is set to ${subdomain} and domain is set to ${domain}..."
	fi
}

function logMessage(){
	logFileSizeKB=$(du -k "$LogFile" | cut -f1)
	if [ "$logFileSizeKB" -ge 20000 ]; then
		mv "$LogFile" "${LogFile}_${CURDATETIMEFN}"
	fi
	
	if [ "$debug" = true ]; then
		echo "Log file size is ${logFileSizeKB} KB..."
	fi
	
	if [ ! -z "$1" ]; then
		echo -e "$1" >> "$LogFile"
		if [ "$debug" = true ]; then
			echo -e "$1"
		fi
	else
		if [ ! -z "$2" ]; then
			echo -e "" >> "$LogFile"
			echo -e ""
		fi
	fi
}

##################
#     Main App   #
##################
logMessage "----------------------------------------------------------------------"
logMessage "Running IP address check on ${CURDATETIME}..." 
logMessage "----------------------------------------------------------------------"
getExternalIPAddress
