defmodule Rudder.BlockResultUploaderTest do
  use ExUnit.Case, async: true

  setup_all do
    blockResultUploader = start_supervised!(Rudder.BlockResultUploader)
    iPFSInteractor = start_supervised!(Rudder.IPFSInteractor)

    %{blockResultUploader: blockResultUploader, iPFSInteractor: iPFSInteractor}
  end

  test "uploads block result to ipfs and sends the block result hash to proof chain", %{
    blockResultUploader: _blockResultUploader,
    iPFSInteractor: _iPFSInteractor
  } do
    expected_cid = "bafkreiehfggmf4y7xjzrqhvcvhto6eg44ipnsxuyxwwjytqvatvbn5eg4q"

    # tests would be started from project root rather than test/
    file_path = Path.expand(Path.absname(Path.relative_to_cwd("test-data/temp.txt")))

    expected_block_result_hash =
      <<135, 41, 140, 194, 243, 31, 186, 115, 24, 30, 162, 169, 230, 239, 16, 220, 226, 30, 217,
        94, 152, 189, 172, 156, 78, 21, 4, 234, 22, 244, 134, 228>>

    block_result_metadata = %Rudder.BlockResultMetadata{
      chain_id: 1,
      block_height: 1,
      block_specimen_hash: "525D191D6492F1E0928d4e816c29778c",
      file_path: file_path
    }

    {error, cid, block_result_hash} =
      Rudder.BlockResultUploader.upload_block_result(block_result_metadata)

    assert error == :ok
    assert cid == expected_cid
    assert block_result_hash == expected_block_result_hash
  end

  test "ipfs contains cid with known cid", %{
    iPFSInteractor: _iPFSInteractor,
    blockResultUploader: _blockResultUploader
  } do
    file_path = Path.expand(Path.absname(Path.relative_to_cwd("test-data/temp.txt")))
    {err, cid} = Rudder.IPFSInteractor.pin(file_path)
    expected_cid = "bafkreiehfggmf4y7xjzrqhvcvhto6eg44ipnsxuyxwwjytqvatvbn5eg4q"

    assert err == :ok
    assert cid == expected_cid
  end

  test "the server works", %{
    iPFSInteractor: _iPFSInteractor,
    blockResultUploader: _blockResultUploader
  } do
    port = Application.get_env(:rudder, :ipfs_pinner_port)

    {err, _} =
      Finch.build(:get, "http://localhost:#{port}/upload")
      |> Finch.request(Rudder.Finch)

    assert err != :error
  end
end
