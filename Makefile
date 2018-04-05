NAME = guigui
COOKIE = toto
PHONY : all

client :
	erl # -name $NAME -setcookie $COOKIE

all : clean client

clean :
	rm -f *.beam
	rm -f src/*.beam
	rm -f *.dump
