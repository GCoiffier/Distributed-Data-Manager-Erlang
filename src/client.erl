-module(client).

%% -----------------------------------------------------------------------------

-import(storage, [distant_main/0]).

%% -----------------------------------------------------------------------------
-export([run/0]).

-export([send_data/2]).
-export([fetch_data/1]).

-export([compile/2, send_code/2]).

%% -----------------------------------------------------------------------------

-define(MAX_SON, 10).
-define(TIMEOUT_TIME, 1000).

%% -----------------------------------------------------------------------------

-on_load(run/0).


run() ->
    io:fwrite("Initializing~n"),
    register(client,self()),
    Pid = spawn(storage, distant_main, []),

    case whereis(test) of
        undefined -> register(test,Pid);
        _ -> ok
    end,

    test ! {are_you_alive, self()},
    receive
        yes -> io:fwrite("Spawning successful~n")
    after ?TIMEOUT_TIME ->
        io:fwrite("Time out~n")
    end.

send_data(Filename,Status) ->
    %%
    % Reads data from Filename and send it to the network
    % Three storage mode are possible
    %     - Simple : the data is stored in one chunk in one process
    %     - Distributed : the data is cut in parts and stored in various processes
    %     - Critical : the data is copied several times and stored in whole in different processes
    %%

    case Status of
        simple -> io:fwrite("Storage mode = SIMPLE~n");
        distributed -> io:fwrite("Storage mode = DISTRIBUTED~n");
        critical -> io:fwrite("Storage mode = CRITICAL~n");
        _ -> io:fwrite("Storage mode should be in {simple,distributed,critical}. Aborting.~n"),
             exit(send_data)
    end,

    Data = readlines(Filename),
    io:fwrite("Data to be sent : ~p~n", [Data]),

    test ! {store_data, {Filename, Data, Status, self()}},
    receive
        ack -> io:fwrite("Success.~n");
        fail -> io:fwrite("Failed.~n")
    after ?TIMEOUT_TIME ->
        io:fwrite("No acknowledgment received. Assuming data sending failed.~n")
    end.


fetch_data(Filename) -> readlines(Filename).

readlines(Filename) ->
    io:fwrite("reading lines from file ~p... ", [Filename]),
    {ok, Data} = file:read_file(Filename),
    binary:split(Data, [<<"\n">>], [global]),
    io:fwrite("Done.~n"),
    binary:bin_to_list(Data).


% asks ID to compile Filename
compile(ID, Filename) -> spawn(ID, compile, file, [Filename]).

% sends a code
send_code(ID, Module) -> {Mod, Bin, File} = code:get_object_code(Module),
                        spawn(ID, code, load_binary, [Mod, File, Bin]).
