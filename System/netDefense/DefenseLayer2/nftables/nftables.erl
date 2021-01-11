-module(nftables).
-export([format_list/1,is_error/1,format_error/1]).
-export([list_ruleset/0,list_ruleset/1,flush_ruleset/0]).
-export([add_table/1,add_table/2,delete_table/1,delete_table/2,list_tables/0,list_tables/1,
		list_table/1,list_table/2,list_table/3,flush_table/1,flush_table/2,exist_table/1,exist_table/2]).
-export([add_chain/2,add_chain/3,add_chain/4,create_chain/2,create_chain/3,create_chain/4,
		delete_chain/2,delete_chain/3,list_chain/2,list_chain/3,list_chain/4,list_chains/0,list_chains/1,
		flush_chain/2,flush_chain/3,rename_chain/3,rename_chain/4,set_policy/3,set_policy/4,
		exist_chain/2,exist_chain/3]).
-export([add_rule/3,add_rule/4,add_rule/5,insert_rule/3,insert_rule/4,insert_rule/5,
	    delete_rule/3,delete_rule/4,list_rule/4,list_rule/5,replace_rule/4,replace_rule/5,
	    exist_rule/4,exist_rule/5]).
-include("nftables.hrl").

%GENERAL UTILITY API
%Formatta l'output dei comandi list_....
format_list(NftListOutput)->
	{ok,Tokens,_}=nft_lexer:string(NftListOutput),
	{ok,Data}=nft_parser:parse(Tokens),
	Data.

%check if commands output is an error or not
is_error([$<|_])->true;
is_error(_)->false.

format_error(Err)->
	Pattern="<cmdline>:[0-9]+:[0-9]+-[0-9]+:.Error:.(.+)[:,].(.+)\n.+",
	{match,[Error,Reason]}=re:run(Err,Pattern,[{capture,all_but_first,list}]),
	[Error,Reason].
%%FINE UTILITY API


%%RULESET API
list_ruleset()->
	Cmd=?CMD++"list ruleset",
	{?EXEC(Cmd),Cmd}.
list_ruleset({opts,Opts})when is_list(Opts)->
	Cmd=?CMD++?STRINGOPTS(Opts)?WS"list ruleset",
	{?EXEC(Cmd),Cmd}.
flush_ruleset()->
	Cmd=?CMD++"flush ruleset",
	{?EXEC(Cmd),Cmd}.
%%%FINE RULESET API

%%TABLE API
add_table(Table)->
	add_table(ip,Table).
add_table(Family,Table)->
	Cmd=?CMD++"add table "++?STRING(Family)?WS?STRING(Table),
	{?EXEC(Cmd),Cmd}.

delete_table(Table)->
	delete_table(ip,Table).
delete_table(Family,Table)->
	Cmd=?CMD++"delete table "++?STRING(Family)?WS?STRING(Table),
	{?EXEC(Cmd),Cmd}.

list_table(Table)->
	list_table(ip,Table).
list_table(Table,{opts,Opts})->
	list_table(ip,Table,{opts,Opts});
list_table(Family,Table)->
	Cmd=?CMD++"list table "++?STRING(Family)?WS?STRING(Table),
	{?EXEC(Cmd),Cmd}.
list_table(Family,Table,{opts,Opts})->
	Cmd=?CMD++?STRINGOPTS(Opts)?WS"list table "++?STRING(Family)?WS?STRING(Table),
	{?EXEC(Cmd),Cmd}.

list_tables()->
	list_tables(ip).
list_tables(Family)->
	Cmd=?CMD++"list tables "++?STRING(Family),
	{?EXEC(Cmd),Cmd}.

exist_table(Table)->
	exist_table(ip,Table).
exist_table(Family,Table)->
	{Res,_}=list_table(Family,Table),
	is_error(Res).


flush_table(Table)->
	flush_table(ip,Table).
flush_table(Family,Table)->
	Cmd=?CMD++"flush table "++?STRING(Family)?WS?STRING(Table),
	{?EXEC(Cmd),Cmd}.
%%FINE TABLE API

%%CHAIN API
add_chain(Table,NameChain)->
	add_chain(ip,Table,NameChain).
add_chain(Table,NameChain,ChainSettings)when is_list(ChainSettings)->
	add_chain(ip,Table,NameChain,ChainSettings);
add_chain(Family,Table,NameChain)->
	Cmd=?CMD++"add chain "++?STRING(Family)?WS?STRING(Table)?WS ?STRING(NameChain),
	{?EXEC(Cmd),Cmd}.
