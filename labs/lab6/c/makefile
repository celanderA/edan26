CC = gcc-16

main:
	$(CC) -o preflow preflow.c pthread_barrier.c -g -O3 -pthread -fgnu-tm
	time sh check-solution.sh ./preflow
	@echo PASS all tests