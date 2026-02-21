// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/FixedPointMath.sol";

/// @title PositionManager
/// @author Kairos Protocol
/// @notice Manages Interest Rate Swap positions as NFTs
/// @dev Each position is represented as an ERC721 token for composability
contract PositionManager is ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using FixedPointMath for uint256;
    using Strings for uint256;
    using Strings for int256;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Position data - gas optimized struct packing
    /// @dev Packed into 4 storage slots
    struct Position {
        // Slot 0: 32 bytes
        address trader;           // 20 bytes - original position creator
        bool isPayingFixed;       // 1 byte - true = pay fixed, receive floating
        uint40 startTime;         // 5 bytes - position open timestamp
        uint40 maturity;          // 5 bytes - position expiry timestamp
        bool isActive;            // 1 byte - position status

        // Slot 1: 32 bytes
        uint128 notional;         // 16 bytes - principal amount (not exchanged)
        uint128 margin;           // 16 bytes - collateral posted

        // Slot 2: 32 bytes
        uint128 fixedRate;        // 16 bytes - locked fixed rate in WAD
        int128 accumulatedPnL;    // 16 bytes - settled profit/loss

        // Slot 3: 32 bytes
        uint40 lastSettlement;    // 5 bytes - last settlement timestamp
        uint216 _reserved;        // 27 bytes - reserved for future use
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Collateral token (e.g., USDC)
    IERC20 public immutable collateralToken;

    /// @notice Collateral token decimals
    uint8 public immutable collateralDecimals;

    /// @notice Next position ID to mint
    uint256 public nextPositionId;

    /// @notice Position data by ID
    mapping(uint256 => Position) public positions;

    /// @notice Authorized contracts that can modify positions (settlement, liquidation)
    mapping(address => bool) public authorizedContracts;

    /// @notice Total notional for positions paying fixed
    uint256 public totalFixedNotional;

    /// @notice Total notional for positions receiving fixed
    uint256 public totalFloatingNotional;

    /// @notice Total margin held in contract
    uint256 public totalMargin;

    /// @notice Total number of active positions
    uint256 public activePositionCount;

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL FEES
    //////////////////////////////////////////////////////////////*/

    /// @notice Trading fee on opening positions (percentage of notional in WAD)
    /// @dev 0.05% = 0.0005e18
    uint256 public tradingFee = 0.0005e18;

    /// @notice Protocol fee recipient address
    address public protocolFeeRecipient;

    /// @notice Total trading fees collected
    uint256 public totalTradingFeesCollected;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initial margin ratio (10% of notional)
    uint256 public constant INITIAL_MARGIN_RATIO = 0.10e18;

    /// @notice Minimum margin ratio (5% of notional)
    uint256 public constant MIN_MARGIN_RATIO = 0.05e18;

    /// @notice Valid maturities in days
    uint256[] public VALID_MATURITIES = [30, 90, 180, 365];

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionOpened(
        uint256 indexed positionId,
        address indexed trader,
        bool isPayingFixed,
        uint256 notional,
        uint256 fixedRate,
        uint256 margin,
        uint256 maturity
    );

    event PositionClosed(
        uint256 indexed positionId,
        address indexed trader,
        int256 finalPnL,
        uint256 payout
    );

    event MarginAdded(
        uint256 indexed positionId,
        address indexed sender,
        uint256 amount,
        uint256 newMargin
    );

    event MarginRemoved(
        uint256 indexed positionId,
        address indexed trader,
        uint256 amount,
        uint256 newMargin
    );

    event PositionSettled(
        uint256 indexed positionId,
        int256 pnlDelta,
        int256 newAccumulatedPnL
    );

    event ContractAuthorized(address indexed contractAddress, bool authorized);

    event TradingFeeCollected(
        uint256 indexed positionId,
        uint256 feeAmount
    );

    event TradingFeeUpdated(uint256 newFee);
    event ProtocolFeeRecipientUpdated(address newRecipient);
    event FeesWithdrawn(address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidNotional();
    error InvalidMaturity();
    error InvalidFixedRate();
    error InsufficientMargin(uint256 required, uint256 provided);
    error PositionNotActive(uint256 positionId);
    error NotPositionOwner(uint256 positionId, address caller);
    error NotAuthorized(address caller);
    error PositionNotMatured(uint256 positionId, uint256 maturity);
    error PositionAlreadyMatured(uint256 positionId);
    error ExcessiveMarginWithdrawal(uint256 requested, uint256 available);
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFee();
    error NoFeesToWithdraw();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorized() {
        if (!authorizedContracts[msg.sender]) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    modifier onlyPositionOwner(uint256 positionId) {
        if (ownerOf(positionId) != msg.sender) {
            revert NotPositionOwner(positionId, msg.sender);
        }
        _;
    }

    modifier positionActive(uint256 positionId) {
        if (!positions[positionId].isActive) {
            revert PositionNotActive(positionId);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _collateralToken,
        uint8 _collateralDecimals,
        address _protocolFeeRecipient
    ) ERC721("Kairos IRS Position", "KIRS") {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_protocolFeeRecipient == address(0)) revert ZeroAddress();

        collateralToken = IERC20(_collateralToken);
        collateralDecimals = _collateralDecimals;
        protocolFeeRecipient = _protocolFeeRecipient;

        // Authorize deployer initially (for setup)
        authorizedContracts[msg.sender] = true;
    }

    /*//////////////////////////////////////////////////////////////
                          POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Open a new swap position
    /// @param isPayingFixed True = pay fixed rate, receive floating rate
    /// @param notional Principal amount (not transferred, used for interest calc)
    /// @param fixedRate Fixed rate in WAD (e.g., 5% = 0.05e18)
    /// @param maturityDays Duration in days (30, 90, 180, or 365)
    /// @param margin Initial margin to deposit
    /// @return positionId The ID of the newly created position
    function openPosition(
        bool isPayingFixed,
        uint128 notional,
        uint128 fixedRate,
        uint256 maturityDays,
        uint128 margin
    ) external nonReentrant returns (uint256 positionId) {
        // Validate inputs
        if (notional == 0) revert InvalidNotional();
        if (fixedRate == 0 || fixedRate > 1e18) revert InvalidFixedRate();
        if (!_isValidMaturity(maturityDays)) revert InvalidMaturity();

        // Calculate minimum margin (10% of notional)
        uint256 minMargin = uint256(notional).wadMul(INITIAL_MARGIN_RATIO);
        if (margin < minMargin) {
            revert InsufficientMargin(minMargin, margin);
        }

        // Calculate trading fee (percentage of notional)
        uint256 feeAmount = uint256(notional).wadMul(tradingFee);

        // Transfer margin + fee from user
        collateralToken.safeTransferFrom(msg.sender, address(this), margin + feeAmount);

        // Accumulate trading fees
        totalTradingFeesCollected += feeAmount;

        // Create position
        positionId = nextPositionId++;

        positions[positionId] = Position({
            trader: msg.sender,
            isPayingFixed: isPayingFixed,
            startTime: uint40(block.timestamp),
            maturity: uint40(block.timestamp + maturityDays * 1 days),
            isActive: true,
            notional: notional,
            margin: margin,
            fixedRate: fixedRate,
            accumulatedPnL: 0,
            lastSettlement: uint40(block.timestamp),
            _reserved: 0
        });

        // Update totals
        if (isPayingFixed) {
            totalFixedNotional += notional;
        } else {
            totalFloatingNotional += notional;
        }
        totalMargin += margin;
        activePositionCount++;

        // Mint NFT to trader
        _mint(msg.sender, positionId);

        emit PositionOpened(
            positionId,
            msg.sender,
            isPayingFixed,
            notional,
            fixedRate,
            margin,
            block.timestamp + maturityDays * 1 days
        );

        if (feeAmount > 0) {
            emit TradingFeeCollected(positionId, feeAmount);
        }
    }

    /// @notice Open a position on behalf of another address (for OrderBook)
    /// @dev Only authorized contracts can call this. Margin must be pre-transferred.
    /// @param trader Address to open position for
    /// @param isPayingFixed True = pay fixed rate, receive floating rate
    /// @param notional Principal amount
    /// @param fixedRate Fixed rate in WAD
    /// @param maturityDays Duration in days
    /// @param margin Margin amount (must already be in contract)
    /// @return positionId The ID of the newly created position
    function openPositionFor(
        address trader,
        bool isPayingFixed,
        uint128 notional,
        uint128 fixedRate,
        uint256 maturityDays,
        uint128 margin
    ) external nonReentrant onlyAuthorized returns (uint256 positionId) {
        // Validate inputs
        if (trader == address(0)) revert ZeroAddress();
        if (notional == 0) revert InvalidNotional();
        if (fixedRate == 0 || fixedRate > 1e18) revert InvalidFixedRate();
        if (!_isValidMaturity(maturityDays)) revert InvalidMaturity();

        // Calculate minimum margin (10% of notional)
        uint256 minMargin = uint256(notional).wadMul(INITIAL_MARGIN_RATIO);
        if (margin < minMargin) {
            revert InsufficientMargin(minMargin, margin);
        }

        // Note: Margin should already be transferred by the authorized contract
        // No trading fee for matched orders (OrderBook has its own matching fee)

        // Create position
        positionId = nextPositionId++;

        positions[positionId] = Position({
            trader: trader,
            isPayingFixed: isPayingFixed,
            startTime: uint40(block.timestamp),
            maturity: uint40(block.timestamp + maturityDays * 1 days),
            isActive: true,
            notional: notional,
            margin: margin,
            fixedRate: fixedRate,
            accumulatedPnL: 0,
            lastSettlement: uint40(block.timestamp),
            _reserved: 0
        });

        // Update totals
        if (isPayingFixed) {
            totalFixedNotional += notional;
        } else {
            totalFloatingNotional += notional;
        }
        totalMargin += margin;
        activePositionCount++;

        // Mint NFT to trader
        _mint(trader, positionId);

        emit PositionOpened(
            positionId,
            trader,
            isPayingFixed,
            notional,
            fixedRate,
            margin,
            block.timestamp + maturityDays * 1 days
        );
    }

    /// @notice Add margin to an existing position
    /// @param positionId Position to add margin to
    /// @param amount Amount of collateral to add
    function addMargin(
        uint256 positionId,
        uint128 amount
    ) external nonReentrant positionActive(positionId) {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[positionId];

        // Transfer margin from sender
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update position margin
        pos.margin += amount;
        totalMargin += amount;

        emit MarginAdded(positionId, msg.sender, amount, pos.margin);
    }

    /// @notice Remove excess margin from a position
    /// @param positionId Position to remove margin from
    /// @param amount Amount of collateral to remove
    function removeMargin(
        uint256 positionId,
        uint128 amount
    ) external nonReentrant onlyPositionOwner(positionId) positionActive(positionId) {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[positionId];

        // Check if withdrawal keeps margin above minimum
        uint256 minMargin = uint256(pos.notional).wadMul(MIN_MARGIN_RATIO);
        uint256 remainingMargin = pos.margin - amount;

        if (remainingMargin < minMargin) {
            revert ExcessiveMarginWithdrawal(amount, pos.margin - minMargin);
        }

        // Update position margin
        pos.margin -= amount;
        totalMargin -= amount;

        // Transfer margin to owner
        collateralToken.safeTransfer(msg.sender, amount);

        emit MarginRemoved(positionId, msg.sender, amount, pos.margin);
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Input struct for batch position opening
    struct OpenPositionParams {
        bool isPayingFixed;
        uint128 notional;
        uint128 fixedRate;
        uint256 maturityDays;
        uint128 margin;
    }

    /// @notice Open multiple positions in a single transaction
    /// @param params Array of position parameters
    /// @return positionIds Array of created position IDs
    function openMultiplePositions(
        OpenPositionParams[] calldata params
    ) external nonReentrant returns (uint256[] memory positionIds) {
        positionIds = new uint256[](params.length);

        // Calculate total margin + fees needed
        uint256 totalRequired = 0;
        for (uint256 i = 0; i < params.length; i++) {
            uint256 feeAmount = uint256(params[i].notional).wadMul(tradingFee);
            totalRequired += params[i].margin + feeAmount;
        }

        // Transfer total amount upfront
        collateralToken.safeTransferFrom(msg.sender, address(this), totalRequired);

        // Create each position
        for (uint256 i = 0; i < params.length; i++) {
            OpenPositionParams memory p = params[i];

            // Validate inputs
            if (p.notional == 0) revert InvalidNotional();
            if (p.fixedRate == 0 || p.fixedRate > 1e18) revert InvalidFixedRate();
            if (!_isValidMaturity(p.maturityDays)) revert InvalidMaturity();

            uint256 minMargin = uint256(p.notional).wadMul(INITIAL_MARGIN_RATIO);
            if (p.margin < minMargin) {
                revert InsufficientMargin(minMargin, p.margin);
            }

            // Calculate fee
            uint256 feeAmount = uint256(p.notional).wadMul(tradingFee);
            totalTradingFeesCollected += feeAmount;

            // Create position
            uint256 positionId = nextPositionId++;
            positionIds[i] = positionId;

            positions[positionId] = Position({
                trader: msg.sender,
                isPayingFixed: p.isPayingFixed,
                startTime: uint40(block.timestamp),
                maturity: uint40(block.timestamp + p.maturityDays * 1 days),
                isActive: true,
                notional: p.notional,
                margin: p.margin,
                fixedRate: p.fixedRate,
                accumulatedPnL: 0,
                lastSettlement: uint40(block.timestamp),
                _reserved: 0
            });

            // Update totals
            if (p.isPayingFixed) {
                totalFixedNotional += p.notional;
            } else {
                totalFloatingNotional += p.notional;
            }
            totalMargin += p.margin;
            activePositionCount++;

            // Mint NFT
            _mint(msg.sender, positionId);

            emit PositionOpened(
                positionId,
                msg.sender,
                p.isPayingFixed,
                p.notional,
                p.fixedRate,
                p.margin,
                block.timestamp + p.maturityDays * 1 days
            );

            if (feeAmount > 0) {
                emit TradingFeeCollected(positionId, feeAmount);
            }
        }
    }

    /// @notice Add margin to multiple positions at once
    /// @param positionIds Array of position IDs
    /// @param amounts Array of margin amounts to add
    function addMarginBatch(
        uint256[] calldata positionIds,
        uint128[] calldata amounts
    ) external nonReentrant {
        require(positionIds.length == amounts.length, "Length mismatch");

        // Calculate total
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        // Transfer total upfront
        collateralToken.safeTransferFrom(msg.sender, address(this), totalAmount);

        // Add to each position
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (amounts[i] == 0) continue;

            Position storage pos = positions[positionIds[i]];
            if (!pos.isActive) revert PositionNotActive(positionIds[i]);

            pos.margin += amounts[i];
            totalMargin += amounts[i];

            emit MarginAdded(positionIds[i], msg.sender, amounts[i], pos.margin);
        }
    }

    /// @notice Get multiple positions at once
    /// @param positionIds Array of position IDs to query
    /// @return positionsData Array of Position structs
    function getMultiplePositions(
        uint256[] calldata positionIds
    ) external view returns (Position[] memory positionsData) {
        positionsData = new Position[](positionIds.length);
        for (uint256 i = 0; i < positionIds.length; i++) {
            positionsData[i] = positions[positionIds[i]];
        }
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update position's accumulated PnL (called by settlement engine)
    /// @param positionId Position to update
    /// @param pnlDelta Change in PnL (can be positive or negative)
    function updatePositionPnL(
        uint256 positionId,
        int256 pnlDelta
    ) external onlyAuthorized positionActive(positionId) {
        Position storage pos = positions[positionId];

        // FIX H-01: Safe cast with bounds check
        require(
            pnlDelta >= type(int128).min && pnlDelta <= type(int128).max,
            "PnL delta overflow"
        );
        pos.accumulatedPnL += int128(pnlDelta);
        pos.lastSettlement = uint40(block.timestamp);

        emit PositionSettled(positionId, pnlDelta, pos.accumulatedPnL);
    }

    /// @notice Close a position (called by settlement or liquidation engine)
    /// @param positionId Position to close
    /// @param finalPnL Final profit/loss to apply
    function closePosition(
        uint256 positionId,
        int256 finalPnL
    ) external onlyAuthorized positionActive(positionId) {
        Position storage pos = positions[positionId];

        // Mark as inactive
        pos.isActive = false;

        // Update totals
        if (pos.isPayingFixed) {
            totalFixedNotional -= pos.notional;
        } else {
            totalFloatingNotional -= pos.notional;
        }
        totalMargin -= pos.margin;
        activePositionCount--;

        // Calculate payout
        int256 totalPnL = pos.accumulatedPnL + int128(finalPnL);
        int256 payoutSigned = int256(uint256(pos.margin)) + totalPnL;
        uint256 payout = payoutSigned > 0 ? uint256(payoutSigned) : 0;

        // Transfer payout to position owner
        address owner = ownerOf(positionId);
        if (payout > 0) {
            collateralToken.safeTransfer(owner, payout);
        }

        emit PositionClosed(positionId, owner, totalPnL, payout);
    }

    /// @notice Reduce position margin (for liquidations)
    /// @param positionId Position to reduce margin
    /// @param amount Amount to reduce
    /// @param recipient Where to send the margin
    function reduceMargin(
        uint256 positionId,
        uint128 amount,
        address recipient
    ) external onlyAuthorized positionActive(positionId) {
        Position storage pos = positions[positionId];

        if (amount > pos.margin) {
            amount = pos.margin;
        }

        pos.margin -= amount;
        totalMargin -= amount;

        collateralToken.safeTransfer(recipient, amount);
    }

    /// @notice Pay keeper reward from protocol reserves (called by SettlementEngine)
    /// @dev Keeper rewards come from trading fees or excess protocol balance
    /// @param keeper Address to receive the reward
    /// @param amount Amount to pay
    function payKeeper(
        address keeper,
        uint256 amount
    ) external onlyAuthorized {
        if (keeper == address(0)) revert ZeroAddress();
        if (amount == 0) return;

        // Pay from protocol's available balance (trading fees or reserves)
        // This is safe because fees are collected during position opening
        collateralToken.safeTransfer(keeper, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get full position data
    /// @param positionId Position ID to query
    /// @return Position struct
    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    /// @notice Get position's current margin
    function getMargin(uint256 positionId) external view returns (uint256) {
        return positions[positionId].margin;
    }

    /// @notice Get position's notional
    function getNotional(uint256 positionId) external view returns (uint256) {
        return positions[positionId].notional;
    }

    /// @notice Check if position is paying fixed
    function isPayingFixed(uint256 positionId) external view returns (bool) {
        return positions[positionId].isPayingFixed;
    }

    /// @notice Get position's fixed rate
    function getFixedRate(uint256 positionId) external view returns (uint256) {
        return positions[positionId].fixedRate;
    }

    /// @notice Get time until maturity
    function getTimeToMaturity(uint256 positionId) external view returns (uint256) {
        Position memory pos = positions[positionId];
        if (block.timestamp >= pos.maturity) return 0;
        return pos.maturity - block.timestamp;
    }

    /// @notice Check if position has matured
    function isMatured(uint256 positionId) external view returns (bool) {
        return block.timestamp >= positions[positionId].maturity;
    }

    /// @notice Calculate minimum margin for a notional amount
    function calculateMinMargin(uint256 notional) external pure returns (uint256) {
        return notional.wadMul(INITIAL_MARGIN_RATIO);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize a contract to modify positions
    /// @param contractAddress Address to authorize
    /// @param authorized Whether to authorize or revoke
    function setAuthorizedContract(
        address contractAddress,
        bool authorized
    ) external {
        // Only deployer can authorize (in production, use proper access control)
        require(authorizedContracts[msg.sender], "Not authorized");
        authorizedContracts[contractAddress] = authorized;
        emit ContractAuthorized(contractAddress, authorized);
    }

    /// @notice Update trading fee
    /// @param _tradingFee New trading fee in WAD (max 1% = 0.01e18)
    function setTradingFee(uint256 _tradingFee) external {
        require(authorizedContracts[msg.sender], "Not authorized");
        if (_tradingFee > 0.01e18) revert InvalidFee(); // Max 1%
        tradingFee = _tradingFee;
        emit TradingFeeUpdated(_tradingFee);
    }

    /// @notice Update protocol fee recipient
    /// @param _recipient New fee recipient address
    function setProtocolFeeRecipient(address _recipient) external {
        require(authorizedContracts[msg.sender], "Not authorized");
        if (_recipient == address(0)) revert ZeroAddress();
        protocolFeeRecipient = _recipient;
        emit ProtocolFeeRecipientUpdated(_recipient);
    }

    /// @notice Withdraw accumulated trading fees
    function withdrawTradingFees() external {
        require(authorizedContracts[msg.sender], "Not authorized");
        uint256 amount = totalTradingFeesCollected;
        if (amount == 0) revert NoFeesToWithdraw();

        totalTradingFeesCollected = 0;
        collateralToken.safeTransfer(protocolFeeRecipient, amount);
        emit FeesWithdrawn(protocolFeeRecipient, amount);
    }

    /// @notice Calculate trading fee for a given notional
    /// @param notional The notional amount
    /// @return feeAmount The trading fee amount
    function calculateTradingFee(uint256 notional) external view returns (uint256) {
        return notional.wadMul(tradingFee);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if maturity is valid
    function _isValidMaturity(uint256 days_) internal view returns (bool) {
        for (uint256 i = 0; i < VALID_MATURITIES.length; i++) {
            if (VALID_MATURITIES[i] == days_) return true;
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            NFT METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the token URI with on-chain SVG metadata
    /// @param tokenId The position ID
    /// @return URI with base64 encoded JSON metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        Position memory pos = positions[tokenId];

        // Simple SVG with minimal styling
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200">',
            '<rect width="300" height="200" fill="#1e293b"/>',
            '<text x="20" y="30" fill="#fff" font-size="16">KAIROS IRS #', tokenId.toString(), '</text>',
            '<text x="20" y="60" fill="#888" font-size="12">', pos.isPayingFixed ? "Pay Fixed" : "Pay Float", '</text>',
            '<text x="20" y="90" fill="#fff" font-size="14">Rate: ', _formatRate(pos.fixedRate), '</text>',
            '<text x="20" y="120" fill="#fff" font-size="14">Notional: ', _formatAmount(pos.notional), '</text>',
            '<text x="20" y="150" fill="#fff" font-size="14">Margin: ', _formatAmount(pos.margin), '</text>',
            '<text x="20" y="180" fill="', pos.isActive ? "#0f0" : "#f00", '" font-size="12">', pos.isActive ? "Active" : "Closed", '</text>',
            '</svg>'
        );

        bytes memory json = abi.encodePacked(
            '{"name":"Kairos IRS #', tokenId.toString(),
            '","description":"IRS Position","image":"data:image/svg+xml;base64,',
            Base64.encode(svg), '"}'
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    /// @notice Format rate as percentage string
    function _formatRate(uint128 rate) internal pure returns (string memory) {
        // Rate is in WAD (1e18), convert to percentage with 2 decimals
        uint256 percentage = (uint256(rate) * 10000) / 1e18;
        uint256 whole = percentage / 100;
        uint256 decimals = percentage % 100;

        if (decimals < 10) {
            return string(abi.encodePacked(whole.toString(), ".0", decimals.toString(), "%"));
        }
        return string(abi.encodePacked(whole.toString(), ".", decimals.toString(), "%"));
    }

    /// @notice Format amount with K/M suffix
    function _formatAmount(uint128 amount) internal view returns (string memory) {
        uint256 adjusted = uint256(amount) / (10 ** collateralDecimals);

        if (adjusted >= 1_000_000) {
            return string(abi.encodePacked((adjusted / 1_000_000).toString(), ".", ((adjusted % 1_000_000) / 100_000).toString(), "M"));
        } else if (adjusted >= 1_000) {
            return string(abi.encodePacked((adjusted / 1_000).toString(), ".", ((adjusted % 1_000) / 100).toString(), "K"));
        }
        return string(abi.encodePacked(adjusted.toString(), " USDC"));
    }

    /// @notice Format PnL with sign
    function _formatPnL(int128 pnl) internal view returns (string memory) {
        if (pnl == 0) return "$0.00";

        bool negative = pnl < 0;
        uint256 absPnl = negative ? uint256(uint128(-pnl)) : uint256(uint128(pnl));
        uint256 adjusted = absPnl / (10 ** collateralDecimals);
        uint256 decimals = (absPnl / (10 ** (collateralDecimals - 2))) % 100;

        string memory sign = negative ? "-$" : "+$";
        if (decimals < 10) {
            return string(abi.encodePacked(sign, adjusted.toString(), ".0", decimals.toString()));
        }
        return string(abi.encodePacked(sign, adjusted.toString(), ".", decimals.toString()));
    }
}
