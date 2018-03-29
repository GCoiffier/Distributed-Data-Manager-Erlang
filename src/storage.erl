-module(storage).

%% ----------------------------------------------------------------------------
-export([distant_main/0]).

%% ----------------------------------------------------------------------------

distant_main() ->
    io:fwrite("Distant main called~n"),

    DataDict = dict:new(),

    receive
        {are_you_alive, Pid} -> Pid ! yes ;

        {store_data, Data, Status, Pid} ->
            case Status of
                simple -> io:fwrite("store data SIMPLE~n");
                distributed -> io:fwrite("store data DISTRIBUTED~n");
                critical -> io:fwrite("store data CRITICAL~n");
                _ -> io:fwrite("received store_data instruction with invalid status !~n")
            end,
            Pid ! ack;

        {fetch_data, DataName, Pid} -> io:fwrite("fetch data~n")
    end.
