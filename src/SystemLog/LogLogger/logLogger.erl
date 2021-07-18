-module(logLogger).
-export([log/2,adding_handler/1,config/0]).

adding_handler(Config) ->
	{ok,Config}.

log(LogEvent,Config)->	
	{Module,Formatter}=maps:get(formatter,Config),
	String = Module:format(LogEvent, Formatter),
	#{file:=FileName}=maps:get(config,Config),
	file:write_file(FileName,String,[append]).

config()->
	#{config => #{file => "../priv/logsErr.log"},
		level=>debug,
		filters=>[{flowFilter,{fun funFilter/2,null}}],
		formatter=>{logger_formatter,#{legacy_header=>true,single_line=>false}}
		}.

funFilter(#{level:=debug,msg:=Msg,meta:=Meta},_)->
	#{level=>debug,msg=>Msg,meta=>Meta};
funFilter(_,_)->
	stop.