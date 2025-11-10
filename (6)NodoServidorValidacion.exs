defmodule User do
  @enforce_keys [:email, :edad, :nombre]
  defstruct @enforce_keys
end

defmodule UsuariosServidor do
  @servicio :servicio_usuarios

  def main do
    IO.puts("SERVIDOR: servicio de validación de usuarios listo.")
    Process.register(self(), @servicio)
    loop()
  end

  defp loop do
    receive do
      {:validar_lote, remitente, usuarios, opts} ->
        repeticiones = Keyword.get(opts, :repeticiones, 1)
        lote = expandir(usuarios, repeticiones)

        {t_seq_us, _out_seq} = :timer.tc(fn -> validar_secuencial(lote) end)
        {t_conc_us, out_conc} = :timer.tc(fn -> validar_concurrente(lote) end)

        t_seq_ms = div(t_seq_us, 1000)
        t_conc_ms = div(t_conc_us, 1000)

        speedup =
          if t_conc_ms == 0, do: :infinito, else: Float.round(t_seq_ms / max(t_conc_ms, 1), 2)

        send(
          remitente,
          {:resultado_usuarios,
           %{
             resultados: out_conc,
             t_seq_ms: t_seq_ms,
             t_conc_ms: t_conc_ms,
             speedup: speedup
           }}
        )

        loop()
    end
  end

  defp validar_secuencial(usuarios) do
    Enum.map(usuarios, &validar/1)
  end

  defp validar_concurrente(usuarios) do
    parent = self()

    refs =
      for u <- usuarios do
        ref = make_ref()

        spawn(fn ->
          r = validar(u)
          send(parent, {:ok, ref, r})
        end)

        ref
      end

    recolectar(refs, [])
  end

  defp recolectar([], acc), do: Enum.reverse(acc)

  defp recolectar(refs, acc) do
    receive do
      {:ok, ref, r} ->
        recolectar(List.delete(refs, ref), [r | acc])
    end
  end

  defp validar(%User{email: email, edad: edad, nombre: nombre}) do
    :timer.sleep(Enum.random(3..10))

    errores =
      []
      |> maybe_add_error(!String.contains?(email, "@"), :email_invalido)
      |> maybe_add_error(!(is_integer(edad) and edad >= 0), :edad_invalida)
      |> maybe_add_error(String.trim(nombre) == "", :nombre_vacio)

    status = if errores == [], do: :ok, else: {:error, errores}
    {email, status}
  end

  defp maybe_add_error(lista, false, _), do: lista
  defp maybe_add_error(lista, true, err), do: [err | lista]

  defp expandir(usuarios, n) when n <= 1, do: usuarios
  defp expandir(usuarios, n), do: List.duplicate(usuarios, n) |> List.flatten()
end

UsuariosServidor.main()
