#!/bin/sh
tail -F /tmp/dnsmasq.log | grep reply |awk  -F "[, ]" '{
ip=$8;
if (ip=="")
{
next;
}
if (index(ip,"<CNAME>")!=0)
{
if (cname==1)
{
    next;
}
cname=1;
domain=$6;
next;
}
if (lastdomain!=$6 && cname!=1)
{
    domain=$6;
    ipcount=0;
    for (ipindex in ipcache)
    {
        delete ipcache[ipindex];
    }
    testall=0;
}
ipcount+=1;
cname=0;
lastdomain=$6
if (index(ip,".")==0)
{
    next;
}
if (!(ip in a))
{ 
    "ipset test gfwlist "ip" 2>&1"| getline ipset;
    close("ipset test gfwlist "ip" 2>&1");
    if (index(ipset,"Warning")!=0){
        "ipset test china "ip" 2>&1"| getline ipset;
        close("ipset test china "ip" 2>&1");
        if (index(ipset,"Warning")!=0){
            print("warning china "ip" "domain" is in gfwlist")
        }else{
            print("pass");
        }
    next;
}
if (passdomain==domain)
{
    print("pass by packets>10 at same domain");
    a[ip]=domain;
    next;
}
ipcache[ipcount]=ip;
if (testall==0){
    tryhttps=0;
    tryhttp=0;
    while ("grep "ip" /proc/net/nf_conntrack"| getline ret > 0)
    {
        split(ret, b," +");
        split(b[11], pagnum,"=");
        if (pagnum[2]>10)
        {
            print("pass by packets="pagnum[2]" "ip" "domain);
            for (ipindex in ipcache)
            {
                a[ipcache[ipindex]]=domain;
                delete ipcache[ipindex];
            }
            passdomian=domain;
            close("grep "ip" /proc/net/nf_conntrack");
            next;
        }
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
}else{
    if (testall==443)
    {
        tryhttps=1
    }else{
        tryhttp=1
    }
}
if (tryhttps==1)
{
    for (ipindex in ipcache){
        print(ipcache[ipindex]" "domain" 443");
        a[ipcache[ipindex]]=domain;
        system("testip.sh "ipcache[ipindex]" "domain" 443 &");
        delete ipcache[ipindex];
    }
    ipcount=0;
    testall=443;
}
else if (tryhttp==1)
{
    for (ipindex in ipcache){
        print(ipcache[ipindex]" "domain" 80");
        a[ipcache[ipindex]]=domain;
        system("testip.sh "ipcache[ipindex]" "domain" 80 &");
        delete ipcache[ipindex];
    }
    ipcount=0;
    testall=80;
}}}'