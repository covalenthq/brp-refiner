defmodule Rudder.BlockResultUploaderTest do
  use ExUnit.Case, async: true

  setup_all do
    ipfs_node_process =
      Porcelain.spawn_shell(
        "sudo ./server  -port 3000 -jwt eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6ZXRocjoweGMxQkE4ODRFNzczMjBBODQ2NDk4QjI1RDZmNWI4NWU1YkRENDViMTYiLCJpc3MiOiJ3ZWIzLXN0b3JhZ2UiLCJpYXQiOjE2NjE4OTk5MzE3NTAsIm5hbWUiOiJyZWZpbmVyLWlwZnMtcGlubmVyIn0.aX1F8S-dIGFKLa4vjQv8FEH-z_T3AU5z5DNyBUKRLOA"
      )

    docker_compose_process =
      Porcelain.spawn_shell(
        "docker compose --env-file '.env' -f 'docker-compose-local.yml' up --remove-orphans"
      )

    # wait 20 seconds for ipfs and docker container to start
    :timer.sleep(20000)

    blockResultUploader = start_supervised!(Rudder.BlockResultUploader)
    iPFSInteractor = start_supervised!(Rudder.IPFSInteractor)

    on_exit(fn ->
      Porcelain.Process.stop(docker_compose_process)
      Porcelain.Process.stop(ipfs_node_process)
      Porcelain.Process.await(docker_compose_process)
      Porcelain.Process.await(ipfs_node_process)

      # sometimes stopping the ipfs process doesn't remove the lock, so we need to do it explicitly
      Porcelain.shell("sudo rm ~/.ipfs/repo.lock")
    end)

    %{blockResultUploader: blockResultUploader, iPFSInteractor: iPFSInteractor}
  end

  test "uploads block result to ipfs and sends the block result hash to proof chain", %{
    blockResultUploader: blockResultUploader,
    iPFSInteractor: iPFSInteractor
  } do
    expected_cid = "QmS21GuXiRMvJKHos4ZkEmQDmRBqRaF5tQS2CQCu2ne9sY"

    expected_block_result_hash =
      <<31, 26, 22, 170, 43, 54, 255, 231, 162, 119, 199, 183, 64, 168, 246, 27, 81, 121, 116,
        216, 76, 76, 0, 53, 139, 112, 13, 157, 133, 247, 226, 242>>

    {:ok, cid, block_result_hash} =
      Rudder.BlockResultUploader.upload_block_result(
        1,
        1,
        "525D191D6492F1E0928d4e816c29778c",
        "./test/test_file_to_upload.txt"
      )

    assert cid = expected_cid
    assert block_result_hash = expected_block_result_hash
  end
end