-module(layer3).
-export([init/0,init/1,handle_info/2]).
-include("$PWD/Headers/packetFlow.hrl").

init()->
	gen_server:start_link({local,layer3},?MODULE,[],[]).
init([])->
	{ok,null}.

handle_info({PacketData,Datagram},_)->
	ProtoDatagram=maps:get(protoDatagram,PacketData#packet.ethHeader),
	{RawDatagramHeader,DatagramPayload}=extract(ProtoDatagram,Datagram),
	case RawDatagramHeader==null of
		true-> 
			ok;%nel caso il protocollo di livello 3 non fosse supportato,allora lo scarto!
		false->
			{SizeDatagramHeader,DatagramHeader}= unpack(ProtoDatagram,list_to_binary(RawDatagramHeader)),
			%se il payload del datagramma è vuoto oppure è un pacchetto di livello 3
			case (length(DatagramPayload)==0) orelse (maps:is_key(protoFragment,DatagramHeader) == false) of
			true->
				netProcesser ! PacketData#packet{sizeDatagramHeader=SizeDatagramHeader,datagramHeader=DatagramHeader,sizeFragmentHeader=0,sizePayload=0};%il pacchetto si ferma a questo livello!
			false->
				layer4 ! {PacketData#packet{sizeDatagramHeader=SizeDatagramHeader,datagramHeader=DatagramHeader},DatagramPayload}
    		end
    end,
    {noreply,null}.

extract(2048,IpDatagram)->
		LenRemain=(byte_size(list_to_binary(IpDatagram))-1)*8,
		<<_V:4,Ihl:4,_Else:LenRemain>> = list_to_binary(IpDatagram),
		HeaderLen=Ihl*4,
		lists:split(HeaderLen,IpDatagram);
extract(2054,ArpDatagram)->
	lists:split(28,ArpDatagram);
extract(_,_Datagram)->%Protocollo di livello 3 non supportato
	{null,null}.

unpack(2048,IpHeader)->
	case byte_size(IpHeader)>20 of
		false->
			<<Version:4,Ihl:4,Prec:3,Latency:1,Through:1,Reliability:1,Future:2,
				TotalLen:16,Id:16,Flags:3,FrgOff:13,Ttl:8,
				ProtoFragment:8,CheckSum:16,IpSource:32,IpDest:32>> = IpHeader,
				{ok,IpSrc}=inet:parse_address(integer_to_list(IpSource)),
				{ok,IpDst}=inet:parse_address(integer_to_list(IpDest)),
				{20,#{type=>ipv4,version=>Version,ihl=>Ihl,prec=>Prec,latency=>Latency,throughput=>Through,
				reliability=>Reliability,future=>Future,totLen=>TotalLen,id=>Id,
				flags=>Flags,frgOff=>FrgOff,ttl=>Ttl,protoFragment=>ProtoFragment,
				checksum=>CheckSum,ipSrc=>IpSrc,ipDst=>IpDst}};
		true->
			Rem=(byte_size(IpHeader)-20)*8,
			<<Version:4,Ihl:4,Prec:3,Latency:1,Through:1,Reliability:1,Future:2,
				TotalLen:16,Id:16,Flags:3,FrgOff:13,Ttl:8,
				ProtoFragment:8,CheckSum:16,IpSource:32,IpDest:32,Options:Rem>> = IpHeader,
				{ok,IpSrc}=inet:parse_address(integer_to_list(IpSource)),
				{ok,IpDst}=inet:parse_address(integer_to_list(IpDest)),
				{20,#{type=>ipv4,version=>Version,ihl=>Ihl,prec=>Prec,latency=>Latency,throughput=>Through,
				reliability=>Reliability,future=>Future,totLen=>TotalLen,id=>Id,
				flags=>Flags,frgOff=>FrgOff,ttl=>Ttl,protoFragment=>ProtoFragment,
				checksum=>CheckSum,ipSrc=>IpSrc,ipDst=>IpDst,options=>Options}}
	end;
unpack(2054,ArpHeader)->
	<<HwType:16,ProtoType:16,HLen:8,Plen:8,Op:16,Sha:48,Spa:32,Tha:48,Tpa:32>> =ArpHeader,
	{ok,SenderIp}=inet:parse_address(integer_to_list(Spa)),
	{ok,TargetIp}=inet:parse_address(integer_to_list(Tpa)),
	{28,#{type=>arp,hwType=>HwType,protoType=>ProtoType,hLen=>HLen,pLen=>Plen,op=>Op,
	senderHwAddr=>integer_to_list(Sha,16),ipSrc=>SenderIp,targetHwAddr=>integer_to_list(Tha,16),ipDst=>TargetIp}}.