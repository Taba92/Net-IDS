-module(sniffer).
-export([init/0,init/1,handle_info/2,handle_continue/2]).
-include("$PWD/Headers/packetFlow.hrl").
-on_load(load_nif/0).

load_nif()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	erlang:load_nif(CurDir++"/snifNif", 0).

init()->
	gen_server:start_link({local,sniffer},?MODULE,[],[]).
init([])->
	{ok,null,{continue,sniff}}.

handle_continue(sniff,_)->
	self() ! sniff,
	{noreply,null}.

handle_info(sniff,_)->
	sniffing(),
	self() ! sniff,
	{noreply,null}.

sniffing()->
	RawFrame=sniff(),
	case RawFrame of
		X when is_integer(X)->ok;
		_->
 			MilliSec=logger:timestamp(),
			{Date,Time}=calendar:system_time_to_local_time(MilliSec,1000000),
			PacketData=#packet{data=Date,time=Time,millisec=MilliSec},
			layer2 ! {PacketData,RawFrame}
	end.

sniff()->
	exit(nif_library_not_loaded).
