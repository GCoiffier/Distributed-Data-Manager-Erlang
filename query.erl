-module(query).
%% -----------------------------------------------------------------------------
-import(storage, [storage_init/0]).
-import(server, [server_run/1]).
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
-define(MAX_STORAGE_CAPACITY, 1024*1024*1024).
-define(RESET_TIME, 1000).
-define(MASTER_TIMEOUT_TIME, 1000).
-define(FREQUENCY_MASTER_CHECK, 5).
-define(FREQUENCY_LEADER_CHANGE, 50).
%% ----------------------------------------------------------------------------

query_init(IsLeader) ->
    receive
        {other_query_nodes, QueryNodes} -> query_init(?NB_STORAGE_NODE, maps:new(), sets:del_element(self(), QueryNodes), IsLeader)
    end.

query_init(0, Children, Neighbours, IsLeader) ->
    lists:map(fun (Pid) -> Pid ! {new_father,self()} end, maps:keys(Children)),
    ?LOG({"Query node init OK", IsLeader}),
    query_run(Children, Neighbours, IsLeader);

query_init(M, Children, Neighbours, IsLeader) ->
    Pid = spawn(storage, storage_init, []),
    query_init(M-1, maps:put(Pid,0,Children), Neighbours, IsLeader).

query_run(Children, Neighbours, IsLeader) ->
    if IsLeader ->
        case random:uniform(?FREQUENCY_MASTER_CHECK) of
            1 -> check_master(Neighbours);
            _ -> ok
        end,
        case random:uniform(?FREQUENCY_LEADER_CHANGE) of
            1 -> ok; % TODO : leader election
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
        {new_child, Pid} -> query_run(maps:put(Pid,0,Children), Neighbours, IsLeader);

        {kill_child, Pid} -> query_run(maps:remove(Pid,Children), Neighbours, IsLeader);

        {new_query, Pid} -> query_run(Children, sets:add_element(Pid,Neighbours), IsLeader);

        {kill_query, Pid} -> query_run(Children, sets:del_element(Pid,Neighbours), IsLeader);

        {kill} ->
            ?LOG("Someone asked me to commit suicide!"),
            lists:map(fun (Pid) -> Pid ! {kill_query, self()} end, Neighbours);

        % -- Data protocol --
        {store_data, Request} ->
            {Dataname, DataSize, Data, Status, Pid} = Request,
            case Status of
                simple -> UpdatedChildren = store_data_simple(Children, Dataname, DataSize, Data, Pid);

                distributed -> UpdatedChildren = store_data_distributed(Children, Dataname, DataSize, Data, Pid);

                critical -> UpdatedChildren = store_data_critical(Children, Dataname, DataSize, Data, Pid);

                _ ->
                    ?LOG("received store_data instruction with invalid status !"),
                    Pid ! fail,
                    UpdatedChildren = Children
            end,
            query_run(UpdatedChildren, Neighbours, IsLeader);

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

% ------------------- Storage calls functions  -------------------------

store_data_simple(Children, Dataname, DataSize, Data, Pid) ->
    case find_min_load(Children) of
        full ->
            Pid ! fail,
            Children;

        Node ->
            Node ! {store_data, {Dataname, 0, Data}},
            UpdatedChildren =  maps:update(Node, fun (Old) -> Old+DataSize end, Children),
            Pid ! {ack, {Dataname, Node}},
            UpdatedChildren
    end.

store_data_distributed(Children,Dataname, DataSize, Data, Pid) ->
    Pid ! {ack, {self()}},
    Children.

store_data_critical(Children,Dataname, DataSize, Data, Pid) ->
    Pid ! {ack, {self()}},
    Children.


% ------------------- Utility function working on data -------------------------
split_data(Data) -> Data.

merge_data(DataList) -> DataList.

% ------------------- Utility functions misc  -------------------------

% % % % %
% Returns the Pid and the load of the child with minimal load.
% % % % %
find_min_load(Children) ->
    {Node, Load} = lists:foldl(fun (X,R) -> if
                                                element(2,X) < element(2,R) -> X;
                                                true -> R
                                            end end,
                                {void, ?MAX_STORAGE_CAPACITY},
                                maps:to_list(Children) ),
    case Load of
        ?MAX_STORAGE_CAPACITY -> full;
        _ -> Node
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
