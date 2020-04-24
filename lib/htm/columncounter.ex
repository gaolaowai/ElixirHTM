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
