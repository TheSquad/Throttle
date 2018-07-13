defmodule Throttling.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    :ets.new(:my_dets, [:set, :public, :named_table])
    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Throttling.Worker.start_link(arg1, arg2, arg3)
      worker(ThrottleServ, []),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Throttling.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp create_queue(q, 0), do: q
  defp create_queue(q, n) do
    create_queue(:queue.in(Randomizer.randomizer(:random.uniform * 100 |> trunc()), q), n-1)
  end
  def create_message(n) do
    dets = get_queue()
    queue = create_queue(:queue.new, n)
    :dets.insert(dets, {:queue, queue})
  end

  def get_queue() do
    case :ets.lookup(:my_dets, :ref) do
      [] ->
        Logger.warn "Dets doesn't exist anymore creating it..."
        {:ok, dets_ref} = :dets.open_file("Testing.db", auto_save: 100)
        :ets.insert(:my_dets, {:ref, dets_ref})
        dets_ref
      [{:ref, dets_ref}] ->
        dets_ref
    end
  end

end
