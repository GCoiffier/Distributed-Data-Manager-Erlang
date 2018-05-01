-module(storage).

%% ----------------------------------------------------------------------------
-export([storage_init/0]).

%% ----------------------------------------------------------------------------
%-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

-define(STORAGE_UPDATE_TIME,10000).
-define(STORAGE_TIMEOUT_TIME,1000).
%% ----------------------------------------------------------------------------


storage_init() ->
    storage_run(dict:new(), sets:new()).

storage_run(DataDict,Father) ->
    receive
        {ping, Pid} ->
            Pid ! pong,
            storage_run(DataDict,Father);

        {new_father, Pid} -> storage_run(DataDict, Pid);

        {store_data, Request} ->
            {Dataname, DataID, Data} = Request,
            storage_run(append(DataDict, {Dataname, DataID}, Data), Father);

        {GetRequest, DataInfo, ReturnPid} when (GetRequest =:= fetch_data) or (GetRequest =:= release_data) ->
            {_, Dataname, UUID} = DataInfo,
            Key = {Dataname, UUID},
            case dict:find(Key, DataDict) of
                error -> ReturnPid ! {reply, not_found};
                {ok, Value} -> ReturnPid ! {reply, Value}
            end,
            case GetRequest of
                fetch_data -> storage_run(DataDict,Father);
                release_data -> storage_run(dict:erase(Key,DataDict),Father)
            end;

        kill -> ok;

        _X -> ?LOG({"Received something unusual :", _X}),
             storage_run(DataDict,Father)
    after ?STORAGE_UPDATE_TIME ->
        Father ! {ping, self()},
        receive pong -> ok
        after ?STORAGE_TIMEOUT_TIME -> ?LOG("Father not responding"), master ! {ask_query, self()}
        end,
        storage_run(DataDict, Father)
    end. %end receive

append(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname}),
    case dict:find(Dataname, DataDict) of
        error -> dict:append(Dataname,Data,DataDict);
        {ok, _} -> DataDict % avoid duplicates
    end.
