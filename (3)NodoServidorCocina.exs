defmodule Orden do
  @enforce_keys [:id, :item, :prep_ms]
  defstruct @enforce_keys
end

defmodule CocinaServidor do
  @servicio :servicio_cocina

  def main do
    IO.puts("SERVIDOR: servicio de cocina listo.")
    Process.register(self(), @servicio)
    loop()
  end

  defp loop do
    receive do
      {:procesar, remitente, ordenes, opts} ->
        repeticiones = Keyword.get(opts, :repeticiones, 1)
        lote = expandir(ordenes, repeticiones)

        {t_seq_us, tickets_seq} = :timer.tc(fn -> preparar_secuencial(lote) end)
        {t_conc_us, tickets_conc} = :timer.tc(fn -> preparar_concurrente(lote) end)

        t_seq_ms = div(t_seq_us, 1000)
        t_conc_ms = div(t_conc_us, 1000)

        speedup =
          if t_conc_ms == 0, do: :infinito, else: Float.round(t_seq_ms / max(t_conc_ms, 1), 2)

        send(
          remitente,
          {:resultado_cocina,
           %{
             tickets: tickets_conc,
             t_seq_ms: t_seq_ms,
             t_conc_ms: t_conc_ms,
             speedup: speedup
           }}
        )

        loop()
    end
  end

  defp preparar_secuencial(ordenes) do
    Enum.map(ordenes, &preparar_orden/1)
  end

  defp preparar_concurrente(ordenes) do
    parent = self()

    refs =
      for o <- ordenes do
        ref = make_ref()

        spawn(fn ->
          ticket = preparar_orden(o)
          send(parent, {:ok, ref, ticket})
        end)

        ref
      end

    recolectar(refs, [])
  end

  defp recolectar([], acc), do: Enum.reverse(acc)

  defp recolectar(refs, acc) do
    receive do
      {:ok, ref, ticket} ->
        recolectar(List.delete(refs, ref), [ticket | acc])
    end
  end

  defp preparar_orden(%Orden{id: id, item: item, prep_ms: ms}) do
    :timer.sleep(ms)
    %{id: id, item: item, listo_en_ms: ms}
  end

  defp expandir(ordenes, n) when n <= 1, do: ordenes
  defp expandir(ordenes, n), do: List.duplicate(ordenes, n) |> List.flatten()
end

CocinaServidor.main()
