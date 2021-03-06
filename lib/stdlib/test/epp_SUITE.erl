%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 1998-2010. All Rights Reserved.
%%
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% %CopyrightEnd%

-module(epp_SUITE).
-export([all/1]).

-export([rec_1/1, predef_mac/1, 
	 upcase_mac/1, upcase_mac_1/1, upcase_mac_2/1,
	 variable/1, variable_1/1, otp_4870/1, otp_4871/1, otp_5362/1,
         pmod/1, not_circular/1, skip_header/1, otp_6277/1, otp_7702/1,
         otp_8130/1, overload_mac/1, otp_8388/1]).

-export([epp_parse_erl_form/2]).

%%
%% Define to run outside of test server
%%
%-define(STANDALONE,1).

-ifdef(STANDALONE).
-compile(export_all).
-define(line, put(line, ?LINE), ).
-define(config(A,B),config(A,B)).
%% -define(t, test_server).
-define(t, io).
config(priv_dir, _) ->    
    filename:absname("./epp_SUITE_priv");
config(data_dir, _) ->
    filename:absname("./epp_SUITE_data").
-else.
-include("test_server.hrl").
-export([init_per_testcase/2, fin_per_testcase/2]).

% Default timetrap timeout (set in init_per_testcase).
-define(default_timeout, ?t:minutes(1)).

init_per_testcase(_, Config) ->
    ?line Dog = ?t:timetrap(?default_timeout),
    [{watchdog, Dog} | Config].
fin_per_testcase(_, Config) ->
    Dog = ?config(watchdog, Config),
    test_server:timetrap_cancel(Dog),
    ok.
-endif.

all(doc) ->
    ["Test cases for epp."];
all(suite) ->
    [rec_1, upcase_mac, predef_mac, variable, otp_4870, otp_4871, otp_5362,
     pmod, not_circular, skip_header, otp_6277, otp_7702, otp_8130,
     overload_mac, otp_8388].

rec_1(doc) ->
    ["Recursive macros hang or crash epp (OTP-1398)."];
rec_1(suite) ->
    [];
rec_1(Config) when is_list(Config) ->
    ?line File = filename:join(?config(data_dir, Config), "mac.erl"),
    ?line {ok, List} = epp_parse_file(File, [], []),
    %% we should encounter errors
    ?line {value, _} = lists:keysearch(error, 1, List),
    ?line check_errors(List),
    ok.

%%% Here is a little reimplementation of epp:parse_file, which times out
%%% after 4 seconds if the epp server doesn't respond. If we use the
%%% regular epp:parse_file, the test case will time out, and then epp
%%% server will go on growing until we dump core.
epp_parse_file(File, Inc, Predef) ->
    {ok, Epp} = epp:open(File, Inc, Predef),
    List = collect_epp_forms(Epp),
    epp:close(Epp),
    {ok, List}.

collect_epp_forms(Epp) ->
    Result = epp_parse_erl_form(Epp),
    case Result of
	{error, _Error} ->
	    [Result | collect_epp_forms(Epp)];
	{ok, Form} ->
	    [Form | collect_epp_forms(Epp)];
	{eof, _} ->
	    [Result]
    end.

epp_parse_erl_form(Epp) ->
    P = spawn(?MODULE, epp_parse_erl_form, [Epp, self()]),
    receive
	{P, Result} ->
	    Result
    after 4000 ->
	    exit(Epp, kill),
	    exit(P, kill),
	    timeout
    end.

epp_parse_erl_form(Epp, Parent) ->
    Parent ! {self(), epp:parse_erl_form(Epp)}.

check_errors([]) ->
    ok;
check_errors([{error, Info} | Rest]) ->
    ?line {Line, Mod, Desc} = Info,
    ?line case Line of
              I when is_integer(I) -> ok;
              {L,C} when is_integer(L), is_integer(C), C >= 1 -> ok
          end,
    ?line Str = lists:flatten(Mod:format_error(Desc)),
    ?line [Str] = io_lib:format("~s", [Str]),
    check_errors(Rest);
check_errors([_ | Rest]) ->
    check_errors(Rest).

upcase_mac(doc) ->
    ["Check that uppercase macro names are implicitly quoted (OTP-2608)"];
upcase_mac(suite) ->
    [upcase_mac_1, upcase_mac_2].

upcase_mac_1(doc) ->
    [];
upcase_mac_1(suite) ->
    [];
upcase_mac_1(Config) when is_list(Config) ->
    ?line File = filename:join(?config(data_dir, Config), "mac2.erl"),
    ?line {ok, List} = epp:parse_file(File, [], []),
    ?line [_, {attribute, _, plupp, Tuple} | _] = List,
    ?line Tuple = {1, 1, 3, 3},
    ok.

upcase_mac_2(doc) ->
    [];
upcase_mac_2(suite) ->
    [];
upcase_mac_2(Config) when is_list(Config) ->
    ?line File = filename:join(?config(data_dir, Config), "mac2.erl"),
    ?line {ok, List} = epp:parse_file(File, [], [{p, 5}, {'P', 6}]),
    ?line [_, {attribute, _, plupp, Tuple} | _] = List,
    ?line Tuple = {5, 5, 6, 6},
    ok.

predef_mac(doc) ->
    [];
predef_mac(suite) ->
    [];
