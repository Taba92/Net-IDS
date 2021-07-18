-module(defenseLayer1).
-export([handle_info/2,init/0,init/1,formatSSOutput/3]).
-include("../include/packetFlow.hrl").
-record(state,{pattern}).

init()->
	gen_server:start_link({local,defenseLayer1},?MODULE,[],[]).
init([])->
	wx:new(),
	{ok,Pattern}=re:compile("(.+?)\s.+:(\\d{1,5}).+"),
	State=#state{pattern=Pattern},
	{ok,State}.

handle_info({FlowId,FlowInfo,Prediction},State)->
	logger:log(info,[{flow,FlowId,FlowInfo,Prediction}]),
	execAction({FlowId,FlowInfo,Prediction},State),
	{noreply,State}.

execAction({_,_,"BENIGN"},_)->
	ok;
execAction({FlowId,_,"PortScan"},State)->
	#state{pattern=Pattern}=State,
	AttackNotice=flowUtils:notifyFlow(FlowId,"PortScan"),
	OutPut=string:lexemes(os:cmd("ss -tuln"),[$\n]),
	OpenSockets=formatSSOutput(Pattern,tl(OutPut),"PORTE APERTE: TIPO PORTA\tPORTA"++"\n"),
	StringInfo=AttackNotice++OpenSockets,
	showMsg(StringInfo),
	ok;
execAction({FlowId,_,Attack},_)->
	AttackNotice=flowUtils:notifyFlow(FlowId,Attack),
	showMsg(AttackNotice),
	%%FUTURE WORK: When will be presente NetDefense2.erl
	%{_,ProtoName}=Protocol,
	%AttackReport={inet:ntoa(IpSrc),inet:ntoa(IpDst),atom_to_list(ProtoName),integer_to_list(PortSrc),integer_to_list(PortDst),Attack},
	%defenseLayer2 ! AttackReport.
	ok.
	
formatSSOutput(Pattern,[H|T],Acc)->
	{match,[Type,Port]}=re:run(H,Pattern,[{capture,all_but_first,list}]),
	Line="\t\t\t"++Type++"\t\t"++Port++"\n",
	formatSSOutput(Pattern,T,Acc++Line);
formatSSOutput(_,[],Acc)->Acc.

showMsg(Msg)->
	wxMessageDialog:showModal(wxMessageDialog:new(wx:null(),Msg)).