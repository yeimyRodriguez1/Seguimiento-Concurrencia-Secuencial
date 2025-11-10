defmodule Venta do
  @enforce_keys [:item, :qty, :precio]
  defstruct @enforce_keys
end

defmodule Sucursal do
  @enforce_keys [:id, :ventas_diarias]
  defstruct @enforce_keys
end

defmodule ReportesServidor do
  @servicio :servicio_reportes

  def main do
    IO.puts("SERVIDOR: servicio de reportes listo.")
    Process.register(self(), @servicio)
    loop()
  end

  defp loop do
    receive do
      {:generar_reportes, remitente, sucursales, opts} ->
        repeticiones = Keyword.get(opts, :repeticiones, 1)
        lote = expandir(sucursales, repeticiones)

        {t_seq_us, _out_seq} = :timer.tc(fn -> generar_secuencial(lote) end)
        {t_conc_us, out_conc} = :timer.tc(fn -> generar_concurrente(lote) end)

        t_seq_ms = div(t_seq_us, 1000)
        t_conc_ms = div(t_conc_us, 1000)

        speedup =
          if t_conc_ms == 0, do: :infinito, else: Float.round(t_seq_ms / max(t_conc_ms, 1), 2)

        send(
          remitente,
          {:resultado_reportes,
           %{
             resumenes: out_conc,
             t_seq_ms: t_seq_ms,
             t_conc_ms: t_conc_ms,
             speedup: speedup
           }}
        )

        loop()
    end
  end

  defp generar_secuencial(sucursales) do
    Enum.map(sucursales, &reporte_sucursal/1)
  end

  defp generar_concurrente(sucursales) do
    parent = self()

    refs =
      for s <- sucursales do
        ref = make_ref()

        spawn(fn ->
          r = reporte_sucursal(s)
          send(parent, {:ok, ref, r})
        end)

        ref
      end

    recolectar(refs, [])
  end

  defp recolectar([], acc), do: Enum.reverse(acc)

  defp recolectar(refs, acc) do
    receive do
      {:ok, ref, r} ->
        recolectar(List.delete(refs, ref), [r | acc])
    end
  end

  defp reporte_sucursal(%Sucursal{id: id, ventas_diarias: ventas}) do
    :timer.sleep(Enum.random(50..120))

    total_cent =
      Enum.reduce(ventas, 0, fn %Venta{qty: q, precio: p}, acc -> acc + q * p end)

    por_item =
      ventas
      |> Enum.group_by(& &1.item)
      |> Enum.map(fn {item, vs} ->
        rev = Enum.reduce(vs, 0, fn %Venta{qty: q, precio: p}, a -> a + q * p end)
        %{item: item, revenue_cents: rev}
      end)
      |> Enum.sort_by(& &1.revenue_cents, :desc)
      |> Enum.take(3)

    %{sucursal_id: id, total_cents: total_cent, top3: por_item}
  end

  defp expandir(sucursales, n) when n <= 1, do: sucursales
  defp expandir(sucursales, n), do: List.duplicate(sucursales, n) |> List.flatten()
end

ReportesServidor.main()
