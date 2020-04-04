defmodule HTM.Column do
  use GenServer
  alias HTM.BitMan

  @strengthen_amount 0.1
  @weaken_amount 0.1

  # Define our state struct for our column
  defmodule State do
    defstruct id: nil,
    connectionscore: 0,
    sdr_size: 0,
    name: 0,
    resting: false,
    distal_connections: [],
    sdr_this_turn: [],
    connected_this_turn: [],
    distal_strengths: [] # holds index of valid connections, to update strengths
    # distals: [], # will hold tuples of column and cell
    # distal_strength: %{}, # using tuple as key, update strengths
    # predictive: false,
    # which_predictive: 0
  end

  # Client Interface

  def start(id, default_distals) when is_integer(id) do

    # Create atom as tag for this column in process registry.
    cname = "column"<> Integer.to_string(id)
      |> String.to_atom

    # IO.puts "Starting column #{id} as #{cname}..."
    GenServer.start(__MODULE__, %State{id: cname, distal_connections: default_distals}, name: cname)

    # Return atom
    cname
  end

  def send_sdr(name, sdr) when is_list(sdr) do
    GenServer.call name, {:check_sdr, sdr}
  end

  # Server Callbacks

  @spec init(atom | %{distal_connections: any}) :: {:ok, atom | %{distal_connections: any}}
  def init(state) do
    # Shuffle our default connection template
    randomized_distals = Enum.shuffle(state.distal_connections)
    IO.inspect randomized_distals

    # Initial strengths
    initial_strengths =
      randomized_distals
      |>Enum.reduce([], fn x, acc -> [ bit_to_int(x) | acc] end)
    IO.inspect initial_strengths

    new_state = %{ state | distal_connections: randomized_distals, distal_strengths: initial_strengths}

    # Process.link(HTM.PoolManager)

    {:ok, new_state}
  end

  def handle_cast(:strengthen_connections, state) do
    # IO.puts "hit cast strengthen..."
    # IO.puts "Before strengthening:  #{inspect state.distal_strengths}"
    new_strengths = strengthen_distals(state)

    newstate = %{ state | distal_strengths: new_strengths }
    # IO.puts "After strengthening:  #{inspect newstate}"
    {:noreply, newstate}
  end

  def handle_cast({:strengthen_connections, winners}, state) do
    # IO.puts "hit cast strengthen..."
    # IO.puts "Before strengthening:  #{inspect state.distal_strengths}"
    new_strengths = strengthen_distals(state)

    newstate = %{ state | distal_strengths: new_strengths }
    # IO.puts "After strengthening:  #{inspect newstate}"
    {:noreply, newstate}
  end

  def handle_cast(:weaken_connections, state) do
    new_strengths = Enum.zip(state.connected_this_turn, state.distal_strengths)
      |>Enum.reduce([], fn x, acc -> [ weaken?(x) | acc] end)

    newstate = %{ state | distal_strengths: new_strengths }
    {:noreply, newstate}
  end

  def handle_cast({:check_sdr, sdr}, state) do
    # IO.puts "hit cast checksdr..."
    sdrsize = sdr |> Enum.count
    connected_this_turn = BitMan.bitstring_maskand(state.distal_connections, sdr)

    connection_count = Enum.sum(connected_this_turn)
    # IO.puts "#{state.id}: #{inspect connection_count} this turn."

    new_state = %State{ state | connected_this_turn: connected_this_turn,
                            connectionscore: connection_count,
                            sdr_this_turn: sdr,
                            sdr_size: sdrsize
                      }

    GenServer.call(HTM.PoolManager, {:incr_counter, {new_state.id, new_state.connectionscore, new_state.resting}})

    {:noreply, new_state}
  end

  #
  # Catch-alls
  #
  def handle_call(_, _from, state) do
    IO.puts "generic call hit..."
    {:reply, :generic_response, state}
  end

  def handle_cast(_, state) do
    IO.puts "generic cast hit..."
    {:noreply, state}
  end

  def handle_info(message, state) do
    IO.puts "Can't touch this! #{inspect message}"
    {:noreply, state}
  end

  defp bit_to_int(x) do
    if(x == <<1::1>>) do
      :rand.uniform_real
    else
      0.0
    end
  end

  defp strengthen?({connected, strength}) do
    if(connected == 1) do
      strength + @strengthen_amount
    else
      strength
    end
  end

  defp weaken?({connected, strength}) do
    if(connected == 1) do
      strength - @weaken_amount
    else
      strength
    end
  end

  defp strengthen_distals(state) do
    Enum.zip(state.connected_this_turn, state.distal_strengths)
    |> Enum.reduce([], fn x, acc -> [ strengthen?(x) | acc] end)
  end      

end
