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

sum_prime:: (Int,Int)->Int
sum_prime(a, b)
	| a > b = 0
	| otherwise =
		if (is_prime(b)) then 	
			1 + sum_prime(a, b-1)
		else	
			sum_prime(a, b-1)
	
main:: IO()
main = do
	line <- getLine
	begin <- getCurrentTime

	let	[n] = map read (words line) :: [Int]
		s = sum_prime(2,n)

	s `deepseq` do
		end <- getCurrentTime

		printf "seq haskell sum of primes in 2..%d = %d \n" n s
		printf "time: "
		print $ diffUTCTime end begin
