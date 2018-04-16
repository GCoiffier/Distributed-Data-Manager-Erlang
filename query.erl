-module(query).
%% -----------------------------------------------------------------------------
-import(storage, [storage_init/0]).
-import(server, [server_run/1]).
%% ----------------------------------------------------------------------------
-export([query_init/2]).
%% ----------------------------------------------------------------------------
-define(DEBUG,true).
-ifdef(DEBUG).
-define(LOG(X), io:format("<Module ~p, Line ~p> : ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

-define(NB_STORAGE_NODE,5).
-define(RESET_TIME, 1000).
-define(MASTER_TIMEOUT_TIME, 1000).
-define(FREQUENCY_MASTER_CHECK, 5).
-define(FREQUENCY_LEADER_CHANGE, 50).
%% ----------------------------------------------------------------------------

query_init(N, IsLeader) ->
    receive
        {other_query_nodes, QueryNodes} -> query_init(N, ?NB_STORAGE_NODE, sets:new(), sets:del_element(self(), QueryNodes), IsLeader)
    end.

query_init(N, 0, Children, Neighbours, IsLeader) ->
    lists:map(fun (Pid) -> Pid ! {new_father,self()} end, sets:to_list(Children)),
    ?LOG({"Query node init OK", N, IsLeader}),
    query_run(Children, Neighbours, IsLeader);

query_init(N, M, Children, Neighbours, IsLeader) ->
    Pid = spawn(storage, storage_init, []),
    query_init(N, M-1, sets:add_element(Pid,Children), Neighbours, IsLeader).

query_run(Children, Neighbours, IsLeader) ->
    if IsLeader ->
        case random:uniform(?FREQUENCY_MASTER_CHECK) of
            1 -> check_master(Neighbours);
            _ -> ok
        end,

            case random:uniform(?FREQUENCY_LEADER_CHANGE) of
                1 -> ok;
                _ -> ok
            end;
        true -> ok
    end,

    receive
        {ping, Pid} ->
            % ?LOG("I was Pinged !"),
            Pid ! pong,
            query_run(Children, Neighbours, IsLeader);

        {display, Mess} ->
            io:fwrite("~p~n",[Mess]),
            query_run(Children, Neighbours, IsLeader);

        % -- Leader election protocol --



        % -- Birth / Death of processes --
        {new_child, Pid} -> query_run(sets:add_element(Pid,Children), Neighbours, IsLeader);

        {kill_child, Pid} -> query_run(sets:del_element(Pid,Children), Neighbours, IsLeader);

        {new_query, Pid} -> query_run(Children, sets:add_element(Pid,Neighbours), IsLeader);

        {kill_query, Pid} -> query_run(Children, sets:del_element(Pid,Neighbours), IsLeader);

        {kill} ->
            ?LOG("Someone asked me to commit suicide!"),
            lists:map(fun (Pid) -> Pid ! {kill_query, self()} end, Neighbours);

        % -- Data protocol --
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
            query_run(Children, Neighbours, IsLeader);

        {fetch_data, Request} ->
            {Dataname, Pid} = Request,
            query_run(Children, Neighbours, IsLeader);

        {release_data, Request} ->
            {Dataname, Pid} = Request,
            query_run(Children, Neighbours, IsLeader);

        % -- default case --
        _ -> ?LOG("Received something unusual"),
             query_run(Children, Neighbours, IsLeader)
    after ?RESET_TIME ->
        query_run(Children, Neighbours, IsLeader)
    end.

check_master(NodeSet) ->
    try
        master ! {ping, self()},
        receive
            {pong,_} -> ok
        after ?MASTER_TIMEOUT_TIME ->
            ?LOG("Disconnected from master. Restarting master node")
        end
    of
        ok -> ok
    catch error:badarg ->
        NewMasterPid = spawn(server,server_run,[sets:add_element(self(),NodeSet)]),
        register(master,NewMasterPid)
    end.

% ------------------- Utility function working on data -------------------------
split_data(Data) -> Data.

merge_data(DataList) -> DataList.
