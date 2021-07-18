-module(netDefender).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/DefenseLayer1/"),
	supervisor:start_link({local,netDefender},?MODULE,[]).
	
init([])->
	SupFlags = #{strategy=>one_for_one,intensity=>10,period=>1},
	ChildSpecs=[
		#{id =>defenseLayer1,start=>{defenseLayer1,init,[]},restart=>permanent,type=>worker}
   	 ],
	 {ok, {SupFlags, ChildSpecs}}.