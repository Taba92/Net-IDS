-module(optionsGraphic).
-export([init/0,init/1,handle_info/2]).
-define(ADJUSTDIR(Dir),case lists:last(Dir)/=$/ of true->Dir++"/";false->Dir end).
-record(state,{dets,ets,window}).
-include_lib("wx/include/wx.hrl").

init()-> gen_server:start({local,options},?MODULE,[],[]).

init([])->
	wx:new(),
	Dets=options:file_configs(),
	Ets=options:load_configs(Dets),
	Frame=graphic_interface(Dets),
	State=#state{dets=Dets,ets=Ets,window=Frame},
	{ok,State}.


graphic_interface(Dets)->
	Frame=wxFrame:new(wx:null(),0,"NIDS",[{size,{500,500}}]),
	wxFrame:connect(Frame, close_window),
	Notebook = wxNotebook:new(Frame, ?wxID_ANY),
	SettingsPanel = setupSettingsPanel(Notebook,Dets),
	UpdatesPanel= setupUpdatesPanel(Notebook),
	UtilsPanel=setupUtilsPanel(Notebook),
	wxNotebook:addPage(Notebook, SettingsPanel, "Run-time settings"),
	wxNotebook:addPage(Notebook, UpdatesPanel, "Run-time updates"),
	wxNotebook:addPage(Notebook, UtilsPanel, "Utilities"),
	wxFrame:show(Frame),
	Frame.

setupSettingsPanel(Parent,Dets)->
	SettingsPanel = wxPanel:new(Parent),
  	wxStaticText:new(SettingsPanel,?wxID_ANY,"Option",[{pos,{20,30}}]),
  	Opt=wxTextCtrl:new(SettingsPanel,?wxID_ANY,[{pos,{150, 30}}]),
	wxTextCtrl:setSize(Opt,210,37),
	wxStaticText:new(SettingsPanel,?wxID_ANY,"Value",[{pos,{20,80}}]),
	Value=wxTextCtrl:new(SettingsPanel,?wxID_ANY,[{pos,{150, 80}}]),
	wxTextCtrl:setSize(Value,210,37),
	Output= wxTextCtrl:new(SettingsPanel,?wxID_ANY,[{style, ?wxTE_MULTILINE bor ?wxTE_READONLY},{pos,{170,140}}]),
	wxTextCtrl:setSize(Output,150,150),
	wxTextCtrl:setValue(Output,options:format(options:list_configs(Dets))),
	Reset=wxButton:new(SettingsPanel,1, [{label, "RESET"}, {pos,{20, 140}}]),
	wxButton:connect(Reset, command_button_clicked,[{userData,Output}]),
	SetOpt=wxButton:new(SettingsPanel,2, [{label, "SET OPTION"}, {pos,{20, 190}}]),
	wxButton:connect(SetOpt, command_button_clicked,[{userData,{Opt,Value,Output}}]),
  	SettingsPanel.

setupUpdatesPanel(Parent)->
  	UpdatesPanel = wxPanel:new(Parent),
  	Fit=wxButton:new(UpdatesPanel,3, [{label, "FIT"}, {pos,{20, 30}}]),
  	Dataset=wxButton:new(UpdatesPanel,5, [{label, "NEW DATASET"}, {pos,{20, 250}}]),
	ChunksFolder=wxTextCtrl:new(UpdatesPanel,?wxID_ANY,[{pos,{170, 250}}]),
	wxTextCtrl:setSize(ChunksFolder,210,37),
	wxButton:connect(Dataset, command_button_clicked,[{userData,ChunksFolder}]),
	wxButton:connect(Fit, command_button_clicked),
  	UpdatesPanel.

setupUtilsPanel(Parent)->
	UtilsPanel = wxPanel:new(Parent),
	Observer=wxButton:new(UtilsPanel,6, [{label, "OBSERVER"}, {pos,{20, 30}}]),
	wxButton:connect(Observer, command_button_clicked),
	FolderLog=wxTextCtrl:new(UtilsPanel,?wxID_ANY,[{pos,{170, 80}}]),
	wxTextCtrl:setSize(FolderLog,210,37),
	Log=wxButton:new(UtilsPanel,7, [{label, "DUMP LOG"}, {pos,{20, 80}}]),
	wxButton:connect(Log, command_button_clicked,[{userData,FolderLog}]),
	UtilsPanel.

handle_info(restart_window,State)->
	NewWindow=graphic_interface(State#state.dets),
	NewState=State#state{window=NewWindow},
	{noreply,NewState};
handle_info({wx,0,_,_,_},State)->
	#state{window=Window}=State,
	wxFrame:destroy(Window),
	{noreply,State};
handle_info({wx,1,_,TextBox,_},State)->
	#state{dets=Dets}=State,
	options:reset_configs(Dets),
	Opts=options:list_configs(Dets),
	wxTextCtrl:setValue(TextBox,options:format(Opts)),
	options:showMsg("OPTIONS RESET DONE"),
	{noreply,State};
handle_info({wx,2,_,{OptBox,ValueBox,TextBox},_},State)->
	#state{dets=Dets}=State,
	{Opt,Value}={wxTextCtrl:getValue(OptBox),wxTextCtrl:getValue(ValueBox)},
	options:set_config(Dets,{list_to_atom(Opt),list_to_atom(Value)}),
	Opts=options:list_configs(Dets),
	wxTextCtrl:setValue(TextBox,options:format(Opts)),
	{noreply,State};
handle_info({wx,6,_,_,_},State)->
	case whereis(observer) of
		undefined->spawn(observer,start,[]);
		_->ok
	end,
	{noreply,State};
handle_info({wx,3,_,_,_},State)->
	case (whereis(dbHandler)==undefined) or (whereis(erlDecisor)==undefined) of
		true->options:showMsg("MODEL REFITTING NO AVAILABLE TEMPORALY");
		false->
			wxWindow:disable(State#state.window),
			sys:suspend(sniffer,5000),%%sospendo lo sniffing
			netFlow ! suspend_recorders,%%sospendo i recorder dei flussi
			dbHandler ! fit,
			receive fitted->wxWindow:enable(State#state.window) end,
			sys:resume(sniffer,5000),
			netFlow ! resume_recorders,%%riattivo i recorders dei flussi
			options:showMsg("MODEL REFITTED")
	end,
	{noreply,State};
handle_info({wx,7,_,TextBox,_},State)->
	Dir=wxTextCtrl:getValue(TextBox),
	case filelib:is_dir(Dir) of
		true->
			wxWindow:disable(State#state.window),
			options:dump_log(?ADJUSTDIR(Dir)),
			wxWindow:enable(State#state.window),
			options:showMsg("LOG DUMPING TERMINATED");
		false->
			options:showMsg("INVALID PATH OR UNEXPECTED FOLDER")
	end,
	{noreply,State};
handle_info({wx,5,_,TextBox,_},State)->
	Dir=wxTextCtrl:getValue(TextBox),
	case filelib:is_dir(Dir) andalso whereis(dbHandler)/=undefined of
		true->
			wxWindow:disable(State#state.window),
			dbHandler ! {create_new_dataset,?ADJUSTDIR(Dir)},
			receive 
				created_new_dataset->options:showMsg("NEW DATASET CREATED");
				invalid_dir->options:showMsg("INVALID CHUNKS FOLDER,CHECK THAT ALL ARE CSV FILES AND THAT AT LEAST ONE EXISTS!!")
			end,
			wxWindow:enable(State#state.window);
		false->
			options:showMsg("INVALID PATH OR DBHANDLER INACTIVE")
	end,
	{noreply,State}.

