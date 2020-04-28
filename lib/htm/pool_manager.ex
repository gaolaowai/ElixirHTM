defmodule HTM.PoolManager do
  use GenServer

  alias HTM.Column
  alias HTM.BitMan

  @number_of_columns 2048 # acts like a global within this module
  @connection_percent_to_sdr 0.7
  @sparsity_percentage 0.02 #between 0.00 and 1.0
  @sparsity trunc(@number_of_columns * @sparsity_percentage)

  defmodule State do
    defstruct pool_id: "pool_id",
    columns: [],
    poolstate: %{},
    prevwinners: %{},
    counter: 0,
    start_time: System.os_time(),
    stop_time: System.os_time(),
    resting: [],
    turn_complete: true
  end

  ##################################################################
  #
  #      Start Links --> starts a new genserver for our pool
  #
  ##################################################################

  def start_links(args) do

    # Eventually pass these in at new pool init
    pool_id = 1
    pool_size = @number_of_columns
    IO.puts pool_size

    # Create the initial map of distal connections to input space.
    # Each column then shuffles their own copy of this at startup.
    default_distals = Range.new(1, args.sdr_size)
      |> Enum.reduce([], fn x, acc -> if (x < args.number_of_connections) do [1|acc] else [0|acc] end end)
      |> HTM.BitMan.list_to_bitlist

    IO.inspect default_distals

    # Start a number of processes, returning their pids as a list to be stored in local state.
    columns = for i <- Range.new(1, @number_of_columns), do: Column.start(pool_id, i, default_distals)
    # columns = for i <- Range.new(1, @number_of_columns), do: Kernel.spawn_link(HTM.Column, :start, [pool_id, i, default_distals])

    state = %State{columns: columns, pool_id: pool_id}

    HTM.Counter.start_link( 0, pool_id )
    HTM.WinnersTracker.start_link(pool_id)
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  ############################################################
  #
  #                   Client Interface
  #
  ############################################################

  def send_sdr(sdr) do
    sdr = sdr |> String.to_charlist|> BitMan.list_to_bitlist
    # IO.inspect sdr
    GenServer.cast(HTM.PoolManager, {:send_sdr, sdr})
  end

  def start_pool(sdr_length) do
    sdr_length = sdr_length |> String.to_integer
    number_of_connections = (sdr_length * @connection_percent_to_sdr|> Kernel.trunc)
    args = %{sdr_size: sdr_length, number_of_connections: number_of_connections}
    GenServer.cast(HTM.KickStarter, {:start_pool, args})
  end

  def poolstate do
    GenServer.call(HTM.PoolManager, :pool_state)
    # |> to_zero_one
    |> colnum_from_tuple
  end


  def whowon do
    GenServer.call(HTM.PoolManager, :who_won)
    # |> to_zero_one
    # |> colnum_from_tuple
  end


  ############################################################
  #
  #                   Server callbacks
  #
  ############################################################
  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_cast({:send_sdr, sdr}, state) do
    if(state.turn_complete) do
      HTM.WinnersTracker.roll_winners()
      HTM.Counter.reset()
      HTM.Counter.increment_turn()
      state = %State{ state | start_time: System.os_time(), resting: [], turn_complete: false}
      send_sdr(sdr, state.columns)
      {:noreply, state}
    else
      GenServer.cast(HTM.PoolManager, {:send_sdr, sdr})
      {:noreply, state}
    end

  end

  @doc """
  Updates the local state for the connection counting.
  """
  def handle_call({:incr_counter, {l_id, score, resting}}, _from, state) do

    newstate = %State{ state | poolstate: Map.update(state.poolstate, l_id, score, fn x -> if(resting) do 0.0 else x end end ) }
    newstate = %State{ newstate | resting: [ {l_id, resting} | state.resting] }

    HTM.Counter.increment(score)
    counter_state = HTM.Counter.value()
    average = counter_state.current_avg

    newstate = check_count(newstate, average, counter_state)

    {:reply, :ok, newstate}
  end

  def handle_call({:i_won, {l_id, cell}}, _from, state) do
    peeker(state.prevwinners)
    newstate = %State{ state | prevwinners: Map.update(state.prevwinners, l_id, cell, fn x -> x end) }

    {:reply, :ok, newstate}
  end

  def handle_call(:who_won, _from, state) do
    {:reply, state.prevwinners, state}
  end

  def handle_call(:pool_state, _from, state) do
    results = state.prevwinners
    IO.inspect(results)
    {:reply, results, state}
  end

  defp send_sdr(sdr, columns) when is_list(sdr) do
    _ = for column <- columns, do: GenServer.cast(column, {:check_sdr, sdr})
    :done
  end

  defp pick_winners(newstate, average) do
    Enum.reject(newstate.poolstate, fn ({_, value}) -> value < average end)
       |> Enum.sort_by( &(get_value_from_tuple(&1)), :desc)
       |> Enum.take(@sparsity)
  end

  defp get_value_from_tuple({key, value}) do
    value
  end

  defp check_count(newstate, average, counter_state) do
    case counter_state.counter do

      @number_of_columns ->
          # Choose some winners!

          winners = pick_winners(newstate, average)
          IO.puts "WINNERS:  #{inspect winners}"
          IO.puts "AVERAGE:  #{inspect average}"
          IO.puts "SPARSITY:  #{inspect @sparsity}"
          IO.puts "COUNTER_STATE:  #{inspect counter_state}"
          IO.puts "TURN COUNTER:  #{inspect counter_state.turncounter}"


          # handle first run
          _ = for {column, _} <- winners, do: GenServer.cast( column, :strengthen_connections )

          # newstate = %State{ newstate | prevwinners: list_to_map(winners), turn_complete: false }
          newstate = %State{ newstate | turn_complete: true }

          IO.inspect ((System.os_time() - newstate.start_time)/1_000_000) # The result of "System.os_time()" is us!
          IO.puts "After counter #{counter_state.counter}: #{inspect HTM.Counter.value()}"
          IO.puts "Winners this round: #{inspect HTM.WinnersTracker.get_curr_winners()}"

          newstate
      _ ->
          newstate

    end
  end

  defp list_to_map(input_list) do
    input_list
    |> Enum.into(%{})
  end

  defp resetwinners(state) do
    %{ state | prevwinners: %{} }
  end

  defp to_zero_one(list_of_bools) do
    IO.puts "LIST OF BOOLS:  #{inspect list_of_bools}"
    for {_,x} <- list_of_bools, do: if(x == true, do: 1, else: 0)
  end

  defp colnum_from_tuple(list_of_bools) do
    IO.puts "LIST OF BOOLS:  #{inspect list_of_bools}"
    (for {key,_} <- list_of_bools, do: key
      |> peeker
      |> Atom.to_string
      |> String.split("p")
      |> get_tail
    )
    |> Enum.concat
  end

  defp peeker(data) do
    IO.puts "PEEKING AT DATA:  #{inspect data}"
    data
  end

  defp get_head([head|_]) do
    IO.puts "CHOSEN HEAD:  #{inspect head}"
    head
  end

  defp get_tail([_|tail]) do
    IO.puts "CHOSEN HEAD:  #{inspect tail}"
    tail
  end

  defp get_keys(input) do
    for {key,_} <- input, do: key
  end

end