predef_mac(Config) when is_list(Config) ->
    ?line File = filename:join(?config(data_dir, Config), "mac3.erl"),
    ?line {ok, List} = epp:parse_file(File, [], []),
    ?line [_,
	   {attribute, LineCol1, l, Line1},
	   {attribute, _, f, File},
	   {attribute, _, machine1, _},
	   {attribute, _, module, mac3},
	   {attribute, _, m, mac3},
	   {attribute, _, ms, "mac3"},
	   {attribute, _, machine2, _}
	   | _] = List,
    ?line case LineCol1 of
              Line1 -> ok;
              {Line1,_} -> ok
          end,
    ok.

variable(doc) ->
    ["Check variable as first file component of the include directives."];
variable(suite) ->
    [variable_1].

variable_1(doc) ->
    [];
variable_1(suite) ->
    [];
variable_1(Config) when is_list(Config) ->
    ?line DataDir = ?config(data_dir, Config),
    ?line File = filename:join(DataDir, "variable_1.erl"),
    ?line true = os:putenv("VAR", DataDir),
    %% variable_1.erl includes variable_1_include.hrl and
    %% variable_1_include_dir.hrl.
    ?line {ok, List} = epp:parse_file(File, [], []),
    ?line {value, {attribute,_,a,{value1,value2}}} = 
	lists:keysearch(a,3,List),
    ok.

otp_4870(doc) ->
    ["undef without module declaration"];
otp_4870(suite) ->
    [];
otp_4870(Config) when is_list(Config) ->
    Ts = [{otp_4870,
           <<"-undef(foo).
           ">>,
           []}],
    ?line [] = check(Config, Ts),
    ok.

otp_4871(doc) ->
    ["crashing erl_scan"];
otp_4871(suite) ->
    [];
otp_4871(Config) when is_list(Config) ->
    ?line Dir = ?config(priv_dir, Config),
    ?line File = filename:join(Dir, "otp_4871.erl"),
    ?line ok = file:write_file(File, "-module(otp_4871)."),
    %% Testing crash in erl_scan. Unfortunately there currently is
    %% no known way to crash erl_scan so it is emulated by killing the
    %% file io server. This assumes lots of things about how
    %% the processes are started and how monitors are set up, 
    %% so there are some sanity checks before killing.
    ?line {ok,Epp} = epp:open(File, []),
    timer:sleep(1),
    ?line {current_function,{epp,_,_}} = process_info(Epp, current_function),
    ?line {monitored_by,[Io]} = process_info(Epp, monitored_by),
    ?line {current_function,{file_io_server,_,_}} = 
	process_info(Io, current_function),
    ?line exit(Io, emulate_crash),
    timer:sleep(1),
    ?line {error,{_Line,epp,cannot_parse}} = otp_4871_parse_file(Epp),
    ?line epp:close(Epp),
    ok.

otp_4871_parse_file(Epp) ->
    case epp:parse_erl_form(Epp) of
	{ok,_} -> otp_4871_parse_file(Epp);
	Other -> Other
    end.

otp_5362(doc) ->
    ["OTP-5362. The -file attribute is recognized."];
otp_5362(suite) ->
    [];
