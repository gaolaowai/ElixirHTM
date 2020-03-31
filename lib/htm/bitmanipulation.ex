defmodule HTM.BitMan do


  # To convert list of ints, representing bits, into an integer representation.
  # def list_to_ints(input) when is_list(input) do
  #  for i <- input, do: <<>>, into: <<i::1>>
  # end

  # To convert list of ints, representing bits, into a a list of bits.
  def list_to_bitlist(enumerable) when is_list(enumerable) do
    for i <- enumerable, do: <<i::1>>
  end

  def bitlist_to_list(enumerable) when is_list(enumerable) do
    for i <- enumerable, do: if((i ==<<1::1>>), do: 1, else: 0)
  end

  def bitstring_maskand(mask, to_eval) do
    Enum.zip(mask, to_eval)
    # |> peek
    |> Enum.reduce([], fn x, acc -> [bitson?(x) | acc] end)
    |> Enum.reverse()
  end

  defp bitson?({mask, to_eval}) do
    # IO.puts "A: #{inspect mask}, B: #{inspect to_eval}"
    if((mask == <<1::1>>) && (to_eval == <<1::1>>)) do
      1
    else
      0
    end
  end

  defp peek(value) do
    IO.inspect value
    value
  end


  #
  # Probably not the right place to put this, but will resolve later.
  #
  def getstack do
    self()|> Process.info(:current_stacktrace)|> IO.inspect(label: "------------> stacktrace")
  end

end
