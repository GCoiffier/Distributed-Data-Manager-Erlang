ip=`ifconfig | awk -F ":"  '/inet adr/{split($2,a," ");print a[1]}' | tail -1`

erl -c setup.erl -name cloud@$ip -setcookie ensl -detached
erl -c client.erl -name $1@$ip -setcookie ensl
