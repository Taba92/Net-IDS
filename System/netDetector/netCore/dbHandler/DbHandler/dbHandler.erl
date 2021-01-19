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
	[{_,Training}]=ets:lookup(opts,training),
	State=case filelib:is_file(TargetsFileName) andalso filelib:is_file(File) of
		true->
			{ok,Dataset}=file:open(File,[read,append,raw,binary,{read_ahead,200000}]),
			{ok,FileTargets}=file:open(TargetsFileName,[read]),
			{_,Targets}=readFeaturesAndTargetNames(Dataset,FileTargets),
			Frame=dbHandlerGraphic:get_window(Targets),
			#state{graphic=Frame,dataset=Dataset,targets=FileTargets,training=Training};
		false->
			options:showMsg("ATTENZIONE, NON SONO STATI TROVATI I FILE DATI PER IL DBHANDLER\nINIZIALIZZARLI AL PIÙ PRESTO!!!!"),
			#state{training=Training}
		end,
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
			TargetsName=CurDir++"/Dataset/labels.txt",
			DatasetName=CurDir++"/Dataset/Dataset.csv",
			file:close(Dataset),
			file:close(FileTargets),
			file:delete(DatasetName),
			file:delete(TargetsName),
			merge_and_extract(Dir,DatasetName,TargetsName),
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

merge_and_extract(ChunksDir,DatasetPath,TargetsPath)->
	{ok,FilesNames}=file:list_dir(ChunksDir),
	{ok,NewDataset}=file:open(DatasetPath,[append]),
	{ok,NewTargets}=file:open(TargetsPath,[write]),
	merge_and_extract(FilesNames,ChunksDir,true,[],NewDataset,NewTargets).
merge_and_extract([],_,false,Acc,Dataset,Targets)->
	file:close(Dataset),
	TargetsString=lists:concat(lists:join(",",Acc)),
	file:write(Targets,TargetsString),
	file:close(Targets);
merge_and_extract([H|T],ChunksDir,false,Acc,NewDataset,NewTargets)->
	{ok,Chunk}=file:open(ChunksDir++H,[read]),
	file:read_line(Chunk),%gli cavo la prima linea,in quanto i "titoli" delle features le ho gia immagazzinati
	NewAcc=copy_chunk(Chunk,NewDataset,Acc),
	merge_and_extract(T,ChunksDir,false,NewAcc,NewDataset,NewTargets);
merge_and_extract([H|T],ChunksDir,true,Acc,NewDataset,NewTargets)->
	{ok,Chunk}=file:open(ChunksDir++H,[read]),
	NewAcc=copy_chunk(Chunk,NewDataset,Acc),
	merge_and_extract(T,ChunksDir,false,NewAcc,NewDataset,NewTargets).

copy_chunk(Chunk,NewDataset,Acc)->
	copy_chunk(file:read_line(Chunk),Chunk,NewDataset,Acc).
copy_chunk(eof,Chunk,_,Acc)->
	file:close(Chunk),
	Acc;
copy_chunk({ok,Line},Chunk,NewDataset,Acc)->
	ParsedLine=string:split(string:trim(Line),",",all),
	case lists:member("Nan",ParsedLine) orelse lists:member("Infinity",ParsedLine) of
		true->copy_chunk(file:read_line(Chunk),Chunk,NewDataset,Acc);
		false->file:write(NewDataset,Line),
				Target=lists:last(ParsedLine),
				NewAcc=case (lists:member(Target,Acc)==false) and (Target/=" Label") of
						true->Acc++[Target];
						false->Acc
					end,
			   copy_chunk(file:read_line(Chunk),Chunk,NewDataset,NewAcc)
	end.

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
