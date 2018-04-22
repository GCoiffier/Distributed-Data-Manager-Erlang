ip=$(./get_ip.sh)
echo Starting a server at cloud@$ip
echo To start a client, open another terminal and run ./init_client.sh
erlc server.erl
erl -s server server_init -name cloud@$ip -setcookie ensl
