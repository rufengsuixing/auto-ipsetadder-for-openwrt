ipset list gfwlist | awk '{
if (index($0,".")==0)
{
    next;
}
"ipset test china "$0" 2>&1"| getline ipset;
    close("ipset test china "$0" 2>&1");
    if (index(ipset,"Warning")!=0){
    while ("grep "$0" /tmp/nohup.out"| getline ret > 0)
    {
        print(ret);
    }
    }
}'