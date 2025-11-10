defmodule ReportesSucursal do
  @delay_min 50
  @delay_max 120

  def generar_reporte(%Sucursal{id: id, ventas_diarias: ventas}) do
    :timer.sleep(random_delay_ms())

    total = Enum.reduce(ventas, 0, fn v, acc -> acc + v.ventas end)
    dias = max(length(ventas), 1)
    promedio_diario = total / dias

    top3_items =
      ventas
      |> Enum.group_by(& &1.item, & &1.ventas)
      |> Enum.map(fn {item, vs} -> {item, Enum.sum(vs)} end)
      |> Enum.sort_by(fn {_item, sum} -> -sum end)
      |> Enum.take(3)

    reporte = %{
      total: total,
      promedio_diario: promedio_diario,
      top3_items: top3_items
    }

    IO.puts("Reporte listo Sucursal #{id}")
    {id, reporte}
  end

  def procesar_secuencial(sucursales) do
    Enum.map(sucursales, &generar_reporte/1)
  end

  def procesar_concurrente(sucursales) do
    sucursales
    |> Enum.map(fn s -> Task.async(fn -> generar_reporte(s) end) end)
    |> Task.await_many(:infinity)
  end

  def lista_sucursales do
    [
      %Sucursal{
        id: "Norte",
        ventas_diarias: [
          %{item: "Arepa", ventas: 120},
          %{item: "Café", ventas: 80},
          %{item: "Jugo", ventas: 45},
          %{item: "Arepa", ventas: 95},
          %{item: "Café", ventas: 110}
        ]
      },
      %Sucursal{
        id: "Centro",
        ventas_diarias: [
          %{item: "Café", ventas: 200},
          %{item: "Arepa", ventas: 60},
          %{item: "Sandwich", ventas: 70},
          %{item: "Café", ventas: 130}
        ]
      },
      %Sucursal{
        id: "Sur",
        ventas_diarias: [
          %{item: "Jugo", ventas: 90},
          %{item: "Arepa", ventas: 150},
          %{item: "Empanada", ventas: 85},
          %{item: "Café", ventas: 60},
          %{item: "Empanada", ventas: 120}
        ]
      },
      %Sucursal{
        id: "Occidente",
        ventas_diarias: [
          %{item: "Café", ventas: 95},
          %{item: "Arepa", ventas: 105},
          %{item: "Jugo", ventas: 40}
        ]
      }
    ]
  end

  def iniciar do
    sucursales = lista_sucursales()

    {t1_us, rep_seq} = :timer.tc(fn -> procesar_secuencial(sucursales) end)
    {t2_us, rep_con} = :timer.tc(fn -> procesar_concurrente(sucursales) end)

    IO.puts("\n--- Reportes SECUNCIAL ---")
    imprimir_reportes(rep_seq)

    IO.puts("\n--- Reportes CONCURRENTE ---")
    imprimir_reportes(rep_con)

    speedup = t1_us / max(t2_us, 1)

    IO.puts("""
    \nMétricas:
      Secuencial:   #{div(t1_us, 1000)} ms
      Concurrente:  #{div(t2_us, 1000)} ms
      Speedup ≈     #{Float.round(speedup, 2)}x
    """)
  end

  defp random_delay_ms do
    :rand.uniform(@delay_max - @delay_min + 1) + @delay_min - 1
  end

  defp imprimir_reportes(resultados) do
    Enum.each(resultados, fn {id, r} ->
      IO.puts("  Sucursal #{id}:")
      IO.puts("    Total ventas: #{r.total}")
      IO.puts("    Promedio diario: #{Float.round(r.promedio_diario, 2)}")
      IO.puts("    Top-3 ítems:")

      Enum.each(r.top3_items, fn {item, sum} ->
        IO.puts("      - #{item}: #{sum}")
      end)
    end)
  end
end

ReportesSucursal.iniciar()
