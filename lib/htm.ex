defmodule HTM do
  @moduledoc """
  Documentation for `HTM`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> HTM.hello()
      :world

  """

  def start(_type, _args) do
    IO.puts "Starting the application..."
    :observer.start
    HTM.Supervisor.start_link()
  end
end
