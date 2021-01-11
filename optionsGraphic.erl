-module(optionsGraphic).
-export([init/1,handle_info/2]).
-record(state,{dets,ets,window}).
-include_lib("wx/include/wx.hrl").

init([])->
	wx:new(),
	Dets=options:file_configs(),
	Ets=options:load_configs(Dets),
	Frame=graphic_interface(Dets),
	State=#state{dets=Dets,ets=Ets,window=Frame},
	{ok,State}.

graphic_interface(Dets)->
	Frame=wxFrame:new(wx:null(),0,"NIDS",[{size,{480,550}}]),
	wxFrame:connect(Frame, close_window),
	wxStaticText:new(Frame,1,"Opzione",[{pos,{20,30}}]),
	Opt=wxTextCtrl:new(Frame,2,[{pos,{150, 30}}]),
	wxTextCtrl:setSize(Opt,210,37),
	wxStaticText:new(Frame,3,"Valore",[{pos,{20,80}}]),
	Value=wxTextCtrl:new(Frame,4,[{pos,{150, 80}}]),
	wxTextCtrl:setSize(Value,210,37),
	Output= wxTextCtrl:new(Frame,5,[{style, ?wxTE_MULTILINE bor ?wxTE_READONLY},{pos,{170,140}}]),
	wxTextCtrl:setSize(Output,150,150),
	wxTextCtrl:setValue(Output,options:format(options:list_configs(Dets))),
	Reset=wxButton:new(Frame,6, [{label, "RESET"}, {pos,{20, 140}}]),
	wxButton:connect(Reset, command_button_clicked,[{userData,Output}]),
	SetOpt=wxButton:new(Frame,7, [{label, "SETTA OPZIONE"}, {pos,{20, 190}}]),
	wxButton:connect(SetOpt, command_button_clicked,[{userData,{Opt,Value,Output}}]),
	Observer=wxButton:new(Frame,8, [{label, "OBSERVER"}, {pos,{20, 240}}]),
	wxButton:connect(Observer, command_button_clicked),
	Recompilaton= wxTextCtrl:new(Frame,5,[{style, ?wxTE_MULTILINE bor ?wxTE_READONLY},{pos,{170,300}}]),
	wxTextCtrl:setSize(Recompilaton,300,150),
	HotReload=wxButton:new(Frame,10, [{label, "HOT CODE RELOAD"}, {pos,{20, 340}}]),
	wxButton:connect(HotReload, command_button_clicked,[{userData,Recompilaton}]),
	Fit=wxButton:new(Frame,9, [{label, "ALLENA"}, {pos,{20, 290}}]),
	wxButton:connect(Fit, command_button_clicked,[{userData,[Fit,HotReload]}]),
	FolderLog=wxTextCtrl:new(Frame,12,[{pos,{170, 460}}]),
	wxTextCtrl:setSize(FolderLog,210,37),
	Log=wxButton:new(Frame,11, [{label, "DUMP LOG"}, {pos,{20, 460}}]),
	wxButton:connect(Log, command_button_clicked,[{userData,{Log,FolderLog}}]),
	wxFrame:show(Frame),
	Frame.

handle_info(restart_window,State)->
	NewWindow=graphic_interface(State#state.dets),
	NewState=State#state{window=NewWindow},
	{noreply,NewState};
handle_info({wx,0,_,_,_},State)->
	#state{window=Window}=State,
	wxFrame:destroy(Window),
	{noreply,State};
handle_info({wx,6,_,TextBox,_},State)->
	#state{dets=Dets}=State,
	options:reset_configs(Dets),
	Opts=options:list_configs(Dets),
	wxTextCtrl:setValue(TextBox,options:format(Opts)),
	options:showMsg("RESET OPZIONI EFFETTUATO"),
	{noreply,State};
handle_info({wx,7,_,{OptBox,ValueBox,TextBox},_},State)->
	#state{dets=Dets}=State,
	{Opt,Value}={wxTextCtrl:getValue(OptBox),wxTextCtrl:getValue(ValueBox)},
	options:set_config(Dets,{list_to_atom(Opt),list_to_atom(Value)}),
	Opts=options:list_configs(Dets),
	wxTextCtrl:setValue(TextBox,options:format(Opts)),
	{noreply,State};
handle_info({wx,8,_,_,_},State)->
	case whereis(observer) of
		undefined->spawn(observer,start,[]);
		_->ok
	end,
	{noreply,State};
handle_info({wx,9,_,Btns,_},State)->
	case (whereis(dbHandler)==undefined) or (whereis(erlDecisor)==undefined) of
		true->options:showMsg("REFITTING DEL MODELLO NON DISPONIBILE AL MOMENTO");
		false->
			[wxButton:disable(Btn)||Btn<-Btns],
			dbHandler ! fit,
			receive fitted->[wxButton:enable(Btn)||Btn<-Btns] end
	end,
	{noreply,State};
handle_info({wx,10,_,TextBox,_},State)->
	ValueRet=options:hot_code_reload(),
	wxTextCtrl:setValue(TextBox,ValueRet),
	{noreply,State};
handle_info({wx,11,_,{Btn,TextBox},_},State)->
	Dir=wxTextCtrl:getValue(TextBox),
	case filelib:is_dir(Dir) of
		true->
			wxButton:disable(Btn),
			options:dump_log(Dir),
			wxButton:enable(Btn),
			options:showMsg("DUMP DEI LOG TERMINATO~n");
		false->
			options:showMsg("PERCORSO NON VALIDO O CARTELLA INESISTENTE")
	end,
	{noreply,State}.

