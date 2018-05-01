-module(client).

%% -----------------------------------------------------------------------------
-export([connect/1, disconnect/0, update_connection/1]).
-export([send_data/1, send_data/2]).
-export([fetch_data/1, release_data/1]).
-export([broadcast/1, scatter/1]).
-export([get_stored/0]).

-export([kill_node/0, kill_node/1, add_node/2, shutdown/0]).

%% -----------------------------------------------------------------------------
-define(CLIENT_TIMEOUT_TIME, 1000).
%% -----------------------------------------------------------------------------

% -define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

%% -----------------------------------------------------------------------------

% % % % %
% Connects to a Node, where a server should be running
% % % % %
connect(Node) ->
    compile:file(utilities),
    IPid = spawn_link(utilities, store_id, []),
    register(id_storage, IPid),
    % Retrieve set of query nodes on which we can connect
    {master, Node} ! {connect_request, self()},
    receive {reply, L} ->
        NPid = spawn_link(utilities, store, []),
        register(neighbours, NPid),
        neighbours ! {add_list, L}
    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("Error : the client is unable to connect~n")
    end.

% % % % %
% Resets the list of available nodes and the storage list.
% % % % %
disconnect() ->
    neighbours ! kill,
    unregister(neighbours),
    id_storage ! kill,
    unregister(id_storage).

% % % % %
% Asks server running on Node to give its query node list.
% % % % %
update_connection(Node) ->
    {master, Node} ! {connect_request, self()},
    receive {reply, L} ->
        neighbours ! {add_list, L}
    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("Error : the client is unable to connect~n")
    end.

% % % % %
% Reads data from Filename and send it to the network
% Three storage mode are possible
%     - 'simple' : the data is stored in one chunk in one process
%     - 'distributed' : the data is cut in parts and stored in various processes
%     - 'critical' : the data is copied several times and stored in whole in different processes
%     - 'hybrid' : the data is stored in a distributed way, but with redundancy
% % % % %
send_data(Filename,Status) ->
    case Status of
        simple -> ?LOG("Storage mode = SIMPLE");
        distributed -> ?LOG("Storage mode = DISTRIBUTED");
        critical -> ?LOG("Storage mode = CRITICAL");
        hybrid -> ?LOG("Storage mode = HYBRID");
        _ -> io:fwrite("Storage mode should be in {simple,distributed,critical}. Aborting.~n"),
             exit(send_data)
    end,

    Path = string:concat("data/",Filename),

    case readfile(Path) of
        error -> io:fwrite("Couldn't read input file~n");

        {DataSize, Data} ->
            ?LOG({"Data to be sent :", Data}),
            io:fwrite("Sending ~p bytes of data on the network~n", [DataSize]),

            % send request to a random query node of the network
            get_random_node() ! {store_data, {Filename, DataSize, Data, Status, self()}},

            receive
                {ack, DataInfo} ->
                    io:fwrite("Send successful~n"),
                    ?LOG({"After send, retrived", DataInfo}),
                    id_storage ! {add, Filename, DataInfo},
                    ok;

                fail -> io:fwrite("Send Failed~n")

            after ?CLIENT_TIMEOUT_TIME ->
                io:fwrite("No acknowledgment received. Assuming data sending failed.~n")
            end
    end.

send_data(_) ->
    io:fwrite("You need to provide a storage mode as a second argument.~nStorage mode available :~n  -simple~n  -distributed~n  -critical~n  -hybrid~n"),
    ok.

% % % % %
% Retrieve data Filename from the network.
% If the Data couldn't be found, does nothing and write an
%   error message in console
% % % % %
fetch_data(Filename) ->
    id_storage ! {get, Filename, self()},
    receive
        {reply, not_found} ->
            io:fwrite("Error : no information about ~p being stored in the network ~n", [Filename]);

        {reply, DataInfo} -> retrieve_data(DataInfo, fetch_data)

    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("Error : client seems disconnected from its dictionnary ~n")
end.

% % % % %
% Retrieve data Filename and supresses it from the network
% If the Data couldn't be found, does nothing
% % % % %
release_data(Filename) ->
    id_storage ! {get_and_delete, Filename, self()},
    receive
        {reply, not_found} ->
            io:fwrite("Error : no information about ~p being stored in the network ~n", [Filename]);

        {reply, DataInfo} -> retrieve_data(DataInfo, release_data)

    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("Error : client seems disconnected from its dictionnary ~n")
end.

% % % % %
% Sends a message to every query node of the server
% % % % %
broadcast(Message) -> lists:map(fun(Pid) -> Pid ! Message end, get_neighbours()), ok.

% % % % %
% Scatter MessageList to query nodes of the server
% % % % %
scatter(MessageList) -> scatter(MessageList, get_neighbours()).
scatter([],_) -> ok;
scatter(L, []) -> scatter(L, get_neighbours());
scatter([M|Q1], [N|Q2]) -> N ! M, scatter(Q1,Q2).

% ------------------------- Non exported com functions -------------------------

% Type = (fetch_data | release_data)
retrieve_data(DataInfo, Type) ->
    {_,Filename,_} = DataInfo,
    get_random_node() ! {get_client, Type, {DataInfo, self()}},
    receive
        {data, Data} ->
            io:fwrite("Data ~p successfully retrieved from the network~n", [Filename]),
            writefile(Filename, Data);
        not_found -> io:fwrite("Data ~p does not seem to be stored in the network ~n",[Filename])
    after ?CLIENT_TIMEOUT_TIME*10 ->
        io:fwrite("Timeout~n")
    end.

% -------------------- Functions  modifying the network ------------------------

kill_node() -> kill_node(get_random_node()).

kill_node(Pid) ->
    Pid ! {kill, proper},
    neighbours ! {del, Pid}.

add_node(MasterNode, NewNode) ->
    {master, MasterNode} ! {init_new_node, NewNode}.

shutdown() ->
    get_random_node() ! shutdown.

% ------------------------- Utility functions ----------------------------------

get_stored() ->
    id_storage ! {get_stored, self()},
    receive {reply, L} -> L
    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("in get_stored() : the node seems to be disconnected"), []
    end.

get_neighbours() ->
    neighbours ! {get, self()},
    receive {reply, L} -> L
    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("in get_neighbours() : the node seems to be disconnected"), []
    end.

get_random_node() ->
    neighbours ! {get_one, self()},
    receive {reply, X} -> X
    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("in get_random_node() : the node seems to be disconnected"), none
    end.

% ------------------- Utility function working on data -------------------------

% % % % %
% Reads the content of a file and convert it to a list of strings
% % % % %
readfile(Filename) ->
    ?LOG({"reading lines from file ", Filename}),
    case file:read_file(Filename) of
        {ok, Data} ->
            binary:split(Data, [<<"\n">>], [global]),
            ?LOG("Reading Done."),
            {byte_size(Data), binary:bin_to_list(Data)};
        {error, Reason} ->
            io:fwrite("Error in readfile : ~p~n", [Reason]),
            error
    end.

% % % % %
% Writes back the content of a file
% % % % %
writefile(Filename, File) ->
    file:write_file(string:concat("output/", Filename), io_lib:fwrite("~s", [File])),
    io:fwrite("Data successfully retrieved and stored in output/~p~n", [Filename]).
