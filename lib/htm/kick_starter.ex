defmodule HTM.KickStarter do
  use GenServer

  #
  # This gets called by the supervisor.
  #
  def start_link(_arg) do
    IO.puts "Starting the kickstarter..."
    state = %{server_pid: nil, pool_man_pid: nil}
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  #
  # This is the first function that gets called when any GenServer starts (start_link).
  #
  def init(state) do
    Process.flag(:trap_exit, true)
    server_pid = start_server()
    new_state = %{state | server_pid: server_pid}

    {:ok, new_state}
  end

  def handle_info({:EXIT, _pid, reason}, _state) do
    IO.puts "HttpServer exited (#{inspect reason})"
    server_pid = start_server()
    {:noreply, server_pid}
  end

  def handle_cast({:start_pool, args}, state) do
    {:ok, pool_pid} = start_pool(args)
    Process.link(pool_pid)

    new_state = %{ state | pool_man_pid: pool_pid}
    # {:reply, %{pool_man_pid: #PID<0.1168.0>, server_pid: #PID<0.163.0>}}
    {:noreply, new_state}
  end

  defp start_pool(args) do
    IO.puts "Starting the HTTP server..."
    HTM.PoolManager.start_links(args)
  end

  defp start_server do
    IO.puts "Starting the HTTP server..."
    _port = Application.get_env(:htm, :port)
    server_pid = spawn_link(HTM.HttpServer, :start, [4000])
    Process.register(server_pid, :http_server)
    server_pid
  end
end
