defmodule HTM.Column do
  use GenServer
  alias HTM.BitMan

  @strengthen_amount 0.1
  @weaken_amount 0.1
  @column_depth 10

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

  def handle_cast(:strengthen_connections, state) do
    new_strengths = strengthen_distals(state)

    newstate = %{ state | distal_strengths: new_strengths }
    {:noreply, newstate}
  end

  @doc """
  Accepts message: {:strengthen_connections, newstate.prevwinners}
  """
  # Message coming as --->   {:strengthen_connections, newstate.prevwinners}
  def handle_cast({:strengthen_connections, winners}, state) do
    new_strengths = strengthen_distals(state)
    
    # Find a winning cell in the column for this pattern
    winning_cell = find_and_strengthen_winner(state, winners)

    # Tell the pool who won in this column (used as "winners" for the next round)
    report_winner_cell(state, winning_cell)

    # signal proximal connections
    call_to_proximals({state, winning_cell})

    newstate = %{ state | distal_strengths: new_strengths }
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

  def handle_cast({:call_me, msg}, state) do
    new_state = add_callees(state, msg)
    {:noreply, new_state}
  end

  def handle_cast({:vote, cell}, state) do
    new_state = vote_for_cell(state, cell)
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
    Enum.zip(state.connected_this_turn, state.distal_strengths)
    |> Enum.reduce([], fn x, acc -> [ strengthen?(x) | acc] end)
  end

  defp report_winner_cell(state, winning_cell) do
    GenServer.call(HTM.PoolManager, {:i_won, {state.id, winning_cell}})
    {state, winning_cell}
  end

  defp call_to_proximals({state, winning_cell}) do
    _ = for {column, cell} <- state.proximal_cells_connections[winning_cell], do: GenServer.cast(column, {:vote, cell})
    {state, winning_cell}
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

  defp find_and_strengthen_winner(state, winners) do
    
    # Find winner based on highest value
    { winning_cell, _ } = state.proximal_cells_activation_votes
      |> Enum.max_by(fn {key, value} -> value end)

    # Register column:cell with previously winning column:cells
    # Send :call_me to previously winning cells, with column_id and cell_id, as "{:call_me, {column, cell}}"
    _ = for {remote_winning_column, remote_winner_cell} <- winners, do: GenServer.cast( remote_winning_column, {:call_me, {state.id, winning_cell, remote_winner_cell} } )
    
    {state, winning_cell}
  end

  defp add_callees(state, {caller_column_id, caller_winning_cell, local_cell}) do
    # grab, prepend, and bind our existing list
    # Each "cell" is a list of tuples, in format of {callee_column, callee_cell}
    new_callee = [ {caller_column_id, caller_winning_cell} | state.proximal_cells_connections[local_cell] ]

    # update it inside state
    %{ state | proximal_cells_connections: Map.update(state.proximal_cells_connections, local_cell, new_callee, fn x -> x end )}
    IO.inspect new_callee
  end

end
