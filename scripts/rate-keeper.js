/**
 * Rate Keeper Script
 * Fetches real rates from Lendle on Mantle and updates MockRateSource on Base Sepolia
 *
 * Usage: node scripts/rate-keeper.js
 */

const { createPublicClient, createWalletClient, http, parseAbi, formatUnits } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { mantle, baseSepolia } = require('viem/chains');

// Configuration
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const UPDATE_INTERVAL = 60 * 1000; // 1 minute

// Contract addresses
const LENDLE_POOL_MANTLE = '0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3';
const USDC_MANTLE = '0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9';
const MOCK_RATE_SOURCE_BASE_SEPOLIA = '0xDF93275848D010975439C8c0276B23b240FE4EeF';

// ABIs
const LENDLE_POOL_ABI = parseAbi([
  'function getReserveData(address asset) view returns (uint256 configuration, uint128 liquidityIndex, uint128 variableBorrowIndex, uint128 currentLiquidityRate, uint128 currentVariableBorrowRate, uint128 currentStableBorrowRate, uint40 lastUpdateTimestamp, address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress, address interestRateStrategyAddress, uint8 id)'
]);

const MOCK_RATE_SOURCE_ABI = parseAbi([
  'function setSupplyRate(uint256 rate) external',
  'function setBorrowRate(uint256 rate) external',
  'function setRates(uint256 supplyRate, uint256 borrowRate) external',
  'function supplyRate() view returns (uint256)',
  'function borrowRate() view returns (uint256)'
]);

// Clients
const mantleClient = createPublicClient({
  chain: mantle,
  transport: http('https://rpc.mantle.xyz'),
});

const baseSepoliaClient = createPublicClient({
  chain: baseSepolia,
  transport: http('https://sepolia.base.org'),
});

async function getWalletClient() {
  if (!PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY environment variable not set');
  }
  const account = privateKeyToAccount(PRIVATE_KEY.startsWith('0x') ? PRIVATE_KEY : `0x${PRIVATE_KEY}`);
  return createWalletClient({
    account,
    chain: baseSepolia,
    transport: http('https://sepolia.base.org'),
  });
}

async function fetchLendleRates() {
  try {
    const data = await mantleClient.readContract({
      address: LENDLE_POOL_MANTLE,
      abi: LENDLE_POOL_ABI,
      functionName: 'getReserveData',
      args: [USDC_MANTLE],
    });

    // Rates are in RAY (1e27), convert to WAD (1e18)
    const supplyRateRAY = data[3]; // currentLiquidityRate
    const borrowRateRAY = data[4]; // currentVariableBorrowRate

    const supplyRateWAD = (supplyRateRAY * BigInt(1e18)) / BigInt(1e27);
    const borrowRateWAD = (borrowRateRAY * BigInt(1e18)) / BigInt(1e27);

    return { supplyRateWAD, borrowRateWAD, supplyRateRAY, borrowRateRAY };
  } catch (error) {
    console.error('Error fetching Lendle rates:', error.message);
    return null;
  }
}

async function updateMockRateSource(supplyRate, borrowRate) {
  try {
    const walletClient = await getWalletClient();

    const hash = await walletClient.writeContract({
      address: MOCK_RATE_SOURCE_BASE_SEPOLIA,
      abi: MOCK_RATE_SOURCE_ABI,
      functionName: 'setRates',
      args: [supplyRate, borrowRate],
    });

    console.log(`Transaction sent: ${hash}`);

    const receipt = await baseSepoliaClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    return true;
  } catch (error) {
    console.error('Error updating rates:', error.message);
    return false;
  }
}

async function getCurrentMockRates() {
  const supplyRate = await baseSepoliaClient.readContract({
    address: MOCK_RATE_SOURCE_BASE_SEPOLIA,
    abi: MOCK_RATE_SOURCE_ABI,
    functionName: 'supplyRate',
  });

  const borrowRate = await baseSepoliaClient.readContract({
    address: MOCK_RATE_SOURCE_BASE_SEPOLIA,
    abi: MOCK_RATE_SOURCE_ABI,
    functionName: 'borrowRate',
  });

  return { supplyRate, borrowRate };
}

function formatRate(rateWAD) {
  return (Number(formatUnits(rateWAD, 18)) * 100).toFixed(4) + '%';
}

async function runOnce() {
  console.log('\n========================================');
  console.log('Fetching rates from Lendle on Mantle...');

  const lendleRates = await fetchLendleRates();
  if (!lendleRates) {
    console.log('Failed to fetch Lendle rates');
    return false;
  }

  console.log(`Lendle USDC Supply Rate: ${formatRate(lendleRates.supplyRateWAD)}`);
  console.log(`Lendle USDC Borrow Rate: ${formatRate(lendleRates.borrowRateWAD)}`);

  const currentRates = await getCurrentMockRates();
  console.log(`\nCurrent MockRateSource rates:`);
  console.log(`  Supply: ${formatRate(currentRates.supplyRate)}`);
  console.log(`  Borrow: ${formatRate(currentRates.borrowRate)}`);

  // Check if update needed (rates differ by more than 0.01%)
  const threshold = BigInt(1e14); // 0.01%
  const supplyDiff = lendleRates.supplyRateWAD > currentRates.supplyRate
    ? lendleRates.supplyRateWAD - currentRates.supplyRate
    : currentRates.supplyRate - lendleRates.supplyRateWAD;

  if (supplyDiff > threshold) {
    console.log('\nRates differ significantly. Updating...');
    await updateMockRateSource(lendleRates.supplyRateWAD, lendleRates.borrowRateWAD);
    console.log('Rates updated successfully!');
  } else {
    console.log('\nRates are already in sync. No update needed.');
  }

  return true;
}

async function runContinuous() {
  console.log('Starting Rate Keeper...');
  console.log(`Update interval: ${UPDATE_INTERVAL / 1000} seconds`);
  console.log('Press Ctrl+C to stop\n');

  while (true) {
    await runOnce();
    console.log(`\nNext update in ${UPDATE_INTERVAL / 1000} seconds...`);
    await new Promise(resolve => setTimeout(resolve, UPDATE_INTERVAL));
  }
}

// Main
const args = process.argv.slice(2);
if (args.includes('--once')) {
  runOnce().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
  });
} else {
  runContinuous().catch(console.error);
}
