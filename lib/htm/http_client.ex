defmodule HTM.HttpClient do
  def send_request(request, callback_host, callback_port) when is_integer(callback_port) do

    # Convert to charlist, as that's what the erlang function is expecting.
    some_host_in_net = callback_host |> String.to_charlist

    {:ok, socket} =
      :gen_tcp.connect(some_host_in_net, callback_port, [:binary, packet: :raw, active: false])

    :ok = :gen_tcp.send(socket, request)

    # Check response status
    case :gen_tcp.recv(socket, 0) do
      {:ok, response} -> :ok = :gen_tcp.close(socket)
        response
      {:error, :closed} -> IO.puts "Something went wrong."
    end

  end
end

defmodule HTM.ServerTest do

  def request_pool do
    """
    POST /API/JSON HTTP/1.1
    Host: example.com
    User-Agent: ExampleBrowser/1.0
    Accept: */*

    { "action": "create_pool", "params":{"pool_id":"assigned/prefferid", "group_id": "id for a group of pools", "group_aware": true, "encoding_bit_length": 1000, "post_back_enable": true, "post_back_url": "https://someplace.to.post.outputs.to.com/SDRs", "minicolumn_params":{ "minicolumn_in_pool": 10000,"connectivity_to_input_space": 0.7, "cells_per_minicolumn": 32,"cleanup_frequency": 150 }  }}
    """
  end

  def request_send_encoding do
    """
    POST /API/JSON HTTP/1.1
    Host: example.com
    User-Agent: ExampleBrowser/1.0
    Accept: */*

    { "action": "submit_encoding",
    "params":
        {
            "pool_id":"assigned/prefferid",
            "encoding": "text of bits"
        }
    }
    """
  end

  def request_get_poolstate do
  """
  POST /API/JSON HTTP/1.1
  Host: example.com
  User-Agent: ExampleBrowser/1.0
  Accept: */*

  { "action": "get_state",
  "params":
       {
        "pool_id":"assigned/prefferid",
        "which_state": "TM/SP/ALL",
        "post_back_enable": true,
        "post_back_url": "https://ip:port/endpoint",
        "visual?": true
       }
  }
  """
  end

  def testserver do
    HTM.HttpClient.send_request(request_pool, "127.0.0.1", 4000)
    :timer.sleep(1000)
    HTM.HttpClient.send_request(request_send_encoding, "127.0.0.1", 4000)
    :timer.sleep(3000)
    HTM.HttpClient.send_request(request_get_poolstate, "127.0.0.1", 4000)
  end

end

# response = HTM.HttpClient.send_request(request, "127.0.0.1", 4000)
# IO.puts response
