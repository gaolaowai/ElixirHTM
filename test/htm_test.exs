defmodule HTMTest do
  use ExUnit.Case
  doctest HTM

  test "greets the world" do
    assert HTM.hello() == :world
  end
end