otp_5362(Config) when is_list(Config) ->
    Dir = ?config(priv_dir, Config),

    Copts = [return, strong_validation,{i,Dir}],

    File_Incl = filename:join(Dir, "incl_5362.erl"),
    File_Incl2 = filename:join(Dir, "incl2_5362.erl"),
    File_Incl3 = filename:join(Dir, "incl3_5362.erl"),
    Incl = <<"-module(incl_5362).

              -include(\"incl2_5362.erl\").

              -include_lib(\"incl3_5362.erl\").

              hi(There) -> % line 7
                   a.
           ">>,
    Incl2 = <<"-file(\"some.file\", 100).

               foo(Bar) -> % line 102
                   foo.
            ">>,
    Incl3 = <<"glurk(Foo) -> % line 1
                  bar.
            ">>,
    ?line ok = file:write_file(File_Incl, Incl),
    ?line ok = file:write_file(File_Incl2, Incl2),
    ?line ok = file:write_file(File_Incl3, Incl3),

    ?line {ok, incl_5362, InclWarnings} = compile:file(File_Incl, Copts),
    ?line true = message_compare(
                   [{File_Incl3,[{{1,1},erl_lint,{unused_function,{glurk,1}}},
                                 {{1,7},erl_lint,{unused_var,'Foo'}}]},
                    {File_Incl,[{{7,15},erl_lint,{unused_function,{hi,1}}},
                                {{7,18},erl_lint,{unused_var,'There'}}]},
                    {"some.file",[{{102,16},erl_lint,{unused_function,{foo,1}}},
                                  {{102,20},erl_lint,{unused_var,'Bar'}}]}],
                   lists:usort(InclWarnings)),

    file:delete(File_Incl),
    file:delete(File_Incl2),
    file:delete(File_Incl3),

    %% A -file attribute referring back to the including file.
    File_Back = filename:join(Dir, "back_5362.erl"),
    File_Back_hrl = filename:join(Dir, "back_5362.hrl"),
    Back = <<"-module(back_5362).

              -compile(export_all).

              -file(?FILE, 1).
              -include(\"back_5362.hrl\").

              foo(V) -> % line 4
                  bar.
              ">>,
    Back_hrl = [<<"
                  -file(\"">>,File_Back,<<"\", 2).
                 ">>],
    
    ?line ok = file:write_file(File_Back, Back),
    ?line ok = file:write_file(File_Back_hrl, list_to_binary(Back_hrl)),

    ?line {ok, back_5362, BackWarnings} = compile:file(File_Back, Copts),
    ?line true = message_compare(
                   [{File_Back,[{{4,19},erl_lint,{unused_var,'V'}}]}],
                   BackWarnings),
    file:delete(File_Back),
    file:delete(File_Back_hrl),

    %% Set filename but keep line.
    File_Change = filename:join(Dir, "change_5362.erl"),
    Change = [<<"-module(change_5362).

                -file(?FILE, 100).

                -compile(export_all).

                -file(\"other.file\", ?LINE). % like an included file...
                foo(A) -> % line 105
                    bar.

                -file(\"">>,File_Change,<<"\", 1000).

                bar(B) -> % line 1002
                    foo.
              ">>],

    ?line ok = file:write_file(File_Change, list_to_binary(Change)),

    ?line {ok, change_5362, ChangeWarnings} = 
        compile:file(File_Change, Copts),
    ?line true = message_compare(
                   [{File_Change,[{{1002,21},erl_lint,{unused_var,'B'}}]},
                    {"other.file",[{{105,21},erl_lint,{unused_var,'A'}}]}],
                   lists:usort(ChangeWarnings)),

    file:delete(File_Change),

    %% -file attribute ending with a blank (not a newline).
    File_Blank = filename:join(Dir, "blank_5362.erl"),

    Blank = <<"-module(blank_5362).

               -compile(export_all).

               -
               file(?FILE, 18). q(Q) -> foo. % line 18

               a(A) -> % line 20
                   1.

               -file(?FILE, 42).

               b(B) -> % line 44
                   2.

               -file(?FILE, ?LINE). c(C) -> % line 47
                   3.
            ">>,
    ?line ok = file:write_file(File_Blank, Blank),
    ?line {ok, blank_5362, BlankWarnings} = compile:file(File_Blank, Copts),
    ?line true = message_compare(
             [{File_Blank,[{{18,3},erl_lint,{unused_var,'Q'}},
                           {{20,18},erl_lint,{unused_var,'A'}},
                           {{44,18},erl_lint,{unused_var,'B'}},
                           {{47,3},erl_lint,{unused_var,'C'}}]}],
              lists:usort(BlankWarnings)),
    file:delete(File_Blank),

    %% __FILE__ is set by inclusion and by -file attribute
    FILE_incl = filename:join(Dir, "file_5362.erl"),
    FILE_incl1 = filename:join(Dir, "file_incl_5362.erl"),
    FILE = <<"-module(file_5362).

              -export([ff/0, ii/0]).

              -include(\"file_incl_5362.erl\").

              -file(\"other_file\", 100).

              ff() ->
                  ?FILE.">>,
    FILE1 = <<"ii() -> ?FILE.
              ">>,
    FILE_Mod = file_5362,
    ?line ok = file:write_file(FILE_incl, FILE),
    ?line ok = file:write_file(FILE_incl1, FILE1),
    FILE_Copts = [return, {i,Dir},{outdir,Dir}],
    ?line {ok, file_5362, []} = compile:file(FILE_incl, FILE_Copts),
    AbsFile = filename:rootname(FILE_incl, ".erl"),
    ?line {module, FILE_Mod} = code:load_abs(AbsFile, FILE_Mod),
    ?line II = FILE_Mod:ii(),
    ?line "file_incl_5362.erl" = filename:basename(II),
    ?line FF = FILE_Mod:ff(),
    ?line "other_file" = filename:basename(FF),
    code:purge(file_5362),

    file:delete(FILE_incl),
    file:delete(FILE_incl1),

    ok.

pmod(Config) when is_list(Config) ->
    ?line DataDir = ?config(data_dir, Config),
    ?line Pmod = filename:join(DataDir, "pmod.erl"),
    ?line case epp:parse_file([Pmod], [], []) of
	      {ok,Forms} ->
		  %% ?line io:format("~p\n", [Forms]),
		  ?line [] = [F || {error,_}=F <- Forms],
		  ok
	  end,
    ok.

not_circular(Config) when is_list(Config) ->
    %% Used to generate a compilation error, wrongly saying that it
    %% was a circular definition.

    Ts = [{circular_1,
           <<"-define(S(S), ??S).\n"
             "t() -> \"string\" = ?S(string), ok.\n">>,
           ok}],
    ?line [] = run(Config, Ts),
    ok.

skip_header(doc) ->
    ["Skip some bytes in the beginning of the file."];
skip_header(suite) ->
    [];
skip_header(Config) when is_list(Config) ->
    ?line PrivDir = ?config(priv_dir, Config),
    ?line File = filename:join([PrivDir, "epp_test_skip_header.erl"]),
    ?line ok = file:write_file(File,
			       <<"some bytes
                                  in the beginning of the file
                                  that should be skipped
                                  -module(epp_test_skip_header).
                                  -export([main/1]).
                               
                                  main(_) -> ?MODULE.
                               
                                  ">>),
    ?line {ok, Fd} = file:open(File, [read]),
    ?line io:get_line(Fd, ''),
    ?line io:get_line(Fd, ''),
    ?line io:get_line(Fd, ''),
    ?line {ok, Epp} = epp:open(list_to_atom(File), Fd, 4, [], []),

    ?line Forms = epp:parse_file(Epp),
    ?line [] = [Reason || {error, Reason} <- Forms],
    ?line ok = epp:close(Epp),
    ?line ok = file:close(Fd),

    ok.

otp_6277(doc) ->
    ["?MODULE before module declaration."];
otp_6277(suite) ->
    [];
otp_6277(Config) when is_list(Config) ->
    Ts = [{otp_6277,
           <<"-undef(ASSERT).
              -define(ASSERT, ?MODULE).

              ?ASSERT().">>,
           [{error,{{4,16},epp,{undefined,'MODULE', none}}}]}],
    ?line [] = check(Config, Ts),
    ok.

otp_7702(doc) ->
    ["OTP-7702. Wrong line number in stringifying macro expansion."];
otp_7702(suite) ->
    [];
otp_7702(Config) when is_list(Config) ->
    Dir = ?config(priv_dir, Config),
    File = filename:join(Dir, "file_7702.erl"),
    Contents = <<"-module(file_7702).

                  -export([t/0]).

                  -define(RECEIVE(Msg,Body),
                       receive
                           Msg -> Body;
                           M ->
                exit({unexpected_message,M,on_line,?LINE,was_expecting,??Msg})
                       after 10000 ->
                            exit({timeout,on_line,?LINE,was_expecting,??Msg})
                       end).
                   t() ->
                       ?RECEIVE(foo, bar).">>,
    ?line ok = file:write_file(File, Contents),
    ?line {ok, file_7702, []} = 
        compile:file(File, [debug_info,return,{outdir,Dir}]),
    
    BeamFile = filename:join(Dir, "file_7702.beam"),
    {ok, AC} = beam_lib:chunks(BeamFile, [abstract_code]),

    {file_7702,[{abstract_code,{_,Forms}}]} = AC,
    Fun = fun(Attrs) ->
                  {line, L} = erl_parse:get_attribute(Attrs, line),
                  L
          end,
    Forms2 = [erl_lint:modify_line(Form, Fun) || Form <- Forms],
    ?line 
        [{attribute,1,file,_},
         _,
         _,
         {function,_,t,0,
          [{clause,_,[],[],
            [{'receive',14,
              [_,
               {clause,14,
                [{var,14,'M'}],
                [],
                [{_,_,_,
                  [{tuple,14,
                    [{atom,14,unexpected_message},
                     {var,14,'M'},
                     {atom,14,on_line},
                     {integer,14,14},
                     {atom,14,was_expecting},
                     {string,14,"foo"}]}]}]}],
              {integer,14,10000},
              [{call,14,
                {atom,14,exit},
                [{tuple,14,
                  [{atom,14,timeout},
                   {atom,14,on_line},
                   {integer,14,14},
                   {atom,14,was_expecting},
                   {string,14,"foo"}]}]}]}]}]},
         {eof,14}] = Forms2,

    file:delete(File),
    file:delete(BeamFile),

    ok.

otp_8130(doc) ->
    ["OTP-8130. Misc tests."];
otp_8130(suite) ->
    [];
otp_8130(Config) when is_list(Config) ->
    true = os:putenv("epp_inc1", "stdlib"),
    Ts = [{otp_8130_1,
           %% The scanner handles UNICODE in a special way. Hopefully
           %% temporarily.
           <<"-define(M(A), ??A). "
             "t() ->  "
             "   \"{ 34 , [ $1 , 2730 ] , \\\"34\\\" , X . a , 2730 }\" = "
             "        ?M({34,\"1\\x{aaa}\",\"34\",X.a,$\\x{aaa}}), ok. ">>,
          ok},

          {otp_8130_2,
           <<"-define(M(A), ??B). "
             "t() -> B = 18, 18 = ?M(34), ok. ">>,
           ok},

          {otp_8130_2a,
           <<"-define(m(A), ??B). "
             "t() -> B = 18, 18 = ?m(34), ok. ">>,
           ok},

          {otp_8130_3,
           <<"-define(M1(A, B), {A,B}).\n"
             "t0() -> 1.\n"
             "t() ->\n"
             "   {2,7} =\n"
             "      ?M1(begin 1 = fun() -> 1 end(),\n" % Bug -R13B01
             "                2 end,\n"
             "          7),\n"
             "   {2,7} =\n"
             "      ?M1(begin 1 = fun t0/0(),\n"
             "                2 end,\n"
             "          7),\n"
             "   {2,7} =\n"
             "      ?M1(begin 2 = byte_size(<<\"34\">>),\n"
             "                2 end,\n"
             "          7),\n"
             "   R2 = math:sqrt(2.0),\n"
             "   {2,7} =\n"
             "      ?M1(begin yes = if R2 > 1 -> yes end,\n"
             "                2 end,\n"
             "          7),\n"
             "   {2,7} =\n"
             "      ?M1(begin yes = case R2 > 1  of true -> yes end,\n"
             "                2 end,\n"
             "          7),\n"
             "   {2,7} =\n"
             "      ?M1(begin yes = receive 1 -> 2 after 0 -> yes end,\n"
             "                2 end,\n"
             "          7),\n"
             "   {2,7} =\n"
             "      ?M1(begin yes = try 1 of 1 -> yes after foo end,\n"
             "                2 end,\n"
             "          7),\n"
             "ok.\n">>,
           ok},

          {otp_8130_4,
           <<"-define(M3(), A).\n"
             "t() -> A = 1, ?M3(), ok.\n">>,
           ok},

          {otp_8130_5,
           <<"-include_lib(\"$epp_inc1/include/qlc.hrl\").\n"
             "t() -> [1] = qlc:e(qlc:q([X || X <- [1]])), ok.\n">>,
           ok},

          {otp_8130_6,
           <<"-include_lib(\"kernel/include/file.hrl\").\n"
             "t() -> 14 = (#file_info{size = 14})#file_info.size, ok.\n">>,
           ok},

          {otp_8130_7,
           <<"-record(b, {b}).\n"
             "-define(A, {{a,#b.b.\n"
             "t() -> {{a,2}} = ?A}}, ok.">>,
           ok},

          {otp_8130_8,
           <<"\n-define(A(B), B).\n"
             "-undef(A).\n"
             "-define(A, ok).\n"
             "t() -> ?A.\n">>,
           ok},
          {otp_8130_9,
           <<"-define(a, 1).\n"
             "-define(b, {?a,?a}).\n"
             "t() -> ?b.\n">>,
           {1,1}}

         ],
    ?line [] = run(Config, Ts),
          
    Cs = [{otp_8130_c1,
           <<"-define(M1(A), if\n"
             "A =:= 1 -> B;\n"
             "true -> 2\n"
             "end).\n"
            "t() -> {?M1(1), ?M1(2)}. \n">>,
           {errors,[{{5,13},erl_lint,{unbound_var,'B'}},
                    {{5,21},erl_lint,{unbound_var,'B'}}],
            []}},

          {otp_8130_c2,
           <<"-define(M(A), A).\n"
             "t() -> ?M(1\n">>,
           {errors,[{{2,9},epp,{arg_error,'M'}}],[]}},

          {otp_8130_c3,
           <<"-define(M(A), A).\n"
             "t() -> ?M.\n">>,
           {errors,[{{2,9},epp,{mismatch,'M'}}],[]}},

          {otp_8130_c4,
           <<"-define(M(A), A).\n"
             "t() -> ?M(1, 2).\n">>,
           {errors,[{{2,9},epp,{mismatch,'M'}}],[]}},

          {otp_8130_c5,
           <<"-define(M(A), A).\n"
             "t() -> ?M().\n">>,
           {errors,[{{2,9},epp,{mismatch,'M'}}],[]}},

          {otp_8130_c6,
           <<"-define(M3(), A).\n"
             "t() -> A = 1, ?3.14159}.\n">>,
           {errors,[{{2,16},epp,{call,"?3.14159"}}],[]}},

          {otp_8130_c7,
           <<"\nt() -> ?A.\n">>,
           {errors,[{{2,9},epp,{undefined,'A', none}}],[]}},

          {otp_8130_c8,
           <<"\n-include_lib(\"$apa/foo.hrl\").\n">>,
           {errors,[{{2,2},epp,{include,lib,"$apa/foo.hrl"}}],[]}},

          
          {otp_8130_c9,
           <<"-define(S, ?S).\n"
             "t() -> ?S.\n">>,
           {errors,[{{2,9},epp,{circular,'S', none}}],[]}},

          {otp_8130_c10,
           <<"\n-file.">>,
           {errors,[{{2,2},epp,{bad,file}}],[]}},

          {otp_8130_c11,
           <<"\n-include_lib 92.">>,
           {errors,[{{2,2},epp,{bad,include_lib}}],[]}},

          {otp_8130_c12,
           <<"\n-include_lib(\"kernel/include/fopp.hrl\").\n">>,
           {errors,[{{2,2},epp,{include,lib,"kernel/include/fopp.hrl"}}],[]}},

          {otp_8130_c13,
           <<"\n-include(foo).\n">>,
           {errors,[{{2,2},epp,{bad,include}}],[]}},

          {otp_8130_c14,
           <<"\n-undef({foo}).\n">>,
           {errors,[{{2,2},epp,{bad,undef}}],[]}},

          {otp_8130_c15,
           <<"\n-define(a, 1).\n"
            "-define(a, 1).\n">>,
           {errors,[{{3,9},epp,{redefine,a}}],[]}},

          {otp_8130_c16,
           <<"\n-define(A, 1).\n"
            "-define(A, 1).\n">>,
           {errors,[{{3,9},epp,{redefine,'A'}}],[]}},

          {otp_8130_c17,
           <<"\n-define(A(B), B).\n"
            "-define(A, 1).\n">>,
           []},

          {otp_8130_c18,
           <<"\n-define(A, 1).\n"
            "-define(A(B), B).\n">>,
           []},

          {otp_8130_c19,
           <<"\n-define(a(B), B).\n"
            "-define(a, 1).\n">>,
           []},

          {otp_8130_c20,
           <<"\n-define(a, 1).\n"
            "-define(a(B), B).\n">>,
           []},

          {otp_8130_c21,
           <<"\n-define(A(B, B), B).\n">>,
           {errors,[{{2,2},epp,{bad,define}}],[]}},

          {otp_8130_c22,
           <<"\n-define(a(B, B), B).\n">>,
           {errors,[{{2,2},epp,{bad,define}}],[]}},

          {otp_8130_c23,
           <<"\n-file(?b, 3).\n">>,
           {errors,[{{2,8},epp,{undefined,b, none}}],[]}},

          {otp_8130_c24,
           <<"\n-include(\"no such file.erl\").\n">>,
           {errors,[{{2,2},epp,{include,file,"no such file.erl"}}],[]}}

          ],
    ?line [] = compile(Config, Cs),

    Cks = [{otp_check_1,
            <<"\n-include_lib(\"epp_test.erl\").\n">>,
            [{error,{{2,2},epp,{depth,"include_lib"}}}]},

           {otp_check_2,
            <<"\n-include(\"epp_test.erl\").\n">>,
            [{error,{{2,2},epp,{depth,"include"}}}]}
           ],
    ?line [] = check(Config, Cks),

    ?line Dir = ?config(priv_dir, Config),
    ?line File = filename:join(Dir, "otp_8130.erl"),
    ?line ok = file:write_file(File, 
                               "-module(otp_8130).\n"
                               "-define(a, 3.14).\n"
                               "t() -> ?a.\n"),
    ?line {ok,Epp} = epp:open(File, []),
    ?line ['BASE_MODULE','BASE_MODULE_STRING','BEAM','FILE','LINE',
           'MACHINE','MODULE','MODULE_STRING'] = macs(Epp),
    ?line {ok,[{'-',_},{atom,_,file}|_]} = epp:scan_erl_form(Epp),
    ?line {ok,[{'-',_},{atom,_,module}|_]} = epp:scan_erl_form(Epp),
    ?line {ok,[{atom,_,t}|_]} = epp:scan_erl_form(Epp),
    ?line {eof,_} = epp:scan_erl_form(Epp),
    ?line ['BASE_MODULE','BASE_MODULE_STRING','BEAM','FILE','LINE',
           'MACHINE','MODULE','MODULE_STRING',a] = macs(Epp),
    ?line epp:close(Epp),    

    %% escript
    ModuleStr = "any_name",
    Module = list_to_atom(ModuleStr),
    fun() ->
            PreDefMacros = [{'MODULE', Module, redefine},
                            {'MODULE_STRING', ModuleStr, redefine},
                            a, {b,2}],
            ?line {ok,Epp2} = epp:open(File, [], PreDefMacros),
            ?line [{atom,_,true}] = macro(Epp2, a),
            ?line [{integer,_,2}] = macro(Epp2, b),
            ?line false = macro(Epp2, c),
            ?line epp:close(Epp2)
    end(),
    fun() ->
            PreDefMacros = [{a,b,c}],
            ?line {error,{bad,{a,b,c}}} = epp:open(File, [], PreDefMacros)
    end(),
    fun() ->
            PreDefMacros = [a, {a,1}],
            ?line {error,{redefine,a}} = epp:open(File, [], PreDefMacros)
    end(),
    fun() ->
            PreDefMacros = [{a,1},a],
            ?line {error,{redefine,a}} = epp:open(File, [], PreDefMacros)
    end(),
            
    ?line {error,enoent} = epp:open("no such file", []),
    ?line {error,enoent} = epp:parse_file("no such file", [], []),

    _ = ifdef(Config),

    ok.

macs(Epp) ->
    Macros = epp:macro_defs(Epp), % not documented
    lists:sort([MName || {{atom,MName},_} <- Macros]).

macro(Epp, N) ->
    case lists:keyfind({atom,N}, 1, epp:macro_defs(Epp)) of
        false -> false;
        {{atom,N},{_,V}} -> V;
        {{atom,N},Defs} -> lists:append([V || {_,{_,V}} <- Defs])
    end.

ifdef(Config) ->
    Cs = [{ifdef_c1,
           <<"-ifdef(a).\n"
             "a bug.\n"
             "-else.\n"
             "-ifdef(A).\n"
             "a bug.\n"
             "-endif.\n"
             "-else.\n"
             "t() -> ok.\n"
             "-endif.">>,
           {errors,[{{7,2},epp,{illegal,"repeated",'else'}}],[]}},

          {ifdef_c2,
           <<"-define(a, true).\n"
             "-ifdef(a).\n"
             "a bug.\n"
             "-endif.">>,
           {errors,[{{3,3},erl_parse,["syntax error before: ","bug"]}],[]}},

          {ifdef_c3,
           <<"-define(a, true).\n"
             "-ifdef(a).\n"
             "-endif">>,

           {errors,[{{3,2},epp,{bad,endif}},
                    {{3,7},epp,{illegal,"unterminated",ifdef}}],
          []}},

          {ifdef_c4,
           <<"\n-ifdef a.\n"
             "-endif.\n">>,
           {errors,[{{2,2},epp,{bad,ifdef}}],[]}},

          {ifdef_c5,
           <<"-ifdef(a).\n"
             "-else.\n"
             "-endif.\n"
             "-endif.\n">>,
           {errors,[{{4,2},epp,{illegal,"unbalanced",endif}}],[]}},

          {ifdef_c6,
           <<"-ifdef(a).\n"
             "-else.\n"
             "-endif.\n"
             "-else.\n">>,
           {errors,[{{4,2},epp,{illegal,"unbalanced",'else'}}],[]}},

          {ifdef_c7,
           <<"-ifndef(a).\n"
             "-else\n"
             "foo bar\n"
             "-else.\n"
             "t() -> a.\n"
             "-endif.\n">>,
           {errors,[{{2,2},epp,{bad,else}}],[]}},

          {ifdef_c8,
           <<"-ifdef(a).\n"
              "-foo bar.">>,
           {errors,[{{2,10},epp,{illegal,"unterminated",ifdef}}],[]}},

          {ifdef_c9,
           <<"-ifdef(a).\n"
              "3.3e12000.\n"
              "-endif.\n">>,
           []},

          {ifdef_c10,
           <<"\nt() -> 3.3e12000.\n">>,
           {errors,[{{2,8},erl_scan,{illegal,float}},
                    {{2,17},erl_parse,["syntax error before: ","'.'"]}], % ...
            []}},

          {ifndef_c1,
           <<"-ifndef(a).\n"
             "-ifndef(A).\n"
             "t() -> ok.\n"
             "-endif.\n"
             "-else.\n"
             "a bug.\n"
             "-else.\n"
             "a bug.\n"
             "-endif.">>,
           {errors,[{{7,2},epp,{illegal,"repeated",'else'}}],[]}},

          {ifndef_c3,
           <<"-ifndef(a).\n"
             "-endif">>,

           {errors,[{{2,2},epp,{bad,endif}},
                    {{2,7},epp,{illegal,"unterminated",ifndef}}],
          []}},

          {ifndef_c4,
           <<"\n-ifndef a.\n"
             "-endif.\n">>,
           {errors,[{{2,2},epp,{bad,ifndef}}],[]}},

          {define_c5,
           <<"-\ndefine a.\n">>,
           {errors,[{{2,1},epp,{bad,define}}],[]}},

          {define_c6,
           <<"\n-if.\n"
             "-endif.\n">>,
           {errors,[{{2,2},epp,{'NYI','if'}}],[]}},
          
          {define_c7,
           <<"-ifndef(a).\n"
             "-elif.\n"
             "-endif.\n">>,
           {errors,[{{2,2},epp,{'NYI',elif}}],[]}},

          {define_c7,
           <<"-ifndef(a).\n"
             "-if.\n"
             "-elif.\n"
             "-endif.\n"
             "-endif.\n"
             "t() -> a.\n">>,
           {errors,[{{2,2},epp,{'NYI','if'}}],[]}}
          ],
    ?line [] = compile(Config, Cs),

    Ts =  [{ifdef_1,
            <<"-ifdef(a).\n"
              "a bug.\n"
              "-else.\n"
              "-ifdef(A).\n"
              "a bug.\n"
              "-endif.\n"
              "t() -> ok.\n"
              "-endif.">>,
           ok},

           {ifdef_2,
            <<"-define(a, true).\n"
              "-ifdef(a).\n"
              "-define(A, true).\n"
              "-ifdef(A).\n"
              "t() -> ok.\n"
              "-else.\n"
              "a bug.\n"
              "-endif.\n"
              "-else.\n"
              "a bug.\n"
              "-endif.">>,
           ok},

           {ifdef_3,
            <<"\n-define(a, true).\n"
              "-ifndef(a).\n"
              "a bug.\n"
              "-else.\n"
              "-define(A, true).\n"
              "-ifndef(A).\n"
              "a bug.\n"
              "-else.\n"
              "t() -> ok.\n"
              "-endif.\n"
              "-endif.">>,
           ok},

           {ifdef_4,
                       <<"-ifdef(a).\n"
              "a bug.\n"
              "-ifdef(a).\n"
               "a bug.\n"
              "-else.\n"
              "-endif.\n"
             "-ifdef(A).\n"
              "a bug.\n"
             "-endif.\n"
             "-else.\n"
             "t() -> ok.\n"
             "-endif.">>,
            ok},

           {ifdef_5,
           <<"-ifdef(a).\n"
              "-ifndef(A).\n"
              "a bug.\n"
              "-else.\n"
              "-endif.\n"
             "a bug.\n"
             "-else.\n"
              "t() -> ok.\n"
             "-endif.">>,
            ok},

           {ifdef_6,
           <<"-ifdef(a).\n"
              "-if(A).\n"
              "a bug.\n"
              "-else.\n"
              "-endif.\n"
             "a bug.\n"
             "-else.\n"
              "t() -> ok.\n"
             "-endif.">>,
            ok}

           ],
    ?line [] = run(Config, Ts).



overload_mac(doc) ->
    ["Advanced test on overloading macros."];
overload_mac(suite) ->
    [];
overload_mac(Config) when is_list(Config) ->
    Cs = [
          %% '-undef' removes all definitions of a macro
          {overload_mac_c1,
           <<"-define(A, a).\n"
            "-define(A(X), X).\n"
            "-undef(A).\n"
            "t1() -> ?A.\n",
            "t2() -> ?A(1).">>,
           {errors,[{{4,9},epp,{undefined,'A', none}},
                    {{5,9},epp,{undefined,'A', 1}}],[]}},

          %% cannot overload predefined macros
          {overload_mac_c2,
           <<"-define(MODULE(X), X).">>,
           {errors,[{{1,9},epp,{redefine_predef,'MODULE'}}],[]}},

          %% cannot overload macros with same arity
          {overload_mac_c3,
           <<"-define(A(X), X).\n"
            "-define(A(Y), Y).">>,
           {errors,[{{2,9},epp,{redefine,'A'}}],[]}},

          {overload_mac_c4,
           <<"-define(A, a).\n"
            "-define(A(X,Y), {X,Y}).\n"
            "a(X) -> X.\n"
            "t() -> ?A(1).">>,
           {errors,[{{4,9},epp,{mismatch,'A'}}],[]}}
         ],
    ?line [] = compile(Config, Cs),

    Ts = [
          {overload_mac_r1,
           <<"-define(A, 1).\n"
            "-define(A(X), X).\n"
            "-define(A(X, Y), {X, Y}).\n"
            "t() -> {?A, ?A(2), ?A(3, 4)}.">>,
           {1, 2, {3, 4}}},

          {overload_mac_r2,
           <<"-define(A, 1).\n"
            "-define(A(X), X).\n"
            "t() -> ?A(?A).">>,
           1},

          {overload_mac_r3,
           <<"-define(A, ?B).\n"
            "-define(B, a).\n"
            "-define(B(X), {b,X}).\n"
            "a(X) -> X.\n"
            "t() -> ?A(1).">>,
           1}
          ],
    ?line [] = run(Config, Ts).


otp_8388(doc) ->
    ["OTP-8388. More tests on overloaded macros."];
otp_8388(suite) ->
    [];
otp_8388(Config) when is_list(Config) ->
    Dir = ?config(priv_dir, Config),
    ?line File = filename:join(Dir, "otp_8388.erl"),
    ?line ok = file:write_file(File, <<"-module(otp_8388)."
                                       "-define(LINE, a).">>),
    fun() ->
            PreDefMacros = [{'LINE', a}],
            ?line {error,{redefine_predef,'LINE'}} =
                epp:open(File, [], PreDefMacros)
    end(),

    fun() ->
            PreDefMacros = ['LINE'],
            ?line {error,{redefine_predef,'LINE'}} =
                epp:open(File, [], PreDefMacros)
    end(),

    Ts = [
          {macro_1,
           <<"-define(m(A), A).\n"
             "t() -> ?m(,).\n">>,
           {errors,[{{2,11},epp,{arg_error,m}}],[]}},
          {macro_2,
           <<"-define(m(A), A).\n"
             "t() -> ?m(a,).\n">>,
           {errors,[{{2,12},epp,{arg_error,m}}],[]}},
          {macro_3,
           <<"-define(LINE, a).\n">>,
           {errors,[{{1,9},epp,{redefine_predef,'LINE'}}],[]}},
          {macro_4,
           <<"-define(A(B, C, D), {B,C,D}).\n"
             "t() -> ?A(a,,3).\n">>,
           {errors,[{{2,8},epp,{mismatch,'A'}}],[]}},
          {macro_5,
           <<"-define(Q, {?F0(), ?F1(,,4)}).\n">>,
           {errors,[{{1,24},epp,{arg_error,'F1'}}],[]}}
         ],
    ?line [] = compile(Config, Ts),
    ok.

check(Config, Tests) ->
    eval_tests(Config, fun check_test/2, Tests).

compile(Config, Tests) ->
    eval_tests(Config, fun compile_test/2, Tests).

run(Config, Tests) ->
    eval_tests(Config, fun run_test/2, Tests).

eval_tests(Config, Fun, Tests) ->
    F = fun({N,P,E}, BadL) ->
                %% io:format("Testing ~p~n", [P]),
                Return = Fun(Config, P),
                case message_compare(E, Return) of
                    true ->
                        BadL;
                    false -> 
                        ?t:format("~nTest ~p failed. Expected~n  ~p~n"
                                  "but got~n  ~p~n", [N, E, Return]),
			fail()
                end
        end,
    lists:foldl(F, [], Tests).


check_test(Config, Test) ->
    Filename = 'epp_test.erl',
    ?line PrivDir = ?config(priv_dir, Config),
    ?line File = filename:join(PrivDir, Filename),
    ?line ok = file:write_file(File, Test),
    ?line case epp:parse_file(File, [PrivDir], []) of
              {ok,Forms} -> 
                  [E || E={error,_} <- Forms];
              {error,Error} -> 
                  Error
          end.

compile_test(Config, Test0) ->
    Test = [<<"-module(epp_test). -compile(export_all). ">>, Test0],
    Filename = 'epp_test.erl',
    ?line PrivDir = ?config(priv_dir, Config),
    ?line File = filename:join(PrivDir, Filename),
    ?line ok = file:write_file(File, Test),
    Opts = [export_all,return,nowarn_unused_record,{outdir,PrivDir}],
    case compile_file(File, Opts) of
        {ok, Ws} -> warnings(File, Ws);
        Else -> Else
    end.
            
warnings(File, Ws) ->
    case lists:append([W || {F, W} <- Ws, F =:= File]) of
        [] -> [];
        L -> {warnings, L}
    end.

compile_file(File, Opts) ->
    case compile:file(File, Opts) of
        {ok, _M, Ws} -> {ok, Ws};
        {error, FEs, []} -> {errors, errs(FEs, File), []};
        {error, FEs, [{File,Ws}]} -> {error, errs(FEs, File), Ws}
    end.

errs([{File,Es}|L], File) ->
    Es ++ errs(L, File);
errs([_|L], File) ->
    errs(L, File);
errs([], _File) ->
    [].

run_test(Config, Test0) ->
    Test = [<<"-module(epp_test). -compile(export_all). ">>, Test0],
    Filename = "epp_test.erl",
    ?line PrivDir = ?config(priv_dir, Config),
    ?line File = filename:join(PrivDir, Filename),
    ?line ok = file:write_file(File, Test),
    Opts = [return, {i,PrivDir},{outdir,PrivDir}],
    ?line {ok, epp_test, []} = compile:file(File, Opts),
    AbsFile = filename:rootname(File, ".erl"),
    ?line {module, epp_test} = code:load_abs(AbsFile, epp_test),
    ?line Reply = epp_test:t(),
    code:purge(epp_test),
    Reply.

fail() ->
    io:format("failed~n"),
    test_server:fail().

message_compare(T, T) ->
    true;
message_compare(T1, T2) ->
    ln(T1) =:= T2.

%% Replaces locations like {Line,Column} with Line. 
ln({warnings,L}) ->
    {warnings,ln0(L)};
ln({errors,EL,WL}) ->
    {errors,ln0(EL),ln0(WL)};
ln(L) ->
    ln0(L).

ln0(L) ->
    lists:keysort(1, ln1(L)).

ln1([]) ->
    [];
ln1([{File,Ms}|MsL]) when is_list(File) ->
    [{File,ln0(Ms)}|ln1(MsL)];
ln1([M|Ms]) ->
    [ln2(M)|ln1(Ms)].

ln2({{L,_C},Mod,Mess}) ->
    {L,Mod,Mess};
ln2({error,M}) ->
    {error,ln2(M)};
ln2(M) ->
    M.
