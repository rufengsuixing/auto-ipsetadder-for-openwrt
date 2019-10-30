#!/bin/sh
echo $* | awk '{
ip=$1 
domain=$2
port=$3
stop=0;
while (stop==0){
    stop=1;
    system("sleep 120");
    while ("grep "ip" /proc/net/nf_conntrack"| getline ret > 0)
    {
        stop=0;
        break;
    }
    close("grep "ip" /proc/net/nf_conntrack");
}
"ipset test gfwlist "ip" 2>&1"| getline ipset;
    close("ipset test gfwlist "ip" 2>&1");
    if (index(ipset,"Warning")!=0){
        "ipset test china "ip" 2>&1"| getline ipset;
        close("ipset test china "ip" 2>&1");
        if (index(ipset,"Warning")!=0){
            print("china "ip" "domain" test again");
            system("ipset del gfwlist "$1);
            print "">"/tmp/run/"domain
            system("testip.sh "ip" "domain" "port" 1 1 &");
        }
    }
}'
