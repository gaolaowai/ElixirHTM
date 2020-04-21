defmodule HTM.Handler do

  @moduledoc """
  Handles HTTP requests.
  """


  import HTM.Plugins, only: [rewrite_path: 1, log: 1, track: 1]
  import HTM.Parser, only: [parse: 1]
  import HTM.FileHandler, only: [handle_file: 2]

  alias HTM.Conv
  alias HTM.BitMan
  alias HTM.JsonDispatcher

  @pages_path Path.expand("../../pages", __DIR__)
  @doc """
  Transforms the request object and returns the response object
  """
  def handle(request) do
    request
    |> parse
    |> rewrite_path
    |> log
    |> route
    |> track
    |> format_response
  end

  def route(%Conv{ method: "GET", path: "/test" } = conv) do
    %{ conv | status: 200, resp_body: "Yeah, I'm up..." }
  end

  def route(%Conv{ method: "GET", path: "/SDR/" <> sdr } = conv) do
    HTM.PoolManager.send_sdr(sdr)
    %{ conv| status: 200, resp_body: "SDR AWAY!" }
  end

  def route(%Conv{ method: "GET", path: "/pool/start/" <> sdr_length } = conv) do
    HTM.PoolManager.start_pool(sdr_length)
    %{ conv| status: 200, resp_body: "Pool started..." }
  end

  def route(%Conv{ method: "POST", path: "/API/JSON"} = conv) do
    IO.puts "conv object: #{inspect conv}"
    response = JsonDispatcher.handle_json( Poison.decode!(conv.message_body) )
    %{ conv| status: 200, resp_body: inspect response }
  end

  def route(%Conv{ method: "GET", path: "/pool/state/" } = conv) do
    %{ conv| status: 200, resp_body: Poison.encode( HTM.PoolManager.poolstate() ) }
    # %{ conv| status: 200, resp_body: IO.inspect HTM.PoolManager.poolstate() }
  end

  def route(%Conv{method: "GET", path: "/about"} = conv) do
      @pages_path
      |> Path.join("about.html")
      |> File.read
      |> handle_file(conv)
  end


  def route(%Conv{ path: path } = conv) do
    %{ conv | status: 404, resp_body: "No #{path} here!"}
  end

  def format_response(%Conv{} = conv) do

    case is_tuple(conv.resp_body) do

      true -> IO.puts "Is a tuple. Looks like: #{inspect conv.resp_body}"
      {:ok, body} = conv.resp_body
      """
      HTTP/1.1 #{Conv.full_status(conv)}
      Content-Type: text/html
      Content-Length: #{String.length(body)}

      #{body}
      """

      false -> """
      HTTP/1.1 #{Conv.full_status(conv)}
      Content-Type: text/html
      Content-Length: #{String.length(conv.resp_body)}

      #{conv.resp_body}
      """
    end
  end

end
