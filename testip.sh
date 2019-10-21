#!/bin/sh
echo $* | awk '{
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
    if (addlist==0){
    if (index(ret,"short read")!=0)
    {
    system("ipset add gfwlist "$1);
    print("doname rst autoaddip "$1" "$2);
    addlist=1;
    }
    else if (index(ret,"timeout")!=0)
    {
        print("direct so slow autoaddip "$1" "$2);
        system("ipset add gfwlist "$1);
        addlist=1;
        slow=1;
    }else if (index(ret,"SSL handshake error: (null)")!=0)
    {
        if(system("curl -m 10 --resolve "$2":443:"$1" https://"$2" -o /dev/null 2>/dev/null")==0){
            close(cmd);
            next;
        }
    }
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
        }
}
if (addlist==1){
fin=0;
while ((cmd | getline ret) > 0)
{
    if (fin==0)
    {
    if (index(ret,"short read")!=0)
    {
    system("ipset del gfwlist "$1);
    print("doname proxy rst autodelip "$1" "$2);
    fin=1;
    }
    else if (index(ret,"timeout")!=0)
    {
        print("proxy so slow"$1" "$2);
        if (slow==1)
        {
            system("ipset del gfwlist "$1);
            print("change back to direct "$1" "$2);
        }
        fin=1;
    }else if (index(ret,"SSL handshake error: (null)")!=0)
    {
        if(system("curl -m 10 --resolve "$2":443:"$1" https://"$2" -o /dev/null 2>/dev/null")==0)
        {
            fin=1;
        }
    }
    }
}
close(cmd);
if (fin==1)
{
next;
}
split(ret, c,"[ /]+");
print(c[6]);
if (c[6]=="failed,")
{
    system("ipset del gfwlist "$1);
    print("proxy can not connect autodelip "$1" "$2);
}}}'