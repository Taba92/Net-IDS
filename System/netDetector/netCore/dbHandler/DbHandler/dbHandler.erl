-module(dbHandler).
-export([init/0,init/1,handle_info/2,handle_call/3]).
-record(state,{graphic,dataset,features,targets,training}).

init()->
	gen_server:start_link({local,dbHandler},?MODULE,[],[]).

init([])->
	wx:new(),
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	TargetsFileName=CurDir++"/Dataset/labels.txt",
	File=CurDir++"/Dataset/Dataset.csv",
	{ok,Dataset}=file:open(File,[read,append,raw,binary,{read_ahead,200000}]),
	{ok,FileTargetNames}=file:open(TargetsFileName,[read]),
	[{_,Training}]=ets:lookup(opts,training),
	{Features,Targets}=readFeaturesAndTargetNames(Dataset,FileTargetNames),
	Frame=dbHandlerGraphic:get_window(Targets),
	State=#state{graphic=Frame,dataset=Dataset,features=Features,targets=Targets,training=Training},
	{ok,State}.

handle_info({storeRecord,FlowId,RecordDecided},State)when State#state.training->
	#state{graphic=Frame,dataset=Dataset,targets=Targets}=State,
	RecordString=stringify(RecordDecided,[]),
	Text=flowUtils:notifyFlow(FlowId,lists:last(RecordString)),
	dbHandlerGraphic:show_window(Frame,Text),
	NewState=case dbHandlerGraphic:handle_window(RecordString,Frame,Targets) of
		{Frame,Line}->writeLine(Dataset,",",Line),State;
		NewFrame->State#state{graphic=NewFrame}
	end,
	{noreply,NewState};
handle_info(fit,State)->
	#state{dataset=Dataset,features=FeaturesNames,targets=TargetsNames}=State,
	file:position(Dataset,bof),
	file:read_line(Dataset),
	erlDecisor ! {loadTargets,[FeaturesNames,TargetsNames]},
	receive {erlDecisor,ackTargets}->ok end,
	readDataset(0,Dataset,ets:new(chunk,[duplicate_bag])),
	{noreply,State};
handle_info({change_train,Bool},State)->
	{noreply,State#state{training=Bool}};
handle_info(_,State)->
	{noreply,State}.

handle_call(fit,_,State)->
	#state{dataset=Dataset,features=FeaturesNames,targets=TargetsNames}=State,
	erlDecisor ! {loadTargets,[FeaturesNames,TargetsNames]},
	receive {erlDecisor,ackTargets}->ok end,
	readDataset(0,Dataset,ets:new(chunk,[duplicate_bag])),
	{reply,ok,State}.

readDataset(SeqNumber,File,Ets)->
	IsFinish=readDatasetChunk(File,file:read_line(File),Ets,0),
	case IsFinish of
		otherLines->
			DataChunk=ets:tab2list(Ets),
			erlDecisor ! {loadDataset,otherLines,DataChunk},
			ets:delete_all_objects(Ets),
			readDataset(SeqNumber+1,File,Ets);
		eof->
			DataChunk=ets:tab2list(Ets),
			erlDecisor ! {loadDataset,SeqNumber,eof,DataChunk},
			ets:delete(Ets)
	end.

readDatasetChunk(_,eof,_,_)->eof;
readDatasetChunk(_,_,_,100000)->otherLines;
readDatasetChunk(File,{ok,<<Line/binary>>},Ets,Int)->
		BinRecord=binary:split(Line,[<<",">>,<<"\n">>],[global,trim]),
		ParsedRecord=[parseRecord(H)||H<-BinRecord],
		ets:insert(Ets,{0,ParsedRecord}),
		readDatasetChunk(File,file:read_line(File),Ets,Int+1).

parseRecord(<<H/binary>>)->
	try binary_to_integer(H)
    catch
        error:badarg -> try binary_to_float(H)
        				catch
        					error:badarg->binary_to_list(H)
        				end
    end.

readFeaturesAndTargetNames(Dataset,TargetsFile)->
	{ok,<<FeaturesLine/binary>>}=file:read_line(Dataset),
	{ok,TargetsLine}=file:read_line(TargetsFile),
	FeaturesNames=string:split(string:trim(binary_to_list(FeaturesLine)),",",all),
	TargetsNames=string:split(string:trim(TargetsLine),",",all),
	{FeaturesNames,TargetsNames}.

stringify([H|T],Acc)->
	if
		is_integer(H) ->stringify(T,lists:append(Acc,[integer_to_list(H)]));
		is_float(H)->stringify(T,lists:append(Acc,[float_to_list(H,[{decimals,7}])]));
		true->stringify(T,lists:append(Acc,[H]))
	end;
stringify([],Acc)->Acc.

writeLine(File,Pattern,TupleLine)when is_tuple(TupleLine)->
	case lists:member(false,[is_list(X)||X<-tuple_to_list(TupleLine)]) of
		false->
			Record=lists:join(Pattern,tuple_to_list(TupleLine)),
			file:write(File,Record),
			file:write(File,"\n");
		true->
			exit("One element of line is not a string,will not write")
	end.
