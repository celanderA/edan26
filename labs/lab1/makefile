preflow:
	erlc preflow.erl
	erl -noshell -s preflow preflow -s init stop < i 
	sh check-solution.sh ./run.sh

clean:
	rm -f *.beam *.dump
