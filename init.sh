ip=$(./get_ip.sh)
erl -c setup.erl -name cloud@$ip -setcookie ensl -detached

echo Server started at cloud@$ip
echo Starting client at ${1:-noname}@$ip
echo To connect, type client:connect\(\'cloud@$ip\'\)
echo
erl -c client.erl -name ${1:-noname}@$ip -setcookie ensl
