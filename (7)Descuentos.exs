defmodule Descuentos do
  @cupones %{
    "SALE10" => 0.10,
    "VIP20" => 0.20,
    "BF30" => 0.30
  }

  @desc_cat %{
    "ropa" => 0.15,
    "electronica" => 0.05,
    "snacks" => 0.10
  }

  defp costo_simulado(), do: :timer.sleep(Enum.random(5..15))

  def total_con_descuentos(%Carrito{id: id, items: items, cupon: cupon}) do
    costo_simulado()

    total_items =
      Enum.reduce(items, 0.0, fn %Item{} = it, acc ->
        qty_efectiva = if it.dos_por_uno?, do: it.qty - div(it.qty, 2), else: it.qty
        desc_cat = Map.get(@desc_cat, to_string(it.categoria), 0.0)
        precio_cat = it.precio * (1.0 - desc_cat)
        acc + precio_cat * qty_efectiva
      end)

    desc_cupon = Map.get(@cupones, cupon || "", 0.0)
    total_final = total_items * (1.0 - desc_cupon)

    {id, Float.round(total_final, 2)}
  end
end

defmodule Checkout do
  def lista_carritos do
    [
      %Carrito{
        id: 101,
        cupon: "SALE10",
        items: [
          %Item{
            id: 1,
            nombre: "Remera",
            categoria: "ropa",
            precio: 120_000.0,
            qty: 2,
            dos_por_uno?: false
          },
          %Item{
            id: 2,
            nombre: "Papas",
            categoria: "snacks",
            precio: 12_000.0,
            qty: 3,
            dos_por_uno?: true
          }
        ]
      },
      %Carrito{
        id: 102,
        cupon: nil,
        items: [
          %Item{
            id: 3,
            nombre: "Auriculares",
            categoria: "electronica",
            precio: 320_000.0,
            qty: 1,
            dos_por_uno?: false
          },
          %Item{
            id: 4,
            nombre: "Gaseosa",
            categoria: "snacks",
            precio: 8_000.0,
            qty: 4,
            dos_por_uno?: true
          }
        ]
      },
      %Carrito{
        id: 103,
        cupon: "VIP20",
        items: [
          %Item{
            id: 5,
            nombre: "Buzo",
            categoria: "ropa",
            precio: 180_000.0,
            qty: 1,
            dos_por_uno?: false
          },
          %Item{
            id: 6,
            nombre: "Papas",
            categoria: "snacks",
            precio: 12_000.0,
            qty: 2,
            dos_por_uno?: true
          }
        ]
      },
      %Carrito{
        id: 104,
        cupon: "BF30",
        items: [
          %Item{
            id: 7,
            nombre: "Camiseta",
            categoria: "ropa",
            precio: 150_000.0,
            qty: 3,
            dos_por_uno?: false
          }
        ]
      }
    ]
  end

  defp simular_carrito(%Carrito{} = c) do
    {id, total} = Descuentos.total_con_descuentos(c)
    IO.puts("Carrito #{id} total final: #{total} (ms de reglas simuladas)")
    {id, total}
  end

  def checkout_secuencial(carritos) do
    Enum.map(carritos, &simular_carrito/1)
    |> Enum.sort_by(fn {_id, total} -> total end)
  end

  def checkout_concurrente(carritos) do
    carritos
    |> Task.async_stream(&simular_carrito/1,
      timeout: :infinity,
      max_concurrency: System.schedulers_online()
    )
    |> Enum.map(fn {:ok, res} -> res end)
    |> Enum.sort_by(fn {_id, total} -> total end)
  end

  defp imprimir_ranking(titulo, pares) do
    IO.puts("\n#{titulo}:")

    Enum.each(pares, fn {id, total} ->
      IO.puts("  Carrito #{id} - $#{:erlang.float_to_binary(total, [:compact, {:decimals, 2}])}")
    end)
  end

  def iniciar do
    carritos = lista_carritos()

    {t_seq_us, ranking_seq} = :timer.tc(fn -> checkout_secuencial(carritos) end)
    imprimir_ranking("Ranking SECUENCIAL (↓ total)", ranking_seq)

    IO.puts("\n\n")

    {t_con_us, ranking_con} = :timer.tc(fn -> checkout_concurrente(carritos) end)
    imprimir_ranking("Ranking CONCURRENTE (↓ total)", ranking_con)

    speedup =
      if t_con_us > 0 do
        Float.round(t_seq_us / t_con_us, 2)
      else
        :infinity
      end

    IO.puts("""
    \n---------------------------
    Tiempo secuencial:  #{t_seq_us} µs
    Tiempo concurrente: #{t_con_us} µs
    Speedup:            #{speedup}x
    ---------------------------
    """)
  end
end

Checkout.iniciar()
