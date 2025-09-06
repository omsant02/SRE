// SPDX-License-Identifier: MIT
pragma solidity 0.8.20; //Do not change the solidity version as it negatively impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    uint256 public deadline = block.timestamp + 30 seconds;
    uint256 public constant threshold = 1 ether;
    bool openForWithdraw = false;

    mapping(address => uint256) public balances;
    event Stake(address, uint256);

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    }

    // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
    // (Make sure to add a `Stake(address,uint256)` event and emit it for the frontend `All Stakings` tab to display)
    function stake() public payable {
        balances[msg.sender] += msg.value;
        emit Stake(msg.sender, msg.value);
    }

    // After some `deadline` allow anyone to call an `execute()` function
    // If the deadline has passed and the threshold is met, it should call `exampleExternalContract.complete{value: address(this).balance}()`
    function execute() external {
        require(block.timestamp >= deadline, "deadline is not met");

        if (address(this).balance >= threshold) {
            exampleExternalContract.complete{ value: address(this).balance }();
        } else {
            // Set openForWithdraw = true (you need to add this bool)
            openForWithdraw = true;
        }
    }

    // If the `threshold` was not met, allow everyone to call a `withdraw()` function to withdraw their balance
    function withdraw() external {
        require(openForWithdraw, "threshold has already met");
        require(block.timestamp >= deadline, "Deadline not reached yet");
        (bool sent, ) = (msg.sender).call{ value: balances[msg.sender] }("");
        require(sent, "failed to send ether");
    }

    // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    // Add the `receive()` special function that receives eth and calls stake()

    receive() external payable {
        stake();
    }
}
