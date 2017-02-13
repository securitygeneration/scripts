#!/bin/bash
# ssh_authenum.sh
# Test list of hosts/IPs for supported SSH authentication types
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release with time-out checks
#
# TODO: Regex IP/hostnames; Read from stdin?
#
# You can use the following nmap scan to get a quick list of 
# all SSH hosts in your target scope:
# sudo nmap -sS -T4 -Pn -n -p 22 -iL <scope_file.txt> --open | grep "scan report for"|awk '{print $5}' > ssh_targets.txt
# -------------------------------------------------------------

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\e[32m'
NC='\033[0m' # No Color

# Stats variables
ctunusual=0
ctfound=0
ctconn=0
cttimeout=0
ctunresolved=0
ctrefused=0
ctpassword=0
ctkeyboardinteractive=0
total=0

if [ -z "$1" ]; then

	echo "Usage:"
	echo "     ./ssh_auth.sh <inputfile> (one host per line)"
	echo "     Assumes SSH is running on TCP/22 unless host:port is supplied"

else

	echo "----- Starting scan $(date) -----"

	while IFS= read -r HOST	
	do
		result=""
		methods=""
		port="22"
		let "total += 1"
		#Debug
		#echo "Testing host: $HOST"

		# Handle hostname: formats
		if [[ $HOST == *":"* ]]; then
			port="$(echo "$HOST"|cut -d: -f2)"
			HOST=$(echo "$HOST"|cut -d: -f1)
		fi

		result=$(ssh -T -o PreferredAuthentications=none -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p "$port" "$HOST" 2> >(cat))
		# Debug
		#echo "Result is $result"

		HOSTPORT="$HOST:$port"

		methods=$(echo "$result"|grep 'denied'|tr -d '().'|cut -d ' ' -f3)
		# Debug
		#echo "methods is $methods"

		if [[ $result == *"timed out"* ]]; then
			echo -e "${RED}Host $HOSTPORT connection timed out${NC}"
			let "cttimeout += 1"
		elif [[ $result == *"Could not resolve"* ]]; then
			echo -e "${RED}Host $HOST could not be resolved${NC}"
			let "ctunresolved += 1"
		elif [[ $result == *"Connection refused"* ]]; then
			echo -e "${RED}Host $HOSTPORT connection refused${NC}"
			let "ctrefused += 1"
		elif [ -n "$methods" ]; then
			echo -e "${GREEN}Host $HOSTPORT supports $methods${NC}"
			if [[ $methods == *"password"* ]]; then
				pwhosts="$pwhosts$HOST\n"
				let "ctpassword += 1"
			fi
			if [[ $methods == *"keyboard-interactive"* ]]; then
				kihosts="$kihosts$HOST\n"
				let "ctkeyboardinteractive += 1"
			fi
			let "ctfound += 1"
			let "ctconn += 1"
		else
			echo -e "${YELLOW}Host $HOSTPORT returned unusual response, check!${NC}"
			let "ctunusual += 1"
			let "ctconn += 1"
		fi
	done < "$1" 

	printf "\n----- Stats -----\nTotal hosts scanned: $total\nTotal connections: $ctconn\nSSH hosts found: $ctfound\nUnusual responses: $ctunusual\nConnections refused: $ctrefused\nTimed out: $cttimeout\nUnresolved: $ctunresolved\n"

	if [ "$pwhosts" ]; then
		printf "\nSSH hosts that support password authentication ($ctpassword/$ctfound):\n${RED}$pwhosts${NC}"
	fi

	if [ "$kihosts" ]; then
		printf "\nSSH hosts that support keyboard-interactive authentication ($ctkeyboardinteractive/$ctfound):\n${YELLOW}$kihosts${NC}"
	fi

fi
#End
