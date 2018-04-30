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
-define(QUERY_TIMEOUT_TIME, 100).
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
        case rand:uniform(?FREQUENCY_MASTER_CHECK) of
            1 -> check_master(Neighbours);
            _ -> ok
        end,
        case rand:uniform(?FREQUENCY_LEADER_CHANGE) of
            1 ->  ?LOG("Started a leader election"),
                  lists:map( fun (X) -> X ! election end, sets:to_list(Neighbours)),
                  query_run(Children,Neighbours,leader_election(Neighbours));
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
        election -> query_run(Children, Neighbours, leader_election(Neighbours));

        % -- Birth / Death of processes --
        {new_child, Pid} -> query_run(maps:put(Pid,0,Children), Neighbours, IsLeader);

        {kill_child, Pid} -> query_run(maps:remove(Pid,Children), Neighbours, IsLeader);

        {new_query, Pid} -> query_run(Children, sets:add_element(Pid,Neighbours), IsLeader);

        {kill_query, Pid} -> query_run(Children, sets:del_element(Pid,Neighbours), IsLeader);

        {kill} ->
            lists:map(fun (Pid) -> Pid ! {kill_query, self()} end, Neighbours);
            % simply don't call back query_run

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

        {get_client, Type, Request} -> % message received from a client
            % Type = (fetch_data | release_data) , important only for storage nodes
            {DataInfo, ClientPid} = Request,
            {StorageType, _, _} = DataInfo,
            NeighbourAnswer = lists:map( fun (X) ->
                                            X ! {get_query, Type, DataInfo, self()},
                                            receive {reply, R} -> R
                                            after ?QUERY_TIMEOUT_TIME -> no_response
                                            end
                                         end,
                                         sets:to_list(Neighbours)),
            Answers = lists:concat(lists:filter(fun(L) -> length(L)>0 end, [find_among_children(Type,DataInfo,Children) | NeighbourAnswer])),
            ?LOG(Answers),
            case StorageType of
                simple -> send_data_back_simple(ClientPid, Answers);
                distributed -> send_data_back_distributed(ClientPid, Answers);
                critical -> send_data_back_critical(ClientPid, Answers);
                _ -> ?LOG("received get_data instruction with invalid status !")
            end,
            query_run(Children, Neighbours, IsLeader);

        {get_query, Type, DataInfo, QueryPid} -> % message received from another query node
            QueryPid ! {reply, find_among_children(Type, DataInfo, Children)},
            query_run(Children, Neighbours, IsLeader);

        % -- default case --
        X -> ?LOG({"Received something unusual", X}),
             query_run(Children, Neighbours, IsLeader)

    after ?RESET_TIME ->
        query_run(Children, Neighbours, IsLeader)
    end.

% ------------------- Storage calls functions  -------------------------

store_data_simple(Children, Dataname, DataSize, Data, ClientPid) ->
    case find_min_load(Children) of
        full ->
            ClientPid ! fail,
            Children;
        Node ->
            UUID = get_uuid(),
            Node ! {store_data, {Dataname, UUID, Data}},
            ClientPid ! {ack, {simple, Dataname, UUID}},
            UpdatedChildren =  maps:update(Node, fun (Old) -> Old+DataSize end, Children),
            UpdatedChildren
    end.

store_data_distributed(Children, Dataname, DataSize, Data, ClientPid) ->
    store_data_distributed_aux(Children, maps:keys(Children), get_uuid(), Dataname, split_data(Data), ClientPid, 1).

store_data_distributed_aux(Children, [], UUID, Dataname, _, ClientPid, _) ->
    ClientPid ! {ack, {distributed, Dataname, UUID}},
    Children;

store_data_distributed_aux(Children, [C|L], UUID, Dataname, [D|L2], ClientPid, N) ->
    C ! {store_data, {Dataname, UUID, {N,D}}},
    store_data_distributed_aux(Children, L, UUID, Dataname, L2, ClientPid, N+1).

store_data_critical(Children, Dataname, DataSize , Data, ClientPid) ->
    UUID = get_uuid(),
    lists:map(fun (Node) -> Node ! {store_data, {Dataname, UUID, Data}} end, maps:keys(Children)),
    UpdatedChildren = lists:foldl(fun (Node,M) -> maps:update(Node, fun (Old) -> Old+DataSize end, M) end, Children, maps:keys(Children)),
    ClientPid ! {ack, {critical, Dataname, UUID}},
    UpdatedChildren.

find_among_children(Type, DataInfo, Children) ->
    % Type = (fetch_data | release_data)
    L = lists:map(fun (X) ->
                X ! {Type, DataInfo, self()},
                receive {reply, R} -> R
                after ?QUERY_TIMEOUT_TIME -> no_response
                end
              end,
              maps:keys(Children)),
    lists:filter(fun (X) -> (X /= not_found) and (X /= no_response) end, L).

send_data_back_simple(ClientPid, Answers) ->
    case length(Answers) of
        0 -> ClientPid ! not_found;
        _ -> ClientPid ! {data, hd(Answers)}
    end.

send_data_back_distributed(ClientPid,Answers) ->
    case length(Answers) of
        0 -> ClientPid ! not_found;
        _ -> ClientPid ! {data, merge_data(Answers)}
    end.

send_data_back_critical(ClientPid, Answers) ->
    % exactly the same protocol, except that the data is now present several times in 'answer'
    send_data_back_simple(ClientPid, Answers).

% ------------------- Utility function working on data -------------------------
% % % % % %
% Splits Data into ?NB_STORAGE_NODE chunks of equal size
% % % % % %
split_data(List) -> split_data(List, ?NB_STORAGE_NODE).

split_data([], _) -> [];
split_data(L, K) -> split_data_aux(L, length(L), K, K).
split_data_aux(L, N, K, 1) -> [L];
split_data_aux(L, N, K, M) ->
    {A, B} = lists:split(N div K, L),
    [A | split_data_aux(B, N, K, M-1)].


% % % % % %
% Merge a list of chunks of data
% % % % % %
merge_data(DataList) ->
    Data = sets:to_list(sets:from_list(lists:flatten(DataList))), %get rid of duplicates
    Data2 = lists:sort(fun(A,B) -> {N,_} = A, {M,_} = B, N=<M end, Data),
    ?LOG(Data2),
    Data3 = lists:map(fun ({N,X}) -> X end, Data2),
    ?LOG(Data3),
    Data4 = lists:flatten(Data3),
    ?LOG(Data4),
    Data4.

% ------------------- Utility functions misc  -------------------------

% % % %
% Elect a new leader
% % % %
leader_election(Neighbours) ->
    MyNum = rand:uniform(10000000),
    lists:map(fun (X) -> X ! {id, MyNum} end, sets:to_list(Neighbours)),
    case leader_election_aux(MyNum) of
        MyNum -> ?LOG("end of leader election. I am the new leader"), true;
        _ -> false
    end.

leader_election_aux(Num) ->
    receive {id,Num2} -> leader_election_aux(min(Num,Num2))
    after 1000 -> Num
    end.

% % % % % %
% Returns the Pid and the load of the child with minimal load.
% % % % % %
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

% % % % % %
% Returns a unique (with high probability) identifier
% % % % % %
get_uuid() ->
    {{A,B,C},{D,E,F}} = calendar:universal_time(),
    {A,B,C,D,E,F, rand:uniform(1000000000)}.

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
