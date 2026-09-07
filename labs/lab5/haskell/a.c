#include <math.h>
#include <stdio.h>
#include <stdlib.h>

size_t is_prime(size_t n)
{
	size_t	i;
	size_t	u;

	if (n <= 1)
		return 0;
	else if (n == 2)
		return 1;

	u = lround(sqrt(n));

	for (i = 2; i <= u; i += 1)
		if (n % i == 0)
			return 0;
	return 1; 
}

size_t sum(size_t n)
{
	size_t	s;
	size_t	i;

	s = 0;
	for (i = 1; i <= n; i += 1)
		if (is_prime(i))
			s += i;

	return s;
}

int main(int argc, char** argv)
{
	size_t		n;

	scanf("%zu", &n);

	printf("sum of primes = %zu\n", sum(n));
}
