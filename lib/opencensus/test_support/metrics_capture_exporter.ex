defmodule Opencensus.TestSupport.MetricsCaptureExporter do
  @moduledoc """
    An `:oc_stat_exporter` to capture exported metrics. To wait for next exported data to be returned, call `capture_next`.
  """
  use GenServer
  @behaviour :oc_stat_exporter

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def capture_next do
    GenServer.call(__MODULE__, :capture_next)
  end

  @impl GenServer
  def init(_arg) do
    {:ok, [send_to: nil]}
  end

  @impl :oc_stat_exporter
  def export(view, _config) do
    GenServer.cast(__MODULE__, {:export, view})
  end

  @impl GenServer
  def handle_call(:capture_next, from, send_to: nil) do
    {:noreply, send_to: from}
  end

  @impl GenServer
  def handle_cast({:export, view}, send_to: pid) do
    unless pid == nil do
      GenServer.reply(pid, view)
    end

    {:noreply, send_to: nil}
  end
end
