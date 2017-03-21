#!/bin/bash
# redirector.sh
# Follows URLs supplied in file and outputs redirects.
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release
#
# Disclaimer: Quick and dirty hack. Use at own risk - input is not sanitised!
# -------------------------------------------------------------

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\e[32m'
NC='\033[0m' # No Color

# Stats variables
cturls=0
ctok=0
cterror=0
ctredirects=0
ctredirectedurls=0

function usage {
	echo "Description: Follows URLs supplied in file and outputs redirects."
	echo "Usage: $0 [-r] [-v] {inputfile} (one URL per line)"
	echo "    Optional -r to recursively follow redirects"
	echo "    Optional -v for more verbosity"
}

if [ $# -eq 0 ];
then
	usage "$0";
	exit
else
	while getopts "vr" opt
	do
	    case "$opt" in
		    r)
			    recurse=true
			    ;;
		    v)
			    verbose=true
			    ;;
		    \?) 
			    echo "Invalid option: -$OPTARG" >&2
			    usage "$0"; exit 1
			    ;;
	    esac
	done
	shift "$((OPTIND-1))"

	# Assign input file parameter to variable
	inputfile=$1
fi
# Check inputfile exists
if [[ -z $1 ]]; then
	echo "Error: supply a filename."
	exit 1
elif [[ ! -f $1 ]]; then
	echo "Error: File '$1' doesn't exist."
	exit 1
fi

if [ ! "$recurse" = true ]
then
	echo -e "${YELLOW}Warning:${NC} not recursively following redirects. Output will only show first redirect."
fi

while read -r url; do 
	let "ctredirects = 0"
	let "cturls += 1"
	url2=$(echo -n "$url" | tr -d '\r')
	if [ "$verbose" = true ]
	then
		echo -e "[+] Testing: $url2"
	fi

	response=$(curl -s -D - "$url2" -o /dev/null --connect-timeout 5)
	if [ -z "$response" ]
	then
		# If response is empty then couldn't reach URL/host
		status="[${RED}ERROR${NC}]"
		message="-> Invalid."
		let "cterror += 1"
	else
		redirect=$(echo "$response" | awk '/Location:/{print $2}' | tr -d '\r')
		if [ -z "$redirect" ]
		then
			# Got response, but no 'Location' header.
			status="[${GREEN}OK${NC}]"
			message=""
			let "ctok += 1"
		else
			# Got response and 'Location' header.
			let "ctredirects += 1"
			if [ "$recurse" = true ];
			then
				# Follow redirects recursively
				while [ ! -z "$redirect" ]; do
					last_redirect=$redirect
					response=$(curl -s -w "%{redirect_url}" "$redirect" -o /dev/null --connect-timeout 5)
					redirect=$response

					if [ ! -z "$redirect" ]
					then
						let "ctredirects += 1"
						if [ "$verbose" = true ]
						then
							echo -e "\t[->] Redirect is now $redirect"
						fi
					fi
				done;
			else
				last_redirect=$redirect
			fi
			status="[${YELLOW}REDIRECT${NC}]"
			message="-> $last_redirect [$ctredirects redirect(s)]"
			let "ctredirectedurls += 1"
		fi
	fi
	echo -e "$status $url $message"
done < "$inputfile"

# Print stats
echo -e "${BOLD}[STATS]${NC} $cturls URLs checked, ${GREEN}$ctok OK${NC}, ${YELLOW}$ctredirectedurls redirect${NC}, ${RED}$cterror error${NC}."
