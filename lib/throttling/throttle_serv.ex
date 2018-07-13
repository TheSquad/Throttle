defmodule ThrottleServ do
  use GenServer
  use AMQP

  require Logger

  @retry_timer 2_000
  @exchange "my_exchange"
  @queue "my_queue"
  @queue "#{@queue}_error"
  @mps 1
  @timeout 100

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{channel: nil, dets: nil}, 0}
  end

  def handle_call(p, _f, s) do
    {:reply, :ok, s}
  end

  def handle_cast(p, s) do
    {:noreply, s}
  end

  def handle_info(:timeout, %{channel: nil} = s) do
    case AMQP.Connection.open do
      {:ok, amqp} ->
        dets = Throttling.Application.get_queue()
        {:ok, chan} = Channel.open(amqp)
        setup_queue(chan)
        Logger.info("Connected to RMQ Channel: #{inspect chan}\n- dets ref: #{inspect dets}")

        {:noreply, %{s | channel: chan, dets: dets}, @timeout}
      {:error, :econnrefused} ->
        Logger.warn("Unable to connect to RMQ, try in #{@retry_timer}")
        {:noreply, s, @retry_timer}
    end
  end
  def handle_info(:timeout, %{channel: chan, dets: dets} = s) do
    case :dets.lookup(dets, :queue) do
      [] ->
        :ok
      [{:queue, {[], []}}] ->
        :ok
      [{:queue, q}] ->
        Logger.info("Sending message... #{inspect q}")
        message = :queue.get(q)
        Logger.info("Sending message to RMQ")
        AMQP.Basic.publish chan, @exchange, "", to_string(message)
        :dets.insert(dets, {:queue, :queue.drop(q)})
    end
    {:noreply, s, @timeout}
  end

  def handle_info(p, s) do
    {:noreply, s}
  end

  def terminate(reason, s) do
    :normal
  end

  def setup_queue(chan) do
    AMQP.Queue.declare chan, @queue
    AMQP.Exchange.declare chan, @exchange
    AMQP.Queue.bind chan, @queue, @exchange
  end
end
