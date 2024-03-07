import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
# config :contract_observer, ContractObserverWeb.Endpoint,
#   http: [port: 4000],
#   debug_errors: true,
#   code_reloader: true,
#   check_origin: false,
#   watchers: []

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Default these should point to moonbase alpha since we do all the development testing there
config :refiner,
  operator_private_key: System.get_env("BLOCK_RESULT_OPERATOR_PRIVATE_KEY"),
  bsp_proofchain_address: System.get_env("BSP_PROOFCHAIN_ADDRESS", "0x916B54696A70588a716F899bE1e8f2A5fFd5f135"),
  brp_proofchain_address: System.get_env("BRP_PROOFCHAIN_ADDRESS", "0xCBC44F143FB5baf26e45FB6C7A4fC13e6ca0fa09"),
  proofchain_chain_id: Integer.parse(System.get_env("PROOFCHAIN_CHAIN_ID", "1287")) |> elem(0),
  proofchain_node: System.get_env("NODE_ETHEREUM_MAINNET"),
  ipfs_pinner_url: System.get_env("IPFS_PINNER_URL"),
  evm_server_url: System.get_env("EVM_SERVER_URL")
