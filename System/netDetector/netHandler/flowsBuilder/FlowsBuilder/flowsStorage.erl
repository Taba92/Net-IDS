-module(flowsStorage).
-export([init/0,init/1,handle_info/2]).
-include("$PWD/Headers/packetFlow.hrl").
-record(state,{flows}).

init()->
	gen_server:start_link({local,flowsStorage},?MODULE,[],[]).

init([])->
	State=#state{flows=[]},%%è una lista di tuple([{flowId,Flow}])
	{ok,State}.

handle_info({FlowId,Flow},State)->%gli arriva un flusso finito
	#state{flows=Flows}=State,
	NewFlows=case FlowId==flowUtils:getDualFlow(FlowId) of % guardo se il flowId e uguale al flowId duale
		       false->
					case lists:keyfind(flowUtils:getDualFlow(FlowId),1,Flows) of%%guarda se il "duale" del flusso c'è
						false->%%se non c'è inserisci il flusso e aspetta che arrivi il "duale"
							lists:append(Flows,[{FlowId,Flow}]);
						{DualFlowId,DualFlow}->%%se c'è il "duale"
							CommPackets=lists:sort(fun flowUtils:order/2,Flow++DualFlow),%%crea la lista di tutti i pacchetti della comunicazione in ordine di tempo
							featuresExtractor ! CommPackets,
							lists:keydelete(DualFlowId,1,Flows)%eliminalo
					end;
			   true->
					CommPackets=lists:sort(fun flowUtils:order/2,Flow),%%crea la lista di tutti i pacchetti della comunicazione in ordine di tempo
					featuresExtractor ! CommPackets,
					Flows
			end,
	{noreply,State#state{flows=NewFlows},15000};
handle_info(timeout,State)->
	{noreply,State#state{flows=[]},15000}.