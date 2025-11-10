Code.require_file("comentario.ex", __DIR__)

defmodule ModeracionComentarios do
  @min_len 5
  @max_len 300
  @forbidden ~w(spam oferta odio insulto toxico tóxico estafa scam)
  @link_regex ~r/(https?:\/\/|www\.)/i

  @delay_min 5
  @delay_max 12

  @spec moderar(%Comentario{}) :: {any(), :aprobado | :rechazado}
  def moderar(%Comentario{id: id, texto: texto}) do
    :timer.sleep(random_delay_ms())

    texto_norm = String.downcase(String.trim(texto))

    cond do
      String.length(texto_norm) < @min_len or String.length(texto_norm) > @max_len ->
        {id, :rechazado}

      Regex.match?(@link_regex, texto_norm) ->
        {id, :rechazado}

      contiene_prohibidas?(texto_norm) ->
        {id, :rechazado}

      true ->
        {id, :aprobado}
    end
  end

  def procesar_secuencial(comentarios) do
    Enum.map(comentarios, &moderar/1)
  end

  def procesar_concurrente(comentarios) do
    comentarios
    |> Task.async_stream(&moderar/1,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  def lista_comentarios do
    [
      %Comentario{id: 1, texto: "Excelente servicio, volveré pronto."},
      %Comentario{id: 2, texto: "Visita mi web http://spam.example para ofertas"},
      %Comentario{id: 3, texto: "Muy bueno!"},
      %Comentario{id: 4, texto: "Esto es una estafa total"},
      %Comentario{id: 5, texto: "Me gustó la atención y el café"},
      %Comentario{id: 6, texto: "Odio este lugar"},
      %Comentario{id: 7, texto: "Recomendado."},
      %Comentario{id: 8, texto: "Promo en www.scam.io 2x1!!"}
    ]
  end

  def iniciar do
    comentarios = lista_comentarios()

    {t1_us, out_seq} = :timer.tc(fn -> procesar_secuencial(comentarios) end)
    IO.puts("\n--- Resultados SECUNCIAL ---")
    imprimir_resultados(out_seq)

    {t2_us, out_con} = :timer.tc(fn -> procesar_concurrente(comentarios) end)
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

  defp contiene_prohibidas?(texto) do
    Enum.any?(@forbidden, fn w -> String.contains?(texto, w) end)
  end

  defp random_delay_ms do
    :rand.uniform(@delay_max - @delay_min + 1) + @delay_min - 1
  end

  defp imprimir_resultados(resultados) do
    Enum.each(resultados, fn {id, veredicto} ->
      IO.puts("  #{id}: #{veredicto}")
    end)
  end
end

ModeracionComentarios.iniciar()
