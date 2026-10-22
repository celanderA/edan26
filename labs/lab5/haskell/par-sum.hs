{- HLINT ignore "Use camelCase" -}
import Control.DeepSeq
import Control.Parallel
import Data.Time
import Text.Printf (printf)

int_isqrt = floor . sqrt . fromIntegral

check_is_prime :: (Int, Int) -> Bool
check_is_prime (a, n)
  | a == 1 + int_isqrt n = True
  | n `mod` a == 0 = False
  | otherwise = check_is_prime (a + 1, n)

is_prime :: Int -> Bool
is_prime n =
  (n == 2) || check_is_prime (2, n)

seq_sum_primes :: (Int, Int) -> Int
seq_sum_primes (a, b)
  | a > b = 0
  | is_prime b = b + seq_sum_primes (a, b - 1)
  | otherwise = seq_sum_primes (a, b - 1)

par_sum_primes :: (Int, Int) -> Int
par_sum_primes (a, b) =
  let size = b - a + 1
      q = size `div` 4

      s1 = seq_sum_primes (a, a + q - 1)
      s2 = seq_sum_primes (a + q, a + 2 * q - 1)
      s3 = seq_sum_primes (a + 2 * q, a + 3 * q - 1)
      s4 = seq_sum_primes (a + 3 * q, b)
   in s1
        `par` ( s2 `par` (s3 `par` (s4 `pseq` (s1 + s2 + s3 + s4)))
              )

main :: IO ()
main = do
  line <- getLine

  begin <- getCurrentTime

  let [n] = map read (words line) :: [Int]
      s = par_sum_primes (2, n)

  s `deepseq` do
    end <- getCurrentTime

    printf "par haskell sum of primes in 2..%d = %d \n" n s
    printf "time: "
    print $ diffUTCTime end begin
