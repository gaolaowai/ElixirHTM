defmodule HTM.HttpClient do
  def send_request(request, callback_host, callback_port) when is_integer(callback_port) do
    
    # Convert to charlist, as that's what the erlang function is expecting.
    some_host_in_net = callback_host |> String.to_charlist
    
    {:ok, socket} =
      :gen_tcp.connect(callback_host, callback_port, [:binary, packet: :raw, active: false])
    
    :ok = :gen_tcp.send(socket, request)
    {:ok, response} = :gen_tcp.recv(socket, 0)
    :ok = :gen_tcp.close(socket)
    response
  end
end

request = """
POST /API/JSON HTTP/1.1\r\n
Host: example.com\r\n
User-Agent: ExampleBrowser/1.0\r\n
Accept: */*\r\n
\r\n\r\n
{ "action": "create_pool", "params":{"pool_id":"assigned/prefferid", "group_id": "id for a group of pools", "group_aware": true, "encoding_bit_length": 1000, "post_back_enable": true, "post_back_url": "https://someplace.to.post.outputs.to.com/SDRs", "minicolumn_params":{ "minicolumn_in_pool": 10000,"connectivity_to_input_space": 0.7, "cells_per_minicolumn": 32,"cleanup_frequency": 150 }  }}
"""

response = HTM.HttpClient.send_request(request, "127.0.0.1", 4000)
IO.puts response