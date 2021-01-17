-module(dbHandler).
-export([init/0,init/1,handle_info/2]).
-record(state,{graphic,dataset,targets,training}).

init()->
	gen_server:start_link({local,dbHandler},?MODULE,[],[]).

init([])->
	wx:new(),
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	TargetsFileName=CurDir++"/Dataset/labels.txt",
	File=CurDir++"/Dataset/Dataset.csv",
	{ok,Dataset}=file:open(File,[read,append,raw,binary,{read_ahead,200000}]),
	{ok,FileTargets}=file:open(TargetsFileName,[read]),
	[{_,Training}]=ets:lookup(opts,training),
	{_,Targets}=readFeaturesAndTargetNames(Dataset,FileTargets),
	Frame=dbHandlerGraphic:get_window(Targets),
	State=#state{graphic=Frame,dataset=Dataset,targets=FileTargets,training=Training},
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
	#state{dataset=Dataset,targets=FileTargets}=State,
	file:position(Dataset,bof),
	{Features,Targets}=readFeaturesAndTargetNames(Dataset,FileTargets),
	erlDecisor ! {loadTargets,[Features,Targets]},
	receive {erlDecisor,ackTargets}->ok end,
	readDataset(0,Dataset,ets:new(chunk,[duplicate_bag])),
	{noreply,State};
handle_info({create_new_dataset,Dir},State)->
	#state{dataset=Dataset,targets=FileTargets}=State,
	NewState=case is_valid_chunks_dir(Dir) of
		true->
			CurDir=filename:dirname(code:where_is_file(?FILE)),
			DataFolder=CurDir++"/Dataset",
			TargetsName=CurDir++"/Dataset/labels.txt",
			DatasetName=CurDir++"/Dataset/Dataset.csv",
			file:close(Dataset),
			file:close(FileTargets),
			file:delete(DatasetName),
			file:delete(TargetsName),
			os:cmd("sudo "++CurDir++"/merger.py "++Dir++" "++DataFolder),
			os:cmd("sudo "++CurDir++"/extractor.py "++Dir++" "++DataFolder),
			{ok,NewDataset}=file:open(DatasetName,[read,append,raw,binary,{read_ahead,200000}]),
			{ok,NewFileTargets}=file:open(TargetsName,[read]),
			{_,Targets}=readFeaturesAndTargetNames(NewDataset,NewFileTargets),
			NewFrame=dbHandlerGraphic:get_window(Targets),
			options ! created_new_dataset,
			State#state{graphic=NewFrame,dataset=NewDataset,targets=NewFileTargets};
		false->options ! invalid_dir,
				State
	end,
	{noreply,NewState};
handle_info({change_train,Bool},State)->
	{noreply,State#state{training=Bool}};
handle_info(_,State)->
	{noreply,State}.


is_valid_chunks_dir(Dir)->
	{ok,Chunks}=file:list_dir(Dir),
	case Chunks of%guardo se c'è almeno un file
		[]->false;
		Files->Extensions=[filename:extension(File)==".csv"||File<-Files],%guardo se son tutti file .csv
			case lists:member(false,Extensions) of
				true->false;
				false->true
			end
	end.


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
	file:position(TargetsFile,bof),
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
