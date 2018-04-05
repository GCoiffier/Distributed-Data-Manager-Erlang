-module(storage).

%% ----------------------------------------------------------------------------
-export([storage_init/0]).

%% ----------------------------------------------------------------------------
-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.
%% ----------------------------------------------------------------------------


storage_init() ->
    storage_run(dict:new(), sets:new()).

storage_run(DataDict,Fathers) ->
    receive
        {ping, Pid} ->
            Pid ! pong,
            storage_run(DataDict,Fathers);

        {new_father, Pid} -> storage_run(DataDict, sets:add_element(Pid, Fathers));

        {kill_father, Pid} -> storage_run(DataDict, sets:del_element(Pid, Fathers));

        {store_data, Request} ->

            ?LOG("Someone asked me to store datas!"),
            ?LOG({"What I received :", Request}),

            {Dataname, Data, Pid} = Request,
            storage_run(append(DataDict, Dataname, Data),Fathers);

        {fetch_data, Request} ->
            ?LOG("Someone asked me to give him data!"),
            {Dataname, Pid} = Request,
            case dict:find(Dataname, DataDict) of
                error -> Pid ! not_found;
                {ok, Value} -> Pid ! {data, Value}
            end,
            storage_run(DataDict,Fathers);

        {release_data, Request} ->
            ?LOG("Someone asked me to release some data"),
            {Dataname, Pid} = Request,
            case dict:find(Dataname, DataDict) of
                error -> Pid ! not_found;
                {ok, Value} -> Pid ! {data, Value}
            end,
            storage_run(dict:erase(Dataname,DataDict),Fathers);

        {kill} ->
            ?LOG("Someone asked me to commit suicide!"),
            lists:map(fun (Pid) -> Pid ! {kill_child, self()} end, sets:to_list(Fathers));

        _ -> ?LOG("Received something unusual"),
             storage_run(DataDict,Fathers)

    after 5000 ->
        case sets:size(Fathers) of
            0 -> io:fwrite("Storage node ~p is disconnected from the network. Shutting down~n", [self()]);
            x when x<3 -> io:fwrite("Not enough Father for me ! ~p", [self()]);
            _ -> ok
        end,
        storage_run(DataDict,Fathers)
    end. %end receive

append(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname}),
    case dict:find(Dataname, DataDict) of
        error -> dict:append(Dataname,Data,DataDict);
        {ok, _} -> DataDict % avoid duplicates
    end.
