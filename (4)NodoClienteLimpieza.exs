defmodule Review do
  @enforce_keys [:id, :texto]
  defstruct @enforce_keys
end

defmodule ResenasCliente do
  @nodo_remoto :nodoservidor@servidor
  @servicio_remoto {:servicio_resenas, @nodo_remoto}

  @reseñas [
    %Review{
      id: 1,
      texto: "¡Excelente servicio! La comida fue deliciosa y el personal muy atento."
    },
    %Review{id: 2, texto: "Me ENCANTÓ el lugar, pero el tiempo de espera fue largo."},
    %Review{id: 3, texto: "Precio/calidad OK. Repetiría sin dudarlo."},
    %Review{id: 4, texto: "No me gustó la música; demasiado fuerte para conversar."},
    %Review{id: 5, texto: "Todo perfecto. Volveré pronto :)"},
    %Review{id: 6, texto: "La atención podría mejorar; el café llegó tibio."}
  ]

  def main do
    IO.puts("CLIENTE: conectando a #{@nodo_remoto} ...")

    case Node.connect(@nodo_remoto) do
      true ->
        IO.puts("CLIENTE: conectado. Enviando lote de reseñas...")
        send(@servicio_remoto, {:limpiar_lote, self(), @reseñas, repeticiones: 5})
        esperar_resultado()

      false ->
        IO.puts("CLIENTE: no pudo conectar al nodo remoto")
    end
  end

  defp esperar_resultado do
    receive do
      {:resultado_resenas, %{salida: salida, t_seq_ms: tseq, t_conc_ms: tconc, speedup: s}} ->
        IO.puts("\n=== RESEÑAS (RESÚMENES LIMPIOS) ===")

        Enum.each(salida, fn r ->
          IO.puts("##{r.id}: #{r.resumen}")
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

ResenasCliente.main()
