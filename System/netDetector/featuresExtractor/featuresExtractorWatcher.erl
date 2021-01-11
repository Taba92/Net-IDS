-module(featuresExtractorWatcher).
-behaviour(supervisor).
-export([init/0,init/1]).

init()->
	CurDir=filename:dirname(code:where_is_file(?FILE)),
	code:add_patha(CurDir++"/FeaturesExtractor/"),
	supervisor:start_link({local,featuresExtractorWatcher},?MODULE,[]).

init([])->
	SupFlags = #{strategy=>one_for_all,intensity=>10,period=>1},
	ChildSpecs = [
		#{id =>featuresExtractor,start=>{featuresExtractor,init,[]},restart=>permanent,type=>worker}
    ],
    {ok, {SupFlags, ChildSpecs}}.
