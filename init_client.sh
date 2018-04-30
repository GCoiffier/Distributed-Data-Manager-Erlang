ip=$(./get_ip.sh)

echo Starting client at ${1:-noname}@$ip
echo Make sure you have a server running somewhere
echo To connect, type client:connect\(server\)
echo
echo
erlc client.erl
erl -name ${1:-noname}@$ip -setcookie ensl
