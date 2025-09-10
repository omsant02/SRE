// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Lending } from "./Lending.sol";
import { CornDEX } from "./CornDEX.sol";
import { Corn } from "./Corn.sol";

contract FlashLoanLiquidator {
    Lending i_lending;
    CornDEX i_cornDEX;
    Corn i_corn;

    constructor(address _lending, address _cornDEX, address _corn) {
        i_lending = Lending(_lending);
        i_cornDEX = CornDEX(_cornDEX);
        i_corn = Corn(_corn);
        i_corn.approve(address(i_lending), type(uint256).max);
    }

    function executeOperation(uint256 amount, address initiator, address toLiquidate) external returns (bool) {
        i_lending.liquidate(toLiquidate);

        uint256 ethReserves = address(i_cornDEX).balance;
        uint256 tokenReserves = i_corn.balanceOf(address(i_cornDEX));
        uint256 requiredETHInput = i_cornDEX.calculateXInput(amount, ethReserves, tokenReserves);

        i_cornDEX.swap{ value: requiredETHInput }(requiredETHInput);

        if (address(this).balance > 0) {
            (bool success, ) = payable(initiator).call{ value: address(this).balance }("");
            require(success, "Failed to send ETH back to initiator");
        }

        return true;
    }

    receive() external payable {}
}

interface IFlashLoanRecipient {
    function executeOperation(uint256 amount, address initiator, address extraParam) external returns (bool);
}
