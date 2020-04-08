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
1. Better format responses from http server. Right now, it's concatenating. Could format output as JSON, make it nicer and API friendly.
2. ~~TM part of HTM. Just need to add bursting handler for handle_cast for columns to choose other columns connections at random.~~ --> DONE!
3. Write some basic tests. That would be nice.
4. Create some nicer abstractions, such as ability to spawn multiple pools, better WebUI, etc.

Including native functions (where existing Erlang functions aren't speedy enough):
http://blog.techdominator.com/article/using-cpp-elixir-nifs.html

For example, to store connections as matrices instead of lists of bits. Early research is leaning me towards:
https://github.com/versilov/matrex

# Elixir resources
As I'm trying to get anyone and everyone involved to start using and breaking this, it only seems right to provide a list of resources on Elixir itself. If you have some familarity with Ruby, Elm, or even Erlang, Elixir itself isn't too difficult to parse and pick up.

## Free online resources for learning:
"Joy of Elixir" --> Free tutorial progressively going from basic to intermediate level. https://joyofelixir.com/toc.html

"Elixir School" --> Covers from basic all the way to advanced usage, including some OTP concepts. https://elixirschool.com/en/

"Getting Started" pages on elixir-lang.org. Beginner to advanced. https://elixir-lang.org/getting-started/introduction.html

The "Docs", same domain: https://elixir-lang.org/docs.html

"The Soul of Erlang and Elixir" Talk by Saša Jurić, shows use of BEAM in live setting. https://youtu.be/JvBT4XBdoUE


## Non-free, but *very* useful:
https://online.pragmaticstudio.com/ --> "Developing with Elixir/OTP" course is worth every penny and taught very well.

"Elixir in Action", book by Saša Jurić --> Focuses on real-world applications https://www.manning.com/books/elixir-in-action

 "The Little Elixir & OTP Guidebook", book by Benjamin Tan Wei Hao --> provides more development path and examples with OTP https://www.manning.com/books/the-little-elixir-and-otp-guidebook
