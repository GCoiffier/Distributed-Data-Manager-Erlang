NAME = NONE
COOKIE = "toto"
PHONY : all

client :
	erl -name $NAME -setcookie $COOKIE

all : client
