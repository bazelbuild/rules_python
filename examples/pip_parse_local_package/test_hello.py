import hello

EXAMPLE_HJSON = """
{
  # TL;DR
  human:   Hjson
  machine: JSON
}
"""

res = hello.parse(EXAMPLE_HJSON)
assert res["human"] == "Hjson"
assert res["machine"] == "JSON"
