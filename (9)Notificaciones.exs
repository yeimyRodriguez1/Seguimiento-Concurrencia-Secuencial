defmodule EnvioNotificaciones do
  @costos %{
    email: 80,
    sms: 60,
    push: 40
  }

  @spec enviar(%Notif{}) :: :ok
  def enviar(%Notif{canal: canal, usuario: user}) do
    :timer.sleep(Map.get(@costos, canal, 50))
    IO.puts("Enviada a user #{user} (canal #{canal})")
    :ok
  end

  def lote_ejemplo do
    [
      %Notif{canal: :email, usuario: "ana@example.com", plantilla: "bienvenida"},
      %Notif{canal: :sms, usuario: "+57 3001112222", plantilla: "2FA"},
      %Notif{canal: :push, usuario: "uid_42", plantilla: "promo"},
      %Notif{canal: :email, usuario: "carlos@example.com", plantilla: "newsletter"},
      %Notif{canal: :sms, usuario: "+57 3112223333", plantilla: "alerta"},
      %Notif{canal: :push, usuario: "uid_77", plantilla: "recordatorio"}
    ]
  end

  def enviar_secuencial(notifs) do
    Enum.map(notifs, &enviar/1)
  end

  def enviar_concurrente(notifs) do
    notifs
    |> Task.async_stream(&enviar/1,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, :ok} -> :ok end)
  end

  def iniciar do
    notifs = lote_ejemplo()

    {t1_us, _} = :timer.tc(fn -> enviar_secuencial(notifs) end)
    IO.puts("\n--- Fin SECUNCIAL ---")

    {t2_us, _} = :timer.tc(fn -> enviar_concurrente(notifs) end)
    IO.puts("\n--- Fin CONCURRENTE ---")

    speedup = t1_us / max(t2_us, 1)

    IO.puts("""
    \nMétricas:
      Secuencial:   #{div(t1_us, 1000)} ms
      Concurrente:  #{div(t2_us, 1000)} ms
      Speedup ≈     #{Float.round(speedup, 2)}x
    """)
  end
end

EnvioNotificaciones.iniciar()
