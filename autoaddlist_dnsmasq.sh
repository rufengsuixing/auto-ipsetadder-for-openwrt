#!/bin/sh
tail -F /tmp/dnsmasq.log | grep reply |awk  -F "[, ]" '{
ip=$8;
domain=$6;
if (index(ip,".")==0)
{
next;
}
if (!(ip in a))
{ 
"ipset test gfwlist "ip" 2>&1"| getline ipset;
close("ipset test gfwlist "ip" 2>&1");
if (index(ipset,"Warning")!=0){
print("pass");
next;
}

tryhttps=0;
tryhttp=0;
while ("grep "ip" /proc/net/nf_conntrack"|getline ret > 0)
{
    split(ret, b," +");
    if (b[8]=="dst="ip)
    {
        if (b[10]=="dport=443"){
            tryhttps=1;
            break;
        }
        else if (b[10]=="dport=80"){
            tryhttp=1;
        }
    }
}
close("grep "ip" /proc/net/nf_conntrack");
if (tryhttps==1)
{
print(ip" "domain" 443");
a[ip]=domain;
system("testip.sh "ip" "domain" 443 &");
}
else if (tryhttp==1)
{
print(ip" "domain" 80");
a[ip]=domain;
system("testip.sh "ip" "domain" 80 &");
}}}'