Definitions.

TAB = table
CH = chain
TYPE = type
HOOK = hook
PRIO = priority
POLICY = policy
DEV = device
HANDLE = handle
STRING = [0-9a-zA-Z\.]+
STARTOBJ = {
GRATELLA = #
SEMICOL = ;
ENDOBJ = }
WS = [\s\t]
LB = \n|\r\n|\r

Rules.
{TAB}       : {token,{tab,TokenChars}}.
{CH}       : {token,{ch,TokenChars}}.
{TYPE}       : {token,{type,TokenChars}}.
{HOOK}       : {token,{hook,TokenChars}}.
{PRIO}       : {token,{prio,TokenChars}}.
{POLICY}       : {token,{policy,TokenChars}}.
{DEV}       : {token,{dev,TokenChars}}.
{HANDLE}       : {token,{handle,TokenChars}}.
{STRING}      : {token, {string, TokenChars}}.
{STARTOBJ}    : skip_token.
{GRATELLA}    : skip_token.
{SEMICOL}    : skip_token.
{ENDOBJ}    : skip_token.
{WS}        : skip_token.
{LB}        : skip_token.

Erlang code.

