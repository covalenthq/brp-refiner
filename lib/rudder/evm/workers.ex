defmodule Rudder.BlockProcessor.Worker do
  require Logger
  alias Rudder.BlockProcessor.Struct
  alias Rudder.BlockProcessor.Worker
  alias Rudder.Events

  defmodule WorkerSupervisor do
    use Supervisor

    def start_link(args) do
      Supervisor.start_link(__MODULE__, args)
    end

    @impl true
    def init({inp = %Struct.InputParams{}, evm = %Struct.EVMParams{}}) do
      block_id = inp.block_id
      executor_id = block_id <> "_executor"

      children = [
        %{
          id: executor_id,
          start: {Worker.Executor, :start_link, [inp, evm]},
          type: :worker,
          restart: :transient
        }
      ]

      Supervisor.init(children, strategy: :one_for_one, max_restarts: 3, max_seconds: 10)
    end
  end

  defmodule Executor do
    def start_link(%Struct.InputParams{} = inp, %Struct.EVMParams{} = evm) do
      pid = spawn_link(__MODULE__, :execute, [inp, evm])
      {:ok, pid}
    end

    def execute(%Struct.InputParams{} = inp, %Struct.EVMParams{} = evm) do
      start_execute_ms = System.monotonic_time(:millisecond)
      {handler, output_path} = process_handler(inp.block_id, evm)

      case handler do
        {:error, reason} ->
          # log self too
          Logger.error("failed: " <> reason)
          Process.exit(self(), "process spawn failed: " <> reason)

        msg ->
          Logger.info("porcelain message: #{inspect(msg)}")
      end

      Porcelain.Process.send_input(handler, inp.contents)

      case Porcelain.Process.await(handler, 60_000) do
        {:ok, result} ->
          handle_result(
            inp.sender,
            adapt_result(result.status, inp.block_id, output_path, inp.misc)
          )

        {:error, :timeout} ->
          Logger.error("log timeout here")
          raise "oops timeout"

        {:error, :noproc} ->
          Logger.error("plugin not processed")
          raise "oops unexecutable"
      end

      Events.bsp_execute(System.monotonic_time(:millisecond) - start_execute_ms)
      Porcelain.Process.stop(handler)
    end

    defp adapt_result(0, block_id, output_path, misc),
      do: %Struct.ExecResult{
        block_id: block_id,
        status: :success,
        output_path: output_path,
        misc: misc
      }

    defp adapt_result(_, block_id, _, misc),
      do: %Struct.ExecResult{block_id: block_id, status: :failure, misc: misc}

    defp handle_result(sender, %Struct.ExecResult{} = res) do
      send(sender, res)
    end

    defp process_handler(block_id, %Struct.EVMParams{} = evm) do
      output_file = block_id <> "-result.json"
      result_path = Path.join(Path.expand(evm.output_basedir), output_file)

      {Porcelain.spawn(
         Path.expand(evm.evm_exec_path),
         [
           "t8n",
           "--input.replica",
           evm.input_replica_path,
           "--output.basedir",
           evm.output_basedir,
           "--output.blockresult",
           output_file,
           "--output.body",
           "stdout",
           "--output.alloc",
           "stdout",
           "--output.result",
           "stdout"
         ],
         in: :receive
       ), result_path}
    end
  end
end
