Nonterminals
tables table chains chain opts rules rule ruleBody.

Terminals
string tab ch type hook prio policy dev handle.

Rootsymbol tables.

tables -> table tables : maps:merge('$1','$2').
tables -> table : '$1'.

table -> tab string string chains : #{{unzip('$3'),unzip('$2')}=>#{chains=>'$4'}}.
table -> tab string string : #{{unzip('$3'),unzip('$2')}=>#{}}.

chains -> chain chains : maps:merge('$1','$2').
chains -> chain : '$1'.

chain -> ch string : #{unzip('$2')=>#{opts=>#{},rules=>[]}}.
chain -> ch string opts rules : #{unzip('$2')=>#{opts=>'$3',rules=>'$4'}}.
chain -> ch string opts : #{unzip('$2')=>#{opts=>'$3',rules=>[]}}.
chain -> ch string rules : #{unzip('$2')=>#{opts=>#{},rules=>'$3'}}.

opts -> type string hook string prio string policy string : map('$2','$4','$6','$8').
opts -> type string hook string dev string prio string policy string : map('$2','$4','$6','$8','$10').

rules -> rule rules : lists:merge('$1','$2').
rules -> rule : '$1'.

rule -> ruleBody : [{'$1',null}].
rule -> ruleBody handle string : [{'$1',unzip('$3')}].

ruleBody -> string ruleBody : unzip('$1')++" "++'$2'.
ruleBody -> string : unzip('$1').

Erlang code.

unzip({_,V})->V.
map(A,B,C,D)->#{type=>unzip(A),hook=>unzip(B),priority=>unzip(C),policy=>unzip(D)}.
map(A,B,C,D,E)->#{type=>unzip(A),hook=>unzip(B),device=>unzip(C),priority=>unzip(D),policy=>unzip(E)}.