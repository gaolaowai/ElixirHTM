defmodule HTM.Parser do


  alias HTM.Conv

  def parse(request) do
    top = ""
    params_string = ""

    request = request |> String.replace("\r\n", "\n")
    IO.puts "replaced: #{inspect request}"

    [top, params_string] = request  |> String.split("\n\n")

    [request_line | header_lines] = String.split(top, "\n")

    [method, path, _] = String.split(request_line, " ")

    headers = parse_headers(header_lines, %{})

    IO.puts "Headers: #{inspect(headers)}"

    params = parse_params(headers["Content-Type"], params_string)
    IO.puts "params_string: #{inspect params_string}"
    %Conv{
      method: method,
      path: path,
      params: params,
      headers: headers,
      message_body: params_string
    }
  end

  def parse_headers([head|tail], headers) do
    [key, value] = String.split(head, ": ")
    headers = Map.put(headers, key, value)
    parse_headers(tail, headers)
  end

  def parse_headers([], headers) do
    headers
  end

  def parse_params("application/x-www-form-urlencoded", param_string) do
    param_string |> String.trim |> URI.decode_query
  end

  def parse_params(_,_), do: %{}

end

