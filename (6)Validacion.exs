defmodule ValidadorUsuarios do
  @delay_min 3
  @delay_max 10

  @spec validar(%User{}) :: {String.t(), :ok | {:error, [atom()]}}
  def validar(%User{email: email, edad: edad, nombre: nombre}) do
    :timer.sleep(random_delay_ms())

    errores =
      []
      |> maybe_add_error(:email_invalido, not email_valido?(email))
      |> maybe_add_error(:edad_invalida, not edad_valida?(edad))
      |> maybe_add_error(:nombre_vacio, not nombre_valido?(nombre))

    if errores == [], do: {email, :ok}, else: {email, {:error, errores}}
  end

  def procesar_secuencial(usuarios) do
    Enum.map(usuarios, &validar/1)
  end

  def procesar_concurrente(usuarios) do
    usuarios
    |> Task.async_stream(&validar/1,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  def lista_usuarios do
    [
      %User{email: "ana@example.com", edad: 28, nombre: "Ana"},
      %User{email: "carlos_at_mail.com", edad: 33, nombre: "Carlos"},
      %User{email: "beatriz@example.com", edad: -1, nombre: "Bea"},
      %User{email: "diego@example.com", edad: 0, nombre: ""},
      %User{email: "luz@example.com", edad: 21, nombre: "Luz"},
      %User{email: "invalid.com", edad: 19, nombre: "Inv"},
      %User{email: "sofia@mail.org", edad: 55, nombre: "Sofia"},
      %User{email: "   ", edad: 40, nombre: "Blank"},
      %User{email: "felipe@example.com", edad: 36, nombre: "Felipe"},
      %User{email: "maria@example.com", edad: 27, nombre: "María"}
    ]
  end

  def iniciar do
    usuarios = lista_usuarios()

    {t1_us, out_seq} = :timer.tc(fn -> procesar_secuencial(usuarios) end)
    {t2_us, out_con} = :timer.tc(fn -> procesar_concurrente(usuarios) end)

    IO.puts("\n--- Resultados SECUNCIAL ---")
    imprimir_resumen(out_seq)

    IO.puts("\n--- Resultados CONCURRENTE ---")
    imprimir_resumen(out_con)

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

  defp maybe_add_error(list, _error, false), do: list
  defp maybe_add_error(list, error, true), do: [error | list]

  defp email_valido?(email) when is_binary(email) do
    String.contains?(email, "@") and String.trim(email) != ""
  end

  defp edad_valida?(edad) when is_integer(edad), do: edad >= 0
  defp edad_valida?(_), do: false

  defp nombre_valido?(nombre) when is_binary(nombre) do
    String.trim(nombre) != ""
  end

  defp nombre_valido?(_), do: false

  defp imprimir_resumen(resultados) do
    {oks, errs} =
      Enum.split_with(resultados, fn
        {_email, :ok} -> true
        _ -> false
      end)

    IO.puts("  OK: #{length(oks)}   Errores: #{length(errs)}")

    resultados
    |> Enum.take(10)
    |> Enum.each(fn
      {email, :ok} ->
        IO.puts("     #{email}")

      {email, {:error, motivos}} ->
        IO.puts("     #{email} -> #{Enum.join(Enum.map(motivos, &Atom.to_string/1), ", ")}")
    end)
  end
end

ValidadorUsuarios.iniciar()
