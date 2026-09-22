main:
	gcc -o preflow preflow.c -g -O3 -pthread
	time sh check-solution.sh ./preflow
	@echo PASS all tests

tsan:
	gcc -o preflow_tsan preflow.c -g -O1 -fsanitize=thread -fno-omit-frame-pointer -pthread
	time sh check-solution.sh ./preflow_tsan

clean:
	rm -f preflow preflow_tsan