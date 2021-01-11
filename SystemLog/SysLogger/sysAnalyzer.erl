-module(sysAnalyzer).
-export([handle_info/2,init/0,init/1]).
-record(state,{ets,threshold,sysCondition}).

init()->
	gen_server:start({local,sysAnalyzer},?MODULE,[],[]).
init([])->
	wx:new(),
	State=#state{ets=ets:new(errors,[set]),threshold=10,sysCondition=normal},
	{ok,State}.

handle_info(#{level:=error,msg:=Msg,meta:=#{time:=TimeStamp}},State)->
	#state{ets=Ets,threshold=Threshold}=State,
	case ets:lookup(Ets,Msg) of
		[]->ets:insert(Ets,{Msg,[TimeStamp/1000000]});
		[{CurVal,Times}]->ets:insert(Ets,{CurVal,Times++[TimeStamp/1000000]})
	end,
	NewState=case Threshold-1 of
		0->
			MedInterval=analizeSystem(ets:tab2list(Ets)),
			response(State,MedInterval);
		_->
			State#state{threshold=Threshold-1}
	end,
	{noreply,NewState}.

response(State,Condition)when Condition<2.5->%%emergenza
	Report=getErrorsRepo(State),
	logger:log(emergency,Report),
	ets:delete(State#state.ets),
	Frame=wxFrame:new(wx:null(),0,"SYSTEM NOTIFICATION"),
	wxStaticText:new(Frame,1,"IL SISTEMA È ANDATO IN PEZZI,URGE VISIONARE I LOG!!!",[{pos,{20,30}}]),
	wxFrame:show(Frame),
	timer:sleep(5000),
	init:stop(),
	exit(normal);
response(State,Condition) when Condition<5.0->%critico
	case State#state.sysCondition of
		normal->
			logger:log(critical,"\n\t\tIL SISTEMA È IN CONDIZIONI CRITICHE,SI ABBASSA LA SOGLIA DI ANALISI\n"),
			State#state{threshold=5,sysCondition=abnormal};
		abnormal->
			logger:log(critical,"\n\t\tIL SISTEMA È ANCORA IN CONDIZIONI CRITICHE,SI SPEGNE\n"),
			response(State,2)
	end;
response(State,_)->%normale
	case State#state.sysCondition of
		abnormal->
			logger:log(error,"\n\t\tIL SISTEMA È TORNATO IN CONDIZIONI NORMALI\n"),
			State#state{threshold=10,sysCondition=normal};
		normal->State
	end.

analizeSystem(Errors)->
	ErrorsTimes=lists:sort(getTimes(Errors)),
	SumIntervals=fun(El,{Last,Sum})->{El,Sum+El-Last} end,
	{_,Sum}=lists:foldl(SumIntervals,{hd(ErrorsTimes),0},ErrorsTimes),
	Sum/(length(ErrorsTimes)-1).

getErrorsRepo(#state{ets=Ets})->
	ErrorsList=ets:tab2list(Ets),
	OrderedErrors=lists:sort(fun mostFrequentsErrors/2,ErrorsList),
	NErrors=round(math:ceil(length(OrderedErrors)*10/100)),
	{MostFrequentsErrors,_}=lists:split(NErrors,OrderedErrors),
	Errors=[{length(TimeStamps),Err}||{Err,TimeStamps}<-MostFrequentsErrors],
	Errors.

mostFrequentsErrors({_,L1},{_,L2})->
	length(L1)>=length(L2).

getTimes([{_,TimeStamps}|T])->
	TimeStamps++getTimes(T);
getTimes([])->[].
