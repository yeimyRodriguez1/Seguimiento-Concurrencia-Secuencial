defmodule PreciosIVA do
  @num_productos 50_000

  # ---- Lógica de negocio ----
  def precio_final(%Producto{precio_sin_iva: base, iva: iva}), do: base * (1.0 + iva)

  def calcular_linea(%Producto{nombre: nombre} = p), do: {nombre, precio_final(p)}

  # ---- Implementaciones ----
  def lista_productos(n \\ @num_productos) do
    1..n
    |> Enum.map(fn i ->
      # IVA variado para simular casos reales
      iva = Enum.at([0.0, 0.05, 0.19], rem(i, 3))

      %Producto{
        nombre: "Producto_#{i}",
        stock: rem(i * 7, 100) + 1,
        precio_sin_iva: 5.0 + rem(i * 23, 10_000) / 10.0,
        iva: iva
      }
    end)
  end

  # Procesamiento secuencial
  def precios_secuencial(productos) do
    Enum.map(productos, &calcular_linea/1)
  end

  # Procesamiento concurrente (un task por elemento, limitado por schedulers)
  def precios_concurrente(productos) do
    productos
    |> Task.async_stream(&calcular_linea/1,
      max_concurrency: System.schedulers_online(),
      ordered: true
    )
    |> Enum.map(fn {:ok, linea} -> linea end)
  end

  def iniciar do
    productos = lista_productos()

    {t_seq_us, res_seq} = :timer.tc(fn -> precios_secuencial(productos) end)
    {t_con_us, res_con} = :timer.tc(fn -> precios_concurrente(productos) end)

    t_seq_ms = Float.round(t_seq_us / 1000, 2)
    t_con_ms = Float.round(t_con_us / 1000, 2)
    speedup = if t_con_us == 0, do: :infinito, else: Float.round(t_seq_us / t_con_us, 2)

    IO.puts("\n---- RESULTADOS ----")
    IO.puts("Elementos procesados: #{length(productos)}")
    IO.puts("Secuencial:   #{t_seq_ms} ms")
    IO.puts("Concurrente:  #{t_con_ms} ms")
    IO.puts("Speedup:      x#{speedup}")

    IO.puts("\nMuestra (10 primeros):")

    Enum.take(res_con, 10)
    |> Enum.each(fn {nombre, total} ->
      IO.puts("  #{nombre} -> #{Float.round(total, 2)}")
    end)

    %{secuencial: res_seq, concurrente: res_con}
  end
end

PreciosIVA.iniciar()
