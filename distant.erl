-module(distant).

%% ----------------------------------------------------------------------------
-export([main/0]).
-export([message/2]).
-export([compile/2]).
-export([send_code/2]).
%% ----------------------------------------------------------------------------

main() -> receive()

% Displays message Mess to process ID's shell
message(ID,Mess) -> spawn(ID, erlang, display, [Mess]).

% asks ID to compile Filename
compile(ID, Filename) -> spawn(ID, compile, file, [Filename]).

% sends a code
send_code(ID, Module) -> {Mod, Bin, File} = code:get_object_code(Module),
                        spawn(ID, code, load_binary, [Mod, File, Bin]).
