-module(flowLogger).
-export([config/0,log/2,adding_handler/1]).
-include("../include/packetFlow.hrl").
-include("../include/log.hrl").

adding_handler(Config) ->
	{ok,Config}.

log(LogEvent,Config)->	
	{Module,Formatter}=maps:get(formatter,Config),
	String = Module:format(LogEvent, Formatter),
	#{file:=FileName}=maps:get(config,Config),
	file:write_file(FileName,String,[append]).

config()->
	#{config => #{file => ?LOGDIR++"/flows.log"},
		level=>info,
		filters=>[{flowFilter,{fun funFilter/2,null}}],
		formatter=>{logger_formatter,#{legacy_header=>true,single_line=>false}}
		}.

funFilter(#{level:=info,msg:={report,[{flow,FlowId,FlowInfo,Prediction}]},meta:=Meta},_)->
	#flowId{ipSrc=IpSrc,ipDst=IpDst,portSrc=PortSrc,portDst=PortDst,protoTrans=ProtoTrans,protoService=ProtoService}=FlowId,
	InfoFlowId=[{ipSrc,IpSrc},{ipDst,IpDst},{portSrc,PortSrc},{portDst,PortDst},{protoTrans,ProtoTrans},{protoService,ProtoService}],
	#flowInfo{numberOfPackets=Num,sizeBytes=Size,start=StartMillisec,finish=FinishMillisec}=FlowInfo,
	{_,Start}=calendar:system_time_to_local_time(StartMillisec,1000000),
	{_,Finish}=calendar:system_time_to_local_time(FinishMillisec,1000000),
	InfoFlowInfo=[{numberOfPackets,Num},{sizeBytes,Size},{start,Start},{finish,Finish}],
	#{level=>info,msg=>{report,InfoFlowId++InfoFlowInfo++[{prediction,Prediction}]},meta=>Meta};
funFilter(_,_)->
	stop.