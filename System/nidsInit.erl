-module(nidsInit).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/netDetector/"),
	code:add_patha(CurDir++"/netDefense/"),
	supervisor:start_link({local,nidsInit},?MODULE,[]).

init([])->
	SupFlags = #{strategy=>one_for_one,intensity=>10,period=>1},
	ChildSpecs=case ets:lookup(opts,netdefense) of
		[{_,true}]->
			[
			#{id =>netDetector,start=>{netDetector,init,[]},restart=>permanent,type=>supervisor},
			#{id =>netDefender,start=>{netDefender,init,[]},restart=>permanent,type=>supervisor}
   	 		];
		[{_,false}]->
			[
			#{id =>netDetector,start=>{netDetector,init,[]},restart=>permanent,type=>supervisor}
   	 		]
	end,
	 {ok, {SupFlags, ChildSpecs}}.
