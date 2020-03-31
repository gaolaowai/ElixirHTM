#
# Kicks off
#
defmodule HTM.Supervisor do
  use Supervisor

  def start_link do
    IO.puts "Starting THE supervisor..."
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      {HTM.KickStarter, %{sdr_size: 100, number_of_connections: 70}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
