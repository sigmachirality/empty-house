import { getDefaultWallets } from '@rainbow-me/rainbowkit'
import { configureChains, createClient, mainnet } from 'wagmi'
import { goerli, hardhat } from 'wagmi/chains'
import { providers } from 'ethers'
import { publicProvider } from 'wagmi/providers/public'
import { jsonRpcProvider } from '@wagmi/core/providers/jsonRpc'

const { DEV } = import.meta.env;

const { chains, provider, webSocketProvider } = configureChains(
  // TODO: pull flag from .env and reconfigure this config object
  // [mainnet, ...(true ? [hardhat] : [])],
  [DEV ? hardhat : goerli],
  [
    // jsonRpcProvider({
    //   rpc: () => ({ http: `http://127.0.0.1:8545/` })
    // }),
    publicProvider(),
  ],
)

const { connectors } = getDefaultWallets({
  appName: 'Empty House',
  chains,
})

// TODO: FIX PROVIDERS!!!!!!!

export const client = createClient({
  autoConnect: true,
  connectors,
  provider: provider(hardhat as any),
  webSocketProvider,
})

export { chains }
