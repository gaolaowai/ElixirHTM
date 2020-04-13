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
      # Create pool
      "get_state pool"
    end

    def dispatch(%{ "action" => "get_group_state" } = json) do
      # Create pool
      "get_group_state"
    end

    def dispatch(%{ "action" => "submit_encoding" } = json) do
      # Create pool
      "send_encoding"
    end

end
