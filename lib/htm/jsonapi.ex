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

    def dispatch(%{ action: "get_state", params: params } = json) do
      # Create pool
      "get_state pool"
    end

    def dispatch(%{ action: "get_group_state", params: params } = json) do
      # Create pool
      "get_group_state"
    end

    def dispatch(%{ action: "send_encoding", params: params } = json) do
      # Create pool
      "send_encoding"
    end

end