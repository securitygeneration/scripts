#!/bin/bash
# blacklister.sh
# Blacklists the supplied IP address in Dome9 and/or Cloudflare
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release
#
# TODO: Provide multiple IPs in a file?
# -------------------------------------------------------------
# Configuration:
#
# You can configure either Cloudflare or Dome9 or both.
# If you don't have one of the two, set its variables to an empty string
#
# Your Cloudflare username (eg. user@email.com)
CFUSER=''
# Your Cloudflare API key (https://www.cloudflare.com/a/account/my-account under API Key)
CFAPI=''
#
# Your Dome9 username (eg. user@email.com)
DOMEUSER=''
# Your Dome9 API key (https://secure.dome9.com/settings under API Key)
DOMEAPI=''
# Optional parameter to allow Dome9 Blacklist items to auto-expire after a certain amount of time (in seconds). Leave blank for permanent blacklisting.
DOME9TTL=86400; # 21600 seconds = 6 hours, 86400 = 24h
# -------------------------------------------------------------

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\e[36m'
NC='\033[0m' # No Color
debug=false

function usage {
	echo "Description: Blacklist supplied IP address in Dome9 and/or Cloudflare."
	echo "Usage: $0 -i <IP> [-n <note>] [-d]"
	echo "    Optional -n <note/comment> provide a note or comment to go with the block"
	echo "    Optional -d to print out debug info. Use to troubleshoot."
}

function check_config {
	# Check at least one service is configured
	if [ -z "$CFUSER" ] && [ -z "$DOMEUSER" ]; then
		echo -e "\n[*] Edit the configuration section of this script to set your Cloudflare or Dome9 API info!"
		exit 1;
	fi
}

echo -e "__________.__                 __   .__  .__          __                  "
echo -e "\______   \  | _____    ____ |  | _|  | |__| _______/  |_  ___________   "
echo -e " |    |  _/  | \__  \ _/ ___\|  |/ /  | |  |/  ___/\   __\/ __ \_  __ \  "
echo -e " |    |   \  |__/ __ \\  \___ |   < |  |_|  |\___ \  |  | \  ___/|  | \/ "
echo -e " |______  /____(____  /\___  >__|_ \____/__/____  > |__|  \___  >__|     "
echo -e "        \/          \/     \/     \/            \/            \/         "

# Check arguments
if [ $# -eq 0 ];
then
	usage "$0";
	check_config;
	exit
else
	while getopts "n:i:d" opt; do
	    case "$opt" in
		    n)
			    NOTE=$OPTARG
			    ;;
		    i)
			    IP=$OPTARG
			    ;;
		    d)
			    debug=true
			    ;;
		    \?)
			    echo "Invalid option: -$OPTARG" >&2
			    usage "$0"; exit 1
			    ;;
		    :)
			    echo "Option -$OPTARG requires an argument." >&2
	    esac
	done
	shift "$((OPTIND-1))"
fi

check_config;

if [ -n "$CFUSER" ] && [ -n "$CFAPI" ]; then
	# Blacklist in Cloudflare
	cf_result=$(curl -v -s -X POST "https://api.cloudflare.com/client/v4/user/firewall/access_rules/rules" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFAPI" -H "Content-Type: application/json" --data '{"mode":"block","configuration":{"target":"ip","value":"'$IP'"},"notes":"'$NOTE'"}' 2>&1)

	status=$(echo "$cf_result" | grep '"success":true')

	if [ -n "$status" ]; then
		echo -e "[+] Blacklisting $IP with Cloudflare: ${GREEN}SUCCESS${NC}"
	else
		echo -e "[!] Blacklisting $IP with Cloudflare: ${RED}FAILED${NC}"
	fi

	if [ "$debug" = true ]; then
		echo "$cf_result"
	fi
else
	echo "[*] Cloudflare not configured, skipping."
fi

if [ -n "$DOMEUSER" ] && [ -n "$DOMEAPI" ]; then
	# Blacklist in Dome9
	if [ -n "$DOME9TTL" ]; then
		TTLSTRING="TTL: $DOME9TTL"
		TTL="&TTL=$DOME9TTL";
	else
		TTLSTRING="No TTL"
		TTL="";
	fi
	# Make Dome9 API request
	d9_result=$(curl -v -H "Accept: application/json" -u ${DOMEUSER}:${DOMEAPI} -X "POST" -d "IP=$IP&Comment=$NOTE$TTL" https://api.dome9.com/v1/blacklist/Items/ 2>&1;)

	status=$(echo "$d9_result" | grep 'Blacklist updated')

	if [ -n "$status" ]; then
		echo -e "[+] Blacklisting $IP with Dome9 ($TTLSTRING): ${GREEN}SUCCESS${NC}"
	else
		echo -e "[!] Blacklisting $IP with Dome9 ($TTLSTRING): ${RED}FAILED${NC}"
	fi

	if [ "$debug" = true ]; then
		echo "$d9_result"
	fi
else
	echo "[*] Dome9 not configured, skipping."
fi
