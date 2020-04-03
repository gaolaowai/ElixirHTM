# HTM

**At second attempt at implementing HTM in Elixir, using OTP**

All application logic lives in the \lib directory.

## Setup
https://elixir-lang.org/getting-started/introduction.html

1. Clone locally, then navigate into ELIXIRHTM directory.
2. Assuming that Elixir >=1.4 is installed on your system, type:
```elixir
iex -S mix
```

## Starting a pool
1. Hit the local http server at port 4000, letting it know our input SDRs will be 100 bits long.
```
curl http://localhost:4000/pool/start/100
```

## Sending in SDR data
```bash
curl http://localhost:4000/SDR/10010100101001010010100101001010010100101001010010100101001010010100101001010010100101111100000
```

## Getting pool state
```bash
curl http://localhost:4000/pool/state/
```

## Performance
Startup for 10k columns takes about 30 seconds, and passing in SDRs, letting all columns update and strengthen, currently takes around 32ms with a 7th gen i7, which launches 8 schedulers for the BEAM vm. Adding bursting later for TM likely won't add much to this, though we're currently not weakening connections either. Planning to enable that to happen with a 10% chance each turn, rather than each turn.

Looking forward to testing it on a threadripper with its 32 cores.

Currently can only startup a single pool, but I plan to allow multiple pools for simulating geographically different areas of the brain devoted to special functions.

## TODO:
1. Better format responses from http server. Right now, it's concatenating. Could format output as JSON, make it nicer and API friendly.
2. TM part of HTM. Just need to add bursting handler for handle_cast for columns to choose other columns connections at random. Wednesday.
3. Write some basic tests. That would be nice.
4. Create some nicer abstractions, such as ability to spawn multiple pools, better WebUI, etc.

Including native functions (where existing Erlang functions aren't speedy enough):
http://blog.techdominator.com/article/using-cpp-elixir-nifs.html

For example, to store connections as matrices instead of lists of bits. Early research is leaning me towards:
https://github.com/versilov/matrex

