#!/bin/bash
# redirector.sh
# Follows URLs supplied in file and outputs HTTP redirects (and SSL errors)
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release
#
# Disclaimer: Quick and dirty hack. Use at own risk - input is not sanitised!
# Note: This script outputs _HTTP_ Response redirects to a HEAD request;
#       this will not catch redirects performed by JavaScript or other.
#	It prints out the HTTP Response code, but anything other than
#	a redirect (i.e. 404, 500) is still counted as 'OK'.
#
# -------------------------------------------------------------
# Configuration:
max_redirs=10 # Maximum number of redirects to follow
# -------------------------------------------------------------

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\e[32m'
BLUE='\e[36m'
NC='\033[0m' # No Color

# Stats variables
cturls=0
ctok=0
cterror=0
ctredirects=0
ctredirectedurls=0
cttotalhosts=0
ctsslerrors=0

finalurls=()
sslerrorurls=()
recurse=true

function usage {
	echo "Description: Follows URLs supplied in file and outputs redirects."
	echo "Usage: $0 [-R] [-t] [-v] [-u <filename>] [-s <filename>] {inputfile} (one URL per line)"
	echo "    Optional -u <file> to log unique (working) URLs to file"
	echo "    Optional -s <file> to log URLs with SSL validation errors"
	echo "    Optional -R to NOT recursively follow redirects"
	echo "    Optional -t to scan SSL error URLs with testssl.sh"
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

function debug {
	# debug(response)
	responsecode=$(echo "$1" | head -n1 | awk "/^HTTP\//"{'print $2'})
	echo "=== DEBUG: ==============================="
	echo "Response code: '$responsecode'"
	echo "$1"
	echo -e "=======================================\n"
}

# Print banner!
echo -e "__________           .___.__                       __                 "
echo -e "\______   \ ____   __| _/|__|______   ____   _____/  |_  ___________  "
echo -e " |       _// __ \ / __ | |  \_  __ \_/ __ \_/ ___\   __\/  _ \_  __ \ "
echo -e " |    |   \  ___// /_/ | |  ||  | \/\  ___/\  \___|  | (  <_> )  | \/ "
echo -e " |____|_  /\___  >____ | |__||__|    \___  >\___  >__|  \____/|__|    "
echo -e "        \/     \/     \/                 \/     \/                    "

# Check arguments
if [ $# -eq 0 ];
then
	usage "$0";
	exit
else
	while getopts "tvdRu:s:" opt; do
	    case "$opt" in
		    R)
			    recurse=false
			    ;;
		    v)
			    verbose=true
			    ;;
		    d)
			    debug=true
			    ;;
		    t)
			    testssl=true
			    ;;
		    u)
			    unique_file=$OPTARG
			    ;;
		    s)
			    ssl_file=$OPTARG
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

# TODO If -t supplied, check for testssl.sh on the path

# If -R set, print non-recursion warning
if [ ! "$recurse" = true ]
then
	echo -e "${YELLOW}Warning:${NC} -R flag supplied, not recursively following redirects. Output will only show first redirect."
fi

# Print out number of lines in file and wait
cttotalhosts=$(wc -l < "$inputfile")
>&2 echo "Info: '$inputfile' has $cttotalhosts lines!"
>&2 echo "Waiting 3 seconds, press Ctrl-C to abort."
sleep 3

