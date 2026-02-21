import { http, createConfig } from "wagmi";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";

// Flow EVM Testnet
const flowTestnet = {
  id: 545,
  name: "Flow EVM Testnet",
  network: "flow-testnet",
  nativeCurrency: {
    decimals: 18,
    name: "FLOW",
    symbol: "FLOW",
  },
  rpcUrls: {
    default: { http: ["https://testnet.evm.nodes.onflow.org"] },
    public: { http: ["https://testnet.evm.nodes.onflow.org"] },
  },
  blockExplorers: {
    default: { name: "FlowScan", url: "https://evm-testnet.flowscan.io" },
  },
  testnet: true,
};

// Flow EVM Mainnet
const flowMainnet = {
  id: 747,
  name: "Flow EVM",
  network: "flow",
  nativeCurrency: {
    decimals: 18,
    name: "FLOW",
    symbol: "FLOW",
  },
  rpcUrls: {
    default: { http: ["https://mainnet.evm.nodes.onflow.org"] },
    public: { http: ["https://mainnet.evm.nodes.onflow.org"] },
  },
  blockExplorers: {
    default: { name: "FlowScan", url: "https://evm.flowscan.io" },
  },
  testnet: false,
};

export const config = getDefaultConfig({
  appName: "Cascade Finance",
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_ID || "demo",
  chains: [flowTestnet, flowMainnet],
  transports: {
    [flowTestnet.id]: http(),
    [flowMainnet.id]: http(),
  },
  ssr: true,
});

// Contract addresses per chain
export interface FullStackContracts {
  // Tokens
  usdc: `0x${string}`;
  wflow: `0x${string}`;
  // Lending SDK
  comet: `0x${string}`;
  cometFactory: `0x${string}`;
  rateModel: `0x${string}`;
  // DEX SDK
  swapFactory: `0x${string}`;
  swapRouter: `0x${string}`;
  // Cascade IRS
  positionManager: `0x${string}`;
  settlementEngine: `0x${string}`;
  marginEngine: `0x${string}`;
  liquidationEngine: `0x${string}`;
  rateOracle: `0x${string}`;
  rateAdapter: `0x${string}`;
}

export const CONTRACT_ADDRESSES: Record<number, FullStackContracts> = {
  // Flow EVM Testnet - Deployed
  [flowTestnet.id]: {
    // Tokens
    usdc: "0x2C5Bedd15f3d40Da729A68D852E4f436dA14ef79",
    wflow: "0x83388045cab4caDc82ACfa99a63b17E6d4E5Cc87",
    // Lending SDK
    comet: "0x15880a9E1719AAd5a37C99203c51C2E445651c94",
    cometFactory: "0xb4A47F5D656C177be6cF4839551217f44cbb2Cb5",
    rateModel: "0xcC86944f5E7385cA6Df8EEC5d40957840cfdfbb2",
    // DEX SDK
    swapFactory: "0x2716c3E427B33c78d01e06a5Ba19A673EB5d898b",
    swapRouter: "0x824d335886E8c516a121E2df59104F04cABAe30b",
    // Cascade IRS
    positionManager: "0x4A8705C1a7949F51DB589fA616f6f5c7ECf986e6",
    settlementEngine: "0x29Be033fC3bDa9cbfc623848AEf7d38Cd6113d84",
    marginEngine: "0x8061CCD94E4E233BDc602A46aB43681c6026Fee0",
    liquidationEngine: "0x39618E21B20c18B54d9656d90Db7C4835Eb38b68",
    rateOracle: "0x914664B39D8DF72601086ebf903b741907d9cCD0",
    rateAdapter: "0xff0D1Ef082Aabe9bb00DC3e599bcc7d885C683fe",
  },
  // Flow EVM Mainnet - TO BE DEPLOYED
  [flowMainnet.id]: {
    usdc: "0x0000000000000000000000000000000000000000",
    wflow: "0x0000000000000000000000000000000000000000",
    comet: "0x0000000000000000000000000000000000000000",
    cometFactory: "0x0000000000000000000000000000000000000000",
    rateModel: "0x0000000000000000000000000000000000000000",
    swapFactory: "0x0000000000000000000000000000000000000000",
    swapRouter: "0x0000000000000000000000000000000000000000",
    positionManager: "0x0000000000000000000000000000000000000000",
    settlementEngine: "0x0000000000000000000000000000000000000000",
    marginEngine: "0x0000000000000000000000000000000000000000",
    liquidationEngine: "0x0000000000000000000000000000000000000000",
    rateOracle: "0x0000000000000000000000000000000000000000",
    rateAdapter: "0x0000000000000000000000000000000000000000",
  },
};
