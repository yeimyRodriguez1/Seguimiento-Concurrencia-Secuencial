defmodule LimpiezaResenas do
  @vuelo_ms_min 5
  @vuelo_ms_max 15

  @stopwords MapSet.new(~w(
    a al algo algunas algunos ante antes como con contra cual cuales cuando de del desde donde
    el ella ellas ellos en entre es esa esas ese esos esta estas este esto estos fue fueron ha
    hay la las le les lo los mas más me mi mis mucha muchas mucho muchos muy no nos o os para
    pero por porque que se sin sobre su sus te tiene tuve tuvo un una uno unos unas y ya
  ))

  def limpiar(%Review{id: id, texto: texto}) do
    :timer.sleep(random_delay_ms())

    limpio =
      texto
      |> String.downcase()
      |> quitar_tildes()
      |> quitar_puntuacion()
      |> normalizar_espacios()
      |> quitar_stopwords()

    {id, resumen(limpio)}
  end

  def procesar_secuencial(reviews) do
    Enum.map(reviews, &limpiar/1)
  end

  def procesar_concurrente(reviews) do
    reviews
    |> Enum.map(fn r -> Task.async(fn -> limpiar(r) end) end)
    |> Task.await_many(:infinity)
  end

  def lista_reviews do
    [
      %Review{
        id: 101,
        texto: "¡Excelente servicio! La comida fue fantástica y el lugar acogedor."
      },
      %Review{id: 102, texto: "Atención lenta; precios altos, pero la calidad es buena."},
      %Review{id: 103, texto: "Música muy fuerte, no pude conversar. El postre, increíble."},
      %Review{id: 104, texto: "Recomendado: porciones grandes y personal amable, volveré."},
      %Review{id: 105, texto: "Regular. La mesa estaba sucia y demoraron demasiado."},
      %Review{id: 106, texto: "Experiencia perfecta: rápido, rico y a buen precio."}
    ]
  end

  def iniciar do
    reviews = lista_reviews()

    {t1_us, out_seq} = :timer.tc(fn -> procesar_secuencial(reviews) end)
    {t2_us, out_con} = :timer.tc(fn -> procesar_concurrente(reviews) end)

    IO.puts("\nResultados SECUNCIAL:")
    Enum.each(out_seq, fn {id, res} -> IO.puts("  #{id}: #{res}") end)

    IO.puts("\nResultados CONCURRENTE:")
    Enum.each(out_con, fn {id, res} -> IO.puts("  #{id}: #{res}") end)

    speedup = t1_us / max(t2_us, 1)

    IO.puts("""
    \nMétricas:
      Secuencial:   #{div(t1_us, 1000)} ms
      Concurrente:  #{div(t2_us, 1000)} ms
      Speedup ≈     #{Float.round(speedup, 2)}x
    """)
  end

  defp random_delay_ms do
    :rand.uniform(@vuelo_ms_max - @vuelo_ms_min + 1) + @vuelo_ms_min - 1
  end

  defp quitar_tildes(texto) do
    texto
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
  end

  defp quitar_puntuacion(texto) do
    String.replace(texto, ~r/[^a-z0-9ñ\s]/u, " ")
  end

  defp normalizar_espacios(texto) do
    texto
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp quitar_stopwords(texto) do
    texto
    |> String.split(" ")
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
    |> Enum.join(" ")
  end

  defp resumen(texto_limpio, n_palabras \\ 8) do
    texto_limpio
    |> String.split(" ", trim: true)
    |> Enum.take(n_palabras)
    |> Enum.join(" ")
  end
end

LimpiezaResenas.iniciar()
