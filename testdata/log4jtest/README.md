log4jtest
=========

copy log4j.jar into current dir
make
make test

will connect to localhost:2518 and send a logging message

To capture: nc -l 2518 > log4j.capture
