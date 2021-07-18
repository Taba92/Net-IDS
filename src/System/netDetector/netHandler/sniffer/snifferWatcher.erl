-module(snifferWatcher).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/Sniffer/"),
	supervisor:start_link({local,snifferWatcher},?MODULE,[]).
init([])->
	SupFlags = #{strategy=>one_for_one,intensity=>10,period=>1},
    ChildSpecs = [
    	#{id =>netProcesser,start=>{netProcesser,init,[]},restart=>permanent,type=>worker},
		#{id =>layer4,start=>{layer4,init,[]},restart=>permanent,type=>worker},
		#{id =>layer3,start=>{layer3,init,[]},restart=>permanent,type=>worker},
		#{id =>layer2,start=>{layer2,init,[]},restart=>permanent,type=>worker},
		#{id =>sniffer,start=>{sniffer,init,[]},restart=>permanent,type=>worker}
    ],
    {ok, {SupFlags, ChildSpecs}}.