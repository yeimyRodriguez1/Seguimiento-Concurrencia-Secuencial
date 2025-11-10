defmodule Backoffice do
  @costos %{
    reindex: 120,
    purge_cache: 80,
    build_sitemap: 150,
    rotate_logs: 60,
    warmup_cold_keys: 100,
    compact_db: 200
  }

  @type tarea ::
          :reindex
          | :purge_cache
          | :build_sitemap
          | :rotate_logs
          | :warmup_cold_keys
          | :compact_db

  @spec ejecutar(tarea) :: :ok
  def ejecutar(tarea) when is_atom(tarea) do
    ms = Map.get(@costos, tarea, 50)
    :timer.sleep(ms)
    IO.puts("OK tarea #{tarea}")
    :ok
  end

  @spec ejecutar_lote_secuencial([tarea]) :: [:ok]
  def ejecutar_lote_secuencial(tareas) do
    Enum.map(tareas, &ejecutar/1)
  end

  @spec ejecutar_lote_concurrente([tarea]) :: [:ok]
  def ejecutar_lote_concurrente(tareas) do
    tareas
    |> Task.async_stream(&ejecutar/1,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  def lote_diario do
    [
      :purge_cache,
      :reindex,
      :build_sitemap,
      :rotate_logs,
      :warmup_cold_keys,
      :compact_db
    ]
  end

  def iniciar do
    tareas = lote_diario()

    {t1_us, _} = :timer.tc(fn -> ejecutar_lote_secuencial(tareas) end)
    IO.puts("\n--- Fin SECUNCIAL ---")

    {t2_us, _} = :timer.tc(fn -> ejecutar_lote_concurrente(tareas) end)
    IO.puts("\n--- Fin CONCURRENTE ---")

    speedup = t1_us / max(t2_us, 1)

    IO.puts("""
    \nMétricas:
      Secuencial:   #{div(t1_us, 1000)} ms
      Concurrente:  #{div(t2_us, 1000)} ms
      Speedup ≈     #{Float.round(speedup, 2)}x
    """)
  end
end

Backoffice.iniciar()
