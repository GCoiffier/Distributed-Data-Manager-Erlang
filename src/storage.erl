-module(storage).

-define(debug,true).

%% ----------------------------------------------------------------------------
-export([distant_main/0]).

%% ----------------------------------------------------------------------------
-ifdef(debug).
-define(LOG(X), io:format("<Module ~p, Line~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.
%% ----------------------------------------------------------------------------


distant_main() ->
    io:fwrite("Distant main called~n"),
    DataDict = dict:new(),
    run(DataDict).

run(DataDict) ->
    receive
        {are_you_alive, Pid} ->
            ?LOG("Someone asked me if I was alive!"),

            Pid ! yes,
            run(DataDict);

        {store_data, Request} ->

            ?LOG("Someone asked me to store datas!"),
            ?LOG({"What I received :", Request}),

            {Dataname, Data, Status, Pid} = Request,
            case Status of

                simple ->
                    store_simple(DataDict, Dataname, Data),
                    Pid ! ack;

                distributed ->
                    store_distributed(DataDict, Dataname, Data),
                    Pid ! ack;

                critical ->
                    store_critical(DataDict, Dataname, Data),
                    Pid ! ack;

                _ ->
                    io:fwrite("received store_data instruction with invalid status !"),
                    Pid ! fail
            end,
            run(DataDict);

        {fetch_data, Request} ->
            ?LOG("Someone asked me to give him data!"),
            {Dataname, Pid} = Request,
            X = dict:fetch(Dataname, DataDict),
            run(DataDict);

        {kill} ->
            ?LOG("Someone asked me to commit suicide!");

        _ -> io:fwrite("Received something unusual")

    end. %end receive

store_simple(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname, ". Mode = simple"}),
    DataDict = dict:append(Dataname,Data,DataDict).

store_distributed(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname, ". Mode = distributed"}).

store_critical(DataDict, Dataname, Data) ->
    ?LOG({"store data ", Dataname, ". Mode = critical"}).
