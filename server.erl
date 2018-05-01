-module(server).
%% -----------------------------------------------------------------------------
-import(query, [query_init/1]).
-export([server_init/0, server_run/1]).
-export([compile/2, send_code/2]).

%% -----------------------------------------------------------------------------
%-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

-define(NB_QUERY_NODE,10).
%% -----------------------------------------------------------------------------

% % % % %
% Spawns N= NB_QUERY_NODE query nodes and connect them together.
% % % % %
server_init() ->
    io:fwrite("Initializing~n"),
    compile:file(query),
    compile:file(storage),
    register(master, self()),
    server_init(?NB_QUERY_NODE, sets:new()).

server_init(0, QueryNodeSet) ->
    % End of server init. Sends their neighbours to everyone, they enter run loop
    lists:map(fun (Pid) -> Pid ! {other_query_nodes, QueryNodeSet} end, sets:to_list(QueryNodeSet)),
    server_run(QueryNodeSet);

server_init(N, QueryNodeSet) ->
    % spawns a query process, then recursive call.
    Pid = spawn(query, query_init, [N==1]),
    server_init(N-1, sets:add_element(Pid, QueryNodeSet)).

server_run(QueryNodeSet) ->
    % Handles new connections and reply to pings
    receive
        {ping, Pid} ->
            Pid ! {pong, self()},
            server_run(QueryNodeSet);

        {init_new_node, NewNode} ->
            % adds a query process on NewNode.
            case net_adm:ping(NewNode) of
                pong -> ?LOG("Connection success");
                pang -> ?LOG("Connection failed")
            end,
            send_code(NewNode, query),
            Pid = spawn(NewNode, query, query_init, [false]),
            lists:map(fun (X) -> Pid ! {new_query, X} end, sets:to_list(QueryNodeSet)),
            lists:map(fun (X) -> X ! {new_query, Pid} end, sets:to_list(QueryNodeSet)),
            server_run(sets:add_element(Pid, QueryNodeSet));

        {ask_query, Pid} ->
            Pid ! {new_father, hd(sets:to_list(QueryNodeSet))};

        {connect_request, Pid} ->
            Pid ! {reply, sets:to_list(QueryNodeSet)},
            io:fwrite("New client connected : ~p~n", [Pid]),
            server_run(QueryNodeSet);

        shutdown -> io:fwrite("Server shutting down~n"),
            lists:map(fun (X) -> X ! {kill, ending} end, sets:to_list(QueryNodeSet))
    end.

compile(ID, Filename) -> spawn(ID, compile, file, [Filename]).

send_code(ID, Module) -> {Mod, Bin, File} = code:get_object_code(Module),
                         spawn(ID, code, load_binary, [Mod, File, Bin]).
