TEST_HJSON=$(mktemp)

echo "{
  # TL;DR
  human:   Hjson
  machine: JSON
}" > $TEST_HJSON

$HELLO_PARSE $TEST_HJSON
