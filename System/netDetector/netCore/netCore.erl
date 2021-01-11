-module(netCore).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/dbHandler/DbHandler/"),
	code:add_patha(CurDir++"/decisor/Decisor/"),
	supervisor:start_link({local,netCore},?MODULE,[]).

init([])->
	SupFlags = #{strategy=>one_for_all,intensity=>10,period=>1},
	ChildSpecs = [
		#{id=>erlDecisor,start=>{erlDecisor,init,[]},restart=>permanent,type=>worker},
		#{id =>dbHandler,start=>{dbHandler,init,[]},restart=>permanent,type=>worker}
    ],
    {ok, {SupFlags, ChildSpecs}}.
