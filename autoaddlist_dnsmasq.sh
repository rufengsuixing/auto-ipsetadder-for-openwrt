#!/bin/sh
stdbuf -oL tail -F /tmp/dnsmasq.log | awk  -F "[, ]+" '/reply/{
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
if(lastdomain!=$6){
    for (ipindex in ipcache)
    {
        delete ipcache[ipindex];
    }
    ipcount=0;
if (cname!=1)
{
    domain=$6;
    testall=0;
    createpid=1;
}}
ipcount++;
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
            print(ip" "domain" is in gfwlist pass");
        }
        next;
    }
if (passdomain==domain)
{
    print(ip" "domain" pass by same domain ok");
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
        if (pagnum[2]>12)
        {
            print("pass by packets="pagnum[2]" "ip" "domain);
            for (ipindex in ipcache)
            {
                a[ipcache[ipindex]]=domain;
                delete ipcache[ipindex];
            }
            passdomain=domain;
            close("grep "ip" /proc/net/nf_conntrack");
            ipcount--;
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
{   if (createpid==1)
    {
        print "">"/tmp/run/"domain
		close("/tmp/run/"domain);
        print("create"domain);
        print(ip" "domain" 443"ipcount-1);
        a[ip]=domain;
        system("testip.sh "ip" "domain" 443 "ipcount-1" &");
        delete ipcache[ipcount];
        createpid=0;
    }
    for (ipindex in ipcache){
        print(ipcache[ipindex]" "domain" 443 "ipindex-1);
        a[ipcache[ipindex]]=domain;
        system("testip.sh "ipcache[ipindex]" "domain" 443 "ipindex-1" &");
        delete ipcache[ipindex];
    }
    testall=443;
}
else if (tryhttp==1)
{   
    if (createpid==1)
    {
        print "">"/tmp/run/"domain
		close("/tmp/run/"domain);
        print("create"domain);
        print(ip" "domain" 80 "ipcount-1);
        a[ip]=domain;
        system("testip.sh "ip" "domain" 80 "ipcount-1" &");
        delete ipcache[ipcount];
        createpid=0;
    }
    for (ipindex in ipcache){
        print(ipcache[ipindex]" "domain" 80 "ipindex-1);
        a[ipcache[ipindex]]=domain;
        system("testip.sh "ipcache[ipindex]" "domain" 80 "ipindex-1" &");
        delete ipcache[ipindex];
    }
    testall=80;
}}
}'