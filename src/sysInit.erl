-module(sysInit).
-export([init/0,init/1]).

init()->gen_server:start({local,sysInit},?MODULE,[],[]).

init([])->
   gen_server:start({local,options},optionsGraphic,[],[]),
   logInit:init(),
   nidsInit:init(),
   {ok,null}.
