-module(logInit).
-export([init/0]).

handlers_id()->
	[logLogger,sysLogger,packetLogger,flowLogger].

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/SysLogger/"),
	code:add_patha(CurDir++"/PacketLogger/"),
	code:add_patha(CurDir++"/FlowLogger/"),
	code:add_patha(CurDir++"/LogLogger/"),
	logger:remove_handler(default),
	logger:set_primary_config(level,all),
	[logger:add_handler(Id,Id,Id:config())||Id<-handlers_id()].
