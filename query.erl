-module(query).
%% -----------------------------------------------------------------------------
-import(storage, [storage_init/0]).
%% ----------------------------------------------------------------------------
-export([query_init/1]).
%% ----------------------------------------------------------------------------
-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

-define(NB_STORAGE_NODE,5).
%% ----------------------------------------------------------------------------

query_init(N) ->
    ?LOG({"Query node init", N}),
    receive
        {other_query_nodes, QueryNodes} -> query_init(N, ?NB_STORAGE_NODE, sets:new(), sets:del_element(self(), QueryNodes))
    end.

query_init(N, 0, Children, Neighbours) ->
    lists:map(fun (Pid) -> Pid ! {new_father,self()} end, sets:to_list(Children)),
    query_run(Children, Neighbours);

query_init(N, M, Children, Neighbours) ->
    Pid = spawn(storage, storage_init, []),
    query_init(N, M-1, sets:add_element(Pid,Children), Neighbours).

query_run(Children, Neighbours) ->
    receive
        {ping, Pid} ->
            ?LOG("Ping received !"),
            Pid ! pong,
            query_run(Children, Neighbours);

        {new_child, Pid} -> query_run(sets:add_element(Pid,Children), Neighbours);

        {kill_child, Pid} -> query_run(sets:del_element(Pid,Children), Neighbours);

        {new_query, Pid} -> query_run(Children, sets:add_element(Pid,Neighbours));

        {kill_query, Pid} -> query_run(Children, sets:del_element(Pid,Neighbours));

        {store_data, Request} ->
            {Dataname, Data, Status, Pid} = Request,
            case Status of
                simple ->
                    Pid ! ack;
                distributed ->
                    Pid ! ack;
                critical ->
                    Pid ! ack;
                _ ->
                    io:fwrite("received store_data instruction with invalid status !"),
                    Pid ! fail
            end,
            query_run(Children, Neighbours);

        {fetch_data, Request} ->
            {Dataname, Pid} = Request,
            query_run(Children, Neighbours);

        {release_data, Request} ->
            {Dataname, Pid} = Request,
            query_run(Children, Neighbours);

        {kill} ->
            ?LOG("Someone asked me to commit suicide!"),
            lists:map(fun (Pid) -> Pid ! {kill_query, self()} end, Neighbours);

        _ -> ?LOG("Received something unusual"),
             query_run(Children, Neighbours)
    end.

% ------------------- Utility function working on data -------------------------
split_data(Data) -> Data.

merge_data(DataList) -> DataList.
