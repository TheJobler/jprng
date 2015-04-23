-module(jprng).
-export([nano_time/0, nano_time/1, rand/0, rand/1,
        init/1, next_int/1, next_int/2, next/2]).

%% Java multiplier value.
-define(JAVA_MULTIPLIER, 16#5DEECE66D).

%% Java addend value.
-define(JAVA_ADDEND, 16#B).

%% Java mask value. (1<<48)-1
-define(JAVA_MASK, 281474976710655).

%% Java uniquifier value.
-define(JAVA_UNIQUIFIER, 8682522807148012).

nano_time()->
  nano_time(now()).

nano_time({M,S,Ms})->
  ((M*1000000+S)*1000+Ms)*1000000.

reduce_val(B,V,N,S)->
  if
    ((B-V + (N-1)) < 0 )->
      S2 = ((S*?JAVA_MULTIPLIER + ?JAVA_ADDEND) band ?JAVA_MASK),
      B2 = (S2 bsr (48 - 31)),
      V2 = B rem N,
      reduce_val(B2,V2,N,S2);
    true ->
      {V,S}
  end.


rand()->
  rand(?JAVA_UNIQUIFIER+1+nano_time()).

rand(Seed)->
  receive
    {From, init}->
      Seed2 = (Seed bxor ?JAVA_MULTIPLIER) band ?JAVA_MASK,
      From ! {self(), Seed2},
      rand(Seed2);
    {From, next, B}->
      Seed2 = (Seed * ?JAVA_MULTIPLIER + ?JAVA_ADDEND) band ?JAVA_MASK,
      Value = (Seed2 bsr (48 - B)),
      From ! {self(), Value},
      rand(Seed2);
    {From, next_int, N}->
      if
        (N =< 0)->
          %% TODO: Send back an error message later
          %% for now just sending back the value N
          From ! {self(), negative_argument},
          rand(Seed);
        (N==(N band -N))->
          Seed2 = (Seed * ?JAVA_MULTIPLIER + ?JAVA_ADDEND) band ?JAVA_MASK,
          Value = (N*(Seed2 bsr (48 - 31)) bsr 31),
          From ! {self(), Value},
          rand(Seed2);
        true->
          Seed2  = (Seed * ?JAVA_MULTIPLIER + ?JAVA_ADDEND) band ?JAVA_MASK,
          Bits   = (Seed2 bsr (48-31)),
          TValue = (Bits rem N),
          {Value, NewSeed} = reduce_val(Bits,TValue,N,Seed2),
          From ! {self(), Value},
          rand(NewSeed)
      end
  end.


init(Pid)->
  Pid ! {self(), init},
  receive
    {_From, Seed}-> Seed
  end.

next(Pid, N)->
  Pid ! {self(), next, N},
  receive
    {_From, Value}->Value
  end.

next_int(Pid)->
  next(Pid, 32).


next_int(Pid, N)->
  Pid ! {self(), next_int, N},
  receive
    {_From, negative_argument}->N;
    {_From, Value}->Value
  end.
