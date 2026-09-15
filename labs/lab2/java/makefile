java:
	# make this complete first and when it works
	# parallelize it and modify the makefile!
	javac sequential.java
	time sh check-solution.sh java Preflow
	@echo PASS all tests
javaParalell:
	# make this complete first and when it works
	# parallelize it and modify the makefile!
	javac parallel.java
	time sh check-solution.sh java Preflow
	@echo PASS all tests

one: 
	javac sequential.java
	java Preflow < i

oneP:
	javac parallel.java
	java Preflow < i