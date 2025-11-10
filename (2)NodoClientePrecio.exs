defmodule Producto do
  @enforce_keys [:nombre, :stock, :precio_sin_iva, :iva]
  defstruct @enforce_keys
end

defmodule PreciosCliente do
  @nodo_remoto :nodoservidor@servidor
  @servicio_remoto {:servicio_precios, @nodo_remoto}

  def main do
    IO.puts("CLIENTE: conectando a #{@nodo_remoto} ...")

    case Node.connect(@nodo_remoto) do
      true ->
        IO.puts("CLIENTE: conectado. Enviando lote para cálculo de precios...")

        productos = generar_productos(10_000)

        opts = [
          sleep_ms: 2,
          max_concurrency: 8 * System.schedulers_online(),
          muestra_n: 10
        ]

        send(@servicio_remoto, {:calcular, self(), productos, opts})
        esperar_resultado()

      false ->
        IO.puts("CLIENTE: no pudo conectar al nodo remoto")
    end
  end

  defp esperar_resultado do
    receive do
      {:resultado_precios,
       %{total_items: total, muestra: muestra, t_seq_ms: tseq, t_conc_ms: tconc, speedup: s}} ->
        IO.puts("\n=== RESULTADOS PRECIOS CON IVA ===")
        IO.puts("Total de productos: #{total}")
        IO.puts("Muestra de resultados (nombre, precio_final):")

        Enum.each(muestra, fn {nombre, precio} ->
          IO.puts("  - #{nombre}: $#{precio}")
        end)

        IO.puts("\nTiempo secuencial:  #{tseq} ms")
        IO.puts("Tiempo concurrente: #{tconc} ms")
        IO.puts("Speedup:            #{s}")
    after
      60_000 ->
        IO.puts("CLIENTE: timeout esperando resultado (60s)")
    end
  end

  defp generar_productos(n) when is_integer(n) and n > 0 do
    base_nombres =
      ~w(Teclado Mouse Pantalla Portatil DiscoSSD Memoria RAM Base Cargador Funda Webcam)

    for i <- 1..n do
      nombre = "#{Enum.at(base_nombres, rem(i, length(base_nombres)))}-#{i}"
      stock = :rand.uniform(200) - 1
      base = Float.round(:rand.uniform() * 500 + 20, 2)
      iva = Enum.random([0.05, 0.10, 0.12, 0.19])
      %Producto{nombre: nombre, stock: stock, precio_sin_iva: base, iva: iva}
    end
  end
end

PreciosCliente.main()
