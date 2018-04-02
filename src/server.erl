-module(server).
%% -----------------------------------------------------------------------------
-import(query, [query_init/0]).
-export([server_init/0]).
%% -----------------------------------------------------------------------------
-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.
%% -----------------------------------------------------------------------------

server_init() ->
    % Spawns 2 query nodes and connect them to the client
    ?LOG("server init"),
    Pid1 = spawn(query, query_init, []),
    Pid2 = spawn(query, query_init, []),
    receive {are_you_done, Pid} ->
        Pid ! {init_done, [Pid1, Pid2]}
    end.
