-module(layer2).
-export([init/0,init/1,handle_info/2]).
-include("$PWD/Headers/packetFlow.hrl").
%i dati del pacchetto finali sarà una record di mappe!
init()->
	gen_server:start_link({local,layer2},?MODULE,[],[]).
init([])->
	{ok,null}.

handle_info({PacketData,RawFrame},_)->
	{EthernetHeader,Payload}=lists:split(14,RawFrame),
	<<MacDst:48,MacSrc:48,ProtoSup:16>>= list_to_binary(EthernetHeader),
	ParsedHeader=#{macDst=>integer_to_list(MacDst,16),
	      		   macSrc=>integer_to_list(MacSrc,16),
				   protoDatagram=>ProtoSup
			       },
	layer3 ! {PacketData#packet{sizeEthHeader=14,ethHeader=ParsedHeader},Payload},
    {noreply,null}.
