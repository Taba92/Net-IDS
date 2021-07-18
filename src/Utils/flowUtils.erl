-module(flowUtils).
-export([getPairDirections/1,getFlowId/1,getDualFlow/1,getFlowInfo/1,getSizePacket/1,order/2]).
-export([notifyFlow/2]).
-include("../include/packetFlow.hrl").
-define(TUPLESTRING(Tuple),lists:flatten(io_lib:format("~p", [Tuple]))).
-define(STRINGIFY(Val),case is_integer(Val) of true->integer_to_list(Val);false->atom_to_list(Val) end).

getPairDirections(BidirectionalFlow)->%dato un flusso BIDIREZIONALE ne estrapola i due flussi MONODIREZIONALI
	FlowId=getFlowId(hd(BidirectionalFlow)),
	case (FlowId==getDualFlow(FlowId)) of
		false->
			A=fun(PacketData)->%se ip sorgente=ip sorgente nel pacchetto E (se c'è) la porta sorgente= porta sorgente del pacchetto
				FlowId==getFlowId(PacketData)
			end,
			{FlowSrcToDst,FlowDstToSrc}=lists:partition(A,BidirectionalFlow);
		true->
			{FlowSrcToDst,FlowDstToSrc}={BidirectionalFlow,BidirectionalFlow}
	end,
	{FlowSrcToDst,FlowDstToSrc}.

getFlowId(PacketData)->%dato un PACCHETTO,genera un record (flowId) che contiene i dati del flusso UNIDIREZIONALE a cui il pacchetto appartiene!
	DatagramHeader=PacketData#packet.datagramHeader,
	{IpSrc,IpDst}={maps:get(ipSrc,DatagramHeader),maps:get(ipDst,DatagramHeader)},
	ProtoTrans=getProtoTransaction(PacketData),
	case ((PacketData#packet.fragmentHeader/= undefined) andalso (maps:is_key(portDst,PacketData#packet.fragmentHeader))) of
		false->
			#flowId{ipSrc=IpSrc,ipDst=IpDst,protoTrans=ProtoTrans};
		true->
			FragmentHeader=PacketData#packet.fragmentHeader,
			{PortSrc,PortDst}={maps:get(portSrc,FragmentHeader),maps:get(portDst,FragmentHeader)},
			ProtoService=PacketData#packet.protoPayload,
			#flowId{ipSrc=IpSrc,ipDst=IpDst,portSrc=PortSrc,portDst=PortDst,protoTrans=ProtoTrans,protoService=ProtoService}
	end.

getProtoTransaction(PacketData)->
	case PacketData#packet.fragmentHeader==undefined of
		true->
			{maps:get(protoDatagram,PacketData#packet.ethHeader),maps:get(type,PacketData#packet.datagramHeader)};
		false->
			{maps:get(protoFragment,PacketData#packet.datagramHeader),maps:get(type,PacketData#packet.fragmentHeader)}
	end.

getFlowInfo(Flow)->%%dato un FLUSSO nel estrapola le informazioni come nel record flowInfo
	NumPackets=length(Flow),
	FlowSizeBytes=lists:sum([getSizePacket(Packet)||Packet<-Flow]),
	{Start,Finish}={(hd(Flow))#packet.millisec,(lists:last(Flow))#packet.millisec},
	#flowInfo{numberOfPackets=NumPackets,sizeBytes=FlowSizeBytes,start=Start,finish=Finish}.

getSizePacket(PacketData)->%dato un pacchetto,ritorna la grandezza in bytes del pacchetto
	PacketData#packet.sizeDatagramHeader+PacketData#packet.sizeFragmentHeader+PacketData#packet.sizePayload.

getDualFlow(FlowId)->%%dato un flowId,genera la "controparte direzionale"
	#flowId{ipSrc=FlowId#flowId.ipDst,ipDst=FlowId#flowId.ipSrc,
			portSrc=FlowId#flowId.portDst,portDst=FlowId#flowId.portSrc,
			protoTrans=FlowId#flowId.protoTrans,protoService=FlowId#flowId.protoService}.

order(Packet1,Packet2)->
	Packet1#packet.millisec =< Packet2#packet.millisec.

notifyFlow(FlowId,Prediction)->
	#flowId{ipSrc=IpSrc,ipDst=IpDst,portSrc=PortSrc,portDst=PortDst,protoTrans=Protocol}=FlowId,
	Src="IP SORGENTE: "++inet:ntoa(IpSrc)++"\n"++"PORTA SORGENTE: "++?STRINGIFY(PortSrc)++"\n",
	Proto="PROTOCOLLO: "++?TUPLESTRING(Protocol)++"\n",
	Dest="IP DEST: "++inet:ntoa(IpDst)++"\n"++"PORTA DEST: "++?STRINGIFY(PortDst)++"\n",
	Type="TIPO FLUSSO: "++Prediction++"\n",
	Type++Src++Proto++Dest.