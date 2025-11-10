defmodule Cocina do
  @num_ordenes 30

  def lista_ordenes(n \\ @num_ordenes) do
    items = [
      "Espresso",
      "Capuccino",
      "Latte",
      "Té verde",
      "Té negro",
      "Mocaccino",
      "Americano",
      "Chocolate",
      "Sandwich",
      "Croissant"
    ]

    tiempos = [120, 180, 250, 320, 400, 600, 800]

    1..n
    |> Enum.map(fn i ->
      %Orden{
        id: i,
        item: Enum.at(items, rem(i, length(items))),
        prep_ms: Enum.at(tiempos, rem(i * 7, length(tiempos)))
      }
    end)
  end

  def preparar(%Orden{id: id, item: item, prep_ms: ms}) do
    :timer.sleep(ms)
    ticket = "Ticket: Orden #{id} (#{item}) lista en #{ms} ms"
    IO.puts(ticket)
    {id, item, ms, ticket}
  end

  def preparar_secuencial(ordenes) do
    Enum.map(ordenes, &preparar/1)
  end

  def preparar_concurrente(ordenes) do
    ordenes
    |> Task.async_stream(&preparar/1,
      max_concurrency: System.schedulers_online(),
      ordered: true
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  def iniciar do
    ordenes = lista_ordenes()

    IO.puts("\n--- SECuencial ---")
    {t_seq_us, res_seq} = :timer.tc(fn -> preparar_secuencial(ordenes) end)

    IO.puts("\n--- CONcurrente ---")
    {t_con_us, res_con} = :timer.tc(fn -> preparar_concurrente(ordenes) end)

    t_seq_ms = Float.round(t_seq_us / 1000, 2)
    t_con_ms = Float.round(t_con_us / 1000, 2)
    speedup = if t_con_us == 0, do: :infinito, else: Float.round(t_seq_us / t_con_us, 2)

    IO.puts("\n--- RESUMEN ---")
    IO.puts("Órdenes:      #{length(ordenes)}")
    IO.puts("Secuencial:   #{t_seq_ms} ms")
    IO.puts("Concurrente:  #{t_con_ms} ms")
    IO.puts("Speedup:      x#{speedup}")

    %{secuencial: res_seq, concurrente: res_con}
  end
end

Cocina.iniciar()
