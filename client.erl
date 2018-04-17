-module(client).

%% -----------------------------------------------------------------------------
-export([connect/1]).
-export([send_data/2, fetch_data/1, release_data/1]).
-export([broadcast/1, scatter/1]).
%% -----------------------------------------------------------------------------
-define(CLIENT_TIMEOUT_TIME, 1000).
%% -----------------------------------------------------------------------------

-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

%% -----------------------------------------------------------------------------

connect(Node) ->
    compile:file(utilities),
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
% Reads data from Filename and send it to the network
% Three storage mode are possible
%     - Simple : the data is stored in one chunk in one process
%     - Distributed : the data is cut in parts and stored in various processes
%     - Critical : the data is copied several times and stored in whole in different processes
% % % % %
send_data(Filename,Status) ->
    case Status of
        simple -> ?LOG("Storage mode = SIMPLE");
        distributed -> ?LOG("Storage mode = DISTRIBUTED");
        critical -> ?LOG("Storage mode = CRITICAL");
        _ -> io:fwrite("Storage mode should be in {simple,distributed,critical}. Aborting.~n"),
             exit(send_data)
    end,

    Path = string:concat("data/",Filename),

    Data = readfile(Path),
    ?LOG({"Data to be sent :", Data}),

    L = get_neighbours(),
    To = lists:nth(random:uniform(length(L))-1, L),
    To ! {store_data, {Filename, Data, Status, self()}},
    receive
        ack -> io:fwrite("Send successful~n");
        fail -> io:fwrite("Send Failed~n")
    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("No acknowledgment received. Assuming data sending failed.~n")
    end.

% % % % %
% Retrieve data Filename from the network.
% If the Data couldn't be found, does nothing and write an
%   error message in console
% % % % %
fetch_data(Filename) ->
    receive
        not_found ->
            io:fwrite("Data ~p does not seem to be stored in the network.~n", [Filename]);

        {data,Value} ->
            [Data | _ ] = Value,
            ?LOG({"Data =", Data}),
            writefile(Filename, Data)

    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("No data received in time. Assuming connection failed.~n")
    end.


% % % % %
% Retrieve data Filename and supresses it from the network
% If the Data couldn't be found, does nothing
% % % % %
release_data(Filename) ->
    receive
        not_found ->
            io:fwrite("Data ~p does not seem to be stored in the network.~n", [Filename]);

        {data,Value} ->
            [Data | _ ] = Value,
            ?LOG({"Data =", Data}),
            writefile(Filename, Data)

    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("No data received in time. Assuming connection failed.~n")
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

% ------------------------------------------------------------------------------

get_neighbours() ->
    neighbours ! {get, self()},
    receive {reply, L} -> L
    after ?CLIENT_TIMEOUT_TIME ->
        io:fwrite("in get_neighbours() : the node seems to be disconnected"), []
    end.

% Reads the content of a txt file and convert it to a list of strings
readfile(Filename) ->
    ?LOG({"reading lines from file ", Filename}),
    {ok, Data} = file:read_file(Filename),
    binary:split(Data, [<<"\n">>], [global]),
    ?LOG("Reading Done."),
    binary:bin_to_list(Data).

writefile(Filename,File) ->
    file:write_file(string:concat("/output/", Filename), io_lib:fwrite("~s", [File])),
    io:fwrite("Data successfully retrieved and stored in output/~p", [Filename]).
