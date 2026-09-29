main:
	gcc -std=gnu18 -o preflow preflow.c pthread_barrier.c -g -O3 -pthread
	time sh check-solution.sh ./preflow
	@echo PASS all tests

lab0:
	gcc -std=gnu18 -o preflow seq.c pthread_barrier.c -g -O3 -pthread
	time sh check-solution.sh ./preflow
	@echo PASS all tests
tsan:
	gcc -o preflow_tsan preflow.c pthread_barrier.c -g -O1 -fsanitize=thread -fno-omit-frame-pointer -pthread
	time sh check-solution.sh ./preflow_tsan
	make clean
clean:
	rm -f preflow preflow_tsan


