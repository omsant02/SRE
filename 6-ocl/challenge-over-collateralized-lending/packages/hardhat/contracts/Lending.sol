// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Corn.sol";
import "./CornDEX.sol";

error Lending__InvalidAmount();
error Lending__TransferFailed();
error Lending__UnsafePositionRatio();
error Lending__BorrowingFailed();
error Lending__RepayingFailed();
error Lending__PositionSafe();
error Lending__NotLiquidatable();
error Lending__InsufficientLiquidatorCorn();

contract Lending is Ownable {
    uint256 private constant COLLATERAL_RATIO = 120; // 120% collateralization required
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators

    Corn private i_corn;
    CornDEX private i_cornDEX;

    mapping(address => uint256) public s_userCollateral; // User's collateral balance
    mapping(address => uint256) public s_userBorrowed; // User's borrowed corn balance

    event CollateralAdded(address indexed user, uint256 indexed amount, uint256 price);
    event CollateralWithdrawn(address indexed user, uint256 indexed amount, uint256 price);
    event AssetBorrowed(address indexed user, uint256 indexed amount, uint256 price);
    event AssetRepaid(address indexed user, uint256 indexed amount, uint256 price);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    constructor(address _cornDEX, address _corn) Ownable(msg.sender) {
        i_cornDEX = CornDEX(_cornDEX);
        i_corn = Corn(_corn);
        i_corn.approve(address(this), type(uint256).max);
    }

    /**
     * @notice Allows users to add collateral to their account
     */
    function addCollateral() public payable {
        if (msg.value == 0) {
            revert Lending__InvalidAmount(); 
        }

        s_userCollateral[msg.sender] += msg.value;
        emit CollateralAdded( msg.sender, msg.value, i_cornDEX.currentPrice());
    }

    /**
     * @notice Allows users to withdraw collateral as long as it doesn't make them liquidatable
     * @param amount The amount of collateral to withdraw
     */
    function withdrawCollateral(uint256 amount) public {
        if( amount == 0 || amount > s_userCollateral[msg.sender] ) {
            revert Lending__InvalidAmount();
        }

        s_userCollateral[msg.sender] -= amount;

        if(s_userBorrowed[msg.sender] != 0){
            _validatePosition(msg.sender);
        }
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        if (!sent) {
            revert Lending__TransferFailed();
        }
        emit CollateralWithdrawn(msg.sender, amount, i_cornDEX.currentPrice());
    }

    /**
     * @notice Calculates the total collateral value for a user based on their collateral balance
     * @param user The address of the user to calculate the collateral value for
     * @return uint256 The collateral value
     */
    function calculateCollateralValue(address user) public view returns (uint256) {
        return (s_userCollateral[user] * i_cornDEX.currentPrice() / 1e18);
    }

    /**
     * @notice Calculates the position ratio for a user to ensure they are within safe limits
     * @param user The address of the user to calculate the position ratio for
     * @return uint256 The position ratio
     */
    function _calculatePositionRatio(address user) internal view returns (uint256) {
        if (s_userBorrowed[user] == 0) return type(uint256).max;
        return (calculateCollateralValue(user) * 1e18) / s_userBorrowed[user];
    }

    /**
     * @notice Checks if a user's position can be liquidated
     * @param user The address of the user to check
     * @return bool True if the position is liquidatable, false otherwise
     */
    function isLiquidatable(address user) public view returns (bool) {
        if (_calculatePositionRatio(user)*100 < COLLATERAL_RATIO * 1e18) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Internal view method that reverts if a user's position is unsafe
     * @param user The address of the user to validate
     */
    function _validatePosition(address user) internal view {
        if(isLiquidatable(user)) {
            revert Lending__UnsafePositionRatio();
        }
    }

    /**
     * @notice Allows users to borrow corn based on their collateral
     * @param borrowAmount The amount of corn to borrow
     */
    function borrowCorn(uint256 borrowAmount) public {
        if(borrowAmount == 0) {
            revert Lending__InvalidAmount();
        }

        s_userBorrowed[msg.sender] += borrowAmount;
        _validatePosition(msg.sender);

        bool success = i_corn.transfer(msg.sender, borrowAmount);
        if (!success) {
            revert Lending__BorrowingFailed();
        }

        emit AssetBorrowed(msg.sender, borrowAmount, i_cornDEX.currentPrice());
    }

    /**
     * @notice Allows users to repay corn and reduce their debt
     * @param repayAmount The amount of corn to repay
     */
    function repayCorn(uint256 repayAmount) public {
        if(repayAmount == 0 || repayAmount > i_corn.balanceOf(msg.sender)) {
            revert Lending__InvalidAmount();
        }

        s_userBorrowed[msg.sender] -= repayAmount;

        bool success = i_corn.transferFrom(msg.sender, address(this), repayAmount);
        if (!success) {
            revert Lending__RepayingFailed();
        }

        emit AssetRepaid( msg.sender, repayAmount, i_cornDEX.currentPrice());
    }

    /**
     * @notice Allows liquidators to liquidate unsafe positions
     * @param user The address of the user to liquidate
     * @dev The caller must have enough CORN to pay back user's debt
     * @dev The caller must have approved this contract to transfer the debt
     */
    function liquidate(address user) public {
        if (!isLiquidatable(user)){
            revert Lending__NotLiquidatable();
        }                  
        uint256 users_debt = s_userBorrowed[user];
        uint256 users_collateral = s_userCollateral[user];
        uint256 user_collateral_value = calculateCollateralValue(user);

        if (i_corn.balanceOf(msg.sender) < s_userBorrowed[user]){
            revert Lending__InsufficientLiquidatorCorn();
        }

        i_corn.transferFrom(msg.sender, address(this), users_debt);

        s_userBorrowed[user] = 0;

        uint256 collateral_needed = users_debt * users_collateral / user_collateral_value;
        

        uint256 liquidator_amount = collateral_needed + (collateral_needed * LIQUIDATOR_REWARD/100);
        liquidator_amount = liquidator_amount > users_collateral ? users_collateral : liquidator_amount;

        s_userCollateral[user] -= liquidator_amount;

        (bool sent, ) = payable(msg.sender).call{value: liquidator_amount}("");
        
        if(!sent) {
            revert Lending__TransferFailed();
        }

        emit Liquidation( user, msg.sender, liquidator_amount, users_debt, i_cornDEX.currentPrice());
    }

    function flashLoan(IFlashLoanRecipient _recipient, uint256 _amount, address _extraParam) public {
        i_corn.transfer(address(_recipient), _amount);

        bool sent = _recipient.executeOperation(_amount, msg.sender, _extraParam);
        require(sent, "operation was unseccessful");

        i_corn.transferFrom(address(_recipient), address(this), _amount);
    }
}

interface IFlashLoanRecipient {
    function executeOperation(uint256 amount, address initiator, address extraParam) external returns (bool);
} 
