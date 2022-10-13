defmodule Rudder.BlockResultUploader do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    {:ok, []}
  end

  @impl true
  def handle_call(
        {:upload_block_result, {chain_id, block_height, block_specimen_hash, file_path}},
        _from,
        state
      ) do
    {:ok, cid} = Rudder.IPFSInteractor.pin(file_path)
    block_result_hash = hash_block_result_file(file_path)

    :ok =
      Rudder.ProofChain.Interactor.submit_block_result_proof(
        chain_id,
        block_height,
        block_specimen_hash,
        block_result_hash,
        cid
      )

    {:reply, {:ok, cid, block_result_hash}, state}
  end

  def upload_block_result(chain_id, block_height, block_specimen_hash, file_path) do
    GenServer.call(
      Rudder.BlockResultUploader,
      {:upload_block_result, {chain_id, block_height, block_specimen_hash, file_path}}
    )
  end

  defp hash_block_result_file(file_path) do
    hash_ref = :crypto.hash_init(:sha256)

    File.stream!(file_path)
    |> Enum.reduce(hash_ref, fn chunk, prev_ref ->
      new_ref = :crypto.hash_update(prev_ref, chunk)
      new_ref
    end)
    |> :crypto.hash_final()
  end
end