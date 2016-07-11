#!/bin/bash
# nsesearch.sh
# Searches nmap NSE scripts and prints out help, usage, parameter and sample output.
# Created because for some reason there doesn't seem to be an easy way to do this in nmap
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release
#
# Note: Rough hack. Only tested on Mac OS X and Kali Linux!
# -------------------------------------------------------------

# Try using standard grep command by default
grep='grep'

# Check if BSD or GNU grep
flavour=`$grep -V | $grep -o BSD | head -1`
if [[ $flavour == "BSD" ]]; then
	if ! type "ggrep" &> /dev/null; then
		echo "This won't work with BSD grep. Install GNU grep."
		echo "On OS X, install using Homebrew: "
		echo "# brew tap homebrew/dupes"
		echo "# brew install homebrew/dupes/grep"
		echo "# brew install pcre"
		exit 0
	else
		# Use ggrep (installed by Homebrew on OS X when you install GNU grep)
		grep='ggrep'
	fi
fi

# Check nmap is installed as we'll call it
if ! type "nmap" &> /dev/null; then
	echo "Error: nmap not found!"
	exit 0
fi

if [ -z $1 ]; then
	echo "./nsesearch <search term> | Searches available nmap NSE scripts."
	exit 0
else
	search=$1
fi

# Find installed NSE scripts
nmap_basepath=`nmap -v -d 2>/dev/null | $grep -Po 'Read from \K\/.*(?=:)'`
script_list=`$grep -Po '[\w-]+(?=.nse)' $nmap_basepath/scripts/script.db | $grep "$search"`

# Search NSE script names for search parameter
if [[ -n $script_list ]]; then
	num=0
	echo "Available nmap NSE scripts:"
	for line in $script_list; do
		path[$num]="$nmap_basepath/scripts/$line.nse"
		name[$num]=$line
		echo "${num}) ${name[$num]}"
		((num++))
	done;

	# Read in chosen script number
	read -p "Select a script number: " selection
	until [ $selection -ge 0 ] && [ $selection -lt $num ];
	do
	echo "Invalid number!"
	read -p "Select a script number: " selection
	done

	# Get script help output from nmap --script-help
	output=`nmap --script-help=${name[$selection]}`

	# Get usage, args and output info from script file
	output=$output"\n\n`$grep -Poz "(?s)(--\s@.*?\n)\n" ${path[$selection]}`"
	echo "$output" | less

else
	echo "No NSE scripts found containing '$search'."
fi