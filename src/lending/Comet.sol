// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CometStorage.sol";
import "./interfaces/IComet.sol";

/// @title Comet
/// @notice Compound V3 style single-asset lending pool
/// @dev Supplies earn interest, borrows pay interest, collateral enables borrowing
contract Comet is CometStorage, IComet, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        PHASE 1 SECURITY CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum staleness for price data (1 hour)
    /// @dev From Leihyn/knowledge/defi/chainlink/integration-guide.md
    uint256 public constant MAX_PRICE_STALENESS = 1 hours;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error Unauthorized();
    error InvalidAsset();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientCollateral();
    error NotLiquidatable();
    error BorrowTooSmall();
    error SupplyCapExceeded();
    error AlreadyInitialized();
    error ZeroAddress();

    // Phase 1 Security: Oracle validation errors
    error OracleNotConfigured();
    error StalePriceData(address asset, uint256 lastUpdate);
    error InvalidPriceData(address asset);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address baseToken_,
        uint8 baseTokenDecimals_,
        address rateModel_,
        uint64 reserveFactorMantissa_,
        address governor_
    ) CometStorage(baseToken_, baseTokenDecimals_, rateModel_, reserveFactorMantissa_) {
        if (governor_ == address(0)) revert ZeroAddress();
        governor = governor_;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a collateral asset
    /// @param config The asset configuration
    function addAsset(AssetConfig calldata config) external onlyGovernor {
        if (config.asset == address(0)) revert ZeroAddress();
        if (_isCollateralAsset[config.asset]) revert AlreadyInitialized();

        _assetIndex[config.asset] = uint8(_assetConfigs.length);
        _assetConfigs.push(config);
        _isCollateralAsset[config.asset] = true;
    }

    /// @notice Pause/unpause the protocol
    function setPaused(bool paused_) external onlyGovernor {
        paused = paused_;
    }

    /// @notice Set the price oracle (FIX C-03)
    /// @param oracle_ Address of the price oracle contract
    function setPriceOracle(address oracle_) external onlyGovernor {
        priceOracle = IPriceOracle(oracle_);
    }

    /*//////////////////////////////////////////////////////////////
                          SUPPLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComet
    function supply(address asset, uint256 amount) external override {
        supplyTo(msg.sender, asset, amount);
    }

    /// @inheritdoc IComet
    function supplyTo(address dst, address asset, uint256 amount) public override nonReentrant whenNotPaused {
        if (asset != baseToken) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();

        accrueInterest();

        // Transfer tokens in
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), amount);

        // Update user's principal
        UserBasic storage userInfo = _userBasic[dst];
        int104 principalNew = userInfo.principal + _safe104(int256(amount));
        userInfo.principal = principalNew;

        // Update totals
        _totalSupplyBase += uint104(amount);

        emit Supply(msg.sender, dst, amount);
    }

    /// @inheritdoc IComet
    function withdraw(address asset, uint256 amount) external override {
        withdrawTo(msg.sender, asset, amount);
    }

    /// @inheritdoc IComet
    function withdrawTo(address to, address asset, uint256 amount) public override nonReentrant whenNotPaused {
        if (asset != baseToken) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();

        accrueInterest();

        UserBasic storage userInfo = _userBasic[msg.sender];
        int104 principal = userInfo.principal;

        // Calculate new principal after withdrawal
        int104 principalNew = principal - _safe104(int256(amount));

        // If resulting in a borrow (negative principal)
        if (principalNew < 0) {
            // Check collateral sufficiency for borrow
            if (!_isBorrowCollateralized(msg.sender, -principalNew)) {
                revert InsufficientCollateral();
            }
            // Update borrow totals
            uint104 newBorrow = uint104(int104(-principalNew));
            uint104 oldBorrow = principal < 0 ? uint104(int104(-principal)) : 0;
            _totalBorrowBase += newBorrow - oldBorrow;
            if (principal > 0) {
                _totalSupplyBase -= uint104(int104(principal));
            }
        } else {
            // Pure withdrawal from supply
            uint256 balance = _presentValue(principal);
            if (balance < amount) revert InsufficientBalance();
            _totalSupplyBase -= uint104(amount);
        }

        userInfo.principal = principalNew;

        // Transfer tokens out
        IERC20(baseToken).safeTransfer(to, amount);

        emit Withdraw(msg.sender, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComet
    function supplyCollateral(address asset, uint256 amount) external override nonReentrant whenNotPaused {
        if (!_isCollateralAsset[asset]) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();

        AssetConfig memory config = _assetConfigs[_assetIndex[asset]];
        if (_totalCollateral[asset] + amount > config.supplyCap) revert SupplyCapExceeded();

        // Transfer tokens in
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Update balances
        _userCollateral[msg.sender][asset] += uint128(amount);
        _totalCollateral[asset] += amount;

        emit SupplyCollateral(msg.sender, msg.sender, asset, amount);
    }

    /// @inheritdoc IComet
    function withdrawCollateral(address asset, uint256 amount) external override nonReentrant whenNotPaused {
        if (!_isCollateralAsset[asset]) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();

        uint128 collateral = _userCollateral[msg.sender][asset];
        if (collateral < amount) revert InsufficientBalance();

        accrueInterest();

        // Update balances (check collateral after)
        _userCollateral[msg.sender][asset] = collateral - uint128(amount);
        _totalCollateral[asset] -= amount;

        // Check if still solvent after withdrawal
        UserBasic memory userInfo = _userBasic[msg.sender];
        if (userInfo.principal < 0) {
            if (!_isBorrowCollateralized(msg.sender, -userInfo.principal)) {
                revert InsufficientCollateral();
            }
        }

        // Transfer tokens out
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit WithdrawCollateral(msg.sender, msg.sender, asset, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComet
    function absorb(address absorber, address[] calldata accounts) external override nonReentrant whenNotPaused {
        accrueInterest();

        for (uint256 i = 0; i < accounts.length; i++) {
            _absorbInternal(absorber, accounts[i]);
        }
    }

    function _absorbInternal(address absorber, address borrower) internal {
        if (!isLiquidatable(borrower)) revert NotLiquidatable();

        UserBasic storage borrowerInfo = _userBasic[borrower];
        int104 principal = borrowerInfo.principal;

        if (principal >= 0) revert NotLiquidatable();

        uint104 borrowAmount = uint104(-principal);
        uint256 collateralValue = _getCollateralValue(borrower);

        // Seize all collateral
        for (uint8 i = 0; i < _assetConfigs.length; i++) {
            address asset = _assetConfigs[i].asset;
            uint128 collateral = _userCollateral[borrower][asset];
            if (collateral > 0) {
                _userCollateral[borrower][asset] = 0;
                _userCollateral[absorber][asset] += collateral;
            }
        }

        // Clear the borrower's debt
        borrowerInfo.principal = 0;
        _totalBorrowBase -= borrowAmount;

        // Protocol takes the loss if collateral < debt
        if (collateralValue < borrowAmount) {
            uint104 loss = uint104(borrowAmount - collateralValue);
            if (_totalReserves >= loss) {
                _totalReserves -= loss;
            }
        }

        emit Absorb(absorber, borrower, borrowAmount, collateralValue);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEREST ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComet
    function accrueInterest() public override {
        uint64 now_ = uint64(block.timestamp);
        uint64 timeElapsed = now_ - _lastAccrualTime;

        if (timeElapsed == 0) return;

        uint256 cash = IERC20(baseToken).balanceOf(address(this));
        uint256 borrows = _totalBorrowBase;
        uint256 reserves = _totalReserves;

        // Get current rates
        uint256 borrowRate = rateModel.getBorrowRate(cash, borrows, reserves);
        uint256 supplyRate = rateModel.getSupplyRate(cash, borrows, reserves, reserveFactorMantissa);

        // Calculate interest factors
        uint256 borrowIndexNew = uint256(_baseBorrowIndex) + (uint256(_baseBorrowIndex) * borrowRate * timeElapsed) / FACTOR_SCALE;
        uint256 supplyIndexNew = uint256(_baseSupplyIndex) + (uint256(_baseSupplyIndex) * supplyRate * timeElapsed) / FACTOR_SCALE;

        // Calculate reserve increase
        uint256 interestAccumulated = (borrows * borrowRate * timeElapsed) / FACTOR_SCALE;
        uint256 reserveIncrease = (interestAccumulated * reserveFactorMantissa) / FACTOR_SCALE;

        // Update state
        _baseBorrowIndex = uint64(borrowIndexNew);
        _baseSupplyIndex = uint64(supplyIndexNew);
        _totalReserves += uint104(reserveIncrease);
        _lastAccrualTime = now_;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComet
    function totalSupply() external view override returns (uint256) {
        return _totalSupplyBase;
    }

    /// @inheritdoc IComet
    function totalBorrow() external view override returns (uint256) {
        return _totalBorrowBase;
    }

    /// @inheritdoc IComet
    function userBasic(address account) external view override returns (UserBasic memory) {
        return _userBasic[account];
    }

    /// @inheritdoc IComet
    function userCollateral(address account, address asset) external view override returns (uint128) {
        return _userCollateral[account][asset];
    }

    /// @inheritdoc IComet
    function getSupplyRate() external view override returns (uint64) {
        uint256 cash = IERC20(baseToken).balanceOf(address(this));
        return uint64(rateModel.getSupplyRate(cash, _totalBorrowBase, _totalReserves, reserveFactorMantissa));
    }

    /// @inheritdoc IComet
    function getBorrowRate() external view override returns (uint64) {
        uint256 cash = IERC20(baseToken).balanceOf(address(this));
        return uint64(rateModel.getBorrowRate(cash, _totalBorrowBase, _totalReserves));
    }

    /// @inheritdoc IComet
    function getUtilization() external view override returns (uint256) {
        uint256 cash = IERC20(baseToken).balanceOf(address(this));
        return rateModel.utilizationRate(cash, _totalBorrowBase, _totalReserves);
    }

    /// @inheritdoc IComet
    function balanceOf(address account) external view override returns (uint256) {
        int104 principal = _userBasic[account].principal;
        if (principal <= 0) return 0;
        return _presentValue(principal);
    }

    /// @inheritdoc IComet
    function borrowBalanceOf(address account) external view override returns (uint256) {
        int104 principal = _userBasic[account].principal;
        if (principal >= 0) return 0;
        return _presentValueBorrow(uint104(int104(-principal)));
    }

    /// @inheritdoc IComet
    function isLiquidatable(address account) public view override returns (bool) {
        UserBasic memory userBasic_ = _userBasic[account];
        if (userBasic_.principal >= 0) return false;

        uint256 borrowValue = _presentValueBorrow(uint104(-userBasic_.principal));
        uint256 collateralValue = _getLiquidationCollateralValue(account);

        return borrowValue > collateralValue;
    }

    /// @inheritdoc IComet
    function numAssets() external view override returns (uint8) {
        return uint8(_assetConfigs.length);
    }

    /// @inheritdoc IComet
    function getAssetInfo(uint8 i) external view override returns (AssetConfig memory) {
        return _assetConfigs[i];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _presentValue(int104 principal) internal view returns (uint256) {
        if (principal >= 0) {
            return (uint256(uint104(principal)) * _baseSupplyIndex) / FACTOR_SCALE;
        } else {
            return (uint256(uint104(-principal)) * _baseBorrowIndex) / FACTOR_SCALE;
        }
    }

    function _presentValueBorrow(uint104 principal) internal view returns (uint256) {
        return (uint256(principal) * _baseBorrowIndex) / FACTOR_SCALE;
    }

    function _isBorrowCollateralized(address account, int104 borrowPrincipal) internal view returns (bool) {
        if (borrowPrincipal <= 0) return true;

        uint256 borrowValue = _presentValueBorrow(uint104(borrowPrincipal));
        uint256 collateralValue = _getBorrowCollateralValue(account);

        return collateralValue >= borrowValue;
    }

    function _getCollateralValue(address account) internal view returns (uint256) {
        uint256 totalValue = 0;
        uint256 length = _assetConfigs.length;

        for (uint256 i = 0; i < length;) {
            AssetConfig memory config = _assetConfigs[i];
            uint128 collateral = _userCollateral[account][config.asset];
            if (collateral > 0) {
                // Phase 1 Security: Use validated price - NO FALLBACK
                uint256 price = _getValidatedPrice(config.asset);
                // FIX: Scale to base token decimals for proper comparison
                uint256 value = _scaleCollateralToBase(config.asset, collateral, price);
                totalValue += value;
            }
            unchecked { ++i; }
        }
        return totalValue;
    }

    function _getBorrowCollateralValue(address account) internal view returns (uint256) {
        uint256 totalValue = 0;
        uint256 length = _assetConfigs.length;

        for (uint256 i = 0; i < length;) {
            AssetConfig memory config = _assetConfigs[i];
            uint128 collateral = _userCollateral[account][config.asset];
            if (collateral > 0) {
                // Phase 1 Security: Use validated price - NO FALLBACK
                uint256 price = _getValidatedPrice(config.asset);
                // FIX: Scale to base token decimals for proper comparison
                uint256 valueInBase = _scaleCollateralToBase(config.asset, collateral, price);
                uint256 value = (valueInBase * config.borrowCollateralFactor) / FACTOR_SCALE;
                totalValue += value;
            }
            unchecked { ++i; }
        }
        return totalValue;
    }

    function _getLiquidationCollateralValue(address account) internal view returns (uint256) {
        uint256 totalValue = 0;
        uint256 length = _assetConfigs.length;

        for (uint256 i = 0; i < length;) {
            AssetConfig memory config = _assetConfigs[i];
            uint128 collateral = _userCollateral[account][config.asset];
            if (collateral > 0) {
                // Phase 1 Security: Use validated price - NO FALLBACK
                uint256 price = _getValidatedPrice(config.asset);
                // FIX: Scale to base token decimals for proper comparison
                uint256 valueInBase = _scaleCollateralToBase(config.asset, collateral, price);
                uint256 value = (valueInBase * config.liquidateCollateralFactor) / FACTOR_SCALE;
                totalValue += value;
            }
            unchecked { ++i; }
        }
        return totalValue;
    }

    /// @notice Scale collateral value to base token decimals
    /// @dev Converts (collateral amount * price) to base token units
    /// @param asset The collateral asset address
    /// @param collateral The collateral amount in asset's native decimals
    /// @param price The price in 18 decimals (USD per 1 whole token)
    /// @return value The collateral value in base token decimals
    function _scaleCollateralToBase(
        address asset,
        uint128 collateral,
        uint256 price
    ) internal view returns (uint256 value) {
        // Get collateral token decimals
        uint8 collateralDecimals = IERC20Metadata(asset).decimals();

        // Formula: value = (collateral * price * 10^baseDecimals) / (10^collateralDecimals * 10^18)
        // This converts from: collateral in native decimals * price in 18 decimals
        // To: value in base token decimals (e.g., USDC 6 decimals)
        //
        // Example: 1 WETH ($3000) to USDC
        // collateral = 1e18 (1 WETH in 18 decimals)
        // price = 3000e18 ($3000 in 18 decimals)
        // baseDecimals = 6
        // collateralDecimals = 18
        // value = (1e18 * 3000e18 * 1e6) / (1e18 * 1e18) = 3000e6 USDC

        value = (uint256(collateral) * price * (10 ** baseTokenDecimals))
              / ((10 ** collateralDecimals) * 1e18);
    }

    /// @notice Get validated price from oracle with staleness check
    /// @dev Phase 1 Security: Reverts if oracle not configured or price stale/invalid
    /// @dev Reference: Leihyn/knowledge/defi/chainlink/integration-guide.md
    /// @param asset The asset to get price for
    /// @return price The validated price in 18 decimals
    function _getValidatedPrice(address asset) internal view returns (uint256 price) {
        // CRITICAL: Oracle MUST be configured - no silent fallback
        if (address(priceOracle) == address(0)) {
            revert OracleNotConfigured();
        }

        // Get price with timestamp from oracle
        (uint256 assetPrice, uint256 updatedAt) = priceOracle.getPriceWithTimestamp(asset);

        // Staleness check - from Chainlink best practices
        if (block.timestamp - updatedAt > MAX_PRICE_STALENESS) {
            revert StalePriceData(asset, updatedAt);
        }

        // Price validity check
        if (assetPrice == 0) {
            revert InvalidPriceData(asset);
        }

        return assetPrice;
    }

    function _safe104(int256 x) internal pure returns (int104) {
        require(x >= type(int104).min && x <= type(int104).max, "int104 overflow");
        return int104(x);
    }
}
