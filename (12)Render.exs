Code.require_file("tpl.ex", __DIR__)

defmodule RenderMiniPlantillas do

  @catalogo %{
    "bienvenida" => "Hola {{user}}, ¡bienvenid@! Tu plan: {{plan}}.",
    "saldo"      => "Hola {{user}}, tu saldo disponible es ${{saldo}}.",
    "record"     => "Hola {{user}}, tu mejor marca es {{marca}} en {{fecha}}.",
    "promo"      => "¡{{user}}! Usa el cupón {{cupon}} y ahorra {{porcentaje}}% hoy.",
    "aviso"      => "Estimad@ {{user}}, hay una actualización en {{seccion}}. Revísala."
  }

  # ---- Parámetros de costo (ms) ----
  # Costo base + costo por carácter del template final (aprox.)
  @base_ms  8
  @per_char 0.12

  @spec render(%Tpl{}) :: {any(), String.t()}
  def render(%Tpl{id: id, nombre: nombre, vars: vars}) do
    tpl = Map.fetch!(@catalogo, nombre)

    # Reemplazar {{clave}} por valor en vars (valores se convierten a string)
    html =
      Enum.reduce(vars || %{}, tpl, fn {k, v}, acc ->
        String.replace(acc, "{{#{k}}}", to_string(v))
      end)

    # Simular costo según tamaño final (redondeo a entero)
    :timer.sleep(round(@base_ms + @per_char * String.length(html)))

    {id, html}
  end

  # ---------------- Modos de ejecución ----------------

  def render_secuencial(lista) do
    Enum.map(lista, &render/1)
  end

  def render_concurrente(lista) do
    lista
    |> Task.async_stream(&render/1,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  # ---------------- Dataset de ejemplo ----------------

  def lista_tpls do
    [
      %Tpl{id: 1, nombre: "bienvenida", vars: %{"user" => "Ana", "plan" => "Premium"}},
      %Tpl{id: 2, nombre: "saldo",      vars: %{"user" => "Carlos", "saldo" => 25}},
      %Tpl{id: 3, nombre: "record",     vars: %{"user" => "Luz", "marca" => "00:57", "fecha" => "2025-11-07"}},
      %Tpl{id: 4, nombre: "promo",      vars: %{"user" => "Diego", "cupon" => "DESC20", "porcentaje" => 20}},
      %Tpl{id: 5, nombre: "aviso",      vars: %{"user" => "Sofía", "seccion" => "perfil"}}
    ]
  end

  # ---------------- Punto de entrada ----------------

  def iniciar do
    tpls = lista_tpls()

    {t1_us, out_seq} = :timer.tc(fn -> render_secuencial(tpls) end)
    IO.puts("\n--- SECUNCIAL ---")
    imprimir(out_seq)

    {t2_us, out_con} = :timer.tc(fn -> render_concurrente(tpls) end)
    IO.puts("\n--- CONCURRENTE ---")
    imprimir(out_con)

    speedup = t1_us / max(t2_us, 1)

    IO.puts("""
    \nMétricas:
      Secuencial:   #{div(t1_us, 1000)} ms
      Concurrente:  #{div(t2_us, 1000)} ms
      Speedup ≈     #{Float.round(speedup, 2)}x
    """)
  end

  # ---------------- Helpers ----------------

  defp imprimir(pares) do
    Enum.each(pares, fn {id, html} ->
      IO.puts("  #{id}: #{html}")
    end)
  end
end

# Ejecutar:
RenderMiniPlantillas.iniciar()