# Start main loop - read and follow URLs
while read -r url; do 
	let "ctredirects = 0"
	let "cturls += 1"
	response=''
	error=''
	ssl_error=''
	last_redirect=''
	message=''
	head='-I'

	url2=$(echo -n "$url" | tr -d '\r')

	# Auto-prepend 'http' if ommitted
	if [[ ! "$url2" =~ ^https?:\/\/.* ]]
	then
		url2="http://$url2"
		if [ "$verbose" = true ]
		then
			echo -e "\033[K[!] No http(s) in $url, prepending with 'http://'"
		fi
	fi

	if [ "$verbose" = true ]; then
		echo -e "\033[K[*] Testing: $url2"
		progress
	fi

	# Request URL
	response=$(curl $head -s -D - "$url2" -o /dev/null --connect-timeout 3 -S 2>&1)
	# Store HTTP Response code
	responsecode=$(echo "$response" | head -n1 | awk "/^HTTP\//"{'print $2'})
	# Grep any curl errors
	error=$(echo "$response" | head | grep "curl:")

	if [ "$debug" = true ]; then debug "$response"; fi

	# If server returns empty or 5xx response, retry with GET request
	if [[ "$error" =~ 'curl: (52)' ]] || [[ $responsecode =~ 5[[:digit:]][[:digit:]] ]]; then
		if [ "$verbose" = true ]; then
			echo -e "\033[K   [*] Blank or 5xx response returned, disabling HEAD requests for this URL."
			progress
		fi
		head=''
		response=$(curl $head -s -D - "$url2" -o /dev/null --connect-timeout 3 -S 2>&1)
		error=$(echo "$response" | head | grep "curl:")

		if [ "$debug" = true ]; then debug "$response"; fi
	fi

	# Check for an SSL error
	if [[ "$error" =~ .*SSL.* ]]; then
		# If SSL error, log it and proceed ignoring SSL errors
		ssl_error=$error
		if [ "$verbose" = true ]
		then
			echo -e "\033[K   ${RED}[!]${NC} Invalid SSL on: $url2 [$ssl_error]"
			progress
		fi
		response=$(curl $head -k -s -D - "$url2" -o /dev/null --connect-timeout 3 -S 2>&1)
		error=$(echo "$response" | head | grep "curl:")
		let "ctsslerrors += 1"
		sslerrorurls+=("$url2")

		if [ "$debug" = true ]; then debug "$response"; fi
	fi

	# Store HTTP Response code
	responsecode=$(echo "$response" | head -n1 | awk "/^HTTP\//"{'print $2'})

	# Check for an error
	if [ -z "$response" ] || [ ! -z "$error" ]; then
		# If response is empty or curl error
		status="[${RED}ERROR${NC}]"
		message="-> Invalid [$error]"
		let "cterror += 1"
	else
		# Check for redirect in response
		redirect=$(echo "$response" | awk '/^Location:/{print $2}' | tr -d '\r')
		if [ -z "$redirect" ]; then
			# Got response, but no 'Location' header.
			# Mark 'OK'
			status="[${GREEN}OK${NC}]"
			message="[$responsecode]"
			if [ ! -z "$ssl_error" ]; then
				message+=" (${YELLOW}Warning:${NC} Website is accessible, but presents an invalid SSL certificate)"
			fi
			let "ctok += 1"
			if [ "$verbose" = true ]; then
				echo -e "\033[K   [+] HTTP Response code is: $responsecode"
				progress
			fi
			finalurls+=("$url2")
		else
			# Got response and 'Location' header.
			# Log redirect
			let "ctredirects += 1"

			# If value provided in Location header is relative, make absolute
			if [[ ! "$redirect" =~ ^https?:// ]]; then
				full_url=$(echo "$url2" | cut -d/ -f1)//$(echo "$url2" | cut -d/ -f3)$redirect
				redirect="$full_url"	
			fi
			
			if [ "$verbose" = true ]; then
				echo -e "\033[K   [+] HTTP Response code is: $responsecode"
				echo -e "\033[K   [->] Redirect is now '$redirect'"
				progress
			fi

			if [ "$recurse" = true ]; then
				# Follow redirects recursively
				while [ ! -z "$redirect" ] && [ "$ctredirects" -lt "$max_redirs" ]; do
					head="-I"
					last_redirect=$redirect
					response=$(curl $head -D - -s -w "\n%{redirect_url}" "$redirect" --connect-timeout 3 -S -o /dev/null 2>&1)
					# Store HTTP Response code
					responsecode=$(echo "$response" | head -n1 | awk "/^HTTP\//"{'print $2'})
					# Check for errors
					error=$(echo "$response" | head | grep "curl:")

					if [ "$debug" = true ]; then debug "$response"; fi

					# If server returns empty or 5xx response, retry with GET request
					if [[ "$error" =~ 'curl: (52)' ]] || [[ $responsecode =~ 5[[:digit:]][[:digit:]] ]]; then
						if [ "$verbose" = true ]; then
							echo -e "\033[K   [*] Blank or 5xx response returned, disabling HEAD requests for this URL."
							progress
						fi
						head=''
						response=$(curl $head -D - -s -w "\n%{redirect_url}" "$redirect" --connect-timeout 3 -S -o /dev/null 2>&1)
						error=$(echo "$response" | head | grep "curl:")

						if [ "$debug" = true ]; then debug "$response"; fi
					fi

					# Check for an SSL error
					if [[ "$error" =~ .*SSL.* ]]; then
						# If SSL error, log it and proceed ignoring SSL errors
						ssl_error=$error
						if [ "$verbose" = true ]
						then
							echo -e "\033[K   ${RED}[!]${NC} Invalid SSL on: $redirect [$ssl_error]"
							progress
						fi
						response=$(curl $head -D - -k -s -w "\n%{redirect_url}" "$redirect" --connect-timeout 3 -S -o /dev/null 2>&1)
						error=$(echo "$response" | head | grep "curl:")
						let "ctsslerrors += 1"
						sslerrorurls+=("$redirect")

						if [ "$debug" = true ]; then debug "$response"; fi
					fi
					# Check for other errors
					redirect=$(echo "$response" | tail -n1 | grep -E "https?://" | tr -d '\r')
					responsecode=$(echo "$response" | head -n1 | awk "/^HTTP\//"{'print $2'})
					error=$(echo "$response" | head | grep "curl:")
					if [ ! -z "$error" ]; then
						# Error with next URL	
						# Mark 'Error'
						status="[${RED}ERROR${NC}]"
						message="-> $last_redirect [$ctredirects redirect(s)] Error: $error"
						let "cterror += 1"
						redirect=''
					elif [ ! -z "$redirect" ]; then
						# No error, next url returned
						# Log redirect
						let "ctredirects += 1"
						if [ "$verbose" = true ]; then
							echo -e "\033[K   [+] HTTP Response code is: $responsecode"
							echo -e "\033[K   [->] Redirect is now '$redirect'"
							progress
						fi
					else
						# No URL returned - end of redirects
						# Mark 'Redirect'
						let "ctredirectedurls += 1"
						status="[${YELLOW}REDIRECT${NC}]"
						message="-> $last_redirect [$ctredirects redirect(s), $responsecode]"
						if [ ! -z "$ssl_error" ]; then
							message="$message (${YELLOW}Warning:${NC} Website is accessible, but at least one server in the redirect chain presented an invalid SSL certificate)"
						fi
						finalurls+=("$last_redirect")
					fi
				done;

				if [ ! "$ctredirects" -lt "$max_redirs" ]; then
					# Exceeded redirect limit, mark 'Error'
					status="[${RED}ERROR${NC}]"
					error="Exceeded redirect limit ($max_redirs)"
					message="-> $last_redirect [$ctredirects redirect(s)] Error: $error"
					let "cterror += 1"
					redirect=''
				fi
			else
				# Log and mark 'Redirect'
				let "ctredirectedurls += 1"
				last_redirect=$redirect
				status="[${YELLOW}REDIRECT${NC}]"
				message="-> $last_redirect [$ctredirects redirect(s)]"
				finalurls+=("$last_redirect")
			fi
		fi
	fi
	# Print current URL status
	echo -e "\033[K$status $url2 $message"
	progress
done < "$inputfile"

# Calculate number of unique URLs and bad SSL URLs.
if [ ! "${#finalurls[@]}" -eq 0 ]; then
	# Remove trailing slash for more accurate unique (eg. google.com/ & google.com)
	ctuniqueurls=$(tr ' ' '\n' <<< "${finalurls[@]}" | sed 's/\/$//g' | sort -u | wc -l)
else
	ctuniqueurls="0"
fi
if [ ! "${#sslerrorurls[@]}" -eq 0 ]; then
	# Remove trailing slash for more accurate unique (eg. google.com/ & google.com)
	ctsslurls=$(tr ' ' '\n' <<< "${sslerrorurls[@]}" | sed 's/\/$//g' | sort -u | wc -l)
else
	ctsslurls="0"
fi

# Print stats
echo -e "\033[K${BOLD}[STATS]${NC} $cturls URLs checked, ${GREEN}$ctok OK${NC}, ${YELLOW}$ctredirectedurls redirect${NC}, ${YELLOW}$ctsslerrors SSL errors${NC}, ${RED}$cterror error${NC}, ${BLUE}$ctuniqueurls unique${NC}."

# Output unique and bad SSL URLs to files
if [ ! -z "$unique_file" ]; then
	# Remove trailing slash for more accurate unique (eg. google.com/ & google.com)
	unique_urls=$(tr ' ' '\n' <<< "${finalurls[@]}"  | sed 's/\/$//g' | sort -u)
	echo "$unique_urls" > "$unique_file"
	echo "Info: $ctuniqueurls unique (non-redirect and successful-redirect) URL(s) saved to $unique_file" >&2
fi
if [ ! -z "$ssl_file" ]; then
	# Remove trailing slash for more accurate unique (eg. google.com/ & google.com)
	ssl_urls=$(tr ' ' '\n' <<< "${sslerrorurls[@]}" | sed 's/\/$//g' | sort -u)
	echo "$ssl_urls" > "$ssl_file"
	echo "Info: $ctsslurls URL(s) with SSL validation errors were saved to $ssl_file" >&2
fi

# Run bad SSL URLs through testssl.sh
if [ "$testssl" = true ]; then
	for url in "${sslerrorurls[@]}"; do
		echo "[!] Scanning $url with testssl.sh!"
		testssl.sh "$url" | tee -a testssl.txt
	done
fi
