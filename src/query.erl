-module(query).
%% -----------------------------------------------------------------------------
-import(storage, [storage_init/0]).
%% ----------------------------------------------------------------------------
-export([query_init/0]).
%% ----------------------------------------------------------------------------
-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.
%% ----------------------------------------------------------------------------

query_init() -> ?LOG("Query node init"),
                storage_init().
