-module(netFlow).
-export([init/0,init/1,handle_info/2]).
-include("$PWD/Headers/packetFlow.hrl").
-record(state,{flowRecorders}).
init()->
	gen_server:start_link({local,netFlow},?MODULE,[],[]).

init([])->
	State=#state{flowRecorders=[]},%%lista di tuple[{FlowId,PidOfRecorderFlow}]
	{ok,State}.

handle_info({'DOWN',MonRef,_,Pid,_},State)->
	demonitor(MonRef),
	#state{flowRecorders=FlowRecorders}=State,
	NewFlowRecorders=lists:keydelete(Pid,2,FlowRecorders),
	{noreply,State#state{flowRecorders=NewFlowRecorders}};
handle_info(suspend_recorders,State)->
	#state{flowRecorders=FlowRecorders}=State,
	[sys:suspend(RecorderPid)||{_,RecorderPid}<-FlowRecorders],
	{noreply,State};
handle_info(resume_recorders,State)->
	#state{flowRecorders=FlowRecorders}=State,
	[sys:resume(RecorderPid)||{_,RecorderPid}<-FlowRecorders],
	{noreply,State};
handle_info(PacketData,State)->
	FlowId=flowUtils:getFlowId(PacketData),
	#state{flowRecorders=FlowRecorders}=State,
	NewFlowRecorders=case lists:keyfind(FlowId,1,FlowRecorders) of
						false->	
							{ok,Pid}=gen_server:start(flowRecorder,[FlowId],[]),
							monitor(process,Pid),
							Pid ! PacketData,
							lists:append(FlowRecorders,[{FlowId,Pid}]);
						{_,Pid}->%%mando il pacchetto al giusto gestore di flusso!
							Pid ! PacketData,
							FlowRecorders
					end,
	{noreply,State#state{flowRecorders=NewFlowRecorders}}.
	