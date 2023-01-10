import "./index.css"
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount } from 'wagmi'

import { Account } from './components'

export function App() {
  const { isConnected } = useAccount()
  return (
    <>
      <h1 className="text-xl">absolutely mental poker</h1>

      <ConnectButton />
      {isConnected && <Account />}
    </>
  )
}
