#!/bin/bash
# ssh_authenum.sh
# Test list of hosts/IPs for supported SSH authentiation types
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
NC='\033[0m' # No Color

# Stats variables
ctunusual=0
ctfound=0
cttimeout=0
total=0

if [ -z "$1" ]; then

	echo "Usage:"
	echo "     ./ssh_auth.sh <inputfile> (one host per line)"
	echo "     Currently assumes SSH is running on TCP/22"

else

	echo "----- Starting scan $(date) -----"

	for HOST in $(cat $1);
	do
		result=""
		methods=""
		let "total += 1"
		#Debug
		#echo "Testing host: $HOST"

		result=$(ssh -T -o PreferredAuthentications=none -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=3 $HOST 2> >(cat))
		# Debug
		#echo "Result is $result"

		methods=$(echo "$result"|grep 'denied'|tr -d '().'|cut -d ' ' -f3)
		# Debug
		#echo "methods is $methods"

		if [[ $result == *"timed out"* ]]; then
			echo "Host $HOST: connection timed out"
			let "cttimeout += 1"
		elif [ -n "$methods" ]; then
			echo "Host $HOST supports: $methods"
			if [[ $methods == *"password"* ]]; then
				pwhosts="$pwhosts$HOST\n"
			fi
			let "ctfound += 1"
		else
			echo "Host $HOST: unusual response, check!"
			let "ctunusual += 1"
		fi
	done

	printf "\n----- Stats -----\nTotal hosts scanned: $total\nSSH hosts found: $ctfound\nTimed out: $cttimeout\nUnusual responses: $ctunusual\n"

	printf "\nHosts that support password authentication:\n${RED}$pwhosts${NC}"

fi
#End
