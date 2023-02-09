defmodule Rudder.BlockProcessor.Struct do
  require System

  defmodule PoolState do
    defstruct [:request_queue, workers_limit: 10]
  end

  defmodule InputParams do
    @enforce_keys [:block_id]
    defstruct [:block_id, :contents, :sender, :misc]
  end

  defmodule EVMParams do
    alias Rudder.BlockProcessor.Struct.EVMParams
    @default_output_dir "./evm-out"
    @default_evm_url "http://127.0.0.1/3002"
    defstruct evm_server_url: @default_evm_url,
              output_basedir: @default_output_dir

    @spec new :: %Rudder.BlockProcessor.Struct.EVMParams{
            evm_exec_path: any,
            input_replica_path: <<_::40>>,
            output_basedir: <<_::72>>
          }
    def new() do
      evm_server_url = Application.get_env(:rudder, :evm_server_url)

      evm_server_url =
        if evm_server_url != nil do
          evm_server_url
        else
          @default_evm_url
        end

      %EVMParams{evm_server_url: evm_server_url}
    end
  end

  defmodule ExecResult do
    defstruct [:status, :block_id, :output_path, :misc]
  end
end
