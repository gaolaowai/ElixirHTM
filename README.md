# HTM
Based on work and research done by [Numenta](https://numenta.com/) and the [HTM Community!](https://numenta.org/). Other work/experimentation done in this area using Elixir also includes [Elixir_NE](https://github.com/d-led/elixir_ne) and others.

**This is a second attempt for me at implementing Numenta's HTM in Elixir, using OTP**

All application logic lives in the \lib directory.

## Setup
https://elixir-lang.org/getting-started/introduction.html

1. Clone locally, then navigate into ELIXIRHTM directory.
2. Assuming that Elixir >=1.4 is installed on your system, type:
```elixir
iex -S mix
```

## Starting a pool
1. Hit the local http server at port 4000, letting it know our input encodings will be 100 bits long.
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
Startup for 10k columns takes about 30 seconds, and passing in encodings, letting all columns update and strengthen, currently takes around 32ms with a 7th gen i7, which launches 8 schedulers for the BEAM vm. Adding bursting later for TM likely won't add much to this, though we're currently not weakening connections either. Planning to enable that to happen with a 10% chance each turn, rather than each turn.

Looking forward to testing it on a threadripper with its 32 cores.

Currently can only startup a single pool, but I plan to allow multiple pools for simulating geographically different areas of the brain devoted to special functions.

## TODO:
1. Better format responses from http server. Current it's concatenating and clamping off output.
2. ~~TM part of HTM. Just need to add bursting handler for handle_cast for columns to choose other columns connections at random.~~ --> DONE!
3. Write some basic tests. That would be nice.
4. Create some nicer abstractions:
..* such as ability to spawn multiple pools.
..* JSON-based API calls.
..* better WebUI.
..* wxGUI for local operation.

Including native functions (where existing Erlang functions aren't speedy enough):
http://blog.techdominator.com/article/using-cpp-elixir-nifs.html

For example, to store connections as matrices instead of lists of bits. Early research is leaning me towards:
https://github.com/versilov/matrex

# Elixir resources
As I'm trying to get anyone and everyone involved to start using and breaking this, it only seems right to provide a list of resources on Elixir itself. If you have some familarity with Ruby, Elm, or even Erlang, Elixir itself isn't too difficult to parse and pick up.

## Free online resources for learning:
["Joy of Elixir"](https://joyofelixir.com/toc.html) --> Free tutorial progressively going from basic to intermediate level.

["Elixir School"](https://elixirschool.com/en/) --> Covers from basic all the way to advanced usage, including some OTP concepts.

["Getting Started"](https://elixir-lang.org/getting-started/introduction.html) pages on elixir-lang.org. Beginner to advanced.

[The "Docs"](https://elixir-lang.org/docs.html), same domain

["The Soul of Erlang and Elixir"](https://youtu.be/JvBT4XBdoUE) Talk by Saša Jurić, shows use of BEAM in live setting.


## Non-free, but *very* useful:
["Developing with Elixir/OTP"](https://online.pragmaticstudio.com/) course is worth every penny and taught very well.

["Elixir in Action"](https://www.manning.com/books/elixir-in-action), book by Saša Jurić --> Focuses on real-world applications 

 ["The Little Elixir & OTP Guidebook"](https://www.manning.com/books/the-little-elixir-and-otp-guidebook), book by Benjamin Tan Wei Hao --> provides more development path and examples with OTP.

## The BEAM VM itself
The technology that makes this possible at at all is the [BEAM virtual machine](https://blog.stenmans.org/theBeamBook/#_preface). How any why it works is a good study for any thought on distributed processing in general.
