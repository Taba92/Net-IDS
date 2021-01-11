-module(flowsBuilderWatcher).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/FlowsBuilder/"),
	supervisor:start_link({local,flowsBuilderWatcher},?MODULE,[]).
	
init([])->
	SupFlags = #{strategy=>one_for_one,intensity=>10,period=>1},
    ChildSpecs = [
    	#{id =>flowsStorage,start=>{flowsStorage,init,[]},restart=>permanent,type=>worker},
		#{id =>netFlow,start=>{netFlow,init,[]},restart=>permanent,type=>worker}
    ],
    {ok, {SupFlags, ChildSpecs}}.
