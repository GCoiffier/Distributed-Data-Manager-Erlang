NAME = NONE
COOKIE = "toto"
PHONY : all

client :
	erl -name $NAME -setcookie $COOKIE

all : client

clean :
	rm -f *.beam
	rm -f src/*.beam
