### Bash one-liners to do random things

### Extract IP, protocol, port, service, NSE script name and script output from nmap.xml file ###
# Sample output:
# 10.11.18.197 udp 161 snmp snmp-brute 
#   public - Valid credentials
#   private - Valid credentials

xmlstarlet sel -t -m "//host/ports/port[service[@name='snmp']]/script" -v "concat(ancestor::host/address[@addrtype='ipv4']/@addr,' ', ../@protocol,' ', ../@portid,' ', ../service/@name,' ',@id,' ',str:replace(@output,'&#xa;',' '))" -n snmp_brute.xml

###
