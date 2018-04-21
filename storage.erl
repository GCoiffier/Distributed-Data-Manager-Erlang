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

-define(STORAGE_UPDATE_TIME,5000).
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

            {Dataname, DataID, Data} = Request,
            storage_run(dict:append({Dataname, DataID}, Data, DataDict), Fathers);

        {fetch_data, Request} ->
            ?LOG("Someone asked me to give him data!"),
            {Dataname, UUID, Pid} = Request,
            Key = {Dataname, UUID},
            case dict:find(Key, DataDict) of
                error -> Pid ! not_found;
                {ok, Value} -> Pid ! {data, Value}
            end,
            storage_run(DataDict,Fathers);

        {release_data, Request} ->
            ?LOG("Someone asked me to release some data"),
            {Dataname, UUID, Pid} = Request,
            Key = {Dataname, UUID},
            case dict:find(Dataname, DataDict) of
                error -> Pid ! not_found;
                {ok, Value} -> Pid ! {data, Value}
            end,
            storage_run(dict:erase(Key,DataDict),Fathers);

        {kill} ->
            ?LOG("Someone asked me to commit suicide!"),
            lists:map(fun (Pid) -> Pid ! {kill_child, self()} end, sets:to_list(Fathers));

        X -> ?LOG({"Received something unusual :", X}),
             storage_run(DataDict,Fathers)

    end. %end receive

append(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname}),
    case dict:find(Dataname, DataDict) of
        error -> dict:append(Dataname,Data,DataDict);
        {ok, _} -> DataDict % avoid duplicates
    end.
