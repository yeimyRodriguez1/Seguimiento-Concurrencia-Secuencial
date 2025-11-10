# nodo-servidor-carrera.exs
defmodule Car do
  @enforce_keys [:id, :piloto, :pit_ms, :vuelta_ms]
  defstruct @enforce_keys
end

defmodule CarreraServidor do
  @servicio :servicio_carrera

  def main do
    IO.puts("SERVIDOR: servicio de carreras listo.")
    Process.register(self(), @servicio)
    loop()
  end

  defp loop do
    receive do
      {:simular, remitente, autos, opts} ->
        vueltas = Keyword.get(opts, :vueltas, 3)

        {t_seq_us, seq_totales} =
          :timer.tc(fn -> simular_secuencial(autos, vueltas) end)

        {t_conc_us, conc_totales} =
          :timer.tc(fn -> simular_concurrente(autos, vueltas) end)

        ranking =
          conc_totales
          |> Enum.sort_by(fn {_car, total} -> total end, :asc)
          |> Enum.with_index(1)
          |> Enum.map(fn {{%Car{id: id, piloto: p}, total}, pos} ->
            %{pos: pos, id: id, piloto: p, total_ms: total}
          end)

        t_seq_ms = div(t_seq_us, 1000)
        t_conc_ms = div(t_conc_us, 1000)

        speedup =
          if t_conc_ms == 0, do: :infinito, else: Float.round(t_seq_ms / max(t_conc_ms, 1), 2)

        send(
          remitente,
          {:resultado_carrera,
           %{ranking: ranking, t_seq_ms: t_seq_ms, t_conc_ms: t_conc_ms, speedup: speedup}}
        )

        loop()
    end
  end

  defp simular_secuencial(autos, vueltas) do
    Enum.map(autos, fn car ->
      total = simular_car(car, vueltas)
      {car, total}
    end)
  end

  defp simular_concurrente(autos, vueltas) do
    parent = self()

    refs =
      for car <- autos do
        ref = make_ref()

        spawn(fn ->
          total = simular_car(car, vueltas)
          send(parent, {:ok, ref, car, total})
        end)

        ref
      end

    collect(refs, [])
  end

  defp collect([], acc), do: acc

  defp collect(refs, acc) do
    receive do
      {:ok, ref, car, total} ->
        collect(List.delete(refs, ref), [{car, total} | acc])
    end
  end

  defp simular_car(%Car{pit_ms: pit, vuelta_ms: lap} = _car, vueltas) do
    Enum.each(1..vueltas, fn _ -> :timer.sleep(lap) end)
    :timer.sleep(pit)
    vueltas * lap + pit
  end
end

CarreraServidor.main()
