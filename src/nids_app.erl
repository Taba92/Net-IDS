-module(nids_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    sysInit:init().

stop(_State) ->
    ok.

