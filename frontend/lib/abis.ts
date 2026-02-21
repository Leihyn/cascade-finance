// Minimal ABIs for frontend interaction

export const POSITION_MANAGER_ABI = [
  // Read functions
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "positions",
    outputs: [
      { name: "trader", type: "address" },
      { name: "isPayingFixed", type: "bool" },
      { name: "startTime", type: "uint40" },
      { name: "maturity", type: "uint40" },
      { name: "isActive", type: "bool" },
      { name: "notional", type: "uint128" },
      { name: "margin", type: "uint128" },
      { name: "fixedRate", type: "uint128" },
      { name: "accumulatedPnL", type: "int128" },
      { name: "lastSettlement", type: "uint40" },
      { name: "_reserved", type: "uint216" },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "ownerOf",
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "getMargin",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "nextPositionId",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalMargin",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "activePositionCount",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  // Write functions
  {
    inputs: [
      { name: "isPayingFixed", type: "bool" },
      { name: "notional", type: "uint128" },
      { name: "fixedRate", type: "uint128" },
      { name: "maturityDays", type: "uint256" },
      { name: "margin", type: "uint128" },
    ],
    name: "openPosition",
    outputs: [{ name: "positionId", type: "uint256" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { name: "positionId", type: "uint256" },
      { name: "amount", type: "uint128" },
    ],
    name: "addMargin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { name: "positionId", type: "uint256" },
      { name: "amount", type: "uint128" },
    ],
    name: "removeMargin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  // Events
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "positionId", type: "uint256" },
      { indexed: true, name: "trader", type: "address" },
      { indexed: false, name: "isPayingFixed", type: "bool" },
      { indexed: false, name: "notional", type: "uint256" },
      { indexed: false, name: "fixedRate", type: "uint256" },
      { indexed: false, name: "margin", type: "uint256" },
      { indexed: false, name: "maturity", type: "uint256" },
    ],
    name: "PositionOpened",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "positionId", type: "uint256" },
      { indexed: true, name: "trader", type: "address" },
      { indexed: false, name: "finalPnL", type: "int256" },
      { indexed: false, name: "marginReturned", type: "uint256" },
    ],
    name: "PositionClosed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "positionId", type: "uint256" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "newMargin", type: "uint256" },
    ],
    name: "MarginAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "positionId", type: "uint256" },
      { indexed: false, name: "settlementAmount", type: "int256" },
      { indexed: false, name: "newMargin", type: "int256" },
    ],
    name: "PositionSettled",
    type: "event",
  },
] as const;

export const SETTLEMENT_ENGINE_ABI = [
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "settle",
    outputs: [{ name: "settlementAmount", type: "int256" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "closeMaturedPosition",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "canSettle",
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "getPendingSettlement",
    outputs: [{ name: "", type: "int256" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

export const MARGIN_ENGINE_ABI = [
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "getHealthFactor",
    outputs: [{ name: "healthFactor", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "calculateMaintenanceMargin",
    outputs: [{ name: "requiredMargin", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "isLiquidatable",
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "positionId", type: "uint256" }],
    name: "getPositionLeverage",
    outputs: [{ name: "leverage", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

export const RATE_ORACLE_ABI = [
  {
    inputs: [],
    name: "getCurrentRate",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

export const ERC20_ABI = [
  {
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ name: "account", type: "address" }],
    name: "balanceOf",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    name: "allowance",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
    type: "function",
  },
] as const;
