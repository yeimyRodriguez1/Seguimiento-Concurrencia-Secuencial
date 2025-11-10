defmodule Orden do
  @enforce_keys [:id, :item, :prep_ms]
  defstruct @enforce_keys
end

defmodule CocinaCliente do
  @nodo_remoto :nodoservidor@servidor
  @servicio_remoto {:servicio_cocina, @nodo_remoto}

  @ordenes [
    %Orden{id: 101, item: "Espresso",      prep_ms: 120},
    %Orden{id: 102, item: "Capuchino",     prep_ms: 220},
    %Orden{id: 103, item: "Latte",         prep_ms: 180},
    %Orden{id: 104, item: "Té verde",      prep_ms: 150},
    %Orden{id: 105, item: "Sandwich mixto",prep_ms: 300}
  ]

  def main do
    IO.puts("CLIENTE: conectando a #{@nodo_remoto} ...")
    case Node.connect(@nodo_remoto) do
      true ->
        IO.puts("CLIENTE: conectado. Enviando órdenes...")
        # Puedes ajustar :repeticiones para lotes grandes (p. ej. 10, 50, 100)
        send(@servicio_remoto, {:procesar, self(), @ordenes, repeticiones: 3})
        esperar_resultado()

      false ->
        IO.puts("CLIENTE: no pudo conectar al nodo remoto")
    end
  end

  defp esperar_resultado do
    receive do
      {:resultado_cocina, %{tickets: tickets, t_seq_ms: tseq, t_conc_ms: tconc, speedup: s}} ->
        IO.puts("\n=== TICKETS LISTOS ===")
        Enum.each(tickets, fn t ->
          IO.puts("Orden ##{t.id} (#{t.item}) lista en ~#{t.listo_en_ms} ms")
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

CocinaCliente.main()
