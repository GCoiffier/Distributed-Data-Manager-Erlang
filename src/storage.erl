-module(storage).

%% ----------------------------------------------------------------------------
-export([distant_main/0]).

%% ----------------------------------------------------------------------------

distant_main() ->
    io:fwrite("Distant main called~n"),
    DataDict = dict:new(),
    run(DataDict).

run(DataDict) ->
    receive
        {are_you_alive, Pid} ->
            io:fwrite("Someone asked me if I was alive!~n"),
            Pid ! yes,
            run(DataDict);

        {store_data, DataName, Data, Status, Pid} ->
            io:fwrite("Someone asked me to store datas!~n"),
            case Status of

                simple ->
                    store_simple(DataDict, DataName, Data),
                    Pid ! ack;

                distributed ->
                    store_distributed(DataDict, DataName, Data),
                    Pid ! ack;

                critical ->
                    store_critical(DataDict, DataName, Data),
                    Pid ! ack;

                _ -> io:fwrite("received store_data instruction with invalid status !~n"),
                     Pid ! fail;
            end,
            run(DataDict);

        {fetch_data, DataName, Pid} ->
            io:fwrite("Someone asked me to give him data!~n"),
            fetch(DataDict, DataName)
            run(DataDict);

        {kill} ->
            io:fwrite("Someone asked me to commit suicide!~n")
    end.



store_simple(DataDict, DataName, Data) ->
    io:fwrite("store data ~p . MODE = SIMPLE~n", [DataName]).

store_distributed(DataDict, DataName, Data) ->
    io:fwrite("store data ~p . MODE = DISTRIBUTED~n", [DataName]).

store_critical(DataDict, DataName, Data) ->
    io:fwrite("store data ~p . MODE = CRITICAL~n", [DataName]).
