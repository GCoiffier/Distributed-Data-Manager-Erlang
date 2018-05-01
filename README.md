# Distributed systems course
# erlang project
## Guillaume Coiffier
## ENS de Lyon, Spring 2018

## How to use
The script `./init_server.sh` initializes a distributed server on a node that has a name cloud@<your IP adress>
The script `./init_client.sh` initializes a client. From a client, you have to compile the *client* module with
`c(client).`. You can then use the client API to talk to the server :

- `connect/1` : connect(Node) connects to a Node. A server should be running on this node.
- `disconnect/0` : disconnect the client
- `update_connection/1` : get an update on the state of the server (a list of alive processes I can talk to)
- `send_data/2` : `send_data(dataname, mode)`. *dataname* should be the name of the file located in the data folder. It can be of any type. Mode has to be chosen in 4 possible modes :
    - simple : the data is stored once at only one place
    - distributed : the data is split into small parts and spread over the network
    - critical : the data is duplicated over several processes
    - hybrid : the data is split into bits, and then duplicated to be stored (takes less memory than critical mode but still have redundancy)
- `fetch_data/1` : given a file name, retrieves it from the network.
- `release_data/1` : given a file name, retrieves it from the network and suppresses it from the network.
- `broadcast/1` : broadcast a message to all processes I have access to
- `scatter/1` : scatter a list of messages to all processes I have access to
- `get_stored/0` : get a list of all the name of files that are stored in the connected network.


use `make clean` to get rid of the erlang compiled file (.beam)
