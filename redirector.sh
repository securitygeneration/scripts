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
# Note: This script outputs _HTTP_ Response redirects to a HEAD request;
#       this will not catch redirects performed by JavaScript or other.
#	This script does not handle redirect loops (PR?)
#
# TODO: Handle redirect loops.
# -------------------------------------------------------------

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\e[32m'
BLUE='\e[96m'
NC='\033[0m' # No Color

# Stats variables
cturls=0
ctok=0
cterror=0
ctredirects=0
ctredirectedurls=0
cttotalhosts=0

finalurls=()
recurse=true

function usage {
	echo "Description: Follows URLs supplied in file and outputs redirects."
	echo "Usage: $0 [-R] [-v] {inputfile} (one URL per line)"
	echo "    Optional -R to NOT recursively follow redirects"
	echo "    Optional -v for more verbosity"
}

function progress {
	width=30
	percentage=$(awk "BEGIN { pc=100*${cturls}/${cttotalhosts}; i=int(pc); print (pc-i<0.5)?i:i+1 }")
	num=$(( percentage * width / 100 ))
	if [ $num -gt 0 ]
	then
		bar=$(printf "%.0s=" $(seq 1 $num))
	else
		bar=
	fi
	tput sc
	tput cup "$(tput lines)"
	>&2 printf "${BOLD}Progress: [%-${width}s] (%s%%)${NC}" "$bar" "$percentage"
	tput rc
}

if [ $# -eq 0 ];
then
	usage "$0";
	exit
else
	while getopts "vR" opt
	do
	    case "$opt" in
		    R)
			    recurse=false
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
	echo -e "${YELLOW}Warning:${NC} -R flag supplied, not recursively following redirects. Output will only show first redirect."
fi

cttotalhosts=$(wc -l < "$inputfile")
>&2 echo "Info: '$inputfile' has $cttotalhosts lines!"
>&2 echo "Waiting 3 seconds, press Ctrl-C to abort."
sleep 3

while read -r url; do 

	let "ctredirects = 0"
	let "cturls += 1"
	url2=$(echo -n "$url" | tr -d '\r')

	if [[ ! $url2 =~ ^https?:\/\/.* ]]
	then
		url2="http://$url2"
		if [ "$verbose" = true ]
		then
			echo -e "\033[K[!] No http(s) in $url, prepending with 'http://'"
		fi
	fi

	if [ "$verbose" = true ]
	then
		echo -e "\033[K[+] Testing: $url2"
		progress
	fi

	# Request URL
	response=$(curl -I -s -D - "$url2" -o /dev/null --connect-timeout 3 -S 2>&1)
	# echo "$response" # DEBUG

	# Check for an error
	error=$(echo "$response" | head | grep "curl:")
	if [ -z "$response" ] || [ ! -z "$error" ]
	then
		# If response is empty or curl error
		status="[${RED}ERROR${NC}]"
		message="-> Invalid [$error]"
		let "cterror += 1"
	else
		# Check for redirect in response
		redirect=$(echo "$response" | awk '/Location:/{print $2}' | tr -d '\r')
		if [ -z "$redirect" ]
		then
			# Got response, but no 'Location' header.
			status="[${GREEN}OK${NC}]"
			message=""
			let "ctok += 1"
			finalurls+=("$url2")
		else
			# Got response and 'Location' header.
			let "ctredirects += 1"
			if [ "$verbose" = true ]
			then
				echo -e "\033[K\t[->] Redirect is now $redirect"
				progress
			fi

			if [ "$recurse" = true ];
			then
				# Follow redirects recursively
				while [ ! -z "$redirect" ]; do
					last_redirect=$redirect
					response=$(curl -s -w "%{redirect_url}" "$redirect" -o /dev/null --connect-timeout 3 -S 2>&1)
					redirect=$response

					error=$(echo "$redirect" | head | grep "curl:")
					if [ ! -z "$error" ]
					then
						# Error with next URL	
						status="[${RED}ERROR${NC}]"
						message="-> $last_redirect [$ctredirects redirect(s)] Error: $error"
						let "cterror += 1"
						redirect=''
					elif [ ! -z $redirect ]	
					then
						# No error, next url returned
						let "ctredirects += 1"
						if [ "$verbose" = true ]
						then
							echo -e "\033[K\t[->] Redirect is now $redirect"
							progress
						fi
					else
						# No URL returned - end of redirects
						let "ctredirectedurls += 1"
						status="[${YELLOW}REDIRECT${NC}]"
						message="-> $last_redirect [$ctredirects redirect(s)]"
						finalurls+=("$last_redirect")
					fi
				done;
			else
				let "ctredirectedurls += 1"
				last_redirect=$redirect
				status="[${YELLOW}REDIRECT${NC}]"
				message="-> $last_redirect [$ctredirects redirect(s)]"
				finalurls+=("$last_redirect")
			fi
		fi
	fi
	echo -e "\033[K$status $url2 $message"
	progress
done < "$inputfile"

# Print stats
ctuniqueurls=$(tr ' ' '\n' <<< "${finalurls[@]}" | sort -u | wc -l)
echo -e "\033[K${BOLD}[STATS]${NC} $cturls URLs checked, ${GREEN}$ctok OK${NC}, ${YELLOW}$ctredirectedurls redirect${NC}, ${RED}$cterror error${NC}, ${BLUE}$ctuniqueurls unique${NC}."
