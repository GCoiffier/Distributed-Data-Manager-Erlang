-module(main).

%% -----------------------------------------------------------------------------

-import(storage, [distant_main/0]).

%% -----------------------------------------------------------------------------
-export([run/0]).

-export([send_data/2]).
-export([fetch_data/1]).

-export([compile/2, send_code/2]).

%% -----------------------------------------------------------------------------

-define(MAX_SON, 10).

-define(RING_SIZE_SMALL, 5).
-define(RING_SIZE_MEDIUM, 10).
-define(RING_SIZE_LARGE, 20).

%% -----------------------------------------------------------------------------

-on_load(run/0).


run() ->
    io:fwrite("Initializing~n"),
    register(client,self()),
    Pid = spawn(storage, distant_main, []),
    register(test,Pid),
    test ! {are_you_alive, self()},
    receive
        yes -> io:fwrite("Spawning successful~n")
    after 5000 ->
        io:fwrite("Time out~n")
    end.

send_data(FileName,Status) ->
    %%
    % Reads data from FileName and send it to the network
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

    test ! {store_data, FileName, Status, self()},

    receive
        ack -> io:fwrite("ok~n")
    end.


fetch_data(FileName) -> readlines(FileName).

readlines(FileName) ->
    {ok, Data} = file:read_file(FileName),
    binary:split(Data, [<<"\n">>], [global]).


% asks ID to compile Filename
compile(ID, Filename) -> spawn(ID, compile, file, [Filename]).

% sends a code
send_code(ID, Module) -> {Mod, Bin, File} = code:get_object_code(Module),
                        spawn(ID, code, load_binary, [Mod, File, Bin]).
