-module(dbHandlerGraphic).
-export([get_window/1,show_window/2,handle_window/3]).
-include_lib("wx/include/wx.hrl").

get_window(Targets)->
	Frame=wxFrame:new(wx:null(),0,"RECORD TRAINER"),
	RdTextBox=wxTextCtrl:new(Frame,2,[{style, ?wxTE_MULTILINE bor ?wxTE_READONLY},{pos,{10,10}}]),
	wxTextCtrl:setSize(RdTextBox,200,200),
	wxStaticText:new(Frame,10,"PAY ATTENTION TO THE SELECTION,\nBEFORE PRESSING THE BUTTON!!",[{pos,{10,250}}]),
	Target=wxChoice:new(Frame,2,[{pos,{10,300}},{choices, Targets}]),
	wxChoice:setSelection(Target,0),
	SendDecision=wxButton:new(Frame,5, [{label, "SUBMIT"}, {pos,{10,350}}]),
	wxButton:connect(SendDecision, command_button_clicked,[{userData,Target}]),
	Frame.

show_window(Frame,Text)->
	RefBox=hd(wxFrame:getChildren(Frame)),
	TextBox=wx:typeCast(RefBox,wxTextCtrl),
	wxTextCtrl:setValue(TextBox,Text),
	wxFrame:show(Frame).

handle_window(RecordString,Frame,Targets)->
	receive
		{wx,5,_,UserData,_}->
			TargetVal=wxChoice:getStringSelection(UserData),
			Rd=lists:droplast(RecordString),
			NewRecord=Rd++[TargetVal],
			wxFrame:hide(Frame),
			{Frame,list_to_tuple(NewRecord)};
		{wx,0,_,_,_}->
			wxFrame:destroy(Frame),
			NewFrame=dbHandlerGraphic:get_window(Targets),
			NewFrame
	end.