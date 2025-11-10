defmodule Review do
  @enforce_keys [:id, :texto]
  defstruct @enforce_keys
end

defmodule ResenasServidor do
  @servicio :servicio_resenas

  def main do
    IO.puts("SERVIDOR: servicio de reseñas listo.")
    Process.register(self(), @servicio)
    loop()
  end

  defp loop do
    receive do
      {:limpiar_lote, remitente, reseñas, opts} ->
        repeticiones = Keyword.get(opts, :repeticiones, 1)
        lote = expandir(reseñas, repeticiones)

        {t_seq_us, seq_salida} = :timer.tc(fn -> limpiar_secuencial(lote) end)
        {t_conc_us, conc_salida} = :timer.tc(fn -> limpiar_concurrente(lote) end)

        t_seq_ms = div(t_seq_us, 1000)
        t_conc_ms = div(t_conc_us, 1000)

        speedup =
          if t_conc_ms == 0, do: :infinito, else: Float.round(t_seq_ms / max(t_conc_ms, 1), 2)

        send(
          remitente,
          {:resultado_resenas,
           %{
             salida: conc_salida,
             t_seq_ms: t_seq_ms,
             t_conc_ms: t_conc_ms,
             speedup: speedup
           }}
        )

        loop()
    end
  end

  defp limpiar_secuencial(reseñas) do
    Enum.map(reseñas, &limpiar_review/1)
  end

  defp limpiar_concurrente(reseñas) do
    parent = self()

    refs =
      for r <- reseñas do
        ref = make_ref()

        spawn(fn ->
          salida = limpiar_review(r)
          send(parent, {:ok, ref, salida})
        end)

        ref
      end

    recolectar(refs, [])
  end

  defp recolectar([], acc), do: Enum.reverse(acc)

  defp recolectar(refs, acc) do
    receive do
      {:ok, ref, salida} ->
        recolectar(List.delete(refs, ref), [salida | acc])
    end
  end

  defp limpiar_review(%Review{id: id, texto: texto}) do
    :timer.sleep(:rand.uniform(11) + 4)

    limpio =
      texto
      |> String.downcase()
      |> quitar_tildes()
      |> quitar_stopwords()

    resumen =
      limpio
      |> String.split()
      |> Enum.take(8)
      |> Enum.join(" ")

    %{id: id, resumen: resumen}
  end

  defp quitar_tildes(str) do
    str
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
  end

  @stop_es ~w(
    a al algo algunas algunos ante antes como con contra cual cuando de del desde donde
    dos e el ella ellas ellos en entre es esa esas ese eso esos esta estaba estaban
    este esto estos fue fueron ha han hasta hay la las le les lo los mas mas o para
    pero por porque que se si sin sobre su sus te tuvo un una uno y ya
  )

  defp quitar_stopwords(str) do
    tokens = String.split(str, ~r/[^a-z0-9áéíóúüñ]+/u, trim: true)

    filtrados =
      tokens
      |> Enum.reject(&(&1 in @stop_es))

    Enum.join(filtrados, " ")
  end

  defp expandir(reseñas, n) when n <= 1, do: reseñas
  defp expandir(reseñas, n), do: reseñas |> List.duplicate(n) |> List.flatten()
end

ResenasServidor.main()
