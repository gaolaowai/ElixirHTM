# HTM

**At second attempt at implementing HTM in Elixir, using OTP**

All application logic lives in the \lib directory.

## Setup
1. Clone locally, then navigate into ELIXIRHTM directory.
2. Assuming that Elixir >=1.4 is installed on your system, type:
```elixir
iex -S mix
```

## Starting a pool
1. Hit the local http server at port 4000
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

## TODO:
1. Better format responses from http server. Right now, it's concatenating. Could format output as JSON, make it nicer and API friendly.
2. TM part of HTM. Just need to add bursting handler for handle_cast for columns to choose other columns connections at random.
3. Write some basic tests. That would be nice.
4. Create some nicer abstractions, such as ability to spawn multiple pools, better WebUI, etc.

