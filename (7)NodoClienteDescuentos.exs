defmodule Item do
  @enforce_keys [:nombre, :categoria, :precio, :qty]
  defstruct @enforce_keys ++ [bogo?: false]
end

defmodule Carrito do
  @enforce_keys [:id, :items]
  defstruct @enforce_keys ++ [cupon: nil]
end

defmodule DescuentosCliente do
  @nodo_remoto :nodoservidor@servidor
  @servicio_remoto {:servicio_descuentos, @nodo_remoto}

  @carritos [
    %Carrito{
      id: 101,
      cupon: "SAVE10",
      items: [
        %Item{nombre: "Camiseta", categoria: :ropa, precio: 60.0, qty: 2},
        %Item{nombre: "Plancha", categoria: :hogar, precio: 80.0, qty: 1}
      ]
    },
    %Carrito{
      id: 102,
      cupon: nil,
      items: [
        %Item{nombre: "Audífonos", categoria: :electronica, precio: 120.0, qty: 1},
        %Item{nombre: "Refresco", categoria: :hogar, precio: 5.0, qty: 3, bogo?: true}
      ]
    },
    %Carrito{
      id: 103,
      cupon: "SAVE20",
      items: [
        %Item{nombre: "Jeans", categoria: :ropa, precio: 100.0, qty: 1},
        %Item{nombre: "Funda", categoria: :electronica, precio: 25.0, qty: 2, bogo?: true}
      ]
    },
    %Carrito{
      id: 104,
      cupon: nil,
      items: [
        %Item{nombre: "Toalla", categoria: :hogar, precio: 20.0, qty: 4, bogo?: true},
        %Item{nombre: "Gorra", categoria: :ropa, precio: 35.0, qty: 1}
      ]
    }
  ]

  def main do
    IO.puts("CLIENTE: conectando a #{@nodo_remoto} ...")

    case Node.connect(@nodo_remoto) do
      true ->
        IO.puts("CLIENTE: conectado. Enviando carritos...")

        send(@servicio_remoto, {:procesar, self(), @carritos, reps: 1})
        esperar_resultado()

      false ->
        IO.puts("CLIENTE: no pudo conectar al nodo remoto")
    end
  end

  defp esperar_resultado do
    receive do
      {:resultado_descuentos, %{ranking: ranking, t_seq_ms: tseq, t_conc_ms: tconc, speedup: s}} ->
        IO.puts("\n=== RESULTADOS DESCUENTOS ===")

        Enum.each(ranking, fn r ->
          IO.puts("#{r.pos}. Carrito #{r.id}  total_final=$#{r.total_final}")
        end)

        IO.puts("\nTiempo secuencial:  #{tseq} ms")
        IO.puts("Tiempo concurrente: #{tconc} ms")
        IO.puts("Speedup:            #{s}")
    after
      20_000 ->
        IO.puts("CLIENTE: timeout esperando resultado (20s)")
    end
  end
end

DescuentosCliente.main()
