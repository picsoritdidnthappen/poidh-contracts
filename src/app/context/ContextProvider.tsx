'use client'
import React, { ReactNode, useEffect } from 'react';
import {
  DynamicContextProvider,
  useDynamicContext,
} from "@dynamic-labs/sdk-react-core";
import { EthereumWalletConnectors } from "@dynamic-labs/ethereum";





interface ContextProviderProps {
  children: ReactNode;
}



 

const ContextProvider: React.FC<ContextProviderProps> = ({ children }) => {

 

 // Initialization effect for network switching
//  useEffect(() => {
//   const switchNetwork = async () => {
//     const { walletConnector } = useDynamicContext();
//     if (walletConnector && await walletConnector.supportsNetworkSwitching()) {
//       try {
//         await walletConnector.switchNetwork({ networkChainId: 5 });
//         console.log("Success! Network switched");
//       } catch (error) {
//         console.error("Failed to switch network", error);
//       }
//     }
//   };

//   switchNetwork();
// }, []);
 
// Setting up list of evmNetworks
const evmNetworks = [
  {
    blockExplorerUrls: ['https://etherscan.io/'],
    chainId: 1,
    chainName: 'Ethereum Mainnet',
    iconUrls: ['https://app.dynamic.xyz/assets/networks/eth.svg'],
    name: 'Ethereum',
    nativeCurrency: {
      decimals: 18,
      name: 'Ether',
      symbol: 'ETH',
    },
    networkId: 1,
    
    rpcUrls: ['https://mainnet.infura.io/v3/'],
    vanityName: 'ETH Mainnet',
  },
{
    blockExplorerUrls: ['https://etherscan.io/'],
    chainId: 5,
    chainName: 'Ethereum Goerli',
    iconUrls: ['https://app.dynamic.xyz/assets/networks/eth.svg'],
    name: 'Ethereum',
    nativeCurrency: {
      decimals: 18,
      name: 'Ether',
      symbol: 'ETH',
    },
    networkId: 5,
    rpcUrls: ['https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161'],
    
    vanityName: 'Goerli',
  },
  {
    blockExplorerUrls: ['https://polygonscan.com/'],
    chainId: 137,
    chainName: 'Matic Mainnet',
    iconUrls: ["https://app.dynamic.xyz/assets/networks/polygon.svg"],
    name: 'Polygon',
    nativeCurrency: {
      decimals: 18,
      name: 'MATIC',
      symbol: 'MATIC',
    },
    networkId: 137,
    rpcUrls: ['https://polygon-rpc.com'],    
    vanityName: 'Polygon',
  },
];





  return (
    <DynamicContextProvider 
      settings={{ 
        environmentId: '622731b3-a151-4656-8b08-de858d71d397',
        walletConnectors: [ EthereumWalletConnectors],
        networkValidationMode: "always",
        



      }}
      

      > 
      {children}
    </DynamicContextProvider> 
  );
};

export default ContextProvider;
