-module(options).
-export([file_configs/0,load_configs/1,reset_configs/1,list_configs/1,set_config/2]).
-export([dump_log/1,hot_code_reload/0,showMsg/1,format/1]).
-define(ROOTLOG,"SystemLog/").
-define(ROOT,sysInit).%indica il nome della radice dell'albero dell'applicazione
-define(ISRUNTIME(),whereis(?ROOT)/=undefined).
-define(ISBOOLEAN(Bool),Bool==true;Bool==false).
-define(ISCHILD(Father,ChildId),lists:keymember(ChildId,1,supervisor:which_children(Father))).

dump_log(Dir)->
	DirOut=Dir++"/"++createName(),
	file:make_dir(DirOut),
	Files=["FlowLogger/flows.log","LogLogger/logsErr.log","PacketLogger/packets.log","SysLogger/sysLog.log"],
	[file:copy(?ROOTLOG++File,DirOut++"/"++filename:basename(File))||File<-Files],
	[file:write_file(?ROOTLOG++File,"")||File<-Files].

createName()->
	{Data,Ora}=erlang:localtime(),
	StringData=string:join([integer_to_list(X)||X<-tuple_to_list(Data)],"-"),
	StringTime=string:join([integer_to_list(X)||X<-tuple_to_list(Ora)],"-"),
	"NIDS LOG "++string:concat(StringData,string:concat("*",StringTime)).

format(Opts)->
	format(Opts,"").
format([],Acc)->Acc;
format([{Key,Value}|T],Acc)->
	NewAcc=Acc++atom_to_list(Key)++" : "++atom_to_list(Value)++"\n",
	format(T,NewAcc).

hot_code_reload()->
	CurDir=filename:dirname(code:which(?MODULE)),
	Pred=fun(Path)->Path/=preloaded andalso lists:prefix(CurDir,Path) end,
	Modules=[{Module,Path}||{Module,Path}<-code:all_loaded(),Pred(Path)],
	CompRes=os:cmd("./compile"),
	case string:find(CompRes,"Warning")==nomatch andalso string:find(CompRes,"error")==nomatch of
		true->lists:foreach(fun c:l/1,[Module||{Module,_}<-Modules]),
				"HOT_CODE_RELOAD COMPLETATED";
		_->CompRes
	end.

default_configs()->
	[{training,false},{netdefense,true}].
file_configs()->
	{ok,Dets}=dets:open_file(config,[{type,set}]),
	Dets.

reset_configs(Dets)->
	dets:delete_all_objects(Dets),
	[set_config(Dets,Opt)||Opt<-default_configs()].

load_configs(Dets)->
	Opts=ets:new(opts,[named_table,set,public,{read_concurrency,true}]),
	dets:to_ets(Dets,Opts),
	Opts.

list_configs(Dets)->
	Ets=ets:new(temp,[set]),
	Ets=dets:to_ets(Dets,Ets),
	Config=ets:tab2list(Ets),
	ets:delete(Ets),
	Config.

set_config(Dets,Opt)->
	case ?ISRUNTIME() of
		true->
			set_disk_config(Dets,Opt),
			set_runtime_config(Opt);
		false->set_disk_config(Dets,Opt)
	end.

set_runtime_config({training,Bool})when ?ISBOOLEAN(Bool)->
	[{training,OldBool}]=ets:lookup(opts,training),
	ets:insert(opts,{training,Bool}),
	case OldBool/=Bool andalso whereis(dbHandler)/=undefined of
		false->showMsg("TRAINING NO SET:SAME VALUE OR INACTIVE DBHANDLER");
		true->dbHandler ! {change_train,Bool}
	end;
set_runtime_config({netdefense,Bool}) when ?ISBOOLEAN(Bool)->
	[{netdefense,OldBool}]=ets:lookup(opts,netdefense),
	ets:insert(opts,{netdefense,Bool}),
	case OldBool/=Bool andalso whereis(nidsInit)/=undefined of
		false->showMsg("NETDEFENSE NO SET:SAME VALUE OR INACTIVE NIDS CORE");
		true->case {OldBool,Bool} of
				{false,true}->case ?ISCHILD(nidsInit,netDefender) of
								true->supervisor:restart_child(nidsInit,netDefender);
								false->supervisor:start_child(nidsInit,#{id =>netDefender,start=>{netDefender,init,[]},restart=>permanent,type=>supervisor})
							end;
				{true,false}->supervisor:terminate_child(nidsInit,netDefender)
			end
	end;
set_runtime_config(_)->
	showMsg("INVALID OPTION,NOT SUPPORTED").

set_disk_config(Dets,{training,Bool})when ?ISBOOLEAN(Bool)->
	dets:insert(Dets,{training,Bool});
set_disk_config(Dets,{netdefense,Bool})when ?ISBOOLEAN(Bool)->
	dets:insert(Dets,{netdefense,Bool});
set_disk_config(_,_)->
	showMsg("INVALID OPTION,NOT SUPPORTED").

showMsg(Msg)->
	wxMessageDialog:showModal(wxMessageDialog:new(wx:null(),Msg)).
