defmodule Venta do
  @enforce_keys [:item, :qty, :precio]
  defstruct @enforce_keys
end

defmodule Sucursal do
  @enforce_keys [:id, :ventas_diarias]
  defstruct @enforce_keys
end

defmodule ReportesCliente do
  @nodo_remoto :nodoservidor@servidor
  @servicio_remoto {:servicio_reportes, @nodo_remoto}

  @sucursales [
    %Sucursal{
      id: "Norte",
      ventas_diarias: [
        %Venta{item: "Café", qty: 85, precio: 350},
        %Venta{item: "Capuchino", qty: 40, precio: 500},
        %Venta{item: "Latte", qty: 55, precio: 480},
        %Venta{item: "Té", qty: 30, precio: 300},
        %Venta{item: "Sandwich", qty: 25, precio: 1200}
      ]
    },
    %Sucursal{
      id: "Centro",
      ventas_diarias: [
        %Venta{item: "Café", qty: 120, precio: 350},
        %Venta{item: "Capuchino", qty: 60, precio: 500},
        %Venta{item: "Té", qty: 50, precio: 300},
        %Venta{item: "Brownie", qty: 35, precio: 900}
      ]
    },
    %Sucursal{
      id: "Sur",
      ventas_diarias: [
        %Venta{item: "Café", qty: 70, precio: 350},
        %Venta{item: "Latte", qty: 65, precio: 480},
        %Venta{item: "Té Chai", qty: 28, precio: 600},
        %Venta{item: "Sandwich", qty: 18, precio: 1200}
      ]
    }
  ]

  def main do
    IO.puts("CLIENTE: conectando a #{@nodo_remoto} ...")

    case Node.connect(@nodo_remoto) do
      true ->
        IO.puts("CLIENTE: conectado. Enviando sucursales...")

        send(@servicio_remoto, {:generar_reportes, self(), @sucursales, repeticiones: 5})
        esperar_resultado()

      false ->
        IO.puts("CLIENTE: no pudo conectar al nodo remoto")
    end
  end

  defp esperar_resultado do
    receive do
      {:resultado_reportes, %{resumenes: resumenes, t_seq_ms: tseq, t_conc_ms: tconc, speedup: s}} ->
        IO.puts("\n=== REPORTES ===")

        Enum.each(resumenes, fn r ->
          IO.puts("Reporte listo Sucursal #{r.sucursal_id}")
          total = r.total_cents
          top3 = r.top3
          IO.puts("  Total del día: $#{Float.round(total / 100, 2)}")

          Enum.each(top3, fn %{item: i, revenue_cents: c} ->
            IO.puts("  - #{i}: $#{Float.round(c / 100, 2)}")
          end)
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

ReportesCliente.main()
