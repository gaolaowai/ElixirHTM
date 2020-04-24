
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
