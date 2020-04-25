defmodule HTM.Column do
  use GenServer
  use Agent
  alias HTM.BitMan

  @strengthen_amount 0.1
  @weaken_amount 0.1
  @column_depth 10
  @max_callees 512

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

    new_state = %{ state | distal_connections: randomized_distals,
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
  # Message coming as --->   {:strengthen_connections, newstate.prevwinners}
  def handle_cast(:strengthen_connections, state) do


    # IO.puts "#{state.id}: NOT DEAD YETS...\n\n\n\n\n"

    # pull out previous winners
    winners = HTM.WinnersTracker.get_prev_winners()
    # IO.puts "\n\n\n\n\n#{state.id} --> :strengthen_distals --> winners: #{inspect winners} "

    # Find a winning cell in the column for this pattern
    { winning_cell, _ } = state.proximal_cells_activation_votes
      |> Enum.max_by(fn {_, value} -> value end)

    # Find a winning cell in the column for this pattern
    # IO.puts "\n\n#{state.id} --> :strengthen_distals --> winning cell:  #{inspect winning_cell}"

    # Tell the WinnerTracker who won in this column (used as "winners" for the next round)
    HTM.WinnersTracker.add_winner({state.id, winning_cell})

    ##### GenServer.call(HTM.PoolManager, {:i_won, {state.id, winning_cell}})

    # Tell the pool who won in this column (used as "winners" for the next round)

    # signal our cell's proximal connections
    call_to_proximals({state, winning_cell})

    # update distal strengths
    new_strengths = strengthen_distals(state)
    # IO.puts "\n\n#{state.id} --> :strengthen_distals --> new_strength:  #{inspect new_strengths}"

    newstate = %{ state | distal_strengths: new_strengths, resting: true }
    # IO.puts "After strengthening:  #{inspect newstate}"
    {:noreply, newstate}
  end

  def handle_cast(:weaken_connections, state) do
    new_strengths = Enum.zip(state.connected_this_turn, state.distal_strengths)
      |> Enum.reduce([], fn x, acc -> [ weaken?(x) | acc] end)

    newstate = %{ state | distal_strengths: new_strengths }
    {:noreply, newstate}
  end

  def handle_cast({:check_sdr, sdr}, state) do
    # IO.puts "hit cast checksdr..."
    sdrsize = sdr |> Enum.count
    connected_this_turn = BitMan.bitstring_maskand(state.distal_connections, sdr)

    # peeker(connected_this_turn, "connected_this_turn:")

    connection_count = Enum.sum(connected_this_turn)
    if (state.resting) do
      IO.puts "#{state.id}: resting this turn."
    end
    # IO.puts "#{state.id}: #{inspect connection_count} this turn."

    new_state = %{ state |  connected_this_turn: connected_this_turn,
                            connectionscore: connection_count,
                            sdr_this_turn: sdr,
                            sdr_size: sdrsize
                  }

    GenServer.call(HTM.PoolManager, {:incr_counter, {new_state.id, new_state.connectionscore, new_state.resting}})

    new_state = %{ new_state | resting: false }

    # peeker(new_state, "column state:")

    {:noreply, new_state}
  end

  def handle_cast({:call_me, msg}, state) do
    new_state = add_callees(state, msg)
    IO.puts ":call_me --> #{inspect new_state}"
    {:noreply, new_state}
    # {:reply, state, state}
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
    # IO.puts "\n\nreport_winner_cell --> #{state.id} --> winning cell:  #{inspect winning_cell}"
    HTM.WinnersTracker.add_winner({state.id, winning_cell})
    GenServer.call(HTM.PoolManager, {:i_won, {state.id, winning_cell}})
    {state, winning_cell}
  end

  defp call_to_proximals({state, winning_cell}) do
    # IO.puts "\n\--> #{state.id} nstate.proximal_cells_connections[winning_cell]:  #{inspect state.proximal_cells_connections[winning_cell]}"

    case state.proximal_cells_connections[winning_cell] do
      nil ->  IO.puts "Hit nil!\n"
              {state, winning_cell}

      _ -> _ = for {column, cell} <- state.proximal_cells_connections[winning_cell], do: GenServer.cast(column, {:vote, cell})
      {state, winning_cell}
    end

  end

  defp vote_for_cell(state, cell) do
    %{ state | proximal_cells_activation_votes:
                            Map.update(
                              state.proximal_cells_activation_votes,
                              cell,
                              state.proximal_cells_activation_votes[cell],
                              fn x -> x + 1 end
                              )
     }
  end


  defp add_callees(state, {caller_column_id, caller_winning_cell, local_cell}) do
    # grab, prepend, and bind our existing list
    # Each "cell" is a list of tuples, in format of {callee_column, callee_cell}
    new_callee = [ {caller_column_id, caller_winning_cell} | state.proximal_cells_connections[local_cell] ]
    IO.puts" new_callee: #{inspect new_callee}"

    # update it inside state
    %{ state | proximal_cells_connections: Map.update(state.proximal_cells_connections, local_cell, new_callee, fn x -> x end )}

  end

end
