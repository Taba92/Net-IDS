-module(erlDecisor).
-export([handle_info/2,init/0,init/1]).
-record(state,{flows,infitting,chunkNum,port}).

init() ->
    gen_server:start_link({local,erlDecisor},?MODULE,[],[]).

init([])->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	ExtPrg=CurDir++"/PythonDecisionMaker/PyDecisionMaker.py",
    Port= erlang:open_port({spawn, ExtPrg},[{packet,4},stderr_to_stdout,exit_status]),
    State=#state{flows=ets:new(info,[set]),infitting=false,port=Port},
    {ok,State}.

handle_info({Port, {data,[0|ErrList]}},State)when Port==State#state.port ->
	PythonErr=binary_to_term(list_to_binary(ErrList)),
	logger:log(error,PythonErr),
	{noreply,State};
handle_info({Port, {data, [1]}},State)when Port==State#state.port ->
	dbHandler ! {erlDecisor,ackTargets},
	{noreply,State};
handle_info({Port, {data, [2|[0]]}},State)when Port==State#state.port ->
	{noreply,State};
handle_info({Port, {data, [2|[1]]}},State)when Port==State#state.port ->
	options ! fitted,
	{noreply,State#state{infitting=false}};
handle_info({Port, {data, Data}},State)when Port==State#state.port ->
	DecidedRecord=binary_to_term(list_to_binary(Data)),
	{Record,[Prediction]}=lists:split(length(DecidedRecord)-1,DecidedRecord),
	[{Record,FlowId,FlowInfo}]=ets:take(State#state.flows,Record),
	dbHandler ! {storeRecord,FlowId,DecidedRecord},
	case ets:lookup(opts,netdefense) of
		[{_,true}]->
			defenseLayer1 ! {FlowId,FlowInfo,Prediction};
		[{_,false}]->ok
	end,
	{noreply,State};
handle_info({loadTargets,TargetsAndFeatures},State)->
	State#state.port ! {self(), {command,[1,term_to_binary(TargetsAndFeatures)]}},
    {noreply,State#state{infitting=true,chunkNum=0}};
handle_info({loadDataset,otherLines,Dataset},State)->
	#state{chunkNum=ChunkNum}=State,
	PrunedDataset=[Y||{_,Y}<-Dataset],
	State#state.port ! {self(), {command,[2,term_to_binary([0|PrunedDataset])]}},
	{noreply,State#state{chunkNum=ChunkNum+1}};
handle_info({loadDataset,SeqNumber,eof,Dataset},State)when SeqNumber==State#state.chunkNum->
	#state{chunkNum=ChunkNum}=State,
	PrunedDataset=[Y||{_,Y}<-Dataset],
	State#state.port ! {self(), {command,[2,term_to_binary([1|PrunedDataset])]}},
	{noreply,State#state{chunkNum=ChunkNum+1}};
handle_info({loadDataset,SeqNumber,eof,Dataset},State)->
	self() ! {loadDataset,SeqNumber,eof,Dataset},
	{noreply,State};
handle_info({decide,Record,FlowId,FlowInfo},State)->
	case State#state.infitting of
		false->
			PrunedRecord=[Y||{_,Y}<-Record],
			ets:insert(State#state.flows,{PrunedRecord,FlowId,FlowInfo}),
			State#state.port ! {self(), {command,[3,term_to_binary(PrunedRecord)]}};
		true->self() ! {decide,Record,FlowId,FlowInfo}
	end,
	{noreply,State};
handle_info({Port,{exit_status,_}},State)when Port==State#state.port->
	exit(port_error).