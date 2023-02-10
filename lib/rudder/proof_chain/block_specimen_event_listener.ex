defmodule Rudder.ProofChain.BlockSpecimenEventListener do
  require Logger
  use GenServer

  @impl true
  def init(_) do
    start()
    {:ok, []}
  end

  @bsp_submitted_event_hash "0x57b0cb34d2ff9ed661f8b3c684aaee6cbf0bda5da02f4044205556817fa8e76c"
  @bsp_awarded_event_hash "0xf05ac779af1ec75a7b2fbe9415b33a67c00294a121786f7ce2eb3f92e4a6424a"

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start() do
    reregister_process()
    Logger.info("starting event listener")
    proofchain_address = Application.get_env(:rudder, :proofchain_address)
    push_bsps_to_process(Rudder.Journal.items_with_status(:discover))
    block_height = load_last_checked_block()
    listen_for_event(proofchain_address, block_height)
  end

  def reregister_process() do
    register_name = :bspec_listener

    case Process.whereis(register_name) do
      nil ->
        :ok

      _pid ->
        _ = Process.unregister(register_name)
        :ok
    end

    Process.register(self(), register_name)
  end

  def load_last_checked_block() do
    {:ok, block_height} = Rudder.Journal.last_started_block()

    if block_height == 1 do
      {:ok, block_height} = Rudder.Network.EthereumMainnet.eth_blockNumber()
      block_height
    else
      block_height
    end
  end

  defp extract_awarded_specimens([]), do: []

  defp extract_awarded_specimens(log_events) do
    Enum.reduce(log_events, [], fn log_event, keys ->
      {:ok, [_event_hash, chain_id_raw, block_height_raw, block_hash]} =
        Map.fetch(log_event, "topics")

      [specimen_hash_raw] = Rudder.Util.extract_data(log_event, "(bytes32)")

      # prepare data to generate key
      specimen_hash = Base.encode16(specimen_hash_raw, case: :lower)
      "0x" <> chain_id_raw = chain_id_raw
      "0x" <> block_height_raw = block_height_raw
      "0x" <> block_hash = block_hash
      {chain_id, _} = Integer.parse(chain_id_raw, 16)
      {block_height, _} = Integer.parse(block_height_raw, 16)

      key =
        to_string(chain_id) <>
          "_" <> to_string(block_height) <> "_" <> block_hash <> "_" <> specimen_hash

      [key | keys]
    end)
  end

  defp push_bsps_to_process(bsp_keys) do
    Enum.map(bsp_keys, fn bsp_key ->
      Rudder.Journal.discover(bsp_key)
      [_chain_id, block_height, _block_hash, specimen_hash] = String.split(bsp_key, "_")
      is_brp_sesion_open = Rudder.ProofChain.Interactor.is_block_result_session_open(block_height)

      if is_brp_sesion_open do
        specimen_hash_bytes32 = Rudder.Util.convert_to_bytes32(specimen_hash)
        bsp_urls = Rudder.ProofChain.Interactor.get_urls(specimen_hash_bytes32)
        Rudder.Pipeline.Spawner.push_hash(bsp_key, bsp_urls)
      else
        Rudder.Journal.skip(bsp_key)
      end
    end)
  end

  defp listen_for_event(proofchain_address, block_height) do
    Logger.info("listening for events at #{block_height}")
    Rudder.Journal.block_height_started(block_height)

    {:ok, bsp_awarded_logs} =
      Rudder.Network.EthereumMainnet.eth_getLogs([
        %{
          address: proofchain_address,
          fromBlock: block_height,
          toBlock: block_height,
          topics: [@bsp_awarded_event_hash]
        }
      ])

    bsps_to_process = extract_awarded_specimens(bsp_awarded_logs)
    Logger.info("found #{length(bsps_to_process)} bsps to process")
    push_bsps_to_process(bsps_to_process)
    Rudder.Journal.block_height_committed(block_height)

    next_block_height = block_height + 1
    loop(next_block_height)
    listen_for_event(proofchain_address, next_block_height)
  end

  defp loop(curr_block_height) do
    {:ok, latest_block_number} = Rudder.Network.EthereumMainnet.eth_blockNumber()
    Logger.info("curr_block: #{curr_block_height} and latest_block_num:#{latest_block_number}")

    if curr_block_height > latest_block_number do
      # ~12 seconds is mining time of one moonbeam block
      :timer.sleep(12_000)
      loop(curr_block_height)
    end
  end
end
