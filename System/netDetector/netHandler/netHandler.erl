-module(netHandler).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/sniffer/"),
	code:add_patha(CurDir++"/flowsBuilder/"),
	supervisor:start_link({local,netHandler},?MODULE,[]).

init([])->
	SupFlags = #{strategy=>one_for_one,intensity=>10,period=>1},
    ChildSpecs = [
    	#{id =>flowsBuilderWatcher,start=>{flowsBuilderWatcher,init,[]},restart=>permanent,type=>supervisor},
		#{id =>snifferWatcher,start=>{snifferWatcher,init,[]},restart=>permanent,type=>supervisor}
    ],
    {ok, {SupFlags, ChildSpecs}}.