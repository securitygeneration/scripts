#!/bin/bash
# openports.sh
# Prints out all hosts that have the specified port(s) open in gnmap file.
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release
#
# -------------------------------------------------------------

function usage {
	echo "Description: Lists hosts with a given port open."
	echo "Usage: $0 [-i] {port} {gnmap file}"
	echo "	Port can be single port (e.g. 22), or multiple '21|22|23' (note quoted list)"
	echo "	Optional -i outputs only IP addresses"
}

if [ $# -eq 0 ];
then
	usage $0;
	exit
else

	iflag=false
	while getopts i opt
	do
	    case "$opt" in
	      i)  iflag=true;;
	      \?)		# unknown flag
			usage $0; exit;;
	    esac
	done
	shift "$((OPTIND-1))"

	# Assign parameters to variables
	port=$1
	gnmapfile=$2

	# Check port entry is valid
	re="^[0-9]+(\|[0-9]+)*$"
	if ! [[ $port =~ $re ]] ; then
   		echo "Error: port number must be an integer or '23|24|...', you entered: $port" >&2; exit 1
		exit 1
	fi

	# Check gnmap file exists
	if [[ ! -f $gnmapfile ]]; then
		echo "Error: File '$gnmapfile' doesn't exist."
		exit 1
	fi

	if [[ $iflag == true ]]; then
		egrep "\s($port)\/open" "$gnmapfile" | awk {'print $2'}
	else
		egrep "\s($port)\/open" "$gnmapfile"
	fi
fi #echo