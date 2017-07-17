#!/usr/bin/python  
# blacklister.py
# Blacklists the supplied IP address in Dome9 and/or Cloudflare
# By Sebastien Jeanquier (@securitygen)
# Security Generation - http://www.securitygeneration.com
#
# ChangeLog -
# 0.1: Initial release (2017-07-16)
#
# TODO: Provide multiple IPs in a file?
# ----CONFIG START----------------------------------------------
# Configuration:
#
# You can configure either Cloudflare or Dome9 or both.
#
# Blacklist using Cloudflare
cloudflare = True
# Your Cloudflare username (eg. user@email.com)
CFUSER = ''
# Your Cloudflare API key (https://www.cloudflare.com/a/account/my-account under API Key)
CFAPI = ''
#
# Blacklist using Dome9
dome9 = True
# Your Dome9 username (eg. user@email.com)
domeuser = ''
# Your Dome9 API key (https://secure.dome9.com/settings under API Key)
domeapi = ''
# Optional parameter to allow Dome9 Blacklist items to auto-expire after a certain amount of time (in seconds). Set to 0 for permanent blacklisting.
dome9ttl = 86400 # eg. 86400 = 24h
# ----CONFIG END-------------------------------------------------

# Imports
import socket				# Import socket module
import sys, getopt			# Import sys and getopt to grab some cmd options like port number
import requests				# Import requests to perform HTTP requests to Dome9
import datetime				# For logging with timestamps
import json

debug = False
note = ''

print "__________.__                 __   .__  .__          __                  "
print "\______   \  | _____    ____ |  | _|  | |__| _______/  |_  ___________   "
print " |    |  _/  | \__  \ _/ ___\|  |/ /  | |  |/  ___/\   __\/ __ \_  __ \  "
print " |    |   \  |__/ __ \\  \___ |   < |  |_|  |\___ \  |  | \  ___/|  | \/ "
print " |______  /____(____  /\___  >__|_ \____/__/____  > |__|  \___  >__|     "
print "        \/          \/     \/     \/            \/            \/         "

def usage(): 
    print "Description: Blacklist supplied IP address in Dome9 and/or Cloudflare."
    print 'Usage: ' + sys.argv[0] + ' -i <IP> [-n <note>] [-d]'
    print "    Optional -n <note/comment> provide a note or comment to go with the block"
    print "    Optional -d to print out debug info. Use to troubleshoot."

def check_config():
    if CFUSER == '' and domeuser == '':
        print "[*] Edit the configuration section of this script to set your Cloudflare or Dome9 API info!"
        sys.exit(2)

# Get command line input
try:
    opts, args = getopt.getopt(sys.argv[1:], "n:i:d")
    if not opts:
        usage()
        check_config()
        sys.exit(2)
except getopt.GetoptError:
    usage()
    sys.exit(2)
for opt, arg in opts:
    if opt == '-n':
        note = arg
    elif opt == '-i':
        client_ip = arg
    elif opt == '-d':
        debug = True

check_config()

# If using Dome9, check API username/key are set - or die.
# TODO validate they work
if dome9 and (domeuser == "" or domeapi == ""):
    sys.exit("\n[!] Configured to use Dome9 but Dome9 username or API key are not set.\n")
# If Dome9 is enabled, use it.
if dome9:
    payload = {'IP': client_ip, 'Comment':note} # Build request payload
    if dome9ttl > 0:
        payload['TTL'] = dome9ttl # If a TTL is set in config, add it to the request payload
    else:
        dome9ttl = "Permanent" # For logging

    # Send blacklist request to Dome9	
    resp = requests.post('https://api.dome9.com/v1/blacklist/Items/', auth=(domeuser,domeapi), params=payload)
    if debug:
       print resp.text
    # Check it was successful
    if resp.status_code == 200:
        print "[+] Blacklisted {0} with Dome9 (TTL: {1})".format(client_ip, dome9ttl)
    elif resp.status_code == 403:	
        print "[!] Failed to blacklist {0} with Dome9. HTTP response code {1}, check the Dome9 username and API key in the config.".format(client_ip, resp.status_code)
    else:
        print "[!] Failed to blacklist {0} with Dome9. HTTP response code {1}.".format(client_ip, resp.status_code)

# If using Cloudflare, check API username/key are set - or die.
# TODO validate they work
if cloudflare and (CFUSER == "" or CFAPI == ""):
    sys.exit("\n[!] Configured to use Cloudflare but Cloudflare username or API key are not set.\n")
# If Cloudflare is enabled, use it.
if cloudflare:
    payload = {'mode': 'block', 'configuration':{"target":"ip","value":client_ip}, 'notes':note} # Build request payload
    headers = {'X-Auth-Email':CFUSER, 'X-Auth-Key':CFAPI}
        
    # Send blacklist request to Dome9	

    # req = requests.Request('POST', 'https://api.cloudflare.com/client/v4/user/firewall/access_rules/rules', data=json.dumps(payload), headers=headers)
    # prepared = req.prepare()
    # print prepared.body
    resp = requests.post('https://api.cloudflare.com/client/v4/user/firewall/access_rules/rules', data=json.dumps(payload), headers=headers)
    if debug:
       print resp.text
    # Check it was successful
    if resp.status_code == 200:
        print "[+] Blacklisted {0} with Cloudflare.".format(client_ip)
    elif resp.status_code == 403:	
        print "[!] Failed to blacklist {0} with Cloudflare. HTTP response code {1}, check the Cloudflare username and API key in the config.".format(client_ip, resp.status_code)
    else:
        print "[!] Failed to blacklist {0} with Cloudflare. HTTP response code {1}.".format(client_ip, resp.status_code)

## END
