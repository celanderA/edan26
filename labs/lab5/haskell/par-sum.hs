import Control.Parallel
import Control.DeepSeq
import Data.Time
import Text.Printf (printf)

int_isqrt = floor . sqrt . fromIntegral

check_is_prime::(Int,Int)->Bool
check_is_prime(a, n) =
	if a == 1+int_isqrt n then
		True
	else if n `mod` a == 0 then
		False
	else
		check_is_prime(a+1, n)
		
is_prime:: Int->Bool
is_prime(n) = 
	if n == 2 then True
	else
		check_is_prime(2, n)

seq_sum_primes:: (Int,Int)->Int
seq_sum_primes(a, b) =
	if a > b then 0
	else if (is_prime(b)) then 	
		1 + seq_sum_primes(a, b-1)
	else	
		seq_sum_primes(a, b-1)

par_sum_primes:: (Int,Int)->Int
par_sum_primes(a, b) =
	let	m = a + (b-a) `div` 2
		s1 = seq_sum_primes(a, m)
		s2 = seq_sum_primes(m+1, b)
	in
		par s1 (pseq s2 (s1 + s2))
	
main:: IO()
main = do
	line <- getLine

	begin <- getCurrentTime

	let	[n] = map read (words line) :: [Int]
		s = par_sum_primes(2,n)

	s `deepseq` do
		end <- getCurrentTime

		printf "par haskell sum of primes in 2..%d = %d \n" n s
		printf "time: "
		print $ diffUTCTime end begin
