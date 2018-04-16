-module(query).
%% -----------------------------------------------------------------------------
-import(storage, [storage_init/0]).
-import(server, [server_run/0]).
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
-define(MASTER_TIMEOUT_TIME, 10000).
-define(FREQUENCY_MASTER_CHECK, 5).
-define(FREQUENCY_LEADER_CHANGE, 50).
%% ----------------------------------------------------------------------------

query_init(N, IsLeader) ->
    % ?LOG({"Query node init", N}),
    receive
        {other_query_nodes, QueryNodes} -> query_init(N, ?NB_STORAGE_NODE, sets:new(), sets:del_element(self(), QueryNodes), IsLeader)
    end.

query_init(N, 0, Children, Neighbours, IsLeader) ->
    lists:map(fun (Pid) -> Pid ! {new_father,self()} end, sets:to_list(Children)),
    query_run(Children, Neighbours, IsLeader);

query_init(N, M, Children, Neighbours, IsLeader) ->
    Pid = spawn(storage, storage_init, []),
    query_init(N, M-1, sets:add_element(Pid,Children), Neighbours, IsLeader).

query_run(Children, Neighbours, IsLeader) ->
    if IsLeader ->
            case random:uniform(?FREQUENCY_MASTER_CHECK) of
                1 -> io:fwrite("Pinging master~n"), check_master(Neighbours);
                _ -> ok
            end,

            case random:uniform(?FREQUENCY_LEADER_CHANGE) of
                1 -> ok;
                _ -> ok
            end;
        true -> ok,

    receive
        {ping, Pid} ->
            % ?LOG("I was Pinged !"),
            Pid ! pong,
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
    end.

check_master(NodeSet) ->
    master ! {ping, self()},
    receive
        pong -> ok
    after ?MASTER_TIMEOUT_TIME ->
        ?LOG("Disconnected from master"),
        unregister(master),
        Pid = spawn(setup,server_run,[sets:add_element(self(),NodeSet)]),
        register(master,Pid)
    end.

% ------------------- Utility function working on data -------------------------
split_data(Data) -> Data.

merge_data(DataList) -> DataList.
