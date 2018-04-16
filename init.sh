ip=$(./get_ip.sh)
erl -c setup.erl -name cloud@$ip -setcookie ensl -detached
erl -c client.erl -name ${1:-noname}@$ip -setcookie ensl
