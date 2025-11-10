defmodule User do
  @enforce_keys [:email, :edad, :nombre]
  defstruct @enforce_keys
end

defmodule UsuariosCliente do
  @nodo_remoto :nodoservidor@servidor
  @servicio_remoto {:servicio_usuarios, @nodo_remoto}

  @usuarios_seed [
    %User{email: "ana@example.com", edad: 23, nombre: "Ana"},
    %User{email: "bruno@example", edad: 31, nombre: "Bruno"},
    %User{email: "cata@example.com", edad: -1, nombre: "Cata"},
    %User{email: "diego@example.com", edad: 0, nombre: ""},
    %User{email: "eva@example.com", edad: 42, nombre: "Eva"},
    %User{email: "felix@@example.com", edad: 19, nombre: "Felix"}
  ]

  def main do
    IO.puts("CLIENTE: conectando a #{@nodo_remoto} ...")

    case Node.connect(@nodo_remoto) do
      true ->
        IO.puts("CLIENTE: conectado. Enviando lote para validación...")
        send(@servicio_remoto, {:validar_lote, self(), @usuarios_seed, repeticiones: 500})
        esperar_resultado()

      false ->
        IO.puts("CLIENTE: no pudo conectar al nodo remoto")
    end
  end

  defp esperar_resultado do
    receive do
      {:resultado_usuarios,
       %{resultados: resultados, t_seq_ms: tseq, t_conc_ms: tconc, speedup: s}} ->
        ok_count =
          resultados
          |> Enum.count(fn {_email, status} -> status == :ok end)

        err_count = length(resultados) - ok_count

        IO.puts("\n=== RESUMEN ===")
        IO.puts("Usuarios válidos:   #{ok_count}")
        IO.puts("Usuarios con error: #{err_count}")

        IO.puts("\nMuestras (primeros 12 resultados):")

        resultados
        |> Enum.take(12)
        |> Enum.each(fn
          {email, :ok} ->
            IO.puts("  #{email}  -> :ok")

          {email, {:error, errs}} ->
            IO.puts("  #{email}  -> {:error, #{inspect(Enum.reverse(errs))}}")
        end)

        IO.puts("\nTiempo secuencial:  #{tseq} ms")
        IO.puts("Tiempo concurrente: #{tconc} ms")
        IO.puts("Speedup:            #{s}")
    after
      30_000 ->
        IO.puts("CLIENTE: timeout esperando resultado (30s)")
    end
  end
end

UsuariosCliente.main()
