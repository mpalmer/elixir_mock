defmodule MockWatcher do
  use GenServer

  def start_link(mock_name) do
    watcher_name = get_watcher_name_for(mock_name)
    GenServer.start_link(__MODULE__, %{calls: []}, name: watcher_name)
  end

  def handle_call({:record_call, fn_name, args}, _from, state) do
    calls = state.calls ++ [{fn_name, args}]
    {:reply, :ok, %{state | calls: calls}}
  end

  def handle_call({:call_exists, fn_name, args}, _from, state) do
    call_exists = {fn_name, args} in state.calls
    {:reply, call_exists, state}
  end

  def get_watcher_name_for(mock_name) do
    :"__mockex__watcher_#{mock_name}"
  end
end