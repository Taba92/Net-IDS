-module(packetLogger).
-export([config/0,log/2,adding_handler/1]).
-include("$PWD/Headers/packetFlow.hrl").

adding_handler(Config) ->
	{ok,Config}.

log(LogEvent,Config)->	
	{Module,Formatter}=maps:get(formatter,Config),
	String = Module:format(LogEvent, Formatter),
	#{file:=FileName}=maps:get(config,Config),
	file:write_file(FileName,String,[append]).

config()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	#{config => #{file => CurDir++"/packets.log"},
		level=>info,
		filters=>[{packetFilter,{fun funFilter/2,null}}],
		formatter=>{logger_formatter,#{legacy_header=>true,single_line=>false}}
		}.

funFilter(#{level:=info,msg:={report,[{packet,Packet}]},meta:=Meta},_)->
	#packet{millisec=MilliSec,ethHeader=EthHeader}=Packet,
	#{macDst:=MacDst,macSrc:=MacSrc}=EthHeader,
	InfoPacket=[{macSrc,MacSrc},{macDst,MacDst}],
	FlowId=flowUtils:getFlowId(Packet),
	#flowId{ipSrc=IpSrc,ipDst=IpDst,portSrc=PortSrc,portDst=PortDst,protoTrans=ProtoTrans,protoService=ProtoService}=FlowId,
	PacketId=[{ipSrc,IpSrc},{ipDst,IpDst},{portSrc,PortSrc},{portDst,PortDst},{protoTrans,ProtoTrans},{protoService,ProtoService}],
	#{pid:=Pid,gl:=Gl,time:=_}=Meta,
	NewMeta=#{pid=>Pid,gl=>Gl,time=>round(MilliSec*1000)},
	#{level=>info,msg=>{report,InfoPacket++PacketId},meta=>NewMeta};
funFilter(_,_)->
	stop.