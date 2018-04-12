-module(setup).
%% -----------------------------------------------------------------------------
-import(query, [query_init/1]).
-export([server_init/0]).
-export([compile/2, send_code/2]).

%% -----------------------------------------------------------------------------
-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

-define(NB_QUERY_NODE,10).
%% -----------------------------------------------------------------------------

-on_load(server_init/0).

% Spawns N=10 query nodes and connect them together.
server_init() ->
    io:fwrite("Initializing~n"),
    compile:file(query),
    compile:file(storage),
    server_init(?NB_QUERY_NODE, sets:new()).

server_init(0, QueryNodeSet) ->
    lists:map(fun (Pid) -> Pid ! {other_query_nodes, QueryNodeSet} end, sets:to_list(QueryNodeSet)),
    server_run(QueryNodeSet).

server_init(N, QueryNodeSet) ->
    Pid = spawn(query, query_init, [N]),
    server_init(N-1, sets:add_element(Pid, QueryNodeSet)).

server_run(QueryNodeSet) ->
    receive
        {connect_request, Pid} ->
            Pid ! {reply, QueryNodeSet},
            server_run(QueryNodeSet)
    end.

compile(ID, Filename) -> spawn(ID, compile, file, [Filename]).

send_code(ID, Module) -> {Mod, Bin, File} = code:get_object_code(Module),
                         spawn(ID, code, load_binary, [Mod, File, Bin]).
