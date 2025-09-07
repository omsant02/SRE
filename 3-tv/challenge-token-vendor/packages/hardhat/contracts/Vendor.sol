pragma solidity 0.8.20; //Do not change the solidity version as it negatively impacts submission grading
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YourToken.sol";

contract Vendor is Ownable {
    event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);
    event SellTokens(address seller, uint256 amountOfTokens, uint256 amountOfETH);

    YourToken public yourToken;

    uint256 public constant tokensPerEth = 100;

    constructor(address tokenAddress) Ownable(msg.sender) {
        yourToken = YourToken(tokenAddress);
    }

    // ToDo: create a payable buyTokens() function:
    function buyTokens() external payable {
        yourToken.transfer(msg.sender, (msg.value) * (tokensPerEth));

        emit BuyTokens(msg.sender, msg.value, (msg.value) * (tokensPerEth));
    }

    // ToDo: create a withdraw() function that lets the owner withdraw ETH
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // ToDo: create a sellTokens(uint256 _amount) function:
    function sellTokens(uint256 _amount) public {
        yourToken.transferFrom(msg.sender, address(this), _amount);

        // Calculate ETH to pay: tokens / tokensPerEth
        uint256 ethToReturn = _amount / tokensPerEth;

        // Send ETH to user
        payable(msg.sender).transfer(ethToReturn);

        emit SellTokens(msg.sender, _amount, ethToReturn);
    }
}
