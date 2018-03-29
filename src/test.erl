-module(test).

%% -----------------------------------------------------------------------------

%% -----------------------------------------------------------------------------
%-export([init_process/1]).
-export([message/2]).
-export([compile/2]).
-export([send_code/2]).
-export([readlines/1]).
%% -----------------------------------------------------------------------------

readlines(FileName) ->
    {ok, Data} = file:read_file(FileName),
    binary:split(Data, [<<"\n">>], [global]).

%init_process(Name) -> PID = spawn(distant,distant_main,[Name]),
%                      Name ! {are_you_alive}
%                      receive {yes} -> erlang:display("ok") end.

% Displays message Mess to process ID's shell
message(ID,Mess) -> spawn(ID, erlang, display, [Mess]).

% asks ID to compile Filename
compile(ID, Filename) -> spawn(ID, compile, file, [Filename]).

% sends a code
send_code(ID, Module) -> {Mod, Bin, File} = code:get_object_code(Module),
                        spawn(ID, code, load_binary, [Mod, File, Bin]).
