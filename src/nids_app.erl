-module(nids_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->nids_app_sup:start_link().

stop(_State) ->
    ok.

