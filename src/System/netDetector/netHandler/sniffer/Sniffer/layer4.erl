-module(layer4).
-export([handle_info/2,init/1,init/0]).
-include("../include/packetFlow.hrl").

init()->
	gen_server:start_link({local,layer4},?MODULE,[],[]).
init([])->
	{ok,null}.

handle_info({PacketData,Fragment},_)->
	ProtoFragment=maps:get(protoFragment,PacketData#packet.datagramHeader),
	{RawFragmentHeader,FragmentPayload}=extract(ProtoFragment,Fragment),
	case RawFragmentHeader==null of
		true->
			ok;%nel caso il protocollo di livello 4 non fosse supportato,allora lo scarto!
		false->
			{SizeFragmentHeader,FragmentHeader}= unpack(ProtoFragment,list_to_binary(RawFragmentHeader)),
			netProcesser ! PacketData#packet{sizeFragmentHeader=SizeFragmentHeader,fragmentHeader=FragmentHeader,
						   sizePayload=length(FragmentPayload),payload=FragmentPayload}
    end,
    {noreply,null}.

extract(1,IcmpFragment)->
	lists:split(8,IcmpFragment);
extract(17,UdpFragment)->
	lists:split(8,UdpFragment);
extract(6,TcpFragment)->
	LenRemain=(byte_size(list_to_binary(TcpFragment))*8)-100,
	<<_U:96,Ihl:4,_Else:LenRemain>> = list_to_binary(TcpFragment),
	HeaderLen=Ihl*4,
	lists:split(HeaderLen,TcpFragment);
extract(_,_Fragment)->
	{null,null}.

unpack(1,IcmpHeader)->
	<<Type:8,Code:8,CheckSum:16,Data:32>> =IcmpHeader,
	{8,#{type=>icmp,typeIcmp=>Type,code=>Code,checkSum=>CheckSum,data=>Data}};
unpack(17,UdpHeader)->
	<<PortSrc:16,PortDst:16,Len:16,CheckSum:16>> =UdpHeader,
	{8,#{type=>udp,portSrc=>PortSrc,portDst=>PortDst,len=>Len,checkSum=>CheckSum}};
unpack(6,TcpHeader)->
	case byte_size(TcpHeader)>20 of
		false->
			<<PortSrc:16,PortDst:16,SeqNum:32,AckNum:32,Offset:4,Res:4,
			Cwr:1,Ece:1,Urg:1,Ack:1,Psh:1,Rst:1,Syn:1,Fin:1,
			WinSize:16,CheckSum:16,UrgPtr:16>> = TcpHeader,
			{20,#{type=>tcp,portSrc=>PortSrc,portDst=>PortDst,seqNum=>SeqNum,ackNum=>AckNum,offSet=>Offset,res=>Res,
			cwr=>Cwr,ece=>Ece,urg=>Urg,ack=>Ack,psh=>Psh,rst=>Rst,syn=>Syn,fin=>Fin,
			winSize=>WinSize,checkSum=>CheckSum,urgPtr=>UrgPtr}};
		true->
			Rem=(byte_size(TcpHeader)-20)*8,
				<<PortSrc:16,PortDst:16,SeqNum:32,AckNum:32,Offset:4,Res:4,
			Cwr:1,Ece:1,Urg:1,Ack:1,Psh:1,Rst:1,Syn:1,Fin:1,
			WinSize:16,CheckSum:16,UrgPtr:16,Options:Rem>> = TcpHeader,
			{20,#{type=>tcp,portSrc=>PortSrc,portDst=>PortDst,seqNum=>SeqNum,ackNum=>AckNum,offSet=>Offset,res=>Res,
			cwr=>Cwr,ece=>Ece,urg=>Urg,ack=>Ack,psh=>Psh,rst=>Rst,syn=>Syn,fin=>Fin,
			winSize=>WinSize,checkSum=>CheckSum,urgPtr=>UrgPtr,options=>Options}}
	end.