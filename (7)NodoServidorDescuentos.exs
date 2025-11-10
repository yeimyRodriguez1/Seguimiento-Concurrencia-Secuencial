defmodule Item do
  @enforce_keys [:nombre, :categoria, :precio, :qty]
  defstruct @enforce_keys ++ [bogo?: false]
end

defmodule Carrito do
  @enforce_keys [:id, :items]
  defstruct @enforce_keys ++ [cupon: nil]
end

defmodule DescuentosServidor do
  @servicio :servicio_descuentos

  def main do
    IO.puts("SERVIDOR: servicio de descuentos listo.")
    Process.register(self(), @servicio)
    loop()
  end

  defp loop do
    receive do
      {:procesar, remitente, carritos, opts} ->
        reps = Keyword.get(opts, :reps, 1)

        {t_seq_us, seq_result} =
          :timer.tc(fn -> procesar_secuencial(carritos, reps) end)

        {t_conc_us, conc_result} =
          :timer.tc(fn -> procesar_concurrente(carritos, reps) end)

        ranking =
          conc_result
          |> Enum.sort_by(fn {_c, total} -> total end, :asc)
          |> Enum.with_index(1)
          |> Enum.map(fn {{%Carrito{id: id}, total}, pos} ->
            %{pos: pos, id: id, total_final: Float.round(total, 2)}
          end)

        t_seq_ms = div(t_seq_us, 1000)
        t_conc_ms = div(t_conc_us, 1000)

        speedup =
          if t_conc_ms == 0, do: :infinito, else: Float.round(t_seq_ms / max(t_conc_ms, 1), 2)

        send(
          remitente,
          {:resultado_descuentos,
           %{ranking: ranking, t_seq_ms: t_seq_ms, t_conc_ms: t_conc_ms, speedup: speedup}}
        )

        loop()
    end
  end

  @cat_desc %{
    electronica: 0.10,
    hogar: 0.05,
    ropa: 0.08
  }

  @cupones %{
    "SAVE10" => 0.10,
    "SAVE20" => 0.20
  }

  defp procesar_secuencial(carritos, reps) do
    Enum.map(carritos, fn c ->
      total = total_con_descuentos(c, reps)
      {c, total}
    end)
  end

  defp procesar_concurrente(carritos, reps) do
    parent = self()

    refs =
      for c <- carritos do
        ref = make_ref()

        spawn(fn ->
          total = total_con_descuentos(c, reps)
          send(parent, {:ok, ref, c, total})
        end)

        ref
      end

    collect(refs, [])
  end

  defp collect([], acc), do: acc

  defp collect(refs, acc) do
    receive do
      {:ok, ref, c, total} ->
        collect(List.delete(refs, ref), [{c, total} | acc])
    end
  end

  defp total_con_descuentos(%Carrito{items: items, cupon: cupon} = carrito, reps) do
    for _ <- 1..reps do
      :timer.sleep(5 + rem(carrito.id * 7, 11))
    end

    subtotal_items =
      items
      |> Enum.map(&total_item/1)
      |> Enum.sum()

    total =
      case Map.get(@cupones, cupon) do
        nil -> subtotal_items
        pct -> subtotal_items * (1.0 - pct)
      end

    Float.round(total, 2)
  end

  defp total_item(%Item{precio: precio, qty: qty, bogo?: bogo, categoria: cat}) do
    qty_pagar =
      if bogo do
        div(qty, 2) + rem(qty, 2)
      else
        qty
      end

    base = precio * qty_pagar

    desc_cat = Map.get(@cat_desc, cat, 0.0)
    base * (1.0 - desc_cat)
  end
end

DescuentosServidor.main()
