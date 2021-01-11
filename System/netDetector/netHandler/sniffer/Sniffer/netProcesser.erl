-module(netProcesser).
-export([handle_info/2,init/0,init/1]).
-include("$PWD/Headers/packetFlow.hrl").

init()->
	gen_server:start_link({local,netProcesser},?MODULE,[],[]).
init([])->
	{ok,null}.

handle_info(PacketData,_)->% è un record di tipo packet!
	case isPacketService(PacketData) of
		true->
			ProtoPayload=getProtoService(maps:get(portSrc,PacketData#packet.fragmentHeader),maps:get(portDst,PacketData#packet.fragmentHeader)),
			FinalPacketData=PacketData#packet{protoPayload=ProtoPayload},
			logger:log(info,[{packet,FinalPacketData}]),
			netFlow ! FinalPacketData;
		false->
			logger:log(info,[{packet,PacketData}]),
			netFlow ! PacketData
	end,
    {noreply,null}.

isPacketService(PacketData)->%se c'è l'header di livello 4 e se c'è contiene le porte(relative ad un servizio applicativo!)
	(PacketData#packet.fragmentHeader/=undefined) andalso (maps:is_key(portSrc,PacketData#packet.fragmentHeader)).

getProtoService(20,_)->
	'ftp-data';
getProtoService(_,20)->
	'ftp-data';
getProtoService(21,_)->
	'ftp-control';
getProtoService(_,21)->
	'ftp-control';
getProtoService(22,_)->
	ssh;
getProtoService(_,22)->
	ssh;
getProtoService(23,_)->
	telnet;
getProtoService(_,23)->
	telnet;
getProtoService(25,_)->
	smtp;
getProtoService(_,25)->
	smtp;
getProtoService(53,_)->
	dns;
getProtoService(_,53)->
	dns;
getProtoService(67,_)->
	'dhcp-client';
getProtoService(_,67)->
	'dhcp-client';
getProtoService(68,_)->
	'dhcp-server';
getProtoService(_,68)->
	'dhcp-server';
getProtoService(80,_)->
	http;
getProtoService(_,80)->
	http;
getProtoService(110,_)->
	pop3;
getProtoService(_,110)->
	pop3;
getProtoService(123,_)->
	ntp;
getProtoService(_,123)->
	ntp;
getProtoService(143,_)->
	imap;
getProtoService(_,143)->
	imap;
getProtoService(161,_)->
	'snmp-agent';
getProtoService(_,161)->
	'snmp-agent';
getProtoService(162,_)->
	'snmp-manager';
getProtoService(_,162)->
	'snmp-manager';
getProtoService(443,_)->
	https;
getProtoService(_,443)->
	https;
getProtoService(465,_)->
	'smtp-ssl';
getProtoService(_,465)->
	'smtp-ssl';
getProtoService(993,_)->
	'imap-ssl';
getProtoService(_,993)->
	'imap-ssl';
getProtoService(995,_)->
	'pop-ssl';
getProtoService(_,995)->
	'pop-ssl';
getProtoService(_,_)->
	undefined.