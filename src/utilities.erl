-module(utilities).

-export([store/0]).

% ------------------------------ Utilities -------------------------------------
store() -> store(sets:new()).

store(S) ->
    receive
        {get, Pid} -> Pid ! {reply, sets:to_list(S)},
                      store(S);

        {add, X} -> store(sets:add_element(X,S));

        {add_list, L} -> store(sets:union(S,sets:from_list(L)));

        {del, X} -> store(sets:del_element(X,S));

        {kill} -> ok
    end.
