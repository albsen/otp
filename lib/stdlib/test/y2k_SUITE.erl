%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 1998-2009. All Rights Reserved.
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
%%
%% File:     y2k_SUITE.erl
%% Purpose:  Year 2000 tests.

-module(y2k_SUITE).

-include("test_server.hrl").

-export([all/1,
	 date_1999_01_01/1, date_1999_02_28/1, 
	 date_1999_09_09/1, date_2000_01_01/1, 
	 date_2000_02_29/1, date_2001_01_01/1, 
	 date_2001_02_29/1, date_2004_02_29/1
	]).

all(doc) ->
    "This is the test suite for year 2000. Eight dates according "
    "to Ericsson Corporate Millennium Test Specification "
    "(LME/DT-98:1097 are tested.";

all(suite) ->
    [date_1999_01_01, 
     date_1999_02_28,
     date_1999_09_09,
     date_2000_01_01,
     date_2000_02_29,
     date_2001_01_01,
     date_2001_02_29,
     date_2004_02_29
    ].

date_1999_01_01(doc) ->
    "#1 : 1999-01-01: test roll-over from 1998-12-31 to 1999-01-01.";
date_1999_01_01(suite) ->
    [];
date_1999_01_01(Config) when is_list(Config) ->
    ?line Date = {1998, 12, 31}, NextDate = {1999, 1, 1},
    ?line match(next_date(Date), NextDate),
    TZD = tzd(Date),
    if 
	TZD > 0 ->
	    ?line Time = {24 - TZD, 0, 0},
	    ?line {NDate, _NTime} = 
		erlang:localtime_to_universaltime({Date, Time}),
	    ?line match(NDate, NextDate);
	TZD < 0  ->
	    ?line Time = {24 + TZD, 0, 0},
	    ?line {NDate, _NTime} = 
		erlang:universaltime_to_localtime({Date, Time}),
	    ?line match(NDate, NextDate);
	true  ->
	    ok
    end.
    
date_1999_02_28(doc) ->
    "#2 : 1999-02-28: test roll-over from 1999-02-28 to 1999-03-01.";
date_1999_02_28(suite) ->
    [];
date_1999_02_28(Config) when is_list(Config) ->
    ?line Date = {1999, 2, 28}, NextDate = {1999, 3, 1},
    ?line match(next_date(Date), NextDate),
    ?line match(tz_next_date(Date), NextDate).

date_1999_09_09(doc) ->
    "#3 : 1999-09-09: test roll-over from 1999-09-08 to 1999-09-09.";
date_1999_09_09(suite) ->
    [];
date_1999_09_09(Config) when is_list(Config) ->
    ?line Date = {1999, 9, 8}, NextDate = {1999, 9, 9},
    ?line match(next_date(Date), NextDate),
    ?line match(tz_next_date(Date), NextDate).

date_2000_01_01(doc) ->
    "#4 : 2000-01-01: test roll-over from 1999-12-31 to 2000-01-01 to "
    "2000-01-02.";
date_2000_01_01(suite) ->
    [];
date_2000_01_01(Config) when is_list(Config) ->
    ?line Date = {1999, 12, 31}, NextDate = {2000, 1, 1},
    ?line match(next_date(Date), NextDate),
    ?line match(tz_next_date(Date), NextDate),
    ?line NextDate1 = {2000, 1, 2},
    ?line match(next_date(NextDate), NextDate1),
    ?line match(tz_next_date(NextDate), NextDate1).

date_2000_02_29(doc) ->
    "#5 : 2000-02-29: test roll-over from 2000-02-28 to 2000-02-29 to "
    "2000-03-01.";
date_2000_02_29(suite) ->
    [];
date_2000_02_29(Config) when is_list(Config) ->
    ?line Date = {2000, 2, 28}, NextDate = {2000, 2, 29},
    ?line match(next_date(Date), NextDate),
    ?line match(tz_next_date(Date), NextDate),
    ?line NextDate1 = {2000, 3, 1},
    ?line match(next_date(NextDate), NextDate1),
    ?line match(tz_next_date(NextDate), NextDate1).

date_2001_01_01(doc) ->
    "#6 : 2001-01-01: test roll-over from 2000-12-31 to 2001-01-01.";
date_2001_01_01(suite) ->
    [];
date_2001_01_01(Config) when is_list(Config) ->
    ?line Date = {2000, 12, 31}, NextDate = {2001, 1, 1},
    ?line match(next_date(Date), NextDate),
    ?line match(tz_next_date(Date), NextDate).

date_2001_02_29(doc) ->
    "#7 : 2001-02-29: test roll-over from 2001-02-28 to 2001-03-01.";
date_2001_02_29(suite) ->
    [];
date_2001_02_29(Config) when is_list(Config) ->
    ?line Date = {2001, 2, 28}, NextDate = {2001, 3, 1},
    ?line match(next_date(Date), NextDate),
    ?line match(tz_next_date(Date), NextDate).

date_2004_02_29(doc) ->
    "#8 : 2004-02-29: test roll-over from 2004-02-28 to 2004-02-29 to "
    "2004-03-01.";
date_2004_02_29(suite) ->
    [];
date_2004_02_29(Config) when is_list(Config) ->
    ?line Date = {2004, 2, 28}, NextDate = {2004, 2, 29},
    ?line match(next_date(Date), NextDate),
    ?line match(tz_next_date(Date), NextDate),
    ?line NextDate1 = {2004, 3, 1},
    ?line match(next_date(NextDate), NextDate1),
    ?line match(tz_next_date(NextDate), NextDate1).
   
%%
%% Local functions
%%
next_date(Date) ->
    calendar:gregorian_days_to_date(calendar:date_to_gregorian_days(Date) + 1).
%%
%% timezonediff
%%
tzd(Date) ->
    ?line {_LDate, {LH, _LM, _LS}} = 
	erlang:universaltime_to_localtime({Date, {12, 0, 0}}),
    12 - LH.

tz_next_date(Date) ->
    TZD = tzd(Date),
    if 
	TZD > 0 ->
	    ?line Time = {24 - TZD, 0, 0},
	    ?line {NDate, _NTime} = 
		erlang:localtime_to_universaltime({Date, Time}),
	    ?line NDate;
	TZD < 0  ->
	    ?line Time = {24 + TZD, 0, 0},
	    ?line {NDate, _NTime} = 
		erlang:universaltime_to_localtime({Date, Time}),
	    ?line NDate;
	true  ->
	    Date
    end.

%%
%% match({X, X}) ->
%%    ok.

match(X, X) ->
    ok.



