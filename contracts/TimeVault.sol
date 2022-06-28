// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/ITimeVault.sol";

contract TimeVault is ReentrancyGuard, ITimeVault {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeERC20 for IERC20;

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice Underlying Asset
    IERC20 public immutable underlying;

    /// @notice Collateral
    IERC20 public immutable collateral;

    /// @notice Convenience
    IConvenience public immutable convenience;

    /// -----------------------------------------------------------------------
    /// Constant variables
    /// -----------------------------------------------------------------------

    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Owner
    address public owner;

    /// @notice Pending owner
    address public pendingOwner;

    /// @notice Address of fee receiver
    address public feeReceiver;

    /// @notice Vault fee
    uint256 public fee;

    /// @notice The unix timestamp maturity of the pool
    uint256 public maturity;

    /// @notice Vault capacity
    uint256 public vaultCapacity;

    /// @notice Count how many times manager invests
    uint256 public currentRound;

    /// @notice Count closed positions
    uint256 public closedRound;

    /// @notice Total amount users deposited
    uint256 public totalDeposit;

    /// @notice Mapping of User Info
    mapping(address => UserInfo) public userInfos;

    /// @notice Mapping of total deposit for round
    mapping(uint256 => uint256) public roundTotalDeposit;

    /// @notice Mapping of reward for round
    mapping(uint256 => uint256) public roundReward;

    /// @notice Mapping of invest amount for round
    mapping(uint256 => uint256) public roundInvestAmount;

    /// @notice Mapping of claims out for round
    mapping(uint256 => IPair.Claims) public roundClaimsOut;

    /// @notice Mapping of user deposit amount for round
    mapping(address => mapping(uint256 => uint256)) public userRoundDeposit;

    /* ===== INIT ===== */

    /// @dev Constructor
    /// @param _owner Owner address
    /// @param _underlying Underlying token which users deposit
    /// @param _collateral Collateral Token address
    /// @param _convenience Convenience contract address
    /// @param _feeReceiver Address of fee receiver
    /// @param _maturity The unix timestamp maturity of the pool
    /// @param _fee Vault fee
    /// @param _vaultCapacity Vault capacity that users can deposit
    constructor(
        address _owner,
        address _underlying,
        address _collateral,
        address _feeReceiver,
        address _convenience,
        uint256 _maturity,
        uint256 _fee,
        uint256 _vaultCapacity
    ) {
        if (_owner == address(0))
            revert VaultError(VaultErrorCodes.ZERO_ADDRESS);

        owner = _owner;
        underlying = IERC20(_underlying);
        collateral = IERC20(_collateral);
        convenience = IConvenience(_convenience);
        feeReceiver = _feeReceiver;
        maturity = _maturity;
        fee = _fee;
        vaultCapacity = _vaultCapacity;
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @notice Inherit from ITimeVault
    function deposit(uint256 _amount) external override {
        if (_amount == 0)
            revert VaultError(VaultErrorCodes.INSUFFICIENT_BALANCE);
        if (totalDeposit + _amount > vaultCapacity)
            revert VaultError(VaultErrorCodes.CAPACITY_EXCEEDED);

        underlying.safeTransferFrom(msg.sender, address(this), _amount);

        UserInfo storage userInfo = userInfos[msg.sender];

        userInfo.depositAmount += _amount;
        userRoundDeposit[msg.sender][currentRound + 1] = userInfo.depositAmount;
        totalDeposit += _amount;

        emit Deposited(msg.sender, _amount, currentRound + 1);
    }

    /// @notice Inherit from ITimeVault
    function requestWithdraw(uint256 _amount) external override {
        if (_amount == 0)
            revert VaultError(VaultErrorCodes.INSUFFICIENT_BALANCE);
        UserInfo storage userInfo = userInfos[msg.sender];

        if (userInfo.request == true)
            revert VaultError(VaultErrorCodes.ALREADY_REQUESTED);

        calculateReward(msg.sender);

        if (
            _amount > underlying.balanceOf(address(this)) ||
            _amount > userInfo.reward + userInfo.depositAmount
        ) revert VaultError(VaultErrorCodes.INSUFFICIENT_BALANCE);

        userInfo.prevReward = userInfo.reward;

        if (_amount <= userInfo.reward) {
            userInfo.reward -= _amount;
        } else {
            userInfo.depositAmount -= _amount - userInfo.reward;
            userInfo.reward = 0;
        }

        userInfo.withdrawAmount = _amount;
        totalDeposit -= _amount;
        userInfo.request = true;

        emit WithdrawRequested(msg.sender, _amount);
    }

    /// @notice Inherit from ITimeVault
    function cancelWithdraw(uint256 _amount) external override {
        UserInfo storage userInfo = userInfos[msg.sender];

        if (userInfo.withdrawAmount < _amount)
            revert VaultError(VaultErrorCodes.INSUFFICIENT_BALANCE);

        if (_amount <= userInfo.prevReward) {
            userInfo.reward += _amount;
        } else {
            userInfo.reward = userInfo.prevReward;
            userInfo.depositAmount += _amount - userInfo.reward;
        }

        userInfo.withdrawAmount -= _amount;
        totalDeposit += _amount;

        if (userInfo.withdrawAmount == 0) userInfo.request = false;

        emit WithdrawCancelled(msg.sender, _amount);
    }

    /// @notice Inherit from ITimeVault
    function completeWithdraw() external override nonReentrant {
        UserInfo storage userInfo = userInfos[msg.sender];
        if (userInfo.request == false)
            revert VaultError(VaultErrorCodes.NOT_REQUESTED);

        underlying.safeTransfer(msg.sender, userInfo.withdrawAmount);

        emit WithdrawCompleted(msg.sender, userInfo.withdrawAmount);

        userInfo.withdrawAmount = 0;
        userInfo.request = false;
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @notice Inherit from ITimeVault
    function setVaultCap(uint256 _newCap) external override {
        if (msg.sender != owner) revert VaultError(VaultErrorCodes.NOT_OWNER);
        if (_newCap == 0)
            revert VaultError(VaultErrorCodes.INSUFFICIENT_BALANCE);

        emit VaultCapSet(msg.sender, vaultCapacity, _newCap);

        vaultCapacity = _newCap;
    }

    /// @notice Inherit from ITimeVault
    function setPendingOwner(address _pendingOwner) external override {
        if (msg.sender != owner) revert VaultError(VaultErrorCodes.NOT_OWNER);
        if (_pendingOwner == address(0))
            revert VaultError(VaultErrorCodes.ZERO_ADDRESS);

        pendingOwner = _pendingOwner;

        emit PendingOwnerSet(_pendingOwner);
    }

    /// @notice Inherit from ITimeVault
    function acceptOwner() external override {
        if (msg.sender != pendingOwner)
            revert VaultError(VaultErrorCodes.NOT_PENDING_OWNER);

        owner = msg.sender;
        pendingOwner = address(0);

        emit OwnerAccepted(msg.sender);
    }

    /// @notice Inherit from ITimeVault
    function invest(
        uint112 _amount,
        uint40 _percent,
        uint128 _minBond,
        uint128 _minInsurance
    ) external override {
        if (msg.sender != owner) revert VaultError(VaultErrorCodes.NOT_OWNER);
        currentRound++;
        roundTotalDeposit[currentRound] = totalDeposit;
        roundInvestAmount[currentRound] = _amount;

        (, roundClaimsOut[currentRound]) = convenience.lendGivenPercent(
            ILend.LendGivenPercent(
                underlying,
                collateral,
                maturity,
                address(this),
                address(this),
                _amount,
                _percent,
                _minBond,
                _minInsurance,
                block.timestamp + 1 days
            )
        );

        emit Invested(
            _amount,
            roundClaimsOut[currentRound],
            maturity,
            currentRound,
            closedRound
        );
    }

    /// @notice Inherit from ITimeVault
    function collect() external override {
        if (msg.sender != owner) revert VaultError(VaultErrorCodes.NOT_OWNER);

        closedRound++;

        IPair.Tokens memory tokensOut = convenience.collect(
            IWithdraw.Collect(
                underlying,
                collateral,
                maturity,
                address(this),
                address(this),
                roundClaimsOut[closedRound]
            )
        );

        swap(
            address(collateral),
            address(underlying),
            tokensOut.collateral,
            0,
            address(this)
        );

        roundReward[closedRound] =
            uint256(tokensOut.asset) +
            uint256(tokensOut.collateral) -
            roundInvestAmount[closedRound] -
            fee;

        underlying.safeTransfer(feeReceiver, fee);

        emit Collected(
            tokensOut,
            maturity,
            closedRound,
            roundReward[closedRound],
            currentRound
        );
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    /// @dev Swap any tokens in the vault to the denomination of the tokens invested by users.
    /// @dev Use the UniswapV2Router for exchange.
    /// @dev Can only be called by the current owner.
    /// @param _tokenIn Address of collateral token
    /// @param _tokenOut Address of underlying token
    /// @param _amountIn Amount of collateral tokens in the vault
    /// @param _amountOutMin Min amount of tokens can be exchanged
    /// @param _to Address of receiver who receive exchanged tokens
    function swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _to
    ) internal {
        if (msg.sender != owner) revert VaultError(VaultErrorCodes.NOT_OWNER);

        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        address[] memory path;
        if (_tokenIn == WETH || _tokenOut == WETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WETH;
            path[2] = _tokenOut;
        }

        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            _to,
            block.timestamp
        );

        emit Swapped(_tokenIn, _tokenOut, _amountIn, _amountOutMin, _to);
    }

    /// @dev Calculate user's reward from last withdraw round to latest closed reward.
    /// @dev User reward URn = Σn (Rn * Dn / Tn)
    /// @dev Rn = Reward after nth investment is done.
    /// @dev Dn = User's deposit amount which take participate in nth manager's investment.
    /// @dev Tn = Total deposit amount which take participate in nth invest.
    /// @param _user User address
    function calculateReward(address _user) internal {
        UserInfo storage userInfo = userInfos[_user];

        for (uint256 i = userInfo.lastWithdrawRound; i < closedRound; ++i) {
            if (userRoundDeposit[_user][i + 1] == 0) {
                userRoundDeposit[_user][i + 1] = userRoundDeposit[_user][i];
            }
            userInfo.reward +=
                (roundReward[i + 1] * userRoundDeposit[_user][i + 1]) /
                roundTotalDeposit[i + 1];
        }

        userInfo.lastWithdrawRound = closedRound;

        emit RewardCalculated(_user, userInfo.reward);
    }
}
