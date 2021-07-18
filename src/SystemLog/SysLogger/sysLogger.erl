-module(sysLogger).
-export([config/0,log/2,adding_handler/1]).
-include("../include/log.hrl").

adding_handler(Config) ->
	sysAnalyzer:init(),
	{ok,Config}.

log(LogEvent,Config)->
	{Module,Formatter}=maps:get(formatter,Config),
	String = Module:format(LogEvent, Formatter),
	#{errLog:=FileLog}=maps:get(config,Config),
	file:write_file(FileLog,String,[append]).

config()->
	#{config => #{errLog => ?LOGDIR++"/sysLog.log"},
		level=>error,
		filters=>[{packetFilter,{fun funFilter/2,null}}],
		formatter=>{logger_formatter,#{legacy_header=>true,single_line=>false}}
		}.

funFilter(Log,null) when map_get(level,Log)==error->
	case whereis(sysAnalyzer) of
		undefined->stop;
		_-> sysAnalyzer ! Log,
			Log
	end;
funFilter(Log,null)->
	Log.