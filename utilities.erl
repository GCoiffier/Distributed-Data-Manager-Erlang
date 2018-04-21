-module(utilities).

-export([store/0, store_id/0]).

% ------------------------------ Utilities -------------------------------------
store() -> store(sets:new()).
store(S) ->
    receive
        {get, Pid} ->
            Pid ! {reply, sets:to_list(S)},
            store(S);

        {get_one, Pid} ->
            [H|_] = sets:to_list(S),
            Pid ! {reply, H},
            store(S);

        {add, X} -> store(sets:add_element(X,S));

        {add_list, L} -> store(sets:union(S,sets:from_list(L)));

        {del, X} -> store(sets:del_element(X,S));

        {kill} -> ok
    end.


store_id() -> store_id(maps:new()).
store_id(M) ->
    receive
        {get, Entryname, Pid} ->
            Pid ! {reply, maps:get(Entryname, M, not_found)},
            store_id(M);

        {get_and_delete, Entryname, Pid} ->
            Pid ! {reply, maps:get(Entryname, M, not_found)},
            store_id(maps:remove(Entryname,M));

        {get_stored, Pid} ->
            Pid ! {reply, maps:keys(M)},
            store_id(M);

        {get_all, Pid} ->
            Pid ! {reply, maps:to_list(M)},
            store_id(M);

        {add, Key, Data} ->
            store_id(maps:put(Key,Data,M));

        {add_list, L} ->
            M2 = lists:foldl(fun({K,D}, Map) -> maps:put(K,D,Map) end, M, L),
            store_id(M2);

        {del, Key} ->
            store_id(maps:remove(Key,M));

        {kill} -> ok
    end.
