-module(logInit).
-export([init/0]).

handlers_id()->
	[logLogger,sysLogger,packetLogger,flowLogger].

init()->
	logger:remove_handler(default),
	logger:set_primary_config(level,all),
	[logger:add_handler(Id,Id,Id:config())||Id<-handlers_id()].