add_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{priority,Prio}])->
	add_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{priority,Prio},{policy,accept}]);
add_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{priority,Prio},{policy,Policy}])->
	Settings="'{type "++?STRING(Type)?WS"hook "++?STRING(Hook)?WS"priority "++integer_to_list(Prio)?WS";policy "++?STRING(Policy)++";}'",
	Cmd=?CMD++"add chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(NameChain)?WS Settings,
	{?EXEC(Cmd),Cmd};
add_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{device,Dev},{priority,Prio}])->
	add_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{device,Dev},{priority,Prio},{policy,accept}]);
add_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{device,Dev},{priority,Prio},{policy,Policy}])->
	Settings="'{type "++?STRING(Type)?WS"hook "++?STRING(Hook)?WS"device "++?STRING(Dev)?WS"priority "++integer_to_list(Prio)?WS";policy "++?STRING(Policy)++";}'",
	Cmd=?CMD++"add chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(NameChain)?WS Settings,
	{?EXEC(Cmd),Cmd}.

create_chain(Table,NameChain)->
	create_chain(ip,Table,NameChain).
create_chain(Table,NameChain,ChainSettings)when is_list(ChainSettings)->
	create_chain(ip,Table,NameChain,ChainSettings);
create_chain(Family,Table,NameChain)->
	Cmd=?CMD++"create chain "++?STRING(Family)?WS?STRING(Table)?WS ?STRING(NameChain),
	{?EXEC(Cmd),Cmd}.
create_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{priority,Prio}])->
	create_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{priority,Prio},{policy,accept}]);
create_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{priority,Prio},{policy,Policy}])->
	Settings="'{type "++?STRING(Type)?WS"hook "++?STRING(Hook)?WS"priority "++integer_to_list(Prio)?WS";policy "++?STRING(Policy)++";}'",
	Cmd=?CMD++"create chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(NameChain)?WS Settings,
	{?EXEC(Cmd),Cmd};
create_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{device,Dev},{priority,Prio}])->
	create_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{device,Dev},{priority,Prio},{policy,accept}]);
create_chain(Family,Table,NameChain,[{type,Type},{hook,Hook},{device,Dev},{priority,Prio},{policy,Policy}])->
	Settings="'{type "++?STRING(Type)?WS"hook "++?STRING(Hook)?WS"device "++?STRING(Dev)?WS"priority "++integer_to_list(Prio)?WS";policy "++?STRING(Policy)++";}'",
	Cmd=?CMD++"create chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(NameChain)?WS Settings,
	{?EXEC(Cmd),Cmd}.

delete_chain(Table,NameChain)->
	delete_chain(ip,Table,NameChain).
delete_chain(Family,Table,NameChain)->
	Cmd=?CMD++"delete chain "++?STRING(Family)?WS?STRING(Table)?WS ?STRING(NameChain),
	{?EXEC(Cmd),Cmd}.

list_chain(Table,NameChain)->
	list_chain(ip,Table,NameChain).
list_chain(Table,NameChain,{opts,Opts})->
	list_chain(ip,Table,NameChain,{opts,Opts});
list_chain(Family,Table,NameChain)->
	Cmd=?CMD++"list chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(NameChain),
	{?EXEC(Cmd),Cmd}.
list_chain(Family,Table,NameChain,{opts,Opts})->
	Cmd=?CMD++?STRINGOPTS(Opts)?WS"list chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(NameChain),
	{?EXEC(Cmd),Cmd}.

list_chains()->
	list_chains(ip).
list_chains(Family)->
	Cmd=?CMD++"list chains "++?STRING(Family),
	{?EXEC(Cmd),Cmd}.

flush_chain(Table,NameChain)->
	flush_chain(ip,Table,NameChain).
flush_chain(Family,Table,NameChain)->
	Cmd=?CMD++"flush chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(NameChain),
	{?EXEC(Cmd),Cmd}.

rename_chain(Table,OldName,NewName)->
	rename_chain(ip,Table,OldName,NewName).
rename_chain(Family,Table,OldName,NewName)->
	Cmd=?CMD++"rename chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(OldName)?WS?STRING(NewName),
	{?EXEC(Cmd),Cmd}.

exist_chain(Table,Chain)->
	exist_chain(ip,Table,Chain).
