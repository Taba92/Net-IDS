-module(featuresExtractor).
-export([init/0,init/1,handle_info/2]).
-include("$PWD/Headers/packetFlow.hrl").

init()->
	gen_server:start_link({local,featuresExtractor},?MODULE,[],[]).

init([])->
	{ok,null}.

handle_info(CommPackets,State)->
	FlowId=flowUtils:getFlowId(hd(CommPackets)),
	FlowInfo=flowUtils:getFlowInfo(CommPackets),
	RecordFlow=createRecordFeatures(CommPackets,FlowId,FlowInfo),
	erlDecisor ! {decide,RecordFlow,FlowId,FlowInfo},
	{noreply,State}.

createRecordFeatures(CommPackets,TotalFlowId,TotalFlowInfo)->
	{FlowFwd,FlowBwd}=flowUtils:getPairDirections(CommPackets),
	{FlowFwdId,FlowBwdId}={flowUtils:getFlowId(hd(FlowFwd)),flowUtils:getFlowId(hd(FlowBwd))},
	{FlowFwdInfo,FlowBwdInfo}={flowUtils:getFlowInfo(FlowFwd),flowUtils:getFlowInfo(FlowBwd)},
	PortDst=TotalFlowId#flowId.portDst,
	ProtoTrans=element(1,TotalFlowId#flowId.protoTrans),
	Duration=round(getFlowDuration(TotalFlowInfo)),
	{TotalFwdPackets,TotalBwdPackets}={FlowFwdInfo#flowInfo.numberOfPackets,FlowBwdInfo#flowInfo.numberOfPackets},
	{TotalLenFwdPackets,TotalLenBwdPackets}={getTotalSizePayload(FlowFwd),getTotalSizePayload(FlowBwd)},
	{MinLenFwdPacket,MeanLenFwdPacket,MaxLenFwdPacket,StdLenFwdPacket}=getSizePacketsInfo(FlowFwd,FlowFwdInfo),
	{MinLenBwdPacket,MeanLenBwdPacket,MaxLenBwdPacket,StdLenBwdPacket}=getSizePacketsInfo(FlowBwd,FlowBwdInfo),
	{FlowBytesXSec,FlowPacketsXSec}={getInfoXSec(TotalFlowInfo#flowInfo.sizeBytes,Duration),getInfoXSec(TotalFlowInfo#flowInfo.numberOfPackets,Duration)},
	{TotalFlowMinInterval,TotalFlowMeanInterval,TotalFlowMaxInterval,TotalFlowStdInterval,_}=getInfosIntervalPackets(CommPackets),
	{FlowFwdMinInterval,FlowFwdMeanInterval,FlowFwdMaxInterval,FlowFwdStdInterval,FlowFwdTotInterval}=getInfosIntervalPackets(FlowFwd),
	{FlowBwdMinInterval,FlowBwdMeanInterval,FlowBwdMaxInterval,FlowBwdStdInterval,FlowBwdTotInterval}=getInfosIntervalPackets(FlowBwd),
	{FwdPSHFlag,FwdURGFlag}=getNumberTimesOfFlags([psh,urg],ProtoTrans,FlowFwd),
	{BwdPSHFlag,BwdURGFlag}=getNumberTimesOfFlags([psh,urg],ProtoTrans,FlowBwd),
	FwdHeaderLen=getHeadersLen(FlowFwd),
	BwdHeaderLen=getHeadersLen(FlowBwd),
	{FwdPacketsXSec,BwdPacketsXSec}={getInfoXSec(FlowFwdInfo#flowInfo.numberOfPackets,getFlowDuration(FlowFwdInfo)),getInfoXSec(FlowBwdInfo#flowInfo.numberOfPackets,getFlowDuration(FlowBwdInfo))},
	{TotFlowMinPktLen,TotFlowMeanPktLen,TotFlowMaxPktLen,TotFlowStdPktLen}=getSizePacketsInfo(CommPackets,TotalFlowInfo),
	Variance=math:pow(TotFlowStdPktLen,2),
	{TotFin,TotSyn,TotRst,TotPsh,TotAck,TotUrg,TotCwr,TotEce}=getNumPacketsWithFlags([fin,syn,rst,psh,ack,urg,cwr,ece],ProtoTrans,CommPackets),
	UpDownLoadRatio=length(FlowBwd)/length(FlowFwd),
	{AvgTotPktSize,AvgFwdPktSize,AvgBwdPktSize}={getAvgSize(CommPackets,TotalFlowInfo),getAvgSize(FlowFwd,FlowFwdInfo),getAvgSize(FlowBwd,FlowBwdInfo)},
	{FwdBulkBytes,FwdBulkPackets,FwdNBulk}=getBulkInfo(CommPackets,FlowFwdId),
	{BwdBulkBytes,BwdBulkPackets,BwdNBulk}=getBulkInfo(CommPackets,FlowBwdId),
	{InitWinSizeFwd,InitWinSizeBwd}=getInitWinSize(FlowFwd,FlowBwd,ProtoTrans),
	ActDataFwd=getActData(ProtoTrans,FlowFwd),
	MinSegSizeFwd=lists:min([Packet#packet.sizeFragmentHeader||Packet<-FlowFwd]),
	ActiveSubFlows=extractActiveSubFlows(CommPackets,[]),
	{MinActivity,MeanActivity,MaxActivity,StdActivity}=getStatisticsActivityFlow(ActiveSubFlows),
	{MinInactivity,MeanInactivity,MaxInactivity,StdInactivity}=getStatisticsInactivityFlow(ActiveSubFlows),
	%%%RECORD DA MANDARE AL DECISORE PYTHON!!!!	
	[{'Destination Port',case PortDst of undefined-> 0; PortDst->PortDst end},
	{'Flow Duration',Duration},
	{'Total Fwd Packets',TotalFwdPackets},
	{'Total Backward Packets',TotalBwdPackets},
	{'Total Length of Bwd Packets',TotalLenFwdPackets},
	{'Total Length of Bwd Packets',TotalLenBwdPackets},
	{'Fwd Packet Length Max',MaxLenFwdPacket},
	{'Fwd Packet Length Min',MinLenFwdPacket},
	{'Fwd Packet Length Mean',MeanLenFwdPacket},
	{'Fwd Packet Length Std',StdLenFwdPacket},
	{'Bwd Packet Length Max',MaxLenBwdPacket},
	{'Bwd Packet Length Min',MinLenBwdPacket},
	{'Bwd Packet Length Mean',MeanLenBwdPacket},
	{'Bwd Packet Length Std',StdLenBwdPacket},
	{'Flow Bytes/s',FlowBytesXSec},
	{'FlowPackets/s',FlowPacketsXSec},
	{'Flow IAT Mean',TotalFlowMeanInterval},
	{'Flow IAT Std',TotalFlowStdInterval},
	{'Flow IAT Max',TotalFlowMaxInterval},
	{'Flow IAT Min',TotalFlowMinInterval},
	{'Fwd IAT Total',FlowFwdTotInterval},
	{'Fwd IAT Mean',FlowFwdMeanInterval},
	{'Fwd IAT Std',FlowFwdStdInterval},
	{'Fwd IAT Max',FlowFwdMaxInterval},
	{'Fwd IAT Min',FlowFwdMinInterval},
	{'Bwd IAT Total',FlowBwdTotInterval},
	{'Bwd IAT Mean',FlowBwdMeanInterval},
	{'Bwd IAT Std',FlowBwdStdInterval},
	{'Bwd IAT Max',FlowBwdMaxInterval},
	{'Bwd IAT Min',FlowBwdMinInterval},
	{'Fwd PSH Flags',FwdPSHFlag},
	{'Bwd PSH Flags',BwdPSHFlag},
	{'Fwd URG Flags',FwdURGFlag},
	{'Bwd URG Flags',BwdURGFlag},
	{'Fwd Header Length',FwdHeaderLen},
	{'Bwd Header Length',BwdHeaderLen},
	{'Fwd Packets/s',FwdPacketsXSec},
	{'Bwd Packets/s',BwdPacketsXSec},
	{'Min Packet Length',TotFlowMinPktLen},
	{'Max Packet Length',TotFlowMaxPktLen},
	{'Packet Length Mean',TotFlowMeanPktLen},
	{'Packet Length Std',TotFlowStdPktLen},
	{'Packet Length Variance',Variance},
	{'FIN Flag Count',TotFin},
	{'SYN Flag Count',TotSyn},
	{'RST Flag Count',TotRst},
	{'PSH Flag Count',TotPsh},
	{'ACK Flag Count',TotAck},
	{'URG Flag Count',TotUrg},
	{'CWE Flag Count',TotCwr},
	{'ECE Flag Count',TotEce},
	{'Down/Up Ratio',UpDownLoadRatio},
	{'Average Packet Size',AvgTotPktSize},
	{'Avg Fwd Segment Size',AvgFwdPktSize},
	{'Avg Bwd Segment Size',AvgBwdPktSize},
	{'Fwd Header Length',TotalLenFwdPackets},
	{'Fwd Avg Bytes/Bulk',FwdBulkBytes},
	{'Fwd Avg Packets/Bulk',FwdBulkPackets},
	{'Fwd Avg Bulk Rate',FwdNBulk},
	{'Bwd Avg Bytes/Bulk',BwdBulkBytes},
	{'Bwd Avg Packets/Bulk',BwdBulkPackets},
	{'Bwd Avg Bulk Rate',BwdNBulk},
	{'Subflow Fwd Packets',TotalFwdPackets},
	{'Subflow Fwd Bytes',TotalLenFwdPackets},
	{'Subflow Bwd Packets',TotalBwdPackets},
	{'Subflow Bwd Bytes',TotalLenBwdPackets},
	{'Init_Win_bytes_forward',InitWinSizeFwd},
	{'Init_Win_bytes_backward',InitWinSizeBwd},
	{'act_data_pkt_fwd',ActDataFwd},
	{'min_seg_size_forward',MinSegSizeFwd},
	{'Active Mean',MeanActivity},
	{'Active Std',StdActivity},
	{'Active Max',MaxActivity},
	{'Active Min',MinActivity},
	{'Idle Mean',MeanInactivity},
	{'Idle Std',StdInactivity},
	{'Idle Max',MaxInactivity},
	{'Idle Min',MinInactivity}
	 ].

%ottiene la durata in MICROSECONDI di un flusso
getFlowDuration(FlowInfo)->
	case FlowInfo#flowInfo.numberOfPackets of
		1->
			FlowInfo#flowInfo.finish/0.0000001;
		_N->
			(FlowInfo#flowInfo.finish-FlowInfo#flowInfo.start)
	end.

%Nel caso di Tcp, dato un flusso ottiene la q.tà di pacchetti che hanno almeno un byte di payload 
getActData(ProtoTrans,Flow)->
	case ProtoTrans==6 of
		true->
			length([Packet||Packet<-Flow,Packet#packet.sizePayload>= 1]);
		false->
			1
	end.

%Se il protocollo è tcp,ritorna la tupla delle due grandezze delle finestre iniziali
%(guardo la testa del flusso)
getInitWinSize(FlowFwd,FlowBwd,ProtoTrans)->
	case ProtoTrans==6 of
		true->
			{maps:get(winSize,(hd(FlowFwd))#packet.fragmentHeader),maps:get(winSize,(hd(FlowBwd))#packet.fragmentHeader)};
		false->
			{-1,-1}
		end.

%%Con size o length di un packet,viene inteso SOLO il payload!!
getTotalSizePayload(Flow)->
	lists:sum([Packet#packet.sizePayload||Packet<-Flow]).

%Dato un flusso e le sue informazioni,ritorna le 3 statistische sui bulk nel flusso
getBulkInfo(Flow,FlowId)->
	ValidBulks=getBulks(Flow,FlowId),% è una lista di liste!
	case length(ValidBulks) of
		0->{0,0,0};
		N->
			SizeTotal=lists:sum([lists:sum([Packet#packet.sizePayload||Packet<-Bulk])||Bulk<-ValidBulks]),
			PacketCount=lists:sum([length(Bulk)||Bulk<-ValidBulks]),
			BulkDurationSec=lists:sum([getBulkDurationSec(Bulk)||Bulk<-ValidBulks]),
			{SizeTotal/N,PacketCount/N,SizeTotal/BulkDurationSec}
	end.

%Dato un bulk, ne ritorna la durata in secondi!
getBulkDurationSec(Bulk)->
	BulkInfo=flowUtils:getFlowInfo(Bulk),
	DurationSec=(BulkInfo#flowInfo.finish-BulkInfo#flowInfo.start)/1000000,
	DurationSec.

%dato un flusso e le sue relative informazioni, ne ritorna la lista di bulk presenti all'interno
%Bulk è un flusso!
getBulks(Flow,FlowId)->
	OnlyNotEmptyPackets=[Packet||Packet<-Flow,Packet#packet.sizePayload >0],% guardo solo quelli pieni
	PossibleBulks=extractPossibleBulks(OnlyNotEmptyPackets,FlowId,[],[]),% ne estraggo i possibili bulk
	ValidBulks=[Bulk||Bulk<-PossibleBulks,length(Bulk)>=4 andalso isNotTrunkedBulk(Bulk)],% estrapolo solo quelli che sono effettivamente bulk!
	ValidBulks.

isNotTrunkedBulk([_])->true;
isNotTrunkedBulk([P1|[P2|T]])->
	(((P2#packet.millisec-P1#packet.millisec)/1000000) < 1) and (isNotTrunkedBulk([P2|T])).

%estraggo i possibile bulk,ovvero quei sotto-flussi, che hanno pacchetti contigui con lo stesso flowId
extractPossibleBulks([],_FlowId,TotAcc,_Acc)->TotAcc;
extractPossibleBulks([H|T],FlowId,TotAcc,Acc)->
	case flowUtils:getFlowId(H)==FlowId of
		true->
			extractPossibleBulks(T,FlowId,TotAcc,lists:append(Acc,[H]));
		false->
			extractPossibleBulks(T,FlowId,lists:append(TotAcc,[Acc]),[])
	end.

%dato un flusso e le sue informazioni,calcola la media della grandezza di un pacchetto
getAvgSize(Flow,FlowInfo)->
	case FlowInfo#flowInfo.numberOfPackets < 2 of
			true->
				(hd(Flow))#packet.sizePayload;
			false->
				(FlowInfo#flowInfo.sizeBytes)/(FlowInfo#flowInfo.numberOfPackets-1)
	end.

%Nel caso di Tcp conteggio,per ogni FLAG in FlagList, i numero dei pacchetti con quel FLAG
getNumPacketsWithFlags(FlagList,ProtoTrans,Flow)->
	case ProtoTrans==6 of
		true->
			FlagsCounts=[length([Packet||Packet<-Flow,maps:get(Flag,Packet#packet.fragmentHeader)==1])||Flag<-FlagList],
			list_to_tuple(FlagsCounts);
		false->
			{0,0,0,0,0,0,0,0}
	end.

%dato un flusso,ritorna la grandezza totale in bytes degli header di livello 4
getHeadersLen(Flow)->
	lists:sum([Packet#packet.sizeFragmentHeader||Packet<-Flow]).

%%Dati una lista dif flag e un flusso,ritorna la tupla contenente,i valori di quei flag nel pacchetto di testa.nel caso fosse TCP
getNumberTimesOfFlags(FlagList,ProtoTrans,Flow)->
	case ProtoTrans==6 of
		false->
			{0,0};
		true->
			ListNumTimesFlags=[maps:get(Flag,(hd(Flow))#packet.fragmentHeader)||Flag<-FlagList],
			list_to_tuple(ListNumTimesFlags)
	end.

%dato un flusso e le relative info su di esso,ne ritorna minimo,medio,massimo e scarto quadratico medio in base alla grandezza del PAYLOAD	
getSizePacketsInfo(Flow,FlowInfo)->
	ListPacketSize=[Packet#packet.sizePayload||Packet<-Flow],
	Min=lists:min(ListPacketSize),
	Mean=(FlowInfo#flowInfo.sizeBytes)/(FlowInfo#flowInfo.numberOfPackets),
	Max=lists:max(ListPacketSize),
	StandardDeviation=getStdDev(Mean,ListPacketSize),
	{Min,Mean,Max,StandardDeviation}.

%%dato una media e una lista di valori,ne calcola lo scarto quadratico medio
getStdDev(Mean,ValueList)->
	WasteList=[Value-Mean||Value<-ValueList],
	PowWasteList=[math:pow(Waste,2)||Waste<-WasteList],
	SampleVariance=lists:sum(PowWasteList)/length(ValueList),
	StdDev=math:sqrt(SampleVariance),
	StdDev.

%%Data una q.tà e una durata,ritorna la q.tà/durata
getInfoXSec(Info,Duration)->
	case Duration==0 of%%nel caso abbia una durata = 0(UN SOLO PACCHETTO NEL FLUSSO!!),uso una durata di default
		true->
			Info/0.000001;
		false->
			Info/(Duration/1000000)
	end.

%Dato un flusso,ne ritorna le statistiche sulla lista degli intervalli tra i vari pacchetti
getInfosIntervalPackets(Flow)->
	case length(Flow)==1 of 
		false->
			ListInterval=getIntervalsBetweenPackets(Flow,[]),
			MinInterval=lists:min(ListInterval),
			MeanInterval=lists:sum(ListInterval)/length(ListInterval),
			MaxInterval=lists:max(ListInterval),
			StandardDevInterval=getStdDev(MeanInterval,ListInterval),
			TotalInterval=lists:sum(ListInterval),
			{MinInterval,MeanInterval,MaxInterval,StandardDevInterval,TotalInterval};
		true->
			{0,0,0,0,0}
	end.

%%preso in unput un flusso e un accumulatore,ne ritorna la lista degli intervalli tra i vari pacchetti!
getIntervalsBetweenPackets([_P1|[]],Acc)->Acc;
getIntervalsBetweenPackets([P1|[P2|T]],Acc)->
	Interval=P2#packet.millisec-P1#packet.millisec,
	getIntervalsBetweenPackets([P2|T],Acc++[Interval]).

%%dato un flusso,ne estrae i sotto flussi attivi,UNO ALLA VOLTA
extractActiveSubFlows([],TotAcc)->TotAcc;
extractActiveSubFlows([P1|T],TotAcc)->
	{SubFlow,ListRemain}=extractFirstActiveSubFlow([P1|T],[P1]),
	extractActiveSubFlows(ListRemain,TotAcc++SubFlow).

%%dato un flusso,estrae il primo sotto flusso attivo e ritorna {sottoflusso,resto della lista}
%un flusso è attivo se la l'intervallo tra i vari pacchetti è meno di 2 secondi!
extractFirstActiveSubFlow([_P1|[]],Acc)->{[Acc],[]};
extractFirstActiveSubFlow([P1|[P2|T]],Acc)->
	case (P2#packet.millisec-P1#packet.millisec) < 2000 of
		true->
			extractFirstActiveSubFlow([P2|T],Acc++[P2]);
		false->
			{[Acc],[P2|T]}
	end.	

%Dati i sotto-flussi,ne ritorna le statistiche di ATTIVITÀ su di esso
getStatisticsActivityFlow(SubFlows)->
	case length(SubFlows) of
		1->
			{0,0,0,0};
		_N->
			SubFlowsInfo=[flowUtils:getFlowInfo(Sub)||Sub<-SubFlows],
			ActivityDurations=[SubInfo#flowInfo.finish-SubInfo#flowInfo.start||SubInfo<-SubFlowsInfo],
			Min=lists:min(ActivityDurations),
			Mean=(lists:sum(ActivityDurations))/(length(SubFlows)),
			Max=lists:max(ActivityDurations),
			StandardDeviation=getStdDev(Mean,ActivityDurations),
			{Min,Mean,Max,StandardDeviation}
	end.

%Dati i sotto-flussi,ne ritorna le statistiche di INATTIVITÀ su di esso
getStatisticsInactivityFlow(SubFlows)->
	case length(SubFlows) of
		1->{0,0,0,0};
		_N->
			SubFlowsInfo=[flowUtils:getFlowInfo(Sub)||Sub<-SubFlows],
			IdleDurations=getIntervalsBetweenSubFlows(SubFlowsInfo,[]),
			Min=lists:min(IdleDurations),
			Mean=(lists:sum(IdleDurations))/(length(SubFlows)),
			Max=lists:max(IdleDurations),
			StandardDeviation=getStdDev(Mean,IdleDurations),
			{Min,Mean,Max,StandardDeviation}
	end.

%Dato una lista di sotto-flussi(lista di liste),ne ottiene gli intervalli (di inattività) tra i sotto-flussi
getIntervalsBetweenSubFlows([_FI1|[]],Acc)->Acc;
getIntervalsBetweenSubFlows([FI1|[FI2|T]],Acc)->
	IdleDuration=FI2#flowInfo.start-FI1#flowInfo.finish,
	getIntervalsBetweenSubFlows([FI2|T],Acc++[IdleDuration]).
