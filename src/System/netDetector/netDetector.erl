-module(netDetector).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->supervisor:start_link({local,netDetector},?MODULE,[]).
	
init([])->
	SupFlags = #{strategy=>one_for_one,intensity=>10,period=>1},
    ChildSpecs = [
		#{id =>netCore,start=>{netCore,init,[]},restart=>permanent,type=>supervisor},
		#{id =>featuresExtractorWatcher,start=>{featuresExtractorWatcher,init,[]},restart=>permanent,type=>supervisor},
		#{id =>netHandler,start=>{netHandler,init,[]},restart=>permanent,type=>supervisor}
    ],
    {ok, {SupFlags, ChildSpecs}}.