exist_chain(Family,Table,Chain)->
	{Res,_}=list_chain(Family,Table,Chain),
	is_error(Res).

set_policy(Table,Chain,Policy)->
	set_policy(ip,Table,Chain,Policy).
set_policy(Family,Table,Chain,Policy)->
	Cmd=?CMD++"chain "++?STRING(Family)?WS?STRING(Table)?WS?STRING(Chain)?WS"'{policy "++?STRING(Policy)++"}'",
	{?EXEC(Cmd),Cmd}.
%%FINE CHAIN API

%%RULE API
add_rule(Table,Chain,Statement)->
	add_rule(ip,Table,Chain,Statement).
add_rule(Table,Chain,{pos,Pos},Statement)->
	add_rule(ip,Table,Chain,{pos,Pos},Statement);
add_rule(Family,Table,Chain,Statement)->
	Cmd=?CMD++"add rule "++?STRING(Family)?WS?STRING(Table)?WS?STRING(Chain)?WS Statement,
	{?EXEC(Cmd),Cmd}.
add_rule(Family,Table,Chain,{pos,Pos},Statement)->
	Cmd=?CMD++"add rule "++?STRING(Family)?WS?STRING(Table)?WS?STRING(Chain)?WS"position "++integer_to_list(Pos)++" "++Statement,
	{?EXEC(Cmd),Cmd}.

insert_rule(Table,Chain,Statement)->
	insert_rule(ip,Table,Chain,Statement).
insert_rule(Table,Chain,{pos,Pos},Statement)->
	insert_rule(ip,Table,Chain,{pos,Pos},Statement);
insert_rule(Family,Table,Chain,Statement)->
	Cmd=?CMD++"insert rule "++?STRING(Family)?WS?STRING(Table)?WS?STRING(Chain)?WS Statement,
	{?EXEC(Cmd),Cmd}.
insert_rule(Family,Table,Chain,{pos,Pos},Statement)->
	Cmd=?CMD++"insert rule "++?STRING(Family)?WS?STRING(Table)?WS?STRING(Chain)?WS"position "++integer_to_list(Pos)++" "++Statement,
	{?EXEC(Cmd),Cmd}.

delete_rule(Table,Chain,Handle)->
	delete_rule(ip,Table,Chain,Handle).
delete_rule(Family,Table,Chain,Handle)->
	Cmd=?CMD++"delete rule "++?STRING(Family)?WS?STRING(Table)?WS?STRING(Chain)?WS"handle "++integer_to_list(Handle),
	{?EXEC(Cmd),Cmd}.

replace_rule(Table,Chain,Handle,Statement)->
	replace_rule(ip,Table,Chain,Handle,Statement).
replace_rule(Family,Table,Chain,Handle,Statement)->
	Cmd=?CMD++"replace rule "++?STRING(Family)?WS?STRING(Table)?WS?STRING(Chain)?WS"handle "++integer_to_list(Handle)?WS Statement,
	{?EXEC(Cmd),Cmd}.

list_rule(Table,Chain,StatementOrHandle,MapListOutput)->
	list_rule(ip,Table,Chain,StatementOrHandle,MapListOutput).
%Given a statement or handle and format_list, it return the rule : handle if exist
list_rule(Family,Table,Chain,Statement,MapListOutput)when is_list(Statement)->
	#{chains:=Chains}=maps:get({?STRING(Table),?STRING(Family)},MapListOutput),
	case maps:get(?STRING(Chain),Chains,no_chain) of
		no_chain->{error,no_chain};
		ChainData->
			Rules=maps:get(rules,ChainData),
			lists:keyfind(Statement,1,Rules)
	end;
list_rule(Family,Table,Chain,Handle,MapListOutput)when is_integer(Handle)->
	#{chains:=Chains}=maps:get({?STRING(Table),?STRING(Family)},MapListOutput),
	case maps:get(?STRING(Chain),Chains,no_chain) of
		no_chain->{error,no_chain};
		ChainData->
			Rules=maps:get(rules,ChainData),
			lists:keyfind(integer_to_list(Handle),2,Rules)
	end.

exist_rule(Table,Chain,StatementOrHandle,MapListOutput)->
	exist_rule(ip,Table,Chain,StatementOrHandle,MapListOutput).
exist_rule(Family,Table,Chain,StatementOrHandle,MapListOutput)->
	case list_rule(Family,Table,Chain,StatementOrHandle,MapListOutput) of
		{_,_}->true;
		_->false
	end. 
%%FINE RULE API