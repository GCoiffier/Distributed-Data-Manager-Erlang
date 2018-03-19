-module(distant).

%% ----------------------------------------------------------------------------
-export([distant_main/1]).
%% ----------------------------------------------------------------------------

distant_main(Name) -> register(Name,self()),
                      receive {are_you_alive, Pid} -> Pid ! yes end.
