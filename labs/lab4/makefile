main:
	gcc -o preflow preflow.c pthread_barrier.c -g -O3 -pthread
	time sh check-solution.sh ./preflow
	@echo PASS all tests

lab0:
	gcc -o seq seq.c -g -O3 -pthread
	time sh check-solution.sh ./seq
	@echo PASS all tests

lab0Atomic:
	gcc -o atomic_lab0 atomic_seq.c pthread_barrier.c -g -O3 -pthread
	time sh check-solution.sh ./atomic_lab0
	@echo PASS all tests

