// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "./IConvenience.sol";

interface ITimeVault {
    /// -----------------------------------------------------------------------
    /// Struct
    /// -----------------------------------------------------------------------

    /// @param depositAmount Deposit amount
    /// @param withdrawAmount Withdraw amount
    /// @param lastWithdrawRound Round index when user withdrew in the last
    /// @param reward Rewards which user gets from last withdraw to current withdraw
    /// @param prevReward Temporary variable to restore the previous reward when cancel the request withdraw
    /// @param request Bool variable if withdraw is requested or not
    struct UserInfo {
        uint256 depositAmount;
        uint256 withdrawAmount;
        uint256 lastWithdrawRound;
        uint256 reward;
        uint256 prevReward;
        bool request;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum VaultErrorCodes {
        ZERO_ADDRESS,
        NOT_OWNER,
        CAPACITY_EXCEEDED,
        INSUFFICIENT_BALANCE,
        NOT_PENDING_OWNER,
        NOT_REQUESTED,
        ALREADY_REQUESTED
    }

    error VaultError(VaultErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when user deposit.
    /// @param user User address
    /// @param amount Deposit amount
    /// @param depositRound Round that new deposit amount can take participate
    event Deposited(address indexed user, uint256 amount, uint256 depositRound);

    /// @dev Emits when user request withdraw.
    /// @param user User address
    /// @param amount Request withdraw amount
    event WithdrawRequested(address indexed user, uint256 amount);

    /// @dev Emits when user cancel withdraw.
    /// @param user User address
    /// @param amount Cancel withdraw amount
    event WithdrawCancelled(address indexed user, uint256 amount);

    /// @dev Emits when user compelete withdraw.
    /// @param user User address
    /// @param amount Complete withdraw amount
    event WithdrawCompleted(address indexed user, uint256 amount);

    /// @dev Emits when owner set vault cap.
    /// @param owner Owner address
    /// @param oldCap Previous vault cap
    /// @param newCap New vault cap
    event VaultCapSet(address indexed owner, uint256 oldCap, uint256 newCap);

    /// @dev Emits when owner sets the pending owner.
    /// @param pendingOwner Pending owner address
    event PendingOwnerSet(address indexed pendingOwner);

    /// @dev Emits when pending owner accepts the role.
    /// @param newOwner New owner address
    event OwnerAccepted(address indexed newOwner);

    /// @dev Emits when manager invest.
    /// @param amount Invest amount
    /// @param claimsOut Bond & Insurance tokens from the pool
    /// @param maturity Maturity of the pool
    /// @param currentRound Current invest round
    /// @param closedRound Latest closed round
    event Invested(
        uint256 amount,
        IPair.Claims claimsOut,
        uint256 maturity,
        uint256 currentRound,
        uint256 closedRound
    );

    /// @dev Emits when manager close lend position.
    /// @param tokensOut Tokens out from the pool after maturity
    /// @param maturity maturity of the pool
    /// @param closedRound Latest closed round
    /// @param reward Reward after maturity from the pool
    /// @param currentRound Current invest round
    event Collected(
        IPair.Tokens tokensOut,
        uint256 maturity,
        uint256 closedRound,
        uint256 reward,
        uint256 currentRound
    );

    /// @dev Emits when manager swaps collateral token to underlying token
    /// @param tokenIn Address of collateral token
    /// @param tokenOut Address of underlying token
    /// @param amountIn Amount of collateral tokens in the vault
    /// @param amountOutMin Min amount of tokens can be exchanged
    /// @param to Address of receiver who receive exchanged tokens
    event Swapped(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address indexed to
    );

    /// @dev Emits when user's reward is calculated.
    /// @param user Address of user
    /// @param reward Amount of reward
    event RewardCalculated(address indexed user, uint256 reward);

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @dev Deposits UNDERLYING tokens to the vault
    /// @param _amount Amount of UNDERLYING tokens to deposit
    function deposit(uint256 _amount) external;

    /// @dev Request withdraw from the vault
    /// @dev Unless cancelled, withdraw request can be completed at the end of the round
    /// @param _amount Request withdraw amount
    function requestWithdraw(uint256 _amount) external;

    /// @dev Cancel a withdraw request
    /// @param _amount Cancel withdraw amount
    function cancelWithdraw(uint256 _amount) external;

    /// @dev Complete withdraw request and claim UNDERLYING tokens from the vault
    function completeWithdraw() external;

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Set vault capacity
    /// @param _newCap Vault capacity amount in UNDERLYING
    function setVaultCap(uint256 _newCap) external;

    /// @dev Set the pending owner of the contract
    /// @dev Can only be called by the current owner.
    /// @param _pendingOwner the chosen pending owner.
    function setPendingOwner(address _pendingOwner) external;

    /// @dev Set the pending owner as the owner of the contract.
    /// @dev Reset the pending owner to zero.
    /// @dev Can only be called by the pending owner.
    function acceptOwner() external;

    /// @dev Invest(lend) the funds to the Timeswap pool of a specific pair only that which maturity does not exceed the weekly frequency.
    /// @dev Can only be called by the current owner.
    /// @param _amount Invest amount which manager deposits
    /// @param _percent Percent rate between bond and insurance
    /// @param _minBond Minimum bond value
    /// @param _minInsurance Minimum insurance value
    function invest(
        uint112 _amount,
        uint40 _percent,
        uint128 _minBond,
        uint128 _minInsurance
    ) external;

    /// @dev Collect the funds which manager invested(lent) to the pool after maturity.
    /// @dev Can only be called by the current owner.
    function collect() external;
}
