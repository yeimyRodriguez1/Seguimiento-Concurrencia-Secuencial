defmodule Car do
  @enforce_keys [:id, :piloto, :pit_ms, :vuelta_ms]
  defstruct @enforce_keys
end

defmodule CarreraCliente do
  @nodo_remoto :nodoservidor@servidor
  @servicio_remoto {:servicio_carrera, @nodo_remoto}


  @autos [
    %Car{id: 7, piloto: "Hamilton",  pit_ms: 120, vuelta_ms: 180},
    %Car{id: 16, piloto: "Leclerc",  pit_ms: 150, vuelta_ms: 170},
    %Car{id: 1, piloto: "Verstappen", pit_ms: 100, vuelta_ms: 160},
    %Car{id: 55, piloto: "Sainz",    pit_ms: 140, vuelta_ms: 185},

  ]

  def main do
    IO.puts("CLIENTE: conectando a #{@nodo_remoto} ...")
    case Node.connect(@nodo_remoto) do
      true ->
        IO.puts("CLIENTE: conectado. Enviando simulación...")
        send(@servicio_remoto, {:simular, self(), @autos, vueltas: 3})
        esperar_resultado()

      false ->
        IO.puts("CLIENTE: no pudo conectar al nodo remoto")
    end
  end

  defp esperar_resultado do
    receive do
      {:resultado_carrera, %{ranking: ranking, t_seq_ms: tseq, t_conc_ms: tconc, speedup: s}} ->
        IO.puts("\n=== RESULTADOS ===")
        Enum.each(ranking, fn r ->
          IO.puts("#{r.pos}. ##{r.id} #{r.piloto}  total=#{r.total_ms} ms")
        end)
        IO.puts("\nTiempo secuencial:  #{tseq} ms")
        IO.puts("Tiempo concurrente: #{tconc} ms")
        IO.puts("Speedup:            #{s}")
    after
      20_000 ->
        IO.puts("CLIENTE: timeout esperando resultado (20s)")
    end
  end
end

CarreraCliente.main()
