defmodule HTM.PoolManager do
  use GenServer

  alias HTM.Column
  alias HTM.BitMan

  @number_of_columns 10000 # acts like a global within this module
  @connection_percent_to_sdr 0.7
  @sparsity_percentage 0.02 #between 0.00 and 1.0
  @sparsity trunc(@number_of_columns / @sparsity_percentage)

  def start_links(args) do

    # Eventually pass this in at init
    pool_id = "pool_id_here"

    # Create the initial map of distal connections to input space.
    # Each column then shuffles their own copy of this at startup.
    default_distals = Range.new(1, args.sdr_size)
      |> Enum.reduce([], fn x, acc -> if (x < args.number_of_connections) do [1|acc] else [0|acc] end end)
      |> HTM.BitMan.list_to_bitlist

    IO.inspect default_distals

    # Start a number of processes, returning their pids as a list to be stored in local state.
    columns = for i <- Range.new(1, @number_of_columns), do: Column.start(i, default_distals)

    state = %{pool_id: pool_id, columns: columns, poolstate: %{}, prevwinners: %{}, counter: 0, start_time: System.os_time(), stop_time: System.os_time(), resting: [], turn_complete: true }

    HTM.Counter.start_link(0)
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
    |> to_zero_one
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
    HTM.Counter.reset()
    state = %{ state | start_time: System.os_time(), resting: [], turn_complete: false}
    send_sdr(sdr, state.columns)
    {:noreply, state}
  end

  @doc """
  Updates the local state for the connection counting.
  """
  def handle_call({:incr_counter, {l_id, score, resting}}, _from, state) do
    # newstate = %{}

    newstate = %{ state | poolstate: Map.update(state.poolstate, l_id, score, fn x -> if(resting) do 0.0 else x end end ) }
    newstate = %{ newstate | resting: [ {l_id, resting} | state.resting] }

    HTM.Counter.increment(score)
    counter_state = HTM.Counter.value()
    average = counter_state.current_avg
    # IO.puts "poolstate counter: #{HTM.Counter.value()}"
    if(counter_state.counter == @number_of_columns) do
      # Choose some winners!
      winners = pick_winners(newstate, average)

      # handle first run
      _ = for {column, _} <- winners, do: GenServer.cast( column, :strengthen_connections )

      newstate = %{ newstate | prevwinners: winners, turn_complete: false }

      IO.inspect ((System.os_time() - state.start_time)/1_000_000) # The result of "System.os_time()" is us!
      IO.puts "After counter #{counter_state.counter}: #{inspect HTM.Counter.value()}"
      IO.puts "Winners this round: #{inspect newstate.prevwinners}"
    end

    if(newstate.turn_complete == true) do
      IO.puts "TURN COMPLETE!!!!\nAfter counter #{counter_state.counter}: #{inspect HTM.Counter.value()}"
      IO.puts "Winners this round: #{inspect HTM.WinnersTracker.value()}"
    end

    {:reply, :ok, newstate}
  end

  def handle_call({:i_won, {l_id, cell}}, _from, state) do
    # add winner to ce
    HTM.WinnersTracker.add_winner({l_id, cell})
    newstate = %{ state | prevwinners: Map.update(state.prevwinners, l_id, cell, fn x -> x end) }

    {:reply, :ok, newstate}
  end

  def handle_call(:pool_state, _from, state) do
    results = HTM.WinnersTracker.value()
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

  defp resetwinners(state) do
    %{ state | prevwinners: %{} }
  end

  defp to_zero_one(list_of_bools) do
    for {_,x} <- list_of_bools, do: if(x == true, do: 1, else: 0)
  end

end










defmodule HTM.Counter do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> %{counter: initial_value, current_avg: 0, sum: 0} end, name: __MODULE__)
  end

  def value do
    Agent.get(__MODULE__, fn state -> state end)
  end

  @doc """
  Find rolling average, and increment counter.
  """
  def increment(value) do
    # newval = &1.counter + 1
    Agent.update(__MODULE__, fn state ->
      newcounter = state.counter + 1
      newsum = state.sum + value
      newaverage = newsum / newcounter
      %{ state | counter: newcounter, current_avg: newaverage, sum: newsum}
    end )
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> %{counter: 0, current_avg: 0, sum: 0} end )
  end

end











defmodule HTM.WinnersTracker do
  use Agent

  def start_link(g_id) do
    Agent.start_link(fn -> %{groupid: g_id, prevwinners: %{}, currentwinners: %{}} end, name: __MODULE__)
  end

  def value do
    Agent.get(__MODULE__, fn state -> state end)
  end

  @doc """
  Find rolling average, and increment counter.
  """
  def add_winner({l_id, cell}) do
    # newval = &1.counter + 1
    Agent.update(__MODULE__, fn state ->
      %{ state | currentwinners: Map.update(state.currentwinners, l_id, cell, fn x -> x end) }
    end )
  end

  def roll_winners do
    # newval = &1.counter + 1
    Agent.update(__MODULE__, fn state ->
      oldwinners = state.currentwinners
      %{ state | prevwinners: oldwinners, currentwinners: %{} }
    end )
  end

  def get_curr_winners do
    Agent.get(__MODULE__, fn state -> state.currentwinners end)
  end

  def get_prev_winners do
    # newval = &1.counter + 1
    Agent.get(__MODULE__, fn state -> state.prevwinners end)
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> %{counter: 0, current_avg: 0, sum: 0} end )
  end

end
