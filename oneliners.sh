# Bash one-liners to do random things

# Extract IP, prot, port, service and script name
# 10.11.18.197 udp 161 snmp snmp-brute 
#   public - Valid credentials
#   private - Valid credentials

xmlstarlet sel -t -m "//host/ports/port[service[@name='snmp']]/script" -v "concat(ancestor::host/address[@addrtype='ipv4']/@addr,' ', ../@protocol,' ', ../@portid,' ', ../service/@name,' ',@id,' ',str:replace(@output,'&#xa;',' '))" -n snmp_brute.xml

##############
