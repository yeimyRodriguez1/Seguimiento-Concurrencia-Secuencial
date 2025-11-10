defmodule Carrito do
  defstruct [:id, :items, :cupon]
end

defmodule Item do
  defstruct [:id, :nombre, :categoria, :precio, :qty, :dos_por_uno?]
end
