defmodule Producto do
  @enforce_keys [:nombre, :stock, :precio_sin_iva, :iva]
  defstruct @enforce_keys
end

defmodule PreciosServidor do
  @servicio :servicio_precios

  def main do
    IO.puts("SERVIDOR: servicio de precios listo.")
    Process.register(self(), @servicio)
    loop()
  end

  defp loop do
    receive do
      {:calcular, remitente, productos, opts} ->
        sleep_ms        = Keyword.get(opts, :sleep_ms, 0)
        max_concurrency =
          Keyword.get(opts, :max_concurrency, System.schedulers_online() * 4)
        muestra_n       = Keyword.get(opts, :muestra_n, 10)

        {t_seq_us, seq_res} =
          :timer.tc(fn -> calcular_secuencial(productos, sleep_ms) end)

        {t_conc_us, conc_res} =
          :timer.tc(fn -> calcular_concurrente(productos, sleep_ms, max_concurrency) end)

          
        total_items = length(productos)

        t_seq_ms  = div(t_seq_us, 1000)
        t_conc_ms = div(t_conc_us, 1000)

        speedup =
          cond do
            t_conc_ms <= 0 and t_seq_ms > 0 -> :infinito
            t_conc_ms <= 0 and t_seq_ms == 0 -> 1.0
            true -> Float.round(t_seq_ms / max(t_conc_ms, 1), 2)
          end

        muestra = Enum.take(conc_res, muestra_n)

        send(remitente, {:resultado_precios, %{
          total_items: total_items,
          muestra: muestra,
          t_seq_ms: t_seq_ms,
          t_conc_ms: t_conc_ms,
          speedup: speedup
        }})

        loop()
    end
  end


  defp calcular_secuencial(productos, sleep_ms) do
    Enum.map(productos, fn p ->
      precio = precio_final(p)
      if sleep_ms > 0, do: :timer.sleep(sleep_ms)
      {p.nombre, precio}
    end)
  end

  defp calcular_concurrente(productos, sleep_ms, max_concurrency) do
    productos
    |> Task.async_stream(
      fn p ->
        precio = precio_final(p)
        if sleep_ms > 0, do: :timer.sleep(sleep_ms)
        {p.nombre, precio}
      end,
      max_concurrency: max_concurrency,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, v} -> v end)
  end

  defp precio_final(%Producto{precio_sin_iva: base, iva: iva}) do
    base * (1.0 + iva)
    |> Float.round(2)
  end
end

PreciosServidor.main()
