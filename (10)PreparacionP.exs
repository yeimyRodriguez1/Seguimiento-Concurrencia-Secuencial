Code.require_file("paquete.ex", __DIR__)

defmodule PreparacionPaquetes do
  @etiquetar_ms 40
  @pesar_ms 60
  @embalar_ms 90

  @fragil_recargo_ms 70

  @spec preparar(%Paquete{}) :: {any(), non_neg_integer()}
  def preparar(%Paquete{id: id, peso: peso, fragil?: fragil?}) do
    t0 = now_ms()

    :timer.sleep(@etiquetar_ms)

    if invalid_peso?(peso), do: :timer.sleep(@pesar_ms)

    :timer.sleep(@embalar_ms + if(fragil?, do: @fragil_recargo_ms, else: 0))

    total = now_ms() - t0
    IO.puts("Paquete #{id} listo en #{total} ms")
    {id, total}
  end

  def preparar_secuencial(paquetes) do
    Enum.map(paquetes, &preparar/1)
  end

  def preparar_concurrente(paquetes) do
    paquetes
    |> Task.async_stream(&preparar/1,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  def lista_paquetes do
    [
      %Paquete{id: "PK-001", peso: 2_000, fragil?: true},
      %Paquete{id: "PK-002", peso: 0, fragil?: false},
      %Paquete{id: "PK-003", peso: 500, fragil?: false},
      %Paquete{id: "PK-004", peso: -1, fragil?: true},
      %Paquete{id: "PK-005", peso: 1200, fragil?: true}
    ]
  end

  def iniciar do
    paquetes = lista_paquetes()

    {t1_us, out_seq} = :timer.tc(fn -> preparar_secuencial(paquetes) end)
    IO.puts("\n--- Resultados SECUNCIAL ---")
    imprimir_resultados(out_seq)

    {t2_us, out_con} = :timer.tc(fn -> preparar_concurrente(paquetes) end)
    IO.puts("\n--- Resultados CONCURRENTE ---")
    imprimir_resultados(out_con)

    speedup = t1_us / max(t2_us, 1)

    IO.puts("""
    \nMétricas:
      Secuencial:   #{div(t1_us, 1000)} ms
      Concurrente:  #{div(t2_us, 1000)} ms
      Speedup ≈     #{Float.round(speedup, 2)}x
    """)
  end

  defp invalid_peso?(p) when is_number(p), do: p <= 0
  defp invalid_peso?(_), do: true

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp imprimir_resultados(pares) do
    Enum.each(pares, fn {id, ms} ->
      IO.puts("  #{id} -> listo en #{ms} ms")
    end)
  end
end

PreparacionPaquetes.iniciar()
