-module(flowRecorder).
-export([init/1,handle_info/2]).
-include("$PWD/Headers/packetFlow.hrl").
-record(state,{flowId,flow}).
-define(FLOWEXPIRED,30000).

init([FlowId])->
	State=#state{flowId=FlowId,flow=[]},
	{ok,State,?FLOWEXPIRED}.

handle_info(timeout,State)->
	#state{flowId=FlowId,flow=Flow}=State,
	flowsStorage ! {FlowId,Flow},
	exit(normal);
handle_info(PacketData,State) when length(State#state.flow)<49->
	#state{flow=Flow}=State,
	NewFlow=lists:append(Flow,[PacketData]),
	{noreply,State#state{flow=NewFlow},?FLOWEXPIRED};
handle_info(PacketData,State)->
	#state{flowId=FlowId,flow=Flow}=State,
	flowsStorage ! {FlowId,lists:append(Flow,[PacketData])},
	exit(normal).
