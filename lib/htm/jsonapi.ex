defmodule HTM.JsonDispatcher do
    def handle_json(json) when is_map(json) do
      IO.puts "Handling JSON!!!\n"
      json
      |> dispatch
    end

    def dispatch(%{ "action" => "create_pool" } = json) do
      # Create pool
      "created pool"
    end

    def dispatch(%{ "action" => "get_state"} = json) do
      # get_state pool
      "get_state pool"
    end

    def dispatch(%{ "action" => "get_group_state" } = json) do
      # get_group_statel
      "get_group_state"
    end

    def dispatch(%{ "action" => "submit_encoding" } = json) do
      # send_encoding
      "send_encoding"
    end

end
