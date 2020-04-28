defmodule HTM.Column do
  use GenServer
  use Agent
  alias HTM.BitMan

  @strengthen_amount 0.1
  @weaken_amount 0.1
  @column_depth 10
  @max_callees 512
  @predictive_threshold 20

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
    distal_strengths: [], # holds index of valid connections, to update strengths
    proximal_cells_connections: %{}, # will hold tuples of columns and cells for TM. Cell connections will be maps of "proximal_column_id: cell_id"
    proximal_cells_activation_votes: %{}, # using tuple as key, update strengths
    predictive: false
    # which_predictive: 0
  end
  @doc """
  ############################################################
  #
  #                   Client Interface
  #
  ############################################################
"""
  def start(pool_id, id, default_distals) when is_integer(id) do

    # Create atom as tag for this column in process registry.
    cname = Integer.to_string(pool_id) <> "p" <> Integer.to_string(id)
      |> String.to_atom

    # IO.puts "Starting column #{id} as #{cname}..."
    GenServer.start(__MODULE__, %State{id: cname, distal_connections: default_distals}, name: cname)

    # Return atom
    cname
  end

  def send_sdr(name, sdr) when is_list(sdr) do
    GenServer.call name, {:check_sdr, sdr}
  end
@doc """
  ############################################################
  #
  #                   Server callbacks
  #
  ############################################################
"""
  @spec init(atom | %{distal_connections: any}) :: {:ok, atom | %{distal_connections: any}}
  def init(state) do
    # Shuffle our default connection template
    randomized_distals = Enum.shuffle(state.distal_connections)

    # Initial strengths
    initial_strengths =
      randomized_distals
      |> Enum.reduce([], fn x, acc -> [ bit_to_int(x) | acc] end)

    # Create blank proximal connections
    proximal_cells_connections = for i <- Range.new(1, @column_depth), do: %{i => []}
    proximal_cells_connections = proximal_cells_connections |> Enum.reduce(%{}, fn x, acc -> Map.merge(x, acc) end)

    # Create and randomize cell vote map
    proximal_cells_activation_votes = for i <- Range.new(1, @column_depth), do: %{i => :rand.uniform(20)}
    proximal_cells_activation_votes = proximal_cells_activation_votes
      |> Enum.reduce(%{}, fn x, acc -> Map.merge(x, acc) end)

    new_state = %State{ state | distal_connections: randomized_distals,
                           distal_strengths: initial_strengths,
                           proximal_cells_connections: proximal_cells_connections,
                           proximal_cells_activation_votes: proximal_cells_activation_votes
                 }

    # Process.link(HTM.PoolManager)

    {:ok, new_state}
  end


  @doc """
  Accepts message: {:strengthen_connections, newstate.prevwinners}
  """
  def handle_cast(:strengthen_connections, state) do

    # Find a winning cell in the column for this pattern
    { winning_cell, _ } = state.proximal_cells_activation_votes
      |> Enum.max_by(fn {_, value} -> value end)
    turn = HTM.Counter.get_turn()
    if (turn >= 23) do
      IO.puts "winner data: {#{inspect state.id}, #{inspect winning_cell}}"
    end
    # Tell the WinnerTracker who won in this column (used as "winners" for the next round)
    HTM.WinnersTracker.add_winner({state.id, winning_cell})

    # pull out previous winners
    winners = HTM.WinnersTracker.get_prev_winners()

    # Tell previous winners who we are
    _ = for {prev_win_column, prev_win_cell} <- winners,
        do: GenServer.cast( prev_win_column,
                            {:call_me, {state.id, winning_cell, prev_win_cell}}
                          )

    # signal our cell's proximal connections
    call_to_proximals({state, winning_cell})

    # update distal strengths
    new_strengths = strengthen_distals(state)

    newstate = %State{ state | distal_strengths: new_strengths, resting: true }

    {:noreply, newstate}
  end

  def handle_cast(:weaken_connections, state) do
    new_strengths = Enum.zip(state.connected_this_turn, state.distal_strengths)
      |> Enum.reduce([], fn x, acc -> [ weaken?(x) | acc] end)

    newstate = %State{ state | distal_strengths: new_strengths }
    {:noreply, newstate}
  end

  def handle_cast({:check_sdr, sdr}, state) do
    sdrsize = sdr |> Enum.count
    connected_this_turn = BitMan.bitstring_maskand(state.distal_connections, sdr)

    connection_count = Enum.sum(connected_this_turn)

    new_state = %State{ state |  connected_this_turn: connected_this_turn,
                            connectionscore: connection_count,
                            sdr_this_turn: sdr,
                            sdr_size: sdrsize
                  }

    GenServer.call(HTM.PoolManager, {:incr_counter, {new_state.id, new_state.connectionscore, new_state.resting}})

    new_state = %State{ new_state | resting: false }

    {:noreply, new_state}
  end

  def handle_cast({:call_me, msg}, state) do
    new_state = add_callees(state, msg)
    {:noreply, new_state}
  end

  def handle_cast({:vote, cell}, state) do
    new_state = vote_for_cell(state, cell)

    {:noreply, new_state}
  end


  def handle_call(:colstate, _from, state) do
    {:reply, state, state}
  end
  ######################################################
  #
  #              CATCH-ALL CALLS AND CASTS
  #
  ######################################################
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


  ############################################
  #
  #            Private Functions
  #
  ############################################

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
    # peeker(state, "state:")

    Enum.zip(state.connected_this_turn, state.distal_strengths)
    # |> peeker("strengthen_distals:")
    |> Enum.reduce([], fn x, acc -> [ strengthen?(x) | acc] end)
  end

  defp peeker(input, label) do
    IO.puts "#{inspect label} --> PEEKER: #{inspect input}"
    input
  end

  defp report_winner_cell(state, winning_cell) do
    IO.puts "\n\nreport_winner_cell --> #{state.id} --> winning cell:  #{inspect winning_cell}"
    HTM.WinnersTracker.add_winner({state.id, winning_cell})
    GenServer.call(HTM.PoolManager, {:i_won, {state.id, winning_cell}})
    {state, winning_cell}
  end

  defp call_to_proximals({state, winning_cell}) do
    # IO.puts "\n\--> #{state.id} nstate.proximal_cells_connections[winning_cell]:  #{inspect state.proximal_cells_connections[winning_cell]}"

    case state.proximal_cells_connections[winning_cell] do
      [] ->  # IO.puts "Hit nil!\n"
              {state, winning_cell}

      _ -> _ = for {column, cell} <- state.proximal_cells_connections[winning_cell], do: GenServer.cast(column, {:vote, cell})
      {state, winning_cell}
    end

  end

  defp vote_for_cell(state, cell) do
    newmap = Map.update(
      state.proximal_cells_activation_votes,
      cell,
      state.proximal_cells_activation_votes[cell],
      fn x -> x + 1 end
    )
    if ( ! state.predictive ) do
      if predictive?(newmap, cell) do
        %State{ state | proximal_cells_activation_votes: newmap, predictive: true }
      end
    else
      %{ state | proximal_cells_activation_votes: newmap }
    end
  end

  defp call_previous_winners({caller_column_id, caller_winning_cell, local_cell}) do
    {caller_column_id, caller_winning_cell, local_cell}
  end

  defp predictive?(newmap, cell) do
    if (newmap[cell] > @predictive_threshold) do
      true
    else
      false
    end
  end

  defp add_callees(state, {caller_column_id, caller_winning_cell, local_cell}) do

    # grab, prepend, and bind our existing list
    # Each "cell" is a list of tuples, in format of {callee_column, callee_cell}
    new_callee = {caller_column_id, caller_winning_cell}

    # Append to front of list, while grabbing only (up to) @max_calless worth of items. Drops off old connections.
    new_proximal_connections = Map.update(state.proximal_cells_connections, local_cell, new_callee, &[ new_callee|Enum.take( &1, @max_callees )])
    # IO.puts "\n\n\n\n\n new_callee | local_cell | new_proximal_connections: #{inspect new_callee}|#{inspect local_cell} | #{inspect new_proximal_connections}\n\n\n\n\n"

    # update it inside state
    new_state = %State{ state | proximal_cells_connections: new_proximal_connections }
    new_state
  end

end
