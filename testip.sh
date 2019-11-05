#!/bin/sh
echo $* | awk '{
if ($4=="")
{ 
wait=0;
}else
{wait=$4;}
system("sleep "wait);
getline drop< "/tmp/run/"$2;
if (ERRNO) {
addlist=100;
close("/tmp/run/"$2);
print("bypass"$1" "$2);
next;}
close("/tmp/run/"$2);
if ($3=="443")
{
cmd=("httping -c 1 -t 4 -l "$2" --divert-connect "$1);
}
else if ($3=="80")
{
cmd=("httping -c 1 -t 4 "$2" --divert-connect "$1);
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
        if (system("httping -q -c 1 -t 4 -l "$2" --divert-connect "$1)==0)
        {
            close(cmd);
            addlist=-1;
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
            addlist=-1;
        }
    }else if (index(ret,"Connection refused")!=0){
        print("direct Connection refused autoaddip"$1" "$2);
        system("ipset add gfwlist "$1);
        addlist=1;
    }
}
close(cmd);
getline drop< "/tmp/run/"$2;
close("/tmp/run/"$2);
if (ERRNO) {next;}
if (addlist!=1)
{
    if (addlist==0){
    split(ret, c,"[ /]+");
    print(c[6]);
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
    }else{addlist=-1;}
    }
    if (addlist==-1)
    {
        "ipset test china "$1" 2>&1"| getline ipset;
        close("ipset test china "$1" 2>&1");
        if (index(ipset,"Warning")==0){
        while (("ping -c 5 -q -A "$1 | getline ret) > 0)
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
    addlist=-2;
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
        addlist=-2;
    }else{
        addlist=2;
    }
}
}
}END{
if (addlist==2)
{   
    getline drop< "/tmp/run/"$2;
    if (ERRNO) {
        system("ipset del gfwlist "$1);
        print("cancel add myself "$1" "$2" due to one ip success direct");
    }else{
    print $1"\n">>"/tmp/run/"$2;
    }
    close("/tmp/run/"$2);
}else if (addlist==-1)
{
    print($1" "$2" direct success");
    while ((getline ret< "/tmp/run/"$2) > 0)
    {
        if (ret!=""){
        system("ipset del gfwlist "ret);
        print("cancel add someone "ret" "$2" due to me"$1" success direct");
        }
    }
    close("/tmp/run/"$2);
    system("rm /tmp/run/"$2" 2>/dev/null");
    print($1" del "$2);
}else if (addlist==-2)
{   
    system("sleep 10");
    while ((getline ret< "/tmp/run/"$2) > 0)
    {
        if (ret!=""){
        system("ipset add gfwlist "$1);
        print("add "ret" "$2" due to one ip success proxy");
        break;}
    }
    close("/tmp/run/"$2);
}}'