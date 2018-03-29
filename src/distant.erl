-module(distant).

%% ----------------------------------------------------------------------------
-export([distant_main/1]).

%% ----------------------------------------------------------------------------

init_distant(Name) ->
    register(Name,self()),
    receive {are_you_alive, Pid} -> Pid ! yes end.


distant_main(Name) -> try init_distant(Name) of
                        _ -> ok
                      catch
                        _ -> {exit, caught, Exit}
                      end.
