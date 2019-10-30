#!/bin/sh
echo $* | awk '{
if ($4!="1")
{ 
system("sleep 2");
}
getline drop< "/tmp/run/"$2;
if (ERRNO) {next;}
if ($3=="443")
{
cmd=("httping -c 1 -t 4 -l "$2" --divert-connect "$1);
}
else if ($3=="80")
{
cmd=("httping -c 1 -t 4 "$2" --divert-connect "$1);
cmdb=("httping -c 1 -t 4 -l "$2" --divert-connect "$1);
}
addlist=0;
slow=0;
while ((cmd | getline ret) > 0)
{
    if (addlist==1)
    {
        continue;
    }
    else if (index(ret,"short read")!=0)
    {
        if (system(cmdb)==0)
        {
            close(cmd);
            next;
        }else{
            system("ipset add gfwlist "$1);
            print("doname rst autoaddip "$1" "$2);
            addlist=1;
        }
    } 
    else if (index(ret,"timeout")!=0)
    {
        while ((cmd | getline ret) > 0)
        {
            if (index(ret,"timeout")!=0)
            {
                print("direct so slow autoaddip "$1" "$2);
                system("ipset add gfwlist "$1);
                addlist=1;
                slow=1;
            }
        }
    }else if (index(ret,"SSL handshake error: (null)")!=0)
    {
        if(system("curl -m 10 --resolve "$2":443:"$1" https://"$2" -o /dev/null 2>/dev/null")==0){
            close(cmd);
            next;
        }
    }else if (index(ret,"Connection refused")!=0){
        print("direct Connection refused autoaddip"$1" "$2);
        system("ipset add gfwlist "$1);
        addlist=1;
    }
}
close(cmd);
split(ret, c,"[ /]+");
print(c[6]);
if (addlist==0)
{
    if (c[6]=="failed,"){
    system("ipset add gfwlist "$1);
    print("can not connect autoaddip "$1" "$2);
    addlist=1;
    }
    else if (c[6]+0>10000)
    {
        system("ipset add gfwlist "$1);
        print("direct ssl so slow autoaddip "$1" "$2);
        addlist=1;
    }else{
        while (("ping -c 5 -q "$1 | getline ret) > 0)
        {
            if (index(ret,"packet loss")!=0)
            {
                split(ret, p,"[ ]+");
                if (p[4]>0 && p[4]<4)
                {
                    system("ipset add gfwlist "$1);
                    print("ping packet loss autoaddip "$1" "$2);
                    addlist=1;
                    break;
                }
            } 
        }
        close("ping -c 5 -q "$1);
        if (addlist==0)
        {
            system("rm /tmp/run/"$2" 2>/dev/null");
        }
    }
}
if (addlist==1){
while ((cmd | getline ret) > 0)
{
    if (addlist==1)
    {
    if (index(ret,"short read")!=0)
    {
    system("ipset del gfwlist "$1);
    print("doname proxy rst autodelip "$1" "$2);
    addlist=0;
    }
    else if (index(ret,"SSL handshake error: (null)")!=0)
    {
        if(system("curl -m 10 --resolve "$2":443:"$1" https://"$2" -o /dev/null 2>/dev/null")==0)
        {
            addlist=2;
        }
    }
    }
}
close(cmd);
if (addlist==1){
    split(ret, c,"[ /]+");
    print(c[6]);
    if (c[6]=="failed,")
    {
        system("ipset del gfwlist "$1);
        print("proxy can not connect autodelip "$1" "$2);
        addlist=0;
    }else{
        addlist=2;
    }
}
if (addlist==2 && $5=="")
{
    "ipset test china "ip" 2>&1"| getline ipset;
    close("ipset test china "ip" 2>&1");
    if (index(ipset,"Warning")!=0){
        system("delayretest.sh "$1" "$2" "$3" &");
    }
}
}}'