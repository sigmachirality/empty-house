import { getDefaultWallets } from '@rainbow-me/rainbowkit'
import { configureChains, createClient } from 'wagmi'
import { mainnet, hardhat } from 'wagmi/chains'
import { publicProvider } from 'wagmi/providers/public'

const { chains, provider, webSocketProvider } = configureChains(
  // TODO: pull this flag from .env
  // import.meta.env.VITE_DEV
  [mainnet, ...(true ? [hardhat] : [])],
  [
    publicProvider(),
  ],
)

const { connectors } = getDefaultWallets({
  appName: 'Empty House',
  chains,
})

export const client = createClient({
  autoConnect: true,
  connectors,
  provider,
  webSocketProvider,
})

export { chains }
