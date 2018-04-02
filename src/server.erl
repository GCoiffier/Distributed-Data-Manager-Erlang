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

server_init() -> ?LOG("server init"),
                 query_init().
