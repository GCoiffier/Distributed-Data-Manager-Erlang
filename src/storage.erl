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
    DataDict = dict:new(),
    storage_run(DataDict).

storage_run(DataDict) ->
    receive
        {are_you_alive, Pid} ->
            ?LOG("Someone asked me if I was alive!"),

            Pid ! yes,
            storage_run(DataDict);

        {store_data, Request} ->

            ?LOG("Someone asked me to store datas!"),
            ?LOG({"What I received :", Request}),

            {Dataname, Data, Status, Pid} = Request,
            case Status of

                simple ->
                    DataDictUpdated = store_simple(DataDict, Dataname, Data),
                    Pid ! ack;

                distributed ->
                    DataDictUpdated = store_distributed(DataDict, Dataname, Data),
                    Pid ! ack;

                critical ->
                    DataDictUpdated = store_critical(DataDict, Dataname, Data),
                    Pid ! ack;

                _ ->
                    io:fwrite("received store_data instruction with invalid status !"),
                    Pid ! fail,
                    DataDictUpdated = DataDict
            end,
            storage_run(DataDictUpdated);

        {fetch_data, Request} ->
            ?LOG("Someone asked me to give him data!"),
            {Dataname, Pid} = Request,
            case dict:find(Dataname, DataDict) of
                error -> Pid ! not_found;
                {ok, Value} -> Pid ! {data, Value}
            end,
            storage_run(DataDict);

        {release_data, Request} ->
            ?LOG("Someone asked me to release some data"),
            {Dataname, Pid} = Request,
            case dict:find(Dataname, DataDict) of
                error -> Pid ! not_found;
                {ok, Value} -> Pid ! {data, Value}
            end,
            storage_run(dict:erase(Dataname,DataDict));

        {kill} ->
            ?LOG("Someone asked me to commit suicide!");

        _ -> ?LOG("Received something unusual"),
             storage_run(DataDict)

    end. %end receive

store_simple(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname, ". Mode = simple"}),
    case dict:find(Dataname, DataDict) of
        error -> dict:append(Dataname,Data,DataDict);
        {ok, Value} -> DataDict % avoid duplicates
    end.

store_distributed(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname, ". Mode = distributed"}),
    case dict:find(Dataname, DataDict) of
        error -> dict:append(Dataname,Data,DataDict);
        {ok, Value} -> DataDict % avoid duplicates
    end.

store_critical(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname, ". Mode = critical"}),
    case dict:find(Dataname, DataDict) of
        error -> dict:append(Dataname,Data,DataDict);
        {ok, Value} -> DataDict % avoid duplicates
    end.
